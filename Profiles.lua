-- FabsResourceTracker / Profiles.lua
-- Native profile system: no external libraries required.
-- Export format:  !FRT_<base64-encoded serialised table>
CT = CT or {}

-- ---------------------------------------------------------------
-- Keys that belong to a profile (everything except meta/minimap)
-- ---------------------------------------------------------------
local PROFILE_KEYS = {
    "Windows", "BuffWindow", "SectionOrder", "EquipBlacklist",
    "GUIFontSize", "ShowTooltips",
}

local PREFIX = "!FRT_"

-- ---------------------------------------------------------------
-- Base64 encode / decode  (RFC 4648, pure Lua)
-- ---------------------------------------------------------------
local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function Base64Encode(data)
    local result = {}
    local pad = 0
    for i = 1, #data, 3 do
        local b0 = data:byte(i)     or 0
        local b1 = data:byte(i+1)   or (pad==0 and (pad==0) and 0)
        local b2 = data:byte(i+2)   or 0
        if not data:byte(i+1) then pad = 2 elseif not data:byte(i+2) then pad = 1 end
        local n = b0 * 65536 + (data:byte(i+1) or 0) * 256 + (data:byte(i+2) or 0)
        result[#result+1] = B64_CHARS:sub(math.floor(n/262144)%64+1, math.floor(n/262144)%64+1)
        result[#result+1] = B64_CHARS:sub(math.floor(n/4096)%64+1,   math.floor(n/4096)%64+1)
        result[#result+1] = pad >= 2 and "=" or B64_CHARS:sub(math.floor(n/64)%64+1, math.floor(n/64)%64+1)
        result[#result+1] = pad >= 1 and "=" or B64_CHARS:sub(n%64+1, n%64+1)
    end
    return table.concat(result)
end

local B64_MAP = {}
for i = 1, #B64_CHARS do B64_MAP[B64_CHARS:sub(i,i)] = i - 1 end

local function Base64Decode(data)
    data = data:gsub("[^A-Za-z0-9+/=]", "")
    local result = {}
    for i = 1, #data, 4 do
        local c0 = B64_MAP[data:sub(i,i)]   or 0
        local c1 = B64_MAP[data:sub(i+1,i+1)] or 0
        local c2 = B64_MAP[data:sub(i+2,i+2)] or 0
        local c3 = B64_MAP[data:sub(i+3,i+3)] or 0
        local n = c0 * 262144 + c1 * 4096 + c2 * 64 + c3
        result[#result+1] = string.char(math.floor(n/65536) % 256)
        if data:sub(i+2,i+2) ~= "=" then
            result[#result+1] = string.char(math.floor(n/256) % 256)
        end
        if data:sub(i+3,i+3) ~= "=" then
            result[#result+1] = string.char(n % 256)
        end
    end
    return table.concat(result)
end

-- ---------------------------------------------------------------
-- Table serialiser / deserialiser  (handles string, number, bool, table)
-- ---------------------------------------------------------------
local function Serialise(val, depth)
    depth = depth or 0
    local t = type(val)
    if t == "boolean" then return val and "true" or "false"
    elseif t == "number" then
        -- Preserve decimals
        if val ~= math.floor(val) then return string.format("%.6g", val)
        else return tostring(math.floor(val)) end
    elseif t == "string" then
        -- Escape backslash, double-quote, newline
        return '"' .. val:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n') .. '"'
    elseif t == "table" then
        if depth > 20 then return '{}' end  -- safety cap
        local parts = {}
        -- Detect array-like tables for compact output
        local n = 0; for _ in pairs(val) do n = n + 1 end
        local isArr = (n > 0 and val[1] ~= nil and #val == n)
        if isArr then
            for _, v in ipairs(val) do
                parts[#parts+1] = Serialise(v, depth+1)
            end
            return "{" .. table.concat(parts, ",") .. "}"
        else
            for k, v in pairs(val) do
                local ks
                if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                    ks = k
                else
                    ks = "[" .. Serialise(k, depth+1) .. "]"
                end
                parts[#parts+1] = ks .. "=" .. Serialise(v, depth+1)
            end
            table.sort(parts)  -- deterministic output
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "nil"
end

local function Deserialise(str)
    -- Wrap in a function and load it as Lua, sandboxed
    local fn, err = loadstring("return " .. str)
    if not fn then return nil, "Parse error: " .. (err or "unknown") end
    -- Sandbox: only allow safe globals (no print/pairs/etc access needed)
    setfenv(fn, {})
    local ok, result = pcall(fn)
    if not ok then return nil, "Eval error: " .. tostring(result) end
    return result, nil
end

-- ---------------------------------------------------------------
-- Deep-copy helper
-- ---------------------------------------------------------------
local function DeepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[DeepCopy(k)] = DeepCopy(v)
    end
    return copy
end

-- ---------------------------------------------------------------
-- DB helpers
-- ---------------------------------------------------------------
local function DB() return ConsumableTrackerDB end

local function EnsureProfiles()
    local d = DB()
    if not d then return end
    if not d.Profiles then d.Profiles = {} end
    if not d.ActiveProfile then d.ActiveProfile = "Default" end
end

-- Position keys that must NEVER be saved into profiles.
local POS_KEYS = {"AnchorPoint","AnchorToPoint","AnchorToFrame","X","Y"}

local function StripPositions(tbl)
    if type(tbl) ~= "table" then return tbl end
    local out = {}
    for k,v in pairs(tbl) do
        local skip = false
        for _,pk in ipairs(POS_KEYS) do if k==pk then skip=true; break end end
        if not skip then
            out[k] = type(v)=="table" and StripPositions(v) or v
        end
    end
    return out
end

-- Read actual on-screen positions of every window frame and the buff window.
-- Falls back to current DB values if frames aren't visible yet.
local function CapturePositions()
    local pos = {wins={}}
    local d = DB()
    if d and d.Windows then
        for i=1,#d.Windows do
            local f = _G["FabsWin_"..i]
            local pt,rpt,fx,fy
            if f and f:IsVisible() then
                pt,_,rpt,fx,fy = f:GetPoint(1)
            end
            local w = d.Windows[i]
            pos.wins[i] = {
                AnchorPoint   = pt   or (w and w.AnchorPoint)   or "CENTER",
                AnchorToPoint = rpt  or (w and w.AnchorToPoint) or "CENTER",
                AnchorToFrame = "UIParent",
                X = fx and math.floor(fx+0.5) or (w and w.X) or 0,
                Y = fy and math.floor(fy+0.5) or (w and w.Y) or 0,
            }
        end
    end
    local bf = _G["FabsBuffWindow"]
    local bpt,brpt,bx,by
    if bf and bf:IsVisible() then
        bpt,_,brpt,bx,by = bf:GetPoint(1)
    end
    local bw = d and d.BuffWindow
    pos.buff = {
        AnchorPoint   = bpt  or (bw and bw.AnchorPoint)   or "CENTER",
        AnchorToPoint = brpt or (bw and bw.AnchorToPoint) or "CENTER",
        AnchorToFrame = "UIParent",
        X = bx and math.floor(bx+0.5) or (bw and bw.X) or 0,
        Y = by and math.floor(by+0.5) or (bw and bw.Y) or 0,
    }
    return pos
end

local function ApplyPositions(pos)
    if not pos then return end
    local d = DB()
    if not d then return end
    -- Buff window
    if pos.buff then
        d.BuffWindow = d.BuffWindow or {}
        for _,k in ipairs(POS_KEYS) do d.BuffWindow[k] = pos.buff[k] end
    end
    -- Main windows — only apply to windows that exist in the new profile
    if pos.wins and d.Windows then
        for i,wp in pairs(pos.wins) do
            if d.Windows[i] then
                for _,k in ipairs(POS_KEYS) do d.Windows[i][k] = wp[k] end
            end
        end
    end
end

-- Extract only profile-relevant keys, with all positions stripped out
local function SnapshotLiveDB()
    local snap = {}
    local d = DB()
    for _,k in ipairs(PROFILE_KEYS) do
        if d[k] ~= nil then
            snap[k] = StripPositions(DeepCopy(d[k]))
        end
    end
    return snap
end

-- Apply a snapshot: positions are NEVER part of the profile and always survive
local function ApplySnapshot(snap)
    local d = DB()
    -- 1. Save current on-screen positions BEFORE changing anything
    local savedPos = CapturePositions()
    -- 2. Replace profile data
    for _,k in ipairs(PROFILE_KEYS) do d[k] = nil end
    for _,k in ipairs(PROFILE_KEYS) do
        if snap[k] ~= nil then d[k] = DeepCopy(snap[k]) end
    end
    -- 3. Write saved positions back — profile data never wins over live positions
    ApplyPositions(savedPos)
    -- 4. Refresh
    if CT.RefreshLayout then CT:RefreshLayout() end
    if CT.RefreshBuffWindow then CT.RefreshBuffWindow() end
    C_Timer.After(0.05, function()
        if CT._RebuildGUI then CT._RebuildGUI() end
    end)
end

-- ---------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------

--- Return list of saved profile names (always includes "Default")
function CT:GetProfiles()
    EnsureProfiles()
    local d = DB()
    local names = {}
    local seen = {}
    -- Default is always first
    names[1] = "Default"; seen["Default"] = true
    for name in pairs(d.Profiles) do
        if not seen[name] then
            names[#names+1] = name
            seen[name] = true
        end
    end
    table.sort(names, function(a,b)
        if a == "Default" then return true end
        if b == "Default" then return false end
        return a < b
    end)
    return names
end

--- Return the currently active profile name
function CT:GetActiveProfile()
    EnsureProfiles()
    return DB().ActiveProfile or "Default"
end

--- Save current settings as a new profile and switch to it.
--- If the profile already exists its contents are overwritten.
function CT:CreateProfile(name)
    if not name or name == "" then return false, "Profile name cannot be empty" end
    EnsureProfiles()
    local d = DB()
    local current = d.ActiveProfile or "Default"
    -- Save current state into both the outgoing profile and the new one
    local snap = SnapshotLiveDB()
    d.Profiles[current] = snap
    d.Profiles[name]    = DeepCopy(snap)
    d.ActiveProfile     = name
    -- No ApplySnapshot needed — settings are already live
    return true, nil
end

--- Switch to an existing profile (or create a copy of the current one if new).
function CT:SwitchProfile(name)
    if not name or name == "" then return false, "Profile name cannot be empty" end
    EnsureProfiles()
    local d = DB()
    -- Save current settings into the outgoing profile
    local current = d.ActiveProfile or "Default"
    d.Profiles[current] = SnapshotLiveDB()
    -- Switch
    d.ActiveProfile = name
    if not d.Profiles[name] then
        -- Brand-new name: start as a copy of current settings
        d.Profiles[name] = DeepCopy(d.Profiles[current])
    end
    ApplySnapshot(d.Profiles[name])
    return true, nil
end

--- Copy the active profile into a new profile name.
function CT:CopyProfile(name)
    if not name or name == "" then return false, "Profile name cannot be empty" end
    EnsureProfiles()
    local d = DB()
    d.Profiles[name] = SnapshotLiveDB()
    return true, nil
end

--- Delete a saved profile. Cannot delete the active profile.
function CT:DeleteProfile(name)
    if not name or name == "" then return false, "Profile name cannot be empty" end
    EnsureProfiles()
    local d = DB()
    if (d.ActiveProfile or "Default") == name then
        return false, "Cannot delete the active profile. Switch to another profile first."
    end
    d.Profiles[name] = nil
    return true, nil
end

--- Reset the active profile back to default settings.
--- Clears all windows/slots and resets to a single empty window.
function CT:ResetProfile()
    EnsureProfiles()
    local d = DB()
    local savedPos = CapturePositions()
    d.Windows=nil; d.BuffWindow=nil; d.SectionOrder=nil
    d.EquipBlacklist=nil; d.GUIFontSize=nil; d.ShowTooltips=nil
    ApplyPositions(savedPos)
    local name = d.ActiveProfile or "Default"
    d.Profiles[name] = SnapshotLiveDB()
    if CT.RefreshLayout then CT:RefreshLayout() end
    if CT.RefreshBuffWindow then CT.RefreshBuffWindow() end
    C_Timer.After(0.05, function() if CT._RebuildGUI then CT._RebuildGUI() end end)
end

--- Export the active profile as a shareable string.
--- Format: !FRT_<base64(serialised table)>
function CT:ExportProfile()
    local snap = SnapshotLiveDB()
    local payload = { profile = snap }
    local serialised = Serialise(payload)
    local encoded   = Base64Encode(serialised)
    return PREFIX .. encoded
end

--- Import a profile string and load it into the specified profile name.
--- Returns: success (bool), err (string or nil)
function CT:ImportProfile(importStr, name)
    if type(importStr) ~= "string" then
        return false, "Import string must be a string"
    end
    if importStr:sub(1, #PREFIX) ~= PREFIX then
        return false, "Invalid import string (missing !FRT_ prefix)"
    end
    local encoded = importStr:sub(#PREFIX + 1)
    if encoded == "" then
        return false, "Import string is empty"
    end
    local serialised = Base64Decode(encoded)
    if not serialised or serialised == "" then
        return false, "Failed to decode import string"
    end
    local payload, parseErr = Deserialise(serialised)
    if not payload then
        return false, "Failed to parse import string: " .. (parseErr or "unknown error")
    end
    if type(payload) ~= "table" or type(payload.profile) ~= "table" then
        return false, "Import string has unexpected format"
    end
    -- Validate name
    if not name or name == "" then
        return false, "Target profile name cannot be empty"
    end
    EnsureProfiles()
    local d = DB()
    -- Store into the target profile slot
    d.Profiles[name] = DeepCopy(payload.profile)
    -- If importing into the active profile, apply immediately
    if (d.ActiveProfile or "Default") == name then
        ApplySnapshot(d.Profiles[name])
    end
    return true, nil
end
