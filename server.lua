
local RSGCore = exports['rsg-core']:GetCoreObject()
local activeGames = {}
local gameIdCounter = 0

local PIECE_VALUES = {
    pawn = 1, knight = 3, bishop = 3, rook = 5, queen = 9, king = 100
}

local function deepCopyBoard(board)
    local newBoard = {}
    for i = 1, 64 do
        if board[i] then
            newBoard[i] = {type = board[i].type, color = board[i].color, moved = board[i].moved}
        end
    end
    return newBoard
end

local function createGame(location, player1, isAI, difficulty)
    gameIdCounter = gameIdCounter + 1
    activeGames[gameIdCounter] = {
        id = gameIdCounter,
        location = location,
        players = {white = player1, black = isAI and 'AI' or nil},
        board = initializeBoard(),
        currentTurn = 'white',
        gameState = isAI and 'active' or 'waiting',
        moves = {},
        capturedPieces = {white = {}, black = {}},
        check = false,
        checkmate = false,
        stalemate = false,
        startTime = isAI and os.time() or nil,
        isAI = isAI or false,
        difficulty = difficulty or 'medium',
        lastMove = nil,
        enPassantTarget = nil
    }
    return gameIdCounter
end

function initializeBoard()
    local board = {}
    for i = 1, 64 do board[i] = nil end
    
    board[1] = {type='rook', color='black', moved=false}
    board[2] = {type='knight', color='black', moved=false}
    board[3] = {type='bishop', color='black', moved=false}
    board[4] = {type='queen', color='black', moved=false}
    board[5] = {type='king', color='black', moved=false}
    board[6] = {type='bishop', color='black', moved=false}
    board[7] = {type='knight', color='black', moved=false}
    board[8] = {type='rook', color='black', moved=false}
    for i = 9, 16 do board[i] = {type='pawn', color='black', moved=false} end
    
    for i = 49, 56 do board[i] = {type='pawn', color='white', moved=false} end
    board[57] = {type='rook', color='white', moved=false}
    board[58] = {type='knight', color = 'white', moved=false}
    board[59] = {type='bishop', color='white', moved=false}
    board[60] = {type='queen', color='white', moved=false}
    board[61] = {type='king', color='white', moved=false}
    board[62] = {type='bishop', color='white', moved=false}
    board[63] = {type='knight', color='white', moved=false}
    board[64] = {type='rook', color='white', moved=false}
    
    return board
end

-- #region Utility Functions (FIXED)
local function posToIndex(pos)
    if not pos or #pos < 2 then return nil end
    local file = string.byte(pos:sub(1,1)) - 96
    local rank = tonumber(pos:sub(2,2))
    if not file or not rank or file < 1 or file > 8 or rank < 1 or rank > 8 then return nil end
    return (9 - rank) * 8 - 8 + file
end

local function indexToPos(index)
    if not index or index < 1 or index > 64 then return nil end
    local rank = 9 - math.ceil(index / 8)
    local file = ((index - 1) % 8) + 1
    return string.char(96 + file) .. rank
end

local function getFileRank(pos)
    if not pos or #pos < 2 then return 0, 0 end
    local file = string.byte(pos:sub(1,1)) - 96
    local rank = tonumber(pos:sub(2,2))
    return file, rank
end

local function isPathClear(board, fromFile, fromRank, toFile, toRank)
    local fileStep = (toFile > fromFile and 1) or (toFile < fromFile and -1) or 0
    local rankStep = (toRank > fromRank and 1) or (toRank < fromRank and -1) or 0
    local currentFile, currentRank = fromFile + fileStep, fromRank + rankStep
    while currentFile ~= toFile or currentRank ~= toRank do
        local pos = string.char(96 + currentFile) .. currentRank
        if board[posToIndex(pos)] then return false end
        currentFile, currentRank = currentFile + fileStep, currentRank + rankStep
    end
    return true
end

