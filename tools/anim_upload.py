#!/usr/bin/env python3
"""
anim_upload.py -- Blender action -> Roblox Animation asset, no GUI anywhere.

Run inside Blender (its Python has the rig loaded):
    exec(open("tools/anim_upload.py").read())
    upload_action("R15_walk", step=2)

Pipeline: Blender fcurves -> joint-local rotations in Roblox space -> KeyframeSequence
.rbxmx -> Open Cloud Assets API -> permanent rbxassetid.

Proven end to end 2026-07-26: R15_idle -> asset 136922974979522, played on a live rig
at Waist -2.44..2.46 (source +/-2.49), Neck -1.47..1.45, LeftShoulder Z 4.00 exact.

Requires .env with RBX_OPEN_CLOUD_KEY (needs the *Asset* scope, read+write --
without it every asset endpoint 403s with the misleading "User not authenticated")
and RBX_USER_ID.
"""
import bpy, os, json, uuid, time, urllib.request, urllib.error
from mathutils import Matrix

ENV_PATH = os.path.expanduser("~/Documents/rbx-eyes/.env")
OUT_DIR  = os.path.expanduser("~/Documents/rbx-eyes/exchange")
ARMATURE = "R15_WalkRig"
SCALE    = 4.6565          # studs per Blender unit, from clean rest geometry
BASIS    = Matrix(((-1,0,0),(0,0,1),(0,1,0)))   # (bx,by,bz) -> (-bx, bz, by)

# Pose tree must mirror the rig's REAL joint graph. Modern R15 routes the arms
# through Spine/Chest/Clavicle bones; the classic UpperTorso>LeftUpperArm chain
# applies nothing and fails silently.
HIER = {
 "HumanoidRootPart":["LowerTorso"],
 "LowerTorso":["UpperTorso","LeftUpperLeg","RightUpperLeg"],
 "UpperTorso":["Spine"], "Spine":["Chest"],
 "Chest":["Head","LeftClavicle","RightClavicle"],
 "LeftClavicle":["LeftUpperArm"],  "LeftUpperArm":["LeftLowerArm"],  "LeftLowerArm":["LeftHand"],
 "RightClavicle":["RightUpperArm"],"RightUpperArm":["RightLowerArm"],"RightLowerArm":["RightHand"],
 "LeftUpperLeg":["LeftLowerLeg"],  "LeftLowerLeg":["LeftFoot"],
 "RightUpperLeg":["RightLowerLeg"],"RightLowerLeg":["RightFoot"],
}

def _env():
    e = {}
    for line in open(ENV_PATH):
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            e[k.strip()] = v.strip().strip('"').strip("'")
    return e

def extract(action_name, step=2):
    arm = bpy.data.objects[ARMATURE]
    scene = bpy.context.scene
    bones = arm.data.bones
    # GOTCHA: assigning an action does NOT clear channels it doesn't animate.
    # Without this reset you export the previous action's root motion by accident.
    for pb in arm.pose.bones:
        pb.location = (0,0,0); pb.rotation_euler = (0,0,0)
        pb.rotation_quaternion = (1,0,0,0); pb.scale = (1,1,1)
    act = bpy.data.actions[action_name]
    arm.animation_data_create(); arm.animation_data.action = act
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    rot = sorted({fc.data_path.split('"')[1] for fc in act.fcurves
                  if fc.data_path.endswith("rotation_euler")})
    has_loc = any(fc.data_path.endswith("location") for fc in act.fcurves)
    Binv = BASIS.inverted()
    def d(n):
        pb = arm.pose.bones[n]
        return pb.matrix.to_3x3() @ bones[n].matrix_local.to_3x3().inverted()
    frames = []
    for f in range(f0, f1 + 1, step):
        scene.frame_set(f); bpy.context.view_layer.update()
        m = {}
        for n in rot:
            p = bones[n].parent.name if bones[n].parent else None
            Dp = d(p) if (p and p in rot) else Matrix.Identity(3)
            m[n] = BASIS @ (Dp.inverted() @ d(n)) @ Binv
        # root translation rides on the LowerTorso pose (the Root joint);
        # the HumanoidRootPart pose maps to no joint and is discarded.
        ry = arm.pose.bones["HumanoidRootPart"].location.z * SCALE if has_loc else 0.0
        frames.append(((f - f0) / scene.render.fps, m, ry))
    return frames

