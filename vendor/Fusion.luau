-- ++++++++ WAX BUNDLED DATA BELOW ++++++++ --

-- Will be used later for getting flattened globals
local ImportGlobals

-- Holds direct closure data (defining this before the DOM tree for line debugging etc)
local ClosureBindings = {
    function()local wax,script,require=ImportGlobals(1)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler
--[[
	The entry point for the Fusion library.
]]

local Types = require(script.Types)
local External = require(script.External)

type Fusion = Types.Fusion

export type Animatable = Types.Animatable
export type UsedAs<T> = Types.UsedAs<T>
export type Child = Types.Child
export type Computed<T> = Types.Computed<T>
export type Contextual<T> = Types.Contextual<T>
export type GraphObject = Types.GraphObject
export type For<KO, VO> = Types.For<KO, VO>
export type Observer = Types.Observer
export type PropertyTable = Types.PropertyTable
export type Scope<Constructors = Fusion> = Types.Scope<Constructors>
export type ScopedObject = Types.ScopedObject
export type SpecialKey = Types.SpecialKey
export type Spring<T> = Types.Spring<T>
export type StateObject<T> = Types.StateObject<T>
export type Task = Types.Task
export type Tween<T> = Types.Tween<T>
export type Use = Types.Use
export type Value<T, S = T> = Types.Value<T, S>
export type Version = Types.Version

-- Down the line, this will be conditional based on whether Fusion is being
-- compiled for Roblox.
do
	local RobloxExternal = require(script.RobloxExternal)
	External.setExternalProvider(RobloxExternal)
end

local Fusion: Fusion = table.freeze {
	-- General
	version = {major = 0, minor = 3, isRelease = true},
	Contextual = require(script.Utility.Contextual),
	Safe = require(script.Utility.Safe),

	-- Memory
	cleanup = require(script.Memory.legacyCleanup),
	deriveScope = require(script.Memory.deriveScope),
	doCleanup = require(script.Memory.doCleanup),
	innerScope = require(script.Memory.innerScope),
	scoped = require(script.Memory.scoped),
	
	-- Graph
	Observer = require(script.Graph.Observer),

	-- State
	Computed = require(script.State.Computed),
	ForKeys = require(script.State.ForKeys) :: Types.ForKeysConstructor,
	ForPairs = require(script.State.ForPairs) :: Types.ForPairsConstructor,
	ForValues = require(script.State.ForValues) :: Types.ForValuesConstructor,
	peek = require(script.State.peek),
	Value = require(script.State.Value),

	-- Roblox API
	Attribute = require(script.Instances.Attribute),
	AttributeChange = require(script.Instances.AttributeChange),
	AttributeOut = require(script.Instances.AttributeOut),
	Child = require(script.Instances.Child),
	Children = require(script.Instances.Children),
	Hydrate = require(script.Instances.Hydrate),
	New = require(script.Instances.New),
	OnChange = require(script.Instances.OnChange),
	OnEvent = require(script.Instances.OnEvent),
	Out = require(script.Instances.Out),

	-- Animation
	Tween = require(script.Animation.Tween),
	Spring = require(script.Animation.Spring),
}

return Fusion
end)() end,
    [3] = function()local wax,script,require=ImportGlobals(3)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Outputs the current external time as a state object.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
-- Graph
local change = require(Package.Graph.change)
-- Utility
local nicknames = require(Package.Utility.nicknames)

type ExternalTime = Types.StateObject<number>

type Self = ExternalTime

local class = {}
class.type = "State"
class.kind = "ExternalTime"
class.timeliness = "lazy"
class.dependencySet = table.freeze {}
class._EXTREMELY_DANGEROUS_usedAsValue = External.lastUpdateStep()

local METATABLE = table.freeze {__index = class}

local allTimers: {Self} = {}

local function ExternalTime(
	scope: Types.Scope<unknown>
): ExternalTime
	local createdAt = os.clock()
	local self: Self = setmetatable(
		{
			createdAt = createdAt,
			dependentSet = {},
			lastChange = nil,
			scope = scope,
			validity = "invalid"
		}, 
		METATABLE
	) :: any
	local destroy = function()
		self.scope = nil
		local index = table.find(allTimers, self)
		if index ~= nil then
			table.remove(allTimers, index)
		end
	end
	self.oldestTask = destroy
	nicknames[self.oldestTask] = "ExternalTime"
	table.insert(scope, destroy)
	table.insert(allTimers, self)
	return self
end

function class._evaluate(
	self: Self
): boolean
	-- While someone else could call `change()` on this object, it wouldn't be
	-- idiomatic. So, since the only idiomatic time this function runs is when
	-- the external update step runs, it's safe enough to assume that the result
	-- has always meaningfully changed. The worst that can happen is unexpected
	-- refreshing for people doing unorthodox shenanigans, which is an OK trade.
	return true
end

External.bindToUpdateStep(function(
	externalNow: number
): ()
	class._EXTREMELY_DANGEROUS_usedAsValue = External.lastUpdateStep()
	for _, timer in allTimers do
		change(timer)
	end
end)

-- Do *not* freeze the class table, because it stores the shared value of all
-- external time objects, and is updated every frame because of that.
-- table.freeze(class)
return ExternalTime
end)() end,
    [4] = function()local wax,script,require=ImportGlobals(4)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	A specialised state object for following a goal state smoothly over time,
	using physics to shape the motion.

	https://elttob.uk/Fusion/0.3/api-reference/animation/types/spring/
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
-- Memory
local checkLifetime = require(Package.Memory.checkLifetime)
-- Graph
local depend = require(Package.Graph.depend)
local change = require(Package.Graph.change)
local evaluate = require(Package.Graph.evaluate)
-- State
local castToState = require(Package.State.castToState)
local peek = require(Package.State.peek)
-- Animation
local ExternalTime = require(Package.Animation.ExternalTime)
local Stopwatch = require(Package.Animation.Stopwatch)
local packType = require(Package.Animation.packType)
local unpackType = require(Package.Animation.unpackType)
local springCoefficients = require(Package.Animation.springCoefficients)
-- Utility
local nicknames = require(Package.Utility.nicknames)

local EPSILON = 0.00001

type Self<T> = Types.Spring<T> & {
	_activeDamping: number,
	_activeGoal: T,
	_activeLatestP: {number},
	_activeLatestV: {number},
	_activeNumSprings: number,
	_activeSpeed: number,
	_activeStartP: {number},
	_activeStartV: {number},
	_activeTargetP: {number},
	_activeType: string,
	_speed: Types.UsedAs<number>,
	_damping: Types.UsedAs<number>,
	_goal: Types.UsedAs<T>,
	_stopwatch: Stopwatch.Stopwatch
}

local class = {}
class.type = "State"
class.kind = "Spring"
class.timeliness = "eager"

local METATABLE = table.freeze {__index = class}

local function Spring<T>(
	scope: Types.Scope<unknown>,
	goal: Types.UsedAs<T>,
	speed: Types.UsedAs<number>?,
	damping: Types.UsedAs<number>?
): Types.Spring<T>
	local createdAt = os.clock()
	if typeof(scope) ~= "table" or castToState(scope) ~= nil then
		External.logError("scopeMissing", nil, "Springs", "myScope:Spring(goalState, speed, damping)")
	end

	local goalState = castToState(goal)
	local stopwatch = nil
	if goalState ~= nil then
		stopwatch = Stopwatch(scope, ExternalTime(scope))
		stopwatch:unpause()
	end

	local speed = speed or 10
	local damping = damping or 1

	local self: Self<T> = setmetatable(
		{
			createdAt = createdAt,
			dependencySet = {},
			dependentSet = {},
			lastChange = nil,
			scope = scope,
			validity = "invalid",
			_activeDamping = -1,
			_activeGoal = nil,
			_activeLatestP = {},
			_activeLatestV = {},
			_activeNumSprings = 0,
			_activeSpeed = -1,
			_activeStartP = {},
			_activeStartV = {},
			_activeTargetP = {},
			_activeType = "",
			_damping = damping,
			_EXTREMELY_DANGEROUS_usedAsValue = peek(goal),
			_goal = goal,
			_speed = speed,
			_stopwatch = stopwatch
		},
		METATABLE
	) :: any
	local destroy = function()
		self.scope = nil
		for dependency in pairs(self.dependencySet) do
			dependency.dependentSet[self] = nil
		end
	end
	self.oldestTask = destroy
	nicknames[self.oldestTask] = "Spring"
	table.insert(scope, destroy)
	
	if goalState ~= nil then
		checkLifetime.bOutlivesA(
			scope, self.oldestTask,
			goalState.scope, goalState.oldestTask,
			checkLifetime.formatters.animationGoal
		)
	end
	local speedState = castToState(speed)
	if speedState ~= nil then
		checkLifetime.bOutlivesA(
			scope, self.oldestTask,
			speedState.scope, speedState.oldestTask,
			checkLifetime.formatters.parameter, "speed"
		)
	end
	local dampingState = castToState(damping)
	if dampingState ~= nil then
		checkLifetime.bOutlivesA(
			scope, self.oldestTask,
			dampingState.scope, dampingState.oldestTask,
			checkLifetime.formatters.parameter, "damping"
		)
	end

	-- Eagerly evaluated objects need to evaluate themselves so that they're
	-- valid at all times.
	evaluate(self, true)

	return self
end

function class.addVelocity<T>(
	self: Self<T>,
	deltaValue: T
): ()
	evaluate(self, false) -- ensure the _active params are up to date
	local deltaType = typeof(deltaValue)
	if deltaType ~= self._activeType then
		External.logError("springTypeMismatch", nil, deltaType, self._activeType)
	end
	local newStartV = unpackType(deltaValue, deltaType)
	for index, velocity in self._activeLatestV do
		newStartV[index] += velocity
	end
	self._activeStartP = table.clone(self._activeLatestP)
	self._activeStartV = newStartV
	self._stopwatch:zero()
	self._stopwatch:unpause()
	change(self)
end

function class.get<T>(
	self: Self<T>
): never
	return External.logError("stateGetWasRemoved")
end

function class.setPosition<T>(
	self: Self<T>,
	newValue: T
): ()
	evaluate(self, false) -- ensure the _active params are up to date
	local newType = typeof(newValue)
	if newType ~= self._activeType then
		External.logError("springTypeMismatch", nil, newType, self._activeType)
	end
	self._activeStartP = unpackType(newValue, newType)
	self._activeStartV = table.clone(self._activeLatestV)
	self._stopwatch:zero()
	self._stopwatch:unpause()
	change(self)
end

function class.setVelocity<T>(
	self: Self<T>,
	newValue: T
): ()
	evaluate(self, false) -- ensure the _active params are up to date
	local newType = typeof(newValue)
	if newType ~= self._activeType then
		External.logError("springTypeMismatch", nil, newType, self._activeType)
	end
	self._activeStartP = table.clone(self._activeLatestP)
	self._activeStartV = unpackType(newValue, newType)
	self._stopwatch:zero()
	self._stopwatch:unpause()
	change(self)
end

function class._evaluate<T>(
	self: Self<T>
): boolean
	local goal = castToState(self._goal)
	-- Allow non-state goals to pass through transparently.
	if goal == nil then
		self._EXTREMELY_DANGEROUS_usedAsValue = self._goal :: T
		return false
	end
	-- depend(self, goal)
	local nextFrameGoal = peek(goal)
	-- Protect against NaN goals.
	if nextFrameGoal ~= nextFrameGoal then
		External.logWarn("springNanGoal")
		return false
	end
	local nextFrameGoalType = typeof(nextFrameGoal)
	local discontinuous = nextFrameGoalType ~= self._activeType

	local stopwatch = self._stopwatch :: Stopwatch.Stopwatch
	local elapsed = peek(stopwatch)
	depend(self, stopwatch)

	local oldValue = self._EXTREMELY_DANGEROUS_usedAsValue
	local newValue: T

	if discontinuous then
		-- Propagate changes in type instantly throughout the whole reactive
		-- graph, even if simulation is logically one frame behind, because it
		-- makes the whole graph behave more consistently.
		newValue = nextFrameGoal
	elseif elapsed <= 0 then
		newValue = oldValue
	else
		-- Calculate spring motion.
		-- IMPORTANT: use the parameters from last frame, not this frame. We're
		-- integrating the motion that happened over the last frame, after all.
		-- The stopwatch will have captured the length of time needed correctly.
		local posPos, posVel, velPos, velVel = springCoefficients(
			elapsed, 
			self._activeDamping, 
			self._activeSpeed
		)
		local isMoving = false
		for index = 1, self._activeNumSprings do
			local startP = self._activeStartP[index]
			local targetP = self._activeTargetP[index]
			local startV = self._activeStartV[index]
			local startD = startP - targetP
			local latestD = startD * posPos + startV * posVel
			local latestV = startD * velPos + startV * velVel
			if latestD ~= latestD or latestV ~= latestV then
				External.logWarn("springNanMotion")
				latestD, latestV = 0, 0
			end
			if math.abs(latestD) > EPSILON or math.abs(latestV) > EPSILON then
				isMoving = true
			end
			local latestP = latestD + targetP
			self._activeLatestP[index] = latestP
			self._activeLatestV[index] = latestV
		end
		-- Sleep and snap to goal if the motion has decayed to a negligible amount.
		if not isMoving then
			for index = 1, self._activeNumSprings do
				self._activeLatestP[index] = self._activeTargetP[index]
			end
			-- TODO: figure out how to do sleeping correctly for single frame
			-- changes
			-- stopwatch:pause()
			-- stopwatch:zero()
		end
		-- Pack springs into final value.
		newValue = packType(self._activeLatestP, self._activeType) :: any
	end

	-- Reconfigure spring when any of its parameters are changed.
	-- This should happen after integrating the last frame's motion.
	-- NOTE: don't need to add a dependency on these objects! they do not cause
	-- a spring to wake from sleep, so the stopwatch dependency is sufficient.
	local nextFrameSpeed = peek(self._speed) :: number
	local nextFrameDamping = peek(self._damping) :: number
	if
		discontinuous or
		nextFrameGoal ~= self._activeGoal or
		nextFrameSpeed ~= self._activeSpeed or
		nextFrameDamping ~= self._activeDamping
	then
		self._activeTargetP = unpackType(nextFrameGoal, nextFrameGoalType)
		self._activeNumSprings = #self._activeTargetP
		if discontinuous then
			self._activeStartP = table.clone(self._activeTargetP)
			self._activeLatestP = table.clone(self._activeTargetP)
			self._activeStartV = table.create(self._activeNumSprings, 0)
			self._activeLatestV = table.create(self._activeNumSprings, 0)
		else
			self._activeStartP = table.clone(self._activeLatestP)
			self._activeStartV = table.clone(self._activeLatestV)
		end
		self._activeType = nextFrameGoalType
		self._activeGoal = nextFrameGoal
		self._activeDamping = nextFrameDamping
		self._activeSpeed = nextFrameSpeed
		stopwatch:zero()
		stopwatch:unpause()
	end

	-- Push update and check for similarity.
	-- Don't need to use the similarity test here because this code doesn't
	-- deal with tables, and NaN is already guarded against, so the similarity
	-- test doesn't actually add any new safety here.
	self._EXTREMELY_DANGEROUS_usedAsValue = newValue
	return oldValue ~= newValue
end

table.freeze(class)
return Spring :: Types.SpringConstructor
end)() end,
    [5] = function()local wax,script,require=ImportGlobals(5)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	State object for measuring time since an event using a reference timer.

	TODO: this should not be exposed to users until it has a proper reactive API
	surface
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
-- Memory
local checkLifetime = require(Package.Memory.checkLifetime)
-- Graph
local depend = require(Package.Graph.depend)
local change = require(Package.Graph.change)
-- State
local peek = require(Package.State.peek)
-- Utility
local nicknames = require(Package.Utility.nicknames)

export type Stopwatch = Types.StateObject<number> & {
	zero: (Stopwatch) -> (),
	pause: (Stopwatch) -> (),
	unpause: (Stopwatch) -> ()
}

type Self = Stopwatch & {
	_measureTimeSince: number,
	_playing: boolean,
	_timer: Types.StateObject<number>
}

local class = {}
class.type = "State"
class.kind = "Stopwatch"
class.timeliness = "lazy"

local METATABLE = table.freeze {__index = class}

local function Stopwatch(
	scope: Types.Scope<unknown>,
	timer: Types.StateObject<number>
): Stopwatch
	local createdAt = os.clock()
	local self: Self = setmetatable(
		{
			awake = true,
			createdAt = createdAt,
			dependencySet = {},
			dependentSet = {},
			lastChange = nil,
			scope = scope,
			validity = "invalid",
			_EXTREMELY_DANGEROUS_usedAsValue = 0,
			_measureTimeSince = 0, -- this should be set on unpause
			_playing = false,
			_timer = timer
		}, 
		METATABLE
	) :: any
	local destroy = function()
		self.scope = nil
	end
	self.oldestTask = destroy
	nicknames[self.oldestTask] = "Stopwatch"
	table.insert(scope, destroy)

	checkLifetime.bOutlivesA(
		scope, self.oldestTask,
		timer.scope, timer.oldestTask,
		checkLifetime.formatters.parameter, "timer"
	)
	depend(self, timer)
	return self
end

function class.zero(
	self: Self
): ()
	local newTimepoint = peek(self._timer)
	if newTimepoint ~= self._measureTimeSince then
		self._measureTimeSince = newTimepoint
		self._EXTREMELY_DANGEROUS_usedAsValue = 0
		change(self)
	end
end

function class.pause(
	self: Self
): ()
	if self._playing == true then
		self._playing = false
		change(self)
	end
end

function class.unpause(
	self: Self
): ()
	if self._playing == false then
		self._playing = true
		self._measureTimeSince = peek(self._timer) - self._EXTREMELY_DANGEROUS_usedAsValue
		change(self)
	end
end

function class._evaluate(
	self: Self
): boolean
	if self._playing then
		depend(self, self._timer)
		local currentTime = peek(self._timer)
		local oldValue = self._EXTREMELY_DANGEROUS_usedAsValue
		local newValue = currentTime - self._measureTimeSince
		self._EXTREMELY_DANGEROUS_usedAsValue = newValue
		return oldValue ~= newValue
	else
		return false
	end
	
end

table.freeze(class)
return Stopwatch
end)() end,
    [6] = function()local wax,script,require=ImportGlobals(6)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	A specialised state object for following a goal state smoothly over time,
	using a TweenInfo to shape the motion.

	https://elttob.uk/Fusion/0.3/api-reference/animation/types/tween/
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
-- Memory
local checkLifetime = require(Package.Memory.checkLifetime)
-- Graph
local depend = require(Package.Graph.depend)
local evaluate = require(Package.Graph.evaluate)
-- State
local castToState = require(Package.State.castToState)
local peek = require(Package.State.peek)
-- Animation
local ExternalTime = require(Package.Animation.ExternalTime)
local Stopwatch = require(Package.Animation.Stopwatch)
local lerpType = require(Package.Animation.lerpType)
local getTweenRatio = require(Package.Animation.getTweenRatio)
local getTweenDuration = require(Package.Animation.getTweenDuration)
-- Utility
local nicknames = require(Package.Utility.nicknames)

export type Self<T> = Types.Tween<T> & {
	_activeDuration: number,
	_activeElapsed: number,
	_activeFrom: T,
	_activeTo: T,
	_activeTweenInfo: TweenInfo,
	_goal: Types.UsedAs<T>,
	_stopwatch: Stopwatch.Stopwatch?,
	_tweenInfo: Types.UsedAs<TweenInfo>,
}

local class = {}
class.type = "State"
class.kind = "Tween"
class.timeliness = "eager"

local METATABLE = table.freeze {__index = class}

local function Tween<T>(
	scope: Types.Scope<unknown>,
	goal: Types.UsedAs<T>,
	tweenInfo: Types.UsedAs<TweenInfo>?
): Types.Tween<T>
	local createdAt = os.clock()
	if castToState(scope) then
		External.logError("scopeMissing", nil, "Tweens", "myScope:Tween(goalState, tweenInfo)")
	end

	local goalState = castToState(goal)
	local stopwatch = nil
	if goalState ~= nil then
		stopwatch = Stopwatch(scope, ExternalTime(scope))
	end

	local self: Self<T> = setmetatable(
		{
			createdAt = createdAt,
			dependencySet = {},
			dependentSet = {},
			lastChange = nil,
			scope = scope,
			validity = "invalid",
			_activeDuration = nil,
			_activeElapsed = nil,
			_activeFrom = nil,
			_activeTo = nil,
			_activeTweenInfo = nil,
			_EXTREMELY_DANGEROUS_usedAsValue = peek(goal),
			_goal = goal,
			_stopwatch = stopwatch,
			_tweenInfo = tweenInfo or TweenInfo.new()
		},
		METATABLE
	) :: any
	local destroy = function()
		self.scope = nil
		for dependency in pairs(self.dependencySet) do
			dependency.dependentSet[self] = nil
		end
	end
	self.oldestTask = destroy
	nicknames[self.oldestTask] = "Tween"
	table.insert(scope, destroy)

	if goalState ~= nil then
		checkLifetime.bOutlivesA(
			scope, self.oldestTask,
			goalState.scope, goalState.oldestTask,
			checkLifetime.formatters.animationGoal
		)
	end

	local tweenInfoState = castToState(tweenInfo)
	if tweenInfoState ~= nil then
		checkLifetime.bOutlivesA(
			scope, self.oldestTask,
			tweenInfoState.scope, tweenInfoState.oldestTask,
			checkLifetime.formatters.parameter, "tween info"
		)
	end

	-- Eagerly evaluated objects need to evaluate themselves so that they're
	-- valid at all times.
	evaluate(self, true)

	return self
