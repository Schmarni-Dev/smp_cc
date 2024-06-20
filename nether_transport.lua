---@type { [string]: ccTweaked.peripherals.Inventory}
local inputs = {}
---@type ccTweaked.peripherals.Inventory
---@diagnostic disable-next-line: assign-type-mismatch
local output = peripheral.wrap("minecraft:dropper_0");
if output == nil then
	error("output perph is nil")
end

for _, value in ipairs(peripheral.getNames()) do
	if string.match(value, "minecraft:hopper") then
		---@diagnostic disable-next-line: assign-type-mismatch
		inputs[value] = peripheral.wrap(value);
	end
end

local function add_inputs()
	while true do
		local event, side = os.pullEvent("peripheral");
		if event == "peripheral" then
			if string.match(side, "minecraft:hopper") then
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
			if string.match(side, "minecraft:hopper") then
				---@diagnostic disable-next-line: assign-type-mismatch
				inputs[side] = nil;
			end
		end
		coroutine.yield()
	end
end

local function move_items()
	while true do
		for name, inv in pairs(inputs) do
			for slot, _ in pairs(inv.list()) do
				print(slot)
				inv.pushItems(peripheral.getName(output), slot)
			end
		end
		coroutine.yield()
	end
end

local function pulse_redstone()
	local state = false;
	while true do
		local all = 0;
		for _, item in pairs(output.list()) do
			all = all + item.count;
		end
		if all > 0 then
			state = not state;
			redstone.setOutput("top", state)
		end
		coroutine.yield()
	end
end

parallel.waitForAny(add_inputs, remove_inputs, move_items, pulse_redstone)
