local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Refs = {}

function Refs.create()
	local localPlayer = Players.LocalPlayer
	local attributes = localPlayer:WaitForChild("attributes")
	local replicatedSettings = ReplicatedStorage:WaitForChild("Settings")
	local stock = replicatedSettings:WaitForChild("Stock")

	return {
		players = Players,
		replicatedStorage = ReplicatedStorage,
		lighting = Lighting,
		workspace = Workspace,
		localPlayer = localPlayer,
		playerGui = localPlayer:WaitForChild("PlayerGui"),
		attributes = attributes,
		replicatedSettings = replicatedSettings,
		stock = stock,
		gameFolder = Workspace:WaitForChild("Game"),
		buyStockEvent = ReplicatedStorage:WaitForChild("BuyStockEvent"),
		recipeEvent = ReplicatedStorage:WaitForChild("RecipeEvent"),
		sushiData = require(ReplicatedStorage:WaitForChild("Sushiss")),
		bank = replicatedSettings:WaitForChild("Bank"),
		gameover = replicatedSettings:WaitForChild("Gameover"),
		energy = attributes:WaitForChild("Energy"),
		level = attributes:WaitForChild("Lv"),
		recipe = attributes:WaitForChild("Recipe"),
		sales = attributes:WaitForChild("Sales"),
		cents = attributes:WaitForChild("Cents"),
		days = attributes:WaitForChild("Days"),
		plates = stock:WaitForChild("Plates"),
		dirtyPlates = stock:WaitForChild("PlatesDirty"),
	}
end

return Refs
