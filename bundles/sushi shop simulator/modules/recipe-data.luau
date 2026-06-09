local RecipeData = {}
RecipeData.__index = RecipeData

function RecipeData.new(rawAccessor)
	return setmetatable({
		rawAccessor = rawAccessor,
		cache = {},
	}, RecipeData)
end

function RecipeData:get(recipeId)
	if self.cache[recipeId] then
		return self.cache[recipeId]
	end

	local rawRecipe = self.rawAccessor(recipeId)
	if not rawRecipe then
		return nil
	end

	local name,
		cookSeconds,
		requiredLevel,
		xpReward,
		saleCents,
		commissionCents,
		riceRequired,
		vegetableRequired,
		fishRequired,
		premiumFishRequired,
		servings = table.unpack(rawRecipe)

	local recipe = {
		id = recipeId,
		name = name,
		cookSeconds = cookSeconds,
		requiredLevel = requiredLevel,
		xpReward = xpReward,
		saleCents = saleCents,
		commissionCents = commissionCents,
		servings = servings,
		ingredients = {
			Rice = riceRequired,
			Vegetable = vegetableRequired,
			Fish = fishRequired,
			PremFish = premiumFishRequired,
		},
	}

	self.cache[recipeId] = recipe
	return recipe
end

return RecipeData
