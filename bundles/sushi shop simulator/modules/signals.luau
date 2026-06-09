local Signals = {}

function Signals.connect(signal, callback, connectionList)
	local connection = signal:Connect(callback)
	if connectionList then
		table.insert(connectionList, connection)
	end
	return connection
end

function Signals.waitForValue(valueObject, predicate, timeout)
	if predicate(valueObject.Value) then
		return true
	end

	local event = Instance.new("BindableEvent")
	local resolved = false
	local matched = false
	local connection = valueObject:GetPropertyChangedSignal("Value"):Connect(function()
		if not resolved and predicate(valueObject.Value) then
			resolved = true
			matched = true
			event:Fire()
		end
	end)

	if timeout and timeout > 0 then
		task.delay(timeout, function()
			if not resolved then
				resolved = true
				event:Fire()
			end
		end)
	end

	event.Event:Wait()
	connection:Disconnect()
	event:Destroy()
	return matched
end

function Signals.disconnectAll(connectionList)
	for _, connection in connectionList do
		connection:Disconnect()
	end
	table.clear(connectionList)
end

function Signals.waitUntilChanged(valueObject, previousValue, timeout)
	return Signals.waitForValue(valueObject, function(currentValue)
		return currentValue ~= previousValue
	end, timeout)
end

return Signals
