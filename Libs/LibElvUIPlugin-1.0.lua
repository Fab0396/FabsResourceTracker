local MAJOR, MINOR = "LibElvUIPlugin-1.0", 3
local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then return end

lib.plugins = lib.plugins or {}
lib.index = lib.index or 1

-- Register a plugin with ElvUI
function lib:RegisterPlugin(pluginName, insertOptions)
    if not pluginName or type(pluginName) ~= "string" then return end
    
    self.plugins[pluginName] = insertOptions or true
    
    -- If ElvUI is loaded, insert options now
    if _G.ElvUI then
        local E = unpack(_G.ElvUI)
        if E and E.Libs and E.Libs.AceConfigRegistry then
            if type(insertOptions) == "function" then
                insertOptions()
            end
        end
    end
end

-- Get plugin table
function lib:GetPluginTable()
    return self.plugins
end

-- Check if plugin is registered
function lib:IsPluginRegistered(pluginName)
    return self.plugins[pluginName] ~= nil
end