end

function class.get<T>(
	self: Self<T>
): never
	return External.logError("stateGetWasRemoved")
end

function class._evaluate<T>(
	self: Self<T>
): boolean
	local goal = castToState(self._goal)
	-- Allow non-state goals to pass through transparently.
	if goal == nil then
		self._EXTREMELY_DANGEROUS_usedAsValue = self._goal :: T
		return false
	end
	depend(self, goal)
	local newTweenTo = peek(goal)
	-- Protect against NaN goals.
	if newTweenTo ~= newTweenTo then
		External.logWarn("tweenNanGoal")
		return false
	end
	local stopwatch = self._stopwatch :: Stopwatch.Stopwatch
	local tweenInfo = peek(self._tweenInfo) :: TweenInfo
	-- Restart animation when the goal changes, or if the tween info changes
	-- partway through another animation.
	if 
		self._activeTo ~= newTweenTo or
		(self._activeElapsed < self._activeDuration and self._activeTweenInfo ~= tweenInfo)
	then
		self._activeDuration = getTweenDuration(tweenInfo)
		self._activeFrom = self._EXTREMELY_DANGEROUS_usedAsValue
		self._activeTo = newTweenTo
		self._activeTweenInfo = tweenInfo
		stopwatch:zero()
		stopwatch:unpause()
	end
	depend(self, stopwatch)
	self._activeElapsed = peek(stopwatch)
	if
		self._activeFrom == self._activeTo or -- endpoints match
		self._activeElapsed >= self._activeDuration or -- animation is done
		typeof(self._activeTo) ~= typeof(self._activeFrom) -- type difference
	then
		self._activeFrom = self._activeTo
		self._activeElapsed = self._activeDuration
		stopwatch:pause()
	end
	-- Compute actual tweened value.
	local ratio = getTweenRatio(tweenInfo, self._activeElapsed)
	local oldValue = self._EXTREMELY_DANGEROUS_usedAsValue
	local newValue = lerpType(self._activeFrom, self._activeTo, ratio) :: T
	-- Protect against NaN after motion.
	if newValue ~= newValue then
		External.logWarn("tweenNanMotion")
		newValue = self._activeTo
	end
	-- Push update and check for similarity.
	-- Don't need to use the similarity test here because this code doesn't
	-- deal with tables, and NaN is already guarded against, so the similarity
	-- test doesn't actually add any new safety here.
	self._EXTREMELY_DANGEROUS_usedAsValue = newValue
	return oldValue ~= newValue
end

table.freeze(class)
return Tween :: Types.TweenConstructor
end)() end,
    [7] = function()local wax,script,require=ImportGlobals(7)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Given a `tweenInfo`, returns how many seconds it will take before the tween
	finishes moving. The result may be infinite if the tween repeats forever.
]]

local TweenService = game:GetService("TweenService")

local function getTweenDuration(
	tweenInfo: TweenInfo
): number
	if tweenInfo.RepeatCount <= -1 then
		return math.huge
	end
	local tweenDuration = tweenInfo.DelayTime + tweenInfo.Time
	if tweenInfo.Reverses then
		tweenDuration += tweenInfo.Time
	end
	tweenDuration *= tweenInfo.RepeatCount + 1
	return tweenDuration
end

return getTweenDuration
end)() end,
    [8] = function()local wax,script,require=ImportGlobals(8)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Given a `tweenInfo` and `currentTime`, returns a ratio which can be used to
	tween between two values over time.
]]

local TweenService = game:GetService("TweenService")

local function getTweenRatio(
	tweenInfo: TweenInfo,
	currentTime: number
): number
	local delay = tweenInfo.DelayTime
	local duration = tweenInfo.Time
	local reverses = tweenInfo.Reverses
	local numCycles = 1 + tweenInfo.RepeatCount
	local easeStyle = tweenInfo.EasingStyle
	local easeDirection = tweenInfo.EasingDirection
	local cycleDuration = delay + duration
	if reverses then
		cycleDuration += duration
	end
	-- If currentTime is infinity, then presumably the tween should be over.
	-- This avoids NaN when the duration of an infinitely repeating tween is given.
	if currentTime == math.huge then
		return 1
	end
	if currentTime >= cycleDuration * numCycles and tweenInfo.RepeatCount > -1 then
		return 1
	end
	local cycleTime = currentTime % cycleDuration
	if cycleTime <= delay then
		return 0
	end
	local tweenProgress = (cycleTime - delay) / duration
	if tweenProgress > 1 then
		tweenProgress = 2 - tweenProgress
	end
	local ratio = TweenService:GetValue(tweenProgress, easeStyle, easeDirection)
	return ratio
end

return getTweenRatio
end)() end,
    [9] = function()local wax,script,require=ImportGlobals(9)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Linearly interpolates the given animatable types by a ratio.
	If the types are different or not animatable, then the first value will be
	returned for ratios below 0.5, and the second value for 0.5 and above.
]]

local Package = script.Parent.Parent
local Oklab = require(Package.Colour.Oklab)

local function lerpType(
	from: unknown, 
	to: unknown, 
	ratio: number
): unknown
	local typeString = typeof(from)

	if typeof(to) == typeString then
		-- both types must match for interpolation to make sense
		if typeString == "number" then
			local to, from = to :: number, from :: number
			return (to - from) * ratio + from

		elseif typeString == "CFrame" then
			local to, from = to :: CFrame, from :: CFrame
			return from:Lerp(to, ratio)

		elseif typeString == "Color3" then
			local to, from = to :: Color3, from :: Color3
			local fromLab = Oklab.fromSRGB(from)
			local toLab = Oklab.fromSRGB(to)
			return Oklab.toSRGB(
				fromLab:Lerp(toLab, ratio),
				false
			)

		elseif typeString == "ColorSequenceKeypoint" then
			local to, from = to :: ColorSequenceKeypoint, from :: ColorSequenceKeypoint
			local fromLab = Oklab.fromSRGB(from.Value)
			local toLab = Oklab.fromSRGB(to.Value)
			return ColorSequenceKeypoint.new(
				(to.Time - from.Time) * ratio + from.Time,
				Oklab.toSRGB(
					fromLab:Lerp(toLab, ratio),
					false
				)
			)

		elseif typeString == "DateTime" then
			local to, from = to :: DateTime, from :: DateTime
			return DateTime.fromUnixTimestampMillis(
				(to.UnixTimestampMillis - from.UnixTimestampMillis) * ratio + from.UnixTimestampMillis
			)

		elseif typeString == "NumberRange" then
			local to, from = to :: NumberRange, from :: NumberRange
			return NumberRange.new(
				(to.Min - from.Min) * ratio + from.Min,
				(to.Max - from.Max) * ratio + from.Max
			)

		elseif typeString == "NumberSequenceKeypoint" then
			local to, from = to :: NumberSequenceKeypoint, from :: NumberSequenceKeypoint
			return NumberSequenceKeypoint.new(
				(to.Time - from.Time) * ratio + from.Time,
				(to.Value - from.Value) * ratio + from.Value,
				(to.Envelope - from.Envelope) * ratio + from.Envelope
			)

		elseif typeString == "PhysicalProperties" then
			local to, from = to :: PhysicalProperties, from :: PhysicalProperties
			return PhysicalProperties.new(
				(to.Density - from.Density) * ratio + from.Density,
				(to.Friction - from.Friction) * ratio + from.Friction,
				(to.Elasticity - from.Elasticity) * ratio + from.Elasticity,
				(to.FrictionWeight - from.FrictionWeight) * ratio + from.FrictionWeight,
				(to.ElasticityWeight - from.ElasticityWeight) * ratio + from.ElasticityWeight
			)

		elseif typeString == "Ray" then
			local to, from = to :: Ray, from :: Ray
			return Ray.new(
				from.Origin:Lerp(to.Origin, ratio),
				from.Direction:Lerp(to.Direction, ratio)
			)

		elseif typeString == "Rect" then
			local to, from = to :: Rect, from :: Rect
			return Rect.new(
				from.Min:Lerp(to.Min, ratio),
				from.Max:Lerp(to.Max, ratio)
			)

		elseif typeString == "Region3" then
			local to, from = to :: Region3, from :: Region3
			-- FUTURE: support rotated Region3s if/when they become constructable
			local position = from.CFrame.Position:Lerp(to.CFrame.Position, ratio)
			local halfSize = from.Size:Lerp(to.Size, ratio) / 2
			return Region3.new(position - halfSize, position + halfSize)

		elseif typeString == "Region3int16" then
			local to, from = to :: Region3int16, from :: Region3int16
			return Region3int16.new(
				Vector3int16.new(
					(to.Min.X - from.Min.X) * ratio + from.Min.X,
					(to.Min.Y - from.Min.Y) * ratio + from.Min.Y,
					(to.Min.Z - from.Min.Z) * ratio + from.Min.Z
				),
				Vector3int16.new(
					(to.Max.X - from.Max.X) * ratio + from.Max.X,
					(to.Max.Y - from.Max.Y) * ratio + from.Max.Y,
					(to.Max.Z - from.Max.Z) * ratio + from.Max.Z
				)
			)

		elseif typeString == "UDim" then
			local to, from = to :: UDim, from :: UDim
			return UDim.new(
				(to.Scale - from.Scale) * ratio + from.Scale,
				(to.Offset - from.Offset) * ratio + from.Offset
			)

		elseif typeString == "UDim2" then
			local to, from = to :: UDim2, from :: UDim2
			return from:Lerp(to, ratio)

		elseif typeString == "Vector2" then
			local to, from = to :: Vector2, from :: Vector2
			return from:Lerp(to, ratio)

		elseif typeString == "Vector2int16" then
			local to, from = to :: Vector2int16, from :: Vector2int16
			return Vector2int16.new(
				(to.X - from.X) * ratio + from.X,
				(to.Y - from.Y) * ratio + from.Y
			)

		elseif typeString == "Vector3" then
			local to, from = to :: Vector3, from :: Vector3
			return from:Lerp(to, ratio)

		elseif typeString == "Vector3int16" then
			local to, from = to :: Vector3int16, from :: Vector3int16
			return Vector3int16.new(
				(to.X - from.X) * ratio + from.X,
				(to.Y - from.Y) * ratio + from.Y,
				(to.Z - from.Z) * ratio + from.Z
			)
		end
	end

	-- fallback case: the types are different or not animatable
	if ratio < 0.5 then
		return from
	else
		return to
	end
end

return lerpType
end)() end,
    [10] = function()local wax,script,require=ImportGlobals(10)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Packs an array of numbers into a given animatable data type.
	If the type is not animatable, nil will be returned.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local Oklab = require(Package.Colour.Oklab)

local function packType(
	numbers: {number},
	typeString: string
): Types.Animatable?
	if typeString == "number" then
		return numbers[1]

	elseif typeString == "CFrame" then
		return
			CFrame.new(numbers[1], numbers[2], numbers[3]) *
			CFrame.fromAxisAngle(
				Vector3.new(numbers[4], numbers[5], numbers[6]).Unit,
				numbers[7]
			)

	elseif typeString == "Color3" then
		return Oklab.toSRGB(
			Vector3.new(numbers[1], numbers[2], numbers[3]),
			false
		)

	elseif typeString == "ColorSequenceKeypoint" then
		return ColorSequenceKeypoint.new(
			numbers[4],
			Oklab.toSRGB(
				Vector3.new(numbers[1], numbers[2], numbers[3]),
				false
			)
		)

	elseif typeString == "DateTime" then
		return DateTime.fromUnixTimestampMillis(numbers[1])

	elseif typeString == "NumberRange" then
		return NumberRange.new(numbers[1], numbers[2])

	elseif typeString == "NumberSequenceKeypoint" then
		return NumberSequenceKeypoint.new(numbers[2], numbers[1], numbers[3])

	elseif typeString == "PhysicalProperties" then
		return PhysicalProperties.new(numbers[1], numbers[2], numbers[3], numbers[4], numbers[5])

	elseif typeString == "Ray" then
		return Ray.new(
			Vector3.new(numbers[1], numbers[2], numbers[3]),
			Vector3.new(numbers[4], numbers[5], numbers[6])
		)

	elseif typeString == "Rect" then
		return Rect.new(numbers[1], numbers[2], numbers[3], numbers[4])

	elseif typeString == "Region3" then
		-- FUTURE: support rotated Region3s if/when they become constructable
		local position = Vector3.new(numbers[1], numbers[2], numbers[3])
		local halfSize = Vector3.new(numbers[4] / 2, numbers[5] / 2, numbers[6] / 2)
		return Region3.new(position - halfSize, position + halfSize)

	elseif typeString == "Region3int16" then
		return Region3int16.new(
			Vector3int16.new(numbers[1], numbers[2], numbers[3]),
			Vector3int16.new(numbers[4], numbers[5], numbers[6])
		)

	elseif typeString == "UDim" then
		return UDim.new(numbers[1], numbers[2])

	elseif typeString == "UDim2" then
		return UDim2.new(numbers[1], numbers[2], numbers[3], numbers[4])

	elseif typeString == "Vector2" then
		return Vector2.new(numbers[1], numbers[2])

	elseif typeString == "Vector2int16" then
		return Vector2int16.new(numbers[1], numbers[2])

	elseif typeString == "Vector3" then
		return Vector3.new(numbers[1], numbers[2], numbers[3])

	elseif typeString == "Vector3int16" then
		return Vector3int16.new(numbers[1], numbers[2], numbers[3])
	else
		return nil
	end
end

return packType
end)() end,
    [11] = function()local wax,script,require=ImportGlobals(11)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Returns a 2x2 matrix of coefficients for a given time, damping and angular
	frequency (aka 'speed').
	
	Specifically, this returns four coefficients - posPos, posVel, velPos, and
	velVel - which can be multiplied with position and velocity like so:

	local newPosition = oldPosition * posPos + oldVelocity * posVel
	local newVelocity = oldPosition * velPos + oldVelocity * velVel

	For speed = 1 and damping = 0, the result is a simple harmonic oscillator
	with a period of tau.

	Special thanks to AxisAngle for helping to improve numerical precision.
]]

local function springCoefficients(
	time: number,
	damping: number,
	speed: number
): (number, number, number, number)
	-- if time or speed is 0, then the spring won't move
	if time == 0 or speed == 0 then
		return 1, 0, 0, 1
	end
	local posPos, posVel, velPos, velVel

	if damping > 1 then
		-- overdamped spring

		local alpha = math.sqrt(damping^2 - 1)
		local negHalf_over_alpha_speed = -0.5 / (alpha * speed)
		local z1 = speed * (alpha + damping) * -1
		local z2 = speed * (alpha - damping)
		local exp1 = math.exp(time * z1)
		local exp2 = math.exp(time * z2)

		posPos = (exp2 * z1 - exp1 * z2) * negHalf_over_alpha_speed
		posVel = (exp1 - exp2) * negHalf_over_alpha_speed / speed
		velPos = (exp2 - exp1) * negHalf_over_alpha_speed * speed
		velVel = (exp1 * z1 - exp2 * z2) * negHalf_over_alpha_speed

	elseif damping == 1 then
		-- critically damped spring

		local time_speed = time * speed
		local time_speed_neg1 = time_speed * -1
		local exp = math.exp(time_speed_neg1)

		posPos = exp * (time_speed + 1)
		posVel = exp * time
		velPos = exp * (time_speed_neg1 * speed)
		velVel = exp * (time_speed_neg1 + 1)
	else
		-- underdamped spring

		local alpha = speed * math.sqrt(1 - damping^2)
		local overAlpha = 1 / alpha
		local exp = math.exp(-1 * time * speed * damping)
		local sin = math.sin(alpha * time)
		local cos = math.cos(alpha * time)
		local exp_sin = exp * sin
		local exp_cos = exp * cos
		local exp_sin_speed_damping_overAlpha = exp_sin * speed * damping * overAlpha

		posPos = exp_sin_speed_damping_overAlpha + exp_cos
		posVel = exp_sin * overAlpha
		velPos = -1 * ( exp_sin * alpha + speed * damping * exp_sin_speed_damping_overAlpha )
		velVel = exp_cos - exp_sin_speed_damping_overAlpha
	end

	return posPos, posVel, velPos, velVel
end

return springCoefficients
end)() end,
    [12] = function()local wax,script,require=ImportGlobals(12)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Unpacks an animatable type into an array of numbers.
	If the type is not animatable, an empty array will be returned.
]]

local Package = script.Parent.Parent
local Oklab = require(Package.Colour.Oklab)

local function unpackType(
	value: unknown,
	typeString: string
): {number}
	if typeString == "number" then
		local value = value :: number
		return {value}

	elseif typeString == "CFrame" then
		local value = value :: CFrame
		-- FUTURE: is there a better way of doing this? doing distance
		-- calculations on `angle` may be incorrect
		local axis, angle = value:ToAxisAngle()
		return {value.X, value.Y, value.Z, axis.X, axis.Y, axis.Z, angle}

	elseif typeString == "Color3" then
		local value = value :: Color3
		local lab = Oklab.fromSRGB(value)
		return {lab.X, lab.Y, lab.Z}

	elseif typeString == "ColorSequenceKeypoint" then
		local value = value :: ColorSequenceKeypoint
		local lab = Oklab.fromSRGB(value.Value)
		return {lab.X, lab.Y, lab.Z, value.Time}

	elseif typeString == "DateTime" then
		local value = value :: DateTime
		return {value.UnixTimestampMillis}

	elseif typeString == "NumberRange" then
		local value = value :: NumberRange
		return {value.Min, value.Max}

	elseif typeString == "NumberSequenceKeypoint" then
		local value = value :: NumberSequenceKeypoint
		return {value.Value, value.Time, value.Envelope}

	elseif typeString == "PhysicalProperties" then
		local value = value :: PhysicalProperties
		return {value.Density, value.Friction, value.Elasticity, value.FrictionWeight, value.ElasticityWeight}

	elseif typeString == "Ray" then
		local value = value :: Ray
		return {value.Origin.X, value.Origin.Y, value.Origin.Z, value.Direction.X, value.Direction.Y, value.Direction.Z}

	elseif typeString == "Rect" then
		local value = value :: Rect
		return {value.Min.X, value.Min.Y, value.Max.X, value.Max.Y}

	elseif typeString == "Region3" then
		local value = value :: Region3
		-- FUTURE: support rotated Region3s if/when they become constructable
		return {
			value.CFrame.X, value.CFrame.Y, value.CFrame.Z,
			value.Size.X, value.Size.Y, value.Size.Z
		}

	elseif typeString == "Region3int16" then
		local value = value :: Region3int16
		return {value.Min.X, value.Min.Y, value.Min.Z, value.Max.X, value.Max.Y, value.Max.Z}

	elseif typeString == "UDim" then
		local value = value :: UDim
		return {value.Scale, value.Offset}

	elseif typeString == "UDim2" then
		local value = value :: UDim2
		return {value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset}

	elseif typeString == "Vector2" then
		local value = value :: Vector2
		return {value.X, value.Y}

	elseif typeString == "Vector2int16" then
		local value = value :: Vector2int16
		return {value.X, value.Y}

	elseif typeString == "Vector3" then
		local value = value :: Vector3
		return {value.X, value.Y, value.Z}

	elseif typeString == "Vector3int16" then
		local value = value :: Vector3int16
		return {value.X, value.Y, value.Z}
	else
		return {}
	end
end

return unpackType
end)() end,
    [14] = function()local wax,script,require=ImportGlobals(14)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Provides functions for converting Color3s into Oklab space, for more
	perceptually uniform colour blending.

	See: https://bottosson.github.io/posts/oklab/
]]

local sRGB = require(script.Parent.sRGB)

local Oklab = {}

-- Converts a Color3 in linear RGB space to a Vector3 in Oklab space.
function Oklab.fromLinear(rgb: Color3): Vector3

	local l = rgb.R * 0.4122214708 + rgb.G * 0.5363325363 + rgb.B * 0.0514459929
	local m = rgb.R * 0.2119034982 + rgb.G * 0.6806995451 + rgb.B * 0.1073969566
	local s = rgb.R * 0.0883024619 + rgb.G * 0.2817188376 + rgb.B * 0.6299787005

	local lRoot = l ^ (1/3)
	local mRoot = m ^ (1/3)
	local sRoot = s ^ (1/3)

	return Vector3.new(
		lRoot * 0.2104542553 + mRoot * 0.7936177850 - sRoot * 0.0040720468,
		lRoot * 1.9779984951 - mRoot * 2.4285922050 + sRoot * 0.4505937099,
		lRoot * 0.0259040371 + mRoot * 0.7827717662 - sRoot * 0.8086757660
	)
