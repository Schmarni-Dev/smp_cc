local input = peripheral.wrap("minecraft:chest_8")
local output = peripheral.wrap("minecraft:chest_10")
local fuel_input = peripheral.wrap("minecraft:chest_9")
local fuel_items_per_operation = 2
local items_burned_per_cycle = 3
local tasks_per_batch = 240


local perphs = peripheral.getNames();
--1: input 2:fuel 3:output
---@type {id:string,api:ccTweaked.peripherals.Inventory}[]
local furnaces = {}

for _, value in ipairs(perphs) do
	if string.match(value, "minecraft:furnace") then
		table.insert(furnaces, { id = value, api = peripheral.wrap(value) });
	end
end


if input == nil then
	error("input is nil")
end
if output == nil then
	error("output is nil")
end
if fuel_input == nil then
	error("fuel_input is nil")
end

local function append(to, from)
	for _, value in ipairs(from) do
		table.insert(to, value)
	end
end

---@param inv ccTweaked.peripherals.Inventory
---@param amount integer
---@param id? string
---@return {slot:integer,amount:integer}[]
local function find_slots_with_min_amount(inv, amount, id)
	for key, value in pairs(inv.list()) do
		if id == nil or value.name == id then
			if value.count >= amount then
				local list = {}
				table.insert(list, { slot = key, amount = amount })
				return list
			else
				local next_slots = find_slots_with_min_amount(inv, amount - value.count, id)
				local list = {}
				table.insert(list, { slot = key, amount = value.count })
				append(list, next_slots);
				return list;
			end
		end
	end
	return {}
end


---@param from ccTweaked.peripherals.Inventory
---@param from_amount integer
---@param from_id? string
---@param to ccTweaked.peripherals.Inventory
---@param to_slot? integer
---@return boolean
local function transfer_first_items_from(from, from_amount, from_id, to, to_slot)
	local slots = find_slots_with_min_amount(from, from_amount, from_id)
	local inserted_items = false
	for _, move_op in ipairs(slots) do
		if to.pullItems(peripheral.getName(from), move_op.slot, move_op.amount, to_slot) ~= 0 then
			inserted_items = true
		end
	end
	return inserted_items
end


local function queue_funcs(list)
	return function()
		local fn = table.remove(list, #list);
		if fn ~= nil then
			parallel.waitForAll(fn, queue_funcs(list))
		end
	end
end

while true do
	---@type table<string,{count:integer,slots:integer[]}>
	local input_items = {}
	for slot, item in pairs(input.list()) do
		if input_items[item.name] == nil then
			input_items[item.name] = { count = 0, slots = {} }
		end
		input_items[item.name].count = item.count + input_items[item.name].count
		table.insert(input_items[item.name].slots, slot)
	end
	local fuel_items = 0
	for slot, item in pairs(fuel_input.list()) do
		fuel_items = fuel_items + item.count
	end
	local loops = 0
	local funcs = {}
	for item, info in pairs(input_items) do
		for _, furnace in ipairs(furnaces) do
			loops = loops + 1
			local index_1 = math.ceil(loops / tasks_per_batch)
			if funcs[index_1] == nil then
				funcs[index_1] = {}
			end
			funcs[index_1][loops % tasks_per_batch] = function()
				transfer_first_items_from(input, items_burned_per_cycle, item, furnace.api, 1)
			end
		end
	end
	for _, furnace in ipairs(furnaces) do
		loops = loops + 1
		local index_1 = math.ceil(loops / tasks_per_batch)
		if funcs[index_1] == nil then
			funcs[index_1] = {}
		end
		funcs[index_1][loops % tasks_per_batch] = function()
			transfer_first_items_from(fuel_input, fuel_items_per_operation,
				"minecraft:bamboo_planks",
				furnace.api, 2)
		end
	end
	for _, furnace in ipairs(furnaces) do
		loops = loops + 1
		local index_1 = math.ceil(loops / tasks_per_batch)
		if funcs[index_1] == nil then
			funcs[index_1] = {}
		end
		funcs[index_1][loops % tasks_per_batch] = function()
			output.pullItems(peripheral.getName(furnace.api), 3)
		end
	end
	for _, value in ipairs(funcs) do
		parallel.waitForAll(table.unpack(value))
	end
end
