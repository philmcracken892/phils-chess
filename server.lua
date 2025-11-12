local RSGCore = exports['rsg-core']:GetCoreObject()
local activeGames = {}
local gameIdCounter = 0

local PIECE_VALUES = {
    pawn = 1,
    knight = 3,
    bishop = 3,
    rook = 5,
    queen = 9,
    king = 100
}

-- Create new chess game
local function createGame(location, player1, isAI, difficulty)
    gameIdCounter = gameIdCounter + 1
    activeGames[gameIdCounter] = {
        id = gameIdCounter,
        location = location,
        players = {
            white = player1,
            black = isAI and 'AI' or nil
        },
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
    
    
    for i = 1, 64 do
        board[i] = nil
    end
    
  
    board[1] = {type='rook', color='black', moved=false}
    board[2] = {type='knight', color='black', moved=false}
    board[3] = {type='bishop', color='black', moved=false}
    board[4] = {type='queen', color='black', moved=false}
    board[5] = {type='king', color='black', moved=false}
    board[6] = {type='bishop', color='black', moved=false}
    board[7] = {type='knight', color='black', moved=false}
    board[8] = {type='rook', color='black', moved=false}
    
    
    for i = 9, 16 do
        board[i] = {type='pawn', color='black', moved=false}
    end
    
   
    for i = 49, 56 do
        board[i] = {type='pawn', color='white', moved=false}
    end
    
   
    board[57] = {type='rook', color='white', moved=false}
    board[58] = {type='knight', color='white', moved=false}
    board[59] = {type='bishop', color='white', moved=false}
    board[60] = {type='queen', color='white', moved=false}
    board[61] = {type='king', color='white', moved=false}
    board[62] = {type='bishop', color='white', moved=false}
    board[63] = {type='knight', color='white', moved=false}
    board[64] = {type='rook', color='white', moved=false}
    
    return board
end


local function posToIndex(pos)
    if not pos or #pos < 2 then return nil end
    local file = string.byte(pos:sub(1,1)) - 96
    local rank = tonumber(pos:sub(2,2))
    if not file or not rank or file < 1 or file > 8 or rank < 1 or rank > 8 then
        return nil
    end
    return (9 - rank) * 8 - 8 + file
end


local function indexToPos(index)
    if not index or index < 1 or index > 64 then return nil end
    local rank = 9 - math.ceil(index / 8)
    local file = ((index - 1) % 8) + 1
    return string.char(96 + file) .. rank
end


local function getFileRank(pos)
    local file = string.byte(pos:sub(1,1)) - 96
    local rank = tonumber(pos:sub(2,2))
    return file, rank
end


local function isPathClear(board, fromFile, fromRank, toFile, toRank)
    local fileStep = 0
    local rankStep = 0
    
    if toFile > fromFile then fileStep = 1
    elseif toFile < fromFile then fileStep = -1 end
    
    if toRank > fromRank then rankStep = 1
    elseif toRank < fromRank then rankStep = -1 end
    
    local currentFile = fromFile + fileStep
    local currentRank = fromRank + rankStep
    
    while currentFile ~= toFile or currentRank ~= toRank do
        local pos = string.char(96 + currentFile) .. currentRank
        local idx = posToIndex(pos)
        
        if board[idx] then
            return false
        end
        
        currentFile = currentFile + fileStep
        currentRank = currentRank + rankStep
    end
    
    return true
end


local function isValidMove(game, from, to, piece)
    local fromIdx = posToIndex(from)
    local toIdx = posToIndex(to)
    
    if not fromIdx or not toIdx then return false end
    if from == to then return false end
    
    local board = game.board
    
    if not piece or piece.color ~= game.currentTurn then
        return false
    end
    
    local destPiece = board[toIdx]
    if destPiece and destPiece.color == piece.color then
        return false
    end
    
    local fromFile, fromRank = getFileRank(from)
    local toFile, toRank = getFileRank(to)
    
    local fileDiff = math.abs(toFile - fromFile)
    local rankDiff = math.abs(toRank - fromRank)
    
    if piece.type == 'pawn' then
        local direction = piece.color == 'white' and 1 or -1
        local startRank = piece.color == 'white' and 2 or 7
        
        if toFile == fromFile and not destPiece then
            if toRank == fromRank + direction then
                return true
            end
            if fromRank == startRank and toRank == fromRank + (2 * direction) then
                local middlePos = string.char(96 + fromFile) .. (fromRank + direction)
                local middleIdx = posToIndex(middlePos)
                if not board[middleIdx] then
                    return true
                end
            end
        end
        
        if fileDiff == 1 and toRank == fromRank + direction then
            if destPiece and destPiece.color ~= piece.color then
                return true
            end
            if game.enPassantTarget == to then
                return true
            end
        end
        
        return false
        
    elseif piece.type == 'knight' then
        return (fileDiff == 2 and rankDiff == 1) or (fileDiff == 1 and rankDiff == 2)
        
    elseif piece.type == 'bishop' then
        if fileDiff ~= rankDiff or fileDiff == 0 then return false end
        return isPathClear(board, fromFile, fromRank, toFile, toRank)
        
    elseif piece.type == 'rook' then
        if fileDiff ~= 0 and rankDiff ~= 0 then return false end
        return isPathClear(board, fromFile, fromRank, toFile, toRank)
        
    elseif piece.type == 'queen' then
        if fileDiff ~= 0 and rankDiff ~= 0 and fileDiff ~= rankDiff then
            return false
        end
        return isPathClear(board, fromFile, fromRank, toFile, toRank)
        
    elseif piece.type == 'king' then
        if fileDiff > 1 or rankDiff > 1 then
            return false
        end
        return true
    end
    
    return false
end


local function findKing(board, color)
    for i = 1, 64 do
        local piece = board[i]
        if piece and piece.type == 'king' and piece.color == color then
            return indexToPos(i)
        end
    end
    return nil
end


local function isSquareUnderAttack(board, square, byColor)
    local squareIdx = posToIndex(square)
    if not squareIdx then return false end
    
    for i = 1, 64 do
        local piece = board[i]
        if piece and piece.color == byColor then
            local from = indexToPos(i)
            local tempGame = {
                board = board,
                currentTurn = byColor,
                enPassantTarget = nil
            }
            if isValidMove(tempGame, from, square, piece) then
                return true
            end
        end
    end
    
    return false
end


local function isKingInCheck(board, color)
    local kingPos = findKing(board, color)
    if not kingPos then return false end
    
    local opponentColor = color == 'white' and 'black' or 'white'
    return isSquareUnderAttack(board, kingPos, opponentColor)
end


local function getAllLegalMoves(board, color)
    local moves = {}
    
    for fromIdx = 1, 64 do
        local piece = board[fromIdx]
        if piece and piece.color == color then
            local from = indexToPos(fromIdx)
            
            for toIdx = 1, 64 do
                local to = indexToPos(toIdx)
                local tempGame = {
                    board = board,
                    currentTurn = color,
                    enPassantTarget = nil
                }
                
                if isValidMove(tempGame, from, to, piece) then
                    local tempBoard = {}
                    for i = 1, 64 do
                        tempBoard[i] = board[i]
                    end
                    tempBoard[toIdx] = tempBoard[fromIdx]
                    tempBoard[fromIdx] = nil
                    
                    if not isKingInCheck(tempBoard, color) then
                        table.insert(moves, {
                            from = from,
                            to = to,
                            piece = piece,
                            capture = board[toIdx]
                        })
                    end
                end
            end
        end
    end
    
    return moves
end


local function hasLegalMoves(board, color)
    local moves = getAllLegalMoves(board, color)
    return #moves > 0
end


local function evaluateBoard(board, color)
    local score = 0
    
    for i = 1, 64 do
        local piece = board[i]
        if piece then
            local value = PIECE_VALUES[piece.type] or 0
            local rank = 9 - math.ceil(i / 8)
            local file = ((i - 1) % 8) + 1
            
            if file >= 3 and file <= 6 and rank >= 3 and rank <= 6 then
                value = value + 0.1
            end
            
            if piece.type == 'pawn' then
                if piece.color == 'white' then
                    value = value + (rank - 2) * 0.1
                else
                    value = value + (7 - rank) * 0.1
                end
            end
            
            if piece.color == color then
                score = score + value
            else
                score = score - value
            end
        end
    end
    
    return score
end


local function getAIMove(game)
    local moves = getAllLegalMoves(game.board, 'black')
    if #moves == 0 then return nil end
    
    if game.difficulty == 'easy' then
        return moves[math.random(#moves)]
        
    elseif game.difficulty == 'medium' then
        local bestMoves = {}
        local bestScore = -9999
        
        for _, move in ipairs(moves) do
            local score = 0
            
            if move.capture then
                score = score + (PIECE_VALUES[move.capture.type] or 0) * 2
            end
            
            local toFile, toRank = getFileRank(move.to)
            if toFile >= 3 and toFile <= 6 and toRank >= 3 and toRank <= 6 then
                score = score + 1
            end
            
            if score > bestScore then
                bestScore = score
                bestMoves = {move}
            elseif score == bestScore then
                table.insert(bestMoves, move)
            end
        end
        
        return bestMoves[math.random(#bestMoves)]
        
    elseif game.difficulty == 'hard' then
        local bestMove = nil
        local bestScore = -9999
        
        for _, move in ipairs(moves) do
            local tempBoard = {}
            for i = 1, 64 do tempBoard[i] = game.board[i] end
            
            local fromIdx = posToIndex(move.from)
            local toIdx = posToIndex(move.to)
            tempBoard[toIdx] = tempBoard[fromIdx]
            tempBoard[fromIdx] = nil
            
            local score = evaluateBoard(tempBoard, 'black')
            
            if move.capture then
                score = score + (PIECE_VALUES[move.capture.type] or 0)
            end
            
            if isKingInCheck(tempBoard, 'white') then
                score = score + 3
            end
            
            local toFile, toRank = getFileRank(move.to)
            if toRank <= 4 then
                score = score + 0.5
            end
            
            if score > bestScore then
                bestScore = score
                bestMove = move
            end
        end
        
        return bestMove
    end
    
    return moves[math.random(#moves)]
end


local function makeAIMove(gameId)
    local game = activeGames[gameId]
    if not game or not game.isAI or game.currentTurn ~= 'black' then return end
    
    SetTimeout(1500 + math.random(1000), function()
        game = activeGames[gameId]
        if not game then return end
        
        local aiMove = getAIMove(game)
        if not aiMove then
           
            return
        end
        
        local fromIdx = posToIndex(aiMove.from)
        local toIdx = posToIndex(aiMove.to)
        
        local capturedPiece = game.board[toIdx]
        if capturedPiece then
            table.insert(game.capturedPieces.black, capturedPiece)
        end
        
        game.board[toIdx] = game.board[fromIdx]
        if game.board[toIdx] then
            game.board[toIdx].moved = true
        end
        game.board[fromIdx] = nil
        
        local toFile, toRank = getFileRank(aiMove.to)
        if game.board[toIdx] and game.board[toIdx].type == 'pawn' and toRank == 1 then
            game.board[toIdx] = {type = 'queen', color = 'black', moved = true}
        end
        
        game.currentTurn = 'white'
        game.check = isKingInCheck(game.board, 'white')
        game.lastMove = {from = aiMove.from, to = aiMove.to}
        
        table.insert(game.moves, {
            from = aiMove.from,
            to = aiMove.to,
            piece = aiMove.piece.type,
            capture = capturedPiece ~= nil
        })
        
        if not hasLegalMoves(game.board, 'white') then
            if game.check then
                TriggerClientEvent('rsg-chess:client:gameEnd', game.players.white, {
                    result = 'loss',
                    reason = 'checkmate',
                    isAI = true
                })
                activeGames[gameId] = nil
                return
            else
                TriggerClientEvent('rsg-chess:client:gameEnd', game.players.white, {
                    result = 'draw',
                    reason = 'stalemate',
                    isAI = true
                })
                activeGames[gameId] = nil
                return
            end
        end
        
        local moveData = {
            from = aiMove.from,
            to = aiMove.to,
            board = game.board,
            currentTurn = game.currentTurn,
            check = game.check,
            capturedPieces = game.capturedPieces,
            aiMove = true
        }
        
        TriggerClientEvent('rsg-chess:client:updateGame', game.players.white, moveData)
        
        if game.check then
            TriggerClientEvent('ox_lib:notify', game.players.white, {
                title = 'Chess',
                description = 'Check!',
                type = 'warning'
            })
        end
    end)
end


RegisterNetEvent('rsg-chess:server:joinGame', function(locationIndex, isAI, difficulty)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    for _, game in pairs(activeGames) do
        if game.players.white == src or game.players.black == src then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Chess',
                description = 'You are already in a game!',
                type = 'error'
            })
            return
        end
    end
    
    if isAI then
        local gameId = createGame(locationIndex, src, true, difficulty)
        
        TriggerClientEvent('rsg-chess:client:startGame', src, {
            gameId = gameId,
            playerColor = 'white',
            board = activeGames[gameId].board,
            currentTurn = activeGames[gameId].currentTurn,
            isAI = true,
            difficulty = difficulty
        })
        
        
    else
        local availableGame = nil
        for _, game in pairs(activeGames) do
            if game.location == locationIndex and game.gameState == 'waiting' and not game.players.black and not game.isAI then
                availableGame = game
                break
            end
        end
        
        if availableGame then
            availableGame.players.black = src
            availableGame.gameState = 'active'
            availableGame.startTime = os.time()
            
            TriggerClientEvent('ox_lib:notify', availableGame.players.white, {
                title = 'Chess',
                description = 'Opponent found! Game starting...',
                type = 'success'
            })
            
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Chess',
                description = 'Joined game as Black!',
                type = 'success'
            })
            
            TriggerClientEvent('rsg-chess:client:startGame', availableGame.players.white, {
                gameId = availableGame.id,
                playerColor = 'white',
                board = availableGame.board,
                currentTurn = availableGame.currentTurn
            })
            
            TriggerClientEvent('rsg-chess:client:startGame', src, {
                gameId = availableGame.id,
                playerColor = 'black',
                board = availableGame.board,
                currentTurn = availableGame.currentTurn
            })
            
            
        else
            local gameId = createGame(locationIndex, src, false)
            
            TriggerClientEvent('rsg-chess:client:startGame', src, {
                gameId = gameId,
                playerColor = 'white',
                board = activeGames[gameId].board,
                currentTurn = activeGames[gameId].currentTurn,
                waiting = true
            })
            
            
        end
    end
end)


RegisterNetEvent('rsg-chess:server:makeMove', function(gameId, from, to)
    local src = source
    local game = activeGames[gameId]
    
    if not game or game.gameState ~= 'active' then
        return
    end
    
    local playerColor = nil
    if game.players.white == src then
        playerColor = 'white'
    elseif game.players.black == src then
        playerColor = 'black'
    else
        return
    end
    
    if playerColor ~= game.currentTurn then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Chess',
            description = 'Not your turn!',
            type = 'error'
        })
        return
    end
    
    local fromIdx = posToIndex(from)
    local toIdx = posToIndex(to)
    
    if not fromIdx or not toIdx then
        return
    end
    
    local piece = game.board[fromIdx]
    
    if not isValidMove(game, from, to, piece) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Chess',
            description = 'Invalid move!',
            type = 'error'
        })
        
        return
    end
    
    local tempBoard = {}
    for i = 1, 64 do tempBoard[i] = game.board[i] end
    tempBoard[toIdx] = tempBoard[fromIdx]
    tempBoard[fromIdx] = nil
    
    if isKingInCheck(tempBoard, playerColor) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Chess',
            description = 'That move would put you in check!',
            type = 'error'
        })
        return
    end
    
    local capturedPiece = game.board[toIdx]
    if capturedPiece then
        table.insert(game.capturedPieces[playerColor], capturedPiece)
    end
    
    game.board[toIdx] = piece
    game.board[toIdx].moved = true
    game.board[fromIdx] = nil
    
    local toFile, toRank = getFileRank(to)
    if piece.type == 'pawn' and (toRank == 8 or toRank == 1) then
        game.board[toIdx] = {type = 'queen', color = playerColor, moved = true}
    end
    
    if piece.type == 'pawn' and math.abs(toRank - tonumber(from:sub(2,2))) == 2 then
        local direction = playerColor == 'white' and 1 or -1
        game.enPassantTarget = string.char(96 + toFile) .. (toRank - direction)
    else
        game.enPassantTarget = nil
    end
    
    game.currentTurn = game.currentTurn == 'white' and 'black' or 'white'
    game.lastMove = {from = from, to = to}
    
    local opponentColor = playerColor == 'white' and 'black' or 'white'
    game.check = isKingInCheck(game.board, opponentColor)
    
    if not hasLegalMoves(game.board, opponentColor) then
        if game.check then
            game.checkmate = true
            game.gameState = 'finished'
            
            TriggerClientEvent('rsg-chess:client:gameEnd', src, {
                result = 'win',
                reason = 'checkmate',
                isAI = game.isAI
            })
            
            if not game.isAI and game.players.black then
                TriggerClientEvent('rsg-chess:client:gameEnd', game.players.black, {
                    result = 'loss',
                    reason = 'checkmate'
                })
            end
            
            
            activeGames[gameId] = nil
            return
        else
            game.stalemate = true
            game.gameState = 'finished'
            
            TriggerClientEvent('rsg-chess:client:gameEnd', game.players.white, {
                result = 'draw',
                reason = 'stalemate',
                isAI = game.isAI
            })
            
            if not game.isAI and game.players.black then
                TriggerClientEvent('rsg-chess:client:gameEnd', game.players.black, {
                    result = 'draw',
                    reason = 'stalemate'
                })
            end
            
            
            activeGames[gameId] = nil
            return
        end
    end
    
    table.insert(game.moves, {
        from = from,
        to = to,
        piece = piece.type,
        capture = capturedPiece ~= nil
    })
    
    local moveData = {
        from = from,
        to = to,
        board = game.board,
        currentTurn = game.currentTurn,
        check = game.check,
        capturedPieces = game.capturedPieces
    }
    
    if game.players.white then
        TriggerClientEvent('rsg-chess:client:updateGame', game.players.white, moveData)
    end
    if game.players.black and not game.isAI then
        TriggerClientEvent('rsg-chess:client:updateGame', game.players.black, moveData)
    end
    
    if game.check then
        local checkPlayer = game.currentTurn == 'white' and game.players.white or game.players.black
        if checkPlayer and checkPlayer ~= 'AI' then
            TriggerClientEvent('ox_lib:notify', checkPlayer, {
                title = 'Chess',
                description = 'Check!',
                type = 'warning'
            })
        end
    end
    
    
    
    if game.isAI and game.currentTurn == 'black' then
        makeAIMove(gameId)
    end
