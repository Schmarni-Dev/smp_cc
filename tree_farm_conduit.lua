---@type ccTweaked.peripherals.Inventory
---@diagnostic disable-next-line: assign-type-mismatch
local output = peripheral.wrap("minecraft:crafter_1")
if output == nil then
	error("input perph is nil")
end
---@type { [string]: ccTweaked.peripherals.Inventory}
local inputs = {};
local function add_input(input)
	inputs[input] = peripheral.wrap(input);
end
add_input("minecraft:hopper_4")
add_input("minecraft:hopper_6")
add_input("minecraft:hopper_8")
add_input("minecraft:hopper_10")
local function move_items()
	while true do
		for _, inv in pairs(inputs) do
			for slot, item in pairs(inv.list()) do
				if item.count > 3 then
					inv.pushItems(peripheral.getName(output), slot, 1)
				end
			end
		end
		sleep(0)
	end
end


parallel.waitForAny(move_items)
