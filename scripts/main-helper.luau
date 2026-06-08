--// this file manages bundles that have been packaged and are being used.

local __bundle_name =
--// ** DO NOT TOUCH ** IDENTIFIER: BUNDLE_NAME

local __bundle_control_key =
--// ** DO NOT TOUCH ** IDENTIFIER: CONTROL_KEY

local __bundle_modules = {}
local __bundle_cache = {}
local __bundle_loading = {}
local __bundle_nil_sentinel = {}
local __bundle_stop_sentinel = {}
local __bundle_finished = false
local __bundle_stop_requested = false
local __bundle_hook_original = nil
local __bundle_hook_installed = false
local __bundle_shared = shared

if type(__bundle_shared) ~= "table" then
    error("The shared table is unavailable", 0)
end

__bundle_shared[__bundle_control_key] = false

local function bundle_should_stop()
    if __bundle_stop_requested or __bundle_shared[__bundle_control_key] == true then
        __bundle_stop_requested = true
    end
    return __bundle_stop_requested
end

local function bundle_checkpoint()
    if bundle_should_stop() then
        error(__bundle_stop_sentinel, 0)
    end
end

-- hookmetamethod is opportunistic here: ordinary writes to an existing table key
-- bypass __newindex, so the polling task remains the reliable notification path.
if type(hookmetamethod) == "function" then
    local hook_ok, original_or_error = pcall(function()
        local original
        original = hookmetamethod(__bundle_shared, "__newindex", function(target, key, value)
            if target == __bundle_shared and key == __bundle_control_key and value == true then
                __bundle_stop_requested = true
            end
            return original(target, key, value)
        end)
        return original
    end)

    if hook_ok and type(original_or_error) == "function" then
        __bundle_hook_original = original_or_error
        __bundle_hook_installed = true
    end
end

task.spawn(function()
    while not __bundle_finished do
        if __bundle_shared[__bundle_control_key] == true then
            __bundle_stop_requested = true
            return
        end
        task.wait(0.1)
    end
end)

local function __bundle_require(module_id)
    bundle_checkpoint()

    local cached = __bundle_cache[module_id]
    if cached ~= nil then
        if cached == __bundle_nil_sentinel then
            return nil
        end
        return cached
    end

    local loader = __bundle_modules[module_id]
    if loader == nil then
        error(`Unknown packaged module: {module_id}`, 0)
    end
    if __bundle_loading[module_id] then
        error(`Circular packaged require: {module_id}`, 0)
    end

    __bundle_loading[module_id] = true
    local result = loader()
    __bundle_loading[module_id] = nil

    __bundle_cache[module_id] = if result == nil then __bundle_nil_sentinel else result
    bundle_checkpoint()
    return result
end

--// ** DO NOT TOUCH ** IDENTIFIER: MODULES

print(`Starting bundle "{__bundle_name}". Stop it with shared["{__bundle_control_key}"] = true`)

local function __bundle_error_handler(problem)
    if problem == __bundle_stop_sentinel then
        return problem
    end
    return debug.traceback(tostring(problem), 2)
end

local __bundle_ok, __bundle_result = xpcall(function()
    return __bundle_require(
--// ** DO NOT TOUCH ** IDENTIFIER: ENTRY_MODULE
    )
end, __bundle_error_handler)

__bundle_finished = true

if __bundle_hook_installed then
    pcall(function()
        hookmetamethod(__bundle_shared, "__newindex", __bundle_hook_original)
    end)
end

local __bundle_was_stopped =
    __bundle_stop_requested
    or __bundle_shared[__bundle_control_key] == true
    or (not __bundle_ok and __bundle_result == __bundle_stop_sentinel)

__bundle_shared[__bundle_control_key] = nil

if __bundle_was_stopped then
    warn(`Bundle "{__bundle_name}" was stopped (control key: {__bundle_control_key}).`)
elseif not __bundle_ok then
    warn(`Bundle "{__bundle_name}" failed:\n{__bundle_result}`)
elseif type(__bundle_result) == "number" and __bundle_result ~= 0 then
    warn(`Bundle "{__bundle_name}" exited with error code {__bundle_result}.`)
elseif __bundle_result == nil or __bundle_result == true or __bundle_result == 0 then
    print(`Bundle "{__bundle_name}" completed successfully.`)
else
    warn(
        `Bundle "{__bundle_name}" returned unsupported status `
            .. `{tostring(__bundle_result)} ({typeof(__bundle_result)}).`
    )
end