end

-- Converts a Color3 in sRGB space to a Vector3 in Oklab space.
function Oklab.fromSRGB(srgb: Color3): Vector3
	return Oklab.fromLinear(sRGB.toLinear(srgb))
end

-- Converts a Vector3 in Oklab space to a Color3 in linear RGB space.
-- The Color3 will be clamped by default unless specified otherwise.
function Oklab.toLinear(lab: Vector3, unclamped: boolean?): Color3
	local lRoot = lab.X + lab.Y * 0.3963377774 + lab.Z * 0.2158037573
	local mRoot = lab.X - lab.Y * 0.1055613458 - lab.Z * 0.0638541728
	local sRoot = lab.X - lab.Y * 0.0894841775 - lab.Z * 1.2914855480

	local l = lRoot ^ 3
	local m = mRoot ^ 3
	local s = sRoot ^ 3

	local red = l * 4.0767416621 - m * 3.3077115913 + s * 0.2309699292
	local green = l * -1.2684380046 + m * 2.6097574011 - s * 0.3413193965
	local blue = l * -0.0041960863 - m * 0.7034186147 + s * 1.7076147010

	if not unclamped then
		red = math.clamp(red, 0, 1)
		green = math.clamp(green, 0, 1)
		blue = math.clamp(blue, 0, 1)
	end

	return Color3.new(red, green, blue)
end

-- Converts a Vector3 in Oklab space to a Color3 in sRGB space.
-- The Color3 will be clamped by default unless specified otherwise.
function Oklab.toSRGB(lab: Vector3, unclamped: boolean?): Color3
	return sRGB.fromLinear(Oklab.toLinear(lab, unclamped))
end

return Oklab
end)() end,
    [15] = function()local wax,script,require=ImportGlobals(15)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
    Provides transformation functions for converting linear RGB values
    into sRGB values.

    RGB color channel transformations are outlined here:
    https://bottosson.github.io/posts/colorwrong/#what-can-we-do%3F
]]

local sRGB = {}

-- Equivalent to f_inv. Takes a linear sRGB channel and returns
-- the sRGB channel
local function transform(channel: number): number
    if channel >= 0.04045 then
        return ((channel + 0.055)/(1 + 0.055))^2.4
    else
        return channel / 12.92
    end
end

-- Equivalent to f. Takes an sRGB channel and returns
-- the linear sRGB channel
local function inverse(channel: number): number
    if channel >= 0.0031308 then
        return (1.055) * channel^(1.0/2.4) - 0.055
    else
        return 12.92 * channel
    end
end

-- Uses a tranformation to convert linear RGB into sRGB.
function sRGB.fromLinear(rgb: Color3): Color3
    return Color3.new(
        transform(rgb.R),
        transform(rgb.G),
        transform(rgb.B)
    )
end

-- Converts an sRGB into linear RGB using a
-- (The inverse of sRGB.fromLinear).
function sRGB.toLinear(srgb: Color3): Color3
    return Color3.new(
        inverse(srgb.R),
        inverse(srgb.G),
        inverse(srgb.B)
    )
end

return sRGB
end)() end,
    [16] = function()local wax,script,require=ImportGlobals(16)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Abstraction layer between Fusion internals and external environments,
	allowing for flexible integration with schedulers and test mocks.
]]

local Package = script.Parent
local formatError = require(Package.Logging.formatError)
local Types = require(Package.Types)

local ERROR_INFO_URL = "https://elttob.uk/Fusion/0.3/api-reference/general/errors/#"

local External = {}

-- Indicates that a highly time-critical passage of code is running. During
-- critical periods of a program, Fusion might decide to change some of its
-- internal behaviour to be more performance friendly.
local timeCritical = false

-- Multiplier for running-time safety checks across the Fusion codebase. Used to
-- stricten tests on infinite loop detection during unit testing.
External.safetyTimerMultiplier = 1

local updateStepCallbacks = {}
local currentProvider: Types.ExternalProvider? = nil
local lastUpdateStep = 0

--[[
	Swaps to a new provider for external operations.
	Returns the old provider, so it can be used again later.
]]
function External.setExternalProvider(
	newProvider: Types.ExternalProvider?
): Types.ExternalProvider?
	local oldProvider = currentProvider
	if oldProvider ~= nil then
		oldProvider.stopScheduler()
	end
	currentProvider = newProvider
	if newProvider ~= nil then
		newProvider.startScheduler()
	end
	return oldProvider
end

--[[
	Returns true if a highly time-critical passage of code is running.
]]
function External.isTimeCritical(): boolean
	return timeCritical
end

--[[
   Sends an immediate task to the external provider. Throws if none is set.
]]
function External.doTaskImmediate(
	resume: () -> ()
)
	if currentProvider == nil then
		External.logError("noTaskScheduler")
	else
		currentProvider.doTaskImmediate(resume)
	end
end

--[[
	Sends a deferred task to the external provider. Throws if none is set.
]]
function External.doTaskDeferred(
	resume: () -> ()
)
	if currentProvider == nil then
		External.logError("noTaskScheduler")
	else
		currentProvider.doTaskDeferred(resume)
	end
end

--[[
	Errors in the current thread and halts execution.
]]
function External.logError(
	messageID: string,
	errObj: Types.Error?,
	...: unknown
): never
	error(formatError(currentProvider, messageID, errObj, ...), 0)
end

--[[
	Errors in a different thread to preserve the flow of execution.
]]
function External.logErrorNonFatal(
	messageID: string,
	errObj: Types.Error?,
	...: unknown
): ()
	local errorString = formatError(currentProvider, messageID, errObj, ...)
	if currentProvider ~= nil then
		currentProvider.logErrorNonFatal(errorString)
	else
		print(errorString)
	end
end

--[[
	Shows a warning message in the output.
]]
function External.logWarn(
	messageID: string,
	...: unknown
): ()
	local errorString = formatError(currentProvider, messageID, debug.traceback(nil, 2), ...)
	if currentProvider ~= nil then
		currentProvider.logWarn(errorString)
	else
		print(errorString)
	end
end

--[[
	Registers a callback to the update step of the external provider.
	Returns a function that can be used to disconnect later.

	Callbacks are given the current number of seconds since an arbitrary epoch.
	
	TODO: This epoch may change between providers. We could investigate ways
	of allowing providers to co-operate to keep the epoch the same, so that
	monotonicity can be better preserved.
]]
function External.bindToUpdateStep(
	callback: (
		now: number
	) -> ()
): () -> ()
	local uniqueIdentifier = {}
	updateStepCallbacks[uniqueIdentifier] = callback
	return function()
		updateStepCallbacks[uniqueIdentifier] = nil
	end
end

--[[
	Steps time-dependent systems with the current number of seconds since an
	arbitrary epoch. This should be called as early as possible in the external
	provider's update cycle.
]]
function External.performUpdateStep(
	now: number
)
	lastUpdateStep = now
	for _, callback in updateStepCallbacks do
		callback(now)
	end
end

--[[
	Returns the timestamp of the last update step.
]]
function External.lastUpdateStep()
	return lastUpdateStep
end

return External
end)() end,
    [17] = function()local wax,script,require=ImportGlobals(17)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Abstraction layer between Fusion internals and external debuggers, allowing
	for deep introspection using function hooks.

	Unlike `External`, attaching a debugger is optional, and all debugger
	functions are expected to be infallible and non-blocking.
]]

local Package = script.Parent
local Types = require(Package.Types)

local currentProvider: Types.ExternalDebugger? = nil
local lastUpdateStep = 0

local Debugger = {}

--[[
	Swaps to a new debugger.
	Returns the old debugger, so it can be used again later.
]]
function Debugger.setDebugger(
	newProvider: Types.ExternalDebugger?
): Types.ExternalDebugger?
	local oldProvider = currentProvider
	if oldProvider ~= nil then
		oldProvider.stopDebugging()
	end
	currentProvider = newProvider
	if newProvider ~= nil then
		newProvider.startDebugging()
	end
	return oldProvider
end

--[[
	Called at the earliest moment after a scope is created or removed from the
	scope pool, but not before the scope has finished being prepared by the
	library, so that debuggers can register its existence and track changes
	to the scope over time.
]]
function Debugger.trackScope(
	scope: Types.Scope<unknown>
): ()
	if currentProvider == nil then
		return
	end
	currentProvider.trackScope(scope)
end

--[[
	Called at the final moment before a scope is poisoned or added to the scope
	pool, after all cleanup tasks have completed, so that debuggers can erase 
	the scope from internal trackers. Note that, due to scope pooling and user
	code, never assume that this correlates with garbage collection events.
]]
function Debugger.untrackScope(
	scope: Types.Scope<unknown>
): ()
	if currentProvider == nil then
		return
	end
	currentProvider.trackScope(scope)
end

return Debugger
end)() end,
    [19] = function()local wax,script,require=ImportGlobals(19)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	A graph object that runs user code when it's updated by the reactive graph.

	http://elttob.uk/Fusion/0.3/api-reference/state/types/observer/
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
-- Memory
local checkLifetime = require(Package.Memory.checkLifetime)
-- Graph
local castToGraph = require(Package.Graph.castToGraph)
local depend = require(Package.Graph.depend)
local evaluate = require(Package.Graph.evaluate)
-- Utility
local nicknames = require(Package.Utility.nicknames)

type Self = Types.Observer & {
	_watchingGraph: Types.GraphObject?,
	_changeListeners: {[unknown]: () -> ()}
}

local class = {}
class.type = "Observer"
class.timeliness = "eager"
class.dependentSet = table.freeze {}

local METATABLE = table.freeze {__index = class}

local function Observer(
	scope: Types.Scope<unknown>,
	watching: unknown
): Types.Observer
	local createdAt = os.clock()
	if watching == nil then
		External.logError("scopeMissing", nil, "Observers", "myScope:Observer(watching)")
	end

	local self: Self = setmetatable(
		{
			scope = scope,
			createdAt = createdAt,
			dependencySet = {},
			lastChange = nil,
			validity = "invalid",
			_watchingGraph = castToGraph(watching),
			_changeListeners = {}
		},
		METATABLE
	) :: any
	local destroy = function()
		self.scope = nil
		for dependency in pairs(self.dependencySet) do
			dependency.dependentSet[self] = nil
		end
	end
	self.oldestTask = destroy
	nicknames[self.oldestTask] = "Observer"
	table.insert(scope, destroy)

	if self._watchingGraph ~= nil then
		checkLifetime.bOutlivesA(
			scope, self.oldestTask,
			self._watchingGraph.scope, self._watchingGraph.oldestTask,
			checkLifetime.formatters.observer
		)
	end

	-- Eagerly evaluated objects need to evaluate themselves so that they're
	-- valid at all times.
	evaluate(self, true)

	return self
end

function class.onBind(
	self: Self,
	callback: () -> ()
): () -> ()
	External.doTaskImmediate(callback)
	return self:onChange(callback)
end

function class.onChange(
	self: Self,
	callback: () -> ()
): () -> ()
	local uniqueIdentifier = table.freeze {}
	self._changeListeners[uniqueIdentifier] = callback
	return function()
		self._changeListeners[uniqueIdentifier] = nil
	end
end

function class._evaluate(
	self: Self
): ()
	if self._watchingGraph ~= nil then
		depend(self, self._watchingGraph)
	end
	for _, callback in self._changeListeners do
		External.doTaskImmediate(callback)
	end
	return true
end

table.freeze(class)
return Observer :: Types.ObserverConstructor
end)() end,
    [20] = function()local wax,script,require=ImportGlobals(20)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Returns the input *only* if it is a graph object.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)

local function castToGraph(
	target: any
): Types.GraphObject?
	if 
		typeof(target) == "table" and
		typeof(target.validity) == "string" and
		typeof(target.timeliness) == "string" and
		typeof(target.dependencySet) == "table" and
		typeof(target.dependentSet) == "table"
	then
		return target
	else
		return nil
	end
end

return castToGraph
end)() end,
    [21] = function()local wax,script,require=ImportGlobals(21)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Prompts a graph object to re-evaluate its own value. If it meaningfully
	changes, then dependents will have to re-evaluate their own values in the
	future.

	https://fluff.blog/2024/04/16/monotonic-painting.html
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
local evaluate = require(Package.Graph.evaluate)

-- How long should this function run before it's considered to be in an infinite
-- cycle and error out?
local TERMINATION_TIME = 1

local function change(
	target: Types.GraphObject
): ()
	if target.validity == "busy" then
		return External.logError("infiniteLoop")
	end

	local meaningfullyChanged = evaluate(target, true)
	if not meaningfullyChanged then
		return
	end

	local searchInNow: {Types.GraphObject} = {}
	local searchInNext: {Types.GraphObject} = {}
	local invalidateList: {Types.GraphObject} = {}

	searchInNow[1] = target
	local terminateBy = os.clock() + TERMINATION_TIME * External.safetyTimerMultiplier
	repeat
		if os.clock() > terminateBy then
			return External.logError("infiniteLoop")
		end
		local done = true
		for _, searchTarget in searchInNow do
			for dependent in searchTarget.dependentSet do
				if dependent.validity == "valid" then
					done = false
					table.insert(invalidateList, dependent)
					table.insert(searchInNext, dependent)
				elseif dependent.validity == "busy" then
					return External.logError("infiniteLoop")
				end
			end
		end
		searchInNow, searchInNext = searchInNext, searchInNow
		table.clear(searchInNext)
	until done

	local eagerList: {Types.GraphObject} = {}

	for _, invalidateTarget in invalidateList do
		invalidateTarget.validity = "invalid"
		if invalidateTarget.timeliness == "eager" then
			table.insert(eagerList, invalidateTarget)
		end
	end
	-- If objects are not executed in order of creations, then dynamic graphs
	-- may experience 'glitches' where nested graph objects see intermediate
	-- values before being destroyed.
	-- https://fluff.blog/2024/07/14/glitches-in-dynamic-reactive-graphs.html
	table.sort(eagerList, function(a, b)
		return a.createdAt < b.createdAt
	end)
	for _, eagerTarget in eagerList do
		evaluate(eagerTarget, false)
	end
end

return change
end)() end,
    [22] = function()local wax,script,require=ImportGlobals(22)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Forms a dependency on a graph object.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
local evaluate = require(Package.Graph.evaluate)
local nameOf = require(Package.Utility.nameOf)

local function depend<T>(
	dependent: Types.GraphObject,
	dependency: Types.GraphObject
): ()
	-- Ensure dependencies are evaluated and up-to-date
	-- when they are depended on. Also, newly created objects
	-- might not have any transitive dependencies captured yet,
	-- so ensure that they're present.
	evaluate(dependency, false)

	if table.isfrozen(dependent.dependencySet) or table.isfrozen(dependency.dependentSet) then
		External.logError("cannotDepend", nil, nameOf(dependent, "Dependent"), nameOf(dependency, "dependency"))
	end
	dependency.dependentSet[dependent] = true
	dependent.dependencySet[dependency] = true
end

return depend
end)() end,
    [23] = function()local wax,script,require=ImportGlobals(23)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Evaluates the graph object if necessary, so that it is up to date.
	Returns true if it meaningfully changed.

	https://fluff.blog/2024/04/16/monotonic-painting.html
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)

local function evaluate(
	target: Types.GraphObject,
	forceComputation: boolean
): boolean
	if target.validity == "busy" then
		return External.logError("infiniteLoop")
	end
	local firstEvaluation = target.lastChange == nil
	local isInvalid = target.validity == "invalid"
	if firstEvaluation or isInvalid or forceComputation then
		local needsComputation = firstEvaluation or forceComputation
		if not needsComputation then
			for dependency in target.dependencySet do
				evaluate(dependency, false)
				if dependency.lastChange > target.lastChange then
					needsComputation = true
					break
				end
			end
		end
		local targetMeaningfullyChanged = false
		if needsComputation then
			for dependency in target.dependencySet do
				dependency.dependentSet[target] = nil
				target.dependencySet[dependency] = nil
			end
			target.validity = "busy"
			targetMeaningfullyChanged = target:_evaluate() or firstEvaluation
		end
		if targetMeaningfullyChanged then
			target.lastChange = os.clock()
		end
		target.validity = "valid"
		return targetMeaningfullyChanged
	else
		return false
	end
end

return evaluate
end)() end,
    [25] = function()local wax,script,require=ImportGlobals(25)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	A special key for property tables, which allows users to apply custom
	attributes to instances
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
-- Memory
local checkLifetime = require(Package.Memory.checkLifetime)
-- Graph
local Observer = require(Package.Graph.Observer)
-- State
local castToState = require(Package.State.castToState)
local peek = require(Package.State.peek)

local keyCache: {[string]: Types.SpecialKey} = {}

local function Attribute(
	attributeName: string
): Types.SpecialKey
	local key = keyCache[attributeName]
	if key == nil then
		key = {
			type = "SpecialKey",
			kind = "Attribute",
			stage = "self",
			apply = function(
				self: Types.SpecialKey,
				scope: Types.Scope<unknown>,
				value: unknown,
				applyTo: Instance
			)
				if castToState(value) then
					local value = value :: Types.StateObject<unknown>
					checkLifetime.bOutlivesA(
						scope, applyTo,
						value.scope, value.oldestTask,
						checkLifetime.formatters.boundAttribute, attributeName
					)
					Observer(scope, value :: any):onBind(function()
						applyTo:SetAttribute(attributeName, peek(value))
					end)
				else
					applyTo:SetAttribute(attributeName, value)
				end
			end
		}
		keyCache[attributeName] = key
	end
	return key
end

return Attribute
end)() end,
    [26] = function()local wax,script,require=ImportGlobals(26)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	A special key for property tables, which allows users to connect to
	an attribute change on an instance.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)

local keyCache: {[string]: Types.SpecialKey} = {}

local function AttributeChange(
	attributeName: string
): Types.SpecialKey
	local key = keyCache[attributeName]
	if key == nil then
		key = {
			type = "SpecialKey",
			kind = "AttributeChange",
			stage = "observer",
			apply = function(
				self: Types.SpecialKey,
				scope: Types.Scope<unknown>,
				value: unknown,
				applyTo: Instance
			)
				if typeof(value) ~= "function" then
					External.logError("invalidAttributeChangeHandler", nil, attributeName)
				end
				local value = value :: (...unknown) -> (...unknown)
				local event = applyTo:GetAttributeChangedSignal(attributeName)
				table.insert(scope, event:Connect(function()
					value((applyTo :: any):GetAttribute(attributeName))
				end))
			end
		}
		keyCache[attributeName] = key
	end
	return key
end

return AttributeChange
end)() end,
    [27] = function()local wax,script,require=ImportGlobals(27)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	A special key for property tables, which allows users to save instance attributes
	into state objects
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
-- Memory
local checkLifetime = require(Package.Memory.checkLifetime)
-- State
local castToState = require(Package.State.castToState)

local keyCache: {[string]: Types.SpecialKey} = {}

local function AttributeOut(
	attributeName: string
): Types.SpecialKey
	local key = keyCache[attributeName]
	if key == nil then
		key = {
			type = "SpecialKey",
			kind = "AttributeOut",
			stage = "observer",
			apply = function(
				self: Types.SpecialKey,
				scope: Types.Scope<unknown>,
				value: unknown,
				applyTo: Instance
			)
				local event = applyTo:GetAttributeChangedSignal(attributeName)
	
				if not castToState(value) then
					External.logError("invalidAttributeOutType")
				end
				local value = value :: Types.StateObject<unknown>
				if value.kind ~= "Value" then
					External.logError("invalidAttributeOutType")
				end
				local value = value :: Types.Value<unknown>
				checkLifetime.bOutlivesA(
					scope, applyTo,
					value.scope, value.oldestTask,
					checkLifetime.formatters.attributeOutputsTo, attributeName
				)

				value:set((applyTo :: any):GetAttribute(attributeName))
				table.insert(scope, event:Connect(function()	
					value:set((applyTo :: any):GetAttribute(attributeName))
				end))
			end
		}
		keyCache[attributeName] = key
	end
	return key
end

return AttributeOut
end)() end,
    [28] = function()local wax,script,require=ImportGlobals(28)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Helper function for type checking purposes. Casts the input to a `Child`
	type, while constraining the input to be an array of `Child` - this prevents
	Luau from erroneously inferring a different array type for the input.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)

local function Child(
	x: {Types.Child}
): Types.Child
	return x
end

return Child
end)() end,
    [29] = function()local wax,script,require=ImportGlobals(29)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	A special key for property tables, which parents any given descendants into
	an instance.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
local Observer = require(Package.Graph.Observer)
local peek = require(Package.State.peek)
local castToState = require(Package.State.castToState)
local doCleanup = require(Package.Memory.doCleanup)

type Set<T> = {[T]: unknown}

-- Experimental flag: name children based on the key used in the [Children] table
local EXPERIMENTAL_AUTO_NAMING = false

