local module = {}

local states = {}
local stunTimers = {}

function module.ReturnStates(plr)
	return states[plr]
end

function module.GetState(plr, stateKey)
	if states[plr] then
		return states[plr][stateKey]
	end
	return nil
end

function module.SetState(plr, stateKey, value, duration)
	if not states[plr] then
		states[plr] = {}
	end

	states[plr][stateKey] = value

	if duration and type(duration) == "number" then
		delay(duration, function()
			if states[plr] then
				states[plr][stateKey] = nil

				if next(states[plr]) == nil then
					states[plr] = nil
				end
			end
		end)
	end
end

function module.RemoveStates(plr, stateKey)
	if not states[plr] then return end

	if stateKey then
		states[plr][stateKey] = nil
		if next(states[plr]) == nil then
			states[plr] = nil
		end
	else
		states[plr] = nil
	end
end

function module.ClearAllStates()
	for plr in pairs(states) do
		states[plr] = nil
	end
	for plr in pairs(stunTimers) do
		stunTimers[plr] = nil
	end
end


game.Players.PlayerRemoving:Connect(function(plr)
	states[plr] = nil
	stunTimers[plr] = nil
end)

return module
