-- Settings.lua (Standalone Mode Only)
local CA = ElvUI_Castbar_Anchors

-- Only load if not in ElvUI plugin mode
if not CA then return end

-- IMMEDIATE DEBUG OUTPUT
print("|cffFF0000=====================================|r")
print("|cffFF0000SETTINGS.LUA LOADED SUCCESSFULLY!|r")
print("|cffFF0000Version: 2.39.0|r")
print("|cffFF0000CA exists:|r", CA ~= nil)
print("|cffFF0000=====================================|r")

-- Anchor point options
local anchorPoints = {
    "TOPLEFT", "TOP", "TOPRIGHT",
    "LEFT", "CENTER", "RIGHT",
    "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT"
}

-- Show settings UI
function CA:ShowSettingsUI()
    if not CA_SettingsFrame then
        CA:CreateSettingsUI()
    end
    
    CA:UpdateSettingsUI()
    CA_SettingsFrame:Show()
end

-- Create settings UI
function CA:CreateSettingsUI()
    local frame = CreateFrame("Frame", "CA_SettingsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(550, 600)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    frame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    
    -- Header
    frame.header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.header:SetPoint("TOPLEFT", 3, -3)
    frame.header:SetPoint("TOPRIGHT", -3, -3)
    frame.header:SetHeight(50)
    frame.header:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground" })
    frame.header:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    
    frame.title = frame.header:CreateFontString(nil, "OVERLAY")
    frame.title:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    frame.title:SetPoint("LEFT", frame.header, "LEFT", 15, 0)
    frame.title:SetText("ElvUI Castbar Anchors")
    frame.title:SetTextColor(0, 0.84, 1)
    
    frame.version = frame.header:CreateFontString(nil, "OVERLAY")
    frame.version:SetFont("Fonts\\FRIZQT__.TTF", 10)
    frame.version:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 2, -2)
    frame.version:SetText("v" .. CA.version .. " |cffffffffStandalone Mode|r")
    frame.version:SetTextColor(0.6, 0.6, 0.6)
    
    frame.profileLabel = frame.header:CreateFontString(nil, "OVERLAY")
    frame.profileLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
    frame.profileLabel:SetPoint("RIGHT", frame.header, "RIGHT", -125, 0)
    frame.profileLabel:SetText("Profile:")
    frame.profileLabel:SetTextColor(0.8, 0.8, 0.8)
    
    frame.profileDropdown = CreateFrame("Frame", "CA_ProfileDropdown", frame.header, "UIDropDownMenuTemplate")
    frame.profileDropdown:SetPoint("LEFT", frame.profileLabel, "RIGHT", -15, -3)
    UIDropDownMenu_SetWidth(frame.profileDropdown, 100)
    
    UIDropDownMenu_Initialize(frame.profileDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Global"
        info.checked = not CA.useCharacterSettings
        info.func = function()
            CA.useCharacterSettings = false
            UIDropDownMenu_SetText(frame.profileDropdown, "Global")
            CA:UpdateSettingsUI()
        end
        UIDropDownMenu_AddButton(info)
        
        info.text = "Character"
        info.checked = CA.useCharacterSettings
        info.func = function()
            CA.useCharacterSettings = true
            UIDropDownMenu_SetText(frame.profileDropdown, "Character")
            CA:UpdateSettingsUI()
        end
        UIDropDownMenu_AddButton(info)
    end)
    
    frame.closeX = CreateFrame("Button", nil, frame.header)
    frame.closeX:SetSize(20, 20)
    frame.closeX:SetPoint("RIGHT", -10, 0)
    frame.closeX.text = frame.closeX:CreateFontString(nil, "OVERLAY")
    frame.closeX.text:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    frame.closeX.text:SetPoint("CENTER", 0, -1)
    frame.closeX.text:SetText("×")
    frame.closeX.text:SetTextColor(0.7, 0.7, 0.7)
    frame.closeX:SetScript("OnClick", function() frame:Hide() end)
    frame.closeX:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 0.3, 0.3) end)
    frame.closeX:SetScript("OnLeave", function(self) self.text:SetTextColor(0.7, 0.7, 0.7) end)
    
    -- Tab bar
    frame.tabBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.tabBar:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT", 0, 0)
    frame.tabBar:SetPoint("TOPRIGHT", frame.header, "BOTTOMRIGHT", 0, 0)
    frame.tabBar:SetHeight(35)
    frame.tabBar:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground" })
    frame.tabBar:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    
    frame.tabs = {}
    local tabInfo = {
        {name = "Player", key = "player"},
        {name = "Target", key = "target"},
        {name = "Focus", key = "focus"},
    }
    
    for i, info in ipairs(tabInfo) do
        local tab = CreateFrame("Button", "CA_Tab"..i, frame.tabBar)
        tab:SetSize(100, 30)
        tab.key = info.key
        
        if i == 1 then
            tab:SetPoint("LEFT", frame.tabBar, "LEFT", 8, 0)
        else
            tab:SetPoint("LEFT", frame.tabs[i-1], "RIGHT", 8, 0)
        end
        
        tab.bg = tab:CreateTexture(nil, "BACKGROUND")
        tab.bg:SetAllPoints()
        tab.bg:SetColorTexture(0.12, 0.12, 0.12, 0.8)
        
        tab.highlight = tab:CreateTexture(nil, "HIGHLIGHT")
        tab.highlight:SetAllPoints()
        tab.highlight:SetColorTexture(0.2, 0.2, 0.2, 0.5)
        
        tab.topBorder = tab:CreateTexture(nil, "OVERLAY")
        tab.topBorder:SetHeight(2)
        tab.topBorder:SetPoint("TOPLEFT")
        tab.topBorder:SetPoint("TOPRIGHT")
        tab.topBorder:SetColorTexture(0, 0.84, 1, 1)
        tab.topBorder:Hide()
        
        tab.text = tab:CreateFontString(nil, "OVERLAY")
        tab.text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        tab.text:SetPoint("CENTER")
        tab.text:SetText(info.name)
        tab.text:SetTextColor(0.7, 0.7, 0.7)
        
        tab:SetScript("OnClick", function(self) CA:SelectTab(self.key) end)
        tab:SetScript("OnEnter", function(self) if CA.selectedCastbar ~= self.key then self.text:SetTextColor(0.9, 0.9, 0.9) end end)
        tab:SetScript("OnLeave", function(self) if CA.selectedCastbar ~= self.key then self.text:SetTextColor(0.7, 0.7, 0.7) end end)
        
        frame.tabs[i] = tab
    end
    
    -- Content area with scroll
    frame.contentFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.contentFrame:SetPoint("TOPLEFT", frame.tabBar, "BOTTOMLEFT", 8, -8)
    frame.contentFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 55)
    frame.contentFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    frame.contentFrame:SetBackdropColor(0.08, 0.08, 0.08, 0.5)
    frame.contentFrame:SetBackdropBorderColor(0.15, 0.15, 0.15, 0.8)
    
    frame.scrollFrame = CreateFrame("ScrollFrame", "CA_ScrollFrame", frame.contentFrame, "UIPanelScrollFrameTemplate")
    frame.scrollFrame:SetPoint("TOPLEFT", frame.contentFrame, "TOPLEFT", 10, -10)
    frame.scrollFrame:SetPoint("BOTTOMRIGHT", frame.contentFrame, "BOTTOMRIGHT", -30, 10)
    
    frame.scrollChild = CreateFrame("Frame", nil, frame.scrollFrame)
    frame.scrollChild:SetSize(480, 600)
    frame.scrollFrame:SetScrollChild(frame.scrollChild)
    
    frame.tabContent = {}
    for _, info in ipairs(tabInfo) do
        local content = CreateFrame("Frame", nil, frame.scrollChild)
        content:SetAllPoints()
        content:Hide()
        frame.tabContent[info.key] = content
        
        CA:PopulateTabContent(content, info.key)
    end
    
    -- Bottom bar
    frame.bottomBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.bottomBar:SetPoint("BOTTOMLEFT", 3, 3)
    frame.bottomBar:SetPoint("BOTTOMRIGHT", -3, 3)
    frame.bottomBar:SetHeight(45)
    frame.bottomBar:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground" })
    frame.bottomBar:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    
    frame.minimapCheckbox = CreateFrame("CheckButton", "CA_MinimapCheckbox", frame.bottomBar, "UICheckButtonTemplate")
    frame.minimapCheckbox:SetPoint("LEFT", 10, 0)
    frame.minimapCheckbox:SetSize(24, 24)
    frame.minimapCheckbox.text:SetFont("Fonts\\FRIZQT__.TTF", 11)
    frame.minimapCheckbox.text:SetText("Show Minimap Icon")
    frame.minimapCheckbox.text:SetTextColor(0.9, 0.9, 0.9)
    frame.minimapCheckbox:SetScript("OnClick", function(self) CA:ToggleMinimapIcon() end)
    
    local function CreateModernButton(parent, text, width)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(width or 90, 30)
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
        btn.text = btn:CreateFontString(nil, "OVERLAY")
        btn.text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        btn.text:SetPoint("CENTER")
        btn.text:SetText(text)
        btn.text:SetTextColor(0.9, 0.9, 0.9)
        btn:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.25, 0.25, 0.25, 1); self.text:SetTextColor(1, 1, 1) end)
        btn:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.15, 0.15, 0.15, 1); self.text:SetTextColor(0.9, 0.9, 0.9) end)
        return btn
    end
    
    frame.closeButton = CreateModernButton(frame.bottomBar, "Close", 80)
    frame.closeButton:SetPoint("RIGHT", -10, 0)
    frame.closeButton.bg:SetColorTexture(0.2, 0.15, 0.1, 1)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)
    frame.closeButton:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.3, 0.2, 0.1, 1); self.text:SetTextColor(1, 1, 1) end)
    frame.closeButton:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.2, 0.15, 0.1, 1); self.text:SetTextColor(0.9, 0.9, 0.9) end)
    
    UIDropDownMenu_SetText(frame.profileDropdown, CA.useCharacterSettings and "Character" or "Global")
    CA:SelectTab("player")
