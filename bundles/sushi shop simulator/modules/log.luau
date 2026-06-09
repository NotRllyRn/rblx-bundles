local Log = {}
Log.__index = Log

function Log.new(config)
	return setmetatable({
		config = config,
		history = {},
		listeners = {},
		historyLimit = 100,
	}, Log)
end

function Log:_format(level, message)
	return `[{self.config.Prefix}] [{level}] {message}`
end

function Log:_record(level, message)
	table.insert(self.history, {
		level = level,
		message = message,
		time = os.clock(),
	})
	if #self.history > self.historyLimit then
		table.remove(self.history, 1)
	end
	for callback in self.listeners do
		task.spawn(callback)
	end
end

function Log:getHistory()
	local history = {}
	for index, entry in self.history do
		history[index] = table.clone(entry)
	end
	return history
end

function Log:subscribe(callback)
	self.listeners[callback] = true
	return function()
		self.listeners[callback] = nil
	end
end

function Log:info(message)
	self:_record("INFO", message)
	if self.config.Enabled then
		print(self:_format("INFO", message))
	end
end

function Log:action(message)
	self:_record("ACTION", message)
	if self.config.Enabled then
		print(self:_format("ACTION", message))
	end
end

function Log:debug(message)
	self:_record("DEBUG", message)
	if self.config.Enabled and self.config.Verbose then
		print(self:_format("DEBUG", message))
	end
end

function Log:warn(message)
	self:_record("WARN", message)
	if self.config.Enabled then
		warn(self:_format("WARN", message))
	end
end

return Log
