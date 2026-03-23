-- Core_Plugin.lua - Only loads if ElvUI is present
local isElvUILoaded = (C_AddOns and C_AddOns.IsAddOnLoaded("ElvUI")) or select(2, IsAddOnLoaded("ElvUI"))
if not isElvUILoaded then return end

-- ======================================
-- ELVUI PLUGIN MODE
-- ======================================
local E, L, V, P, G = unpack(ElvUI)
local MyMod = E:NewModule('ElvUI_Castbar_Anchors', 'AceEvent-3.0', 'AceHook-3.0')
local EP = LibStub("LibElvUIPlugin-1.0")
local LibDBIcon = LibStub("LibDBIcon-1.0")

MyMod.version = "2.24.0"

local CASTBAR_FRAMES = {
    player = "ElvUF_Player_CastBar",
    target = "ElvUF_Target_CastBar",
    focus = "ElvUF_Focus_CastBar",
}

-- Default Settings (stored in ElvUI's profile database)
P['ElvUI_Castbar_Anchors'] = {
    ['castbars'] = {
        ['player'] = { 
            ['enabled'] = false, ['anchorFrame'] = nil, ['anchorPoint'] = "CENTER", ['relativePoint'] = "CENTER", ['offsetX'] = 0, ['offsetY'] = 0, 
            ['updateRate'] = 0.05, ['combatUpdateRate'] = 5, ['usePetFrame'] = false, ['petAnchorFrame'] = nil, 
            ['normalFrameWidth'] = nil, ['normalFrameHeight'] = nil, ['adjustForIcon'] = false, ['normalFrameIconSize'] = 0, ['iconBorderAdjust'] = 0, 
            ['essentialCDIconSize'] = 0, ['essentialCDAdjustForIcon'] = false,
            -- Text positioning (disabled by default)
            ['customizeText'] = false,
            ['textXOffset'] = 0, ['textYOffset'] = 0, ['textAnchor'] = "LEFT",
            ['timeXOffset'] = 0, ['timeYOffset'] = 0, ['timeAnchor'] = "RIGHT",
            -- Appearance (disabled by default)
            ['customizeAppearance'] = false,
            ['font'] = "PT Sans Narrow", ['fontSize'] = 12, ['fontOutline'] = "OUTLINE",
            ['texture'] = "ElvUI Norm"
        },
        ['target'] = { 
            ['enabled'] = false, ['anchorFrame'] = nil, ['anchorPoint'] = "CENTER", ['relativePoint'] = "CENTER", ['offsetX'] = 0, ['offsetY'] = 0, 
            ['updateRate'] = 0.05, ['combatUpdateRate'] = 5, 
            ['normalFrameWidth'] = nil, ['normalFrameHeight'] = nil, ['adjustForIcon'] = false, ['normalFrameIconSize'] = 0, ['iconBorderAdjust'] = 0, 
            ['essentialCDIconSize'] = 0, ['essentialCDAdjustForIcon'] = false,
            -- Text positioning (disabled by default)
            ['customizeText'] = false,
            ['textXOffset'] = 0, ['textYOffset'] = 0, ['textAnchor'] = "LEFT",
            ['timeXOffset'] = 0, ['timeYOffset'] = 0, ['timeAnchor'] = "RIGHT",
            -- Appearance (disabled by default)
            ['customizeAppearance'] = false,
            ['font'] = "PT Sans Narrow", ['fontSize'] = 12, ['fontOutline'] = "OUTLINE",
            ['texture'] = "ElvUI Norm"
        },
        ['focus'] = { 
            ['enabled'] = false, ['anchorFrame'] = nil, ['anchorPoint'] = "CENTER", ['relativePoint'] = "CENTER", ['offsetX'] = 0, ['offsetY'] = 0, 
            ['updateRate'] = 0.05, ['combatUpdateRate'] = 5, 
            ['normalFrameWidth'] = nil, ['normalFrameHeight'] = nil, ['adjustForIcon'] = false, ['normalFrameIconSize'] = 0, ['iconBorderAdjust'] = 0, 
            ['essentialCDIconSize'] = 0, ['essentialCDAdjustForIcon'] = false,
            -- Text positioning (disabled by default)
            ['customizeText'] = false,
            ['textXOffset'] = 0, ['textYOffset'] = 0, ['textAnchor'] = "LEFT",
            ['timeXOffset'] = 0, ['timeYOffset'] = 0, ['timeAnchor'] = "RIGHT",
            -- Appearance (disabled by default)
            ['customizeAppearance'] = false,
            ['font'] = "PT Sans Narrow", ['fontSize'] = 12, ['fontOutline'] = "OUTLINE",
            ['texture'] = "ElvUI Norm"
        },
    },
}

-- Global Settings (shared across all profiles)
G['ElvUI_Castbar_Anchors'] = {
    ['minimap'] = { ['hide'] = false, ['minimapPos'] = 220 },
}

MyMod.updateTickers = {}
MyMod.hooked = {}

-- Apply text/font/texture customizations (separate from positioning)
function MyMod:ApplyCustomizations(castbarType)
    local db = E.db.ElvUI_Castbar_Anchors.castbars[castbarType]
    if not db or not db.enabled then return end
    
    local castbar = self:GetCastbar(castbarType)
    if not castbar then return end
    
    pcall(function()
        -- ENFORCE WIDTH/HEIGHT for EssentialCD (ElvUI keeps resetting them!)
        if db.anchorFrame == "EssentialCooldownViewer" or 
           (castbarType == "player" and db.usePetFrame and db.petAnchorFrame == "EssentialCooldownViewer") then
            
            if db.matchWidth then
                local essentialFrame = _G["EssentialCooldownViewer"]
                if essentialFrame then
                    local anchorWidth = essentialFrame:GetWidth()
                    if anchorWidth and anchorWidth > 0 then
                        -- Calculate correct width
                        local borderAdjust = (db.borderAdjust or 0) * 2
                        local finalWidth = anchorWidth - borderAdjust
                        
                        -- Subtract icon width if enabled
                        if db.essentialCDAdjustForIcon and castbar.Icon and castbar.Icon:IsShown() then
                            local iconWidth = 0
                            local iconType = castbar.Icon:GetObjectType()
                            
                            if iconType == "Texture" then
                                local parent = castbar.Icon:GetParent()
                                if parent and parent.GetWidth then
                                    iconWidth = parent:GetWidth() or 0
                                end
                            else
                                iconWidth = castbar.Icon:GetWidth() or 0
                            end
                            
                            if iconWidth > 0 then
                                finalWidth = finalWidth - iconWidth
                            end
                        end
                        
                        -- ENFORCE the width (fight ElvUI!)
                        if castbar:GetWidth() ~= finalWidth then
                            castbar:SetWidth(finalWidth)
                        end
                    end
                end
            end
            
            -- ENFORCE the height too
            local height = db.essentialCDHeight or 18
            if castbar:GetHeight() ~= height then
                castbar:SetHeight(height)
            end
        end
        
        -- Only apply if customization is enabled
        if db.customizeText then
            -- Update Cast Name Text Position
            if castbar.Text then
                local textAnchor = db.textAnchor or "LEFT"
                local textX = db.textXOffset or 0
                local textY = db.textYOffset or 0
                
                castbar.Text:ClearAllPoints()
                castbar.Text:SetPoint(textAnchor, castbar, textAnchor, textX, textY)
                castbar.Text:SetJustifyH("LEFT")
            end
            
            -- Update Cast Time Text Position
            if castbar.Time then
                local timeAnchor = db.timeAnchor or "RIGHT"
                local timeX = db.timeXOffset or 0
                local timeY = db.timeYOffset or 0
                
                castbar.Time:ClearAllPoints()
                castbar.Time:SetPoint(timeAnchor, castbar, timeAnchor, timeX, timeY)
                castbar.Time:SetJustifyH("RIGHT")
            end
        end
        
        -- Only apply if appearance customization is enabled
        if db.customizeAppearance then
            -- Update Font for Text and Time
            if db.font and db.fontSize then
                local fontPath = E.LSM:Fetch("font", db.font)
                local fontSize = db.fontSize or 12
                local fontOutline = db.fontOutline or "OUTLINE"
                
                if fontPath then
                    if castbar.Text and castbar.Text.SetFont then
                        castbar.Text:SetFont(fontPath, fontSize, fontOutline)
                    end
                    if castbar.Time and castbar.Time.SetFont then
                        castbar.Time:SetFont(fontPath, fontSize, fontOutline)
                    end
                end
            end
            
            -- Update Castbar Texture
            if db.texture then
                local texture = E.LSM:Fetch("statusbar", db.texture)
                if texture and castbar.SetStatusBarTexture then
                    castbar:SetStatusBarTexture(texture)
                end
            end
        end
    end)
end


function MyMod:GetCastbar(castbarType)
    return _G[CASTBAR_FRAMES[castbarType]]
end

function MyMod:UpdateCastbarPosition(castbarType)
    local db = E.db.ElvUI_Castbar_Anchors.castbars[castbarType]
    if not db or not db.anchorFrame then 
        return 
    end
    
    
    -- Wrap everything in pcall to catch forbidden errors (including combat taint)
    local success, err = pcall(function()
        local targetAnchorFrameName = db.anchorFrame
        
        -- Handle pet override (allow EssentialCD pet override even if main anchor is EssentialCD)
        if castbarType == "player" and db.usePetFrame and db.petAnchorFrame then
            if UnitExists("pet") then
                local petFrame = _G[db.petAnchorFrame]
                if petFrame and petFrame:IsShown() then
                    targetAnchorFrameName = db.petAnchorFrame
                else
                end
            else
            end
        end
        
        
        local anchorFrame = _G[targetAnchorFrameName]
        if not anchorFrame then 
            return 
        end
        
        -- Safe check if frame is shown
        local isShown = false
        pcall(function() isShown = anchorFrame:IsShown() end)
        if not isShown then 
            return 
        end
        
        local castbar = self:GetCastbar(castbarType)
        if not castbar then 
            return 
        end
        
        -- Set flag to prevent our SetPoint hook from triggering
        castbar.__CA_SettingPoint = true
        
        -- FORCE re-anchor by clearing ALL points first
        castbar:ClearAllPoints()
        
        -- Determine the ACTUAL frame we're anchoring to
        local actualAnchorFrameName = targetAnchorFrameName
        
        -- Check if ACTUAL anchor (including pet override) is EssentialCooldownViewer
        if targetAnchorFrameName == "EssentialCooldownViewer" and db.matchWidth then
            -- EssentialCooldownViewer mode with width matching enabled
            -- IMPORTANT: Use actual EssentialCooldownViewer frame, not pet override
            local essentialFrame = _G["EssentialCooldownViewer"]
            if not essentialFrame then
                return -- EssentialCooldownViewer not found
            end
            
            local anchorWidth = essentialFrame:GetWidth()
            if anchorWidth and anchorWidth > 0 then
                -- Set height for EssentialCooldownViewer FIRST
                local height = db.essentialCDHeight or 18
                castbar:SetHeight(height)
                
                -- IMPORTANT: Size the icon FIRST (before calculating width adjustment)
                if castbar.Icon then
                    local iconSize = db.essentialCDIconSize
                    if not iconSize or iconSize == 0 then
                        iconSize = height  -- Default to match castbar height
                    end
                    
                    if iconSize > 0 then
                        local iconType = castbar.Icon:GetObjectType()
                        local parent = castbar.Icon:GetParent()
                        
                        if iconType == "Texture" and parent and parent.SetSize then
                            -- Resize the PARENT frame (this is what actually matters!)
                            parent:SetSize(iconSize, iconSize)
                        elseif iconType ~= "Texture" then
                            castbar.Icon:SetSize(iconSize, iconSize)
                        end
                    end
                end
                
                -- NOW calculate width (after icon is properly sized)
                -- Apply border adjustment to width
                local borderAdjust = (db.borderAdjust or 0) * 2
                local finalWidth = anchorWidth - borderAdjust
                
                -- Adjust width for icon if enabled (icon is now properly sized!)
                if db.essentialCDAdjustForIcon and castbar.Icon and castbar.Icon:IsShown() then
                    local iconWidth = 0
                    local iconType = castbar.Icon:GetObjectType()
                    
                    if iconType == "Texture" then
                        -- For textures, get parent frame width
                        local parent = castbar.Icon:GetParent()
                        if parent and parent.GetWidth then
                            iconWidth = parent:GetWidth() or 0
                        end
                    else
                        -- For frames, get width directly
                        iconWidth = castbar.Icon:GetWidth() or 0
                    end
                    
                    if iconWidth > 0 then
                        finalWidth = finalWidth - iconWidth
                    end
                end
                
                castbar:SetWidth(finalWidth)
                
                -- Use EssentialCooldownViewer-specific offsets with border centering
                local finalOffsetX = (db.essentialCDOffsetX or 0) + (db.borderAdjust or 0)
                local finalOffsetY = db.essentialCDOffsetY or 0
                
                castbar:SetPoint(db.anchorPoint or "CENTER", essentialFrame, db.relativePoint or "CENTER", finalOffsetX, finalOffsetY)
            else
                -- Fallback - use EssentialCD offsets without width matching
                local finalOffsetX = db.essentialCDOffsetX or 0
                local finalOffsetY = db.essentialCDOffsetY or 0
                local height = db.essentialCDHeight or 18
                castbar:SetHeight(height)
                
                -- Fix icon size
                if castbar.Icon then
                    local iconSize = db.essentialCDIconSize
                    if not iconSize or iconSize == 0 then
                        iconSize = height
                    end
                    
                    if iconSize > 0 then
                        local iconType = castbar.Icon:GetObjectType()
                        local parent = castbar.Icon:GetParent()
                        
                        if iconType == "Texture" and parent and parent.SetSize then
                            parent:SetSize(iconSize, iconSize)
                        elseif iconType ~= "Texture" then
                            castbar.Icon:SetSize(iconSize, iconSize)
                        end
                    end
                end
                
                castbar:SetPoint(db.anchorPoint or "CENTER", essentialFrame, db.relativePoint or "CENTER", finalOffsetX, finalOffsetY)
            end
            
            -- Update previous anchor tracker
            db.previousAnchor = "EssentialCooldownViewer"
        elseif targetAnchorFrameName == "EssentialCooldownViewer" then
            -- EssentialCooldownViewer but Match Width disabled - use EssentialCD offsets
            -- Use actual EssentialCooldownViewer frame
            local essentialFrame = _G["EssentialCooldownViewer"]
            if not essentialFrame then
                return -- EssentialCooldownViewer not found
            end
            
            local finalOffsetX = db.essentialCDOffsetX or 0
            local finalOffsetY = db.essentialCDOffsetY or 0
            local height = db.essentialCDHeight or 18
            castbar:SetHeight(height)
            
            -- Force icon size on EVERY update
            if castbar.Icon then
                local iconSize = db.essentialCDIconSize
                if not iconSize or iconSize == 0 then
                    iconSize = height  -- Default to match castbar height
                end
                
                if iconSize > 0 then
                    local iconType = castbar.Icon:GetObjectType()
                    local parent = castbar.Icon:GetParent()
                    
                    if iconType == "Texture" and parent and parent.SetSize then
                        parent:SetSize(iconSize, iconSize)
                    elseif iconType ~= "Texture" then
                        castbar.Icon:SetSize(iconSize, iconSize)
                    end
                end
            end
            
            castbar:SetPoint(db.anchorPoint or "CENTER", essentialFrame, db.relativePoint or "CENTER", finalOffsetX, finalOffsetY)
            
            -- Update previous anchor tracker
            db.previousAnchor = "EssentialCooldownViewer"
        else
            -- NORMAL MODE: Set position
            local finalOffsetX = db.offsetX or 0
            local finalOffsetY = db.offsetY or 0
            
            castbar:SetPoint(db.anchorPoint or "CENTER", anchorFrame, db.relativePoint or "CENTER", finalOffsetX, finalOffsetY)
            
            -- Only apply custom width/height for unitframe anchors (HealthBar/PowerBar)
            if actualAnchorFrameName and (actualAnchorFrameName:match("HealthBar") or actualAnchorFrameName:match("PowerBar")) then
                -- Use the addon's normalFrameWidth/Height settings (configured by user for player castbar)
                -- These apply to BOTH player frame AND pet frame when using pet override!
                local customWidth = db.normalFrameWidth or 270
                local customHeight = db.normalFrameHeight or 18
                
                -- If not set yet, read from PLAYER ElvUI settings (not pet, since pet castbar may be disabled)
                if not db.normalFrameWidth or not db.normalFrameHeight then
                    local unitKey = castbarType  -- Always read from castbarType (player/target/focus), never pet
                    if E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units[unitKey] and E.db.unitframe.units[unitKey].castbar then
                        if not db.normalFrameWidth then
                            db.normalFrameWidth = E.db.unitframe.units[unitKey].castbar.width or 270
                        end
                        if not db.normalFrameHeight then
                            db.normalFrameHeight = E.db.unitframe.units[unitKey].castbar.height or 18
                        end
                        customWidth = db.normalFrameWidth
                        customHeight = db.normalFrameHeight
                    end
                end
                
                -- IMPORTANT: Force icon size FIRST (before adjustForIcon calculation)
                -- This ensures icon is correct size when coming from EssentialCD mode
                if castbar.Icon and db.normalFrameIconSize and db.normalFrameIconSize > 0 then
                    local iconSize = db.normalFrameIconSize - (db.iconBorderAdjust or 0)
                    if iconSize < 1 then iconSize = 1 end
                    
                    local iconType = castbar.Icon:GetObjectType()
                    local parent = castbar.Icon:GetParent()
                    
                    if iconType == "Texture" and parent and parent.SetSize then
                        parent:SetSize(iconSize, iconSize)
                    elseif iconType ~= "Texture" then
                        castbar.Icon:SetSize(iconSize, iconSize)
                    end
                end
                
                -- Adjust width for icon if enabled (AFTER forcing correct icon size)
                -- Wrapped in pcall to avoid taint errors with icon width during combat
                if db.adjustForIcon and castbar.Icon and castbar.Icon:IsShown() then
                    pcall(function()
                        local iconWidth = 0
                        local iconType = castbar.Icon:GetObjectType()
                        
                        if iconType == "Texture" then
                            -- For textures, get parent frame width
                            local parent = castbar.Icon:GetParent()
                            if parent and parent.GetWidth then
                                iconWidth = parent:GetWidth() or 0
                            end
                        else
                            -- For frames, get width directly
                            iconWidth = castbar.Icon:GetWidth() or 0
                        end
                        
                        if iconWidth > 0 then
                            customWidth = customWidth - iconWidth
                        end
                    end)
                end
                
                castbar:SetWidth(customWidth)
                castbar:SetHeight(customHeight)
                
                -- Force icon size on EVERY update (ElvUI resets it constantly)
                if castbar.Icon and db.normalFrameIconSize and db.normalFrameIconSize > 0 then
                    local iconSize = db.normalFrameIconSize - (db.iconBorderAdjust or 0)
                    if iconSize < 1 then iconSize = 1 end  -- Minimum 1px
                    
                    local iconType = castbar.Icon:GetObjectType()
                    local parent = castbar.Icon:GetParent()
                    
                    if iconType == "Texture" and parent and parent.SetSize then
                        -- Resize the PARENT frame (this is what works!)
                        parent:SetSize(iconSize, iconSize)
                    elseif iconType ~= "Texture" then
                        -- Frames use SetSize directly
                        castbar.Icon:SetSize(iconSize, iconSize)
                    end
                end
            end
            -- For non-unitframe anchors (UIParent, etc), just set position, don't touch size
            
            -- Update tracker
            if db.previousAnchor == "EssentialCooldownViewer" then
                db.previousAnchor = db.anchorFrame
            elseif db.previousAnchor ~= db.anchorFrame then
                db.previousAnchor = db.anchorFrame
            end
            -- Note: Icon size is managed by ElvUI, we don't touch it
        end
        
        
        -- Clear the flag after a brief delay
        C_Timer.After(0.01, function()
            if castbar then
                castbar.__CA_SettingPoint = nil
            end
        end)
        
        -- Apply customizations (text/font/texture) after positioning
        C_Timer.After(0.02, function()
            MyMod:ApplyCustomizations(castbarType)
        end)
        
    end)
    
    if not success then
    else
    end
    -- Silently ignore all errors (including forbidden/taint errors)
end

function MyMod:StartAnchoring(castbarType)
    local db = E.db.ElvUI_Castbar_Anchors.castbars[castbarType]
    if not db.anchorFrame then 
        return 
    end
    
    
    self:StopAnchoring(castbarType)
    
    local castbar = self:GetCastbar(castbarType)
    if not castbar then 
        return 
    end
    
    -- Hook the castbar's SetPoint to detect when ElvUI moves it (with protection)
    if not castbar.__CA_Hooked then
        local hookSuccess = pcall(function()
            self:SecureHook(castbar, "SetPoint", function(frame)
                -- If we're not in combat and this wasn't our anchor call, re-anchor
                if not InCombatLockdown() and not frame.__CA_SettingPoint then
                    C_Timer.After(0.05, function()
                        if db.enabled and not InCombatLockdown() then
                            MyMod:UpdateCastbarPosition(castbarType)
                        end
                    end)
                end
            end)
            
            self:SecureHook(castbar, "ClearAllPoints", function(frame)
                if not InCombatLockdown() and not frame.__CA_SettingPoint then
                    C_Timer.After(0.05, function()
                        if db.enabled and not InCombatLockdown() then
                            MyMod:UpdateCastbarPosition(castbarType)
                        end
                    end)
                end
            end)
            
            -- Hook castbar update functions to reapply customizations
            -- These functions are called by ElvUI when the castbar updates
            if castbar.PostCastStart then
                self:SecureHook(castbar, "PostCastStart", function()
                    C_Timer.After(0.01, function()
                        MyMod:ApplyCustomizations(castbarType)
                    end)
                end)
            end
            
            if castbar.PostChannelStart then
                self:SecureHook(castbar, "PostChannelStart", function()
                    C_Timer.After(0.01, function()
                        MyMod:ApplyCustomizations(castbarType)
                    end)
                end)
            end
            
            if castbar.PostCastUpdate then
                self:SecureHook(castbar, "PostCastUpdate", function()
                    MyMod:ApplyCustomizations(castbarType)
                end)
            end
            
            if castbar.PostChannelUpdate then
                self:SecureHook(castbar, "PostChannelUpdate", function()
                    MyMod:ApplyCustomizations(castbarType)
                end)
            end
        end)
        
        if hookSuccess then
            castbar.__CA_Hooked = true
        end
    end
    
    -- Simple ticker that just updates position periodically
    self.updateTickers[castbarType] = E:Delay(db.updateRate or 0.05, function()
        if not InCombatLockdown() then
            MyMod:UpdateCastbarPosition(castbarType)
        end
    end, true)
    
    -- Additional ticker for customizations (runs more frequently to combat ElvUI resets)
    -- Runs DURING COMBAT too - text/font/texture operations are safe!
    self.customizationTickers = self.customizationTickers or {}
    self.customizationTickers[castbarType] = C_Timer.NewTicker(0.1, function()
        MyMod:ApplyCustomizations(castbarType)
    end)
    
    -- Combat update ticker for pet override (checks pet status during combat)
    if castbarType == "player" and db.usePetFrame and db.petAnchorFrame then
        self.combatUpdateTickers = self.combatUpdateTickers or {}
        
        -- Use C_Timer.NewTicker instead of E:Delay (works during combat!)
        self.combatUpdateTickers[castbarType] = C_Timer.NewTicker(db.combatUpdateRate or 5, function()
            if InCombatLockdown() then
                -- During combat: Check if pet status changed
                local hasPet = UnitExists("pet")
                if not MyMod.lastPetState then MyMod.lastPetState = {} end
                
                -- If pet state changed, try to update immediately
                if MyMod.lastPetState[castbarType] ~= hasPet then
                    MyMod.lastPetState[castbarType] = hasPet
                    
                    -- Try to update position during combat
                    pcall(function()
                        MyMod:UpdateCastbarPosition(castbarType)
                    end)
                end
            end
        end)
    end
    
    -- Register combat end event to apply queued updates
    if not self.combatEndRegistered then
        self.combatEndRegistered = true
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            -- Combat ended - apply any pending updates
            if MyMod.pendingCombatUpdate then
                for cType, needsUpdate in pairs(MyMod.pendingCombatUpdate) do
                    if needsUpdate then
                        C_Timer.After(0.1, function()
                            MyMod:UpdateCastbarPosition(cType)
                        end)
                    end
                end
                MyMod.pendingCombatUpdate = {}
            end
        end)
    end
    
    self:UpdateCastbarPosition(castbarType)
    -- Silently anchor without chat spam
    
    -- Additional delayed updates on startup for EssentialCooldownViewer
    -- This fixes intermittent width issues when EssentialCD loads slowly
    if db.anchorFrame == "EssentialCooldownViewer" then
        C_Timer.After(0.5, function()
            if not InCombatLockdown() then
                MyMod:UpdateCastbarPosition(castbarType)
            end
        end)
        C_Timer.After(1.5, function()
            if not InCombatLockdown() then
                MyMod:UpdateCastbarPosition(castbarType)
            end
        end)
    end
    
    -- Hook into frame updates to detect changes
    self:HookFrameUpdates(castbarType)
