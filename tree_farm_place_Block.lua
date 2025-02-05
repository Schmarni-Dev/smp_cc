rednet.open("left")
local function block_change()
    while true do
        local _, detail = rednet.receive("farm_block_detail1")
        print(detail)
        turtle.dig()
        if detail == "dirt" then
            turtle.select(1)
        end
        if detail == "nylium" then
            turtle.select(2)
        end
        turtle.place()
        rednet.broadcast("1", "farm_block_done1")
    end
end

local function bonemeal_netherrack()
    while true do
        local block, detail = turtle.inspect()
        if block and detail.name == "minecraft:netherrack" then
            redstone.setOutput("bottom", true)
            sleep(0)
            redstone.setOutput("bottom", false)
        end
        sleep(0)
    end
end
parallel.waitForAll(block_change, bonemeal_netherrack)
