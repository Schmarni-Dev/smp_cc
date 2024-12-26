while true do
	turtle.suckUp(1)
	turtle.place()
	for i = 1, 27, 1 do
		turtle.suck()
		turtle.dropDown()
	end
	turtle.dig()
	turtle.turnLeft()
	turtle.drop()
	turtle.turnRight()
end
