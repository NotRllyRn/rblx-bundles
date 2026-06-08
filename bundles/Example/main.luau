--// example bundle package

--// main index

--// perform game check... no game here in example
if game.GameId ~= 0 then
    game:GetService("Players").LocalPlayer:Kick(`This script does not support this game: {game.GameId}`)
end

--// can load scripts
require("./somefolder/somefile")

--// can load modules and receieve returns
local module = require("./module")

--// do stuff
module.RandomInstance.Color = Color3.new()

return true