return {
	type = "SpecialKey",
	kind = "Children",
	stage = "descendants",
	apply = function(
		self: Types.SpecialKey,
		scope: Types.Scope<unknown>,
		value: unknown,
		applyTo: Instance
	)
		local newParented: Set<Instance> = {}
		local oldParented: Set<Instance> = {}
	
		-- save scopes for state object observers
		local newScopes: {[Types.StateObject<unknown>]: Types.Scope<unknown>} = {}
		local oldScopes: {[Types.StateObject<unknown>]: Types.Scope<unknown>} = {}
	
		-- Rescans this key's value to find new instances to parent and state objects
		-- to observe for changes; then unparents instances no longer found and
		-- disconnects observers for state objects no longer present.
		local function updateChildren()
			oldParented, newParented = newParented, oldParented
			oldScopes, newScopes = newScopes, oldScopes
	
			local function processChild(
				child: unknown,
				autoName: string?
			)
				local childType = typeof(child)
	
				if childType == "Instance" then
					-- case 1; single instance
					local child = child :: Instance
	
					newParented[child] = true
					if oldParented[child] == nil then
						-- wasn't previously present
	
						-- TODO: check for ancestry conflicts here
						child.Parent = applyTo
					else
						-- previously here; we want to reuse, so remove from old
						-- set so we don't encounter it during unparenting
						oldParented[child] = nil
					end
	
					if EXPERIMENTAL_AUTO_NAMING and autoName ~= nil then
						child.Name = autoName
					end
	
				elseif castToState(child) then
					-- case 2; state object
					local child = child :: Types.StateObject<unknown>
	
					local value = peek(child)
					-- allow nil to represent the absence of a child
					if value ~= nil then
						processChild(value, autoName)
					end
	
					local childScope = oldScopes[child]
					if childScope == nil then
						-- wasn't previously present
						childScope = {}
						Observer(childScope, child):onChange(updateChildren)
					else
						-- previously here; we want to reuse, so remove from old
						-- set so we don't encounter it during unparenting
						oldScopes[child] = nil
					end
	
					newScopes[child] = childScope
	
				elseif childType == "table" then
					-- case 3; table of objects
					local child = child :: {[unknown]: unknown}
	
					for key, subChild in pairs(child) do
						local keyType = typeof(key)
						local subAutoName: string? = nil
	
						if keyType == "string" then
							local key = key :: string
							subAutoName = key
						elseif keyType == "number" and autoName ~= nil then
							local key = key :: number
							subAutoName = autoName .. "_" .. key
						end
	
						processChild(subChild, subAutoName)
					end
	
				else
					External.logWarn("unrecognisedChildType", childType)
				end
			end
	
			if value ~= nil then
				-- `propValue` is set to nil on cleanup, so we don't process children
				-- in that case
				processChild(value)
			end
	
			-- unparent any children that are no longer present
			for oldInstance in pairs(oldParented) do
				oldInstance.Parent = nil
			end
			table.clear(oldParented)
	
			-- disconnect observers which weren't reused
			for oldState, childScope in pairs(oldScopes) do
				doCleanup(childScope)
			end
			table.clear(oldScopes)
		end
	
		table.insert(scope, function()
			value = nil
			updateChildren()
		end)
	
		-- perform initial child parenting
		updateChildren()
	end
} :: Types.SpecialKey
end)() end,
    [30] = function()local wax,script,require=ImportGlobals(30)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Processes and returns an existing instance, with options for setting
	properties, event handlers and other attributes on the instance.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
local applyInstanceProps = require(Package.Instances.applyInstanceProps)

local function Hydrate(
	scope: Types.Scope<unknown>,
	target: Instance
)
	if target :: any == nil then
		External.logError("scopeMissing", nil, "instances using Hydrate", "myScope:Hydrate (instance) { ... }")
	end
	return function(
		props: Types.PropertyTable
	): Instance
	
		table.insert(scope, target)
		applyInstanceProps(scope, props, target)
		return target
	end
end

return Hydrate
end)() end,
    [31] = function()local wax,script,require=ImportGlobals(31)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Constructs and returns a new instance, with options for setting properties,
	event handlers and other attributes on the instance right away.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
local defaultProps = require(Package.Instances.defaultProps)
local applyInstanceProps = require(Package.Instances.applyInstanceProps)

type Component = (Types.PropertyTable) -> Instance

local function New(
	scope: Types.Scope<unknown>,
	className: string
)
	if (className :: any) == nil then
		local scope = (scope :: any) :: string
		External.logError("scopeMissing", nil, "instances using New", "myScope:New \"" .. scope .. "\" { ... }")
	end

	-- This might look appealing to try and cache. But please don't. The scope
	-- upvalue is shared between the two curried function calls, so this will
	-- open incredible cross-codebase wormholes like you've never seen before.
	return function(
		props: Types.PropertyTable
	): Instance
		local ok, instance = pcall(Instance.new, className)
		if not ok then
			External.logError("cannotCreateClass", nil, className)
		end

		local classDefaults = defaultProps[className]
		if classDefaults ~= nil then
			for defaultProp, defaultValue in pairs(classDefaults) do
				(instance :: any)[defaultProp] = defaultValue
			end
		end

		table.insert(scope, instance)
		applyInstanceProps(scope, props, instance)

		return instance
	end
end

return New
end)() end,
    [32] = function()local wax,script,require=ImportGlobals(32)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Constructs special keys for property tables which connect property change
	listeners to an instance.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)

local keyCache: {[string]: Types.SpecialKey} = {}

local function OnChange(
	propertyName: string
): Types.SpecialKey
	local key = keyCache[propertyName]
	if key == nil then
		key = {
			type = "SpecialKey",
			kind = "OnChange",
			stage = "observer",
			apply = function(
				self: Types.SpecialKey,
				scope: Types.Scope<unknown>,
				callback: unknown,
				applyTo: Instance
			)
				local ok, event = pcall(applyTo.GetPropertyChangedSignal, applyTo, propertyName)
				if not ok then
					External.logError("cannotConnectChange", nil, applyTo.ClassName, propertyName)
				elseif typeof(callback) ~= "function" then
					External.logError("invalidChangeHandler", nil, propertyName)
				else
					local callback = callback :: (...unknown) -> (...unknown)
					table.insert(scope, event:Connect(function()
						callback((applyTo :: any)[propertyName])
					end))
				end
			end
		}
		keyCache[propertyName] = key
	end
	return key
end

return OnChange
end)() end,
    [33] = function()local wax,script,require=ImportGlobals(33)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Constructs special keys for property tables which connect event listeners to
	an instance.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)

local keyCache: {[string]: Types.SpecialKey} = {}

local function getProperty_unsafe(
	instance: Instance,
	property: string
)
	return (instance :: any)[property]
end

local function OnEvent(
	eventName: string
): Types.SpecialKey
	local key = keyCache[eventName]
	if key == nil then
		key = {
			type = "SpecialKey",
			kind = "OnEvent",
			stage = "observer",
			apply = function(
				self: Types.SpecialKey,
				scope: Types.Scope<unknown>,
				callback: unknown,
				applyTo: Instance
			)
				local ok, event = pcall(getProperty_unsafe, applyTo, eventName)
				if not ok or typeof(event) ~= "RBXScriptSignal" then
					External.logError("cannotConnectEvent", nil, applyTo.ClassName, eventName)
				elseif typeof(callback) ~= "function" then
					External.logError("invalidEventHandler", nil, eventName)
				else
					table.insert(scope, event:Connect(callback :: any))
				end
			end
		}
		keyCache[eventName] = key
	end
	return key
end

return OnEvent
end)() end,
    [34] = function()local wax,script,require=ImportGlobals(34)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	A special key for property tables, which allows users to extract values from
	an instance into an automatically-updated Value object.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
-- Memory
local checkLifetime = require(Package.Memory.checkLifetime)
-- State
local castToState = require(Package.State.castToState)

local keyCache: {[string]: Types.SpecialKey} = {}

local function Out(
	propertyName: string
): Types.SpecialKey
	local key = keyCache[propertyName]
	if key == nil then
		key = {
			type = "SpecialKey",
			kind = "Out",
			stage = "observer",
			apply = function(
				self: Types.SpecialKey,
				scope: Types.Scope<unknown>,
				value: unknown,
				applyTo: Instance
			)
				local ok, event = pcall(applyTo.GetPropertyChangedSignal, applyTo, propertyName)
				if not ok then
					External.logError("invalidOutProperty", nil, applyTo.ClassName, propertyName)
				end
	
				if not castToState(value) then
					External.logError("invalidOutType")
				end
				local value = value :: Types.StateObject<unknown>
				if value.kind ~= "Value" then
					External.logError("invalidOutType")
				end
				local value = value :: Types.Value<unknown>
				checkLifetime.bOutlivesA(
					scope, applyTo, 
					value.scope, value.oldestTask,
					checkLifetime.formatters.propertyOutputsTo, propertyName
				)

				value:set((applyTo :: any)[propertyName])
				table.insert(
					scope,
					event:Connect(function()
						value:set((applyTo :: any)[propertyName])
					end)
				)
			end
		}
		keyCache[propertyName] = key
	end
	return key
end

return Out
end)() end,
    [35] = function()local wax,script,require=ImportGlobals(35)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Applies a table of properties to an instance, including binding to any
	given state objects and applying any special keys.

	No strong reference is kept by default - special keys should take care not
	to accidentally hold strong references to instances forever.

	If a key is used twice, an error will be thrown. This is done to avoid
	double assignments or double bindings. However, some special keys may want
	to enable such assignments - in which case unique keys should be used for
	each occurence.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
-- Logging
local parseError = require(Package.Logging.parseError)
-- Memory
local checkLifetime = require(Package.Memory.checkLifetime)
-- Graph
local Observer = require(Package.Graph.Observer)
-- State
local castToState = require(Package.State.castToState)
local peek = require(Package.State.peek)
-- Utility
local xtypeof = require(Package.Utility.xtypeof)

local function setProperty_unsafe(
	instance: Instance,
	property: string,
	value: unknown
)
	(instance :: any)[property] = value
end

local function testPropertyAssignable(
	instance: Instance,
	property: string
)
	(instance :: any)[property] = (instance :: any)[property]
end

local function setProperty(
	instance: Instance,
	property: string,
	value: unknown
)
	local success, err = xpcall(setProperty_unsafe :: any, parseError, instance, property, value)

	if not success then
		if not pcall(testPropertyAssignable, instance, property) then
			External.logErrorNonFatal("cannotAssignProperty", nil, instance.ClassName, property)
		else
			-- property is assignable, but this specific assignment failed
			-- this typically implies the wrong type was received
			local givenType = typeof(value)
			local expectedType = typeof((instance :: any)[property])

			if givenType == expectedType then
				External.logErrorNonFatal("propertySetError", err)
			else
				External.logErrorNonFatal("invalidPropertyType", nil, instance.ClassName, property, expectedType, givenType)
			end
		end
	end
end

local function bindProperty(
	scope: Types.Scope<unknown>,
	instance: Instance,
	property: string,
	value: Types.UsedAs<unknown>
)
	if castToState(value) then
		local value = value :: Types.StateObject<unknown>
		checkLifetime.bOutlivesA(
			scope, instance,
			value.scope, value.oldestTask,
			checkLifetime.formatters.boundProperty, property
		)
		-- value is a state object - bind to changes
		Observer(scope, value :: any):onBind(function()
			setProperty(instance, property, peek(value))
		end)
	else
		-- value is a constant - assign once only
		setProperty(instance, property, value)
	end
end

local function applyInstanceProps(
	scope: Types.Scope<unknown>,
	props: Types.PropertyTable,
	applyTo: Instance
)
	local specialKeys = {
		self = {} :: {[Types.SpecialKey]: unknown},
		descendants = {} :: {[Types.SpecialKey]: unknown},
		ancestor = {} :: {[Types.SpecialKey]: unknown},
		observer = {} :: {[Types.SpecialKey]: unknown}
	}

	for key, value in pairs(props) do
		local keyType = xtypeof(key)

		if keyType == "string" then
			if key ~= "Parent" then
				bindProperty(scope, applyTo, key :: string, value)
			end
		elseif keyType == "SpecialKey" then
			local stage = (key :: Types.SpecialKey).stage
			local keys = specialKeys[stage]
			if keys == nil then
				External.logError("unrecognisedPropertyStage", nil, stage)
			else
				keys[key] = value
			end
		else
			-- we don't recognise what this key is supposed to be
			External.logError("unrecognisedPropertyKey", nil, keyType)
		end
	end

	for key, value in pairs(specialKeys.self) do
		key:apply(scope, value, applyTo)
	end
	for key, value in pairs(specialKeys.descendants) do
		key:apply(scope, value, applyTo)
	end

	if props.Parent ~= nil then
		bindProperty(scope, applyTo, "Parent", props.Parent)
	end

	for key, value in pairs(specialKeys.ancestor) do
		key:apply(scope, value, applyTo)
	end
	for key, value in pairs(specialKeys.observer) do
		key:apply(scope, value, applyTo)
	end
end

return applyInstanceProps
end)() end,
    [36] = function()local wax,script,require=ImportGlobals(36)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Stores 'sensible default' properties to be applied to instances created by
	the New function.
]]

return {
	ScreenGui = {
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	},

	BillboardGui = {
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Active = true
	},

	SurfaceGui = {
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 50
	},

	Frame = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0
	},

	ScrollingFrame = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,

		ScrollBarImageColor3 = Color3.new(0, 0, 0)
	},

	TextLabel = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,

		Font = Enum.Font.SourceSans,
		Text = "",
		TextColor3 = Color3.new(0, 0, 0),
		TextSize = 14
	},

	TextButton = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,

		AutoButtonColor = false,

		Font = Enum.Font.SourceSans,
		Text = "",
		TextColor3 = Color3.new(0, 0, 0),
		TextSize = 14
	},

	TextBox = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,

		ClearTextOnFocus = false,

		Font = Enum.Font.SourceSans,
		Text = "",
		TextColor3 = Color3.new(0, 0, 0),
		TextSize = 14
	},

	ImageLabel = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0
	},

	ImageButton = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,

		AutoButtonColor = false
	},

	ViewportFrame = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0
	},

	VideoFrame = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0
	},
	
	CanvasGroup = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0
	},

	SpawnLocation = {
		Duration = 0
	},

	BoxHandleAdornment = {
		ZIndex = 0
	},
	ConeHandleAdornment = {
		ZIndex = 0
	},
	CylinderHandleAdornment = {
		ZIndex = 0
	},
	ImageHandleAdornment = {
		ZIndex = 0
	},
	LineHandleAdornment = {
		ZIndex = 0
	},
	SphereHandleAdornment = {
		ZIndex = 0
	},
	WireframeHandleAdornment = {
		ZIndex = 0
	},
	
	Part = {
		Anchored = true,
		Size = Vector3.one,
		FrontSurface = Enum.SurfaceType.Smooth,
		BackSurface = Enum.SurfaceType.Smooth,
		LeftSurface = Enum.SurfaceType.Smooth,
		RightSurface = Enum.SurfaceType.Smooth,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	},
	
	TrussPart = {
		Anchored = true,
		Size = Vector3.one * 2,
		FrontSurface = Enum.SurfaceType.Smooth,
		BackSurface = Enum.SurfaceType.Smooth,
		LeftSurface = Enum.SurfaceType.Smooth,
		RightSurface = Enum.SurfaceType.Smooth,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	},

	MeshPart = {
		Anchored = true,
		Size = Vector3.one,
		FrontSurface = Enum.SurfaceType.Smooth,
		BackSurface = Enum.SurfaceType.Smooth,
		LeftSurface = Enum.SurfaceType.Smooth,
		RightSurface = Enum.SurfaceType.Smooth,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	},

	CornerWedgePart = {
		Anchored = true,
		Size = Vector3.one,
		FrontSurface = Enum.SurfaceType.Smooth,
		BackSurface = Enum.SurfaceType.Smooth,
		LeftSurface = Enum.SurfaceType.Smooth,
		RightSurface = Enum.SurfaceType.Smooth,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	},

	VehicleSeat = {
		Anchored = true,
		Size = Vector3.one,
		FrontSurface = Enum.SurfaceType.Smooth,
		BackSurface = Enum.SurfaceType.Smooth,
		LeftSurface = Enum.SurfaceType.Smooth,
		RightSurface = Enum.SurfaceType.Smooth,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	},
}
end)() end,
    [38] = function()local wax,script,require=ImportGlobals(38)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Formats a Fusion-specific error message.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local messages = require(Package.Logging.messages)

local ERROR_INFO_URL = "https://elttob.uk/Fusion/0.3/api-reference/general/errors/#"

local function formatError(
	externalProvider: Types.ExternalProvider?,
	messageID: string,
	errorOrTrace: Types.Error | string | nil,
	...: unknown
): string
	local originalMessageID = messageID
	local error: Types.Error? = if typeof(errorOrTrace) == "table" then errorOrTrace else nil
	local trace: string? = if typeof(errorOrTrace) == "table" then errorOrTrace.trace else errorOrTrace
	local messageText = messages[messageID]
	if messageText == nil then
		messageID = "unknownMessage"
		messageText = messages[messageID]
	end
	messageText = messageText:format(...)
	if error ~= nil then
		messageText = messageText:gsub("ERROR_MESSAGE", error.message)
		if error.context ~= nil then
			messageText ..= ` ({error.context})`
		end
	else
		messageText = messageText:gsub("ERROR_MESSAGE", originalMessageID)
	end
	messageText = `[Fusion] {messageText} \nID: {messageID}`
	if externalProvider ~= nil and externalProvider.policies.allowWebLinks then
		messageText ..= `\nLearn more: {ERROR_INFO_URL}{messageID:lower()}`
	end
	if trace ~= nil then
		messageText ..= ` \n---- Stack trace ----\n{trace}`
	end
	return messageText:gsub("\n", "\n    ")
end

return formatError
end)() end,
    [39] = function()local wax,script,require=ImportGlobals(39)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Stores templates for different kinds of logging messages.
]]

return {
	callbackError = "Error in callback:\nERROR_MESSAGE",
	cannotAssignProperty = "The class type '%s' has no assignable property '%s'.",
	cannotConnectChange = "The %s class doesn't have a property called '%s'.",
	cannotConnectEvent = "The %s class doesn't have an event called '%s'.",
	cannotCreateClass = "Can't create a new instance of class '%s'.",
	cannotDepend = "%s can't depend on %s.",
	cleanupWasRenamed = "`Fusion.cleanup` was renamed to `Fusion.doCleanup`. This will be an error in future versions of Fusion.",
	destroyedTwice = "`doCleanup()` was given something that it is already cleaning up. Unclear how to proceed.",
	destructorRedundant = "%s destructors no longer do anything. If you wish to run code on destroy, `table.insert` a function into the `scope` argument. See discussion #292 on GitHub for advice.",
	forKeyCollision = "The key '%s' was returned multiple times simultaneously, which is not allowed in `For` objects.",
	infiniteLoop = "Detected an infinite loop. Consider adding an explicit breakpoint to your code to prevent a cyclic dependency.",
	invalidAttributeChangeHandler = "The change handler for the '%s' attribute must be a function.",
	invalidAttributeOutType = "[AttributeOut] properties must be given Value objects.",
	invalidChangeHandler = "The change handler for the '%s' property must be a function.",
	invalidEventHandler = "The handler for the '%s' event must be a function.",
	invalidOutProperty = "The %s class doesn't have a property called '%s'.",
	invalidOutType = "[Out] properties must be given Value objects.",
	invalidPropertyType = "'%s.%s' expected a '%s' type, but got a '%s' type.",
	invalidRefType = "Instance refs must be Value objects.",
	invalidSpringDamping = "The damping ratio for a spring must be >= 0. (damping was %.2f)",
	invalidSpringSpeed = "The speed of a spring must be >= 0. (speed was %.2f)",
	mergeConflict = "Multiple definitions for '%s' found while merging.",
	mistypedSpringDamping = "The damping ratio for a spring must be a number. (got a %s)",
	mistypedSpringSpeed = "The speed of a spring must be a number. (got a %s)",
	mistypedTweenInfo = "The tween info of a tween must be a TweenInfo. (got a %s)",
	noTaskScheduler = "Fusion is not connected to an external task scheduler.",
	poisonedScope = "Attempted to use a scope after it's been destroyed; %s",
	possiblyOutlives = "%s will be destroyed before %s; %s. To fix this, review the order they're created in, and what scopes they belong to. See discussion #292 on GitHub for advice.",
	propertySetError = "Error setting property:\nERROR_MESSAGE",
	scopeMissing = "To create %s, provide a scope. (e.g. `%s`). See discussion #292 on GitHub for advice.",
	springNanGoal = "A spring was given a NaN goal, so some simulation has been skipped. Ensure no springs have NaN goals.",
	springNanMotion = "A spring encountered NaN during motion, so has snapped to the goal position. Ensure no springs have NaN positions or velocities.",
	springTypeMismatch = "The type '%s' doesn't match the spring's type '%s'.",
	stateGetWasRemoved = "`StateObject:get()` has been replaced by `use()` and `peek()` - see discussion #217 on GitHub.",
	tweenNanGoal = "A tween was given a NaN goal, so some animation has been skipped. Ensure no tweens have NaN goals.",
	tweenNanMotion = "A tween encountered NaN during motion, so has snapped to the goal. Ensure no tweens have NaN in their tween infos.",
	unknownMessage = "Unknown error:\nERROR_MESSAGE",
	unrecognisedChildType = "'%s' type children aren't accepted by `[Children]`.",
	unrecognisedPropertyKey = "'%s' keys aren't accepted in property tables.",
	unrecognisedPropertyStage = "'%s' isn't a valid stage for a special key to be applied at.",
	useAfterDestroy = "%s is no longer valid - it was destroyed before %s. See discussion #292 on GitHub for advice."
}
end)() end,
    [40] = function()local wax,script,require=ImportGlobals(40)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	An xpcall() error handler to collect and parse useful information about
	errors, such as clean messages and stack traces.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)

