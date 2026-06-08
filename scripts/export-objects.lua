local fs = require("@lune/fs")
local process = require("@lune/process")

local function loadUnifiedExporter()
    local source = fs.readFile("export-scripts.lua")
    local chunk, err = loadstring(source)

    if not chunk then
        error("Failed to load export-scripts.lua: " .. tostring(err))
    end

    _G.__ROBLOX_EXPORTER_AS_MODULE__ = true
    local ok, result = pcall(chunk)
    _G.__ROBLOX_EXPORTER_AS_MODULE__ = nil

    if not ok then
        error(result)
    end

    return result
end

local function main()
    print("export-objects.lua has been merged into export-scripts.lua.")
    print("Forwarding to the unified exporter with '--export objects'.")
    print("")

    local exporter = loadUnifiedExporter()
    local args = {}

    for _, value in ipairs(process.args) do
        table.insert(args, value)
    end

    local hasExportFlag = false
    for _, value in ipairs(args) do
        if value == "--export" or value:sub(1, 9) == "--export=" then
            hasExportFlag = true
            break
        end
    end

    if not hasExportFlag then
        table.insert(args, "--export")
        table.insert(args, "objects")
    end

    exporter.main(args)
end

main()