end

function MyMod:HookFrameUpdates(castbarType)
    local db = E.db.ElvUI_Castbar_Anchors.castbars[castbarType]
    local anchorFrame = _G[db.anchorFrame]
    
    if anchorFrame and not self.hooked[castbarType] then
        self.hooked[castbarType] = true
        
        -- Wrap hooks in pcall to protect against forbidden access
        pcall(function()
            -- Hook show/hide events (with combat protection)
            if not self:IsHooked(anchorFrame, "Show") then
                self:SecureHookScript(anchorFrame, "Show", function()
                    if not InCombatLockdown() then
                        C_Timer.After(0.1, function()
                            if db.enabled and not InCombatLockdown() then
                                MyMod:UpdateCastbarPosition(castbarType)
                            end
                        end)
                    end
                end)
            end
        end)
        
        pcall(function()
            -- Hook size changes (with combat protection)
            if anchorFrame.SetSize and not self:IsHooked(anchorFrame, "SetSize") then
                self:SecureHook(anchorFrame, "SetSize", function()
                    if not InCombatLockdown() then
                        C_Timer.After(0.1, function()
                            if db.enabled and not InCombatLockdown() then
                                MyMod:UpdateCastbarPosition(castbarType)
                            end
                        end)
                    end
                end)
            end
        end)
    end
    
    -- Also hook pet frame if using pet override (with combat protection)
    if castbarType == "player" and db.usePetFrame and db.petAnchorFrame then
        local petFrame = _G[db.petAnchorFrame]
        if petFrame and not self.hooked["pet_"..castbarType] then
            self.hooked["pet_"..castbarType] = true
            
            pcall(function()
                if not self:IsHooked(petFrame, "Show") then
                    self:SecureHookScript(petFrame, "Show", function()
                        if not InCombatLockdown() then
                            C_Timer.After(0.1, function()
                                if db.enabled and db.usePetFrame and not InCombatLockdown() then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end)
                        end
                    end)
                end
            end)
        end
    end
