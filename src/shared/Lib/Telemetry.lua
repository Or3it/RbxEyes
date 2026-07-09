--!strict
-- Telemetry — one call, two sinks: Roblox AnalyticsService (production
-- funnels/retention) + local bridge mirror (instant visibility during
-- playtests). Fire-and-forget; never throws into game code.
local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Telemetry = {}
local BRIDGE = "http://127.0.0.1:7791/telemetry"
local queue: { { [string]: any } } = {}

function Telemetry.log(event: string, props: { [string]: any }?,
		player: Player?)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, event,
			(props and props.value) or 1)
	end)
	if RunService:IsStudio() then
		table.insert(queue, { event = event, props = props or {},
			player = player and player.Name or nil, t = os.clock() })
	end
end

-- funnel sugar
function Telemetry.funnelStep(funnel: string, step: number, player: Player?)
	Telemetry.log(funnel .. "_step_" .. step, { funnel = funnel, step = step },
		player)
end

if RunService:IsServer() then
	task.spawn(function()
		while true do
			task.wait(3)
			if #queue > 0 then
				local batch = queue
				queue = {}
				for _, rec in ipairs(batch) do
					pcall(function()
						HttpService:PostAsync(BRIDGE,
							HttpService:JSONEncode(rec),
							Enum.HttpContentType.ApplicationJson)
					end)
				end
			end
		end
	end)
end

return Telemetry