end

function CA:PopulateTabContent(content, castbarType)
    content.castbarType = castbarType
    local yOffset = 0
    
    content.enableCheckbox = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    content.enableCheckbox:SetPoint("TOPLEFT", 0, yOffset)
    content.enableCheckbox:SetSize(24, 24)
    content.enableCheckbox.text:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    content.enableCheckbox.text:SetText("Enable " .. string.upper(castbarType:sub(1,1)) .. castbarType:sub(2) .. " Castbar")
    content.enableCheckbox.text:SetTextColor(0, 0.84, 1)
    content.enableCheckbox:SetScript("OnClick", function(self)
        local db = CA:GetActiveDB(castbarType)
        db.enabled = self:GetChecked()
        if db.enabled then CA:StartAnchoring(castbarType) else CA:StopAnchoring(castbarType) end
    end)
    
    yOffset = yOffset - 40
    
    -- Anchor Frame section
    content.anchorHeader = content:CreateFontString(nil, "OVERLAY")
    content.anchorHeader:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    content.anchorHeader:SetPoint("TOPLEFT", 0, yOffset)
    content.anchorHeader:SetText("Anchor Frame")
    content.anchorHeader:SetTextColor(0.9, 0.9, 0.9)
    yOffset = yOffset - 25
    
    content.currentLabel = content:CreateFontString(nil, "OVERLAY")
    content.currentLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
    content.currentLabel:SetPoint("TOPLEFT", 5, yOffset)
    content.currentLabel:SetText("Current:")
    content.currentLabel:SetTextColor(0.7, 0.7, 0.7)
    
    content.currentValue = content:CreateFontString(nil, "OVERLAY")
    content.currentValue:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    content.currentValue:SetPoint("LEFT", content.currentLabel, "RIGHT", 8, 0)
    content.currentValue:SetText("None")
    yOffset = yOffset - 30
    
    -- Suggested frames dropdown
    content.suggestedLabel = content:CreateFontString(nil, "OVERLAY")
    content.suggestedLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
    content.suggestedLabel:SetPoint("TOPLEFT", 5, yOffset)
    content.suggestedLabel:SetText("Quick Select:")
    content.suggestedLabel:SetTextColor(0.7, 0.7, 0.7)
    
    content.suggestedDropdown = CreateFrame("Frame", "CA_SuggestedDropdown_"..castbarType, content, "UIDropDownMenuTemplate")
    content.suggestedDropdown:SetPoint("LEFT", content.suggestedLabel, "RIGHT", -20, -3)
    content.suggestedDropdown.castbarType = castbarType
    UIDropDownMenu_SetWidth(content.suggestedDropdown, 230)
    
    UIDropDownMenu_Initialize(content.suggestedDropdown, function(self, level)
        local suggestions = {}
        if castbarType == "player" then
            table.insert(suggestions, {text = "Player Health Bar", value = "ElvUF_Player_HealthBar"})
            table.insert(suggestions, {text = "Player Power Bar", value = "ElvUF_Player_PowerBar"})
            table.insert(suggestions, {text = "Pet Health Bar", value = "ElvUF_Pet_HealthBar"})
            table.insert(suggestions, {text = "Pet Power Bar", value = "ElvUF_Pet_PowerBar"})
        elseif castbarType == "target" then
            table.insert(suggestions, {text = "Target Health Bar", value = "ElvUF_Target_HealthBar"})
            table.insert(suggestions, {text = "Target Power Bar", value = "ElvUF_Target_PowerBar"})
        elseif castbarType == "focus" then
            table.insert(suggestions, {text = "Focus Health Bar", value = "ElvUF_Focus_HealthBar"})
            table.insert(suggestions, {text = "Focus Power Bar", value = "ElvUF_Focus_PowerBar"})
        end
        -- Add common addons for all types
        table.insert(suggestions, {text = "Essential Cooldown Viewer", value = "EssentialCooldownViewer"})
        table.insert(suggestions, {text = "Screen Center", value = "UIParent"})
        
        for _, item in ipairs(suggestions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.text
            info.value = item.value
            info.func = function()
                print("|cffFF00FF=== DROPDOWN CLICKED ===|r")
                print("|cffFF00FFSelected:|r", item.text)
                print("|cffFF00FFValue:|r", item.value)
                
                CA.selectedCastbar = castbarType
                CA:SetAnchorFrame(item.value)
                UIDropDownMenu_SetText(content.suggestedDropdown, item.text)
                
                print("|cffFF00FFCalling UpdateSettingsUI...|r")
                CA:UpdateSettingsUI()
                print("|cffFF00FFUpdateSettingsUI completed|r")
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    UIDropDownMenu_SetText(content.suggestedDropdown, "Choose...")
    
    yOffset = yOffset - 30
    
    content.orLabel = content:CreateFontString(nil, "OVERLAY")
    content.orLabel:SetFont("Fonts\\FRIZQT__.TTF", 10)
    content.orLabel:SetPoint("TOPLEFT", 5, yOffset)
    content.orLabel:SetText("Or enter custom:")
    content.orLabel:SetTextColor(0.6, 0.6, 0.6)
    yOffset = yOffset - 20
    
    content.frameLabel = content:CreateFontString(nil, "OVERLAY")
    content.frameLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
    content.frameLabel:SetPoint("TOPLEFT", 5, yOffset)
    content.frameLabel:SetText("Frame Name:")
    content.frameLabel:SetTextColor(0.7, 0.7, 0.7)
    
    content.frameInput = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    content.frameInput:SetSize(260, 25)
    content.frameInput:SetPoint("LEFT", content.frameLabel, "RIGHT", 8, 0)
    content.frameInput:SetAutoFocus(false)
    content.frameInput:SetScript("OnEnterPressed", function(self)
        local name = self:GetText()
        if name and name ~= "" then
            CA.selectedCastbar = castbarType
            CA:SetAnchorFrame(name)
        end
        self:ClearFocus()
    end)
    
    content.anchorButton = CreateFrame("Button", nil, content)
    content.anchorButton:SetSize(80, 25)
    content.anchorButton:SetPoint("LEFT", content.frameInput, "RIGHT", 8, 0)
    content.anchorButton.bg = content.anchorButton:CreateTexture(nil, "BACKGROUND")
    content.anchorButton.bg:SetAllPoints()
    content.anchorButton.bg:SetColorTexture(0.2, 0.5, 0.2, 1)
    content.anchorButton.text = content.anchorButton:CreateFontString(nil, "OVERLAY")
    content.anchorButton.text:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    content.anchorButton.text:SetPoint("CENTER")
    content.anchorButton.text:SetText("Anchor")
    content.anchorButton:SetScript("OnClick", function()
        local name = content.frameInput:GetText()
        if name and name ~= "" then
            CA.selectedCastbar = castbarType
            CA:SetAnchorFrame(name)
            CA:UpdateSettingsUI()
        end
    end)
    content.anchorButton:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.25, 0.6, 0.25, 1) end)
    content.anchorButton:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.2, 0.5, 0.2, 1) end)
    
    yOffset = yOffset - 20
    
    content.helpText = content:CreateFontString(nil, "OVERLAY")
    content.helpText:SetFont("Fonts\\FRIZQT__.TTF", 9)
    content.helpText:SetPoint("TOPLEFT", 5, yOffset)
    content.helpText:SetTextColor(0.5, 0.5, 0.5)
    content.helpText:SetText("Use /fstack to find frame names")
    
    yOffset = yOffset - 25
    
    -- Pet frame override (player only)
    if castbarType == "player" then
        content.petCheckbox = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        content.petCheckbox:SetPoint("TOPLEFT", 5, yOffset)
        content.petCheckbox:SetSize(20, 20)
        content.petCheckbox.text:SetFont("Fonts\\FRIZQT__.TTF", 11)
        content.petCheckbox.text:SetText("Use Pet Frame when Active")
        content.petCheckbox.text:SetTextColor(0.9, 0.9, 0.9)
        content.petCheckbox:SetScript("OnClick", function(self)
            local db = CA:GetActiveDB(castbarType)
            db.usePetFrame = self:GetChecked()
            CA:UpdateCastbarPosition(castbarType)
            if db.usePetFrame then
                content.petDropdownLabel:Show()
                content.petDropdown:Show()
                content.petOrLabel:Show()
                content.petFrameLabel:Show()
                content.petFrameInput:Show()
            else
                content.petDropdownLabel:Hide()
                content.petDropdown:Hide()
                content.petOrLabel:Hide()
                content.petFrameLabel:Hide()
                content.petFrameInput:Hide()
            end
        end)
        
        yOffset = yOffset - 30
        
        -- Pet Quick Select dropdown
        content.petDropdownLabel = content:CreateFontString(nil, "OVERLAY")
        content.petDropdownLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
        content.petDropdownLabel:SetPoint("TOPLEFT", 20, yOffset)
        content.petDropdownLabel:SetText("Quick Select:")
        content.petDropdownLabel:SetTextColor(0.7, 0.7, 0.7)
        
        content.petDropdown = CreateFrame("Frame", "CA_PetDropdown_"..castbarType, content, "UIDropDownMenuTemplate")
        content.petDropdown:SetPoint("LEFT", content.petDropdownLabel, "RIGHT", -20, -3)
        content.petDropdown.castbarType = castbarType
        UIDropDownMenu_SetWidth(content.petDropdown, 230)
        
        UIDropDownMenu_Initialize(content.petDropdown, function(self, level)
            local suggestions = {
                {text = "Pet Health Bar", value = "ElvUF_Pet_HealthBar"},
                {text = "Pet Power Bar", value = "ElvUF_Pet_PowerBar"},
            }
            
            for _, item in ipairs(suggestions) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = item.text
                info.value = item.value
                info.func = function()
                    CA.selectedCastbar = castbarType
                    local db = CA:GetActiveDB(castbarType)
                    db.petAnchorFrame = item.value
                    content.petFrameInput:SetText(item.value)
                    UIDropDownMenu_SetText(content.petDropdown, item.text)
                    CA:UpdateCastbarPosition(castbarType)
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        
        UIDropDownMenu_SetText(content.petDropdown, "Choose...")
        
        yOffset = yOffset - 30
        
        content.petOrLabel = content:CreateFontString(nil, "OVERLAY")
        content.petOrLabel:SetFont("Fonts\\FRIZQT__.TTF", 10)
        content.petOrLabel:SetPoint("TOPLEFT", 20, yOffset)
        content.petOrLabel:SetText("Or enter custom:")
        content.petOrLabel:SetTextColor(0.6, 0.6, 0.6)
        yOffset = yOffset - 20
        
        content.petFrameLabel = content:CreateFontString(nil, "OVERLAY")
        content.petFrameLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
        content.petFrameLabel:SetPoint("TOPLEFT", 20, yOffset)
        content.petFrameLabel:SetText("Pet Frame:")
        content.petFrameLabel:SetTextColor(0.7, 0.7, 0.7)
        
        content.petFrameInput = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
        content.petFrameInput:SetSize(260, 25)
        content.petFrameInput:SetPoint("LEFT", content.petFrameLabel, "RIGHT", 8, 0)
        content.petFrameInput:SetAutoFocus(false)
        content.petFrameInput:SetScript("OnEnterPressed", function(self)
            local name = self:GetText()
            if name and name ~= "" then
                local db = CA:GetActiveDB(castbarType)
                db.petAnchorFrame = name
                CA:UpdateCastbarPosition(castbarType)
            end
            self:ClearFocus()
        end)
        
        yOffset = yOffset - 30
    else
        yOffset = yOffset - 5
    end
    
    -- Separator
    local sep1 = content:CreateTexture(nil, "ARTWORK")
    sep1:SetHeight(1)
    sep1:SetPoint("LEFT", 0, yOffset)
    sep1:SetPoint("RIGHT", 0, yOffset)
    sep1:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    yOffset = yOffset - 20
    
    -- Position section
    content.positionHeader = content:CreateFontString(nil, "OVERLAY")
    content.positionHeader:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    content.positionHeader:SetPoint("TOPLEFT", 0, yOffset)
    content.positionHeader:SetText("Position")
    content.positionHeader:SetTextColor(0.9, 0.9, 0.9)
    yOffset = yOffset - 30
    
    content.anchorPointLabel = content:CreateFontString(nil, "OVERLAY")
    content.anchorPointLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
    content.anchorPointLabel:SetPoint("TOPLEFT", 5, yOffset)
    content.anchorPointLabel:SetText("Point:")
    content.anchorPointLabel:SetTextColor(0.7, 0.7, 0.7)
    
    content.anchorPointDropdown = CreateFrame("Frame", "CA_AnchorPoint_"..castbarType, content, "UIDropDownMenuTemplate")
    content.anchorPointDropdown:SetPoint("LEFT", content.anchorPointLabel, "RIGHT", -20, -3)
    content.anchorPointDropdown.castbarType = castbarType
    UIDropDownMenu_SetWidth(content.anchorPointDropdown, 100)
    
    UIDropDownMenu_Initialize(content.anchorPointDropdown, function(self, level)
        local db = CA:GetActiveDB(self.castbarType)
        for _, point in ipairs(anchorPoints) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = point
            info.checked = (db.anchorPoint == point)
            info.func = function()
                db.anchorPoint = point
                UIDropDownMenu_SetText(content.anchorPointDropdown, point)
                CA:UpdateCastbarPosition(self.castbarType)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    content.arrowText = content:CreateFontString(nil, "OVERLAY")
    content.arrowText:SetFont("Fonts\\FRIZQT__.TTF", 14)
    content.arrowText:SetPoint("LEFT", content.anchorPointDropdown, "RIGHT", 10, 3)
    content.arrowText:SetText("→")
    content.arrowText:SetTextColor(0.7, 0.7, 0.7)
    
    content.relativePointDropdown = CreateFrame("Frame", "CA_RelativePoint_"..castbarType, content, "UIDropDownMenuTemplate")
    content.relativePointDropdown:SetPoint("LEFT", content.arrowText, "RIGHT", -10, -3)
    content.relativePointDropdown.castbarType = castbarType
    UIDropDownMenu_SetWidth(content.relativePointDropdown, 100)
    
    UIDropDownMenu_Initialize(content.relativePointDropdown, function(self, level)
        local db = CA:GetActiveDB(self.castbarType)
        for _, point in ipairs(anchorPoints) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = point
            info.checked = (db.relativePoint == point)
            info.func = function()
                db.relativePoint = point
                UIDropDownMenu_SetText(content.relativePointDropdown, point)
                CA:UpdateCastbarPosition(self.castbarType)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    yOffset = yOffset - 40
    
    -- X Offset
    content.offsetXLabel = content:CreateFontString(nil, "OVERLAY")
    content.offsetXLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
    content.offsetXLabel:SetPoint("TOPLEFT", 5, yOffset)
    content.offsetXLabel:SetText("X Offset:")
    content.offsetXLabel:SetTextColor(0.7, 0.7, 0.7)
    
    content.offsetXSlider = CreateFrame("Slider", "CA_OffsetX_"..castbarType, content, "OptionsSliderTemplate")
    content.offsetXSlider:SetPoint("LEFT", content.offsetXLabel, "RIGHT", 15, 0)
    content.offsetXSlider:SetMinMaxValues(-500, 500)
    content.offsetXSlider:SetValueStep(1)
    content.offsetXSlider:SetObeyStepOnDrag(true)
    content.offsetXSlider:SetWidth(240)
    content.offsetXSlider.castbarType = castbarType
    _G["CA_OffsetX_"..castbarType.."Low"]:SetText("-500")
    _G["CA_OffsetX_"..castbarType.."High"]:SetText("500")
    
    content.offsetXInput = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    content.offsetXInput:SetSize(55, 25)
    content.offsetXInput:SetPoint("LEFT", content.offsetXSlider, "RIGHT", 15, 0)
    content.offsetXInput:SetAutoFocus(false)
    content.offsetXInput:SetMaxLetters(5)
    content.offsetXInput:SetJustifyH("CENTER")
    
    content.offsetXSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        local db = CA:GetActiveDB(self.castbarType)
        db.offsetX = value
        content.offsetXInput:SetText(value)
        CA:UpdateCastbarPosition(self.castbarType)
    end)
    
    content.offsetXInput:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        local value = tonumber(text) or 0
        value = math.max(-500, math.min(500, value))
        local db = CA:GetActiveDB(castbarType)
        db.offsetX = value
        content.offsetXSlider:SetValue(value)
        self:SetText(value)
        self:ClearFocus()
        CA:UpdateCastbarPosition(castbarType)
    end)
    
    content.offsetXInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    
    yOffset = yOffset - 35
    
    -- Y Offset
    content.offsetYLabel = content:CreateFontString(nil, "OVERLAY")
    content.offsetYLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
    content.offsetYLabel:SetPoint("TOPLEFT", 5, yOffset)
    content.offsetYLabel:SetText("Y Offset:")
    content.offsetYLabel:SetTextColor(0.7, 0.7, 0.7)
    
    content.offsetYSlider = CreateFrame("Slider", "CA_OffsetY_"..castbarType, content, "OptionsSliderTemplate")
    content.offsetYSlider:SetPoint("LEFT", content.offsetYLabel, "RIGHT", 15, 0)
    content.offsetYSlider:SetMinMaxValues(-500, 500)
    content.offsetYSlider:SetValueStep(1)
    content.offsetYSlider:SetObeyStepOnDrag(true)
    content.offsetYSlider:SetWidth(240)
    content.offsetYSlider.castbarType = castbarType
    _G["CA_OffsetY_"..castbarType.."Low"]:SetText("-500")
    _G["CA_OffsetY_"..castbarType.."High"]:SetText("500")
    
    content.offsetYInput = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    content.offsetYInput:SetSize(55, 25)
    content.offsetYInput:SetPoint("LEFT", content.offsetYSlider, "RIGHT", 15, 0)
    content.offsetYInput:SetAutoFocus(false)
    content.offsetYInput:SetMaxLetters(5)
    content.offsetYInput:SetJustifyH("CENTER")
    
    content.offsetYSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        local db = CA:GetActiveDB(self.castbarType)
        db.offsetY = value
        content.offsetYInput:SetText(value)
        CA:UpdateCastbarPosition(self.castbarType)
    end)
    
    content.offsetYInput:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        local value = tonumber(text) or 0
        value = math.max(-500, math.min(500, value))
        local db = CA:GetActiveDB(castbarType)
        db.offsetY = value
        content.offsetYSlider:SetValue(value)
        self:SetText(value)
        self:ClearFocus()
        CA:UpdateCastbarPosition(castbarType)
    end)
    
    content.offsetYInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    
    yOffset = yOffset - 40
    
    -- Normal Frame Width (shows only for unitframe anchors)
    content.normalFrameWidthLabel = content:CreateFontString(nil, "OVERLAY")
    content.normalFrameWidthLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
    content.normalFrameWidthLabel:SetPoint("TOPLEFT", 5, yOffset)
    content.normalFrameWidthLabel:SetText("Castbar Width (Unitframes only):")
    content.normalFrameWidthLabel:SetTextColor(0.7, 0.7, 0.7)
    content.normalFrameWidthLabel:Hide()  -- Start hidden
    
    content.normalFrameWidthSlider = CreateFrame("Slider", "CA_NormalFrameWidth_"..castbarType, content, "OptionsSliderTemplate")
    content.normalFrameWidthSlider:SetPoint("TOPLEFT", 20, yOffset - 25)
    content.normalFrameWidthSlider:SetMinMaxValues(50, 500)
    content.normalFrameWidthSlider:SetValueStep(1)
    content.normalFrameWidthSlider:SetObeyStepOnDrag(true)
    content.normalFrameWidthSlider:SetWidth(200)
    content.normalFrameWidthSlider.castbarType = castbarType
    content.normalFrameWidthSlider:Hide()  -- Start hidden
    _G["CA_NormalFrameWidth_"..castbarType.."Low"]:SetText("50")
    _G["CA_NormalFrameWidth_"..castbarType.."High"]:SetText("500")
    
    content.normalFrameWidthInput = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    content.normalFrameWidthInput:SetSize(60, 25)
    content.normalFrameWidthInput:SetPoint("LEFT", content.normalFrameWidthSlider, "RIGHT", 15, 0)
    content.normalFrameWidthInput:SetAutoFocus(false)
    content.normalFrameWidthInput:SetMaxLetters(3)
    content.normalFrameWidthInput:SetJustifyH("CENTER")
    content.normalFrameWidthInput:SetText("270")
    content.normalFrameWidthInput:Hide()  -- Start hidden
    
    content.normalFrameWidthSlider:SetScript("OnValueChanged", function(self, value)
        local db = CA:GetActiveDB(self.castbarType)
        db.normalFrameWidth = value
        content.normalFrameWidthInput:SetText(value)
        CA:UpdateCastbarPosition(self.castbarType)
    end)
    
    content.normalFrameWidthInput:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        local value = tonumber(text) or 270
        value = math.max(50, math.min(500, value))
        local db = CA:GetActiveDB(castbarType)
        db.normalFrameWidth = value
        content.normalFrameWidthSlider:SetValue(value)
        self:SetText(value)
        self:ClearFocus()
        CA:UpdateCastbarPosition(castbarType)
    end)
    
    content.normalFrameWidthInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    
    yOffset = yOffset - 60
    
    -- Normal Frame Height (shows only for unitframe anchors)
    content.normalFrameHeightLabel = content:CreateFontString(nil, "OVERLAY")
    content.normalFrameHeightLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
    content.normalFrameHeightLabel:SetPoint("TOPLEFT", 5, yOffset)
    content.normalFrameHeightLabel:SetText("Castbar Height (Unitframes only):")
    content.normalFrameHeightLabel:SetTextColor(0.7, 0.7, 0.7)
    content.normalFrameHeightLabel:Hide()  -- Start hidden
    
    content.normalFrameHeightSlider = CreateFrame("Slider", "CA_NormalFrameHeight_"..castbarType, content, "OptionsSliderTemplate")
    content.normalFrameHeightSlider:SetPoint("TOPLEFT", 20, yOffset - 25)
    content.normalFrameHeightSlider:SetMinMaxValues(5, 100)
    content.normalFrameHeightSlider:SetValueStep(1)
    content.normalFrameHeightSlider:SetObeyStepOnDrag(true)
    content.normalFrameHeightSlider:SetWidth(200)
    content.normalFrameHeightSlider.castbarType = castbarType
    content.normalFrameHeightSlider:Hide()  -- Start hidden
    _G["CA_NormalFrameHeight_"..castbarType.."Low"]:SetText("5")
    _G["CA_NormalFrameHeight_"..castbarType.."High"]:SetText("100")
    
    content.normalFrameHeightInput = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    content.normalFrameHeightInput:SetSize(60, 25)
    content.normalFrameHeightInput:SetPoint("LEFT", content.normalFrameHeightSlider, "RIGHT", 15, 0)
    content.normalFrameHeightInput:SetAutoFocus(false)
    content.normalFrameHeightInput:SetMaxLetters(3)
    content.normalFrameHeightInput:SetJustifyH("CENTER")
    content.normalFrameHeightInput:SetText("18")
    content.normalFrameHeightInput:Hide()  -- Start hidden
    
    content.normalFrameHeightSlider:SetScript("OnValueChanged", function(self, value)
        local db = CA:GetActiveDB(self.castbarType)
        db.normalFrameHeight = value
        content.normalFrameHeightInput:SetText(value)
        CA:UpdateCastbarPosition(self.castbarType)
    end)
    
    content.normalFrameHeightInput:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        local value = tonumber(text) or 18
        value = math.max(5, math.min(100, value))
        local db = CA:GetActiveDB(castbarType)
        db.normalFrameHeight = value
        content.normalFrameHeightSlider:SetValue(value)
        self:SetText(value)
        self:ClearFocus()
        CA:UpdateCastbarPosition(castbarType)
    end)
    
    content.normalFrameHeightInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    
    yOffset = yOffset - 30
    
    -- Match Width checkbox
    content.matchWidthCheckbox = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    content.matchWidthCheckbox:SetPoint("TOPLEFT", 5, yOffset)
    content.matchWidthCheckbox:SetSize(20, 20)
    content.matchWidthCheckbox.text:SetFont("Fonts\\FRIZQT__.TTF", 11)
    content.matchWidthCheckbox.text:SetText("Match Anchor Width (EssentialCooldownViewer only)")
    content.matchWidthCheckbox.text:SetTextColor(0.9, 0.9, 0.9)
    content.matchWidthCheckbox:SetScript("OnClick", function(self)
        local db = CA:GetActiveDB(castbarType)
        db.matchWidth = self:GetChecked()
        CA:UpdateCastbarPosition(castbarType)
        -- Show/hide border adjustment based on match width state
        if db.matchWidth then
            content.borderAdjustLabel:Show()
            content.borderAdjustSlider:Show()
            content.borderAdjustInput:Show()
            content.borderAdjustHelp:Show()
        else
            content.borderAdjustLabel:Hide()
            content.borderAdjustSlider:Hide()
            content.borderAdjustInput:Hide()
            content.borderAdjustHelp:Hide()
        end
    end)
    
    yOffset = yOffset - 30
    
    -- Border Adjustment slider
    content.borderAdjustLabel = content:CreateFontString(nil, "OVERLAY")
    content.borderAdjustLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
    content.borderAdjustLabel:SetPoint("TOPLEFT", 20, yOffset)
    content.borderAdjustLabel:SetText("Border Adjust:")
    content.borderAdjustLabel:SetTextColor(0.7, 0.7, 0.7)
    
    content.borderAdjustSlider = CreateFrame("Slider", "CA_BorderAdjust_"..castbarType, content, "OptionsSliderTemplate")
    content.borderAdjustSlider:SetPoint("LEFT", content.borderAdjustLabel, "RIGHT", 15, 0)
    content.borderAdjustSlider:SetMinMaxValues(0, 10)
    content.borderAdjustSlider:SetValueStep(1)
    content.borderAdjustSlider:SetObeyStepOnDrag(true)
    content.borderAdjustSlider:SetWidth(180)
    content.borderAdjustSlider.castbarType = castbarType
    _G["CA_BorderAdjust_"..castbarType.."Low"]:SetText("0px")
    _G["CA_BorderAdjust_"..castbarType.."High"]:SetText("10px")
    
    content.borderAdjustInput = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    content.borderAdjustInput:SetSize(55, 25)
    content.borderAdjustInput:SetPoint("LEFT", content.borderAdjustSlider, "RIGHT", 15, 0)
    content.borderAdjustInput:SetAutoFocus(false)
    content.borderAdjustInput:SetMaxLetters(2)
    content.borderAdjustInput:SetJustifyH("CENTER")
    content.borderAdjustInput:SetText("0")
    
    content.borderAdjustSlider:SetScript("OnValueChanged", function(self, value)
        local db = CA:GetActiveDB(self.castbarType)
        db.borderAdjust = value
        content.borderAdjustInput:SetText(value)
        CA:UpdateCastbarPosition(self.castbarType)
    end)
    
    content.borderAdjustInput:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        local value = tonumber(text) or 0
        value = math.max(0, math.min(10, value))
        local db = CA:GetActiveDB(castbarType)
        db.borderAdjust = value
        content.borderAdjustSlider:SetValue(value)
        self:SetText(value)
        self:ClearFocus()
        CA:UpdateCastbarPosition(castbarType)
    end)
    
    content.borderAdjustInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    
    yOffset = yOffset - 25
    
    content.borderAdjustHelp = content:CreateFontString(nil, "OVERLAY")
    content.borderAdjustHelp:SetFont("Fonts\\FRIZQT__.TTF", 9)
    content.borderAdjustHelp:SetPoint("TOPLEFT", 20, yOffset)
    content.borderAdjustHelp:SetTextColor(0.5, 0.5, 0.5)
    content.borderAdjustHelp:SetText("For 2px borders, set to 2. Automatically centers - no X offset needed!")
    
    yOffset = yOffset - 30
    
    -- EssentialCooldownViewer X Offset
    content.essentialCDOffsetXLabel = content:CreateFontString(nil, "OVERLAY")
    content.essentialCDOffsetXLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
    content.essentialCDOffsetXLabel:SetPoint("TOPLEFT", 20, yOffset)
    content.essentialCDOffsetXLabel:SetText("EssentialCD X:")
    content.essentialCDOffsetXLabel:SetTextColor(0.7, 0.7, 0.7)
    
    content.essentialCDOffsetXSlider = CreateFrame("Slider", "CA_EssentialCDOffsetX_"..castbarType, content, "OptionsSliderTemplate")
    content.essentialCDOffsetXSlider:SetPoint("LEFT", content.essentialCDOffsetXLabel, "RIGHT", 15, 0)
    content.essentialCDOffsetXSlider:SetMinMaxValues(-500, 500)
    content.essentialCDOffsetXSlider:SetValueStep(1)
    content.essentialCDOffsetXSlider:SetObeyStepOnDrag(true)
    content.essentialCDOffsetXSlider:SetWidth(180)
    content.essentialCDOffsetXSlider.castbarType = castbarType
    _G["CA_EssentialCDOffsetX_"..castbarType.."Low"]:SetText("-500")
    _G["CA_EssentialCDOffsetX_"..castbarType.."High"]:SetText("500")
    
    content.essentialCDOffsetXInput = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    content.essentialCDOffsetXInput:SetSize(55, 25)
    content.essentialCDOffsetXInput:SetPoint("LEFT", content.essentialCDOffsetXSlider, "RIGHT", 15, 0)
    content.essentialCDOffsetXInput:SetAutoFocus(false)
    content.essentialCDOffsetXInput:SetMaxLetters(4)
    content.essentialCDOffsetXInput:SetJustifyH("CENTER")
    content.essentialCDOffsetXInput:SetText("0")
    
    content.essentialCDOffsetXSlider:SetScript("OnValueChanged", function(self, value)
        local db = CA:GetActiveDB(self.castbarType)
        db.essentialCDOffsetX = value
        content.essentialCDOffsetXInput:SetText(value)
        CA:UpdateCastbarPosition(self.castbarType)
    end)
    
    content.essentialCDOffsetXInput:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        local value = tonumber(text) or 0
        value = math.max(-500, math.min(500, value))
        local db = CA:GetActiveDB(castbarType)
        db.essentialCDOffsetX = value
        content.essentialCDOffsetXSlider:SetValue(value)
        self:SetText(value)
        self:ClearFocus()
        CA:UpdateCastbarPosition(castbarType)
    end)
    
    content.essentialCDOffsetXInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    
    yOffset = yOffset - 35
    
    -- EssentialCooldownViewer Y Offset
    content.essentialCDOffsetYLabel = content:CreateFontString(nil, "OVERLAY")
    content.essentialCDOffsetYLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
    content.essentialCDOffsetYLabel:SetPoint("TOPLEFT", 20, yOffset)
    content.essentialCDOffsetYLabel:SetText("EssentialCD Y:")
    content.essentialCDOffsetYLabel:SetTextColor(0.7, 0.7, 0.7)
    
    content.essentialCDOffsetYSlider = CreateFrame("Slider", "CA_EssentialCDOffsetY_"..castbarType, content, "OptionsSliderTemplate")
    content.essentialCDOffsetYSlider:SetPoint("LEFT", content.essentialCDOffsetYLabel, "RIGHT", 15, 0)
    content.essentialCDOffsetYSlider:SetMinMaxValues(-500, 500)
    content.essentialCDOffsetYSlider:SetValueStep(1)
    content.essentialCDOffsetYSlider:SetObeyStepOnDrag(true)
    content.essentialCDOffsetYSlider:SetWidth(180)
    content.essentialCDOffsetYSlider.castbarType = castbarType
    _G["CA_EssentialCDOffsetY_"..castbarType.."Low"]:SetText("-500")
    _G["CA_EssentialCDOffsetY_"..castbarType.."High"]:SetText("500")
    
    content.essentialCDOffsetYInput = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    content.essentialCDOffsetYInput:SetSize(55, 25)
    content.essentialCDOffsetYInput:SetPoint("LEFT", content.essentialCDOffsetYSlider, "RIGHT", 15, 0)
    content.essentialCDOffsetYInput:SetAutoFocus(false)
    content.essentialCDOffsetYInput:SetMaxLetters(4)
    content.essentialCDOffsetYInput:SetJustifyH("CENTER")
    content.essentialCDOffsetYInput:SetText("0")
    
    content.essentialCDOffsetYSlider:SetScript("OnValueChanged", function(self, value)
        local db = CA:GetActiveDB(self.castbarType)
        db.essentialCDOffsetY = value
        content.essentialCDOffsetYInput:SetText(value)
        CA:UpdateCastbarPosition(self.castbarType)
    end)
    
    content.essentialCDOffsetYInput:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        local value = tonumber(text) or 0
        value = math.max(-500, math.min(500, value))
        local db = CA:GetActiveDB(castbarType)
        db.essentialCDOffsetY = value
        content.essentialCDOffsetYSlider:SetValue(value)
        self:SetText(value)
        self:ClearFocus()
        CA:UpdateCastbarPosition(castbarType)
    end)
    
    content.essentialCDOffsetYInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    
    yOffset = yOffset - 35
    
    -- EssentialCooldownViewer Height
    content.essentialCDHeightLabel = content:CreateFontString(nil, "OVERLAY")
    content.essentialCDHeightLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
    content.essentialCDHeightLabel:SetPoint("TOPLEFT", 20, yOffset)
    content.essentialCDHeightLabel:SetText("EssentialCD Height:")
    content.essentialCDHeightLabel:SetTextColor(0.7, 0.7, 0.7)
    
    content.essentialCDHeightSlider = CreateFrame("Slider", "CA_EssentialCDHeight_"..castbarType, content, "OptionsSliderTemplate")
    content.essentialCDHeightSlider:SetPoint("LEFT", content.essentialCDHeightLabel, "RIGHT", 15, 0)
    content.essentialCDHeightSlider:SetMinMaxValues(5, 100)
    content.essentialCDHeightSlider:SetValueStep(1)
    content.essentialCDHeightSlider:SetObeyStepOnDrag(true)
    content.essentialCDHeightSlider:SetWidth(180)
    content.essentialCDHeightSlider.castbarType = castbarType
    _G["CA_EssentialCDHeight_"..castbarType.."Low"]:SetText("5")
    _G["CA_EssentialCDHeight_"..castbarType.."High"]:SetText("100")
    
    content.essentialCDHeightInput = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    content.essentialCDHeightInput:SetSize(55, 25)
    content.essentialCDHeightInput:SetPoint("LEFT", content.essentialCDHeightSlider, "RIGHT", 15, 0)
    content.essentialCDHeightInput:SetAutoFocus(false)
    content.essentialCDHeightInput:SetMaxLetters(3)
    content.essentialCDHeightInput:SetJustifyH("CENTER")
    content.essentialCDHeightInput:SetText("18")
    
    content.essentialCDHeightSlider:SetScript("OnValueChanged", function(self, value)
        local db = CA:GetActiveDB(self.castbarType)
        db.essentialCDHeight = value
        content.essentialCDHeightInput:SetText(value)
        CA:UpdateCastbarPosition(self.castbarType)
    end)
    
    content.essentialCDHeightInput:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        local value = tonumber(text) or 18
        value = math.max(5, math.min(100, value))
        local db = CA:GetActiveDB(castbarType)
        db.essentialCDHeight = value
        content.essentialCDHeightSlider:SetValue(value)
        self:SetText(value)
        self:ClearFocus()
        CA:UpdateCastbarPosition(castbarType)
    end)
    
    content.essentialCDHeightInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    
    yOffset = yOffset - 30
    
    -- Separator
    local sep2 = content:CreateTexture(nil, "ARTWORK")
    sep2:SetHeight(1)
    sep2:SetPoint("LEFT", 0, yOffset)
    sep2:SetPoint("RIGHT", 0, yOffset)
    sep2:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    yOffset = yOffset - 20
    
    -- Update Rate
    content.updateRateLabel = content:CreateFontString(nil, "OVERLAY")
    content.updateRateLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
    content.updateRateLabel:SetPoint("TOPLEFT", 5, yOffset)
    content.updateRateLabel:SetText("Update Rate:")
    content.updateRateLabel:SetTextColor(0.7, 0.7, 0.7)
    
    content.updateRateSlider = CreateFrame("Slider", "CA_UpdateRate_"..castbarType, content, "OptionsSliderTemplate")
    content.updateRateSlider:SetPoint("LEFT", content.updateRateLabel, "RIGHT", 15, 0)
    content.updateRateSlider:SetMinMaxValues(0.01, 0.5)
    content.updateRateSlider:SetValueStep(0.01)
    content.updateRateSlider:SetObeyStepOnDrag(true)
    content.updateRateSlider:SetWidth(180)
    content.updateRateSlider.castbarType = castbarType
    _G["CA_UpdateRate_"..castbarType.."Low"]:SetText("0.01s")
    _G["CA_UpdateRate_"..castbarType.."High"]:SetText("0.5s")
    
    content.updateRateInput = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    content.updateRateInput:SetSize(55, 25)
    content.updateRateInput:SetPoint("LEFT", content.updateRateSlider, "RIGHT", 15, 0)
    content.updateRateInput:SetAutoFocus(false)
    content.updateRateInput:SetMaxLetters(5)
    content.updateRateInput:SetJustifyH("CENTER")
    content.updateRateInput:SetText("0.05")
    
    content.updateRateSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 100) / 100
        local db = CA:GetActiveDB(self.castbarType)
        db.updateRate = value
        content.updateRateInput:SetText(string.format("%.2f", value))
        if db.enabled and db.anchorFrame then
            CA:StopAnchoring(self.castbarType)
            CA:StartAnchoring(self.castbarType)
        end
    end)
    
    content.updateRateInput:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        local value = tonumber(text) or 0.05
        value = math.max(0.01, math.min(0.5, value))
        value = math.floor(value * 100) / 100
        local db = CA:GetActiveDB(castbarType)
        db.updateRate = value
        content.updateRateSlider:SetValue(value)
        self:SetText(string.format("%.2f", value))
        self:ClearFocus()
        if db.enabled and db.anchorFrame then
            CA:StopAnchoring(castbarType)
            CA:StartAnchoring(castbarType)
        end
    end)
    
    content.updateRateInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    
    yOffset = yOffset - 30
    
    content.updateRateHelp = content:CreateFontString(nil, "OVERLAY")
    content.updateRateHelp:SetFont("Fonts\\FRIZQT__.TTF", 9)
    content.updateRateHelp:SetPoint("TOPLEFT", 5, yOffset)
    content.updateRateHelp:SetTextColor(0.5, 0.5, 0.5)
    content.updateRateHelp:SetText("Lower = smoother tracking, Higher = better performance")
