---@type ccTweaked.peripherals.Inventory
---@diagnostic disable-next-line: assign-type-mismatch
local input = peripheral.wrap("minecraft:chest_17")
if input == nil then
	error("input perph is nil")
end
---@type { [string]: ccTweaked.peripherals.Inventory}
local outputs = {};

for _, value in ipairs(peripheral.getNames()) do
	if string.match(value, "minecraft:barrel") then
		---@diagnostic disable-next-line: assign-type-mismatch
		outputs[value] = peripheral.wrap(value);
	end
end

local function add_inputs()
	while true do
		local event, side = os.pullEvent("peripheral");
		if event == "peripheral" then
			if string.match(side, "minecraft:barrel") then
				---@diagnostic disable-next-line: assign-type-mismatch
				outputs[side] = peripheral.wrap(side);
			end
		end
		coroutine.yield()
	end
end
local function remove_inputs()
	while true do
		local event, side = os.pullEvent("peripheral_detach");
		if event == "peripheral_detach" then
			if string.match(side, "minecraft:barrel") then
				---@diagnostic disable-next-line: assign-type-mismatch
				outputs[#outputs] = nil;
			end
		end
		coroutine.yield()
	end
end

local function move_items()
	while true do
		for _, inv in pairs(outputs) do
			for slot, item in pairs(input.list()) do
				inv.pullItems(peripheral.getName(input), slot, 1)
				if item.count > 0 then
					break
				end
			end
		end
		os.startTimer(0.05)
		coroutine.yield()
	end
end


parallel.waitForAny(add_inputs, remove_inputs, move_items)