end

function MyMod:StopAnchoring(castbarType)
    
    if self.updateTickers[castbarType] then
        E:CancelTimer(self.updateTickers[castbarType])
        self.updateTickers[castbarType] = nil
    end
    
    -- Also stop combat update ticker if it exists (C_Timer)
    if self.combatUpdateTickers and self.combatUpdateTickers[castbarType] then
        self.combatUpdateTickers[castbarType]:Cancel()
        self.combatUpdateTickers[castbarType] = nil
    end
    
    -- Stop customization ticker
    if self.customizationTickers and self.customizationTickers[castbarType] then
        self.customizationTickers[castbarType]:Cancel()
        self.customizationTickers[castbarType] = nil
    end
    
end

function MyMod:RefreshConfigUI(isProfileChange)
    -- Refresh config UI (silently)
    
    if isProfileChange then
        -- PROFILE CHANGE: Basic refresh
        local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
        if AceConfigRegistry then
            pcall(function()
                AceConfigRegistry:NotifyChange("ElvUI_Castbar_Anchors")
            end)
        end
    else
        -- ANCHOR CHANGE: Silent refresh
        if E.RefreshGUI then
            pcall(function()
                E:RefreshGUI()
            end)
        end
        
        local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
        if AceConfigRegistry then
            pcall(function()
                AceConfigRegistry:NotifyChange("ElvUI_Castbar_Anchors")
            end)
        end
        
        -- Second refresh after delay
        C_Timer.After(0.1, function()
            if E.RefreshGUI then
                pcall(function() E:RefreshGUI() end)
            end
        end)
    end
