rednet.open("left")
local distance = 19
local z_upper = -395
local z_lower = z_upper - distance
local function wait()
    rednet.receive("Farm1")
end

local function safe_dig_condition(inspect_fn)
    local Block, information = inspect_fn()
    return Block and information.name ~= "computercraft:turtle_advanced" and information.name ~= "minecraft:dispenser" and information.name ~= "minecraft:barrel"
end
local function move()
    local _, _, z = gps.locate(20000000000, false)
    if z == z_lower or z == z_upper then
        if safe_dig_condition(turtle.inspect) then
            turtle.dig()
        end
        turtle.forward()
        print("turbo start!")
    end
    _, _, z = gps.locate(20000000000, false)
    while z > z_lower and z < z_upper do
        if safe_dig_condition(turtle.inspectDown) then
            turtle.digDown()
        end
        turtle.dig()
        turtle.digUp()
        turtle.forward()
        _, _, z = gps.locate(20000000000, false)
    end
end
local function dropDown()
    while true do
        turtle.suckUp()
        turtle.dropDown()
        coroutine.yield()
    end
end
local function init_condition()
    local block, info = turtle.inspect()
    return block and (info.name == "minecraft:polished_diorite" or info.name == "minecraft:barrel")
end
local function init()
    sleep(10)
    local _, _, z = gps.locate(20000000000, false)
    if not (z == z_lower or z == z_upper) then
        move()
    else
        while not init_condition() do
            turtle.turnRight()
        end
        turtle.turnRight()
        turtle.turnRight()
    end
end

init()
while true do
    if turtle.getFuelLevel() < 100 then
        turtle.turnRight()
        turtle.turnRight()
        turtle.suck()
        turtle.refuel()
        turtle.turnRight()
        turtle.turnRight()
    end
    parallel.waitForAny(wait, dropDown)
    move()
    turtle.turnRight()
    turtle.turnRight()
    move()
    turtle.turnRight()
    turtle.turnRight()
    for i = 1, 16, 1 do
        turtle.select(i)
        turtle.dropDown()
    end
end
