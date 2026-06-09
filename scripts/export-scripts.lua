local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local SCRIPT_CLASSES = {
    Script = true,
    LocalScript = true,
    ModuleScript = true,
}

local CONFIG = {
    scriptExtensions = {
        Script = ".server.lua",
        LocalScript = ".client.lua",
        ModuleScript = ".lua",
    },

    services = {
        "Workspace",
        "ServerScriptService",
        "ReplicatedStorage",
        "ServerStorage",
        "StarterPlayer",
        "StarterGui",
        "ReplicatedFirst",
        "StarterPack",
        "Lighting",
        "SoundService",
        "Teams",
        "Players",
        "Chat",
        "TextChatService",
    },

    skipInstances = {
        "Camera",
        "Terrain",
    },
}

local PROPERTY_MAP = {
    BasePart = {
        "Size", "Position", "CFrame",
        "Anchored", "CanCollide", "CastShadow", "Massless", "Locked",
        "Material", "Color", "BrickColor", "Transparency", "Reflectance",
        "CollisionGroupId", "RenderFidelity", "CollisionFidelity",
    },
    Part = { "Shape" },
    MeshPart = { "MeshId", "TextureID" },
    SpecialMesh = { "MeshType", "MeshId", "TextureId", "Scale", "Offset" },
    UnionOperation = { "UsePartColor" },
    TrussPart = { "Style" },
    WedgePart = {},
    CornerWedgePart = {},
    SpawnLocation = { "Neutral", "AllowTeamChangeOnTouch", "Duration", "TeamColor" },
    Seat = { "Disabled" },
    VehicleSeat = { "Disabled", "MaxSpeed", "SteerFloat", "ThrottleFloat" },

    Model = { "LevelOfDetail" },
    Folder = {},
    Configuration = {},

    Script = { "Disabled", "RunContext" },
    LocalScript = { "Disabled" },
    ModuleScript = {},

    RemoteEvent = {},
    RemoteFunction = {},
    BindableEvent = {},
    BindableFunction = {},

    StringValue = { "Value" },
    IntValue = { "Value" },
    NumberValue = { "Value" },
    BoolValue = { "Value" },
    Vector3Value = { "Value" },
    CFrameValue = { "Value" },
    Color3Value = { "Value" },
    ObjectValue = { "Value" },

    Humanoid = {
        "MaxHealth", "Health", "WalkSpeed", "JumpPower", "AutoRotate",
        "DisplayName", "NameDisplayDistance", "HealthDisplayDistance",
        "HipHeight", "UseJumpPower", "RigType",
    },
    HumanoidDescription = {
        "HatAccessory", "HairAccessory", "FaceAccessory",
        "BodyTypeScale", "HeadScale", "HeightScale", "ProportionScale",
        "BackAccessory", "FrontAccessory", "NeckAccessory", "ShouldersAccessory",
        "WaistAccessory",
    },
    Animator = {},
    AnimationTrack = {},
    Animation = { "AnimationId" },

    Sound = {
        "SoundId", "Volume", "Looped", "Playing", "PlaybackSpeed",
        "RollOffMaxDistance", "RollOffMinDistance", "RollOffMode", "TimePosition",
    },
    SoundGroup = { "Volume" },
    EqualizerSoundEffect = { "HighGain", "MidGain", "LowGain", "Enabled" },
    ReverbSoundEffect = { "DecayTime", "Density", "Diffusion", "DryLevel", "WetLevel", "Enabled" },
    DistortionSoundEffect = { "Level", "Enabled" },
    EchoSoundEffect = { "Delay", "Feedback", "DryLevel", "WetLevel", "Enabled" },

    Lighting = {
        "Ambient", "Brightness", "ColorShift_Bottom", "ColorShift_Top",
        "EnvironmentDiffuseScale", "EnvironmentSpecularScale",
        "ExposureCompensation", "FogColor", "FogEnd", "FogStart",
        "GlobalShadows", "OutdoorAmbient", "ShadowSoftness",
        "ClockTime", "GeographicLatitude", "Technology",
    },
    Atmosphere = { "Color", "Decay", "Density", "Glare", "Haze", "Offset" },
    Sky = {
        "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp",
        "SunTextureId", "MoonTextureId", "CelestialBodiesShown",
    },
    BloomEffect = { "Enabled", "Intensity", "Size", "Threshold" },
    ColorCorrectionEffect = { "Enabled", "Brightness", "Contrast", "Saturation", "TintColor" },
    SunRaysEffect = { "Enabled", "Intensity", "Spread" },
    DepthOfFieldEffect = { "Enabled", "FarIntensity", "FocusDistance", "InFocusRadius", "NearIntensity" },
    PointLight = { "Brightness", "Color", "Range", "Enabled", "Shadows" },
    SpotLight = { "Brightness", "Color", "Range", "Angle", "Enabled", "Shadows", "Face" },
    SurfaceLight = { "Brightness", "Color", "Range", "Angle", "Enabled", "Shadows", "Face" },

    Decal = { "Texture", "Transparency", "Color3", "Face", "ZIndex" },
    Texture = {
        "Texture", "Transparency", "Color3", "Face",
        "StudsPerTileU", "StudsPerTileV", "OffsetStudsU", "OffsetStudsV",
    },
    SurfaceAppearance = { "AlphaMode", "ColorMap", "MetalnessMap", "NormalMap", "RoughnessMap" },

    WeldConstraint = { "Enabled" },
    RigidConstraint = { "Enabled" },
    NoCollisionConstraint = { "Enabled" },
    HingeConstraint = { "ActuatorType", "Enabled", "LimitsEnabled" },
    BallSocketConstraint = { "Enabled", "LimitsEnabled" },
    CylindricalConstraint = { "ActuatorType", "Enabled", "LimitsEnabled" },
    RopeConstraint = { "Length", "Thickness", "Enabled", "Restitution" },
    Motor6D = { "MaxVelocity", "CurrentAngle", "DesiredAngle" },
    BodyPosition = { "MaxForce", "Position", "P", "D" },
    BodyVelocity = { "MaxForce", "Velocity", "P" },
    BodyAngularVelocity = { "MaxTorque", "AngularVelocity", "P" },
    BodyGyro = { "MaxTorque", "P", "D" },
    LinearVelocity = { "MaxForce", "VelocityConstraintMode", "Enabled" },
    VectorForce = { "Force", "Enabled", "RelativeTo" },

    Workspace = {
        "Gravity", "StreamingEnabled", "StreamingMinRadius",
        "StreamingTargetRadius", "FallenPartsDestroyHeight",
        "SignalBehavior",
    },

    Team = { "AutoAssignable", "TeamColor" },

    GuiBase = {
        "Position", "Size", "AnchorPoint",
        "BackgroundColor3", "BackgroundTransparency",
        "BorderColor3", "BorderSizePixel",
        "Visible", "ZIndex", "LayoutOrder",
        "SizeConstraint", "AutomaticSize",
    },
    ScreenGui = {
        "DisplayOrder", "Enabled", "IgnoreGuiInset",
        "ResetOnSpawn", "ZIndexBehavior",
    },
    Frame = {},
    ScrollingFrame = {
        "CanvasSize", "ScrollBarThickness", "ScrollingEnabled",
        "HorizontalScrollBarInset", "VerticalScrollBarInset",
    },
    ViewportFrame = { "CurrentCamera", "Ambient", "LightColor", "LightDirection" },
    BillboardGui = {
        "Size", "StudsOffset", "AlwaysOnTop",
        "Enabled", "MaxDistance", "LightInfluence",
    },
    SurfaceGui = {
        "Face", "SizingMode", "CanvasSize", "AlwaysOnTop",
        "Enabled", "PixelsPerStud", "ZOffset", "LightInfluence",
    },
    TextLabel = {
        "Text", "TextColor3", "TextSize", "Font",
        "TextWrapped", "TextXAlignment", "TextYAlignment",
        "TextTransparency", "TextScaled", "RichText",
        "LineHeight", "MaxVisibleGraphemes",
    },
    TextButton = {
        "Text", "TextColor3", "TextSize", "Font",
        "TextWrapped", "AutoButtonColor", "Modal",
    },
    TextBox = {
        "Text", "PlaceholderText", "PlaceholderColor3",
        "TextColor3", "TextSize", "Font",
        "ClearTextOnFocus", "MultiLine",
    },
    ImageLabel = { "Image", "ImageColor3", "ImageTransparency", "ScaleType" },
    ImageButton = { "Image", "ImageColor3", "ImageTransparency", "ScaleType", "AutoButtonColor" },

    UIListLayout = {
        "FillDirection", "HorizontalAlignment", "VerticalAlignment",
        "SortOrder", "Padding", "ItemLineAlignment",
    },
    UIGridLayout = {
        "CellSize", "CellPadding", "FillDirection",
        "HorizontalAlignment", "VerticalAlignment", "SortOrder",
    },
    UITableLayout = { "FillEmptySpaceColumns", "FillEmptySpaceRows", "SortOrder" },
    UICorner = { "CornerRadius" },
    UIPadding = { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" },
    UIStroke = { "Color", "Thickness", "Transparency", "ApplyStrokeMode" },
    UIAspectRatioConstraint = { "AspectRatio", "AspectType", "DominantAxis" },
    UIScale = { "Scale" },
    UITextSizeConstraint = { "MaxTextSize", "MinTextSize" },
    UISizeConstraint = { "MaxSize", "MinSize" },
    UIGradient = { "Color", "Rotation", "Transparency", "Enabled", "Offset" },

    ProximityPrompt = {
        "ActionText", "ObjectText", "HoldDuration",
        "MaxActivationDistance", "Enabled", "RequiresLineOfSight",
        "Style", "KeyboardKeyCode", "GamepadKeyCode",
    },
    ClickDetector = { "MaxActivationDistance" },
    DragDetector = { "DragStyle", "MaxDragAngle", "MaxDragTranslation", "Enabled" },
    SelectionBox = { "Color3", "LineThickness", "SurfaceTransparency" },
    SelectionSphere = { "Color3", "SurfaceTransparency" },

    TerrainRegion = {},

    TweenService = {},
    Tween = {},
}

local BASE_CLASSES = {
    Part = "BasePart",
    MeshPart = "BasePart",
    UnionOperation = "BasePart",
    TrussPart = "BasePart",
    WedgePart = "BasePart",
    CornerWedgePart = "BasePart",
    SpawnLocation = "BasePart",
    Seat = "BasePart",
    VehicleSeat = "BasePart",
    TextLabel = "GuiBase",
    TextButton = "GuiBase",
    TextBox = "GuiBase",
    ImageLabel = "GuiBase",
    ImageButton = "GuiBase",
    Frame = "GuiBase",
    ScrollingFrame = "GuiBase",
    ViewportFrame = "GuiBase",
}

local function newScriptStats()
    return {
        totalScripts = 0,
        scriptTypes = {},
        servicesProcessed = 0,
        nestedScripts = 0,
        errors = {},
    }
end

local function newObjectStats()
    return {
        totalNodes = 0,
        scripts = 0,
        classCounts = {},
        errors = {},
    }
end

local function sanitizePath(name)
    local sanitized = name:gsub("[^%w%-%_%.%s]", "_")
        :gsub("%s+", "_")
        :gsub("_+", "_")
        :gsub("^_", "")
        :gsub("_$", "")

    if sanitized == "" then
        return "unnamed"
    end

    return sanitized
end

local function ensureDir(path)
    local success = pcall(function()
        fs.writeDir(path)
    end)
    return success
end

local function shouldSkip(instance)
    for _, skipName in ipairs(CONFIG.skipInstances) do
        if instance.Name == skipName or instance.ClassName == skipName then
            return true
        end
    end
    return false
end

local function getFileNameWithoutExtension(path)
    local filename = path:match("([^/\\]+)$") or path
    return filename:match("(.+)%..+$") or filename
end

local function isScript(instance)
    return SCRIPT_CLASSES[instance.ClassName] == true
end

local function serializeValue(value)
    if value == nil then
        return nil
    end

    local valueType = typeof(value)

    if valueType == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return tostring(value)
        end
        return value
    elseif valueType == "boolean" or valueType == "string" then
        return value
    elseif valueType == "Vector3" then
        return { _type = "Vector3", x = value.X, y = value.Y, z = value.Z }
    elseif valueType == "Vector2" then
        return { _type = "Vector2", x = value.X, y = value.Y }
    elseif valueType == "CFrame" then
        local position = value.Position
        local rx, ry, rz = value:ToEulerAnglesXYZ()
        return {
            _type = "CFrame",
            position = { x = position.X, y = position.Y, z = position.Z },
            rotation_deg = {
                x = math.round(math.deg(rx) * 1000) / 1000,
                y = math.round(math.deg(ry) * 1000) / 1000,
                z = math.round(math.deg(rz) * 1000) / 1000,
            },
        }
    elseif valueType == "Color3" then
        local r = math.round(value.R * 255)
        local g = math.round(value.G * 255)
        local b = math.round(value.B * 255)
        return {
            _type = "Color3",
            r = r,
            g = g,
            b = b,
            hex = string.format("#%02X%02X%02X", r, g, b),
        }
    elseif valueType == "BrickColor" then
        return { _type = "BrickColor", name = tostring(value) }
    elseif valueType == "EnumItem" then
        return { _type = "Enum", enumType = tostring(value.EnumType), value = value.Name }
    elseif valueType == "UDim2" then
        return {
            _type = "UDim2",
            x = { scale = value.X.Scale, offset = value.X.Offset },
            y = { scale = value.Y.Scale, offset = value.Y.Offset },
        }
    elseif valueType == "UDim" then
        return { _type = "UDim", scale = value.Scale, offset = value.Offset }
    elseif valueType == "Rect" then
        return {
            _type = "Rect",
            min = { x = value.Min.X, y = value.Min.Y },
            max = { x = value.Max.X, y = value.Max.Y },
        }
    elseif valueType == "NumberRange" then
        return { _type = "NumberRange", min = value.Min, max = value.Max }
    elseif valueType == "NumberSequence" then
        local keypoints = {}
        for _, keypoint in ipairs(value.Keypoints) do
            table.insert(keypoints, {
                time = keypoint.Time,
                value = keypoint.Value,
                envelope = keypoint.Envelope,
            })
        end
        return { _type = "NumberSequence", keypoints = keypoints }
    elseif valueType == "ColorSequence" then
        local keypoints = {}
        for _, keypoint in ipairs(value.Keypoints) do
            local color = keypoint.Value
            table.insert(keypoints, {
                time = keypoint.Time,
                color = {
                    r = math.round(color.R * 255),
                    g = math.round(color.G * 255),
                    b = math.round(color.B * 255),
                },
            })
        end
        return { _type = "ColorSequence", keypoints = keypoints }
    elseif valueType == "Instance" then
        return { _type = "InstanceRef", name = value.Name, class = value.ClassName }
    end

    local ok, stringValue = pcall(tostring, value)
    return ok and stringValue or nil
end

local function buildPropertyList(className)
    local seen = {}
    local properties = {}

    local function add(list)
        if not list then
            return
        end

        for _, propertyName in ipairs(list) do
            if not seen[propertyName] then
                seen[propertyName] = true
                table.insert(properties, propertyName)
            end
        end
    end

    add(PROPERTY_MAP[className])

    local baseClass = BASE_CLASSES[className]
    if baseClass then
        add(PROPERTY_MAP[baseClass])
    end

    return properties
end

local function extractProperties(instance)
    local propertyNames = buildPropertyList(instance.ClassName)
    if #propertyNames == 0 then
        return {}
    end

    local properties = {}
    for _, propertyName in ipairs(propertyNames) do
        local ok, rawValue = pcall(function()
            return instance[propertyName]
        end)

        if ok and rawValue ~= nil then
            local serializedValue = serializeValue(rawValue)
            if serializedValue ~= nil then
                properties[propertyName] = serializedValue
            end
        end
    end

    return properties
end

local function hasScriptsDeep(instance)
    if shouldSkip(instance) then
        return false
    end

    if isScript(instance) then
        return true
    end

    for _, child in ipairs(instance:GetChildren()) do
        if hasScriptsDeep(child) then
            return true
        end
    end

    return false
end

local function hasDirectScriptChildren(instance)
    for _, child in ipairs(instance:GetChildren()) do
        if isScript(child) or hasScriptsDeep(child) then
            return true
        end
    end
    return false
end

local function createScriptMetadata(instance)
    local metadata = {
        name = instance.Name,
        className = instance.ClassName,
        parent = instance.Parent and instance.Parent.Name or "DataModel",
        fullPath = {},
        properties = {},
        isNestedScript = false,
    }

    local current = instance.Parent
    while current and current.Parent do
        table.insert(metadata.fullPath, 1, current.Name)
        if isScript(current) then
            metadata.isNestedScript = true
        end
        current = current.Parent
    end

    if instance.ClassName == "Script" then
        metadata.properties.Disabled = instance.Disabled
        metadata.properties.RunContext = instance.RunContext
    elseif instance.ClassName == "LocalScript" then
        metadata.properties.Disabled = instance.Disabled
    end

    return metadata
end

local function generateScriptHeader(metadata)
    local lines = {
        "--[[",
        string.format("    %s (%s)", metadata.name, metadata.className),
        string.format("    Path: %s", table.concat(metadata.fullPath, " -> ")),
        string.format("    Parent: %s", metadata.parent),
    }

    if metadata.isNestedScript then
        table.insert(lines, "    NESTED SCRIPT: This script is inside another script")
    end

    if next(metadata.properties) then
        table.insert(lines, "    Properties:")
        for propertyName, value in pairs(metadata.properties) do
            table.insert(lines, string.format("        %s: %s", propertyName, tostring(value)))
        end
    end

    table.insert(lines, string.format("    Exported: %s", os.date("%Y-%m-%d %H:%M:%S")))
    table.insert(lines, "]]")
    table.insert(lines, "")

    return table.concat(lines, "\n")
end

local function getSortedChildren(instance)
    local children = instance:GetChildren()
    table.sort(children, function(a, b)
        local aIsScript = isScript(a)
        local bIsScript = isScript(b)

        if aIsScript ~= bIsScript then
            return aIsScript
        end

        return a.Name < b.Name
    end)
    return children
end

local function buildUniqueChildNames(children)
    local seenNames = {}
    local uniqueNames = {}

    for _, child in ipairs(children) do
        local baseName = sanitizePath(child.Name)
        local count = (seenNames[baseName] or 0) + 1
        seenNames[baseName] = count

        if count == 1 then
            uniqueNames[child] = baseName
        else
            uniqueNames[child] = string.format("%s_%d", baseName, count)
        end
    end

    return uniqueNames
end

local processScriptInstance

local function processScriptChildren(instance, currentPath, stats, depth)
    local children = getSortedChildren(instance)
    local uniqueNames = buildUniqueChildNames(children)

    for _, child in ipairs(children) do
        processScriptInstance(child, currentPath, stats, depth, uniqueNames[child])
    end
end

processScriptInstance = function(instance, currentPath, stats, depth, resolvedName)
    depth = depth or 0

    if depth > 25 then
        table.insert(stats.errors, "Max depth reached at: " .. currentPath)
        return
    end

    if shouldSkip(instance) then
        return
    end

    local sanitizedName = resolvedName or sanitizePath(instance.Name)
    local currentIsScript = isScript(instance)

    if currentIsScript then
        local extension = CONFIG.scriptExtensions[instance.ClassName] or ".lua"
        local filePath = currentPath .. "/" .. sanitizedName .. extension
        local source = instance.Source or "-- No source code found"
        local metadata = createScriptMetadata(instance)
        local header = generateScriptHeader(metadata)

        local ok, err = pcall(function()
            fs.writeFile(filePath, header .. source)
        end)

        if ok then
            stats.totalScripts = stats.totalScripts + 1
            stats.scriptTypes[instance.ClassName] = (stats.scriptTypes[instance.ClassName] or 0) + 1

            if metadata.isNestedScript then
                stats.nestedScripts = stats.nestedScripts + 1
                print(string.format("  [script] %s (nested)", filePath))
            else
                print(string.format("  [script] %s", filePath))
            end
        else
            table.insert(stats.errors, "Failed to write " .. filePath .. ": " .. tostring(err))
            print(string.format("  [script] failed %s", filePath))
        end

        local children = instance:GetChildren()
        if #children > 0 and hasDirectScriptChildren(instance) then
            local scriptFolder = currentPath .. "/" .. sanitizedName .. "_contents"
            ensureDir(scriptFolder)
            processScriptChildren(instance, scriptFolder, stats, depth + 1)
        end

        return
    end

    if not hasScriptsDeep(instance) then
        return
    end

    local newPath = currentPath .. "/" .. sanitizedName
    if ensureDir(newPath) then
        processScriptChildren(instance, newPath, stats, depth + 1)
    end
end

local function createProjectInfo(outputDir, inputPath, options)
    local projectInfo = {
        sourceFile = inputPath,
        exportDate = os.date("%Y-%m-%d %H:%M:%S"),
        luneVersion = "0.9.3",
        exportTarget = options.exportTarget,
        objectMode = options.objectMode,
        structure = "Service-based script export with optional object hierarchy companion export",
        notes = {
            "Server scripts have .server.lua extension",
            "Client scripts have .client.lua extension",
            "Module scripts have .lua extension",
            "Nested scripts are placed in '_contents' folders",
            "Scripts inside scripts are marked as NESTED in headers",
            "Metadata preserved in file headers",
            "Empty '_contents' folders are not created",
        },
    }

    local content = "-- Project Export Information\n"
    content = content .. "-- Generated by Roblox Script Exporter\n\n"
    content = content .. string.format("return %s", table.concat({
        "{",
        string.format('    sourceFile = "%s",', projectInfo.sourceFile),
        string.format('    exportDate = "%s",', projectInfo.exportDate),
        string.format('    luneVersion = "%s",', projectInfo.luneVersion),
        string.format('    exportTarget = "%s",', projectInfo.exportTarget),
        string.format('    objectMode = "%s",', projectInfo.objectMode),
        string.format('    structure = "%s",', projectInfo.structure),
        "    notes = {",
        '        "Server scripts have .server.lua extension",',
        '        "Client scripts have .client.lua extension",',
        '        "Module scripts have .lua extension",',
        '        "Nested scripts are placed in \'_contents\' folders",',
        '        "Scripts inside scripts are marked as NESTED in headers",',
        '        "Metadata preserved in file headers",',
        '        "Empty \'_contents\' folders are not created"',
        "    }",
        "}",
    }, "\n"))

    fs.writeFile(outputDir .. "/project-info.lua", content)
end

local function exportScripts(dataModel, inputPath, outputDir, options)
    local stats = newScriptStats()

    ensureDir(outputDir)

    for _, serviceName in ipairs(CONFIG.services) do
        local service = dataModel:FindFirstChild(serviceName)
        if service and hasScriptsDeep(service) then
            print(string.format("[scripts] Processing %s...", serviceName))

            local servicePath = outputDir .. "/" .. sanitizePath(serviceName)
            ensureDir(servicePath)

            processScriptChildren(service, servicePath, stats, 0)

            stats.servicesProcessed = stats.servicesProcessed + 1
        end
    end

    createProjectInfo(outputDir, inputPath, options)

    print("\nScripts Summary")
    print("===============")
    print(string.format("Total scripts exported: %d", stats.totalScripts))
    print(string.format("Nested scripts found:  %d", stats.nestedScripts))
    print(string.format("Services processed:    %d", stats.servicesProcessed))

    if next(stats.scriptTypes) then
        print("\nScript types:")
        for scriptType, count in pairs(stats.scriptTypes) do
            print(string.format("  %s: %d", scriptType, count))
        end
    end

    if #stats.errors > 0 then
        print(string.format("\nScript export errors: %d", #stats.errors))
        for _, errorMessage in ipairs(stats.errors) do
            print("  " .. errorMessage)
        end
    end

    print(string.format("\nScripts written to: %s", outputDir))
    return stats
end

local function passesObjectFilter(instance, filters)
    if #filters == 0 then
        return true
    end

    for _, filterValue in ipairs(filters) do
        if instance.ClassName == filterValue then
            return true
        end
    end

    return false
end

local function buildObjectTree(instance, options, stats, depth)
    depth = depth or 0

    if depth > options.maxDepth or shouldSkip(instance) then
        return nil
    end

    local isScriptInstance = isScript(instance)
    if options.objectMode == "no-scripts" and isScriptInstance then
        return nil
    end

    if not passesObjectFilter(instance, options.filters) then
        local childNodes = {}
        for _, child in ipairs(instance:GetChildren()) do
            local childNode = buildObjectTree(child, options, stats, depth + 1)
            if childNode then
                table.insert(childNodes, childNode)
            end
        end

        if #childNodes > 0 then
            return {
                name = instance.Name,
                class = instance.ClassName,
                children = childNodes,
            }
        end

        return nil
    end

    local node = {
        name = instance.Name,
        class = instance.ClassName,
        properties = extractProperties(instance),
        children = {},
    }

    if isScriptInstance then
        stats.scripts = stats.scripts + 1

        if options.objectMode == "all" then
            node.properties.Source = instance.Source or ""
        else
            node.isScript = true
        end
    end

    stats.totalNodes = stats.totalNodes + 1
    stats.classCounts[instance.ClassName] = (stats.classCounts[instance.ClassName] or 0) + 1

    for _, child in ipairs(instance:GetChildren()) do
        local childNode = buildObjectTree(child, options, stats, depth + 1)
        if childNode then
            table.insert(node.children, childNode)
        end
    end

    return node
end

local function writeJson(path, value, stats)
    local ok, err = pcall(function()
        fs.writeFile(path, serde.encode("json", value, true))
    end)

    if not ok then
        table.insert(stats.errors, "Failed to write " .. path .. ": " .. tostring(err))
        return false
    end

    return true
end

local function exportObjects(dataModel, inputPath, outputDir, options)
    local stats = newObjectStats()
    ensureDir(outputDir)

    local manifest = {
        meta = {
            sourceFile = inputPath,
            exportDate = os.date("%Y-%m-%d %H:%M:%S"),
            exportTarget = options.exportTarget,
            mode = options.objectMode,
            maxDepth = options.maxDepth,
            filters = options.filters,
            exporter = "roblox-script-exporter unified",
        },
        services = {},
        stats = {},
    }

    local totalServices = 0

    for _, serviceName in ipairs(CONFIG.services) do
        local service = dataModel:FindFirstChild(serviceName)
        if service then
            print(string.format("[objects] Processing %s...", serviceName))

            local serviceData = {
                name = serviceName,
                class = service.ClassName,
                properties = extractProperties(service),
                children = {},
            }

            for _, child in ipairs(service:GetChildren()) do
                local node = buildObjectTree(child, options, stats, 0)
                if node then
                    table.insert(serviceData.children, node)
                end
            end

            local outputFile = outputDir .. "/" .. sanitizePath(serviceName) .. ".json"
            if writeJson(outputFile, serviceData, stats) then
                print(string.format("  [objects] %d top-level nodes -> %s", #serviceData.children, outputFile))
            else
                print(string.format("  [objects] failed %s", outputFile))
            end

            table.insert(manifest.services, {
                name = serviceName,
                class = service.ClassName,
                topLevelNodes = #serviceData.children,
                file = sanitizePath(serviceName) .. ".json",
            })

            totalServices = totalServices + 1
        end
    end

    local classEntries = {}
    for className, count in pairs(stats.classCounts) do
        table.insert(classEntries, { class = className, count = count })
    end

    table.sort(classEntries, function(a, b)
        return a.count > b.count
    end)

    local topClasses = {}
    for index = 1, math.min(10, #classEntries) do
        table.insert(topClasses, classEntries[index])
    end

    manifest.stats = {
        totalNodes = stats.totalNodes,
        scriptsFound = stats.scripts,
        servicesExported = totalServices,
        uniqueClasses = #classEntries,
        topClasses = topClasses,
        errors = stats.errors,
    }

    writeJson(outputDir .. "/manifest.json", manifest, stats)

    print("\nObjects Summary")
    print("===============")
    print(string.format("Services exported: %d", totalServices))
    print(string.format("Nodes exported:    %d", stats.totalNodes))
    print(string.format("Scripts found:     %d", stats.scripts))
    print(string.format("Unique classes:    %d", #classEntries))

    if #classEntries > 0 then
        print("\nTop classes:")
        for index = 1, math.min(10, #classEntries) do
            local entry = classEntries[index]
            print(string.format("  %-35s %d", entry.class, entry.count))
        end
        if #classEntries > 10 then
            print(string.format("  ... and %d more", #classEntries - 10))
        end
    end

    if #stats.errors > 0 then
        print(string.format("\nObject export errors: %d", #stats.errors))
        for _, errorMessage in ipairs(stats.errors) do
            print("  " .. errorMessage)
        end
    end

    print(string.format("\nObjects written to: %s", outputDir))
    return stats
end

local function parseArgs(args)
    local options = {
        inputPath = nil,
        outputArg = nil,
        scriptsDir = nil,
        objectsDir = nil,
        exportTarget = "both",
        objectMode = "objects",
        maxDepth = 50,
        filters = {},
    }

    local index = 1
    while index <= #args do
        local arg = args[index]

        if arg == "--export" and args[index + 1] then
            options.exportTarget = args[index + 1]
            index = index + 2
        elseif arg:sub(1, 9) == "--export=" then
            options.exportTarget = arg:sub(10)
            index = index + 1
        elseif arg == "--mode" and args[index + 1] then
            options.objectMode = args[index + 1]
            index = index + 2
        elseif arg:sub(1, 7) == "--mode=" then
            options.objectMode = arg:sub(8)
            index = index + 1
        elseif arg == "--depth" and args[index + 1] then
            options.maxDepth = tonumber(args[index + 1]) or options.maxDepth
            index = index + 2
        elseif arg:sub(1, 8) == "--depth=" then
            options.maxDepth = tonumber(arg:sub(9)) or options.maxDepth
            index = index + 1
        elseif arg == "--filter" and args[index + 1] then
            table.insert(options.filters, args[index + 1])
            index = index + 2
        elseif arg:sub(1, 9) == "--filter=" then
            table.insert(options.filters, arg:sub(10))
            index = index + 1
        elseif arg == "--scripts-dir" and args[index + 1] then
            options.scriptsDir = args[index + 1]
            index = index + 2
        elseif arg:sub(1, 14) == "--scripts-dir=" then
            options.scriptsDir = arg:sub(15)
            index = index + 1
        elseif arg == "--objects-dir" and args[index + 1] then
            options.objectsDir = args[index + 1]
            index = index + 2
        elseif arg:sub(1, 14) == "--objects-dir=" then
            options.objectsDir = arg:sub(15)
            index = index + 1
        elseif arg:sub(1, 2) ~= "--" then
            if not options.inputPath then
                options.inputPath = arg
            elseif not options.outputArg then
                options.outputArg = arg
            end
            index = index + 1
        else
            index = index + 1
        end
    end

    return options
end

local function resolveOutputDirs(inputPath, options)
    local baseName = sanitizePath(getFileNameWithoutExtension(inputPath))
    local scriptsOutput = options.scriptsDir
    local objectsOutput = options.objectsDir

    if options.exportTarget == "both" then
        local combinedOutput = options.outputArg or scriptsOutput or objectsOutput or (baseName .. "-export")

        if not scriptsOutput then
            scriptsOutput = combinedOutput
        end
        if not objectsOutput then
            objectsOutput = combinedOutput
        end
    elseif options.exportTarget == "scripts" then
        scriptsOutput = scriptsOutput or options.outputArg or (baseName .. "-scripts")
    elseif options.exportTarget == "objects" then
        objectsOutput = objectsOutput or options.outputArg or (baseName .. "-objects")
    end

    return scriptsOutput, objectsOutput
end

local function printUsage()
    print("Roblox Script Exporter")
    print("======================")
    print("Usage:")
    print("  lune run export-scripts.lua <input.rbxl> [output-dir] [options]")
    print("")
    print("Options:")
    print("  --export <scripts|objects|both>   What to export (default: both)")
    print("  --mode <objects|all|no-scripts>   Object export mode (default: objects)")
    print("  --depth <n>                       Object export max depth (default: 50)")
    print("  --filter <Class>                  Include only this class in object JSON")
    print("  --scripts-dir <dir>               Override the scripts output folder")
    print("  --objects-dir <dir>               Override the objects output folder")
    print("")
    print("Examples:")
    print("  lune run export-scripts.lua MyGame.rbxl")
    print("  lune run export-scripts.lua MyGame.rbxl --export scripts")
    print("  lune run export-scripts.lua MyGame.rbxl --export objects --mode all")
    print("  lune run export-scripts.lua MyGame.rbxl export-output")
    print("    # combined export now writes both scripts and objects into export-output/")
    print("  lune run export-scripts.lua MyGame.rbxl --scripts-dir MyGame-scripts --objects-dir MyGame-objects")
end

local function loadPlace(inputPath)
    local fileContent
    local ok, err = pcall(function()
        fileContent = fs.readFile(inputPath)
    end)

    if not ok then
        return nil, "Cannot read file: " .. tostring(err)
    end

    local dataModel
    ok, err = pcall(function()
        dataModel = roblox.deserializePlace(fileContent)
    end)

    if not ok then
        return nil, "Cannot deserialize place: " .. tostring(err)
    end

    return dataModel
end

local function main(args)
    local options = parseArgs(args or process.args)
    if not options.inputPath then
        printUsage()
        return
    end

    local validExports = { scripts = true, objects = true, both = true }
    if not validExports[options.exportTarget] then
        print("Unknown export target: " .. tostring(options.exportTarget))
        printUsage()
        return
    end

    local validModes = { objects = true, all = true, ["no-scripts"] = true }
    if not validModes[options.objectMode] then
        print("Unknown object mode: " .. tostring(options.objectMode))
        printUsage()
        return
    end

    local scriptsOutput, objectsOutput = resolveOutputDirs(options.inputPath, options)

    print("Unified Roblox Exporter")
    print("=======================")
    print(string.format("Input:   %s", options.inputPath))
    print(string.format("Export:  %s", options.exportTarget))
    if scriptsOutput then
        print(string.format("Scripts: %s", scriptsOutput))
    end
    if objectsOutput then
        print(string.format("Objects: %s", objectsOutput))
        print(string.format("Mode:    %s", options.objectMode))
        print(string.format("Depth:   %d", options.maxDepth))
        if #options.filters > 0 then
            print(string.format("Filter:  %s", table.concat(options.filters, ", ")))
        end
    end
    print()

    local dataModel, err = loadPlace(options.inputPath)
    if not dataModel then
        print("Failed to load place: " .. tostring(err))
        return
    end

    if options.exportTarget == "scripts" or options.exportTarget == "both" then
        exportScripts(dataModel, options.inputPath, scriptsOutput, options)
        print()
    end

    if options.exportTarget == "objects" or options.exportTarget == "both" then
        exportObjects(dataModel, options.inputPath, objectsOutput, options)
        print()
    end

    print("Export complete.")
end

local exporter = {
    main = main,
}

if not _G.__ROBLOX_EXPORTER_AS_MODULE__ then
    main(process.args)
end

return exporter
