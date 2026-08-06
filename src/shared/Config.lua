local Config = {}

-- Round timing
Config.HIDE_TIME = 5       -- SET TO 60 FOR PRODUCTION
Config.HUNT_TIME = 30      -- SET TO 240 FOR PRODUCTION
Config.MIN_PLAYERS = 1

-- Debug
Config.DEBUG_FORCE_ROLE = "Survivor" -- set to nil to restore normal random roles
Config.DEBUG_LOGS = true             -- ragdoll/physics diagnostic prints

-- Movement
Config.WALK_SPEED = 16
Config.JUMP_POWER = 50
Config.CRAWL_SPEED = 5

-- NoLander custom body
Config.NOLANDER_SCALE = 3.2       -- 1.571 studs raw mesh * 3.2 = ~5.03 studs
Config.NOLANDER_WALK_SPEED = 20   -- must be re-applied AFTER Model:ScaleTo,
                                  -- which multiplies WalkSpeed by the scale

-- Laser (server-side validation)
Config.SERVER_COOLDOWN = 4.5 -- slightly longer than client 1.5 windup + 3 cooldown
Config.MIN_WINDUP = 1.3

-- Leg hits
Config.SELF_RECOVER_TIME = 20
Config.REVIVE_HOLD = 4

-- Blood loss / healing
Config.BLEED_RATE = 2        -- HP lost per second while bleeding
Config.BLEED_CLOT_TIME = 15  -- seconds until a wound clots on its own
Config.BANDAGE_HOLD = 3      -- seconds a teammate holds E to bandage
Config.BANDAGE_HEAL = 15     -- HP restored when bandaged
Config.REGEN_DELAY = 5       -- seconds after bleeding stops before regen starts
Config.REGEN_RATE = 1        -- HP per second passive regen
Config.DRIP_INTERVAL = 2     -- seconds between blood drips while bleeding

-- Ragdoll
Config.TOPPLE_PUSH = 12  -- horizontal shove so the body falls over (random direction, CLIENT-side)
Config.TOPPLE_LIFT = 2
Config.TOPPLE_SPIN = 14  -- max random angular velocity on the torso
Config.LIMB_KICK = 7     -- random per-limb impulse so arms/legs sprawl instead of staying at the sides
-- Friction near zero = fully floppy corpse physics. If limbs ever jitter or
-- vibrate on the ground, raise these slightly (2-5) to damp them.
Config.JOINT_LIMITS = {
	Root     = {upper = 45,  twistLower = -25, twistUpper = 25, friction = 5},
	Waist    = {upper = 55,  twistLower = -35, twistUpper = 35, friction = 3},
	Neck     = {upper = 65,  twistLower = -50, twistUpper = 50, friction = 1},
	Shoulder = {upper = 150, twistLower = -80, twistUpper = 80, friction = 0},
	Elbow    = {upper = 150, twistLower = -15, twistUpper = 15, friction = 0},
	Wrist    = {upper = 90,  twistLower = -45, twistUpper = 45, friction = 0},
	Hip      = {upper = 110, twistLower = -30, twistUpper = 30, friction = 0},
	Knee     = {upper = 140, twistLower = -8,  twistUpper = 8,  friction = 0},
	Ankle    = {upper = 70,  twistLower = -25, twistUpper = 25, friction = 0},
}
Config.DEFAULT_LIMITS = {upper = 90, twistLower = -30, twistUpper = 30, friction = 0}

return Config
