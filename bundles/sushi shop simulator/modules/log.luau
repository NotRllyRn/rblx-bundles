local Log = {}
Log.__index = Log

function Log.new(config)
	return setmetatable({
		config = config,
	}, Log)
end

function Log:_format(level, message)
	return `[{self.config.Prefix}] [{level}] {message}`
end

function Log:info(message)
	if self.config.Enabled then
		print(self:_format("INFO", message))
	end
end

function Log:action(message)
	if self.config.Enabled then
		print(self:_format("ACTION", message))
	end
end

function Log:debug(message)
	if self.config.Enabled and self.config.Verbose then
		print(self:_format("DEBUG", message))
	end
end

function Log:warn(message)
	if self.config.Enabled then
		warn(self:_format("WARN", message))
	end
end

return Log
