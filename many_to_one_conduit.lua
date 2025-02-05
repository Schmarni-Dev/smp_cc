local input_filter = "minecraft:hopper"
---@type ccTweaked.peripherals.Inventory
---@diagnostic disable-next-line: assign-type-mismatch
local output = peripheral.wrap("minecraft:chest_17")
if output == nil then
	error("input perph is nil")
end
---@type { [string]: ccTweaked.peripherals.Inventory}
local inputs = {};

for _, value in ipairs(peripheral.getNames()) do
	if string.match(value, input_filter) then
		---@diagnostic disable-next-line: assign-type-mismatch
		inputs[value] = peripheral.wrap(value);
	end
end

local function add_inputs()
	while true do
		local event, side = os.pullEvent("peripheral");
		if event == "peripheral" then
			if string.match(side, input_filter) then
				---@diagnostic disable-next-line: assign-type-mismatch
				inputs[side] = peripheral.wrap(side);
			end
		end
		coroutine.yield()
	end
end
local function remove_inputs()
	while true do
		local event, side = os.pullEvent("peripheral_detach");
		if event == "peripheral_detach" then
			if string.match(side, input_filter) then
				---@diagnostic disable-next-line: assign-type-mismatch
				inputs[#inputs] = nil;
			end
		end
		coroutine.yield()
	end
end

local function move_items()
	while true do
		for _, inv in pairs(inputs) do
			for slot, item in pairs(output.list()) do
				inv.pullItems(peripheral.getName(output), slot, 1)
				if item.count > 0 then
					break
				end
			end
		end
		os.startTimer(0.05)
		coroutine.yield()
		sleep(0)
	end
end


parallel.waitForAny(add_inputs, remove_inputs, move_items)