end

function MyMod:SetAnchorFrame(castbarType, frameName)
    local frame = _G[frameName]
    
    local db = E.db.ElvUI_Castbar_Anchors.castbars[castbarType]
    db.anchorFrame = frameName
    
    if db.enabled then 
        self:StartAnchoring(castbarType) 
    end
    
    -- Refresh UI (no close/reopen for anchor changes)
    self:RefreshConfigUI(false)
end

function MyMod:RefreshAllCastbars()
    -- Called when ElvUI profile changes
    -- Stop all current anchoring and restart with new profile settings
    
    if not InCombatLockdown() then
        -- Stop all anchoring first
        for castbarType, _ in pairs(CASTBAR_FRAMES) do
            self:StopAnchoring(castbarType)
        end
        
        -- Wait for ElvUI to finish its own profile change
        C_Timer.After(2.0, function()
            
            for castbarType, _ in pairs(CASTBAR_FRAMES) do
                local db = E.db.ElvUI_Castbar_Anchors.castbars[castbarType]
                
                if db.enabled and db.anchorFrame then
                    self:StartAnchoring(castbarType)
                end
            end
            
            -- Force position update after another delay
            C_Timer.After(0.5, function()
                for castbarType, _ in pairs(CASTBAR_FRAMES) do
                    local db = E.db.ElvUI_Castbar_Anchors.castbars[castbarType]
                    if db.enabled and db.anchorFrame then
                        self:UpdateCastbarPosition(castbarType)
                    end
                end
            end)
            
            -- Show message and try refresh
            C_Timer.After(0.7, function()
                self:RefreshConfigUI(true)  -- true = profile change
            end)
        end)
    end
end

function MyMod:SetupMinimapIcon()
    local LDBObject = LibStub("LibDataBroker-1.1"):NewDataObject("ElvUI_Castbar_Anchors", {
        type = "launcher",
        icon = "Interface\\Icons\\spell_nature_astralrecal",
        OnClick = function() E:ToggleOptions("ElvUI_Castbar_Anchors") end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("|cff00d4ffElvUI Castbar Anchors|r")
            tooltip:AddLine(" ")
            tooltip:AddLine("|cffffd700Click:|r Open Settings (ElvUI Plugin)")
        end,
    })
    LibDBIcon:Register("ElvUI_Castbar_Anchors", LDBObject, E.global.ElvUI_Castbar_Anchors.minimap)
end

function MyMod:ToggleMinimapIcon()
    E.global.ElvUI_Castbar_Anchors.minimap.hide = not E.global.ElvUI_Castbar_Anchors.minimap.hide
    if E.global.ElvUI_Castbar_Anchors.minimap.hide then LibDBIcon:Hide("ElvUI_Castbar_Anchors") else LibDBIcon:Show("ElvUI_Castbar_Anchors") end
end

function MyMod:SetupAddonCompartment()
    if AddonCompartmentFrame then
        AddonCompartmentFrame:RegisterAddon({
            text = "ElvUI Castbar Anchors",
            icon = "Interface\\Icons\\spell_nature_astralrecal",
            notCheckable = true,
            func = function() E:ToggleOptions("ElvUI_Castbar_Anchors") end,
            funcOnEnter = function(button)
                GameTooltip:SetOwner(button, "ANCHOR_LEFT")
                GameTooltip:AddLine("|cff00d4ffElvUI Castbar Anchors|r")
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cffffd700Click:|r Open Settings")
                GameTooltip:Show()
            end,
            funcOnLeave = function() GameTooltip:Hide() end,
        })
    end
end