end

function CA:SelectTab(castbarType)
    local frame = CA_SettingsFrame
    if not frame then return end
    
    CA.selectedCastbar = castbarType
    
    for i, tab in ipairs(frame.tabs) do
        if tab.key == castbarType then
            tab.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
            tab.topBorder:Show()
            tab.text:SetTextColor(0, 0.84, 1)
        else
            tab.bg:SetColorTexture(0.12, 0.12, 0.12, 0.8)
            tab.topBorder:Hide()
            tab.text:SetTextColor(0.7, 0.7, 0.7)
        end
    end
    
    for key, content in pairs(frame.tabContent) do
        if key == castbarType then
            content:Show()
            CA:UpdateTabContent(content, castbarType)
        else
            content:Hide()
        end
    end
end

function CA:UpdateTabContent(content, castbarType)
    print("|cff00FFFF=== UpdateTabContent called ===|r")
    print("|cff00FFFFcastbarType:|r", castbarType)
    
    local db = CA:GetActiveDB(castbarType)
    
    print("|cff00FFFFdb.anchorFrame:|r", db.anchorFrame or "nil")
    
    content.enableCheckbox:SetChecked(db.enabled)
    
    if db.anchorFrame then
        content.currentValue:SetText("|cff00ff00"..db.anchorFrame.."|r")
        content.frameInput:SetText(db.anchorFrame)
    else
        content.currentValue:SetText("|cffff0000None|r")
        content.frameInput:SetText("")
    end
    
    if castbarType == "player" and content.petCheckbox then
        content.petCheckbox:SetChecked(db.usePetFrame or false)
        content.petFrameInput:SetText(db.petAnchorFrame or "")
        
        if db.usePetFrame then
            content.petDropdownLabel:Show()
            content.petDropdown:Show()
            content.petOrLabel:Show()
            content.petFrameLabel:Show()
            content.petFrameInput:Show()
        else
            content.petDropdownLabel:Hide()
            content.petDropdown:Hide()
            content.petOrLabel:Hide()
            content.petFrameLabel:Hide()
            content.petFrameInput:Hide()
        end
    end
    
    UIDropDownMenu_SetText(content.anchorPointDropdown, db.anchorPoint or "CENTER")
    UIDropDownMenu_SetText(content.relativePointDropdown, db.relativePoint or "CENTER")
    
    content.offsetXSlider:SetValue(db.offsetX or 0)
    content.offsetYSlider:SetValue(db.offsetY or 0)
    content.offsetXInput:SetText(db.offsetX or 0)
    content.offsetYInput:SetText(db.offsetY or 0)
    
    content.matchWidthCheckbox:SetChecked(db.matchWidth or false)
    content.borderAdjustSlider:SetValue(db.borderAdjust or 0)
    content.borderAdjustInput:SetText(db.borderAdjust or 0)
    
    -- Enable/disable match width controls based on anchor frame
    local isEssentialCD = (db.anchorFrame == "EssentialCooldownViewer")
    local isUnitframeAnchor = (db.anchorFrame and (db.anchorFrame:match("HealthBar") or db.anchorFrame:match("PowerBar")))
    
    if isEssentialCD then
        content.matchWidthCheckbox:Enable()
        content.matchWidthCheckbox.text:SetTextColor(0.9, 0.9, 0.9)
    else
        content.matchWidthCheckbox:Disable()
        content.matchWidthCheckbox:SetChecked(false)
        db.matchWidth = false
        content.matchWidthCheckbox.text:SetTextColor(0.5, 0.5, 0.5)
    end
    
    -- Show/hide border adjustment based on match width state and anchor frame
    if db.matchWidth and isEssentialCD then
        content.borderAdjustLabel:Show()
        content.borderAdjustSlider:Show()
        content.borderAdjustInput:Show()
        content.borderAdjustHelp:Show()
    else
        content.borderAdjustLabel:Hide()
        content.borderAdjustSlider:Hide()
        content.borderAdjustInput:Hide()
        content.borderAdjustHelp:Hide()
    end
    
    -- Show/hide EssentialCD offset sliders based on anchor frame
    if isEssentialCD then
        content.essentialCDOffsetXLabel:Show()
        content.essentialCDOffsetXSlider:Show()
        content.essentialCDOffsetXInput:Show()
        content.essentialCDOffsetYLabel:Show()
        content.essentialCDOffsetYSlider:Show()
        content.essentialCDOffsetYInput:Show()
        content.essentialCDHeightLabel:Show()
        content.essentialCDHeightSlider:Show()
        content.essentialCDHeightInput:Show()
        
        -- Set values
        content.essentialCDOffsetXSlider:SetValue(db.essentialCDOffsetX or 0)
        content.essentialCDOffsetXInput:SetText(db.essentialCDOffsetX or 0)
        content.essentialCDOffsetYSlider:SetValue(db.essentialCDOffsetY or 0)
        content.essentialCDOffsetYInput:SetText(db.essentialCDOffsetY or 0)
        content.essentialCDHeightSlider:SetValue(db.essentialCDHeight or 18)
        content.essentialCDHeightInput:SetText(db.essentialCDHeight or 18)
    else
        content.essentialCDOffsetXLabel:Hide()
        content.essentialCDOffsetXSlider:Hide()
        content.essentialCDOffsetXInput:Hide()
        content.essentialCDOffsetYLabel:Hide()
        content.essentialCDOffsetYSlider:Hide()
        content.essentialCDOffsetYInput:Hide()
        content.essentialCDHeightLabel:Hide()
        content.essentialCDHeightSlider:Hide()
        content.essentialCDHeightInput:Hide()
    end
    
    -- Show/hide normal frame width/height sliders (only for unitframe anchors, opposite of EssentialCD)
    if isUnitframeAnchor then
        print("|cff00FF00CASTBAR ANCHORS: isUnitframeAnchor = TRUE|r")
        print("|cff00FF00Showing normal frame sliders for anchor:|r", db.anchorFrame or "nil")
        
        -- If not set yet, read from ElvUI database as default
        if not db.normalFrameWidth or not db.normalFrameHeight then
            local unitKey = castbarType
            if E and E.db and E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units[unitKey] and E.db.unitframe.units[unitKey].castbar then
                if not db.normalFrameWidth then
                    db.normalFrameWidth = E.db.unitframe.units[unitKey].castbar.width or 270
                    print("|cffFFFF00Read width from ElvUI:|r", db.normalFrameWidth)
                end
                if not db.normalFrameHeight then
                    db.normalFrameHeight = E.db.unitframe.units[unitKey].castbar.height or 18
                    print("|cffFFFF00Read height from ElvUI:|r", db.normalFrameHeight)
                end
            end
        end
        
        -- Check if sliders exist
        if content.normalFrameWidthLabel then
            content.normalFrameWidthLabel:Show()
            print("|cff00FF00Called Show() on normalFrameWidthLabel|r")
        else
            print("|cffFF0000normalFrameWidthLabel does not exist!|r")
        end
        
        if content.normalFrameWidthSlider then
            content.normalFrameWidthSlider:Show()
            print("|cff00FF00Called Show() on normalFrameWidthSlider|r")
        else
            print("|cffFF0000normalFrameWidthSlider does not exist!|r")
        end
        
        content.normalFrameWidthInput:Show()
        content.normalFrameHeightLabel:Show()
        content.normalFrameHeightSlider:Show()
        content.normalFrameHeightInput:Show()
        
        -- Set values
        content.normalFrameWidthSlider:SetValue(db.normalFrameWidth or 270)
        content.normalFrameWidthInput:SetText(db.normalFrameWidth or 270)
        content.normalFrameHeightSlider:SetValue(db.normalFrameHeight or 18)
        content.normalFrameHeightInput:SetText(db.normalFrameHeight or 18)
        
        print("|cff00FF00Set values - Width:|r", db.normalFrameWidth or 270, "|cff00FF00Height:|r", db.normalFrameHeight or 18)
    else
        print("|cffFF0000CASTBAR ANCHORS: isUnitframeAnchor = FALSE|r")
        print("|cffFF0000Hiding normal frame sliders for anchor:|r", db.anchorFrame or "nil")
        
        content.normalFrameWidthLabel:Hide()
        content.normalFrameWidthSlider:Hide()
        content.normalFrameWidthInput:Hide()
        content.normalFrameHeightLabel:Hide()
        content.normalFrameHeightSlider:Hide()
        content.normalFrameHeightInput:Hide()
    end
    
    content.updateRateSlider:SetValue(db.updateRate or 0.05)
    content.updateRateInput:SetText(string.format("%.2f", db.updateRate or 0.05))
