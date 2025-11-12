local RSGCore = exports['rsg-core']:GetCoreObject()
local currentGame = nil
local chessBlips = {}
local prompts = {}
local isInChessZone = false
local currentLocation = nil

local DEBUG = Config.Debug or false

local function DebugPrint(...)
    if DEBUG then
        print('^3[Chess Debug]^7', ...)
    end
end

-- Chess piece symbols
local pieceSymbols = {
    white = {
        king = '♔',
        queen = '♕',
        rook = '♖',
        bishop = '♗',
        knight = '♘',
        pawn = '♙'
    },
    black = {
        king = '♚',
        queen = '♛',
        rook = '♜',
        bishop = '♝',
        knight = '♞',
        pawn = '♟'
    }
}

-- Create Prompts
local function SetupPrompts()
    for k, location in pairs(Config.ChessLocations) do
        local str = location.prompt.label or 'Play Chess'
        local prompt = PromptRegisterBegin()
        PromptSetControlAction(prompt, 0xD9D0E1C0)
        str = CreateVarString(10, 'LITERAL_STRING', str)
        PromptSetText(prompt, str)
        PromptSetEnabled(prompt, false)
        PromptSetVisible(prompt, false)
        PromptSetHoldMode(prompt, true)
        PromptRegisterEnd(prompt)
        prompts[k] = prompt
        DebugPrint('Prompt created for:', location.name)
    end
end

-- Check Distance
CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        
        isInChessZone = false
        
        for k, location in pairs(Config.ChessLocations) do
            local distance = #(pos - location.coords)
            
            if distance < location.prompt.distance then
                sleep = 0
                isInChessZone = true
                currentLocation = k
                PromptSetEnabled(prompts[k], true)
                PromptSetVisible(prompts[k], true)
                
                if PromptHasHoldModeCompleted(prompts[k]) then
                    DebugPrint('Prompt completed!')
                    if currentGame then
                        DebugPrint('Opening existing game')
                        OpenGame()
                    else
                        DebugPrint('Showing game mode menu')
                        showGameModeMenu(k)
                    end
                end
            else
                PromptSetEnabled(prompts[k], false)
                PromptSetVisible(prompts[k], false)
            end
        end
        
        Wait(sleep)
    end
end)

-- Create Blips
CreateThread(function()
    for k, location in pairs(Config.ChessLocations) do
        local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, location.coords)
        SetBlipSprite(blip, GetHashKey(location.blip.sprite), true)
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, location.name)
        table.insert(chessBlips, blip)
    end
end)

-- Show piece guide menu
function showPieceGuide(locationIndex)
    lib.registerContext({
        id = 'chess_piece_guide',
        title = 'Chess Pieces Guide',
        menu = 'chess_game_mode',
        options = {
            {
                title = '♔ King (White) / ♚ King (Black)',
                description = 'Moves one square in any direction. Most important piece!',
                icon = 'crown',
                disabled = true
            },
            {
                title = '♕ Queen (White) / ♛ Queen (Black)',
                description = 'Moves any number of squares in any direction. Most powerful!',
                icon = 'chess-queen',
                disabled = true
            },
            {
                title = '♖ Rook (White) / ♜ Rook (Black)',
                description = 'Moves any number of squares horizontally or vertically',
                icon = 'chess-rook',
                disabled = true
            },
            {
                title = '♗ Bishop (White) / ♝ Bishop (Black)',
                description = 'Moves any number of squares diagonally',
                icon = 'chess-bishop',
                disabled = true
            },
            {
                title = '♘ Knight (White) / ♞ Knight (Black)',
                description = 'Moves in an L-shape (2 squares + 1 square perpendicular)',
                icon = 'chess-knight',
                disabled = true
            },
            {
                title = '♙ Pawn (White) / ♟ Pawn (Black)',
                description = 'Moves forward one square, captures diagonally',
                icon = 'chess-pawn',
                disabled = true
            },
            {
                title = '⬅️ Back to Menu',
                description = 'Return to game mode selection',
                icon = 'arrow-left',
                onSelect = function()
                    showGameModeMenu(locationIndex)
                end
            }
        }
    })
    lib.showContext('chess_piece_guide')
end

-- Show game mode menu
function showGameModeMenu(locationIndex)
    lib.registerContext({
        id = 'chess_game_mode',
        title = 'Chess Game',
        options = {
            {
                title = 'Play vs Player',
                description = 'Wait for another player to join',
                icon = 'users',
                onSelect = function()
                    TriggerServerEvent('rsg-chess:server:joinGame', locationIndex, false)
                end
            },
            {
                title = 'Play vs Computer',
                description = 'Play against AI opponent',
                icon = 'robot',
                onSelect = function()
                    showDifficultyMenu(locationIndex)
                end
            },
            {
                title = '📚 View Piece Guide',
                description = 'Learn how each piece moves (♔ ♕ ♖ ♗ ♘ ♙)',
                icon = 'book',
                onSelect = function()
                    showPieceGuide(locationIndex)
                end
            }
        }
    })
    lib.showContext('chess_game_mode')