local function parseError(
	err: string
): Types.Error
	return {
		type = "Error",
		raw = err,
		message = err:gsub("^.+:%d+:%s*", ""),
		trace = debug.traceback(nil, 2)
	}
end

return parseError
end)() end,
    [42] = function()local wax,script,require=ImportGlobals(42)local ImportGlobals return (function(...)

--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Procedures for checking lifetimes and printing helpful warnings about them.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
local whichLivesLonger = require(Package.Memory.whichLivesLonger)
local nameOf = require(Package.Utility.nameOf)

local checkLifetime = {}

checkLifetime.formatters = {}

function checkLifetime.formatters.useFunction(
	self: unknown,
	used: unknown
): (string, string)
	local selfName = nameOf(self, "object")
	local usedName = nameOf(used, "object")
	return `The use()-d {usedName}`, `the {selfName}`
end
	
function checkLifetime.formatters.boundProperty(
	instance: Instance,
	bound: unknown,
	property: string
): (string, string)
	local selfName = instance.Name
	local boundName = nameOf(bound, "value")
	return `The {boundName} (bound to the {property} property)`, `the {selfName} instance`
end

function checkLifetime.formatters.boundAttribute(
	instance: Instance,
	bound: unknown,
	attribute: string
): (string, string)
	local selfName = instance.Name
	local boundName = nameOf(bound, "value")
	return `The {boundName} (bound to the {attribute} attribute)`, `the {selfName} instance`
end

function checkLifetime.formatters.propertyOutputsTo(
	instance: Instance,
	bound: unknown,
	property: string
): (string, string)
	local selfName = instance.Name
	local boundName = nameOf(bound, "object")
	return `The {boundName} (which the {property} property outputs to)`, `the {selfName} instance`
end

function checkLifetime.formatters.attributeOutputsTo(
	instance: Instance,
	bound: unknown,
	attribute: string
): (string, string)
	local selfName = instance.Name
	local boundName = nameOf(bound, "object")
	return `The {boundName} (which the {attribute} attribute outputs to)`, `the {selfName} instance`
end

function checkLifetime.formatters.refOutputsTo(
	instance: Instance,
	bound: unknown
): (string, string)
	local selfName = instance.Name
	local boundName = nameOf(bound, "object")
	return `The {boundName} (which the Ref key outputs to)`, `the {selfName} instance`
end

function checkLifetime.formatters.animationGoal(
	self: unknown,
	goal: unknown
): (string, string)
	local selfName = nameOf(self, "object")
	local goalName = nameOf(goal, "object")
	return `The goal {goalName}`, `the {selfName} that is following it`
end

function checkLifetime.formatters.parameter(
	self: unknown,
	used: unknown,
	parameterName: string | false
): (string, string)
	local selfName = nameOf(self, "object")
	local usedName = nameOf(used, "object")
	if parameterName == false then
		return `The {usedName} parameter`, `the {selfName} that it was used for`
	else
		return `The {usedName} representing the {parameterName} parameter`, `the {selfName} that it was used for`
	end
end

function checkLifetime.formatters.observer(
	self: unknown,
	watched: unknown
): (string, string)
	local selfName = nameOf(self, "object")
	local watchedName = nameOf(watched, "object")
	return `The watched {watchedName}`, `the {selfName} that's observing it for changes`
end

function checkLifetime.bOutlivesA<A, B, Args...>(
	scopeA: Types.Scope<unknown>,
	a: A,
	scopeB: Types.Scope<unknown>?,
	b: B,
	formatter: (a: A, b: B, Args...) -> (string, string),
	...: Args...
)
	if scopeB == nil then
		External.logError("useAfterDestroy", nil, formatter(a, b, ...))
	elseif whichLivesLonger(scopeA, a, scopeB, b) == "definitely-a" then
		local aName, bName = formatter(a, b, ...)
		External.logWarn(
			"possiblyOutlives",
			aName, bName, 
			if scopeA == scopeB then
				"they're in the same scope, but the latter is destroyed too quickly"
			else
				"the latter is in a different scope that gets destroyed too quickly"
		)
	end
end
return checkLifetime
end)() end,
    [43] = function()local wax,script,require=ImportGlobals(43)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Creates an empty scope with the same metatables as the original scope. Used
	for preserving access to constructors when creating inner scopes.

	This is the public version of the function, which implements external
	debugging hooks.
]]
local Package = script.Parent.Parent
local Types = require(Package.Types)
local ExternalDebug = require(Package.ExternalDebug)
local deriveScopeImpl = require(Package.Memory.deriveScopeImpl)

local function deriveScope(...)
	local scope = deriveScopeImpl(...)
	ExternalDebug.trackScope(scope)
	return scope
end

return deriveScope :: Types.DeriveScopeConstructor
end)() end,
    [44] = function()local wax,script,require=ImportGlobals(44)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Creates an empty scope with the same metatables as the original scope. Used
	for preserving access to constructors when creating inner scopes.

	This is the internal version of the function, which does not implement
	external debugging hooks.
]]
local Package = script.Parent.Parent
local Types = require(Package.Types)
local merge = require(Package.Utility.merge)
local scopePool = require(Package.Memory.scopePool)

-- This return type is technically a lie, but it's required for useful type
-- checking behaviour.
local function deriveScopeImpl<T>(
	existing: Types.Scope<T>,
	methods: {[unknown]: unknown}?,
	...: {[unknown]: unknown}
): any
	local metatable = getmetatable(existing)
	if methods ~= nil then
		metatable = table.clone(metatable)
		metatable.__index = merge(
			true, {}, 
			metatable.__index, 
			merge(
				false, {},
				methods, 
				...
			)
		)
	end
	local scope = setmetatable(
		scopePool.reuseAny() :: any or {},
		metatable
	)
	return scope
end

return (deriveScopeImpl :: any) :: Types.DeriveScopeConstructor
end)() end,
    [45] = function()local wax,script,require=ImportGlobals(45)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Cleans up the tasks passed in as the arguments.
	A task can be any of the following:

	- an Instance - will be destroyed
	- an RBXScriptConnection - will be disconnected
	- a function - will be run
	- a table with a `Destroy` or `destroy` function - will be called
	- an array - `cleanup` will be called on each item
]]
local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
local scopePool = require(Package.Memory.scopePool)
local poisonScope = require(Package.Memory.poisonScope)

local alreadyDestroying: {[Types.Task]: true} = {}

local function doCleanup(
	task: Types.Task
): ()
	if alreadyDestroying[task] then
		return External.logError("destroyedTwice")
	end
	alreadyDestroying[task] = true

	-- case 1: Instance
	if typeof(task) == "Instance" then
		task:Destroy()

	-- case 2: RBXScriptConnection
	elseif typeof(task) == "RBXScriptConnection" then
		task:Disconnect()

	-- case 3: callback
	elseif typeof(task) == "function" then
		task()

	elseif typeof(task) == "table" then
		local task = (task :: any) :: {Destroy: (...unknown) -> (...unknown)?, destroy: (...unknown) -> (...unknown)?}

		-- case 4: destroy() function
		if typeof(task.destroy) == "function" then
			local task = (task :: any) :: {destroy: (...unknown) -> (...unknown)}
			task:destroy()

		-- case 5: Destroy() function
		elseif typeof(task.Destroy) == "function" then
			local task = (task :: any) :: {Destroy: (...unknown) -> (...unknown)}
			task:Destroy()

		-- case 6: table of tasks with an array part
		elseif task[1] ~= nil then
			local task = task :: {Types.Task}

			-- It is important to iterate backwards through the table, since
			-- objects are added in order of construction.
			for index = #task, 1, -1 do
				doCleanup(task[index])
				task[index] = nil
			end

			if External.isTimeCritical() then
				scopePool.giveIfEmpty(task)
			else
				poisonScope(task, "`doCleanup()` was previously called on this scope. Ensure you are not reusing scopes after cleanup.")
			end
		end
	end
	
	alreadyDestroying[task] = nil
end

return doCleanup
end)() end,
    [46] = function()local wax,script,require=ImportGlobals(46)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Derives a new scope that's destroyed exactly once, whether by the user or by
	the scope that it's inside of.
]]
local Package = script.Parent.Parent
local Types = require(Package.Types)
local ExternalDebug = require(Package.ExternalDebug)
local deriveScopeImpl = require(Package.Memory.deriveScopeImpl)

local function innerScope<T>(
	existing: Types.Scope<T>,
	...: {[unknown]: unknown}
): any
	local new = deriveScopeImpl(existing, ...)
	table.insert(existing, new)
	table.insert(
		new, 
		function()
			local index = table.find(existing, new)
			if index ~= nil then
				table.remove(existing, index)
			end
		end
	)
	ExternalDebug.trackScope(new)
	return new
end

return (innerScope :: any) :: Types.DeriveScopeConstructor
end)() end,
    [47] = function()local wax,script,require=ImportGlobals(47)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
local doCleanup = require(Package.Memory.doCleanup)

local function legacyCleanup(
	value: Types.Task
)
	External.logWarn("cleanupWasRenamed")
	return doCleanup(value)
end

return legacyCleanup
end)() end,
    [48] = function()local wax,script,require=ImportGlobals(48)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Returns true if the given value is not automatically memory managed, and
	requires manual cleanup.
]]

local function needsDestruction(
	x: unknown
): boolean
	return typeof(x) == "Instance"
end

return needsDestruction
end)() end,
    [49] = function()local wax,script,require=ImportGlobals(49)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	'Poisons' the given scope; if the scope is used again, then it will cause
	the program to crash.
]]
local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)

local function poisonScope(
	scope: Types.Scope,
	context: string
): ()
	local mt = getmetatable(scope)
	if typeof(mt) == "table" and mt._FUSION_POISONED then
		return
	end
	table.clear(scope)
	setmetatable(scope :: any, {
		_FUSION_POISONED = true,
		__index = function()
			External.logError("poisonedScope", nil, context)
		end,
		__newindex = function()
			External.logError("poisonedScope", nil, context)
		end
	})
end

return poisonScope
end)() end,
    [50] = function()local wax,script,require=ImportGlobals(50)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

local Package = script.Parent.Parent
local Types = require(Package.Types)
local poisonScope = require(Package.Memory.poisonScope)
local ExternalDebug = require(Package.ExternalDebug)

local ENABLE_POOLING = false
local MAX_POOL_SIZE = 16 -- TODO: need to test what an ideal number for this is

local pool = {}
local poolSize = 0

return {
	giveIfEmpty = function<S>(
		scope: Types.Scope<S>
	): Types.Scope<S>?
		if next(scope) == nil then
			ExternalDebug.untrackScope(scope)
			if ENABLE_POOLING and poolSize < MAX_POOL_SIZE then
				poolSize += 1
				pool[poolSize] = scope
			else
				poisonScope(scope, "previously passed to the internal scope pool, which indicates a Fusion bug.")
			end
			return nil
		else
			return scope
		end
	end,
	clearAndGive = function(
		scope: Types.Scope<unknown>
	)
		ExternalDebug.untrackScope(scope)
		table.clear(scope)
		if ENABLE_POOLING and poolSize < MAX_POOL_SIZE then
			poolSize += 1
			pool[poolSize] = scope :: any
		else
			poisonScope(scope, "previously passed to the internal scope pool, which indicates a Fusion bug.")
		end
	end,
	reuseAny = function(): Types.Scope<unknown>
		if poolSize == 0 then
			return nil :: any
		else
			local scope = pool[poolSize]
			poolSize -= 1
			return scope
		end
	end
}
end)() end,
    [51] = function()local wax,script,require=ImportGlobals(51)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Creates cleanup tables with access to constructors as methods.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local ExternalDebug = require(Package.ExternalDebug)
local merge = require(Package.Utility.merge)
local scopePool = require(Package.Memory.scopePool)

local function scoped(
	...: {[unknown]: unknown}
): any
	local scope = setmetatable(
		scopePool.reuseAny() :: any or {},
		{__index = merge(false, {}, ...)}
	) :: any
	ExternalDebug.trackScope(scope)
	return scope
end

return (scoped :: any) :: Types.ScopedConstructor
end)() end,
    [52] = function()local wax,script,require=ImportGlobals(52)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Calculates how the lifetimes of the two values relate. Specifically, it
	calculates which value will be destroyed earlier or later, if it is possible
	to infer this from their scopes.
]]
local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)

local function whichScopeLivesLonger(
	scopeA: Types.Scope<unknown>,
	scopeB: Types.Scope<unknown>
): "definitely-a" | "definitely-b" | "unsure"
	-- If we can prove one scope is inside of the other scope, then the outer
	-- scope must live longer than the inner scope (assuming idiomatic scopes).
	-- So, we will search the scopes recursively until we find one of them, at
	-- which point we know they must have been found inside the other scope.
	local openSet: {Types.Scope<unknown>} = {scopeA, scopeB}
	local nextOpenSet: {Types.Scope<unknown>} = {}
	local openSetSize, nextOpenSetSize = 2, 0
	local closedSet = {}
	while openSetSize > 0 do
		for _, scope in openSet do
			closedSet[scope] = true
			for _, inScope in ipairs(scope) do
				if inScope == scopeA then
					return "definitely-b"
				elseif inScope == scopeB then
					return "definitely-a"
				elseif typeof(inScope) == "table" then
					local inScope = inScope :: {unknown}
					if inScope[1] ~= nil and closedSet[scope] == nil then
						nextOpenSetSize += 1
						nextOpenSet[nextOpenSetSize] = inScope :: Types.Scope<unknown>
					end
				end 
			end
		end
		table.clear(openSet)
		openSet, nextOpenSet = nextOpenSet, openSet
		openSetSize, nextOpenSetSize = nextOpenSetSize, 0
	end
	return "unsure"
end

local function whichLivesLonger(
	scopeA: Types.Scope<unknown>,
	a: unknown,
	scopeB: Types.Scope<unknown>,
	b: unknown
): "definitely-a" | "definitely-b" | "unsure"
	if External.isTimeCritical() then
		return "unsure"
	elseif scopeA == scopeB then
		local scopeA: {unknown} = scopeA
		for index = #scopeA, 1, -1 do
			local value = scopeA[index]
			if value == a then
				return "definitely-b"
			elseif value == b then
				return "definitely-a"
			end
		end
		return "unsure"
	else
		return whichScopeLivesLonger(scopeA, scopeB)
	end
end

return whichLivesLonger
end)() end,
    [53] = function()local wax,script,require=ImportGlobals(53)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow

--[[
	Roblox implementation for Fusion's abstract provider layer.
]]

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Package = script.Parent
local External = require(Package.External)

local RobloxExternal = {}

RobloxExternal.policies = {
	allowWebLinks = RunService:IsStudio()
}

--[[
   Sends an immediate task to the external provider. Throws if none is set.
]]
function RobloxExternal.doTaskImmediate(
	resume: () -> ()
)
   task.spawn(resume)
end

--[[
	Sends a deferred task to the external provider. Throws if none is set.
]]
function RobloxExternal.doTaskDeferred(
	resume: () -> ()
)
	task.defer(resume)
end

--[[
	Errors in a different thread to preserve the flow of execution.
]]
function RobloxExternal.logErrorNonFatal(
	errorString: string
)
	task.spawn(error, errorString, 0)
end

--[[
	Shows a warning message in the output.
]]
RobloxExternal.logWarn = warn

--[[
	Sends an update step to Fusion using the Roblox clock time.
]]
local function performUpdateStep()
	External.performUpdateStep(os.clock())
end

--[[
	Binds Fusion's update step to RunService step events.
]]
local stopSchedulerFunc = nil :: (() -> ())?
function RobloxExternal.startScheduler()
	if stopSchedulerFunc ~= nil then
		return
	end
	if RunService:IsClient() then
		-- In cases where multiple Fusion modules are running simultaneously,
		-- this prevents collisions.
		local id = "FusionUpdateStep_" .. HttpService:GenerateGUID()
		RunService:BindToRenderStep(
			id,
			Enum.RenderPriority.First.Value,
			performUpdateStep
		)
		stopSchedulerFunc = function()
			RunService:UnbindFromRenderStep(id)
		end
	else
		local connection = RunService.Heartbeat:Connect(performUpdateStep)
		stopSchedulerFunc = function()
			connection:Disconnect()
		end
	end
end

--[[
	Unbinds Fusion's update step from RunService step events.
]]
function RobloxExternal.stopScheduler()
	if stopSchedulerFunc ~= nil then
		stopSchedulerFunc()
		stopSchedulerFunc = nil
	end
end

return RobloxExternal
end)() end,
    [55] = function()local wax,script,require=ImportGlobals(55)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	A specialised state object for tracking single values computed from a
	user-defined computation.

	https://elttob.uk/Fusion/0.3/api-reference/state/types/computed/
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
-- Logging
local parseError = require(Package.Logging.parseError)
-- Utility
local isSimilar = require(Package.Utility.isSimilar)
local never = require(Package.Utility.never)
-- Graph
local depend = require(Package.Graph.depend)
-- State
local castToState = require(Package.State.castToState)
local peek = require(Package.State.peek)
-- Memory
local doCleanup = require(Package.Memory.doCleanup)
local deriveScope = require(Package.Memory.deriveScope)
local checkLifetime = require(Package.Memory.checkLifetime)
local scopePool = require(Package.Memory.scopePool)
-- Utility
local nicknames = require(Package.Utility.nicknames)

type Self<T, S> = Types.Computed<T> & {
	_innerScope: Types.Scope<S>?,
	_processor: (Types.Use, Types.Scope<S>) -> T
}

local class = {}
class.type = "State"
class.kind = "Computed"
class.timeliness = "lazy"

local METATABLE = table.freeze {__index = class}

local function Computed<T, S>(
	scope: S & Types.Scope<unknown>,
	processor: (Types.Use, S) -> T,
	destructor: unknown?
): Types.Computed<T>
	local createdAt = os.clock()
	if typeof(scope) == "function" then
		External.logError("scopeMissing", nil, "Computeds", "myScope:Computed(function(use, scope) ... end)")
	elseif destructor ~= nil then
		External.logWarn("destructorRedundant", "Computed")
	end
	local self: Self<T, S> = setmetatable(
		{
			createdAt = createdAt,
			dependencySet = {},
			dependentSet = {},
			lastChange = nil,
			scope = scope,
			validity = "invalid",
			_EXTREMELY_DANGEROUS_usedAsValue = nil,
			_innerScope = nil,
			_processor = processor
		}, 
		METATABLE
	) :: any
	local destroy = function()
		self.scope = nil
		for dependency in pairs(self.dependencySet) do
			dependency.dependentSet[self] = nil
		end
		if self._innerScope ~= nil then
			doCleanup(self._innerScope)
		end
	end
	self.oldestTask = destroy
	nicknames[self.oldestTask] = "Computed"
	table.insert(scope, destroy)
	return self
end

function class.get<T, S>(
	_self: Self<T, S>
): never
	External.logError("stateGetWasRemoved")
	return never()
end

function class._evaluate<T, S>(
	self: Self<T, S>
): boolean
	if self.scope == nil then
		return false
	end
	local outerScope = self.scope :: S & Types.Scope<unknown>
	local innerScope = deriveScope(outerScope)
	local function use<T>(target: Types.UsedAs<T>): T
		local targetState = castToState(target)
		if targetState ~= nil then
			checkLifetime.bOutlivesA(
				outerScope, self.oldestTask, 
				targetState.scope, targetState.oldestTask, 
				checkLifetime.formatters.useFunction
			)
			depend(self, targetState)
		end
		return peek(target)
	end
	local ok, newValue = xpcall(self._processor, parseError, use, innerScope)
	local innerScope = scopePool.giveIfEmpty(innerScope)
	if ok then
		local similar = isSimilar(self._EXTREMELY_DANGEROUS_usedAsValue, newValue)
		if self._innerScope ~= nil then
			doCleanup(self._innerScope)
		end
		self._innerScope = innerScope

		self._EXTREMELY_DANGEROUS_usedAsValue = newValue
		return not similar
	else
		local errorObj = (newValue :: any) :: Types.Error
		if innerScope ~= nil then
			doCleanup(innerScope)
		end
		innerScope = nil
		
		-- this needs to be non-fatal, because otherwise it'd disrupt the
		-- update process
		External.logErrorNonFatal("callbackError", errorObj)
		return false
	end
