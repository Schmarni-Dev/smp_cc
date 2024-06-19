---@type ccTweaked.http.Websocket | nil
local remote_ws = nil;
local is_waiting_for_ws = true;
local search_str = "";
local should_redraw = true;
local should_refresh_item_list = false;
local curr_state = "main";
local function request_redraw_and_list()
	should_redraw = true;
	should_refresh_item_list = true
end
local connect_websocket = function()
	error("connect_websocket called to early")
end
---@param perph ccTweaked.peripherals.Inventory
local function ProtoStorage_from_peripherial(perph)
	local items = {}
	for i = 1, 27, 1 do
		items[i] = "None";
	end
	local fns = {}
	for slot, _ in pairs(perph.list()) do
		fns[#fns + 1] = function()
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
	end
	parallel.waitForAll(table.unpack(fns))
	return { net_name = peripheral.getName(perph), items = items }
end

local function send(data, bin)
	if remote_ws ~= nil then
		local success, msg = pcall(remote_ws.send, data, bin)
		if not success then
			connect_websocket();
			send(data, bin)
		end
	else
		error("ws is nil")
	end
end

local function sync_storages_with_remote()
	local fns = {}
	local barrels = { SyncStorages = {} }
	for _, value in ipairs(peripheral.getNames()) do
		if string.match(value, "minecraft:barrel") then
			fns[#fns + 1] = function()
				---@diagnostic disable-next-line: param-type-mismatch
				table.insert(barrels.SyncStorages, ProtoStorage_from_peripherial(peripheral.wrap(value)));
			end
		end
	end
	parallel.waitForAll(table.unpack(fns))
	if barrels.SyncStorages == {} then
		barrels.SyncStorages = textutils.empty_json_array;
	end
	local str = textutils.serialiseJSON(barrels);
	send(str, false)
	should_refresh_item_list = true
end

local function __inner_connect_websocket()
	local ws, msg = http.websocket("ws://localhost:6969/storage_computer_ws")
	if ws == false then
		error(msg);
		sleep(30);
		return __inner_connect_websocket()
	end
	return ws
end
connect_websocket = function()
	is_waiting_for_ws = true;
	should_redraw = true;
	if remote_ws ~= nil then
		pcall(remote_ws.close);
	end
	local ws = __inner_connect_websocket()
	is_waiting_for_ws = false;
	should_redraw = true;
	remote_ws = ws
	sync_storages_with_remote()
end
connect_websocket();

local function recv(timeout)
	local success, result, is_bin = pcall(remote_ws.receive, timeout)
	if not success then
		connect_websocket();
		success, result, is_bin = pcall(remote_ws.receive, timeout)
	end
	return result, is_bin
end


local function request_list(filter)
	send(textutils.serialiseJSON({ ListWithFilter = filter or textutils.json_null }), false)
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
	return { ident, name, amount, max_stack_size, nbt_hash }
end

local function handle_list_refresh_requests()
	if should_refresh_item_list then
		---@type string | nil
		local reqst = search_str;
		if reqst == "" then
			reqst = nil
		end
		request_list(reqst)
		should_refresh_item_list = false
		should_redraw = true
	end
	sleep(0)
end

---@param item {ident:string,amount:integer,nbt_hash?: string}
local function send_pull_request(item)
	send(textutils.serialiseJSON({
			PullRequest = {
				ident = item.ident,
				amount = item.amount,
				nbt_hash = item.nbt_hash
			}
		}),
		false)
end
---@param item remote_item
local function send_put_request(item)
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
end

local item_display_list = {}

local function handle_remote_msgs()
	local msg, is_bin = recv()
	if is_bin then
		error("ws message is binary");
		return
	end
	if msg == nil then
		connect_websocket();
		error("msg is nil")
		return
	end
	local packet = textutils.unserialiseJSON(msg, { parse_empty_array = false })
	if packet == nil then
		error("unable to parse json payload: " .. msg)
		return
	end
	if packet.DisplayList ~= nil then
		item_display_list = packet.DisplayList or {};
		should_redraw = true
	end
end

local function handle_char_input()
	---@type ccTweaked.os.event, string
	local event, char = os.pullEvent("char");
	search_str = search_str .. char
	request_redraw_and_list()
end
local coursor_height = 1;
local offset = 0
local function handle_key_input()
	---@type ccTweaked.os.event, integer
	local event, key = os.pullEvent("key");
	if key == keys.backspace and curr_state == "main" then
		if search_str == "" then
			return
		end
		search_str = search_str;
		search_str = string.sub(search_str, 1, string.len(search_str) - 1);
		request_redraw_and_list()
	end
	if key == keys.delete and curr_state == "main" then
		if search_str == "" then
			return
		end
		search_str = "";
		request_redraw_and_list()
	end
	if key == keys.up and curr_state == "main" then
		coursor_height = coursor_height - 1
		should_redraw = true
	end
	if key == keys.down and curr_state == "main" then
		coursor_height = coursor_height + 1
		should_redraw = true
	end
	if key == keys["return"] and curr_state == "main" then
		local item = item_display_list[coursor_height + offset];
		item.amount = 3
		send_put_request(item)
		-- error(textutils.serialise(item))
	end
end
local function DrawMainTui()
	if not should_redraw then
		os.sleep(0);
		return
	end
	local width, height = term.getSize()
	term.setCursorBlink(false);
	term.clear();
	term.setCursorPos(1, 1)
	term.setBackgroundColor(colors.black);
	should_redraw = false
	local printed_search_str = "search: " .. search_str;
	print(printed_search_str);
	local divider = ""
	for _ = 1, width, 1 do
		divider = divider .. "=";
	end
	if coursor_height > height - 3 then
		coursor_height = height - 3
		offset = offset + 1;
	end
	if coursor_height < 1 then
		offset = offset - 1;
		coursor_height = 1
	end
	offset = math.min(offset, #item_display_list - height + 3)
	offset = math.max(offset, 0)
	print(divider)
	for i = 1, height - 3, 1 do
		local item = item_display_list[i + offset];
		-- print(i)
		if i == coursor_height then
			term.setBackgroundColor(colors.magenta);
		elseif ((i + offset) % 2) == 0 then
			term.setBackgroundColor(colors.gray);
		else
			term.setBackgroundColor(colors.black);
		end
		if item ~= nil then
			local final_str = item.name
			local amoumt_str = "" .. item.amount
			for _ = 1, width - (string.len(final_str) + string.len(amoumt_str)), 1 do
				final_str = final_str .. " "
			end
			print(final_str .. amoumt_str)
		end
	end
	term.setBackgroundColor(colors.black);
	term.setCursorPos(string.len(printed_search_str) + 1, 1)
	term.setCursorBlink(true);
	os.sleep(0);
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
remote_ws.close()
parallel.waitForAll(
	parallelize(DrawMainTui),
	parallelize(handle_char_input),
	parallelize(handle_key_input),
	parallelize(handle_remote_msgs),
	parallelize(handle_list_refresh_requests),
	add_storage_on_attach,
	remove_storage_on_detach,
	termination_handler
)