local function findKing(board, color)
    for i = 1, 64 do
        local piece = board[i]
        if piece and piece.type == 'king' and piece.color == color then return indexToPos(i) end
    end
    return nil
end
-- #endregion

-- #region Core Chess Logic (Unchanged from previous version)
local function isValidMove(game, from, to, piece)
    local fromIdx, toIdx = posToIndex(from), posToIndex(to)
    if not fromIdx or not toIdx or from == to then return false end
    
    local board = game.board
    if not piece or piece.color ~= game.currentTurn then return false end
    
    local destPiece = board[toIdx]
    if destPiece and destPiece.color == piece.color then return false end
    
    local fromFile, fromRank = getFileRank(from)
    local toFile, toRank = getFileRank(to)
    local fileDiff, rankDiff = math.abs(toFile - fromFile), math.abs(toRank - fromRank)
    
    if piece.type == 'pawn' then
        local direction = (piece.color == 'white') and 1 or -1
        local startRank = (piece.color == 'white') and 2 or 7
        
        if toFile == fromFile and not destPiece and toRank == fromRank + direction then return true end
        if toFile == fromFile and not destPiece and fromRank == startRank and toRank == fromRank + (2 * direction) then
            local middlePos = string.char(96 + fromFile) .. (fromRank + direction)
            return not board[posToIndex(middlePos)]
        end
        if fileDiff == 1 and toRank == fromRank + direction and destPiece and destPiece.color ~= piece.color then return true end
        if fileDiff == 1 and toRank == fromRank + direction and to == game.enPassantTarget then return true end
        
        return false
        
    elseif piece.type == 'knight' then
        return (fileDiff == 2 and rankDiff == 1) or (fileDiff == 1 and rankDiff == 2)
        
    elseif piece.type == 'bishop' then
        return fileDiff == rankDiff and isPathClear(board, fromFile, fromRank, toFile, toRank)
        
    elseif piece.type == 'rook' then
        return (fileDiff == 0 or rankDiff == 0) and isPathClear(board, fromFile, fromRank, toFile, toRank)
        
    elseif piece.type == 'queen' then
        return (fileDiff == 0 or rankDiff == 0 or fileDiff == rankDiff) and isPathClear(board, fromFile, fromRank, toFile, toRank)
        
    elseif piece.type == 'king' then
        if fileDiff <= 1 and rankDiff <= 1 then return true end
        
        if not piece.moved and fileDiff == 2 and rankDiff == 0 and fromRank == (piece.color == 'white' and 1 or 8) then
            if isKingInCheck(game, piece.color) then return false end

            local rookFile = (toFile > fromFile) and 8 or 1
            local rookPos = string.char(96 + rookFile) .. fromRank
            local rook = board[posToIndex(rookPos)]
            if not rook or rook.type ~= 'rook' or rook.moved then return false end
            
            local pathClearToFile = (toFile > fromFile) and rookFile - 1 or rookFile + 1
            if not isPathClear(board, fromFile, fromRank, pathClearToFile, fromRank) then return false end

            local opponentColor = (piece.color == 'white') and 'black' or 'white'
            local passingFile = fromFile + ((toFile > fromFile) and 1 or -1)
            local passingPos = string.char(96 + passingFile) .. fromRank
            if isSquareUnderAttack(game, passingPos, opponentColor) then return false end
            
            return true
        end
    end
    
    return false
end

