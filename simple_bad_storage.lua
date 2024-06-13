local perphs = peripheral.getNames();


--1: input 2:fuel 3:output
---@type ccTweaked.peripherals.Inventory[]
local barrels = {}

for _, value in ipairs(perphs) do
	if string.match(value, "minecraft:barrel") then
		table.insert(barrels, peripheral.wrap(value));
	end
end

---@type ccTweaked.peripherals.Inventory
local input = peripheral.wrap("minecraft:chest_11")
---@type ccTweaked.peripherals.Inventory
local output = peripheral.wrap("minecraft:chest_12")

if input == nil then
	error("input is nil")
end
if output == nil then
	error("output is nil")
end


local item_get_tries = 0

---@type table<ccTweaked.peripherals.Inventory,boolean>
local full_barrels = {}

---@type {item:string,amount:integer}
local request = { item = "minecraft:barrier", amount = 0 }
local function handle_input()
	while true do
		term.clear()
		term.setCursorPos(1, 1)
		print("Item Identifier:");
		local item_name = io.read();
		print("Item Amount")
		local amount = tonumber(io.read())
		if amount == nil then
			error("Invalid Amount")
		end
		request = { item = item_name, amount = amount }
		item_get_tries = 0
		sleep(0)
	end
end
local function move_items()
	while true do
		if request.amount > 0 and item_get_tries < 2 then
			local found = false
			for _, barrel in ipairs(barrels) do
				for slot, item in pairs(barrel.list()) do
					if item.name == request.item then
						found = true;
						request.amount = request.amount -
							barrel.pushItems(peripheral.getName(output), slot, request.amount);
						full_barrels[barrel] = false
						item_get_tries = 0
						break
					end
				end
				if found then
					break
				end
			end
			item_get_tries = item_get_tries + 1
		else
			local slot = nil
			for s, _ in pairs(input.list()) do
				slot = s
				break
			end
			if slot ~= nil then
				for _, barrel in ipairs(barrels) do
					if full_barrels[barrel] == nil or full_barrels[barrel] == false then
						if barrel.pullItems(peripheral.getName(input), slot) ~= 0 then
							break
						end
						full_barrels[barrel] = true
					end
				end
			end
		end
	end
end
parallel.waitForAll(handle_input, move_items)
