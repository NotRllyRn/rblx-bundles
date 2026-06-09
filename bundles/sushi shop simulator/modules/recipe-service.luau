local RecipeService = {}
RecipeService.__index = RecipeService

local RECIPE_PRIORITIES = {
	business_profit = true,
	commission = true,
	xp = true,
}

function RecipeService.new(refs, settings, state, recipeData, signals, log)
	return setmetatable({
		refs = refs,
		settings = settings,
		state = state,
		recipeData = recipeData,
		signals = signals,
		log = log,
	}, RecipeService)
end

function RecipeService:_ingredientCost(recipe)
	local totalCost = 0

	for ingredientName, requiredAmount in recipe.ingredients do
		local stockValue = self.refs.stock:FindFirstChild(ingredientName)
		local price = stockValue and stockValue:FindFirstChild("Price")
		if price then
			totalCost += price.Value * requiredAmount
		end
	end

	return totalCost
end

function RecipeService:canCraft(recipe)
	if not recipe or recipe.requiredLevel > self.refs.level.Value or self.refs.plates.Value <= 0 then
		return false
	end

	for ingredientName, requiredAmount in recipe.ingredients do
		local stockValue = self.refs.stock:FindFirstChild(ingredientName)
		if not stockValue or stockValue.Value < requiredAmount then
			return false
		end
	end

	return true
end

function RecipeService:_canUseBusinessFunds(cost)
	return self.refs.sales.Value >= cost and self.refs.bank.Value >= cost
end

function RecipeService:_getPriority()
	local priority = string.lower(self.settings.Recipes.Priority or "business_profit")
	if RECIPE_PRIORITIES[priority] then
		return priority
	end

	return "business_profit"
end

function RecipeService:_getMetrics(recipe)
	local ingredientCost = self:_ingredientCost(recipe)
	local cookSeconds = math.max(recipe.cookSeconds, self.settings.Recipes.MinimumCookSeconds)
	local canUseBusinessFunds = self:_canUseBusinessFunds(ingredientCost)

	return {
		ingredientCost = ingredientCost,
		cookSeconds = cookSeconds,
		canUseBusinessFunds = canUseBusinessFunds,
		businessProfitPerSecond = (recipe.saleCents + recipe.commissionCents - ingredientCost) / cookSeconds,
		commissionPerSecond = recipe.commissionCents / cookSeconds,
		personalCommissionPerSecond = (recipe.commissionCents - ingredientCost) / cookSeconds,
		xpPerSecond = recipe.xpReward / cookSeconds,
		xpPerOwnCentPerSecond = ingredientCost > 0
			and recipe.xpReward / ingredientCost / cookSeconds
			or recipe.xpReward / cookSeconds,
	}
end

function RecipeService:_getPriorityScore(recipe, metrics)
	local priority = self:_getPriority()
	if priority == "commission" then
		if metrics.canUseBusinessFunds then
			return metrics.commissionPerSecond
		end

		return metrics.personalCommissionPerSecond
	end

	if priority == "xp" then
		if metrics.canUseBusinessFunds then
			return metrics.xpPerSecond
		end

		return metrics.xpPerOwnCentPerSecond
	end

	return metrics.businessProfitPerSecond
end

function RecipeService:_isBetterCandidate(candidateRecipe, candidateMetrics, bestRecipe, bestMetrics)
	if not bestRecipe then
		return true
	end

	local candidateScore = self:_getPriorityScore(candidateRecipe, candidateMetrics)
	local bestScore = self:_getPriorityScore(bestRecipe, bestMetrics)
	if candidateScore ~= bestScore then
		return candidateScore > bestScore
	end

	if candidateMetrics.businessProfitPerSecond ~= bestMetrics.businessProfitPerSecond then
		return candidateMetrics.businessProfitPerSecond > bestMetrics.businessProfitPerSecond
	end

	if candidateMetrics.commissionPerSecond ~= bestMetrics.commissionPerSecond then
		return candidateMetrics.commissionPerSecond > bestMetrics.commissionPerSecond
	end

	if candidateMetrics.xpPerSecond ~= bestMetrics.xpPerSecond then
		return candidateMetrics.xpPerSecond > bestMetrics.xpPerSecond
	end

	return candidateRecipe.id < bestRecipe.id
end

function RecipeService:getBestCraftableRecipe()
	local bestRecipe = nil
	local bestMetrics = nil

	for recipeId = 1, self.settings.Recipes.Count do
		local recipe = self.recipeData:get(recipeId)
		if self:canCraft(recipe) then
			local metrics = self:_getMetrics(recipe)
			if self:_isBetterCandidate(recipe, metrics, bestRecipe, bestMetrics) then
				bestRecipe = recipe
				bestMetrics = metrics
			end
		end
	end

	return bestRecipe
end

function RecipeService:selectBestRecipe()
	local recipe = self:getBestCraftableRecipe()
	if not recipe then
		return nil
	end

	if self.refs.recipe.Value == recipe.id then
		return recipe
	end

	local now = os.clock()
	if now - self.state.lastRecipeSwitch < self.settings.Timing.RecipeSwitchCooldown then
		local equippedRecipe = self.recipeData:get(self.refs.recipe.Value)
		return self:canCraft(equippedRecipe) and equippedRecipe or nil
	end

	self.state.lastRecipeSwitch = now
	local previousRecipeId = self.refs.recipe.Value
	self.refs.recipeEvent:FireServer(self.settings.RecipeRemoteKey, recipe.id)
	self.signals.waitUntilChanged(
		self.refs.recipe,
		previousRecipeId,
		self.settings.Timing.PurchaseTimeout
	)

	if self.refs.recipe.Value == recipe.id then
		self.log:action(`Selected recipe {recipe.name}`)
		return recipe
	end

	self.log:warn(`Failed to select recipe {recipe.name}`)
	local equippedRecipe = self.recipeData:get(self.refs.recipe.Value)
	return self:canCraft(equippedRecipe) and equippedRecipe or nil
end

return RecipeService
