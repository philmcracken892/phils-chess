Config = {}

Config.ChessLocations = {
    {
        name = "Valentine Saloon Chess Table",
        coords = vector3(-244.54, 770.97, 118.09),
        heading = 90.0,
        blip = {
            sprite = 'blip_mg_dominoes',
            scale = 0.2,
            color = 'WHITE'
        },
        prompt = {
            label = "Play Chess",
            distance = 2.0
        }
    },
    -- Add more locations here
    {
        name = "Saint Denis Chess Club",
        coords = vector3(2631.42, -1225.26, 53.38),
        heading = 180.0,
        blip = {
            sprite = 'blip_mg_dominoes',
            scale = 0.2,
            color = 'WHITE'
        },
        prompt = {
            label = "Play Chess",
            distance = 2.0
        }
    }
}

Config.GameSettings = {
    maxGameTime = 1800, -- 30 minutes in seconds (0 = unlimited)
    allowSpectators = true,
    requireBothPlayers = false
}

Config.Sounds = {
    movePiece = false,
    capture = true,
    check = true,
    gameEnd = true
}