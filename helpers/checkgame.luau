--// checks the game if the gameID is the correct Id
local checkgame: (ID: number, kick: boolean) -> nil = function(ID: number)
    local message = `Current game is not supported for this code: {game.GameId}`

    if game.GameId ~= ID then
        warn(message)

        if kick then
            game:GetService("Players").LocalPlayer:Kick(message)
        end
    end
end

return checkgame