end

table.freeze(class)
return Computed :: Types.ComputedConstructor
end)() end,
    [56] = function()local wax,script,require=ImportGlobals(56)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	The generic implementation for all `For` objects.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
-- Graph
local depend = require(Package.Graph.depend)
-- State
local peek = require(Package.State.peek)
local castToState = require(Package.State.castToState)
local ForTypes = require(Package.State.For.ForTypes)
-- Utility
local never = require(Package.Utility.never)
local nicknames = require(Package.Utility.nicknames)

local Disassembly = require(Package.State.For.Disassembly)

type Self<S, KI, KO, VI, VO> = Types.For<KO, VO> & {
	_disassembly: ForTypes.Disassembly<S, KI, KO, VI, VO>
}

local class = {}
class.type = "State"
class.kind = "For"
class.timeliness = "lazy"

local METATABLE = table.freeze {__index = class}

local function For<S, KI, KO, VI, VO>(
	scope: Types.Scope<S>,
	inputTable: Types.UsedAs<{[KI]: VI}>,
	constructor: (
		Types.Scope<S>,
		initialKey: KI,
		initialValue: VI
	) -> ForTypes.SubObject<S, KI, KO, VI, VO>
): Types.For<KO, VO>
	local createdAt = os.clock()
	local self: Self<S, KI, KO, VI, VO> = setmetatable(
		{
			createdAt = createdAt,
			dependencySet = {},
			dependentSet = {},
			scope = scope,
			validity = "invalid",
			_EXTREMELY_DANGEROUS_usedAsValue = {},
			_disassembly = Disassembly(
				scope,
				inputTable,
				constructor
			)
		}, 
		METATABLE
	) :: any

	local destroy = function()
		self.scope = nil
		for dependency in pairs(self.dependencySet) do
			dependency.dependentSet[self] = nil
		end
	end
	self.oldestTask = destroy
	nicknames[self.oldestTask] = "For"
	table.insert(scope, destroy)

	return self
end

function class.get<S, KI, KO, VI, VO>(
	_self: Self<S, KI, KO, VI, VO>
): never
	External.logError("stateGetWasRemoved")
	return never()
end

function class._evaluate<S, KI, KO, VI, VO>(
	self: Self<S, KI, KO, VI, VO>
): boolean
	if self.scope == nil then
		return false
	end
	local outerScope = self.scope :: S & Types.Scope<unknown>

	depend(self, self._disassembly)
	table.clear(self._EXTREMELY_DANGEROUS_usedAsValue)
	self._disassembly:populate(
		function<T>(
			maybeState: Types.UsedAs<T>
		): T
			local state = castToState(maybeState)
			if state ~= nil then
				depend(self, state)
			end
			return peek(maybeState)
		end,
		self._EXTREMELY_DANGEROUS_usedAsValue
	)

	return true
end

table.freeze(class)
return For
end)() end,
    [57] = function()local wax,script,require=ImportGlobals(57)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Breaks down an input table into reactive sub-objects for each pair.
]]

local Package = script.Parent.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
-- Graph
local depend = require(Package.Graph.depend)
-- State
local peek = require(Package.State.peek)
local castToState = require(Package.State.castToState)
local ForTypes = require(Package.State.For.ForTypes)
-- Memory
local doCleanup = require(Package.Memory.doCleanup)
local deriveScope = require(Package.Memory.deriveScope)
local scopePool = require(Package.Memory.scopePool)
-- Utility
local nameOf = require(Package.Utility.nameOf)
local nicknames = require(Package.Utility.nicknames)

type Self<S, KI, KO, VI, VO> = ForTypes.Disassembly<S, KI, KO, VI, KO> & {
	scope: (S & Types.Scope<unknown>)?,
	_inputTable: Types.UsedAs<{[KI]: VI}>,
	_constructor: (
		Types.Scope<S>,
		initialKey: KI,
		initialValue: VI
	) -> ForTypes.SubObject<S, KI, KO, VI, VO>,
	_subObjects: {[ForTypes.SubObject<S, KI, KO, VI, VO>]: true}
}


local class = {}
class.type = "Graph"
class.kind = "For.Disassembly"
class.timeliness = "lazy"

local METATABLE = table.freeze {__index = class}

local function Disassembly<S, KI, KO, VI, VO>(
	scope: S & Types.Scope<unknown>,
	inputTable: Types.UsedAs<{[KI]: VI}>,
	constructor: (
		Types.Scope<S>,
		initialKey: KI,
		initialValue: VI
	) -> ForTypes.SubObject<S, KI, KO, VI, VO>
): ForTypes.Disassembly<S, KI, KO, VI, KO>
	local createdAt = os.clock()
	local self = setmetatable(
		{
			createdAt = createdAt,
			dependencySet = {},
			dependentSet = {},
			scope = scope,
			validity = "invalid",
			_inputTable = inputTable,
			_constructor = constructor,
			_subObjects = {}
		}, 
		METATABLE
	) :: any

	local destroy = function()
		self.scope = nil
		for dependency in pairs(self.dependencySet) do
			dependency.dependentSet[self] = nil
		end
		for subObject in self._subObjects do
			if subObject.maybeScope ~= nil then
				doCleanup(subObject.maybeScope)
				subObject.maybeScope = nil
			end
		end
	end
	self.oldestTask = destroy
	nicknames[self.oldestTask] = "For (internal disassembler)"
	table.insert(scope, destroy)
	
	return self
end

function class.populate<S, KI, KO, VI, VO>(
	self: Self<S, KI, KO, VI, VO>,
	use: Types.Use,
	output: {[KO]: VO}
): ()
	local minArrayIndex = math.huge
	local maxArrayIndex = -math.huge
	local hasHoles = false
	for subObject in self._subObjects do
		local outputKey, outputValue = subObject:useOutputPair(use)
		if outputKey == nil or outputValue == nil then
			hasHoles = true
			continue
		elseif output[outputKey] ~= nil then
			External.logErrorNonFatal("forKeyCollision", nil, tostring(outputKey))
			continue
		end
		output[outputKey] = outputValue
		if typeof(outputKey) == "number" then
			minArrayIndex = math.min(minArrayIndex, outputKey)
			maxArrayIndex = math.max(maxArrayIndex, outputKey)
		end
	end
	-- Be careful of NaN here
	if hasHoles and maxArrayIndex > minArrayIndex then
		local output: {[number]: VO} = output :: any
		local moveToIndex = minArrayIndex
		for moveFromIndex = minArrayIndex, maxArrayIndex do
			local outputValue = output[moveFromIndex]
			if outputValue == nil then
				continue
			end
			-- The ordering is important in case the indices are the same
			output[moveFromIndex] = nil
			output[moveToIndex] = outputValue
			moveToIndex += 1
		end
	end
end

function class._evaluate<S, KI, KO, VI, VO>(
	self: Self<S, KI, KO, VI, VO>
): boolean
	local outerScope = self.scope :: S & Types.Scope<unknown>
	local inputState = castToState(self._inputTable)
	if inputState ~= nil then
		if inputState.scope == nil then
			External.logError(
				"useAfterDestroy",
				nil,
				`The input {nameOf(inputState, "table")}`,
				`the For object that is watching it`
			)
		end
		depend(self, inputState)
	end

	local pendingPairs = {} :: {[KI]: VI}
	for key, value in peek(self._inputTable) do
		pendingPairs[key] = value
	end

	local newSubObjects = {} :: typeof(self._subObjects)

	for subObject in self._subObjects do
		local reused = false
		local oldInputKey = subObject.inputKey
		local oldInputValue = subObject.inputValue
		local newInputKey: KI
		-- Reuse when the keys are identical.
		if not subObject.roamKeys and pendingPairs[oldInputKey] ~= nil then
			reused = true
			newInputKey = oldInputKey
		else -- Try and reuse some other pair instead.
			for pendingKey, pendingValue in pendingPairs do
				reused = true
				newInputKey = pendingKey
				if subObject.roamValues then
					break
				end
				if pendingValue == oldInputValue then
					-- If the values are the same, then no need to update those,
					-- so prefer this choice to any other.
					break 
				end
			end
		end
		if reused then
			local newInputValue = pendingPairs[newInputKey]
			newSubObjects[subObject] = true
			if newInputKey ~= oldInputKey then
				subObject.inputKey = newInputKey
				subObject:invalidateInputKey()
			end
			if newInputValue ~= oldInputValue then
				subObject.inputValue = newInputValue
				subObject:invalidateInputValue()
			end
			pendingPairs[newInputKey] = nil
		else -- Too many sub objects for the number of pairs.
			if subObject.maybeScope ~= nil then
				doCleanup(subObject.maybeScope)
				subObject.maybeScope = nil
			end
		end
	end

	-- Generate new objects if needed to cover the remaining pending pairs.
	for pendingKey, pendingValue in pendingPairs do
		local subObject = self._constructor(deriveScope(outerScope), pendingKey, pendingValue)
		if subObject.maybeScope ~= nil then
			subObject.maybeScope = scopePool.giveIfEmpty(subObject.maybeScope)
		end
		newSubObjects[subObject] = true
	end

	self._subObjects = newSubObjects

	return true
end

table.freeze(class)
return Disassembly
end)() end,
    [58] = function()local wax,script,require=ImportGlobals(58)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Stores types that are commonly used between For objects.
]]

local Package = script.Parent.Parent.Parent
local Types = require(Package.Types)

export type SubObject<S, KI, KO, VI, VO> = {
	-- Not all sub objects need to store a scope, for example if the scope
	-- remains empty, it'll be given back to the scope pool.
	maybeScope: Types.Scope<S>?,
	inputKey: KI,
	inputValue: VI,
	roamKeys: boolean,
	roamValues: boolean,
	invalidateInputKey: (SubObject<S, KI, KO, VI, VO>) -> (),
	invalidateInputValue: (SubObject<S, KI, KO, VI, VO>) -> (),
	useOutputPair: (SubObject<S, KI, KO, VI, VO>, Types.Use) -> (KO?, VO?)
}

export type Disassembly<S, KI, KO, VI, VO> = Types.GraphObject & {
	populate: (Disassembly<S, KI, KO, VI, VO>, Types.Use, output: {[KO]: VO}) -> ()
}

return nil
end)() end,
    [59] = function()local wax,script,require=ImportGlobals(59)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Constructs and returns a new For state object which processes keys and
	preserves values.

	https://elttob.uk/Fusion/0.3/api-reference/state/members/forkeys/

	TODO: the sub objects constructed here can be more efficiently implemented
	as a dedicated state object.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
-- Memory
local doCleanup = require(Package.Memory.doCleanup)
-- State
local For = require(Package.State.For)
local Value = require(Package.State.Value)
local Computed = require(Package.State.Computed)
local ForTypes = require(Package.State.For.ForTypes)
-- Logging
local parseError = require(Package.Logging.parseError)

local SUB_OBJECT_META = {
	__index = {
		roamKeys = false,
		roamValues = true,
		invalidateInputKey = function(self): ()
			self._inputKeyState:set(self.inputKey)
		end,
		invalidateInputValue = function(self): ()
			-- do nothing
		end,
		useOutputPair = function(self, use)
			return use(self._outputKeyState), self.inputValue
		end
	}
}

local function SubObject<KI, KO, V, S>(
	scope: Types.Scope<S>,
	initialKey: KI,
	initialValue: V,
	processor: (Types.Use, Types.Scope<S>, KI) -> KO
): ForTypes.SubObject<S, KI, KO, V, V>
	local self = {}
	self.maybeScope = scope
	self.inputKey = initialKey
	self.inputValue = initialValue
	self._inputKeyState = Value(scope, initialKey)
	self._processor = processor
	self._outputKeyState = Computed(scope, function(use, scope): KO?
		local inputKey = use(self._inputKeyState)
		local ok, outputKey = xpcall(self._processor, parseError, use, scope, inputKey)
		if ok then
			return outputKey
		else
			local error: Types.Error = outputKey :: any
			error.context = `while processing key {tostring(inputKey)}`
			External.logErrorNonFatal("callbackError", error)
			doCleanup(scope)
			table.clear(scope)
			return nil
		end
	end)
	return setmetatable(self, SUB_OBJECT_META) :: any
end

local function ForKeys<KI, KO, V, S>(
	scope: Types.Scope<S>,
	inputTable: Types.UsedAs<{[KI]: V}>,
	processor: (Types.Use, Types.Scope<S>, KI) -> KO,
	destructor: unknown?
): Types.For<KO, V>
	if typeof(inputTable) == "function" then
		External.logError("scopeMissing", nil, "ForKeys", "myScope:ForKeys(inputTable, function(scope, use, key) ... end)")
	elseif destructor ~= nil then
		External.logWarn("destructorRedundant", "ForKeys")
	end
	return For(
		scope, 
		inputTable, 
		function(scope, initialKey, initialValue)
			return SubObject(scope, initialKey, initialValue, processor)
		end
	)
end

return ForKeys :: Types.ForKeysConstructor
end)() end,
    [60] = function()local wax,script,require=ImportGlobals(60)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Constructs and returns a new For state object which processes keys and
	values in pairs.

	https://elttob.uk/Fusion/0.3/api-reference/state/members/forpairs/

	TODO: the sub objects constructed here can be more efficiently implemented
	as a dedicated state object.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
-- State
local For = require(Package.State.For)
local Value = require(Package.State.Value)
local Computed = require(Package.State.Computed)
local ForTypes = require(Package.State.For.ForTypes)
-- Logging
local parseError = require(Package.Logging.parseError)
-- Memory
local doCleanup = require(Package.Memory.doCleanup)

local SUB_OBJECT_META = {
	__index = {
		roamKeys = false,
		roamValues = false,
		invalidateInputKey = function(self): ()
			self._inputKeyState:set(self.inputKey)
		end,
		invalidateInputValue = function(self): ()
			self._inputValueState:set(self.inputValue)
		end,
		useOutputPair = function(self, use)
			local pair = use(self._outputPairState)
			return pair.key, pair.value
		end
	}
}

local function SubObject<KI, KO, VI, VO, S>(
	scope: Types.Scope<S>,
	initialKey: KI,
	initialValue: VI,
	processor: (Types.Use, Types.Scope<S>, KI, VI) -> (KO, VO)
): ForTypes.SubObject<S, KI, KO, VI, VO>
	local self = {}
	self.maybeScope = scope
	self.inputKey = initialKey
	self.inputValue = initialValue
	self._inputKeyState = Value(scope, initialKey)
	self._inputValueState = Value(scope, initialValue)
	self._processor = processor
	self._outputPairState = Computed(scope, function(use, scope): {key: KO?, value: VO?}
		local inputKey = use(self._inputKeyState)
		local inputValue = use(self._inputValueState)
		local ok, outputKey, outputValue = xpcall(self._processor, parseError, use, scope, inputKey, inputValue)
		if ok then
			return {key = outputKey, value = outputValue}
		else
			local error: Types.Error = outputKey :: any
			error.context = `while processing key {tostring(inputValue)} and value {tostring(inputValue)}`
			External.logErrorNonFatal("callbackError", error)
			doCleanup(scope)
			table.clear(scope)
			return {key = nil, value = nil}
		end
	end)
	return setmetatable(self, SUB_OBJECT_META) :: any
end

local function ForPairs<KI, KO, VI, VO, S>(
	scope: Types.Scope<S>,
	inputTable: Types.UsedAs<{[KI]: VI}>,
	processor: (Types.Use, Types.Scope<S>, KI, VI) -> (KO, VO),
	destructor: unknown?
): Types.For<KO, VO>
	if typeof(inputTable) == "function" then
		External.logError("scopeMissing", nil, "ForPairs", "myScope:ForPairs(inputTable, function(scope, use, key, value) ... end)")
	elseif destructor ~= nil then
		External.logWarn("destructorRedundant", "ForPairs")
	end
	return For(
		scope,
		inputTable,
		function(scope, initialKey, initialValue)
			return SubObject(scope, initialKey, initialValue, processor)
		end
	)
end

return ForPairs :: Types.ForPairsConstructor
end)() end,
    [61] = function()local wax,script,require=ImportGlobals(61)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Constructs and returns a new For state object which processes values and
	preserves keys.

	https://elttob.uk/Fusion/0.3/api-reference/state/members/forvalues/

	TODO: the sub objects constructed here can be more efficiently implemented
	as a dedicated state object.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
-- State
local For = require(Package.State.For)
local Value = require(Package.State.Value)
local Computed = require(Package.State.Computed)
local ForTypes = require(Package.State.For.ForTypes)
-- Logging
local parseError = require(Package.Logging.parseError)
-- Memory
local doCleanup = require(Package.Memory.doCleanup)

local SUB_OBJECT_META = {
	__index = {
		roamKeys = true,
		roamValues = false,
		invalidateInputKey = function(self): ()
			-- do nothing
		end,
		invalidateInputValue = function(self): ()
			self._inputValueState:set(self.inputValue)
		end,
		useOutputPair = function(self, use)
			return self.inputKey, use(self._outputValueState)
		end
	}
}

local function SubObject<K, VI, VO, S>(
	scope: Types.Scope<S>,
	initialKey: K,
	initialValue: VI,
	processor: (Types.Use, Types.Scope<S>, VI) -> VO
): ForTypes.SubObject<S, K, K, VI, VO>
	local self = {}
	self.maybeScope = scope
	self.inputKey = initialKey
	self.inputValue = initialValue
	self._inputValueState = Value(scope, initialValue)
	self._processor = processor
	self._outputValueState = Computed(scope, function(use, scope): VO?
		local inputValue = use(self._inputValueState)
		local ok, outputValue = xpcall(self._processor, parseError, use, scope, inputValue)
		if ok then
			return outputValue
		else
			local error: Types.Error = outputValue :: any
			error.context = `while processing value {tostring(inputValue)}`
			External.logErrorNonFatal("callbackError", error)
			doCleanup(scope)
			table.clear(scope)
			return nil
		end
	end)
	return setmetatable(self, SUB_OBJECT_META) :: any
end

local function ForValues<K, VI, VO, S>(
	scope: Types.Scope<S>,
	inputTable: Types.UsedAs<{[K]: VI}>,
	processor: (Types.Use, Types.Scope<S>, VI) -> VO,
	destructor: unknown?
): Types.For<K, VO>
	if typeof(inputTable) == "function" then
		External.logError("scopeMissing", nil, "ForValues", "myScope:ForValues(inputTable, function(scope, use, value) ... end)")
	elseif destructor ~= nil then
		External.logWarn("destructorRedundant", "ForValues")
	end
	return For(
		scope,
		inputTable,
		function(scope, initialKey, initialValue)
			return SubObject(scope, initialKey, initialValue, processor)
		end
	)
end

return ForValues :: Types.ForValuesConstructor
end)() end,
    [62] = function()local wax,script,require=ImportGlobals(62)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	A state object which allows regular Luau code to control its value.

	https://elttob.uk/Fusion/0.3/api-reference/state/types/value/
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
-- Graph
local change = require(Package.Graph.change)
-- Utility
local isSimilar = require(Package.Utility.isSimilar)
local never = require(Package.Utility.never)
local nicknames = require(Package.Utility.nicknames)

type Self<T, S> = Types.Value<T, S>

local class = {}
class.type = "State"
class.kind = "Value"
class.timeliness = "lazy"
class.dependencySet = table.freeze {}

local METATABLE = table.freeze {__index = class}

local function Value<T>(
	scope: Types.Scope<unknown>,
	initialValue: T
): Types.Value<T, any>
	local createdAt = os.clock()
	if initialValue == nil and (typeof(scope) ~= "table" or (scope[1] == nil and next(scope) ~= nil)) then
		External.logError("scopeMissing", nil, "Value", "myScope:Value(initialValue)")
	end
	local self: Self<T, any> = setmetatable(
		{
			createdAt = createdAt,
			dependentSet = {},
			lastChange = os.clock(),
			scope = scope,
			validity = "valid",
			_EXTREMELY_DANGEROUS_usedAsValue = initialValue
		}, 
		METATABLE
	) :: any
	local destroy = function()
		self.scope = nil
	end
	self.oldestTask = destroy
	nicknames[self.oldestTask] = "Value"
	table.insert(scope, destroy)
	return self
end

function class:get<T, S>(
	_self: Self<T, S>
): never
	External.logError("stateGetWasRemoved")
	return never()
end

function class.set<T, S>(
	self: Self<T, S>,
	newValue: S
): S
	local oldValue = self._EXTREMELY_DANGEROUS_usedAsValue
	if not isSimilar(oldValue, newValue) then
		self._EXTREMELY_DANGEROUS_usedAsValue = newValue :: any
		change(self)
	end
	return newValue
end

function class._evaluate<T, S>(
	_self: Self<T, S>
): boolean
	-- The similarity test is done in advance when the value is set, so this
	-- should be fine.
	return true
