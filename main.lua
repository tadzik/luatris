function dump(o)
    if type(o) == 'table' then
    local s = '{ '
        for k,v in pairs(o) do
            if type(k) ~= 'number' then k = '"'..k..'"' end
                s = s .. '['..k..'] = ' .. dump(v) .. ','
            end
        return s .. '} '
    else
        return tostring(o)
    end
end

function deepcopy(t)
    if type(t) ~= 'table' then return t end
    local mt = getmetatable(t)
    local res = {}
    for k,v in pairs(t) do
        if type(v) == 'table' then
            v = deepcopy(v)
        end
        res[k] = v
    end
    setmetatable(res,mt)
    return res
end

--
-- our board
-- 0 -- empty
-- 1 -- steady piece
-- 2 -- moving piece
map         = {}
----------------- x  y
movingPiece  = nil
lastUpdate   = -1
lastSideMove = 0

-- various constants
piece_a  = 30
border_w = 2
margin   = 10
height   = 20
width    = 10
window_h = 640
window_w = 480

-- pieces
pieces = {
    -- pozycja,    d1,       d2,       d3
    { { 0, 0 }, { 1, 0 }, { 2, 0 }, {-1, 0 } }, -- I
    { { 0, 0 }, { 0,-1 }, { 1, 0 }, { 2, 0 } }, -- J
    { { 0, 0 }, {-2, 0 }, {-1, 0 }, { 0,-1 } }, -- L
    { { 0, 0 }, { 1, 0 }, {-1, 1 }, { 0, 1 } }, -- S
    { { 0, 0 }, {-1, 0 }, { 0, 1 }, { 1, 1 } }, -- Z
    { { 0, 0 }, { 0,-1 }, {-1, 0 }, { 1, 0 } }, -- T
    { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }, -- O
}

function pieceToCoords(p)
    n = { {}, {}, {}, {} }
    n[1] = p[1]
    for i = 2, 4 do
        n[i][1] = n[1][1] + p[i][1]
        n[i][2] = n[1][2] + p[i][2]
    end
    return n
end

function coordsToPix(x, y)
    x = piece_a * (x - 1) + margin
    y = (height - y) * piece_a + margin
    return x, y
end

function pickMovingPiece()
    local new = pieces[math.random(7)]
    new[1] = { 5, 19 }
    return new
end

function checkFull()
    local function isFull(row)
        full = true
        for j = 1, width do
            if row[j] == 0 then full = false end
        end
        return full
    end

    for i = 1, height do
        while isFull(map[i]) do
            for k = i, height - 1 do
                map[k] = map[k + 1]
            end
            map[height] = {}
            for n = 1, width do
                map[height][n] = 0
            end
        end
    end
end

function love.load()
    math.randomseed(os.time())
    -- initialize the board
    for i = 1, height do
        map[i] = {}
        for j = 1, width do
            map[i][j] = 0
        end
    end
    --
    love.graphics.setMode(window_w, window_h)
    love.graphics.setBackgroundColor(200, 200, 200)
    love.graphics.setColor(0, 0, 0)
    love.graphics.setLineWidth(border_w)
end

function updatePiece(what, how)
    local k = pieceToCoords(what)
    for i in pairs(k) do
        x = k[i][1]
        y = k[i][2]
        map[y][x] = how
    end
end

function rotatePiece()
    local function isLegal(piece, map)
        local possible = true
        for i in pairs(piece) do
            x = piece[i][1]
            y = piece[i][2]
            if x < 1 or x > width
            or y < 1 or y > height
            or map[y][x] > 0 then
                possible = false
            end
        end
        return possible
    end

    local rotated = { {}, {}, {}, {} }
    rotated[1] = movingPiece[1]
    for i = 2, 4 do
        rotated[i][1] = - movingPiece[i][2]
        rotated[i][2] =   movingPiece[i][1]
    end
    if isLegal(pieceToCoords(rotated), map) then
        movingPiece = rotated
    end
end

function movePiece(dx, dy)
    if not movingPiece then return end
    -- calculate new position of the moving piece
    local possible       = true
    local stops          = false
    local k = deepcopy(movingPiece)
    k[1][1] = k[1][1] + dx
    k[1][2] = k[1][2] + dy
    local c = pieceToCoords(k)
    for i in pairs(c) do
        x = c[i][1]
        y = c[i][2]
        if y < 1 or map[y][x] == 1 and dy ~= 0
        then
            stops = true
            break
        end
        if x < 1 or x > width or map[y][x] == 1 then
            possible = false
        end
    end
    
    if stops then
        updatePiece(movingPiece, 1)
        movingPiece = pickMovingPiece()
        updatePiece(movingPiece, 2)
        checkFull()
        return
    end

    if possible then
        updatePiece(movingPiece, 0)
        movingPiece = k
        updatePiece(movingPiece, 2)
    end
end

function love.update(dt)
    if love.timer.getTime() - lastUpdate >= 1
    or love.keyboard.isDown("down")
    then
        if movingPiece == nil then
            movingPiece = pickMovingPiece()
        else 
            movePiece(0, -1)
        end
        lastUpdate = love.timer.getTime()

        --debugPrint()
    end

    if love.timer.getMicroTime() - lastSideMove >= 0.07 then
        if love.keyboard.isDown("left") then
            movePiece(-1, 0)
            updatePiece(movingPiece, 2)
        elseif love.keyboard.isDown("right") then
            movePiece(1, 0)
            updatePiece(movingPiece, 2)
        end
        if love.keyboard.isDown("up") then
            updatePiece(movingPiece, 0)
            rotatePiece()
            updatePiece(movingPiece, 2)
        end
        lastSideMove = love.timer.getMicroTime()
    end
end

function debugPrint()
    print(tostring(table.getn(map)))
    io.write("------------\n")
    for i = 1, height do
        io.write("|")
        for j = 1, width do
            if map[i][j] > 0 then
                io.write("#")
            else
                io.write(" ")
            end
        end
        io.write("|\n")
    end
    io.write("------------\n")
end

function love.draw()
    -- border
    love.graphics.rectangle("line", margin, margin,
                            width * piece_a, height * piece_a)

    -- draw the map
    for i = 1, height do
        for j = 1, width do
            if map[i][j] > 0 then
                x, y = coordsToPix(j, i)
                love.graphics.rectangle("fill", x, y, piece_a, piece_a)
            end
        end
    end
end
