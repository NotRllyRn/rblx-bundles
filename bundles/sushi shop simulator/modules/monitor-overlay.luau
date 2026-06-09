local Runtime = require("./react-runtime")
local MonitorApp = require("./monitor-components")

local ReactRoblox = Runtime.ReactRoblox
local e = Runtime.createElement

local MonitorOverlay = {}
MonitorOverlay.__index = MonitorOverlay

function MonitorOverlay.new(refs, controller, log)
	return setmetatable({
		refs = refs,
		controller = controller,
		log = log,
		container = nil,
		root = nil,
	}, MonitorOverlay)
end

function MonitorOverlay:mount()
	if self.root then
		return
	end

	self.container = Instance.new("Folder")
	self.container.Name = "SushiShopMonitorReactRoot"
	self.root = ReactRoblox.createRoot(self.container)
	self.root:render(ReactRoblox.createPortal(e(MonitorApp, {
		controller = self.controller,
	}), self.refs.playerGui))
	self.log:info("React monitor overlay mounted")
end

function MonitorOverlay:destroy()
	if self.root then
		self.root:unmount()
		self.root = nil
	end
	if self.container then
		self.container:Destroy()
		self.container = nil
	end
end

return MonitorOverlay
