---@type { [string]: ccTweaked.peripherals.Inventory}
local inputs = {}
---@type ccTweaked.peripherals.Inventory
---@diagnostic disable-next-line: assign-type-mismatch
local crafter = peripheral.wrap("minecraft:crafter_0");
---@type ccTweaked.peripherals.Inventory
---@diagnostic disable-next-line: assign-type-mismatch
local crafter_out = peripheral.wrap("minecraft:chest_15");
---@type ccTweaked.peripherals.Inventory
---@diagnostic disable-next-line: assign-type-mismatch
local output = peripheral.wrap("minecraft:chest_18");
if output == nil then
	error("output perph is nil")
end

for _, value in ipairs(peripheral.getNames()) do
	if string.match(value, "minecraft:barrel") then
		---@diagnostic disable-next-line: assign-type-mismatch
		inputs[value] = peripheral.wrap(value);
	end
end

local function add_inputs()
	while true do
		local event, side = os.pullEvent("peripheral");
		if event == "peripheral" then
			if string.match(side, "minecraft:barrel") then
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
			if string.match(side, "minecraft:barrel") then
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
			for slot, item in pairs(inv.list()) do
				print(slot)
				if item.count >= 9 then
					for i = 1, 9, 1 do
						inv.pushItems(peripheral.getName(crafter), slot, 1, i)
					end
					redstone.setOutput("right", true)
					sleep(0)
					redstone.setOutput("right", false)
					sleep(0.25)
					crafter_out.pushItems(peripheral.getName(crafter), 1)
					redstone.setOutput("right", true)
					sleep(0)
					redstone.setOutput("right", false)
					sleep(0.25)
					crafter_out.pushItems(peripheral.getName(output), 1)
				end
			end
		end
		coroutine.yield()
	end
end

parallel.waitForAny(add_inputs, remove_inputs, move_items)
