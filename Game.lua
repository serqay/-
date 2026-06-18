local World = require("World")
local Camera = require("Camera")
local Render = require("Render")
local Physics = require("Physics")
local Block = require("Block")

local Game = {}

function Game.loadImageFrom(paths)
    for _, path in ipairs(paths) do
        local success, img = pcall(love.graphics.newImage, path)
        if success and img then
            img:setFilter("nearest", "nearest")
            return img, path
        end
    end
    return nil, nil
end

function Game.init()
    Render.init()
    
    -- Динамическая сборка атласа из отдельных картинок, если папка существует
    local use_dynamic_atlas = false
    local info = love.filesystem.getInfo("textures/blocks")
    if info and info.type == "directory" then
        use_dynamic_atlas = true
    end
    
    if use_dynamic_atlas then
        local uniqueTextures = {}
        local texMap = {}
        
        for id, b in pairs(Block.Types) do
            if b.texture then
                for k, tex in pairs(b.texture) do
                    if not texMap[tex] then
                        texMap[tex] = true
                        table.insert(uniqueTextures, tex)
                    end
                end
            end
        end
        
        -- Сначала узнаем размер тайла по первой картинке (по умолчанию 16)
        local tileSize = 16
        if #uniqueTextures > 0 then
            local success, firstImg = pcall(love.image.newImageData, "textures/blocks/" .. uniqueTextures[1])
            if success then
                tileSize = firstImg:getWidth()
            end
        end
        
        -- Сообщаем этот размер в Block.lua
        Block.TILE_SIZE = tileSize
        
        local atlasW = math.max(1, #uniqueTextures) * tileSize
        local atlasH = tileSize
        local atlasData = love.image.newImageData(atlasW, atlasH)
        
        for i, tex in ipairs(uniqueTextures) do
            local path = "textures/blocks/" .. tex
            local success, imgData = pcall(love.image.newImageData, path)
            if success then
                -- Если размер отличается (например, текстура меньше), масштабируем или вставляем как есть
                local w = math.min(tileSize, imgData:getWidth())
                local h = math.min(tileSize, imgData:getHeight())
                -- Для простоты берем кусок нужного размера (если вдруг текстура слишком большая)
                atlasData:paste(imgData, (i - 1) * tileSize, 0, 0, 0, w, h)
            else
                for x = 0, tileSize - 1 do
                    for y = 0, tileSize - 1 do
                        atlasData:setPixel((i - 1) * tileSize + x, y, 1, 0, 1, 1)
                    end
                end
            end
            texMap[tex] = (i - 1)
        end
        
        Game.texture = love.graphics.newImage(atlasData)
        Game.texture:setFilter("nearest", "nearest")
        Game.texture_path = "generated_from_textures"
        
        for id, b in pairs(Block.Types) do
            if b.texture then
                b.uv = {}
                for k, tex in pairs(b.texture) do
                    local x = texMap[tex]
                    b.uv[k] = {x, 0}
                end
            end
        end
    end
    
    if not Game.texture then
        -- Заглушка, если файл не найден
        local img_data = love.image.newImageData(16, 16)
        for x=0,15 do
            for y=0,15 do
                img_data:setPixel(x,y, 0.8, 0.4, 0.8, 1)
            end
        end
        Game.texture = love.graphics.newImage(img_data)
        Game.texture:setFilter("nearest", "nearest")
        Game.texture_path = "fallback"
    end
    
    -- Новый GUI/HUD/иконки/инвентарь из добавленных текстур 1122.
    Game.gui_texture, Game.gui_path = Game.loadImageFrom({
        "1122Gui.png",
        "assets/1122Gui.png",
        "assets/gui/1122Gui.png",
    })
    Game.icons_texture, Game.icons_path = Game.loadImageFrom({
        "ico1122.png",
        "assets/ico1122.png",
        "assets/gui/ico1122.png",
    })
    Game.inventory_texture, Game.inventory_path = Game.loadImageFrom({
        "inventory1122.png",
        "assets/inventory1122.png",
        "assets/gui/inventory1122.png",
    })
    
    -- Сообщаем реестру блоков реальный размер нового атласа (1024x512),
    -- чтобы UV 16x16-тайлов считались правильно не только для любых 256x256 атласов.
    if Game.texture and Block.setAtlasSize then
        Block.setAtlasSize(Game.texture:getWidth(), Game.texture:getHeight())
    end
    
    -- Бесконечный мир с рандомным seed. render_distance = радиус чанков вокруг игрока.
    local spawnX, spawnZ = 8, 8
    Game.world = World.new()
    Game.world:generateArea(2, spawnX, spawnZ)
    
    -- Инициализируем камеру
    Game.camera = Camera.new()
    
    -- Инициализируем игрока
    Game.player = {
        pos = {x = spawnX, y = 15, z = spawnZ}, -- Исходная позиция
        vel = {x = 0, y = 0, z = 0},
        size = {w = 0.6, h = 1.8, d = 0.6}, -- Реалистичные габариты Стива
        on_ground = false,
        flying = false -- Начинаем с выключенным полетом (работает физика)
    }
    
    Game.time = math.pi / 2.5 -- Старт суточного цикла (утро/полдень, светло и красиво!)
    
    -- Ставим игрока ровно на поверхность ландшафта, чтобы не провалиться
    local spawnBlockX = math.floor(spawnX) + 1
    local spawnBlockZ = math.floor(spawnZ) + 1
    for y = Game.world.height, 1, -1 do
        if Game.world:getBlock(spawnBlockX, y, spawnBlockZ) ~= 0 then
            Game.player.pos.y = y + 0.1
            break
        end
    end
    
    Game.camera.pos.x = Game.player.pos.x
    Game.camera.pos.y = Game.player.pos.y + 1.62
    Game.camera.pos.z = Game.player.pos.z
    
    Game.mode = "survival"
    Game.spawn = {x = spawnX, y = Game.player.pos.y, z = spawnZ}
    Game.player.max_health = 20
    Game.player.health = Game.player.max_health
    Game.player.invuln_timer = 0
    Game.player.fall_start_y = Game.player.pos.y
    Game.dead = false
    Game.death_timer = 0
    
    Game.hotbar = {1, 2, 3, 4, 5, 6, 7, 8}
    -- Стартовый survival-инвентарь. Остальные блоки добываются копанием.
    Game.inventory = {
        [1] = 0,
        [2] = 0,
        [3] = 0,
        [4] = 0,
        [5] = 0,
        [6] = 0,
        [7] = 16,
        [8] = 8,
    }
    Game.selected_slot = 1
    Game.selected_block = Game.hotbar[Game.selected_slot]
    Game.inventory_open = false
    Game.keys = {}
    Game.mx, Game.my = 0, 0
    Game.target = {hit = false}
end

function Game.update(dt)
    -- 1. Обновляем время суток (медленный суточный цикл день/закат/ночь/рассвет)
    Game.time = (Game.time + dt * 0.015) % (2 * math.pi)

    -- Таймеры survival-режима
    if Game.player.invuln_timer and Game.player.invuln_timer > 0 then
        Game.player.invuln_timer = math.max(0, Game.player.invuln_timer - dt)
    end
    
    if Game.dead then
        Game.death_timer = Game.death_timer + dt
        if Game.death_timer > 2.0 then
            Game.respawn()
        end
        return
    end

    -- 2. Обновляем направление взгляда камеры (вращение)
    Game.camera:update(Game.mx, Game.my)
    Game.mx, Game.my = 0, 0 -- Сбрасываем относительное смещение мыши
    
    -- 3. Подгружаем бесконечные чанки вокруг игрока перед физикой
    Game.world:updateLoadedChunks(Game.player.pos.x, Game.player.pos.z)
    
    -- 4. Обновляем физику и коллизии игрока
    local was_on_ground = Game.player.on_ground
    Physics.update(Game.player, Game.world, dt, Game.keys, Game.camera)
    Game.updateSurvival(dt, was_on_ground)
    
    -- 5. Если игрок за кадр перешел в новый чанк — сразу подгружаем окружение еще раз
    Game.world:updateLoadedChunks(Game.player.pos.x, Game.player.pos.z)
    
    -- 6. Выполняем трассировку луча (Raycast) из камеры для выделения блоков
    local origin = {
        x = Game.camera.pos.x,
        y = Game.camera.pos.y,
        z = Game.camera.pos.z
    }
    local dir = Game.camera:getForwardVector()
    Game.target = Game.world:raycast(origin, dir, 5.0) -- Дистанция взаимодействия - 5 блоков
end

function Game.getDrop(block_id)
    -- В survival травяной блок дает землю, остальное падает самим собой.
    if block_id == 1 then return 2 end
    if block_id == 0 then return nil end
    return block_id
end

function Game.addItem(block_id, count)
    if not block_id then return end
    count = count or 1
    Game.inventory[block_id] = (Game.inventory[block_id] or 0) + count
end

function Game.damage(amount)
    if Game.dead then return end
    if Game.player.invuln_timer and Game.player.invuln_timer > 0 then return end
    
    Game.player.health = math.max(0, Game.player.health - amount)
    Game.player.invuln_timer = 0.8
    
    if Game.player.health <= 0 then
        Game.dead = true
        Game.death_timer = 0
        Game.player.vel.x, Game.player.vel.y, Game.player.vel.z = 0, 0, 0
    end
end

function Game.respawn()
    Game.dead = false
    Game.death_timer = 0
    Game.player.health = Game.player.max_health
    Game.player.invuln_timer = 1.0
    Game.player.vel.x, Game.player.vel.y, Game.player.vel.z = 0, 0, 0
    Game.player.pos.x = Game.spawn.x
    Game.player.pos.y = Game.spawn.y
    Game.player.pos.z = Game.spawn.z
    Game.player.fall_start_y = Game.player.pos.y
    Game.world:updateLoadedChunks(Game.player.pos.x, Game.player.pos.z)
    Game.camera.pos.x = Game.player.pos.x
    Game.camera.pos.y = Game.player.pos.y + 1.62
    Game.camera.pos.z = Game.player.pos.z
end

function Game.updateSurvival(dt, was_on_ground)
    if Game.player.flying then
        Game.player.fall_start_y = Game.player.pos.y
        return
    end
    
    if not Game.player.on_ground then
        Game.player.fall_start_y = math.max(Game.player.fall_start_y or Game.player.pos.y, Game.player.pos.y)
    elseif not was_on_ground and Game.player.on_ground then
        local fall_distance = (Game.player.fall_start_y or Game.player.pos.y) - Game.player.pos.y
        if fall_distance > 3.0 then
            -- 2 HP = 1 сердце. Падение с 4 блоков снимает примерно полсердца/сердце.
            local damage = math.max(1, math.floor((fall_distance - 3.0) * 2 + 0.5))
            Game.damage(damage)
        end
        Game.player.fall_start_y = Game.player.pos.y
    else
        Game.player.fall_start_y = Game.player.pos.y
    end
end

function Game.draw()
    Render.draw(Game.world, Game.camera, Game.texture, Game.gui_texture, Game.icons_texture, Game.inventory_texture, Game.target, Game.player, Game.selected_block, Game.time, Game.hotbar, Game.inventory, Game.mode, Game.dead, Game.inventory_open)
end

function Game.keypressed(key)
    if key == "r" and Game.dead then
        Game.respawn()
        return
    end
    
    -- Инвентарь на E.
    if key == "e" then
        Game.inventory_open = not Game.inventory_open
        return
    end
    
    -- Переключение режимов полета оставлено как debug-кнопка.
    if key == "f" then
        Game.player.flying = not Game.player.flying
        Game.player.vel.y = 0 -- Сбрасываем вертикальную скорость при переключении
    end
    
    -- Быстрый выбор блока на клавиши 1-8. 9-й слот специально пустой.
    local slot = tonumber(key)
    if slot and Game.hotbar and Game.hotbar[slot] then
        Game.selected_slot = slot
        Game.selected_block = Game.hotbar[slot]
    end
end

function Game.selectSlot(slot)
    if not Game.hotbar or not Game.hotbar[slot] then return end
    Game.selected_slot = slot
    Game.selected_block = Game.hotbar[slot]
end

function Game.wheelmoved(x, y)
    if not Game.hotbar then return end
    if y > 0 then
        Game.selectSlot((Game.selected_slot - 2) % #Game.hotbar + 1)
    elseif y < 0 then
        Game.selectSlot(Game.selected_slot % #Game.hotbar + 1)
    end
end

function Game.mousepressed(x, y, button)
    if Game.dead then return end
    
    if button == 1 then
        -- ЛКМ: Сломать блок и добавить дроп в survival-инвентарь
        if Game.target and Game.target.hit then
            local broken_id = Game.world:getBlock(Game.target.bx, Game.target.by, Game.target.bz)
            if broken_id and broken_id ~= 0 then
                Game.world:setBlock(Game.target.bx, Game.target.by, Game.target.bz, 0)
                Game.addItem(Game.getDrop(broken_id), 1)
            end
        end
    elseif button == 2 then
        -- ПКМ: Поставить блок
        if Game.target and Game.target.hit then
            local px = Game.target.bx + Game.target.normal.x
            local py = Game.target.by + Game.target.normal.y
            local pz = Game.target.bz + Game.target.normal.z
            
            -- Проверка, чтобы не поставить блок внутри игрока
            local b_minX, b_maxX = px - 1, px
            local b_minY, b_maxY = py - 1, py
            local b_minZ, b_maxZ = pz - 1, pz
            
            local p_minX = Game.player.pos.x - Game.player.size.w / 2
            local p_maxX = Game.player.pos.x + Game.player.size.w / 2
            local p_minY = Game.player.pos.y
            local p_maxY = Game.player.pos.y + Game.player.size.h
            local p_minZ = Game.player.pos.z - Game.player.size.d / 2
            local p_maxZ = Game.player.pos.z + Game.player.size.d / 2
            
            local collides = p_maxX > b_minX and p_minX < b_maxX and
                             p_maxY > b_minY and p_minY < b_maxY and
                             p_maxZ > b_minZ and p_minZ < b_maxZ
                             
            if not collides then
                local count = Game.inventory[Game.selected_block] or 0
                if count > 0 then
                    if Game.world:setBlock(px, py, pz, Game.selected_block) then
                        Game.inventory[Game.selected_block] = count - 1
                    end
                end
            end
        end
    end
end

return Game