def to_rbxmx(frames, name, loop=True):
    ref = [0]
    def cf(M, y=0.0):
        r = [1,0,0,0,1,0,0,0,1] if M is None else [M[i][j] for i in range(3) for j in range(3)]
        t = "".join("<R%d%d>%.6f</R%d%d>" % (i,j,r[i*3+j],i,j) for i in range(3) for j in range(3))
        return '<CoordinateFrame name="CFrame"><X>0</X><Y>%.6f</Y><Z>0</Z>%s</CoordinateFrame>' % (y, t)
    def pose(nm, m, ry, depth):
        ref[0] += 1; pad = "  " * depth
        y = ry if nm == "LowerTorso" else 0.0
        s  = '%s<Item class="Pose" referent="RBX%d">\n%s <Properties>\n' % (pad, ref[0], pad)
        s += '%s  <string name="Name">%s</string>\n' % (pad, nm)
        s += '%s  %s\n' % (pad, cf(m.get(nm), y))
        s += '%s  <token name="EasingDirection">0</token>\n' % pad
        s += '%s  <token name="EasingStyle">0</token>\n' % pad
        s += '%s  <float name="Weight">1</float>\n' % pad
        s += '%s </Properties>\n' % pad
        for c in HIER.get(nm, []):
            s += pose(c, m, ry, depth + 1)
        return s + '%s</Item>\n' % pad
    ref[0] += 1
    x  = '<roblox xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
    x += 'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
    x += '<Item class="KeyframeSequence" referent="RBX%d">\n <Properties>\n' % ref[0]
    x += '  <string name="Name">%s</string>\n' % name
    x += '  <bool name="Loop">%s</bool>\n' % ("true" if loop else "false")
    x += '  <token name="Priority">1</token>\n </Properties>\n'
    for t, m, ry in frames:
        ref[0] += 1
        x += ' <Item class="Keyframe" referent="RBX%d">\n  <Properties>\n' % ref[0]
        x += '   <string name="Name">Keyframe</string>\n   <float name="Time">%.4f</float>\n' % t
        x += '  </Properties>\n'
        x += pose("HumanoidRootPart", m, ry, 2)
        x += ' </Item>\n'
    return x + '</Item>\n</roblox>\n'

def upload(path, display_name, description=""):
    e = _env(); key, uid = e["RBX_OPEN_CLOUD_KEY"], e["RBX_USER_ID"]
    data = open(path, "rb").read()
    req = json.dumps({"assetType": "Animation", "displayName": display_name,
                      "description": description or display_name,
                      "creationContext": {"creator": {"userId": uid}}})
    b = "----b" + uuid.uuid4().hex
    def part(n, v, fn=None, ct=None):
        h = '--%s\r\nContent-Disposition: form-data; name="%s"' % (b, n)
        if fn: h += '; filename="%s"' % fn
        h += "\r\n"
        if ct: h += "Content-Type: %s\r\n" % ct
        return h.encode() + b"\r\n" + (v if isinstance(v, bytes) else v.encode()) + b"\r\n"
    body = part("request", req)
    # NOTE: .rbxmx must be sent as model/x-rbxm. model/x-rbxmx returns 400.
    body += part("fileContent", data, os.path.basename(path), "model/x-rbxm")
    body += ("--%s--\r\n" % b).encode()
    r = urllib.request.Request("https://apis.roblox.com/assets/v1/assets", data=body,
        method="POST", headers={"x-api-key": key,
        "Content-Type": "multipart/form-data; boundary=%s" % b})
    with urllib.request.urlopen(r, timeout=180) as resp:
        op = json.loads(resp.read().decode())["operationId"]
    for _ in range(25):
        time.sleep(3)
        g = urllib.request.Request("https://apis.roblox.com/assets/v1/operations/%s" % op,
                                   headers={"x-api-key": key})
        with urllib.request.urlopen(g, timeout=60) as resp:
            o = json.loads(resp.read().decode())
        if o.get("done"):
            return o.get("response", {}).get("assetId"), o
    return None, {"error": "timed out"}

def hierarchy_from_armature(name=ARMATURE):
    """Derive the pose tree from the Blender rig -- correct for the CUSTOM skinned
    character (NoLanderBody), whose bones are UpperTorso > LeftUpperArm directly."""
    h = {}
    for b in bpy.data.objects[name].data.bones:
        if b.parent:
            h.setdefault(b.parent.name, []).append(b.name)
    return h

# HIER above is the STOCK AVATAR rig (UpperTorso > Spine > Chest > LeftClavicle >
# LeftUpperArm). The two are NOT interchangeable and mismatches fail silently --
# an avatar-hierarchy clip on the custom character animates legs perfectly and
# leaves both arms and the head at exactly 0.00 deg, with no error anywhere.
AVATAR_HIER = dict(HIER)

def upload_action(action_name, step=2, loop=True, hier=None, suffix=""):
    global HIER
    if hier is not None:
        HIER = hier
    frames = extract(action_name, step)
    xml = to_rbxmx(frames, action_name + suffix, loop)
    path = os.path.join(OUT_DIR, action_name + suffix + ".rbxmx")
    open(path, "w").write(xml)
    print("%s: %d keyframes, %d bytes" % (action_name, len(frames), len(xml)))
    aid, info = upload(path, action_name + suffix)
    print("  assetId:", aid, " moderation:",
          info.get("response", {}).get("moderationResult", {}).get("moderationState"))
    return aid
