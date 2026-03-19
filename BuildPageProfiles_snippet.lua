-- ============================================================
-- PAGE 9: Profiles
-- ============================================================
-- Add this function to GUI.lua alongside the other BuildPage* functions.
-- Then wire it into BuildGUI() like the other pages (see instructions below).
-- ============================================================
local function BuildPageProfiles(page)
    local y = 10

    -- ── Active profile banner ────────────────────────────────────────────────
    y = WHeader(page, "Profiles", y)
    y = WTip(page, "Profiles let you save and switch between different window layouts.", ML, y)

    local activeBanner = CreateFrame("Frame", nil, page, "BackdropTemplate")
    activeBanner:SetSize(EW, 28); activeBanner:SetPoint("TOPLEFT", page, "TOPLEFT", ML, -y)
    BD(activeBanner, 0.06, 0.14, 0.06, 1, 0.20, 0.55, 0.20)
    local activeLbl = activeBanner:CreateFontString(nil, "OVERLAY")
    activeLbl:SetFont("Fonts\\ARIALN.TTF", GFS(), "OUTLINE")
    activeLbl:SetTextColor(0.5, 1, 0.5, 1); activeLbl:SetAllPoints(); activeLbl:SetJustifyH("CENTER")
    local function RefreshActiveBanner()
        activeLbl:SetText("Active profile:  |cFFFFFFFF" .. (CT:GetActiveProfile()) .. "|r")
    end
    RefreshActiveBanner(); y = y + 34

    -- ── Profile list ─────────────────────────────────────────────────────────
    y = WHeader(page, "Saved Profiles", y)

    local listHolder = CreateFrame("Frame", nil, page)
    listHolder:SetPoint("TOPLEFT", page, "TOPLEFT", ML, -y); listHolder:SetWidth(EW)

    local function RebuildProfileList()
        for _, c in ipairs({listHolder:GetChildren()}) do c:Hide(); c:SetParent(nil) end
        for _, r in ipairs({listHolder:GetRegions()}) do r:Hide() end
        local profiles = CT:GetProfiles()
        local active   = CT:GetActiveProfile()
        local ry = 0; local RH = 30
        for _, name in ipairs(profiles) do
            local capName = name
            local isActive = (name == active)
            local row = CreateFrame("Frame", nil, listHolder, "BackdropTemplate")
            row:SetSize(EW, RH - 2); row:SetPoint("TOPLEFT", listHolder, "TOPLEFT", 0, -ry)
            BD(row,
                isActive and 0.06 or 0.08,
                isActive and 0.14 or 0.08,
                isActive and 0.06 or 0.08, 1,
                isActive and 0.20 or 0.18,
                isActive and 0.55 or 0.18,
                isActive and 0.20 or 0.18, 1)

            -- Name label
            local nameLbl = row:CreateFontString(nil, "OVERLAY")
            nameLbl:SetFont("Fonts\\ARIALN.TTF", GFS(), "")
            nameLbl:SetTextColor(isActive and 0.5 or 0.9, isActive and 1 or 0.9, isActive and 0.5 or 0.9, 1)
            nameLbl:SetText(name .. (isActive and "  |cFF558855[active]|r" or ""))
            nameLbl:SetPoint("LEFT", row, "LEFT", 8, 0)
            nameLbl:SetPoint("RIGHT", row, "RIGHT", -130, 0)
            nameLbl:SetJustifyH("LEFT")

            -- Delete button (not for active)
            local delBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
            delBtn:SetSize(28, 20); delBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            BD(delBtn, 0.25, 0.06, 0.06, 1, 0.55, 0.12, 0.12)
            local delL = delBtn:CreateFontString(nil, "OVERLAY")
            delL:SetFont("Fonts\\ARIALN.TTF", 9, "OUTLINE"); delL:SetTextColor(1, 0.4, 0.4, 1)
            delL:SetText("X"); delL:SetAllPoints(); delL:SetJustifyH("CENTER")
            delBtn:SetScript("OnEnter", function() delBtn:SetBackdropColor(0.45, 0.08, 0.08, 1); delL:SetTextColor(1,1,1,1) end)
            delBtn:SetScript("OnLeave", function() BD(delBtn, 0.25, 0.06, 0.06, 1, 0.55, 0.12, 0.12); delL:SetTextColor(1, 0.4, 0.4, 1) end)
            if isActive then
                delBtn:SetAlpha(0.3); delBtn:EnableMouse(false)
            else
                delBtn:SetScript("OnClick", function()
                    local ok, err = CT:DeleteProfile(capName)
                    if not ok then
                        print("|cFFFFD700Fabs Resource Tracker|r: " .. (err or "Cannot delete profile"))
                    else
                        RebuildProfileList(); RefreshActiveBanner()
                    end
                end)
            end

            -- Load / switch button
            local loadBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
            loadBtn:SetSize(56, 20); loadBtn:SetPoint("RIGHT", delBtn, "LEFT", -4, 0)
            BD(loadBtn,
                isActive and 0.06 or 0.08,
                isActive and 0.14 or 0.08,
                isActive and 0.06 or 0.08, 1,
                isActive and 0.24 or 0.22,
                isActive and 0.49 or 0.22,
                isActive and 0.73 or 0.22, 1)
            local loadL = loadBtn:CreateFontString(nil, "OVERLAY")
            loadL:SetFont("Fonts\\ARIALN.TTF", 9, "")
            loadL:SetTextColor(isActive and 0.5 or 0.7, isActive and 1 or 0.9, isActive and 0.5 or 0.9, 1)
            loadL:SetText(isActive and "Loaded" or "Load")
            loadL:SetAllPoints(); loadL:SetJustifyH("CENTER")
            if isActive then
                loadBtn:EnableMouse(false)
            else
                loadBtn:SetScript("OnEnter", function() loadBtn:SetBackdropColor(0.10, 0.22, 0.38, 1); loadL:SetTextColor(1,1,1,1) end)
                loadBtn:SetScript("OnLeave", function()
                    BD(loadBtn, 0.08, 0.08, 0.08, 1, 0.22, 0.22, 0.22); loadL:SetTextColor(0.7, 0.9, 0.9, 1)
                end)
                loadBtn:SetScript("OnClick", function()
                    CT:SwitchProfile(capName)
                    RebuildProfileList(); RefreshActiveBanner()
                end)
            end

            ry = ry + RH
        end
        if #profiles == 0 then
            local hint = listHolder:CreateFontString(nil, "OVERLAY")
            hint:SetFont("Fonts\\ARIALN.TTF", 10, ""); hint:SetTextColor(0.4, 0.4, 0.4, 1)
            hint:SetText("No saved profiles yet."); hint:SetPoint("TOPLEFT", listHolder, "TOPLEFT", 0, 0)
            hint:SetWidth(EW); hint:SetJustifyH("CENTER"); ry = 22
        end
        listHolder:SetHeight(math.max(ry, 10))
    end
    RebuildProfileList(); y = y + listHolder:GetHeight() + 8

    -- ── Create / save profile ────────────────────────────────────────────────
    y = WHeader(page, "Save Current Settings as Profile", y)
    y = WTip(page, "Saves your current windows, icons and settings into a named profile.", ML, y)

    local nameBox = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    nameBox:SetSize(EW - 110, 22); nameBox:SetPoint("TOPLEFT", page, "TOPLEFT", ML, -y)
    nameBox:SetAutoFocus(false); nameBox:SetFont("Fonts\\ARIALN.TTF", GFS(), "")
    nameBox:SetTextColor(0.9, 0.9, 0.9, 1); nameBox:SetTextInsets(6, 6, 0, 0)
    nameBox:SetScript("OnEscapePressed", function(sv) sv:ClearFocus() end)

    local saveBtn = CreateFrame("Button", nil, page, "BackdropTemplate")
    saveBtn:SetSize(102, 22); saveBtn:SetPoint("LEFT", nameBox, "RIGHT", 6, 0)
    BD(saveBtn, 0.06, 0.14, 0.06, 1, 0.20, 0.55, 0.20)
    local saveLbl = saveBtn:CreateFontString(nil, "OVERLAY")
    saveLbl:SetFont("Fonts\\ARIALN.TTF", GFS(), ""); saveLbl:SetTextColor(0.5, 1, 0.5, 1)
    saveLbl:SetText("Save Profile"); saveLbl:SetAllPoints(); saveLbl:SetJustifyH("CENTER")
    saveBtn:SetScript("OnEnter", function() saveBtn:SetBackdropColor(0.10, 0.26, 0.10, 1); saveLbl:SetTextColor(1,1,1,1) end)
    saveBtn:SetScript("OnLeave", function() BD(saveBtn, 0.06, 0.14, 0.06, 1, 0.20, 0.55, 0.20); saveLbl:SetTextColor(0.5, 1, 0.5, 1) end)
    saveBtn:SetScript("OnClick", function()
        local name = nameBox:GetText():match("^%s*(.-)%s*$")
        if not name or name == "" then
            print("|cFFFFD700Fabs Resource Tracker|r: Enter a profile name first.")
            return
        end
        local ok, err = CT:CreateProfile(name)
        if not ok then
            print("|cFFFFD700Fabs Resource Tracker|r: " .. (err or "Error saving profile"))
        else
            nameBox:SetText("")
            BD(saveBtn, 0.06, 0.28, 0.06, 1, 0.20, 0.80, 0.20); saveLbl:SetText("Saved!")
            C_Timer.After(1.5, function()
                if saveBtn and saveBtn.GetObjectType then
                    BD(saveBtn, 0.06, 0.14, 0.06, 1, 0.20, 0.55, 0.20); saveLbl:SetText("Save Profile")
                end
            end)
            RebuildProfileList(); RefreshActiveBanner()
        end
    end)
    nameBox:SetScript("OnEnterPressed", function(sv)
        saveBtn:GetScript("OnClick")()
        sv:ClearFocus()
    end)
    y = y + 30

    -- ── Reset active profile ─────────────────────────────────────────────────
    y = y + 6
    local resetBtn = CreateFrame("Button", nil, page, "BackdropTemplate")
    resetBtn:SetSize(EW, 24); resetBtn:SetPoint("TOPLEFT", page, "TOPLEFT", ML, -y)
    BD(resetBtn, 0.18, 0.06, 0.06, 1, 0.45, 0.12, 0.12)
    local resetLbl = resetBtn:CreateFontString(nil, "OVERLAY")
    resetLbl:SetFont("Fonts\\ARIALN.TTF", GFS(), ""); resetLbl:SetTextColor(1, 0.5, 0.5, 1)
    resetLbl:SetText("Reset Active Profile to Defaults"); resetLbl:SetAllPoints(); resetLbl:SetJustifyH("CENTER")
    resetBtn:SetScript("OnEnter", function() resetBtn:SetBackdropColor(0.35, 0.08, 0.08, 1); resetLbl:SetTextColor(1,1,1,1) end)
    resetBtn:SetScript("OnLeave", function() BD(resetBtn, 0.18, 0.06, 0.06, 1, 0.45, 0.12, 0.12); resetLbl:SetTextColor(1, 0.5, 0.5, 1) end)
    resetBtn:SetScript("OnClick", function()
        CT:ResetProfile()
        RebuildProfileList(); RefreshActiveBanner()
    end)
    y = y + 30

    -- ── Export ───────────────────────────────────────────────────────────────
    y = WHeader(page, "Export Profile", y)
    y = WTip(page, "Exports your active profile as a string you can share or back up.", ML, y)

    local exportBox = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    exportBox:SetSize(EW, 22); exportBox:SetPoint("TOPLEFT", page, "TOPLEFT", ML, -y)
    exportBox:SetAutoFocus(false); exportBox:SetFont("Fonts\\ARIALN.TTF", GFS(), "")
    exportBox:SetTextColor(1, 0.82, 0, 1); exportBox:SetTextInsets(6, 6, 0, 0)
    exportBox:SetScript("OnEscapePressed", function(sv) sv:ClearFocus() end)
    y = y + 28

    local exportBtn = CreateFrame("Button", nil, page, "BackdropTemplate")
    exportBtn:SetSize(EW, 24); exportBtn:SetPoint("TOPLEFT", page, "TOPLEFT", ML, -y)
    BD(exportBtn, 0.08, 0.14, 0.22, 1, 0.24, 0.49, 0.73)
    local exportLbl = exportBtn:CreateFontString(nil, "OVERLAY")
    exportLbl:SetFont("Fonts\\ARIALN.TTF", GFS(), ""); exportLbl:SetTextColor(0.5, 0.8, 1, 1)
    exportLbl:SetText("Generate Export String"); exportLbl:SetAllPoints(); exportLbl:SetJustifyH("CENTER")
    exportBtn:SetScript("OnEnter", function() exportBtn:SetBackdropColor(0.12, 0.22, 0.38, 1); exportLbl:SetTextColor(1,1,1,1) end)
    exportBtn:SetScript("OnLeave", function() BD(exportBtn, 0.08, 0.14, 0.22, 1, 0.24, 0.49, 0.73); exportLbl:SetTextColor(0.5, 0.8, 1, 1) end)
    exportBtn:SetScript("OnClick", function()
        local str = CT:ExportProfile()
        exportBox:SetText(str)
        exportBox:SetFocus(); exportBox:HighlightText()
    end)
    y = y + 30

    -- ── Import ───────────────────────────────────────────────────────────────
    y = WHeader(page, "Import Profile", y)
    y = WTip(page, "Paste an export string and give the imported profile a name.", ML, y)

    local importNameLbl = page:CreateFontString(nil, "OVERLAY")
    importNameLbl:SetFont("Fonts\\ARIALN.TTF", GFS(), ""); importNameLbl:SetTextColor(0.9, 0.9, 0.9, 1)
    importNameLbl:SetText("Profile name:"); importNameLbl:SetPoint("TOPLEFT", page, "TOPLEFT", ML, -y)
    y = y + 16

    local importNameBox = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    importNameBox:SetSize(EW, 22); importNameBox:SetPoint("TOPLEFT", page, "TOPLEFT", ML, -y)
    importNameBox:SetAutoFocus(false); importNameBox:SetFont("Fonts\\ARIALN.TTF", GFS(), "")
    importNameBox:SetTextColor(0.9, 0.9, 0.9, 1); importNameBox:SetTextInsets(6, 6, 0, 0)
    importNameBox:SetScript("OnEscapePressed", function(sv) sv:ClearFocus() end)
    y = y + 28

    local importStrLbl = page:CreateFontString(nil, "OVERLAY")
    importStrLbl:SetFont("Fonts\\ARIALN.TTF", GFS(), ""); importStrLbl:SetTextColor(0.9, 0.9, 0.9, 1)
    importStrLbl:SetText("Import string:"); importStrLbl:SetPoint("TOPLEFT", page, "TOPLEFT", ML, -y)
    y = y + 16

    local importBox = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    importBox:SetSize(EW, 22); importBox:SetPoint("TOPLEFT", page, "TOPLEFT", ML, -y)
    importBox:SetAutoFocus(false); importBox:SetFont("Fonts\\ARIALN.TTF", 9, "")
    importBox:SetTextColor(0.9, 0.9, 0.9, 1); importBox:SetTextInsets(6, 6, 0, 0)
    importBox:SetScript("OnEscapePressed", function(sv) sv:ClearFocus() end)
    y = y + 28

    local importStatLbl = page:CreateFontString(nil, "OVERLAY")
    importStatLbl:SetFont("Fonts\\ARIALN.TTF", 10, ""); importStatLbl:SetTextColor(0.5, 0.5, 0.5, 1)
    importStatLbl:SetText(""); importStatLbl:SetPoint("TOPLEFT", page, "TOPLEFT", ML, -y); importStatLbl:SetWidth(EW)
    local function ShowImportStat(msg)
        importStatLbl:SetText(msg)
        C_Timer.After(4, function() if importStatLbl then importStatLbl:SetText("") end end)
    end
    y = y + 18

    local importBtn = CreateFrame("Button", nil, page, "BackdropTemplate")
    importBtn:SetSize(EW, 24); importBtn:SetPoint("TOPLEFT", page, "TOPLEFT", ML, -y)
    BD(importBtn, 0.08, 0.14, 0.22, 1, 0.24, 0.49, 0.73)
    local importBtnLbl = importBtn:CreateFontString(nil, "OVERLAY")
    importBtnLbl:SetFont("Fonts\\ARIALN.TTF", GFS(), ""); importBtnLbl:SetTextColor(0.5, 0.8, 1, 1)
    importBtnLbl:SetText("Import Profile"); importBtnLbl:SetAllPoints(); importBtnLbl:SetJustifyH("CENTER")
    importBtn:SetScript("OnEnter", function() importBtn:SetBackdropColor(0.12, 0.22, 0.38, 1); importBtnLbl:SetTextColor(1,1,1,1) end)
    importBtn:SetScript("OnLeave", function() BD(importBtn, 0.08, 0.14, 0.22, 1, 0.24, 0.49, 0.73); importBtnLbl:SetTextColor(0.5, 0.8, 1, 1) end)
    importBtn:SetScript("OnClick", function()
        local name = importNameBox:GetText():match("^%s*(.-)%s*$")
        local str  = importBox:GetText():match("^%s*(.-)%s*$")
        if not name or name == "" then
            ShowImportStat("|cFFFF4444Enter a profile name|r"); return
        end
        if not str or str == "" then
            ShowImportStat("|cFFFF4444Paste an import string first|r"); return
        end
        local ok, err = CT:ImportProfile(str, name)
        if not ok then
            ShowImportStat("|cFFFF4444Import failed: " .. (err or "unknown error") .. "|r")
        else
            importBox:SetText(""); importNameBox:SetText("")
            ShowImportStat("|cFF44FF44Imported as profile: " .. name .. "|r")
            BD(importBtn, 0.06, 0.28, 0.06, 1, 0.20, 0.80, 0.20); importBtnLbl:SetText("Imported!")
            C_Timer.After(1.5, function()
                if importBtn and importBtn.GetObjectType then
                    BD(importBtn, 0.08, 0.14, 0.22, 1, 0.24, 0.49, 0.73); importBtnLbl:SetText("Import Profile")
                end
            end)
            RebuildProfileList(); RefreshActiveBanner()
        end
    end)
    importBox:SetScript("OnEnterPressed", function(sv)
        importBtn:GetScript("OnClick")()
        sv:ClearFocus()
    end)
end