function isSquareUnderAttack(game, square, byColor)
    local board = game.board
    local targetIdx = posToIndex(square)
    if not targetIdx then return false end
    local targetFile, targetRank = getFileRank(square)

    local pawnDir = byColor == 'white' and -1 or 1
    for _, fileOffset in ipairs({-1, 1}) do
        local checkFile, checkRank = targetFile + fileOffset, targetRank + pawnDir
        if checkFile >= 1 and checkFile <= 8 and checkRank >= 1 and checkRank <= 8 then
            local p = board[posToIndex(string.char(96+checkFile) .. checkRank)]
            if p and p.type == 'pawn' and p.color == byColor then return true end
        end
    end

    local knightMoves = {{1,2}, {1,-2}, {-1,2}, {-1,-2}, {2,1}, {2,-1}, {-2,1}, {-2,-1}}
    for _, move in ipairs(knightMoves) do
        local checkFile, checkRank = targetFile + move[1], targetRank + move[2]
        if checkFile >= 1 and checkFile <= 8 and checkRank >= 1 and checkRank <= 8 then
            local p = board[posToIndex(string.char(96+checkFile) .. checkRank)]
            if p and p.type == 'knight' and p.color == byColor then return true end
        end
    end

    local directions = {rook = {{1,0}, {-1,0}, {0,1}, {0,-1}}, bishop = {{1,1}, {1,-1}, {-1,1}, {-1,-1}}}
    for _, dir in ipairs(directions.rook) do
        for i = 1, 7 do
            local checkFile, checkRank = targetFile + dir[1]*i, targetRank + dir[2]*i
            if checkFile < 1 or checkFile > 8 or checkRank < 1 or checkRank > 8 then break end
            local p = board[posToIndex(string.char(96+checkFile) .. checkRank)]
            if p then
                if p.color == byColor and (p.type == 'rook' or p.type == 'queen') then return true end
                break
            end
        end
    end
    for _, dir in ipairs(directions.bishop) do
        for i = 1, 7 do
            local checkFile, checkRank = targetFile + dir[1]*i, targetRank + dir[2]*i
            if checkFile < 1 or checkFile > 8 or checkRank < 1 or checkRank > 8 then break end
            local p = board[posToIndex(string.char(96+checkFile) .. checkRank)]
            if p then
                if p.color == byColor and (p.type == 'bishop' or p.type == 'queen') then return true end
                break
            end
        end
    end

    for df = -1, 1 do
        for dr = -1, 1 do
            if df ~= 0 or dr ~= 0 then
                local checkFile, checkRank = targetFile + df, targetRank + dr
                if checkFile >= 1 and checkFile <= 8 and checkRank >= 1 and checkRank <= 8 then
                    local p = board[posToIndex(string.char(96+checkFile) .. checkRank)]
                    if p and p.type == 'king' and p.color == byColor then return true end
                end
            end
        end
    end

    return false
end

function isKingInCheck(game, color)
    local kingPos = findKing(game.board, color)
    if not kingPos then return true end
    local opponentColor = color == 'white' and 'black' or 'white'
    return isSquareUnderAttack(game, kingPos, opponentColor)
end

function getAllLegalMoves(game)
    local moves = {}
    local color = game.currentTurn
    
    for fromIdx = 1, 64 do
        local piece = game.board[fromIdx]
        if piece and piece.color == color then
            local from = indexToPos(fromIdx)
            for toIdx = 1, 64 do
                local to = indexToPos(toIdx)
                if isValidMove(game, from, to, piece) then
                    local tempBoard = deepCopyBoard(game.board)
                    local tempToIdx = posToIndex(to)
                    local tempFromIdx = posToIndex(from)
                    tempBoard[tempToIdx] = tempBoard[tempFromIdx]
                    tempBoard[tempFromIdx] = nil
                    
                    local tempGame = { board = tempBoard }
                    if not isKingInCheck(tempGame, color) then
                        table.insert(moves, {from = from, to = to, piece = piece, capture = game.board[toIdx]})
                    end
                end
            end
        end
    end
    return moves
end

function hasLegalMoves(game)
    return #getAllLegalMoves(game) > 0
end
-- #endregion

-- #region AI Logic (Unchanged)
local function evaluateBoard(board, color)
    local score = 0
    for i = 1, 64 do
        local piece = board[i]
        if piece then
            local value = PIECE_VALUES[piece.type] or 0
            if piece.color == color then score = score + value else score = score - value end
        end
    end
    return score
end