end

-- AI difficulty selection
function showDifficultyMenu(locationIndex)
    lib.registerContext({
        id = 'chess_difficulty',
        title = 'Select AI Difficulty',
        menu = 'chess_game_mode',
        options = {
            {
                title = 'Easy',
                description = 'AI makes random moves - Good for beginners',
                icon = 'smile',
                onSelect = function()
                    TriggerServerEvent('rsg-chess:server:joinGame', locationIndex, true, 'easy')
                end
            },
            {
                title = 'Medium',
                description = 'AI makes decent moves - Moderate challenge',
                icon = 'meh',
                onSelect = function()
                    TriggerServerEvent('rsg-chess:server:joinGame', locationIndex, true, 'medium')
                end
            },
            {
                title = 'Hard',
                description = 'AI plays strategically - Experienced players',
                icon = 'brain',
                onSelect = function()
                    TriggerServerEvent('rsg-chess:server:joinGame', locationIndex, true, 'hard')
                end
            },
            {
                title = '⬅️ Back',
                description = 'Return to main menu',
                icon = 'arrow-left',
                onSelect = function()
                    showGameModeMenu(locationIndex)
                end
            }
        }
    })
    lib.showContext('chess_difficulty')
end

-- Convert board to JSON-safe format
local function prepareBoardForNUI(board)
    local result = {}
    for i = 1, 64 do
        if board[i] then
            result[tostring(i)] = {
                type = board[i].type,
                color = board[i].color,
                moved = board[i].moved
            }
        end
    end
    return result
end

-- Start game
RegisterNetEvent('rsg-chess:client:startGame', function(gameData)
    DebugPrint('Game started!', json.encode(gameData))
    currentGame = gameData
    
    if not gameData.waiting then
        DebugPrint('Opening UI with NUI')
        
        local boardData = prepareBoardForNUI(gameData.board)
        
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openChess',
            gameData = {
                gameId = gameData.gameId,
                playerColor = gameData.playerColor,
                board = boardData,
                currentTurn = gameData.currentTurn,
                isAI = gameData.isAI or false,
                difficulty = gameData.difficulty
            }
        })
        
        if gameData.isAI then
            lib.notify({
                title = 'Chess',
                description = 'Playing against AI (' .. (gameData.difficulty or 'medium') .. ')',
                type = 'success',
                duration = 3000
            })
        else
            lib.notify({
                title = 'Chess',
                description = 'Game starting!',
                type = 'success',
                duration = 3000
            })
        end
    else
        DebugPrint('Waiting for opponent')
        lib.notify({
            title = 'Chess',
            description = 'Waiting for opponent...',
            type = 'inform',
            duration = 3000
        })
    end
end)

-- Update game state
RegisterNetEvent('rsg-chess:client:updateGame', function(moveData)
    DebugPrint('Board update received')
    if currentGame then
        currentGame.board = moveData.board
        currentGame.currentTurn = moveData.currentTurn
        
        local boardData = prepareBoardForNUI(moveData.board)
        
        SendNUIMessage({
            action = 'updateBoard',
            moveData = {
                from = moveData.from,
                to = moveData.to,
                board = boardData,
                currentTurn = moveData.currentTurn,
                check = moveData.check,
                capturedPieces = moveData.capturedPieces,
                aiMove = moveData.aiMove
            }
        })
        
        if moveData.check then
            PlaySoundFrontend("CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", true, 1)
        end
        
        if moveData.aiMove then
            lib.notify({
                title = 'Chess',
                description = 'AI played: ' .. moveData.from .. ' to ' .. moveData.to,
                type = 'inform',
                duration = 2000
            })
        end
    end
end)

-- Game end
RegisterNetEvent('rsg-chess:client:gameEnd', function(result)
    local message = ''
    
    if result.result == 'win' then
        if result.reason == 'checkmate' then
            message = result.isAI and 'Checkmate! You beat the AI!' or 'Checkmate! You won!'
        elseif result.reason == 'opponent_forfeit' then
            message = 'Your opponent forfeited. You won!'
        elseif result.reason == 'opponent_disconnect' then
            message = 'Your opponent disconnected. You won!'
        end
    elseif result.result == 'loss' then
        if result.reason == 'checkmate' then
            message = result.isAI and 'Checkmate! The AI won!' or 'Checkmate! You lost!'
        elseif result.reason == 'forfeit' then
            message = 'You forfeited the game.'
        end
    elseif result.result == 'draw' then
        if result.reason == 'stalemate' then
            message = 'Game ended in stalemate!'
        else
            message = 'Game ended in a draw!'
        end
    end
    
    lib.notify({
        title = 'Chess',
        description = message,
        type = result.result == 'win' and 'success' or (result.result == 'draw' and 'inform' or 'error'),
        duration = 5000
    })
    
    SendNUIMessage({
        action = 'closeChess'
    })
    
    SetNuiFocus(false, false)
    currentGame = nil
end)

