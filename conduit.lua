local function move_items(input, output)
	return function()
		local inv = peripheral.wrap(input)
		while true do
			for slot, _ in pairs(inv.list()) do
				print(slot)
				inv.pushItems(output, slot)
			end
			sleep(0)
		end
	end
end

parallel.waitForAny(move_items("minecraft:chest_19", "minecraft:dispenser_0"))
