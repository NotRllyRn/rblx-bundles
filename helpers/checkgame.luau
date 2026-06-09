--// checks the game if the gameID is the correct Id
local checkgame: (ID: number) -> nil = function(ID: number)
    local message = `Current game is not supported for this code: {game.GameId}`

    if game.GameId ~= ID then
        warn(message)
        game:GetService("Players").LocalPlayer:Kick(message)
    end
end

return checkgame