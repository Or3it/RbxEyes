--!strict
-- StateMachine — explicit states/transitions with guards + enter/exit hooks.
-- Round flow, AI behavior, weapon states: all of it belongs here, not in
-- nested if-chains.
local StateMachine = {}
StateMachine.__index = StateMachine

export type Def = {
	initial: string,
	transitions: { { name: string, from: string | { string }, to: string,
		guard: ((...any) -> boolean)? } },
	onEnter: { [string]: (self: any, ...any) -> () }?,
	onExit: { [string]: (self: any, ...any) -> () }?,
}

function StateMachine.new(def: Def)
	local self = setmetatable({
		state = def.initial,
		_def = def,
		_changed = Instance.new("BindableEvent"),
	}, StateMachine)
	self.Changed = self._changed.Event
	return self
end

function StateMachine:can(event: string): boolean
	for _, t in ipairs(self._def.transitions) do
		if t.name == event then
			local froms = typeof(t.from) == "table" and t.from or { t.from }
			for _, f in ipairs(froms :: { string }) do
				if f == self.state or f == "*" then return true end
			end
		end
	end
	return false
end

function StateMachine:fire(event: string, ...: any): boolean
	for _, t in ipairs(self._def.transitions) do
		if t.name == event then
			local froms = typeof(t.from) == "table" and t.from or { t.from }
			for _, f in ipairs(froms :: { string }) do
				if f == self.state or f == "*" then
					if t.guard and not t.guard(...) then return false end
					local old = self.state
					local ex = self._def.onExit and self._def.onExit[old]
					if ex then ex(self, ...) end
					self.state = t.to
					local en = self._def.onEnter and self._def.onEnter[t.to]
					if en then en(self, ...) end
					self._changed:Fire(old, t.to, event)
					return true
				end
			end
		end
	end
	return false
end

return StateMachine
