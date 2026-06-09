local RestockService = {}
RestockService.__index = RestockService

function RestockService.new(refs, settings, signals, log)
	return setmetatable({
		refs = refs,
		settings = settings,
		signals = signals,
		log = log,
	}, RestockService)
end

function RestockService:_getCost(stockValue, restockConfig)
	local price = stockValue:FindFirstChild("Price")
	return price and price.Value * restockConfig.CostMultiplier or math.huge
end

function RestockService:_getCandidates()
	local candidates = {}

	for stockName, threshold in self.settings.StockThresholds do
		local stockValue = self.refs.stock:FindFirstChild(stockName)
		local restockConfig = self.settings.RestockCodes[stockName]
		if stockValue and restockConfig and stockValue.Value < threshold then
			table.insert(candidates, {
				name = stockName,
				valueObject = stockValue,
				config = restockConfig,
				ratio = stockValue.Value / threshold,
				cost = self:_getCost(stockValue, restockConfig),
			})
		end
	end

	table.sort(candidates, function(left, right)
		return left.ratio < right.ratio
	end)

	return candidates
end

function RestockService:_getPaymentCode(candidate)
	local canUseBusiness = self.refs.sales.Value >= candidate.cost and self.refs.bank.Value >= candidate.cost
	if canUseBusiness then
		return candidate.config.Business, "business"
	end

	if self.refs.cents.Value >= candidate.cost then
		return candidate.config.Wallet, "wallet"
	end

	return nil, nil
end

function RestockService:hasActionableRestock()
	for _, candidate in self:_getCandidates() do
		if self:_getPaymentCode(candidate) then
			return true
		end
	end

	return false
end

function RestockService:getPreview()
	local fallback = nil
	for _, candidate in self:_getCandidates() do
		local _, paymentSource = self:_getPaymentCode(candidate)
		local preview = {
			name = candidate.name,
			current = candidate.valueObject.Value,
			cost = candidate.cost,
			paymentSource = paymentSource,
			actionable = paymentSource ~= nil,
		}
		if paymentSource then
			return preview
		end
		fallback = fallback or preview
	end

	return fallback
end

function RestockService:restockNext()
	for _, candidate in self:_getCandidates() do
		local paymentCode, paymentSource = self:_getPaymentCode(candidate)
		if paymentCode then
			local previousValue = candidate.valueObject.Value
			self.refs.buyStockEvent:FireServer(self.settings.BuyStockRemoteKey, paymentCode)
			local changed = self.signals.waitUntilChanged(
				candidate.valueObject,
				previousValue,
				self.settings.Timing.PurchaseTimeout
			)

			if changed and candidate.valueObject.Value > previousValue then
				self.log:action(`Restocked {candidate.name} using {paymentSource} funds`)
				return true
			end

			self.log:warn(`Restock request for {candidate.name} was not confirmed`)
		end
	end

	return false
end

return RestockService