local function getAIMove(game)
    local moves = getAllLegalMoves(game)
    if #moves == 0 then return nil end
    
    if game.difficulty == 'easy' then
        return moves[math.random(#moves)]
    elseif game.difficulty == 'medium' then
        local bestMoves, bestScore = {}, -9999
        for _, move in ipairs(moves) do
            local score = 0
            if move.capture then score = score + (PIECE_VALUES[move.capture.type] or 0) end
            if score > bestScore then
                bestScore, bestMoves = score, {move}
            elseif score == bestScore then
                table.insert(bestMoves, move)
            end
        end
        return bestMoves[math.random(#bestMoves)]
    elseif game.difficulty == 'hard' then
        local bestMove, bestScore = nil, -9999
        for _, move in ipairs(moves) do
            local tempBoard = deepCopyBoard(game.board)
            tempBoard[posToIndex(move.to)] = tempBoard[posToIndex(move.from)]
            tempBoard[posToIndex(move.from)] = nil
            
            local score = evaluateBoard(tempBoard, 'black')
            if isKingInCheck({board = tempBoard}, 'white') then score = score + 3 end

            if score > bestScore then
                bestScore, bestMove = score, move
            end
        end
        return bestMove or moves[math.random(#moves)]
    end
    return moves[math.random(#moves)]
end
-- #endregion

-- #region Game Flow & Events (FIXED)
local function executeMove(game, moveData)
    local from, to = moveData.from, moveData.to
    local fromIdx, toIdx = posToIndex(from), posToIndex(to)
    local piece = game.board[fromIdx]
    if not piece then return end -- Failsafe
    
    local playerColor = piece.color
    local fromFile, fromRank = getFileRank(from)
    local toFile, toRank = getFileRank(to)

    -- Handle En Passant capture
    local capturedPiece = game.board[toIdx]
    if piece.type == 'pawn' and to == game.enPassantTarget and not capturedPiece then
        -- The pawn to be captured is behind the target square
        local capturedPawnIdx = toIdx + (playerColor == 'white' and 8 or -8) -- With a8=1, white moves to lower index, black to higher
        capturedPiece = game.board[capturedPawnIdx]
        game.board[capturedPawnIdx] = nil
    end

    if capturedPiece then
        table.insert(game.capturedPieces[playerColor], capturedPiece)
    end
    
    -- Move the piece
    game.board[toIdx] = piece
    game.board[toIdx].moved = true
    game.board[fromIdx] = nil

    -- Handle Castling rook move
    if piece.type == 'king' and math.abs(fromFile - toFile) == 2 then
        local rookFromIdx, rookToIdx
        if toFile > fromFile then -- Kingside (g-file)
            rookFromIdx, rookToIdx = posToIndex('h'..fromRank), posToIndex('f'..fromRank)
        else -- Queenside (c-file)
            rookFromIdx, rookToIdx = posToIndex('a'..fromRank), posToIndex('d'..fromRank)
        end
        game.board[rookToIdx] = game.board[rookFromIdx]
        if game.board[rookToIdx] then
            game.board[rookToIdx].moved = true
        end
        game.board[rookFromIdx] = nil
    end
    
    -- Handle Pawn Promotion (Corrected)
    if piece.type == 'pawn' and (toRank == 8 or toRank == 1) then
        game.board[toIdx] = {type = 'queen', color = playerColor, moved = true}
    end
    
    -- Set En Passant target for the next turn (Corrected)
    if piece.type == 'pawn' and math.abs(fromRank - toRank) == 2 then
        local epRank = (playerColor == 'white') and fromRank + 1 or fromRank - 1
        game.enPassantTarget = string.char(96 + toFile) .. epRank
    else
        game.enPassantTarget = nil
    end
    
    game.currentTurn = (playerColor == 'white') and 'black' or 'white'
    game.lastMove = {from = from, to = to}
    game.check = isKingInCheck(game, game.currentTurn)
    table.insert(game.moves, {from = from, to = to, piece = piece.type, capture = capturedPiece ~= nil})
    return capturedPiece
end

local function checkGameOver(game)
    if not hasLegalMoves(game) then
        if game.check then
            game.checkmate, game.gameState = true, 'finished'
            local winner = game.currentTurn == 'white' and game.players.black or game.players.white
            local loser = game.currentTurn == 'white' and game.players.white or game.players.black
            
            if winner and winner ~= 'AI' then TriggerClientEvent('rsg-chess:client:gameEnd', winner, {result = 'win', reason = 'checkmate', isAI = game.isAI and loser == 'AI'}) end
            if loser then TriggerClientEvent('rsg-chess:client:gameEnd', loser, {result = 'loss', reason = 'checkmate', isAI = game.isAI and loser ~= 'AI'}) end
        else
            game.stalemate, game.gameState = true, 'finished'
            TriggerClientEvent('rsg-chess:client:gameEnd', game.players.white, {result = 'draw', reason = 'stalemate', isAI = game.isAI})
            if not game.isAI and game.players.black then
                TriggerClientEvent('rsg-chess:client:gameEnd', game.players.black, {result = 'draw', reason = 'stalemate'})
            end
        end
        return true
    end
    return false
end

local function makeAIMove(gameId)
    local game = activeGames[gameId]
    if not game or not game.isAI or game.currentTurn ~= 'black' then return end
    
    SetTimeout(1500 + math.random(1000), function()
        game = activeGames[gameId]
        if not game or game.gameState ~= 'active' then return end
        
        local aiMove = getAIMove(game)
        if not aiMove then return end
        
        executeMove(game, {from = aiMove.from, to = aiMove.to})
        
        if checkGameOver(game) then
            activeGames[gameId] = nil
            return
        end
        
        local moveData = {
            from = aiMove.from, to = aiMove.to, board = game.board,
            currentTurn = game.currentTurn, check = game.check,
            capturedPieces = game.capturedPieces, aiMove = true
        }
        TriggerClientEvent('rsg-chess:client:updateGame', game.players.white, moveData)
        
        if game.check then
            TriggerClientEvent('ox_lib:notify', game.players.white, {title = 'Chess', description = 'Check!', type = 'warning'})
        end
    end)
end

RegisterNetEvent('rsg-chess:server:joinGame', function(locationIndex, isAI, difficulty)
    local src = source
    for _, game in pairs(activeGames) do
        if game.players.white == src or game.players.black == src then
            TriggerClientEvent('ox_lib:notify', src, {description = 'You are already in a game!', type = 'error'})
            return
        end
    end
    if isAI then
        local gameId = createGame(locationIndex, src, true, difficulty)
        TriggerClientEvent('rsg-chess:client:startGame', src, {
            gameId = gameId, playerColor = 'white', board = activeGames[gameId].board,
            currentTurn = activeGames[gameId].currentTurn, isAI = true, difficulty = difficulty
        })
    else
        local availableGame = nil
        for _, game in pairs(activeGames) do
            if game.location == locationIndex and game.gameState == 'waiting' then
                availableGame = game
                break
            end
        end
        if availableGame then
            availableGame.players.black, availableGame.gameState, availableGame.startTime = src, 'active', os.time()
            TriggerClientEvent('rsg-chess:client:startGame', availableGame.players.white, {gameId = availableGame.id, playerColor = 'white', board = availableGame.board, currentTurn = availableGame.currentTurn})
            TriggerClientEvent('rsg-chess:client:startGame', src, {gameId = availableGame.id, playerColor = 'black', board = availableGame.board, currentTurn = availableGame.currentTurn})
            TriggerClientEvent('ox_lib:notify', availableGame.players.white, {description = 'Opponent found! Game starting...', type = 'success'})
            TriggerClientEvent('ox_lib:notify', src, {description = 'Joined game as Black!', type = 'success'})
        else
            local gameId = createGame(locationIndex, src, false)
            TriggerClientEvent('rsg-chess:client:startGame', src, {
                gameId = gameId, playerColor = 'white', board = activeGames[gameId].board,
                currentTurn = activeGames[gameId].currentTurn, waiting = true
            })
        end
    end
end)

RegisterNetEvent('rsg-chess:server:makeMove', function(gameId, from, to)
    local src = source
    local game = activeGames[gameId]
    if not game or game.gameState ~= 'active' then return end
    
    local playerColor = (game.players.white == src and 'white') or (game.players.black == src and 'black')
    if not playerColor or playerColor ~= game.currentTurn then return end
    
    local piece = game.board[posToIndex(from)]
    if not isValidMove(game, from, to, piece) then
        TriggerClientEvent('ox_lib:notify', src, {description = 'Invalid move!', type = 'error'})
        return
    end
    
    local tempBoard = deepCopyBoard(game.board)
    local tempToIdx, tempFromIdx = posToIndex(to), posToIndex(from)
    tempBoard[tempToIdx] = tempBoard[tempFromIdx]
    tempBoard[tempFromIdx] = nil
    if isKingInCheck({board = tempBoard}, playerColor) then
        TriggerClientEvent('ox_lib:notify', src, {description = 'That move would put you in check!', type = 'error'})
        return
    end
    
    executeMove(game, {from = from, to = to})
    
    if checkGameOver(game) then
        activeGames[gameId] = nil
        return
    end
    
    local moveData = {
        from = from, to = to, board = game.board, currentTurn = game.currentTurn,
        check = game.check, capturedPieces = game.capturedPieces
    }
    TriggerClientEvent('rsg-chess:client:updateGame', game.players.white, moveData)
    if not game.isAI and game.players.black then TriggerClientEvent('rsg-chess:client:updateGame', game.players.black, moveData) end
    
    if game.check then
        local opponent = game.currentTurn == 'white' and game.players.white or game.players.black
        if opponent and opponent ~= 'AI' then TriggerClientEvent('ox_lib:notify', opponent, {title = 'Chess', description = 'Check!', type = 'warning'}) end
    end
    
    if game.isAI and game.currentTurn == 'black' then makeAIMove(gameId) end
end)

RegisterNetEvent('rsg-chess:server:forfeit', function(gameId)
    local src = source
    local game = activeGames[gameId]
    if not game then return end
    
    local winner, loser = nil, nil
    if game.players.white == src then
        loser, winner = game.players.white, game.players.black
    elseif game.players.black == src then
        loser, winner = game.players.black, game.players.white
    end
    
    if loser then TriggerClientEvent('rsg-chess:client:gameEnd', loser, {result = 'loss', reason = 'forfeit', isAI = game.isAI}) end
    if winner and winner ~= 'AI' then TriggerClientEvent('rsg-chess:client:gameEnd', winner, {result = 'win', reason = 'opponent_forfeit'}) end
    
    activeGames[gameId] = nil
end)

RegisterNetEvent('rsg-chess:server:leaveGame', function(gameId)
    if activeGames[gameId] and activeGames[gameId].gameState == 'waiting' then
        activeGames[gameId] = nil
    else
        TriggerEvent('rsg-chess:server:forfeit', gameId)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for gameId, game in pairs(activeGames) do
        if game.players.white == src or game.players.black == src then
            local opponent = (game.players.white == src) and game.players.black or game.players.white
            if opponent and opponent ~= 'AI' then
                TriggerClientEvent('rsg-chess:client:gameEnd', opponent, {result = 'win', reason = 'opponent_disconnect'})
            end
            activeGames[gameId] = nil
            break
        end
    end
end)

RegisterCommand('chessinfo', function(source, args)
    if source ~= 0 then return end
    print('^3========== Active Chess Games ==========^7')
    local count = 0
    for id, game in pairs(activeGames) do
        count = count + 1
        print(string.format('^2Game %d:^7 State=%s, Turn=%s, AI=%s, White=%s, Black=%s', 
            id, game.gameState, game.currentTurn, tostring(game.isAI), game.players.white, game.players.black or 'N/A'))
    end
    print(string.format('^3Total games: %d^7', count))
end, true)