end)


RegisterNetEvent('rsg-chess:server:forfeit', function(gameId)
    local src = source
    local game = activeGames[gameId]
    
    if not game then return end
    
    local winner = nil
    local loser = nil
    
    if game.players.white == src then
        winner = game.players.black
        loser = game.players.white
    elseif game.players.black == src then
        winner = game.players.white
        loser = game.players.black
    end
    
    if winner and winner ~= 'AI' then
        TriggerClientEvent('rsg-chess:client:gameEnd', winner, {
            result = 'win',
            reason = 'opponent_forfeit'
        })
    end
    
    if loser then
        TriggerClientEvent('rsg-chess:client:gameEnd', loser, {
            result = 'loss',
            reason = 'forfeit',
            isAI = game.isAI
        })
    end
    
    print(string.format('[Chess] Game %d forfeited', gameId))
    activeGames[gameId] = nil
end)


RegisterNetEvent('rsg-chess:server:leaveGame', function(gameId)
    local src = source
    local game = activeGames[gameId]
    
    if not game then return end
    
    if game.gameState == 'waiting' then
        activeGames[gameId] = nil
    else
        TriggerEvent('rsg-chess:server:forfeit', gameId)
    end
end)


AddEventHandler('playerDropped', function()
    local src = source
    
    for gameId, game in pairs(activeGames) do
        if game.players.white == src or game.players.black == src then
            local opponent = game.players.white == src and game.players.black or game.players.white
            
            if opponent and opponent ~= 'AI' then
                TriggerClientEvent('rsg-chess:client:gameEnd', opponent, {
                    result = 'win',
                    reason = 'opponent_disconnect'
                })
            end
            
            activeGames[gameId] = nil
            break
        end
    end
end)

-- Debug command
RegisterCommand('chessinfo', function(source, args)
    if source ~= 0 then return end
    
    print('^3========== Active Chess Games ==========^7')
    local count = 0
    for id, game in pairs(activeGames) do
        count = count + 1
        print(string.format('^2Game %d:^7 State=%s, Turn=%s, AI=%s', 
            id, game.gameState, game.currentTurn, tostring(game.isAI)))
    end
    print(string.format('^3Total games: %d^7', count))
end, true)