function MyMod:InsertOptions()
    local anchorPoints = {
        ["TOPLEFT"] = "Top Left", ["TOP"] = "Top", ["TOPRIGHT"] = "Top Right",
        ["LEFT"] = "Left", ["CENTER"] = "Center", ["RIGHT"] = "Right",
        ["BOTTOMLEFT"] = "Bottom Left", ["BOTTOM"] = "Bottom", ["BOTTOMRIGHT"] = "Bottom Right"
    }
    
    local function CreateCastbarOptions(castbarType, order)
        local db = E.db.ElvUI_Castbar_Anchors.castbars[castbarType]
        local function getDB() return E.db.ElvUI_Castbar_Anchors.castbars[castbarType] end
        local castbarName = string.upper(castbarType:sub(1,1)) .. castbarType:sub(2)
        
        local options = {
            order = order, type = "group", name = castbarName,
            get = function(info) 
                local db = getDB() 
                return db[info[#info]] 
            end,
            set = function(info, value)
                local db = getDB()
                db[info[#info]] = value
                if db.enabled and db.anchorFrame then
                    MyMod:StopAnchoring(castbarType)
                    MyMod:StartAnchoring(castbarType)
                end
            end,
            args = {
                header = { order = 1, type = "header", name = castbarName .. " Castbar" },
                enabled = {
                    order = 2, type = "toggle", name = "Enable",
                    set = function(info, value)
                        local db = getDB()  -- Fresh reference!
                        db.enabled = value
                        if value then MyMod:StartAnchoring(castbarType) else MyMod:StopAnchoring(castbarType) end
                    end,
                },
                testCastbar = {
                    order = 3, type = "execute", name = "Show / Hide Castbar",
                    desc = "Toggle castbar visibility for testing positioning",
                    func = function()
                        local castbar = MyMod:GetCastbar(castbarType)
                        if not castbar then return end
                        
                        -- Check if we have an active test mode
                        if not MyMod.testCastbars then MyMod.testCastbars = {} end
                        
                        if MyMod.testCastbars[castbarType] then
                            -- HIDE - Turn off test mode
                            
                            -- Stop the ticker if it exists
                            if MyMod.testCastbars[castbarType].ticker then
                                MyMod.testCastbars[castbarType].ticker:Cancel()
                            end
                            
                            -- Reset castbar to normal state
                            castbar.casting = nil
                            castbar.channeling = nil
                            castbar.fadeOut = nil
                            
                            -- Hide the castbar
                            castbar:Hide()
                            
                            -- Clear test mode
                            MyMod.testCastbars[castbarType] = nil
                        else
                            -- SHOW - Turn on test mode
                            
                            -- Force update position first
                            MyMod:UpdateCastbarPosition(castbarType)
                            
                            -- Setup fake cast state (what oUF expects)
                            castbar.casting = true
                            castbar.channeling = nil
                            castbar.fadeOut = nil
                            
                            -- Set values for the cast bar
                            local duration = 100
                            castbar.max = duration
                            castbar.duration = duration
                            castbar.delay = 0
                            castbar.startTime = GetTime()
                            
                            -- Set the bar min/max
                            castbar:SetMinMaxValues(0, duration)
                            castbar:SetValue(duration / 2) -- 50% filled
                            
                            -- Set text to blank or spell name if available
                            if castbar.Text then
                                castbar.Text:SetText("")
                            end
                            
                            -- Set icon if available
                            if castbar.Icon then
                                castbar.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                                if castbar.Icon.Show then
                                    castbar.Icon:Show()
                                end
                            end
                            
                            -- Show spark if available
                            if castbar.Spark then
                                castbar.Spark:Show()
                            end
                            
                            -- Show the castbar itself
                            castbar:Show()
                            
                            -- Keep it visible with a ticker that constantly refreshes
                            local ticker = C_Timer.NewTicker(0.5, function()
                                if castbar and MyMod.testCastbars[castbarType] then
                                    -- Update position in case settings changed
                                    MyMod:UpdateCastbarPosition(castbarType)
                                    
                                    -- Keep the fake cast state active
                                    castbar.casting = true
                                    castbar:SetValue(duration / 2)
                                    
                                    -- Make sure it stays visible
                                    if not castbar:IsShown() then
                                        castbar:Show()
                                    end
                                end
                            end)
                            
                            -- Store test mode state
                            MyMod.testCastbars[castbarType] = {
                                active = true,
                                ticker = ticker
                            }
                        end
                    end,
                },
                spacer1 = { order = 4, type = "description", name = "" },
                anchorGroup = {
                    order = 5, type = "group", name = "Anchor Settings", guiInline = true,
                    disabled = function() return not db.enabled end,
                    args = {
                        suggestedFrames = {
                            order = 1, type = "select", name = "Quick Select",
                            desc = "Common ElvUI frames for this castbar",
                            values = function()
                                local suggestions = {}
                                if castbarType == "player" then
                                    suggestions["ElvUF_Player_HealthBar"] = "Player Health Bar"
                                    suggestions["ElvUF_Player_PowerBar"] = "Player Power Bar"
                                    suggestions["ElvUF_Pet_HealthBar"] = "Pet Health Bar"
                                    suggestions["ElvUF_Pet_PowerBar"] = "Pet Power Bar"
                                elseif castbarType == "target" then
                                    suggestions["ElvUF_Target_HealthBar"] = "Target Health Bar"
                                    suggestions["ElvUF_Target_PowerBar"] = "Target Power Bar"
                                elseif castbarType == "focus" then
                                    suggestions["ElvUF_Focus_HealthBar"] = "Focus Health Bar"
                                    suggestions["ElvUF_Focus_PowerBar"] = "Focus Power Bar"
                                end
                                -- Add common addons for all types
                                suggestions["EssentialCooldownViewer"] = "Essential Cooldown Viewer"
                                suggestions["UIParent"] = "Screen Center"
                                return suggestions
                            end,
                            get = function() 
                                local db = getDB()  -- Fresh reference!
                                return db.anchorFrame 
                            end,
                            set = function(info, value)
                                if value and value ~= "" then
                                    MyMod:SetAnchorFrame(castbarType, value)
                                end
                            end,
                        },
                        spacer1 = { order = 2, type = "description", name = " " },
                        anchorFrame = {
                            order = 3, type = "input", name = "Custom Frame Name", width = "full",
                            desc = "Or enter any frame name (use /fstack to find)",
                            get = function() 
                                local db = getDB()  -- Fresh reference!
                                return db.anchorFrame or "" 
                            end,
                            set = function(info, value) if value and value ~= "" then MyMod:SetAnchorFrame(castbarType, value) end end,
                        },
                        currentFrame = {
                            order = 4, type = "description",
                            name = function() 
                                local db = getDB()  -- Fresh reference!
                                return db.anchorFrame and ("|cff00ff00Current: " .. db.anchorFrame .. "|r") or "|cffff0000No anchor frame set|r" 
                            end,
                        },
                        spacer2 = { order = 5, type = "description", name = " " },
                        anchorPoint = { order = 6, type = "select", name = "Anchor Point", values = anchorPoints },
                        relativePoint = { order = 7, type = "select", name = "Relative Point", values = anchorPoints },
                        offsetX = { 
                            order = 8, type = "range", name = "X Offset", min = -500, max = 500, step = 1,
                            disabled = function()
                                -- Disable if main anchor is EssentialCD OR pet override is EssentialCD
                                if db.anchorFrame == "EssentialCooldownViewer" then return true end
                                if castbarType == "player" and db.usePetFrame and db.petAnchorFrame == "EssentialCooldownViewer" then return true end
                                return false
                            end
                        },
                        offsetY = { 
                            order = 9, type = "range", name = "Y Offset", min = -500, max = 500, step = 1,
                            disabled = function()
                                -- Disable if main anchor is EssentialCD OR pet override is EssentialCD
                                if db.anchorFrame == "EssentialCooldownViewer" then return true end
                                if castbarType == "player" and db.usePetFrame and db.petAnchorFrame == "EssentialCooldownViewer" then return true end
                                return false
                            end
                        },
                        normalFrameWidth = {
                            order = 9.1, type = "range", name = "Castbar Width (Unitframes only)",
                            desc = "Width of castbar when anchored to unitframe Health/Power bars (reads from ElvUI on first load)",
                            min = 50, max = 500, step = 1,
                            disabled = function() 
                                local db = getDB()
                                if not db.enabled then return true end
                                if not db.anchorFrame then return true end
                                
                                -- Determine which anchor is currently active
                                local activeAnchor = db.anchorFrame
                                if castbarType == "player" and db.usePetFrame then
                                    activeAnchor = db.petAnchorFrame or db.anchorFrame
                                end
                                
                                -- Disable if active anchor is EssentialCD
                                if activeAnchor == "EssentialCooldownViewer" then
                                    return true
                                end
                                
                                -- Only enable for Health/Power bars
                                return not (activeAnchor:match("HealthBar") or activeAnchor:match("PowerBar"))
                            end,
                            get = function() 
                                local db = getDB()  -- Fresh reference!
                                -- Auto-read from ElvUI if not set
                                if not db.normalFrameWidth then
                                    local unitKey = castbarType
                                    if E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units[unitKey] and E.db.unitframe.units[unitKey].castbar then
                                        db.normalFrameWidth = E.db.unitframe.units[unitKey].castbar.width or 270
                                    end
                                end
                                return db.normalFrameWidth or 270
                            end,
                            set = function(info, value)
                                local db = getDB()  -- Fresh reference!
                                db.normalFrameWidth = value
                                if db.enabled and db.anchorFrame then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end,
                        },
                        normalFrameHeight = {
                            order = 9.2, type = "range", name = "Castbar Height (Unitframes only)",
                            desc = "Height of castbar when anchored to unitframe Health/Power bars (reads from ElvUI on first load)",
                            min = 5, max = 100, step = 1,
                            disabled = function() 
                                local db = getDB()
                                if not db.enabled then return true end
                                if not db.anchorFrame then return true end
                                
                                -- Determine which anchor is currently active
                                local activeAnchor = db.anchorFrame
                                if castbarType == "player" and db.usePetFrame then
                                    activeAnchor = db.petAnchorFrame or db.anchorFrame
                                end
                                
                                -- Disable if active anchor is EssentialCD
                                if activeAnchor == "EssentialCooldownViewer" then
                                    return true
                                end
                                
                                -- Only enable for Health/Power bars
                                return not (activeAnchor:match("HealthBar") or activeAnchor:match("PowerBar"))
                            end,
                            get = function() 
                                local db = getDB()  -- Fresh reference!
                                -- Auto-read from ElvUI if not set
                                if not db.normalFrameHeight then
                                    local unitKey = castbarType
                                    if E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units[unitKey] and E.db.unitframe.units[unitKey].castbar then
                                        db.normalFrameHeight = E.db.unitframe.units[unitKey].castbar.height or 18
                                    end
                                end
                                return db.normalFrameHeight or 18
                            end,
                            set = function(info, value)
                                local db = getDB()  -- Fresh reference!
                                db.normalFrameHeight = value
                                if db.enabled and db.anchorFrame then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end,
                        },
                        adjustForIcon = {
                            order = 9.3, type = "toggle", name = "Adjust Width for Icon",
                            desc = "Automatically subtract icon width from castbar width so the total width (castbar + icon) matches your setting. Enable this if your castbar icon sticks out.",
                            disabled = function() 
                                local db = getDB()
                                if not db.enabled then return true end
                                if not db.anchorFrame then return true end
                                
                                -- Determine which anchor is currently active
                                local activeAnchor = db.anchorFrame
                                if castbarType == "player" and db.usePetFrame then
                                    activeAnchor = db.petAnchorFrame or db.anchorFrame
                                end
                                
                                -- Disable if active anchor is EssentialCD
                                if activeAnchor == "EssentialCooldownViewer" then
                                    return true
                                end
                                
                                -- Only enable for Health/Power bars
                                return not (activeAnchor:match("HealthBar") or activeAnchor:match("PowerBar"))
                            end,
                            get = function() 
                                local db = getDB()  -- Fresh reference!
                                return db.adjustForIcon 
                            end,
                            set = function(info, value)
                                local db = getDB()  -- Fresh reference!
                                db.adjustForIcon = value
                                if db.enabled and db.anchorFrame then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end,
                        },
                        normalFrameIconSize = {
                            order = 9.4, type = "range", name = "Icon Size (Unitframes only)",
                            desc = "Resize the castbar icon when anchored to unitframes. Set to 0 to use ElvUI's default size.",
                            min = 0, max = 100, step = 1,
                            disabled = function() 
                                local db = getDB()
                                if not db.enabled then return true end
                                if not db.anchorFrame then return true end
                                
                                -- Determine which anchor is currently active
                                local activeAnchor = db.anchorFrame
                                if castbarType == "player" and db.usePetFrame then
                                    activeAnchor = db.petAnchorFrame or db.anchorFrame
                                end
                                
                                -- Disable if active anchor is EssentialCD
                                if activeAnchor == "EssentialCooldownViewer" then
                                    return true
                                end
                                
                                -- Only enable for Health/Power bars
                                return not (activeAnchor:match("HealthBar") or activeAnchor:match("PowerBar"))
                            end,
                            get = function() 
                                local db = getDB()  -- Fresh reference!
                                return db.normalFrameIconSize or 0 
                            end,
                            set = function(info, value)
                                local db = getDB()  -- Fresh reference!
                                db.normalFrameIconSize = value
                                if db.enabled and db.anchorFrame then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end,
                        },
                        iconBorderAdjust = {
                            order = 9.5, type = "range", name = "Icon Border Adjustment",
                            desc = "Reduce icon size by this amount to account for castbar borders (e.g., 2px borders = set to 2)",
                            min = 0, max = 10, step = 0.5,
                            disabled = function() 
                                local db = getDB()
                                if not db.enabled then return true end
                                if not db.anchorFrame then return true end
                                
                                -- Determine which anchor is currently active
                                local activeAnchor = db.anchorFrame
                                if castbarType == "player" and db.usePetFrame then
                                    activeAnchor = db.petAnchorFrame or db.anchorFrame
                                end
                                
                                -- Disable if active anchor is EssentialCD
                                if activeAnchor == "EssentialCooldownViewer" then
                                    return true
                                end
                                
                                -- Only enable for Health/Power bars
                                return not (activeAnchor:match("HealthBar") or activeAnchor:match("PowerBar"))
                            end,
                            get = function() 
                                local db = getDB()  -- Fresh reference!
                                return db.iconBorderAdjust or 0 
                            end,
                            set = function(info, value)
                                local db = getDB()  -- Fresh reference!
                                db.iconBorderAdjust = value
                                if db.enabled and db.anchorFrame then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end,
                        },
                        spacer3 = { order = 10, type = "description", name = " " },
                        matchWidth = {
                            order = 11, type = "toggle", name = "Match Anchor Width",
                            desc = "Automatically resize castbar to match the anchor frame's width (EssentialCooldownViewer only)",
                            disabled = function() 
                                local db = getDB()
                                if not db.enabled then return true end
                                
                                -- Determine which anchor is currently active
                                local activeAnchor = db.anchorFrame
                                if castbarType == "player" and db.usePetFrame then
                                    -- Pet override is active, use pet anchor
                                    activeAnchor = db.petAnchorFrame or db.anchorFrame
                                end
                                
                                -- Enable only if active anchor is EssentialCD
                                return activeAnchor ~= "EssentialCooldownViewer"
                            end,
                            set = function(info, value)
                                local db = getDB()  -- Fresh reference!
                                db.matchWidth = value
                                if db.enabled and db.anchorFrame then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end,
                        },
                        borderAdjust = {
                            order = 12, type = "range", name = "Border Adjustment",
                            desc = "Reduce width by this amount to account for borders (2px borders = set to 2). Set to 0 for no adjustment. Automatically centers the castbar - no need to adjust X offset!",
                            min = 0, max = 50, step = 0.5,
                            disabled = function() 
                                local db = getDB()
                                if not db.enabled or not db.matchWidth then return true end
                                
                                -- Determine which anchor is currently active
                                local activeAnchor = db.anchorFrame
                                if castbarType == "player" and db.usePetFrame then
                                    activeAnchor = db.petAnchorFrame or db.anchorFrame
                                end
                                
                                -- Enable only if active anchor is EssentialCD
                                return activeAnchor ~= "EssentialCooldownViewer"
                            end,
                            set = function(info, value)
                                local db = getDB()  -- Fresh reference!
                                db.borderAdjust = value
                                if db.enabled and db.anchorFrame then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end,
                        },
                        spacer4 = { order = 13, type = "description", name = " " },
                        essentialCDOffsetX = {
                            order = 14, type = "range", name = "EssentialCD X Offset",
                            desc = "X offset specifically for EssentialCooldownViewer (separate from normal offset)",
                            min = -500, max = 500, step = 1,
                            disabled = function() 
                                local db = getDB()
                                if not db.enabled then return true end
                                
                                -- Determine which anchor is currently active
                                local activeAnchor = db.anchorFrame
                                if castbarType == "player" and db.usePetFrame then
                                    activeAnchor = db.petAnchorFrame or db.anchorFrame
                                end
                                
                                -- Enable only if active anchor is EssentialCD
                                return activeAnchor ~= "EssentialCooldownViewer"
                            end,
                            get = function() 
                                local db = getDB()  -- Fresh reference!
                                return db.essentialCDOffsetX or 0 
                            end,
                            set = function(info, value)
                                local db = getDB()  -- Fresh reference!
                                db.essentialCDOffsetX = value
                                if db.enabled and db.anchorFrame then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end,
                        },
                        essentialCDOffsetY = {
                            order = 15, type = "range", name = "EssentialCD Y Offset",
                            desc = "Y offset specifically for EssentialCooldownViewer (separate from normal offset)",
                            min = -500, max = 500, step = 1,
                            disabled = function() 
                                local db = getDB()
                                if not db.enabled then return true end
                                
                                -- Determine which anchor is currently active
                                local activeAnchor = db.anchorFrame
                                if castbarType == "player" and db.usePetFrame then
                                    activeAnchor = db.petAnchorFrame or db.anchorFrame
                                end
                                
                                -- Enable only if active anchor is EssentialCD
                                return activeAnchor ~= "EssentialCooldownViewer"
                            end,
                            get = function() 
                                local db = getDB()  -- Fresh reference!
                                return db.essentialCDOffsetY or 0 
                            end,
                            set = function(info, value)
                                local db = getDB()  -- Fresh reference!
                                db.essentialCDOffsetY = value
                                if db.enabled and db.anchorFrame then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end,
                        },
                        essentialCDHeight = {
                            order = 16, type = "range", name = "EssentialCD Height",
                            desc = "Height of castbar when anchored to EssentialCooldownViewer (separate from ElvUI settings)",
                            min = 5, max = 100, step = 1,
                            disabled = function() 
                                local db = getDB()
                                if not db.enabled then return true end
                                
                                -- Determine which anchor is currently active
                                local activeAnchor = db.anchorFrame
                                if castbarType == "player" and db.usePetFrame then
                                    activeAnchor = db.petAnchorFrame or db.anchorFrame
                                end
                                
                                -- Enable only if active anchor is EssentialCD
                                return activeAnchor ~= "EssentialCooldownViewer"
                            end,
                            get = function() 
                                local db = getDB()  -- Fresh reference!
                                return db.essentialCDHeight or 18 
                            end,
                            set = function(info, value)
                                local db = getDB()  -- Fresh reference!
                                db.essentialCDHeight = value
                                if db.enabled and db.anchorFrame then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end,
                        },
                        essentialCDAdjustForIcon = {
                            order = 16.5, type = "toggle", name = "Adjust Width for Icon (EssentialCD)",
                            desc = "Automatically subtract icon width from castbar width when using Match Anchor Width. Enable this if your icon sticks out horizontally.",
                            disabled = function() 
                                local db = getDB()
                                if not db.enabled then return true end
                                
                                -- Determine which anchor is currently active
                                local activeAnchor = db.anchorFrame
                                if castbarType == "player" and db.usePetFrame then
                                    activeAnchor = db.petAnchorFrame or db.anchorFrame
                                end
                                
                                -- Enable only if active anchor is EssentialCD
                                return activeAnchor ~= "EssentialCooldownViewer"
                            end,
                            get = function() 
                                local db = getDB()  -- Fresh reference!
                                return db.essentialCDAdjustForIcon 
                            end,
                            set = function(info, value)
                                local db = getDB()  -- Fresh reference!
                                db.essentialCDAdjustForIcon = value
                                if db.enabled and db.anchorFrame then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end,
                        },
                        essentialCDIconSize = {
                            order = 17, type = "range", name = "Icon Size (EssentialCD only)",
                            desc = "Resize the castbar icon when anchored to EssentialCooldownViewer. Set to 0 to match castbar height.",
                            min = 0, max = 100, step = 1,
                            disabled = function() 
                                local db = getDB()
                                if not db.enabled then return true end
                                
                                -- Determine which anchor is currently active
                                local activeAnchor = db.anchorFrame
                                if castbarType == "player" and db.usePetFrame then
                                    activeAnchor = db.petAnchorFrame or db.anchorFrame
                                end
                                
                                -- Enable only if active anchor is EssentialCD
                                return activeAnchor ~= "EssentialCooldownViewer"
                            end,
                            get = function() 
                                local db = getDB()  -- Fresh reference!
                                return db.essentialCDIconSize or 0 
                            end,
                            set = function(info, value)
                                local db = getDB()  -- Fresh reference!
                                db.essentialCDIconSize = value
                                if db.enabled and db.anchorFrame then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end,
                        },
                    },
                },
                spacer2 = { order = 6, type = "description", name = "" },
                updateGroup = {
                    order = 7, type = "group", name = "Update Settings", guiInline = true,
                    disabled = function() return not db.enabled end,
                    args = {
                        updateRate = {
                            order = 1, type = "range", name = "Update Rate", min = 0.01, max = 0.5, step = 0.01,
                            desc = "Lower = smoother, Higher = better performance",
                            set = function(info, value)
                                local db = getDB()  -- Fresh reference!
                                db.updateRate = value
                                if db.enabled and db.anchorFrame then
                                    MyMod:StopAnchoring(castbarType)
                                    MyMod:StartAnchoring(castbarType)
                                end
                            end,
                        },
                        combatUpdateRate = {
                            order = 2, type = "range", name = "Combat Update Rate", min = 0.5, max = 10, step = 0.5,
                            desc = "How often to check pet status during combat (seconds). Lower = more responsive, Higher = better performance. Only affects player castbar with pet override enabled.",
                            disabled = function() 
                                local db = getDB()  -- Fresh reference!
                                -- Only enable for player castbar with pet override
                                return castbarType ~= "player" or not db.usePetFrame or not db.petAnchorFrame
                            end,
                            get = function() 
                                local db = getDB()  -- Fresh reference!
                                return db.combatUpdateRate or 5 
                            end,
                            set = function(info, value)
                                local db = getDB()  -- Fresh reference!
                                db.combatUpdateRate = value
                                if db.enabled and db.anchorFrame then
                                    MyMod:StopAnchoring(castbarType)
                                    MyMod:StartAnchoring(castbarType)
                                end
                            end,
                        },
                    },
                },
                spacer3 = { order = 8, type = "description", name = "" },
                textGroup = {
                    order = 9, type = "group", name = "Text Positioning", guiInline = true,
                    disabled = function() 
                        local db = getDB()
                        return not db.enabled 
                    end,
                    args = {
                        customizeText = {
                            order = 0, type = "toggle", name = "Enable Text Positioning",
                            desc = "Enable custom text positioning (disabled by default - uses ElvUI defaults)",
                            set = function(info, value)
                                local db = getDB()
                                db.customizeText = value
                                if db.enabled then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end,
                        },
                        spacer0 = { order = 0.5, type = "description", name = " " },
                        castNameHeader = { 
                            order = 1, type = "header", name = "Cast Name Text",
                            hidden = function() 
                                local db = getDB()
                                return not db.customizeText 
                            end,
                        },
                        textAnchor = {
                            order = 2, type = "select", name = "Text Anchor Point",
                            desc = "Where the text anchors to the castbar",
                            values = anchorPoints,
                            hidden = function() 
                                local db = getDB()
                                return not db.customizeText 
                            end,
                        },
                        textXOffset = {
                            order = 3, type = "range", name = "Text X Offset",
                            min = -200, max = 200, step = 1,
                            hidden = function() 
                                local db = getDB()
                                return not db.customizeText 
                            end,
                            set = function(info, value)
                                local db = getDB()
                                db.textXOffset = value
                                if db.enabled then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end,
                        },
                        textYOffset = {
                            order = 4, type = "range", name = "Text Y Offset",
                            min = -50, max = 50, step = 1,
                            hidden = function() 
                                local db = getDB()
                                return not db.customizeText 
                            end,
                            set = function(info, value)
                                local db = getDB()
                                db.textYOffset = value
                                if db.enabled then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end,
                        },
                        spacer1 = { 
                            order = 5, type = "description", name = " ",
                            hidden = function() 
                                local db = getDB()
                                return not db.customizeText 
                            end,
                        },
                        castTimeHeader = { 
                            order = 6, type = "header", name = "Cast Time Text",
                            hidden = function() 
                                local db = getDB()
                                return not db.customizeText 
                            end,
                        },
                        timeAnchor = {
                            order = 7, type = "select", name = "Time Anchor Point",
                            desc = "Where the time text anchors to the castbar",
                            values = anchorPoints,
                            hidden = function() 
                                local db = getDB()
                                return not db.customizeText 
                            end,
                        },
                        timeXOffset = {
                            order = 8, type = "range", name = "Time X Offset",
                            min = -200, max = 200, step = 1,
                            hidden = function() 
                                local db = getDB()
                                return not db.customizeText 
                            end,
                            set = function(info, value)
                                local db = getDB()
                                db.timeXOffset = value
                                if db.enabled then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end,
                        },
                        timeYOffset = {
                            order = 9, type = "range", name = "Time Y Offset",
                            min = -50, max = 50, step = 1,
                            hidden = function() 
                                local db = getDB()
                                return not db.customizeText 
                            end,
                            set = function(info, value)
                                local db = getDB()
                                db.timeYOffset = value
                                if db.enabled then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end,
                        },
                    },
                },
                spacer4 = { order = 10, type = "description", name = "" },
                appearanceGroup = {
                    order = 11, type = "group", name = "Appearance", guiInline = true,
                    disabled = function() 
                        local db = getDB()
                        return not db.enabled 
                    end,
                    args = {
                        customizeAppearance = {
                            order = 0, type = "toggle", name = "Enable Appearance Customization",
                            desc = "Enable custom font and texture (disabled by default - uses ElvUI defaults)",
                            set = function(info, value)
                                local db = getDB()
                                db.customizeAppearance = value
                                if db.enabled then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end,
                        },
                        spacer0 = { order = 0.5, type = "description", name = " " },
                        font = {
                            order = 1, type = "select", name = "Font",
                            dialogControl = "LSM30_Font",
                            values = function()
                                return E.LSM:HashTable("font")
                            end,
                            hidden = function() 
                                local db = getDB()
                                return not db.customizeAppearance 
                            end,
                            set = function(info, value)
                                local db = getDB()
                                db.font = value
                                if db.enabled then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end,
                        },
                        fontSize = {
                            order = 2, type = "range", name = "Font Size",
                            min = 6, max = 32, step = 1,
                            hidden = function() 
                                local db = getDB()
                                return not db.customizeAppearance 
                            end,
                            set = function(info, value)
                                local db = getDB()
                                db.fontSize = value
                                if db.enabled then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end,
                        },
                        fontOutline = {
                            order = 3, type = "select", name = "Font Outline",
                            values = {
                                ["NONE"] = "None",
                                ["OUTLINE"] = "Outline",
                                ["THICKOUTLINE"] = "Thick Outline",
                                ["MONOCHROME"] = "Monochrome",
                                ["MONOCHROMEOUTLINE"] = "Monochrome Outline",
                            },
                            hidden = function() 
                                local db = getDB()
                                return not db.customizeAppearance 
                            end,
                            set = function(info, value)
                                local db = getDB()
                                db.fontOutline = value
                                if db.enabled then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end,
                        },
                        texture = {
                            order = 4, type = "select", name = "Castbar Texture",
                            dialogControl = "LSM30_Statusbar",
                            values = function()
                                return E.LSM:HashTable("statusbar")
                            end,
                            hidden = function() 
                                local db = getDB()
                                return not db.customizeAppearance 
                            end,
                            set = function(info, value)
                                local db = getDB()
                                db.texture = value
                                if db.enabled then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end,
                        },
                    },
                },
            },
        }
        
        if castbarType == "player" then
            options.args.spacer5 = { order = 12, type = "description", name = "" }
            options.args.petGroup = {
                order = 13, type = "group", name = "Pet Frame Override", guiInline = true,
                disabled = function() 
                    local db = getDB()
                    return not db.enabled 
                end,
                args = {
                    usePetFrame = { 
                        order = 1, type = "toggle", name = "Use Pet Frame when Active", 
                        desc = "Switch to pet frame when pet is active" 
                    },
                    spacer1 = { order = 2, type = "description", name = " " },
                    petQuickSelect = {
                        order = 3, type = "select", name = "Pet Frame Quick Select",
                        desc = "Common pet frames",
                        disabled = function() 
                            local db = getDB()  -- Fresh reference!
                            return not db.usePetFrame 
                        end,
                        values = {
                            ["ElvUF_Pet_HealthBar"] = "Pet Health Bar",
                            ["ElvUF_Pet_PowerBar"] = "Pet Power Bar",
                            ["EssentialCooldownViewer"] = "Essential Cooldown Viewer",
                        },
                        get = function() 
                            local db = getDB()  -- Fresh reference!
                            return db.petAnchorFrame 
                        end,
                        set = function(info, value)
                            local db = getDB()  -- Fresh reference!
                            db.petAnchorFrame = value
                            if db.enabled and db.usePetFrame then
                                MyMod:StopAnchoring(castbarType)
                                MyMod:StartAnchoring(castbarType)
                            end
                        end,
                    },
                    petAnchorFrame = { 
                        order = 4, type = "input", name = "Or Custom Pet Frame Name", 
                        width = "full", desc = "e.g., ElvUF_Pet", 
                        disabled = function() 
                            local db = getDB()  -- Fresh reference!
                            return not db.usePetFrame 
                        end,
                        set = function(info, value)
                            local db = getDB()  -- Fresh reference!
                            db.petAnchorFrame = value
                            if db.enabled and db.usePetFrame then
                                MyMod:StopAnchoring(castbarType)
                                MyMod:StartAnchoring(castbarType)
                            end
                        end,
                    },
                },
            }
        end
        
        return options
    end
    
    E.Options.args.ElvUI_Castbar_Anchors = {
        type = "group", name = "Castbar Anchors", childGroups = "tab",
        args = {
            header = { order = 1, type = "header", name = "|cff00d4ffElvUI Castbar Anchors|r - v" .. MyMod.version },
            description = { order = 2, type = "description", name = "Anchor your ElvUI castbars to any frame.\nUse |cffffd700/fstack|r to find frame names.\n|cff00ff00ElvUI Plugin Mode|r" },
            changelog = { order = 3, type = "execute", name = "Show Changelog", func = function() MyMod:ShowChangelog() end },
            spacer1 = { order = 4, type = "description", name = "" },
            minimapGroup = {
                order = 5, type = "group", name = "Minimap Icon", guiInline = true,
                args = {
                    hide = { order = 1, type = "toggle", name = "Hide Minimap Icon", get = function() return E.global.ElvUI_Castbar_Anchors.minimap.hide end, set = function() MyMod:ToggleMinimapIcon() end },
                },
            },
            spacer2 = { order = 6, type = "description", name = " " },
            player = CreateCastbarOptions("player", 10),
            target = CreateCastbarOptions("target", 20),
            focus = CreateCastbarOptions("focus", 30),
        },
    }
end

function MyMod:Initialize()
    EP:RegisterPlugin('ElvUI_Castbar_Anchors', MyMod.InsertOptions)
    self:SetupMinimapIcon()
    self:SetupAddonCompartment()
    
    -- Hook profile changes
    local profileChangeDelay = nil
    local function handleProfileChange(event)
        -- Cancel any pending refresh
        if profileChangeDelay then
            profileChangeDelay:Cancel()
        end
        
        -- Delay refresh to let ElvUI finish profile change
        profileChangeDelay = C_Timer.NewTimer(0.5, function()
            MyMod:RefreshAllCastbars()
            profileChangeDelay = nil
        end)
    end
    
    -- Try E.data callbacks (recommended ElvUI way)
    if E.data then
        pcall(function()
            E.data.RegisterCallback(self, "OnProfileChanged", function() handleProfileChange("OnProfileChanged") end)
            E.data.RegisterCallback(self, "OnProfileCopied", function() handleProfileChange("OnProfileCopied") end)
        end)
    end
    
    -- Try ElvUI event system
    pcall(function()
        E.RegisterCallback(self, 'ElvUI_ProfileChanged', function() handleProfileChange("ElvUI_ProfileChanged") end)
    end)
    
    -- Listen for various update events
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_REGEN_ENABLED") -- Exiting combat
    self:RegisterEvent("UNIT_PET") -- Pet changes
    self:RegisterEvent("PLAYER_TARGET_CHANGED") -- Target changes
    self:RegisterEvent("PLAYER_FOCUS_CHANGED") -- Focus changes
    
    -- Hook ElvUI's update functions
    if E.private.unitframe and E.private.unitframe.enable then
        local UF = E:GetModule('UnitFrames')
        if UF then
            -- Hook frame updates
            self:SecureHook(UF, 'Update_AllFrames', function()
                if not InCombatLockdown() then
                    C_Timer.After(0.5, function()
                        for castbarType, _ in pairs(CASTBAR_FRAMES) do
                            local db = E.db.ElvUI_Castbar_Anchors.castbars[castbarType]
                            if db.enabled and db.anchorFrame then
                                MyMod:UpdateCastbarPosition(castbarType)
                            end
                        end
                    end)
                end
            end)
            
            -- Hook Configure_CastBar which ElvUI calls when configuring castbars
            if UF.Configure_CastBar then
                self:SecureHook(UF, 'Configure_CastBar', function()
                    if not InCombatLockdown() then
                        C_Timer.After(0.1, function()
                            for castbarType, _ in pairs(CASTBAR_FRAMES) do
                                local db = E.db.ElvUI_Castbar_Anchors.castbars[castbarType]
                                if db.enabled and db.anchorFrame then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end
                        end)
                    end
                end)
            end
            
            -- Hook UpdateAllFrame which is called during layout changes
            if UF.UpdateAllFrames then
                self:SecureHook(UF, 'UpdateAllFrames', function()
                    if not InCombatLockdown() then
                        C_Timer.After(0.3, function()
                            for castbarType, _ in pairs(CASTBAR_FRAMES) do
                                local db = E.db.ElvUI_Castbar_Anchors.castbars[castbarType]
                                if db.enabled and db.anchorFrame then
                                    MyMod:UpdateCastbarPosition(castbarType)
                                end
                            end
                        end)
                    end
                end)
            end
            
            -- Hook individual unit frame updates
            for castbarType in pairs(CASTBAR_FRAMES) do
                local frameName = castbarType:gsub("^%l", string.upper)
                local frame = UF[frameName]
                
                if frame then
                    -- Hook the Configure function
                    if frame.Configure then
                        self:SecureHook(frame, 'Configure', function()
                            if not InCombatLockdown() then
                                C_Timer.After(0.1, function()
                                    local db = E.db.ElvUI_Castbar_Anchors.castbars[castbarType]
                                    if db.enabled and db.anchorFrame then
                                        MyMod:UpdateCastbarPosition(castbarType)
                                    end
                                end)
                            end
                        end)
                    end
                    
                    -- Hook the Update function
                    if frame.Update then
                        self:SecureHook(frame, 'Update', function()
                            if not InCombatLockdown() then
                                C_Timer.After(0.05, function()
                                    local db = E.db.ElvUI_Castbar_Anchors.castbars[castbarType]
                                    if db.enabled and db.anchorFrame then
                                        MyMod:UpdateCastbarPosition(castbarType)
                                    end
                                end)
                            end
                        end)
                    end
                end
            end
        end
    end
    
    E:Delay(2, function()
        for castbarType, _ in pairs(CASTBAR_FRAMES) do
            local db = E.db.ElvUI_Castbar_Anchors.castbars[castbarType]
            if db.enabled and db.anchorFrame then
                MyMod:StartAnchoring(castbarType)
            end
        end
    end)
    
end

function MyMod:PLAYER_ENTERING_WORLD()
    -- Restart all enabled anchors
    E:Delay(1, function()
        for castbarType, _ in pairs(CASTBAR_FRAMES) do
            local db = E.db.ElvUI_Castbar_Anchors.castbars[castbarType]
            if db.enabled and db.anchorFrame then
                MyMod:StartAnchoring(castbarType)
            end
        end
    end)
end

function MyMod:UNIT_PET(_, unit)
    if unit == "player" then
        local db = E.db.ElvUI_Castbar_Anchors.castbars.player
        if db.enabled and db.usePetFrame and not InCombatLockdown() then
            C_Timer.After(0.2, function()
                MyMod:UpdateCastbarPosition("player")
            end)
        end
    end
end

function MyMod:PLAYER_TARGET_CHANGED()
    local db = E.db.ElvUI_Castbar_Anchors.castbars.target
    if db.enabled and not InCombatLockdown() then
        C_Timer.After(0.1, function()
            MyMod:UpdateCastbarPosition("target")
        end)
    end
end

function MyMod:PLAYER_FOCUS_CHANGED()
    local db = E.db.ElvUI_Castbar_Anchors.castbars.focus
    if db.enabled and not InCombatLockdown() then
        C_Timer.After(0.1, function()
            MyMod:UpdateCastbarPosition("focus")
        end)
    end
end

function MyMod:PLAYER_REGEN_ENABLED()
    -- Update all positions after exiting combat
    for castbarType, _ in pairs(CASTBAR_FRAMES) do
        local db = E.db.ElvUI_Castbar_Anchors.castbars[castbarType]
        if db.enabled and db.anchorFrame then
            MyMod:UpdateCastbarPosition(castbarType)
        end
    end
end

E:RegisterModule(MyMod:GetName())