end

table.freeze(class)
return Value :: Types.ValueConstructor
end)() end,
    [63] = function()local wax,script,require=ImportGlobals(63)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Returns the input *only* if it is a state object.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)

local function castToState<T>(
	target: Types.UsedAs<T>
): Types.StateObject<T>?
	if
		typeof(target) == "table" and
		target.type == "State" 
	then
		return target
	else
		return nil
	end
end

return castToState
end)() end,
    [64] = function()local wax,script,require=ImportGlobals(64)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Extracts a value of type T from its input.

	https://elttob.uk/Fusion/0.3/api-reference/state/members/peek/
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
-- State
local castToState = require(Package.State.castToState)
-- Graph
local evaluate = require(Package.Graph.evaluate)

local function peek<T>(
	target: Types.UsedAs<T>
): T
	local targetState = castToState(target)
	if targetState ~= nil then
		evaluate(targetState, false)
		return targetState._EXTREMELY_DANGEROUS_usedAsValue :: T
	else
		return target :: T
	end
end

return peek
end)() end,
    [65] = function()local wax,script,require=ImportGlobals(65)local ImportGlobals return (function(...)return nil -- dummy file so I can write tests
end)() end,
    [66] = function()local wax,script,require=ImportGlobals(66)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Stores common public-facing type information for Fusion APIs.
]]

export type Error = {
	type: "Error",
	raw: string,
	message: string,
	trace: string,
	context: string?
}

-- Types that can be expressed as vectors of numbers, and so can be animated.
export type Animatable =
	number |
	CFrame |
	Color3 |
	ColorSequenceKeypoint |
	DateTime |
	NumberRange |
	NumberSequenceKeypoint |
	PhysicalProperties |
	Ray |
	Rect |
	Region3 |
	Region3int16 |
	UDim |
	UDim2 |
	Vector2 |
	Vector2int16 |
	Vector3 |
	Vector3int16

-- A task which can be accepted for cleanup.
export type Task =
	Instance |
	RBXScriptConnection |
	() -> () |
	{destroy: (unknown) -> ()} |
	{Destroy: (unknown) -> ()} |
	{Task}

-- A scope of tasks to clean up.
export type Scope<Constructors = any> = {Task} & Constructors

-- An object which uses a scope to dictate how long it lives.
export type ScopedObject = {
	scope: Scope<unknown>?,
	oldestTask: unknown
}

-- Script-readable version information.
export type Version = {
	major: number,
	minor: number,
	isRelease: boolean
}

-- An object which stores a value scoped in time.
export type Contextual<T> = {
	type: "Contextual",
	now: (Contextual<T>) -> T,
	is: (Contextual<T>, T) -> ContextualIsMethods
}

type ContextualIsMethods = {
	during: <R, A...>(ContextualIsMethods, (A...) -> R, A...) -> R
}

-- A graph object which can have dependencies and dependencies.
export type GraphObject = ScopedObject & {
	createdAt: number,
	dependencySet: {[GraphObject]: unknown},
	dependentSet: {[GraphObject]: unknown},
	lastChange: number?,
	timeliness: "lazy" | "eager",
	validity: "valid" | "invalid" | "busy",
	_evaluate: (GraphObject) -> boolean
}

-- An object which stores a piece of reactive state.
export type StateObject<T> = GraphObject & {
	type: "State",
	kind: string,
	_EXTREMELY_DANGEROUS_usedAsValue: T
}

-- Passing values of this type to `Use` returns `T`.
export type UsedAs<T> = StateObject<T> | T

-- Function signature for use callbacks.
export type Use = <T>(target: UsedAs<T>) -> T

-- A state object whose value can be set at any time by the user.
export type Value<T, S = T> = StateObject<T> & {
	kind: "State",
	timeliness: "lazy",
 	set: (Value<T, S>, newValue: S, force: boolean?) -> S,
	____phantom_setType: (never) -> S -- phantom data so this contains S
}
export type ValueConstructor = <T>(
	scope: Scope<unknown>,
	initialValue: T
) -> Value<T, any>

-- A state object whose value is derived from other objects using a callback.
export type Computed<T> = StateObject<T> & {
	kind: "Computed",
	timeliness: "lazy"
}
export type ComputedConstructor = <T, S>(
	scope: S & Scope<unknown>,
	callback: (Use, S) -> T
) -> Computed<T>

-- A state object which maps over keys and/or values in another table.
export type For<KO, VO> = StateObject<{[KO]: VO}>  & {
	kind: "For"
}
export type ForPairsConstructor =  <KI, KO, VI, VO, S>(
	scope: S & Scope<unknown>,
	inputTable: UsedAs<{[KI]: VI}>,
	processor: (Use, S, key: KI, value: VI) -> (KO, VO)
) -> For<KO, VO>
export type ForKeysConstructor =  <KI, KO, V, S>(
	scope: S & Scope<unknown>,
	inputTable: UsedAs<{[KI]: V}>,
	processor: (Use, S, key: KI) -> KO
) -> For<KO, V>
export type ForValuesConstructor =  <K, VI, VO, S>(
	scope: S & Scope<unknown>,
	inputTable: UsedAs<{[K]: VI}>,
	processor: (Use, S, value: VI) -> VO
) -> For<K, VO>

-- An object which can listen for updates on another state object.
export type Observer = GraphObject & {
	type: "Observer",
	timeliness: "eager",
	onChange: (Observer, callback: () -> ()) -> (() -> ()),
	onBind: (Observer, callback: () -> ()) -> (() -> ())
}
export type ObserverConstructor = (
	scope: Scope<unknown>,
	watching: unknown
) -> Observer

-- A state object which follows another state object using tweens.
export type Tween<T> = StateObject<T> & {
	kind: "Tween"
}
export type TweenConstructor = <T>(
	scope: Scope<unknown>,
	goalState: UsedAs<T>,
	tweenInfo: UsedAs<TweenInfo>?
) -> Tween<T>

-- A state object which follows another state object using spring simulation.
export type Spring<T> = StateObject<T>  & {
	kind: "Spring",
	setPosition: (Spring<T>, newPosition: T) -> (),
	setVelocity: (Spring<T>, newVelocity: T) -> (),
	addVelocity: (Spring<T>, deltaVelocity: T) -> ()
}
export type SpringConstructor = <T>(
	scope: Scope<unknown>,
	goalState: UsedAs<T>,
	speed: UsedAs<number>?,
	damping: UsedAs<number>?
) -> Spring<T>

-- Denotes children instances in an instance or component's property table.
export type SpecialKey = {
	type: "SpecialKey",
	kind: string,
	stage: "self" | "descendants" | "ancestor" | "observer",
	apply: (
		self: SpecialKey,
		scope: Scope<unknown>,
		value: unknown,
		applyTo: Instance
	) -> ()
}

-- A collection of instances that may be parented to another instance.
export type Child = Instance | StateObject<Child> | {[unknown]: Child}

-- A table that defines an instance's properties, handlers and children.
export type PropertyTable = {[string | SpecialKey]: unknown}

export type NewConstructor = (
	scope: Scope<unknown>,
	className: string
) -> (propertyTable: PropertyTable) -> Instance

export type HydrateConstructor = (
	scope: Scope<unknown>,
	target: Instance
) -> (propertyTable: PropertyTable) -> Instance

-- Is there a sane way to write out this type?
-- ... I sure hope so.

export type DeriveScopeConstructor = (<S>(Scope<S>) -> Scope<S>)
	& (<S, A>(Scope<S>, A & {}) -> Scope<S & A>)
	& (<S, A, B>(Scope<S>, A & {}, B & {}) -> Scope<S & A & B>)
	& (<S, A, B, C>(Scope<S>, A & {}, B & {}, C & {}) -> Scope<S & A & B & C>)
	& (<S, A, B, C, D>(Scope<S>, A & {}, B & {}, C & {}, D & {}) -> Scope<S & A & B & C & D>)
	& (<S, A, B, C, D, E>(Scope<S>, A & {}, B & {}, C & {}, D & {}, E & {}) -> Scope<S & A & B & C & D & E>)
	& (<S, A, B, C, D, E, F>(Scope<S>, A & {}, B & {}, C & {}, D & {}, E & {}, F & {}) -> Scope<S & A & B & C & D & E & F>)
	& (<S, A, B, C, D, E, F, G>(Scope<S>, A & {}, B & {}, C & {}, D & {}, E & {}, F & {}, G & {}) -> Scope<S & A & B & C & D & E & F & G>)
	& (<S, A, B, C, D, E, F, G, H>(Scope<S>, A & {}, B & {}, C & {}, D & {}, E & {}, F & {}, G & {}, H & {}) -> Scope<S & A & B & C & D & E & F & G & H>)
	& (<S, A, B, C, D, E, F, G, H, I>(Scope<S>, A & {}, B & {}, C & {}, D & {}, E & {}, F & {}, G & {}, H & {}, I & {}) -> Scope<S & A & B & C & D & E & F & G & H & I>)
	& (<S, A, B, C, D, E, F, G, H, I, J>(Scope<S>, A & {}, B & {}, C & {}, D & {}, E & {}, F & {}, G & {}, H & {}, I & {}, J & {}) -> Scope<S & A & B & C & D & E & F & G & H & I & J>)
	& (<S, A, B, C, D, E, F, G, H, I, J, K>(Scope<S>, A & {}, B & {}, C & {}, D & {}, E & {}, F & {}, G & {}, H & {}, I & {}, J & {}, K & {}) -> Scope<S & A & B & C & D & E & F & G & H & I & J & K>)
	& (<S, A, B, C, D, E, F, G, H, I, J, K, L>(Scope<S>, A & {}, B & {}, C & {}, D & {}, E & {}, F & {}, G & {}, H & {}, I & {}, J & {}, K & {}, L & {}) -> Scope<S & A & B & C & D & E & F & G & H & I & J & K & L>)

export type ScopedConstructor = (() -> Scope<{}>)
	& (<A>(A & {}) -> Scope<A>)
	& (<A, B>(A & {}, B & {}) -> Scope<A & B>)
	& (<A, B, C>(A & {}, B & {}, C & {}) -> Scope<A & B & C>)
	& (<A, B, C, D>(A & {}, B & {}, C & {}, D & {}) -> Scope<A & B & C & D>)
	& (<A, B, C, D, E>(A & {}, B & {}, C & {}, D & {}, E & {}) -> Scope<A & B & C & D & E>)
	& (<A, B, C, D, E, F>(A & {}, B & {}, C & {}, D & {}, E & {}, F & {}) -> Scope<A & B & C & D & E & F>)
	& (<A, B, C, D, E, F, G>(A & {}, B & {}, C & {}, D & {}, E & {}, F & {}, G & {}) -> Scope<A & B & C & D & E & F & G>)
	& (<A, B, C, D, E, F, G, H>(A & {}, B & {}, C & {}, D & {}, E & {}, F & {}, G & {}, H & {}) -> Scope<A & B & C & D & E & F & G & H>)
	& (<A, B, C, D, E, F, G, H, I>(A & {}, B & {}, C & {}, D & {}, E & {}, F & {}, G & {}, H & {}, I & {}) -> Scope<A & B & C & D & E & F & G & H & I>)
	& (<A, B, C, D, E, F, G, H, I, J>(A & {}, B & {}, C & {}, D & {}, E & {}, F & {}, G & {}, H & {}, I & {}, J & {}) -> Scope<A & B & C & D & E & F & G & H & I & J>)
	& (<A, B, C, D, E, F, G, H, I, J, K>(A & {}, B & {}, C & {}, D & {}, E & {}, F & {}, G & {}, H & {}, I & {}, J & {}, K & {}) -> Scope<A & B & C & D & E & F & G & H & I & J & K>)
	& (<A, B, C, D, E, F, G, H, I, J, K, L>(A & {}, B & {}, C & {}, D & {}, E & {}, F & {}, G & {}, H & {}, I & {}, J & {}, K & {}, L & {}) -> Scope<A & B & C & D & E & F & G & H & I & J & K & L>)

export type ContextualConstructor = <T>(defaultValue: T) -> Contextual<T>

export type Safe = <Success, Fail>(
	callbacks: {
		try: () -> Success,
		fallback: (err: unknown) -> Fail
	}
) -> Success | Fail

export type Fusion = {
	version: Version,
	Contextual: ContextualConstructor,
	Safe: Safe,

	doCleanup: (Task) -> (),
	scoped: ScopedConstructor,
	deriveScope: DeriveScopeConstructor,
	innerScope: DeriveScopeConstructor,

	peek: Use,
	Value: ValueConstructor,
	Computed: ComputedConstructor,
	ForPairs: ForPairsConstructor,
	ForKeys: ForKeysConstructor,
	ForValues: ForValuesConstructor,
	Observer: ObserverConstructor,

	Tween: TweenConstructor,
	Spring: SpringConstructor,

	New: NewConstructor,
	Hydrate: HydrateConstructor,

	Child: ({Child}) -> Child,
	Children: SpecialKey,
	Out: (propertyName: string) -> SpecialKey,
	OnEvent: (eventName: string) -> SpecialKey,
	OnChange: (propertyName: string) -> SpecialKey,
	Attribute: (attributeName: string) -> SpecialKey,
	AttributeChange: (attributeName: string) -> SpecialKey,
	AttributeOut: (attributeName: string) -> SpecialKey,
}

export type ExternalProvider = {
	policies: {
		allowWebLinks: boolean
	},

	logErrorNonFatal: (
		errorString: string
	) -> (),
	logWarn: (
		errorString: string
	) -> (),
	
	doTaskImmediate: (
		resume: () -> ()
	) -> (),
	doTaskDeferred: (
		resume: () -> ()
	) -> (),
	startScheduler: () -> (),
	stopScheduler: () -> ()
}

export type ExternalDebugger = {
	startDebugging: () -> (),
	stopDebugging: () -> (),

	trackScope: (
		scope: Scope<unknown>
	) -> (),
	untrackScope: (
		scope: Scope<unknown>
	) -> ()
}

return nil
end)() end,
    [68] = function()local wax,script,require=ImportGlobals(68)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
    Time-based contextual values, to allow for transparently passing values down
	the call stack.
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
-- Logging
local parseError = require(Package.Logging.parseError)

export type Self<T> = Types.Contextual<T> & {
	_valuesNow: {[thread]: {value: T}},
	_defaultValue: T
}

local class = {}
class.type = "Contextual"

local METATABLE = table.freeze {__index = class}
local WEAK_KEYS_METATABLE = table.freeze {__mode = "k"}

local function Contextual<T>(
	defaultValue: T
): Types.Contextual<T>
	local self: Self<T> = setmetatable(
		{
			-- if we held strong references to threads here, then if a thread was
			-- killed before this contextual had a chance to finish executing its
			-- callback, it would be held strongly in this table forever
			_valuesNow = setmetatable({}, WEAK_KEYS_METATABLE),
			_defaultValue = defaultValue
		}, 
		METATABLE
	) :: any

	return self
end

--[[
	Returns the current value of this contextual.
]]
function class.now<T>(
	self: Self<T>
): T
	local thread = coroutine.running()
	local value = self._valuesNow[thread]
	if typeof(value) ~= "table" then
		return self._defaultValue
	else
		return value.value
	end
end

--[[
	Temporarily assigns a value to this contextual.
]]
function class.is<T>(
	self: Self<T>,
	newValue: T
)
	local methods = {}
	
	function methods.during<T, A...>(
		_: any, -- during is called with colon syntax but we don't care
		callback: (A...) -> T,
		...: A...
	): T
		local thread = coroutine.running()
		local prevValue = self._valuesNow[thread]
		-- Storing the value in this format allows us to distinguish storing
		-- `nil` from not calling `:during()` at all.
		self._valuesNow[thread] = { value = newValue }
		local ok, value = xpcall(callback, parseError, ...)
		self._valuesNow[thread] = prevValue
		if not ok then
			External.logError("callbackError", value :: any)
		end
		return value
	end

	return methods
end

table.freeze(class)
return Contextual
end)() end,
    [69] = function()local wax,script,require=ImportGlobals(69)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
    A variant of xpcall() designed for inline usage, letting you define fallback
	values based on caught errors.
]]

local Package = script.Parent.Parent

local function Safe<Success, Fail>(
	callbacks: {
		try: () -> Success,
		fallback: (err: unknown) -> Fail
	}
): Success | Fail
	local _, value = xpcall(callbacks.try, callbacks.fallback)
	return value
end

return Safe
end)() end,
    [70] = function()local wax,script,require=ImportGlobals(70)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Implements the 'similarity test' used to determine whether two values have
	a meaningful difference.

	https://elttob.uk/Fusion/0.3/tutorials/best-practices/optimisation/#similarity
]]

local function isSimilar(
	a: unknown, 
	b: unknown
): boolean
	local typeA = typeof(a)
	local isTable = typeA == "table"
	local isUserdata = typeA == "userdata"
	return
		if not (isTable or isUserdata) then
			a == b or a ~= a and b ~= b
		elseif typeA == typeof(b) and (isUserdata or table.isfrozen(a :: any) or getmetatable(a :: any) ~= nil) then
			a == b
		else
			false
end

return isSimilar
end)() end,
    [71] = function()local wax,script,require=ImportGlobals(71)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Attempts to merge a variadic number of tables together.
]]

local Package = script.Parent.Parent
local External = require(Package.External)

local function merge(
	overwrite: boolean,
	into: {[unknown]: unknown},
	...: {[unknown]: unknown}
): {[unknown]: unknown}
	local fromTables = {...}
	if #fromTables < 1 then
		return into
	else
		for _, fromTable in fromTables do
			for key, value in fromTable do
				if into[key] == nil then
					into[key] = value
				elseif not overwrite then
					External.logError("mergeConflict", nil, tostring(key))
				end
			end
		end
		return into
	end
end

return merge
end)() end,
    [72] = function()local wax,script,require=ImportGlobals(72)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Returns the most specific custom name for the given object.
]]

local Package = script.Parent.Parent
-- Utility
local nicknames = require(Package.Utility.nicknames)

local function nameOf(
	x: unknown,
	defaultName: string
): string
	local nickname = nicknames[x]
	if typeof(nickname) == "string" then
		return nickname
	end
	if typeof(x) == "table" then
		local x = x :: {[any]: any}
		if typeof(x.name) == "string" then
			return x.name
		elseif typeof(x.kind) == "string" then
			return x.kind
		elseif typeof(x.type) == "string" then
			return x.type
		end
	end
	return defaultName
end

return nameOf
end)() end,
    [73] = function()local wax,script,require=ImportGlobals(73)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Never returns.
]]

local function never(): never
	error("This codepath should not be reachable")
end

return never
end)() end,
    [74] = function()local wax,script,require=ImportGlobals(74)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Stores nicknames for values that don't support metatables, so that `nameOf`
	can return values for them.
]]

return setmetatable({}, {__mode = "k"})
end)() end,
    [75] = function()local wax,script,require=ImportGlobals(75)local ImportGlobals return (function(...)--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Extended typeof, designed for identifying custom objects.
	If given a table with a `type` string, returns that.
	Otherwise, returns `typeof()` the argument.
]]

local function xtypeof(
	x: unknown
): string
	local typeString = typeof(x)

	if typeString == "table" then
		local x = x :: {type: unknown?}
		if typeof(x.type) == "string" then
			return x.type
		end
	end

	return typeString
end

return xtypeof
end)() end
} -- [RefId] = Closure