-- Open game UI
function OpenGame()
    if currentGame then
        local boardData = prepareBoardForNUI(currentGame.board)
        
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openChess',
            gameData = {
                gameId = currentGame.gameId,
                playerColor = currentGame.playerColor,
                board = boardData,
                currentTurn = currentGame.currentTurn,
                isAI = currentGame.isAI or false,
                difficulty = currentGame.difficulty
            }
        })
    end
end

RegisterNetEvent('rsg-chess:client:openGame', function()
    OpenGame()
end)

-- NUI Callbacks
RegisterNUICallback('makeMove', function(data, cb)
    if currentGame then
        DebugPrint('Move request:', data.from, 'to', data.to)
        TriggerServerEvent('rsg-chess:server:makeMove', currentGame.gameId, data.from, data.to)
    end
    cb('ok')
end)

RegisterNUICallback('forfeit', function(data, cb)
    cb('ok') -- Respond immediately to NUI
    
    if currentGame then
        -- Use lib.registerContext instead of alertDialog
        lib.registerContext({
            id = 'chess_forfeit_confirm',
            title = 'Forfeit Game',
            options = {
                {
                    title = 'Yes, Forfeit',
                    description = 'Give up and lose the game',
                    icon = 'flag',
                    onSelect = function()
                        TriggerServerEvent('rsg-chess:server:forfeit', currentGame.gameId)
                        SetNuiFocus(false, false)
                        SendNUIMessage({action = 'closeChess'})
                        currentGame = nil
                    end
                },
                {
                    title = 'No, Continue Playing',
                    description = 'Return to the game',
                    icon = 'times',
                    onSelect = function()
                        -- Just close the confirmation menu
                    end
                }
            }
        })
        lib.showContext('chess_forfeit_confirm')
    end
end)

RegisterNUICallback('closeUI', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('closeGame', function(data, cb)
    if currentGame then
        TriggerServerEvent('rsg-chess:server:leaveGame', currentGame.gameId)
        currentGame = nil
    end
    SetNuiFocus(false, false)
    SendNUIMessage({action = 'closeChess'})
    cb('ok')
end)

-- Initialize
CreateThread(function()
    SetupPrompts()
end)

-- Emergency Fix Command
RegisterCommand('fixchess', function()
    SetNuiFocus(false, false)
    SendNUIMessage({action = 'closeChess'})
    currentGame = nil
    print('^2[Chess] UI force closed and reset^0')
end, false)

-- Command to open piece guide anytime
RegisterCommand('chessguide', function()
    if isInChessZone and currentLocation then
        showPieceGuide(currentLocation)
    else
        -- Show standalone guide
        lib.registerContext({
            id = 'chess_piece_guide_standalone',
            title = 'Chess Pieces Guide',
            options = {
                {
                    title = '♔ King (White) / ♚ King (Black)',
                    description = 'Moves one square in any direction. Most important piece - protect it!',
                    icon = 'crown',
                    disabled = true
                },
                {
                    title = '♕ Queen (White) / ♛ Queen (Black)',
                    description = 'Moves any number of squares in any direction. Most powerful piece!',
                    icon = 'chess-queen',
                    disabled = true
                },
                {
                    title = '♖ Rook (White) / ♜ Rook (Black)',
                    description = 'Moves any number of squares horizontally or vertically',
                    icon = 'chess-rook',
                    disabled = true
                },
                {
                    title = '♗ Bishop (White) / ♝ Bishop (Black)',
                    description = 'Moves any number of squares diagonally',
                    icon = 'chess-bishop',
                    disabled = true
                },
                {
                    title = '♘ Knight (White) / ♞ Knight (Black)',
                    description = 'Moves in an L-shape: 2 squares in one direction, then 1 perpendicular',
                    icon = 'chess-knight',
                    disabled = true
                },
                {
                    title = '♙ Pawn (White) / ♟ Pawn (Black)',
                    description = 'Moves forward one square, captures diagonally forward',
                    icon = 'chess-pawn',
                    disabled = true
                }
            }
        })
        lib.showContext('chess_piece_guide_standalone')
    end
end, false)

-- Debug command
if DEBUG then
    RegisterCommand('chessboard', function()
        if currentGame then
            print('^3=== Current Board State ===^7')
            for i = 1, 64 do
                local piece = currentGame.board[i]
                if piece then
                    local rank = 9 - math.ceil(i / 8)
                    local file = ((i - 1) % 8) + 1
                    local pos = string.char(96 + file) .. rank
                    local symbol = pieceSymbols[piece.color][piece.type]
                    print(string.format('^2Index %d (%s):^7 %s %s %s', i, pos, symbol, piece.color, piece.type))
                end
            end
        else
            print('^1No active game^7')
        end
    end, false)
end

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    for _, blip in ipairs(chessBlips) do
        RemoveBlip(blip)
    end
    
    if currentGame then
        SetNuiFocus(false, false)
        SendNUIMessage({action = 'closeChess'})
    end
end)