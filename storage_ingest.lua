local input_net_name = "minecraft:chest_0"

-- NOT IMPLEMENTED YET
local input_net_names = { [1] = input_net_name }
---@type ccTweaked.http.Websocket | nil
local remote_ws = nil;
local connect_websocket = function()
	error("connect_websocket called to early")
end
---@param perph ccTweaked.peripherals.Inventory
local function ProtoStorage_from_peripherial(perph)
	local items = {}
	for i = 1, 27, 1 do
		items[i] = "None";
	end
	for slot, _ in pairs(perph.list()) do
		local item = perph.getItemDetail(slot);
		if item ~= nil then
			items[slot] = {
				Some = {
					ident = item.name,
					name = item.displayName,
					amount = item.count,
					max_stack_size = item.maxCount,
					nbt_hash = item.nbt
				}
			}
		end
	end
	return { net_name = peripheral.getName(perph), items = items }
end

local function send(data, bin)
	if remote_ws ~= nil then
		local success, _ = pcall(remote_ws.send, data, bin)
		if not success then
			connect_websocket();
			send(data, bin)
		end
	else
		error("ws is nil")
	end
end




local function sync_storages_with_remote()
	local per_batch = 200
	local fns = {}
	local loops = 0
	for _, value in ipairs(peripheral.getNames()) do
		if string.match(value, "minecraft:barrel") then
			loops = loops + 1
			local index_1 = math.ceil(loops / per_batch)
			if fns[index_1] == nil then
				fns[index_1] = {}
			end
			fns[index_1][loops % per_batch] = function()
				---@diagnostic disable-next-line: param-type-mismatch
				send(textutils.serializeJSON({ AddedStorage = ProtoStorage_from_peripherial(peripheral.wrap(value)) }))
			end
		end
	end
	for _, fns_2 in ipairs(fns) do
		parallel.waitForAll(table.unpack(fns_2))
	end
	should_refresh_item_list = true
end

local function __inner_connect_websocket()
	local ws, msg = http.websocket("ws://localhost:6969/storage_computer_ws")
	if ws == false then
		printError(msg);
		sleep(30);
		return __inner_connect_websocket()
	end
	return ws
end
connect_websocket = function()
	is_waiting_for_ws = true;
	if remote_ws ~= nil then
		pcall(remote_ws.close);
	end
	local ws = __inner_connect_websocket()
	is_waiting_for_ws = false;
	remote_ws = ws
end
connect_websocket();
sync_storages_with_remote()

local function recv(timeout)
	local success, result, is_bin = pcall(remote_ws.receive, timeout)
	if not success then
		connect_websocket();
		success, result, is_bin = pcall(remote_ws.receive, timeout)
	end
	return result, is_bin
end

local function add_storage_on_attach()
	while true do
		local event, net_name = os.pullEvent("peripheral");
		if event == "peripheral" then
			---@diagnostic disable-next-line: param-type-mismatch
			local storage = ProtoStorage_from_peripherial(peripheral.wrap(net_name));
			send(textutils.serialiseJSON({ AddedStorage = storage }), false)
		end
	end
end

local function remove_storage_on_detach()
	while true do
		local event, net_name = os.pullEvent("peripheral_detach");
		if event == "peripheral_detach" then
			send(textutils.serialiseJSON({ StorageRemoved = net_name }), false)
		end
	end
end
---@alias remote_item {ident:string,name:string,amount:integer,max_stack_size:integer,nbt_hash:integer?}


---@param ident string
---@param name string
---@param amount integer
---@param max_stack_size integer
---@param nbt_hash integer?
---@return remote_item
local function create_item(ident, name, amount, max_stack_size, nbt_hash)
	return { ident = ident, name = name, amount = amount, max_stack_size = max_stack_size, nbt_hash = nbt_hash }
end

---@param item remote_item
---@param slot number
local function send_put_request(item, slot)
	send(textutils.serialiseJSON({
			InsertRequest = {
				ident = item.ident,
				name = item.name,
				amount = item.amount,
				nbt_hash = item.nbt_hash,
				max_stack_size = item.max_stack_size
			}
		}),
		false)
	local w = recv();
	if w == nil then
		connect_websocket()
		w = recv()
	end
	local packet = textutils.unserialiseJSON(w, { parse_empty_array = false });
	if packet ~= nil and packet.Insert ~= nil then
		local input = peripheral.wrap(input_net_names[1])
		for _, value in ipairs(packet.Insert) do
			local item = input.getItemDetail(slot)
			if item ~= nil then
				local amount = input.pushItems(value.storage, slot, value.amount, value.slot);
				send(textutils.serialiseJSON({
					ItemPushed = {
						storage = value.storage,
						slot = value.slot,
						item = create_item(item.name,
							item.displayName, amount, item.maxCount, item.nbt)
					}
				}))
			end
		end
	end
end

local item_display_list = {}

local input_invs = {}
for i, value in ipairs(input_net_names) do
	input_invs[i] = peripheral.wrap(value);
end

local function request_puts()
	local input = peripheral.wrap(input_net_names[1]);
	for slot, _ in pairs(input.list()) do
		local item = input.getItemDetail(slot)
		if item ~= nil then
			local item = create_item(item.name, item.displayName, item.count, item.maxCount, item.nbt)
			send_put_request(item, slot)
		end
	end
end

local function termination_handler()
	local e, w = os.pullEventRaw("terminate")

	remote_ws.close()
	error("handled")
	os.queueEvent(e, w)
	return
end

local function parallelize(fn)
	return function()
		while true do
			fn()
		end
	end
end
parallel.waitForAll(
	parallelize(request_puts),
	add_storage_on_attach,
	remove_storage_on_detach,
	termination_handler
)