-- Holds the actual DOM data
local ObjectTree = {
    {
        1,
        2,
        {
            "Fusion"
        },
        {
            {
                16,
                2,
                {
                    "External"
                }
            },
            {
                67,
                1,
                {
                    "Utility"
                },
                {
                    {
                        69,
                        2,
                        {
                            "Safe"
                        }
                    },
                    {
                        70,
                        2,
                        {
                            "isSimilar"
                        }
                    },
                    {
                        72,
                        2,
                        {
                            "nameOf"
                        }
                    },
                    {
                        71,
                        2,
                        {
                            "merge"
                        }
                    },
                    {
                        68,
                        2,
                        {
                            "Contextual"
                        }
                    },
                    {
                        75,
                        2,
                        {
                            "xtypeof"
                        }
                    },
                    {
                        74,
                        2,
                        {
                            "nicknames"
                        }
                    },
                    {
                        73,
                        2,
                        {
                            "never"
                        }
                    }
                }
            },
            {
                53,
                2,
                {
                    "RobloxExternal"
                }
            },
            {
                13,
                1,
                {
                    "Colour"
                },
                {
                    {
                        15,
                        2,
                        {
                            "sRGB"
                        }
                    },
                    {
                        14,
                        2,
                        {
                            "Oklab"
                        }
                    }
                }
            },
            {
                37,
                1,
                {
                    "Logging"
                },
                {
                    {
                        40,
                        2,
                        {
                            "parseError"
                        }
                    },
                    {
                        38,
                        2,
                        {
                            "formatError"
                        }
                    },
                    {
                        39,
                        2,
                        {
                            "messages"
                        }
                    }
                }
            },
            {
                66,
                2,
                {
                    "Types"
                }
            },
            {
                54,
                1,
                {
                    "State"
                },
                {
                    {
                        61,
                        2,
                        {
                            "ForValues"
                        }
                    },
                    {
                        55,
                        2,
                        {
                            "Computed"
                        }
                    },
                    {
                        59,
                        2,
                        {
                            "ForKeys"
                        }
                    },
                    {
                        64,
                        2,
                        {
                            "peek"
                        }
                    },
                    {
                        65,
                        2,
                        {
                            "updateAll"
                        }
                    },
                    {
                        63,
                        2,
                        {
                            "castToState"
                        }
                    },
                    {
                        56,
                        2,
                        {
                            "For"
                        },
                        {
                            {
                                58,
                                2,
                                {
                                    "ForTypes"
                                }
                            },
                            {
                                57,
                                2,
                                {
                                    "Disassembly"
                                }
                            }
                        }
                    },
                    {
                        60,
                        2,
                        {
                            "ForPairs"
                        }
                    },
                    {
                        62,
                        2,
                        {
                            "Value"
                        }
                    }
                }
            },
            {
                41,
                1,
                {
                    "Memory"
                },
                {
                    {
                        42,
                        2,
                        {
                            "checkLifetime"
                        }
                    },
                    {
                        46,
                        2,
                        {
                            "innerScope"
                        }
                    },
                    {
                        45,
                        2,
                        {
                            "doCleanup"
                        }
                    },
                    {
                        43,
                        2,
                        {
                            "deriveScope"
                        }
                    },
                    {
                        48,
                        2,
                        {
                            "needsDestruction"
                        }
                    },
                    {
                        47,
                        2,
                        {
                            "legacyCleanup"
                        }
                    },
                    {
                        51,
                        2,
                        {
                            "scoped"
                        }
                    },
                    {
                        44,
                        2,
                        {
                            "deriveScopeImpl"
                        }
                    },
                    {
                        49,
                        2,
                        {
                            "poisonScope"
                        }
                    },
                    {
                        52,
                        2,
                        {
                            "whichLivesLonger"
                        }
                    },
                    {
                        50,
                        2,
                        {
                            "scopePool"
                        }
                    }
                }
            },
            {
                2,
                1,
                {
                    "Animation"
                },
                {
                    {
                        3,
                        2,
                        {
                            "ExternalTime"
                        }
                    },
                    {
                        4,
                        2,
                        {
                            "Spring"
                        }
                    },
                    {
                        10,
                        2,
                        {
                            "packType"
                        }
                    },
                    {
                        9,
                        2,
                        {
                            "lerpType"
                        }
                    },
                    {
                        6,
                        2,
                        {
                            "Tween"
                        }
                    },
                    {
                        8,
                        2,
                        {
                            "getTweenRatio"
                        }
                    },
                    {
                        7,
                        2,
                        {
                            "getTweenDuration"
                        }
                    },
                    {
                        11,
                        2,
                        {
                            "springCoefficients"
                        }
                    },
                    {
                        12,
                        2,
                        {
                            "unpackType"
                        }
                    },
                    {
                        5,
                        2,
                        {
                            "Stopwatch"
                        }
                    }
                }
            },
            {
                17,
                2,
                {
                    "ExternalDebug"
                }
            },
            {
                24,
                1,
                {
                    "Instances"
                },
                {
                    {
                        25,
                        2,
                        {
                            "Attribute"
                        }
                    },
                    {
                        33,
                        2,
                        {
                            "OnEvent"
                        }
                    },
                    {
                        36,
                        2,
                        {
                            "defaultProps"
                        }
                    },
                    {
                        35,
                        2,
                        {
                            "applyInstanceProps"
                        }
                    },
                    {
                        28,
                        2,
                        {
                            "Child"
                        }
                    },
                    {
                        26,
                        2,
                        {
                            "AttributeChange"
                        }
                    },
                    {
                        29,
                        2,
                        {
                            "Children"
                        }
                    },
                    {
                        34,
                        2,
                        {
                            "Out"
                        }
                    },
                    {
                        32,
                        2,
                        {
                            "OnChange"
                        }
                    },
                    {
                        31,
                        2,
                        {
                            "New"
                        }
                    },
                    {
                        27,
                        2,
                        {
                            "AttributeOut"
                        }
                    },
                    {
                        30,
                        2,
                        {
                            "Hydrate"
                        }
                    }
                }
            },
            {
                18,
                1,
                {
                    "Graph"
                },
                {
                    {
                        22,
                        2,
                        {
                            "depend"
                        }
                    },
                    {
                        20,
                        2,
                        {
                            "castToGraph"
                        }
                    },
                    {
                        23,
                        2,
                        {
                            "evaluate"
                        }
                    },
                    {
                        21,
                        2,
                        {
                            "change"
                        }
                    },
                    {
                        19,
                        2,
                        {
                            "Observer"
                        }
                    }
                }
            }
        }
    }
}

-- Line offsets for debugging (only included when minifyTables is false)
local LineOffsets = {
    8,
    [3] = 91,
    [4] = 176,
    [5] = 499,
    [6] = 628,
    [7] = 816,
    [8] = 844,
    [9] = 892,
    [10] = 1057,
    [11] = 1158,
    [12] = 1239,
    [14] = 1343,
    [15] = 1414,
    [16] = 1470,
    [17] = 1639,
    [19] = 1710,
    [20] = 1825,
    [21] = 1855,
    [22] = 1937,
    [23] = 1971,
    [25] = 2028,
    [26] = 2087,
    [27] = 2135,
    [28] = 2199,
    [29] = 2221,
    [30] = 2370,
    [31] = 2404,
    [32] = 2458,
    [33] = 2509,
    [34] = 2564,
    [35] = 2634,
    [36] = 2784,
    [38] = 2979,
    [39] = 3029,
    [40] = 3082,
    [42] = 3108,
    [43] = 3243,
    [44] = 3268,
    [45] = 3314,
    [46] = 3394,
    [47] = 3429,
    [48] = 3448,
    [49] = 3466,
    [50] = 3501,
    [51] = 3557,
    [52] = 3585,
    [53] = 3661,
    [55] = 3760,
    [56] = 3900,
    [57] = 4011,
    [58] = 4223,
    [59] = 4254,
    [60] = 4349,
    [61] = 4447,
    [62] = 4542,
    [63] = 4631,
    [64] = 4658,
    [65] = 4690,
    [66] = 4692,
    [68] = 5007,
    [69] = 5099,
    [70] = 5123,
    [71] = 5153,
    [72] = 5189,
    [73] = 5225,
    [74] = 5240,
    [75] = 5252
}

-- Misc AOT variable imports
local WaxVersion = "0.4.2"
local EnvName = "WaxRuntime"

-- ++++++++ RUNTIME IMPL BELOW ++++++++ --

-- Localizing certain libraries and built-ins for runtime efficiency
local string, task, setmetatable, error, next, table, unpack, coroutine, script, type, require, pcall, tostring, tonumber, _VERSION =
      string, task, setmetatable, error, next, table, unpack, coroutine, script, type, require, pcall, tostring, tonumber, _VERSION

local table_insert = table.insert
local table_remove = table.remove
local table_freeze = table.freeze or function(t) return t end -- lol

local coroutine_wrap = coroutine.wrap

local string_sub = string.sub
local string_match = string.match
local string_gmatch = string.gmatch

-- The Lune runtime has its own `task` impl, but it must be imported by its builtin
-- module path, "@lune/task"
if _VERSION and string_sub(_VERSION, 1, 4) == "Lune" then
    local RequireSuccess, LuneTaskLib = pcall(require, "@lune/task")
    if RequireSuccess and LuneTaskLib then
        task = LuneTaskLib
    end
end

local task_defer = task and task.defer

-- If we're not running on the Roblox engine, we won't have a `task` global
local Defer = task_defer or function(f, ...)
    coroutine_wrap(f)(...)
end

-- ClassName "IDs"
local ClassNameIdBindings = {
    [1] = "Folder",
    [2] = "ModuleScript",
    [3] = "Script",
    [4] = "LocalScript",
    [5] = "StringValue",
}

local RefBindings = {} -- [RefId] = RealObject

local ScriptClosures = {}
local ScriptClosureRefIds = {} -- [ScriptClosure] = RefId
local StoredModuleValues = {}
local ScriptsToRun = {}

-- wax.shared __index/__newindex
local SharedEnvironment = {}

-- We're creating 'fake' instance refs soley for traversal of the DOM for require() compatibility
-- It's meant to be as lazy as possible
local RefChildren = {} -- [Ref] = {ChildrenRef, ...}

-- Implemented instance methods
local InstanceMethods = {
    GetFullName = { {}, function(self)
        local Path = self.Name
        local ObjectPointer = self.Parent

        while ObjectPointer do
            Path = ObjectPointer.Name .. "." .. Path

            -- Move up the DOM (parent will be nil at the end, and this while loop will stop)
            ObjectPointer = ObjectPointer.Parent
        end

        return Path
    end},

    GetChildren = { {}, function(self)
        local ReturnArray = {}

        for Child in next, RefChildren[self] do
            table_insert(ReturnArray, Child)
        end

        return ReturnArray
    end},

    GetDescendants = { {}, function(self)
        local ReturnArray = {}

        for Child in next, RefChildren[self] do
            table_insert(ReturnArray, Child)

            for _, Descendant in next, Child:GetDescendants() do
                table_insert(ReturnArray, Descendant)
            end
        end

        return ReturnArray
    end},

    FindFirstChild = { {"string", "boolean?"}, function(self, name, recursive)
        local Children = RefChildren[self]

        for Child in next, Children do
            if Child.Name == name then
                return Child
            end
        end

        if recursive then
            for Child in next, Children do
                -- Yeah, Roblox follows this behavior- instead of searching the entire base of a
                -- ref first, the engine uses a direct recursive call
                return Child:FindFirstChild(name, true)
            end
        end
    end},

    FindFirstAncestor = { {"string"}, function(self, name)
        local RefPointer = self.Parent
        while RefPointer do
            if RefPointer.Name == name then
                return RefPointer
            end

            RefPointer = RefPointer.Parent
        end
    end},

    -- Just to implement for traversal usage
    WaitForChild = { {"string", "number?"}, function(self, name)
        return self:FindFirstChild(name)
    end},
}

-- "Proxies" to instance methods, with err checks etc
local InstanceMethodProxies = {}
for MethodName, MethodObject in next, InstanceMethods do
    local Types = MethodObject[1]
    local Method = MethodObject[2]

    local EvaluatedTypeInfo = {}
    for ArgIndex, TypeInfo in next, Types do
        local ExpectedType, IsOptional = string_match(TypeInfo, "^([^%?]+)(%??)")
        EvaluatedTypeInfo[ArgIndex] = {ExpectedType, IsOptional}
    end

    InstanceMethodProxies[MethodName] = function(self, ...)
        if not RefChildren[self] then
            error("Expected ':' not '.' calling member function " .. MethodName, 2)
        end

        local Args = {...}
        for ArgIndex, TypeInfo in next, EvaluatedTypeInfo do
            local RealArg = Args[ArgIndex]
            local RealArgType = type(RealArg)
            local ExpectedType, IsOptional = TypeInfo[1], TypeInfo[2]

            if RealArg == nil and not IsOptional then
                error("Argument " .. RealArg .. " missing or nil", 3)
            end

            if ExpectedType ~= "any" and RealArgType ~= ExpectedType and not (RealArgType == "nil" and IsOptional) then
                error("Argument " .. ArgIndex .. " expects type \"" .. ExpectedType .. "\", got \"" .. RealArgType .. "\"", 2)
            end
        end

        return Method(self, ...)
    end
end

local function CreateRef(className, name, parent)
    -- `name` and `parent` can also be set later by the init script if they're absent

    -- Extras
    local StringValue_Value

    -- Will be set to RefChildren later aswell
    local Children = setmetatable({}, {__mode = "k"})

    -- Err funcs
    local function InvalidMember(member)
        error(member .. " is not a valid (virtual) member of " .. className .. " \"" .. name .. "\"", 3)
    end
    local function ReadOnlyProperty(property)
        error("Unable to assign (virtual) property " .. property .. ". Property is read only", 3)
    end

    local Ref = {}
    local RefMetatable = {}

    RefMetatable.__metatable = false

    RefMetatable.__index = function(_, index)
        if index == "ClassName" then -- First check "properties"
            return className
        elseif index == "Name" then
            return name
        elseif index == "Parent" then
            return parent
        elseif className == "StringValue" and index == "Value" then
            -- Supporting StringValue.Value for Rojo .txt file conv
            return StringValue_Value
        else -- Lastly, check "methods"
            local InstanceMethod = InstanceMethodProxies[index]

            if InstanceMethod then
                return InstanceMethod
            end
        end

        -- Next we'll look thru child refs
        for Child in next, Children do
            if Child.Name == index then
                return Child
            end
        end

        -- At this point, no member was found; this is the same err format as Roblox
        InvalidMember(index)
    end

    RefMetatable.__newindex = function(_, index, value)
        -- __newindex is only for props fyi
        if index == "ClassName" then
            ReadOnlyProperty(index)
        elseif index == "Name" then
            name = value
        elseif index == "Parent" then
            -- We'll just ignore the process if it's trying to set itself
            if value == Ref then
                return
            end

            if parent ~= nil then
                -- Remove this ref from the CURRENT parent
                RefChildren[parent][Ref] = nil
            end

            parent = value

            if value ~= nil then
                -- And NOW we're setting the new parent
                RefChildren[value][Ref] = true
            end
        elseif className == "StringValue" and index == "Value" then
            -- Supporting StringValue.Value for Rojo .txt file conv
            StringValue_Value = value
        else
            -- Same err as __index when no member is found
            InvalidMember(index)
        end
    end

    RefMetatable.__tostring = function()
        return name
    end

    setmetatable(Ref, RefMetatable)

    RefChildren[Ref] = Children

    if parent ~= nil then
        RefChildren[parent][Ref] = true
    end

    return Ref
end

-- Create real ref DOM from object tree
local function CreateRefFromObject(object, parent)
    local RefId = object[1]
    local ClassNameId = object[2]
    local Properties = object[3] -- Optional
    local Children = object[4] -- Optional

    local ClassName = ClassNameIdBindings[ClassNameId]

    local Name = Properties and table_remove(Properties, 1) or ClassName

    local Ref = CreateRef(ClassName, Name, parent) -- 3rd arg may be nil if this is from root
    RefBindings[RefId] = Ref

    if Properties then
        for PropertyName, PropertyValue in next, Properties do
            Ref[PropertyName] = PropertyValue
        end
    end

    if Children then
        for _, ChildObject in next, Children do
            CreateRefFromObject(ChildObject, Ref)
        end
    end

    return Ref
end

local RealObjectRoot = CreateRef("Folder", "[" .. EnvName .. "]")
for _, Object in next, ObjectTree do
    CreateRefFromObject(Object, RealObjectRoot)
end

-- Now we'll set script closure refs and check if they should be ran as a BaseScript
for RefId, Closure in next, ClosureBindings do
    local Ref = RefBindings[RefId]

    ScriptClosures[Ref] = Closure
    ScriptClosureRefIds[Ref] = RefId

    local ClassName = Ref.ClassName
    if ClassName == "LocalScript" or ClassName == "Script" then
        table_insert(ScriptsToRun, Ref)
    end
end

local function LoadScript(scriptRef)
    local ScriptClassName = scriptRef.ClassName

    -- First we'll check for a cached module value (packed into a tbl)
    local StoredModuleValue = StoredModuleValues[scriptRef]
    if StoredModuleValue and ScriptClassName == "ModuleScript" then
        return unpack(StoredModuleValue)
    end

    local Closure = ScriptClosures[scriptRef]

    local function FormatError(originalErrorMessage)
        originalErrorMessage = tostring(originalErrorMessage)

        local VirtualFullName = scriptRef:GetFullName()

        -- Check for vanilla/Roblox format
        local OriginalErrorLine, BaseErrorMessage = string_match(originalErrorMessage, "[^:]+:(%d+): (.+)")

        if not OriginalErrorLine or not LineOffsets then
            return VirtualFullName .. ":*: " .. (BaseErrorMessage or originalErrorMessage)
        end

        OriginalErrorLine = tonumber(OriginalErrorLine)

        local RefId = ScriptClosureRefIds[scriptRef]
        local LineOffset = LineOffsets[RefId]

        local RealErrorLine = OriginalErrorLine - LineOffset + 1
        if RealErrorLine < 0 then
            RealErrorLine = "?"
        end

        return VirtualFullName .. ":" .. RealErrorLine .. ": " .. BaseErrorMessage
    end

    -- If it's a BaseScript, we'll just run it directly!
    if ScriptClassName == "LocalScript" or ScriptClassName == "Script" then
        local RunSuccess, ErrorMessage = pcall(Closure)
        if not RunSuccess then
            error(FormatError(ErrorMessage), 0)
        end
    else
        local PCallReturn = {pcall(Closure)}

        local RunSuccess = table_remove(PCallReturn, 1)
        if not RunSuccess then
            local ErrorMessage = table_remove(PCallReturn, 1)
            error(FormatError(ErrorMessage), 0)
        end

        StoredModuleValues[scriptRef] = PCallReturn
        return unpack(PCallReturn)
    end
end

-- We'll assign the actual func from the top of this output for flattening user globals at runtime
-- Returns (in a tuple order): wax, script, require
function ImportGlobals(refId)
    local ScriptRef = RefBindings[refId]

    local function RealCall(f, ...)
        local PCallReturn = {pcall(f, ...)}

        local CallSuccess = table_remove(PCallReturn, 1)
        if not CallSuccess then
            error(PCallReturn[1], 3)
        end

        return unpack(PCallReturn)
    end

    -- `wax.shared` index
    local WaxShared = table_freeze(setmetatable({}, {
        __index = SharedEnvironment,
        __newindex = function(_, index, value)
            SharedEnvironment[index] = value
        end,
        __len = function()
            return #SharedEnvironment
        end,
        __iter = function()
            return next, SharedEnvironment
        end,
    }))

    local Global_wax = table_freeze({
        -- From AOT variable imports
        version = WaxVersion,
        envname = EnvName,

        shared = WaxShared,

        -- "Real" globals instead of the env set ones
        script = script,
        require = require,
    })

    local Global_script = ScriptRef

    local function Global_require(module, ...)
        local ModuleArgType = type(module)

        local ErrorNonModuleScript = "Attempted to call require with a non-ModuleScript"
        local ErrorSelfRequire = "Attempted to call require with self"

        if ModuleArgType == "table" and RefChildren[module]  then
            if module.ClassName ~= "ModuleScript" then
                error(ErrorNonModuleScript, 2)
            elseif module == ScriptRef then
                error(ErrorSelfRequire, 2)
            end

            return LoadScript(module)
        elseif ModuleArgType == "string" and string_sub(module, 1, 1) ~= "@" then
            -- The control flow on this SUCKS

            if #module == 0 then
                error("Attempted to call require with empty string", 2)
            end

            local CurrentRefPointer = ScriptRef

            if string_sub(module, 1, 1) == "/" then
                CurrentRefPointer = RealObjectRoot
            elseif string_sub(module, 1, 2) == "./" then
                module = string_sub(module, 3)
            end

            local PreviousPathMatch
            for PathMatch in string_gmatch(module, "([^/]*)/?") do
                local RealIndex = PathMatch
                if PathMatch == "." then
                    RealIndex = ""
                elseif PathMatch == ".." then
                    CurrentRefPointer = CurrentRefPointer.Parent
                    RealIndex = ""
                end

                -- Don't advance dir if it's just another "/" either
                if RealIndex ~= "" then
                    local ResultRef = CurrentRefPointer:FindFirstChild(RealIndex)
                    if not ResultRef then
                        local CurrentRefParent = CurrentRefPointer.Parent
                        if CurrentRefParent then
                            ResultRef = CurrentRefParent:FindFirstChild(RealIndex)
                        end
                    end

                    if ResultRef then
                        CurrentRefPointer = ResultRef
                    elseif PathMatch ~= PreviousPathMatch and PathMatch ~= "init" and PathMatch ~= "init.server" and PathMatch ~= "init.client" then
                        error("Virtual script path \"" .. module .. "\" not found", 2)
                    end
                end

                -- For possible checks next cycle
                PreviousPathMatch = PathMatch
            end

            if CurrentRefPointer.ClassName ~= "ModuleScript" then
                error(ErrorNonModuleScript, 2)
            elseif CurrentRefPointer == ScriptRef then
                error(ErrorSelfRequire, 2)
            end

            return LoadScript(CurrentRefPointer)
        end

        return RealCall(require, module, ...)
    end

    -- Now, return flattened globals ready for direct runtime exec
    return Global_wax, Global_script, Global_require
end

for _, ScriptRef in next, ScriptsToRun do
    Defer(LoadScript, ScriptRef)
end

-- AoT adjustment: Load init module (MainModule behavior)
return LoadScript(RealObjectRoot:GetChildren()[1])