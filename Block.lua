local Block = {}

Block.TILE_SIZE = 16
Block.ATLAS_WIDTH = 256
Block.ATLAS_HEIGHT = 256
Block.UV_SIZE_X = Block.TILE_SIZE / Block.ATLAS_WIDTH
Block.UV_SIZE_Y = Block.TILE_SIZE / Block.ATLAS_HEIGHT
-- Старое имя оставлено для совместимости, но новый код использует X/Y отдельно.
Block.UV_SIZE = Block.UV_SIZE_X

function Block.setAtlasSize(width, height)
    Block.ATLAS_WIDTH = width or Block.ATLAS_WIDTH
    Block.ATLAS_HEIGHT = height or Block.ATLAS_HEIGHT
    Block.UV_SIZE_X = Block.TILE_SIZE / Block.ATLAS_WIDTH
    Block.UV_SIZE_Y = Block.TILE_SIZE / Block.ATLAS_HEIGHT
    Block.UV_SIZE = Block.UV_SIZE_X
end

function Block.getUVSize()
    return Block.UV_SIZE_X, Block.UV_SIZE_Y
end

-- Реестр блоков
-- ID -> { name, transparent, uv = { top, side, bottom } }
Block.Types = {
    [0] = { name = "Воздух", transparent = true },
    [1] = { 
        name = "Трава", 
        transparent = false,
        texture = { top = "grass_top.png", side = "grass_side.png", bottom = "dirt.png" },
        uv = { top = {0, 0}, side = {1, 0}, bottom = {2, 0} } 
    },
    [2] = { 
        name = "Земля", 
        transparent = false,
        texture = { all = "dirt.png" },
        uv = { all = {2, 0} } 
    },
    [3] = { 
        name = "Камень", 
        transparent = false,
        texture = { all = "stone.png" },
        uv = { all = {3, 0} } 
    },
    [4] = { 
        name = "Дерево (Ствол)", 
        transparent = false,
        texture = { top = "log_oak_top.png", side = "log_oak.png", bottom = "log_oak_top.png" },
        uv = { top = {5, 0}, side = {4, 0}, bottom = {5, 0} } 
    },
    [5] = { 
        name = "Листья", 
        transparent = true,
        texture = { all = "leaves_oak.png" },
        uv = { all = {6, 0} } 
    },
    [6] = { 
        name = "Стекло", 
        transparent = true,
        texture = { all = "glass.png" },
        uv = { all = {7, 0} } 
    },
    [7] = { 
        name = "Доски", 
        transparent = false,
        texture = { all = "planks_oak.png" },
        uv = { all = {8, 0} } 
    },
    -- 8 = Факел.
    [8] = { 
        name = "Факел", 
        transparent = true,
        collidable = false,
        model = "torch",
        texture = { all = "torch_on.png" },
        uv = { all = {9, 0} },
        emissive = true,
        light_level = 14
    },
}

function Block.getUV(id, face_type)
    local b = Block.Types[id]
    if not b or id == 0 then return 0, 0 end
    
    local uv = b.uv[face_type] or b.uv.all or {0,0}
    return uv[1] * Block.UV_SIZE_X, uv[2] * Block.UV_SIZE_Y
end

function Block.isTransparent(id)
    local b = Block.Types[id]
    if not b then return true end
    return b.transparent == true
end

function Block.isCollidable(id)
    local b = Block.Types[id]
    if not b or id == 0 then return false end
    if b.collidable ~= nil then return b.collidable == true end
    return true
end

function Block.getModel(id)
    local b = Block.Types[id]
    if not b then return "cube" end
    return b.model or "cube"
end

function Block.isEmissive(id)
    local b = Block.Types[id]
    if not b then return false end
    return b.emissive == true
end

function Block.getLightLevel(id)
    local b = Block.Types[id]
    if not b or not b.emissive then return 0 end
    return b.light_level or 0
end

function Block.getName(id)
    local b = Block.Types[id]
    if not b then return "Неизвестно" end
    return b.name
end

return Block