end

function CA:UpdateSettingsUI()
    print("|cffFFFF00=== UpdateSettingsUI called ===|r")
    
    if not CA_SettingsFrame then 
        print("|cffFF0000CA_SettingsFrame does not exist!|r")
        return 
    end
    
    print("|cffFFFF00CA_SettingsFrame exists|r")
    
    local frame = CA_SettingsFrame
    
    if frame.profileDropdown then
        UIDropDownMenu_SetText(frame.profileDropdown, CA.useCharacterSettings and "Character" or "Global")
    end
    
    if frame.minimapCheckbox then
        frame.minimapCheckbox:SetChecked(not CA.db.minimap.hide)
    end
    
    print("|cffFFFF00selectedCastbar:|r", CA.selectedCastbar or "nil")
    
    local content = frame.tabContent and frame.tabContent[CA.selectedCastbar]
    if content then
        print("|cffFFFF00Content frame found, calling UpdateTabContent|r")
        CA:UpdateTabContent(content, CA.selectedCastbar)
        print("|cffFFFF00UpdateTabContent completed|r")
    else
        print("|cffFF0000Content frame NOT found!|r")
        print("|cffFF0000frame.tabContent:|r", frame.tabContent)
        if frame.tabContent then
            print("|cffFF0000Available keys:|r")
            for k,v in pairs(frame.tabContent) do
                print("|cffFF0000  Key:|r", k)
            end
        end
    end
end

-- Initialize when loaded
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "ElvUI_Castbar_Anchors" then
        CA:Initialize()
    end
end)
