local function setup_disk(side)
	---@type ccTweaked.peripherals.Drive
	---@diagnostic disable-next-line: assign-type-mismatch
	local drive = peripheral.wrap(side);
	local path = drive.getMountPath()
	if path == nil then
		printError("NON FS DISK!")
		return
	end
	print("handling disk")
	fs.delete(path .. "/startup.lua")
	fs.delete(path .. "/startup")
	fs.copy("_startup", path .. "/startup")
	drive.ejectDisk()
end

while true do
	local _, side = os.pullEvent("disk")
	setup_disk(side)
end
