rednet.open("left")
rednet.host("Farm1", "Sapling_Turtle1")
while true do
    local Block, information = turtle.inspect()
    if Block and information.tags and information.tags["minecraft:logs"] then
        rednet.broadcast("1", "Farm1")
        -- turtle.dig()
        -- turtle.drop()
    end
    if not Block then
        turtle.suckDown(1)
        turtle.place()
    end
end
