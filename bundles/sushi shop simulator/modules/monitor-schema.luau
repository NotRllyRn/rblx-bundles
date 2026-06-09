local sections = {
	{
		key = "Hours",
		label = "Shop Hours",
		fields = {
			{ key = "Open", label = "Open hour", kind = "number", min = 0, max = 24 },
			{ key = "Close", label = "Close hour", kind = "number", min = 0, max = 24 },
			{ key = "Midnight", label = "Midnight", kind = "number", min = 0, max = 24 },
		},
	},
	{
		key = "Recipes",
		label = "Recipes",
		fields = {
			{ key = "Count", label = "Recipe count", kind = "integer", min = 1 },
			{
				key = "MinimumCookSeconds",
				label = "Minimum cook seconds",
				kind = "number",
				min = 0.01,
			},
			{
				key = "Priority",
				label = "Priority",
				kind = "choice",
				choices = { "business_profit", "commission", "xp" },
			},
		},
	},
	{
		key = "StockThresholds",
		label = "Stock Thresholds",
		dynamic = "number",
		min = 0,
	},
	{
		key = "Movement",
		label = "Movement",
		dynamic = "scalar",
	},
	{
		key = "Occupancy",
		label = "Occupancy",
		dynamic = "scalar",
	},
	{
		key = "Timing",
		label = "Timing",
		dynamic = "number",
		min = 0,
	},
	{
		key = "Energy",
		label = "Energy",
		fields = {
			{ key = "Minimum", label = "Rest below", kind = "number", min = 0 },
			{ key = "Resume", label = "Resume above", kind = "number", min = 0 },
		},
	},
	{
		key = "Logging",
		label = "Logging",
		fields = {
			{ key = "Enabled", label = "Enabled", kind = "boolean" },
			{ key = "Verbose", label = "Verbose", kind = "boolean" },
			{ key = "Prefix", label = "Prefix", kind = "string" },
		},
	},
	{
		key = "RestockCodes",
		label = "Restock Multipliers",
		dynamic = "restock",
	},
}

local function titleFromKey(key)
	return string.gsub(key, "(%l)(%u)", "%1 %2")
end

local function inferKind(value)
	if type(value) == "boolean" then
		return "boolean"
	elseif type(value) == "number" then
		return "number"
	end
	return "string"
end

local function getFields(section, settings)
	if section.fields then
		return section.fields
	end

	local fields = {}
	local values = settings[section.key] or {}
	local keys = {}
	for key in values do
		table.insert(keys, key)
	end
	table.sort(keys)

	for _, key in keys do
		local value = values[key]
		if section.dynamic == "restock" then
			table.insert(fields, {
				key = `{key}.CostMultiplier`,
				label = `{titleFromKey(key)} multiplier`,
				kind = "number",
				min = 0,
			})
		elseif type(value) ~= "table" then
			table.insert(fields, {
				key = key,
				label = titleFromKey(key),
				kind = inferKind(value),
				min = section.min,
			})
		end
	end

	return fields
end

return {
	sections = sections,
	getFields = getFields,
}
