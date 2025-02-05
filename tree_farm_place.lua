rednet.open("left")
rednet.host("Farm1", "Sapling_Turtle1")
rednet.host("farm_block_detail1", "Sapling_Turtle1")
local last_item
while true do
    local Block, information = turtle.inspect()
    if Block and information.tags and information.tags["minecraft:logs"] then
        rednet.broadcast("1", "Farm1")
    end
    if not Block then
        turtle.suckDown(1)
        local detail = turtle.getItemDetail()
        if detail and detail.name ~= last_item then
            if detail.name == "minecraft:crimson_fungus" or detail.name == "minecraft:warped_fungus" then
                rednet.broadcast("nylium", "farm_block_detail1")
            else
                rednet.broadcast("dirt", "farm_block_detail1")
            end
            rednet.receive("farm_block_done1")
            last_item = detail.name
        end
        turtle.place()
    end
end
