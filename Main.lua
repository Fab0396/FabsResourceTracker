-- FabsResourceTracker / Main.lua
CT = CT or {}

local HEALTHSTONE_ID         = 5512
local DEMONIC_HEALTHSTONE_ID = 224464
local PACT_OF_GLUTTONY_SPELL = 386689

local GEM_GOLD   = {1.00, 0.85, 0.00, 1}
local GEM_SILVER = {0.78, 0.88, 1.00, 1}

-- Equipment slot number → display name
local SLOT_NAMES = {
    [1]="Head",[2]="Neck",[3]="Shoulders",[15]="Back",[5]="Chest",
    [9]="Wrist",[10]="Hands",[6]="Belt",[8]="Boots",
    [11]="Ring 1",[12]="Ring 2",[13]="Trinket 1",[14]="Trinket 2",
    [16]="Main-Hand",[17]="Off-Hand",
}

-- ---------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------
local function DB()         return ConsumableTrackerDB end
local function GetCount(id) return C_Item.GetItemCount(id,false,true) or 0 end
local function GetCD(id)
    local s,d,enable=C_Item.GetItemCooldown(id)
    s=s or 0; d=d or 0
    -- enable=0 means cooldown is suppressed (GCD bleedthrough) — treat as no CD
    if enable==0 then return 0,0 end
    return s,d
end
local function IsOnCD(id)
    local s,d=GetCD(id); return d>0 and s>0 and (s+d)-GetTime()>0
end

-- ---------------------------------------------------------------
-- Masque (MSQ) integration for icon skinning
-- Masque is the standard WoW icon skinning library used by BCM, ElvUI etc.
-- ---------------------------------------------------------------
local MSQ = LibStub and LibStub("Masque", true)
local MSQGroup = MSQ and MSQ:Group("Fabs Resource Tracker", "Icons")

local function RegisterWithMasque(s)
    if not MSQGroup then return end
    MSQGroup:AddButton(s.frame, {
        Icon     = s.iconTex,
        Cooldown = s.cdFrame,
        Normal   = false,  -- no normal texture (we draw our own border)
        Pushed   = false,
        Checked  = false,
        Border   = false,
        Flash    = false,
        Highlight = false,
        Count    = s.countText,
    })
end

local function GetSpellTex(id)
    -- GetSpellInfo returns the icon as a FileID in modern WoW.
    -- SetTexture with a FileID bypasses Interface\Icons overrides.
    -- Using select(3, GetSpellInfo(id)) gives us the same FileID but
    -- we pass it to SetTexture — WoW resolves it the same way.
    -- The icon pack override only works via path strings, which we can't
    -- reconstruct from a FileID in Lua. So we pass the FileID and let
    -- Masque handle skinning for users who want custom icons.
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, t = pcall(C_Spell.GetSpellTexture, id)
        if ok and t then return t end
    end
    if GetSpellTexture then
        local ok, t = pcall(GetSpellTexture, id)
        if ok and t then return t end
    end
    -- Fallback: pull from GetSpellInfo
    if GetSpellInfo then
        local ok, name, _, icon = pcall(GetSpellInfo, id)
        if ok and icon then return icon end
    end
    return nil
end
local function GetSpellCDInfo(id)
    -- Wrap everything in pcall: tainted secret values in combat cause errors
    -- regardless of tonumber/+0 tricks when the value is a tainted nil.
    -- Graceful fallback to 0,0 means no cooldown swipe shown, which is fine.
    local ok,s,d=pcall(function()
        if GetSpellCooldown then
            local rs,rd=GetSpellCooldown(id)
            return (rs or 0)+0, (rd or 0)+0
        end
        if C_Spell and C_Spell.GetSpellCooldown then
            local info=C_Spell.GetSpellCooldown(id)
            if info then
                return (info.startTime or 0)+0, (info.duration or 0)+0
            end
        end
        return 0,0
    end)
    if ok then return s or 0, d or 0 end
    return 0,0
end
local function GetSpellChargeInfo(id)
    if C_Spell and C_Spell.GetSpellCharges then
        local info=C_Spell.GetSpellCharges(id)
        if info then return info.currentCharges,info.maxCharges end
    end
    if GetSpellCharges then return GetSpellCharges(id) end
    return nil,nil
end
local function IsSpellKnownAny(id)
    if IsPlayerSpell then local ok,r=pcall(IsPlayerSpell,id); if ok and r then return true end end
    if C_SpellBook and C_SpellBook.IsSpellKnown then local ok,r=pcall(C_SpellBook.IsSpellKnown,id); if ok and r then return true end end
    if IsSpellKnown then local ok,r=pcall(IsSpellKnown,id); if ok and r then return true end end
    return false
end

-- Alternate spell IDs for racials that exist under multiple records in the DB
-- Maps primary spellId → list of alternates to also check
local RACIAL_ALT_IDS = {
    [121093] = {28880,59542,59543,59544,59545,59547,59548,370626,416250}, -- Gift of the Naaru
    [20572]  = {33697,33702},                                              -- Blood Fury
    [50613]  = {25046,28730,69179,80483,129597,155145,202719,232633},      -- Arcane Torrent
}

-- Returns the best known spellId: primary or first known alternate
local function BestKnownSpellId(id)
    if IsSpellKnownAny(id) then return id end
    local alts=RACIAL_ALT_IDS[id]
    if alts then
        for _,alt in ipairs(alts) do
            if IsSpellKnownAny(alt) then return alt end
        end
    end
    return nil  -- not known under any variant
end
local function ResolveFrame(name)
    if not name or name=="" or name=="UIParent" then return UIParent end
    return _G[name] or UIParent
end
local function GetTex(itemId)
    local tex=select(10,GetItemInfo(itemId))
    if not tex then C_Item.RequestLoadItemDataByID(itemId) end
    return tex
end

local function ItemHasOnUse(itemId)
    if not itemId or itemId==0 then return false end
    local spellName,spellId=C_Item.GetItemSpell(itemId)
    return (spellId and spellId>0) or (spellName and spellName~="")
end
local function FormatCD(start,dur)
    if not dur or not start or dur<=0 or start<=0 then return "" end
    local r=(start+dur)-GetTime(); if r<=0 then return "" end
    if r>=3600 then return string.format("%dh", math.floor(r/3600+0.5)) end
    if r>=120  then return string.format("%dm", math.floor(r/60+0.5))   end
    if r>=60   then
        local mins=math.floor(r/60); local secs=math.floor(r-mins*60)
        return string.format("%d:%02d", mins, secs)
    end
    return string.format("%d", math.ceil(r))
end
local function ActiveItemID()
    if select(2,UnitClass("player"))=="WARLOCK"
       and C_SpellBook.IsSpellKnown(PACT_OF_GLUTTONY_SPELL) then
        return DEMONIC_HEALTHSTONE_ID
    end
    return HEALTHSTONE_ID
end
local function ResolveGroup(slot)
    local fallback=nil
    for pi=1,4 do
        local id=slot["p"..pi]
        if id and id>0 then
            if not fallback then fallback=id end
            if GetCount(id)>0 then return id end
        end
    end
    return fallback
end

-- ---------------------------------------------------------------
-- Defaults — split into global (non-window) and per-window
-- ---------------------------------------------------------------
local GLOBAL_DEFAULTS = {
    GUIFontSize    = 11,
    ShowTooltips   = true,
    MinimapAngle   = 225,
    MinimapHidden  = false,
    EquipBlacklist = {},
    SectionOrder   = {"racials","defensives","consumables","gear"},
    Windows        = {},
    BuffWindow     = {
        Enabled       = true,
        X             = 0,
        Y             = -100,
        AnchorPoint   = "TOP",
        AnchorToFrame = "UIParent",
        AnchorToPoint = "TOP",
        IconW         = 44,
        IconH         = 44,
        Spacing       = 4,
        GrowDir       = "RIGHT",
        Locked        = false,
        ShowLabel     = true,
        ShowSwipe     = true,
        SwipeAlpha    = 65,
        SwipeInverse  = false,
        CDTextShow    = true,
        CDTextSize    = 14,
        CDTextFont    = "",
        CDTextFlag    = "OUTLINE",
        CDTextAnchor  = "CENTER",
        CDTextX       = 0,
        CDTextY       = 0,
        LabelPos      = "TOP",
        TrackedItems  = {},
        IconStrata    = "HIGH",
        SortMode      = "normal",
        MaxIconsPerRow   = 0,
        WrapDirection    = "DOWN",
        WrapGrowDirection= "RIGHT",
        WrapAnchor       = "FIRST",
        RowSpacing       = 4,
        MidnightAutoTrackEnabled = false,
        MidnightAutoTrack        = {},
    },
}

CT.MIDNIGHT_S1_ONUSE = {
    [249197] = {label="Light Company Guidon",         cooldown=90,  duration=15},
    [249340] = {label="Wraps of Cosmic Madness",      cooldown=120, duration=2},
    [249974] = {label="Vaelgor's Final Stare",        cooldown=90,  duration=15},
    [249345] = {label="Ranger-Captain's Insignia",    cooldown=180, duration=0},
    [249808] = {label="Litany of Lightblind Wrath",   cooldown=90,  duration=30},
    [249339] = {label="Gloom-Spattered Dreadscale",   cooldown=120, duration=0},
    [250144] = {label="Emberwing Feather",            cooldown=120, duration=15},
    [250226] = {label="Latch's Crooked Hook",         cooldown=90,  duration=0},
    [193719] = {label="Dragon Games Equipment",       cooldown=120, duration=0},
    [193701] = {label="Algeth'ar Puzzle Box",         cooldown=120, duration=20},
    [50259]  = {label="Nevermelting Ice Crystal",     cooldown=180, duration=20},
    [151307] = {label="Void Stalker's Contract",      cooldown=90,  duration=0},
    [193718] = {label="Emerald Coach's Whistle",      cooldown=1,   duration=10},
    [151340] = {label="Echo of L'ura",                cooldown=180, duration=45},
    [252411] = {label="Radiant Sunstone",             cooldown=120, duration=20},
    [252421] = {label="Rotting Globule",              cooldown=120, duration=15},
    [151312] = {label="Ampoule of Pure Void",         cooldown=90,  duration=10},
    [252418] = {label="Solar Core Igniter",           cooldown=90,  duration=15},
    [249806] = {label="Radiant Plume",                cooldown=300, duration=60},
    [260235] = {label="Umbral Plume",                 cooldown=300, duration=60},
    [251786] = {label="Ever-Collapsing Void Fissure", cooldown=120, duration=10},
    [251787] = {label="Sealed Chaos Urn",             cooldown=120, duration=20},
    [255326] = {label="Aspirant's Badge of Ferocity", cooldown=60,  duration=15},
    [255613] = {label="Gladiator's Badge of Ferocity",cooldown=60,  duration=15},
}

local WIN_DEFAULTS = {
    Name             = "Window",
    Locked           = false,
    AnchorPoint      = "CENTER",
    AnchorToFrame    = "UIParent",
    AnchorToPoint    = "CENTER",
    X                = 0,
    Y                = -220,
    IconWidth        = 44,
    IconHeight       = 44,
    IconZoom         = 0,
    KeepAspectRatio  = true,
    IconSkin         = "none",
    IconStrata       = "MEDIUM",
    ShowBorder       = true,
    BorderSize       = 1,
    BorderColor      = {0,0,0,1},
    BorderStyle      = "solid",
    HideGCD          = true,
    SwipeAlpha       = 80,
    DesatOnCooldown  = false,
    ShowQualityGem   = true,
    GemSize          = 14,
    GemAnchor        = "TOPLEFT",
    GemShape         = "circle",
    ShowCount        = true,
    CountTextSize    = 12,
    CountAnchor      = "BOTTOMRIGHT",
    CountTextX       = -2,
    CountTextY       = 2,
    ShowCooldownText = true,
    CooldownTextSize = 15,
    CooldownTextX    = 0,
    CooldownTextY    = 0,
    CooldownAnchor   = "CENTER",
    ScaleCDTextByIcon = true,
    FontPath         = "Fonts\\FRIZQT__.TTF",
    FontFlag         = "OUTLINE",
    FontShadow       = 1,
    GrowDirection    = "RIGHT",
    GrowSpacing      = 4,
    MaxIconsPerRow   = 0,
    WrapDirection    = "DOWN",
    WrapGrowDirection= "RIGHT",
    WrapAnchor       = "FIRST",
    RowSpacing       = 4,
    Slots            = {},
}

-- Apply WIN_DEFAULTS to a window definition (fills missing keys)
local function EnsureWinDefaults(w)
    if not w then return end
    for k,v in pairs(WIN_DEFAULTS) do
        if w[k]==nil then
            if type(v)=="table" then
                w[k]={}; for tk,tv in pairs(v) do w[k][tk]=tv end
            else w[k]=v end
        end
    end
end

local GROW = {
    RIGHT={myPoint="LEFT",  toPoint="RIGHT", ox= 1,oy=0},
    LEFT ={myPoint="RIGHT", toPoint="LEFT",  ox=-1,oy=0},
    UP   ={myPoint="BOTTOM",toPoint="TOP",   ox=0, oy=1},
    DOWN ={myPoint="TOP",   toPoint="BOTTOM",ox=0, oy=-1},
}

-- windowStates[winIdx] = {structs={}, anchorFrame=nil}
local windowStates = {}
-- flat union of all structs across all windows (for global ops)
local iconStructs  = {}

-- BCM's pixel-perfect sizing for crisp borders at any resolution/scale
local function PixelPerfect(value)
    if not value then return 0 end
    local _, screenHeight = GetPhysicalScreenSize()
    local uiScale = UIParent:GetEffectiveScale()
    local pixelSize = 768 / screenHeight / uiScale
    return pixelSize * math.floor(value / pixelSize + 0.5333)
end
local function MakeIconStruct(name,parent)
    local f=CreateFrame("Frame",name,parent or UIParent,"BackdropTemplate")
    f:SetFrameStrata("MEDIUM"); f:SetFrameLevel(5); f:SetClampedToScreen(false)

    local iconTex=f:CreateTexture(nil,"BACKGROUND")
    iconTex:SetAllPoints(f)
    -- BCM default: IconZoom=0.1, applied as zoom*0.5=0.05 → SetTexCoord(0.05,0.95,0.05,0.95)
    iconTex:SetTexCoord(0, 1, 0, 1)

    local cdF=CreateFrame("Cooldown",nil,f,"CooldownFrameTemplate")
    cdF:SetAllPoints(f); cdF:SetFrameLevel(6)
    cdF:SetDrawEdge(false); cdF:SetDrawSwipe(true)
    cdF:SetDrawBling(false)
    cdF:SetSwipeTexture("Interface\\Buttons\\WHITE8X8")
    cdF:SetSwipeColor(0,0,0,0.8)
    cdF:SetHideCountdownNumbers(true)  -- hide Blizzard's numbers, we render our own
    cdF:Clear()

    local skinF=CreateFrame("Frame",nil,f)
    skinF:SetAllPoints(f); skinF:SetFrameLevel(7)
    local qSkinTex=skinF:CreateTexture(nil,"OVERLAY")
    qSkinTex:SetAllPoints(skinF); qSkinTex:Hide()

    local textF=CreateFrame("Frame",nil,f)
    textF:SetAllPoints(f); textF:SetFrameLevel(20)

    local cntT=textF:CreateFontString(nil,"OVERLAY")
    cntT:SetFont(STANDARD_TEXT_FONT,12,"OUTLINE"); cntT:SetTextColor(1,1,1,1); cntT:SetText("")
    local cdT=textF:CreateFontString(nil,"OVERLAY")
    cdT:SetFont(STANDARD_TEXT_FONT,13,"OUTLINE"); cdT:SetTextColor(1,1,1,1); cdT:SetText("")

    local qGemBg=textF:CreateTexture(nil,"OVERLAY")
    qGemBg:SetColorTexture(0,0,0,0.70); qGemBg:SetPoint("TOPLEFT",f,"TOPLEFT",1,-1); qGemBg:Hide()
    local qGemTex=textF:CreateTexture(nil,"OVERLAY")
    qGemTex:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
    qGemTex:SetBlendMode("ADD"); qGemTex:SetPoint("TOPLEFT",f,"TOPLEFT",2,-2); qGemTex:Hide()
    local qGemStar=textF:CreateTexture(nil,"OVERLAY")
    qGemStar:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
    qGemStar:SetBlendMode("ADD"); qGemStar:SetPoint("TOPLEFT",f,"TOPLEFT",2,-2); qGemStar:Hide()
    local qGemLbl=textF:CreateFontString(nil,"OVERLAY")
    qGemLbl:SetFont(STANDARD_TEXT_FONT,8,"OUTLINE"); qGemLbl:SetTextColor(1,0.82,0,1); qGemLbl:SetText("F")
    qGemLbl:SetPoint("TOPLEFT",f,"TOPLEFT",2,-2); qGemLbl:Hide()

    return {
        frame=f, iconTex=iconTex,
        cdFrame=cdF, skinFrame=skinF, qSkinTex=qSkinTex,
        textFrame=textF, countText=cntT, cdText=cdT,
        qGemBg=qGemBg, qGemTex=qGemTex, qGemStar=qGemStar, qGemLbl=qGemLbl,
        ticker=nil, itemId=nil, spellId=nil, equipSlot=nil,
        isMain=false, slotRef=nil,
    }
end

-- ---------------------------------------------------------------
-- Apply helpers
-- ---------------------------------------------------------------
local function ApplySkinToStruct(s)
    local skin=DB().IconSkin or "none"
    s.qSkinTex:ClearAllPoints()
    if skin=="none" then s.qSkinTex:Hide(); return
    elseif skin=="actionbutton" then
        s.qSkinTex:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        s.qSkinTex:SetBlendMode("BLEND"); s.qSkinTex:SetAlpha(1.0)
        s.qSkinTex:SetPoint("TOPLEFT",s.frame,"TOPLEFT",-6,6)
        s.qSkinTex:SetPoint("BOTTOMRIGHT",s.frame,"BOTTOMRIGHT",6,-6)
    elseif skin=="gloss" then
        s.qSkinTex:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        s.qSkinTex:SetBlendMode("ADD"); s.qSkinTex:SetAlpha(0.20)
        s.qSkinTex:SetAllPoints(s.skinFrame)
    elseif skin=="vignette" then
        s.qSkinTex:SetTexture("Interface\\Buttons\\UI-Quickslot")
        s.qSkinTex:SetBlendMode("BLEND"); s.qSkinTex:SetAlpha(0.80)
        s.qSkinTex:SetPoint("TOPLEFT",s.frame,"TOPLEFT",-6,6)
        s.qSkinTex:SetPoint("BOTTOMRIGHT",s.frame,"BOTTOMRIGHT",6,-6)
    end
    s.qSkinTex:Show()
end

local _STRATA_UP = {
    BACKGROUND="LOW", LOW="MEDIUM", MEDIUM="HIGH",
    HIGH="DIALOG", DIALOG="FULLSCREEN", FULLSCREEN="TOOLTIP",
    FULLSCREEN_DIALOG="TOOLTIP", TOOLTIP="TOOLTIP",
}
local function ApplyStrataToStruct(s)
    local db=s.winDef or DB().Windows and DB().Windows[1] or DB()
    local strata=db.IconStrata or "MEDIUM"
    s.frame:SetFrameStrata(strata)
    s.textFrame:SetFrameStrata(_STRATA_UP[strata] or strata)
    s.textFrame:SetFrameLevel(s.frame:GetFrameLevel() + 1)
end

local BORDER_STYLES = {
    none          = "none",
    solid         = nil,  -- uses colour lines, no edgeFile
    tooltip       = "Interface\\Tooltips\\UI-Tooltip-Border",
    achievement   = "Interface\\AchievementFrame\\UI-Achievement-WoodBorder",
    chat          = "Interface\\ChatFrame\\ChatFrameBackground",
    dialog        = "Interface\\DialogFrame\\UI-DialogBox-Border",
    glow          = "Interface\\Glues\\Common\\TextPanel-Border",
    party         = "Interface\\PartyFrame\\UI-Party-Border",
    parchment     = "Interface\\QuestFrame\\QuestBG",
}

local function ApplyBorderToStruct(s)
    local db=s.winDef or DB().Windows[1] or DB(); local f=s.frame
    local style = db.BorderStyle or "solid"
    local bc = db.BorderColor or {0,0,0,1}
    local r,g,b,a = bc[1],bc[2],bc[3],bc[4] or 1
    local bs = math.max(1, db.BorderSize or 1)
    local px = PixelPerfect(bs)

    if not s._borders then
        local function MakeLine() return f:CreateTexture(nil,"OVERLAY") end
        s._borders = {MakeLine(), MakeLine(), MakeLine(), MakeLine()}
    end
    local top,bot,lft,rgt = s._borders[1],s._borders[2],s._borders[3],s._borders[4]

    if db.ShowBorder and style ~= "none" then
        if style == "solid" then
            -- Hide backdrop, use 4 pixel-perfect colour lines
            if f.SetBackdrop then f:SetBackdrop(nil) end
            top:SetColorTexture(r,g,b,a);  top:SetHeight(px)
            top:SetPoint("TOPLEFT",f,"TOPLEFT",0,0); top:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,0)
            bot:SetColorTexture(r,g,b,a);  bot:SetHeight(px)
            bot:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",0,0); bot:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",0,0)
            lft:SetColorTexture(r,g,b,a);  lft:SetWidth(px)
            lft:SetPoint("TOPLEFT",f,"TOPLEFT",0,0); lft:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",0,0)
            rgt:SetColorTexture(r,g,b,a);  rgt:SetWidth(px)
            rgt:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,0); rgt:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",0,0)
            for _,ln in ipairs(s._borders) do ln:Show() end
            s.iconTex:ClearAllPoints()
            s.iconTex:SetPoint("TOPLEFT",f,"TOPLEFT",px,-px)
            s.iconTex:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-px,px)
        else
            -- Hide colour lines, use WoW edge texture via backdrop
            for _,ln in ipairs(s._borders) do ln:Hide() end
            local edgeFile = BORDER_STYLES[style] or BORDER_STYLES.tooltip
            local edgeSize = math.max(4, bs * 4)
            if f.SetBackdrop then
                f:SetBackdrop({edgeFile=edgeFile, edgeSize=edgeSize})
                f:SetBackdropBorderColor(r,g,b,a)
            end
            local inset = math.floor(edgeSize * 0.3)
            s.iconTex:ClearAllPoints()
            s.iconTex:SetPoint("TOPLEFT",f,"TOPLEFT",inset,-inset)
            s.iconTex:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-inset,inset)
        end
    else
        for _,ln in ipairs(s._borders) do ln:Hide() end
        if f.SetBackdrop then f:SetBackdrop(nil) end
        s.iconTex:ClearAllPoints(); s.iconTex:SetAllPoints(f)
    end
    s.cdFrame:SetAllPoints(s.iconTex)
    s.cdFrame:SetSwipeColor(0,0,0,(db.SwipeAlpha or 80)/100.0)
end

local function ApplyZoomToStruct(s)
    local db=s.winDef or DB().Windows[1] or DB()
    -- Slider 0 = no zoom (full raw icon), slider 20 = 0.20 crop from each edge
    local z=math.max(0,math.min(0.45,(db.IconZoom or 0)/100))
    local w,h=db.IconWidth or 44,db.IconHeight or 44
    local l,r,t,b=z,1-z,z,1-z
    if db.KeepAspectRatio and math.abs(w-h)>0.05 then
        if w>h then local sp=(1-2*z)*(h/w); l=0.5-sp*0.5; r=0.5+sp*0.5
        else         local sp=(1-2*z)*(w/h); t=0.5-sp*0.5; b=0.5+sp*0.5 end
    end
    s.iconTex:SetTexCoord(l,r,t,b)
end

local function ApplyTextToStruct(s)
    local db=s.winDef or DB().Windows[1] or DB(); local font=db.FontPath or STANDARD_TEXT_FONT; local flag=db.FontFlag or "OUTLINE"; local f=s.frame
    local iconSize = math.max(db.IconWidth or 44, db.IconHeight or 44)
    local scale = db.ScaleCDTextByIcon and (iconSize / 44.0) or 1.0
    local shadow = db.FontShadow

    local function ApplyFont(fs, size)
        if not fs then return end
        fs:SetFont(font, math.max(6, math.floor(size * scale + 0.5)), flag)
        if shadow and shadow > 0 then
            fs:SetShadowColor(0,0,0,1)
            fs:SetShadowOffset(shadow, -shadow)
        else
            fs:SetShadowColor(0,0,0,0)
            fs:SetShadowOffset(0,0)
        end
    end

    ApplyFont(s.countText, db.CountTextSize or 12)
    s.countText:SetShown(db.ShowCount~=false)
    s.countText:ClearAllPoints()
    s.countText:SetPoint(db.CountAnchor or "BOTTOMRIGHT",f,db.CountAnchor or "BOTTOMRIGHT",db.CountTextX or -2,db.CountTextY or 2)

    ApplyFont(s.cdText, db.CooldownTextSize or 15)
    s.cdText:SetShown(db.ShowCooldownText~=false)
    s.cdText:ClearAllPoints()
    s.cdText:SetPoint(db.CooldownAnchor or "CENTER",f,db.CooldownAnchor or "CENTER",db.CooldownTextX or 0,db.CooldownTextY or 0)
end

local function GemAnchorOffsets(anchor)
    if anchor=="TOPRIGHT"    then return "TOPRIGHT",    -1,-1,-2,-2 end
    if anchor=="BOTTOMLEFT"  then return "BOTTOMLEFT",   1, 1, 2, 2 end
    if anchor=="BOTTOMRIGHT" then return "BOTTOMRIGHT", -1, 1,-2, 2 end
    return "TOPLEFT",1,-1,2,-2
end

local function ApplyAllToStruct(s)
    ApplySkinToStruct(s); ApplyStrataToStruct(s)
    ApplyBorderToStruct(s); ApplyTextToStruct(s); ApplyZoomToStruct(s)
end

-- ---------------------------------------------------------------
-- Update: item icon (healthstone, group, specific item)
-- ---------------------------------------------------------------
local function UpdateStruct(s)
    if not s or not s.frame or not s.itemId then return end
    local db=s.winDef or DB().Windows[1] or DB(); local itemId=s.itemId
    local count=GetCount(itemId)
    local tex=GetTex(itemId)
    if tex and tex~=s._lastTex then s.iconTex:SetTexture(tex); ApplyZoomToStruct(s); s._lastTex=tex end
    local start,dur=GetCD(itemId)
    -- Filter GCD (<=1.5s) if HideGCD is enabled
    if dur>0 and dur<=1.5 and db.HideGCD~=false then start=0; dur=0 end
    local onCD=dur>0 and start>0 and (start+dur)-GetTime()>0
    local desat=(count==0) or (onCD and db.DesatOnCooldown)
    if desat~=s._lastDesat then s.iconTex:SetDesaturated(desat and true or false); s._lastDesat=desat end
    -- Only call SetCooldown when start/dur actually change, to avoid resetting the swipe animation
    if dur~=s._lastCDDur or start~=s._lastCDStart then
        if dur>0 and start>0 then s.cdFrame:SetCooldown(start,dur) else s.cdFrame:Clear() end
        s._lastCDStart=start; s._lastCDDur=dur
    end
    local countStr = count==0 and "0" or tostring(count)
    if countStr~=s._lastCount then
        s.countText:SetText(countStr)
        s.countText:SetTextColor(count==0 and 1 or 1, count==0 and 0.3 or 1, count==0 and 0.3 or 1, 1)
        s._lastCount=countStr
    end

    if s.isMain then
        s.qGemTex:Hide(); s.qGemBg:Hide(); s.qGemStar:Hide(); s.qGemLbl:Hide(); return
    end
    -- Hide gem if we have none of any tracked item in bags
    local hasAny = (count > 0)
    if not hasAny and s.slotRef and s.slotRef.type=="group" then
        -- Check if any priority slot has items
        for pi=1,4 do
            local pid=s.slotRef["p"..pi]
            if pid and pid>0 and GetCount(pid)>0 then hasAny=true; break end
        end
    end
    if not hasAny then
        s.qGemTex:Hide(); s.qGemBg:Hide(); s.qGemStar:Hide(); s.qGemLbl:Hide()
        -- Still apply border if set
        if s.winDef and s.winDef.ShowBorder then
            local slot=s.slotRef
            local meta=slot and slot.meta and slot.meta[itemId]
            if meta and meta.borderColor then
                local bc=meta.borderColor; s.frame:SetBackdropBorderColor(bc[1],bc[2],bc[3],bc[4] or 1)
            end
        end
        return
    end
    local slot=s.slotRef
    local meta=slot and slot.meta and slot.meta[itemId]
    local gc=meta and meta.gemColor or "none"
    if db.ShowQualityGem and gc~="none" then
        local sz=math.max(6,math.min(24,db.GemSize or 14))
        local shape=db.GemShape or "circle"
        local pt,bgX,bgY,dotX,dotY=GemAnchorOffsets(db.GemAnchor or "TOPLEFT")
        if gc=="F" then
            s.qGemTex:Hide(); s.qGemBg:Hide(); s.qGemStar:Hide()
            s.qGemLbl:ClearAllPoints(); s.qGemLbl:SetPoint(pt,s.frame,pt,dotX,dotY)
            s.qGemLbl:SetFont(STANDARD_TEXT_FONT,math.max(6,sz+2),"OUTLINE"); s.qGemLbl:Show()
        elseif shape=="star" then
            s.qGemTex:Hide(); s.qGemBg:Hide(); s.qGemLbl:Hide()
            s.qGemStar:SetSize(sz+6,sz+6); s.qGemStar:ClearAllPoints()
            s.qGemStar:SetPoint(pt,s.frame,pt,dotX,dotY)
            if gc=="gold" then s.qGemStar:SetDesaturated(false); s.qGemStar:SetVertexColor(GEM_GOLD[1],GEM_GOLD[2],GEM_GOLD[3],1)
            else s.qGemStar:SetDesaturated(true); s.qGemStar:SetVertexColor(GEM_SILVER[1],GEM_SILVER[2],GEM_SILVER[3],1) end
            s.qGemStar:Show()
        else
            s.qGemStar:Hide(); s.qGemLbl:Hide()
            s.qGemBg:SetSize(sz+4,sz+4); s.qGemBg:ClearAllPoints(); s.qGemBg:SetPoint(pt,s.frame,pt,bgX,bgY)
            s.qGemTex:SetSize(sz,sz); s.qGemTex:ClearAllPoints(); s.qGemTex:SetPoint(pt,s.frame,pt,dotX,dotY)
            if gc=="gold" then s.qGemTex:SetVertexColor(GEM_GOLD[1],GEM_GOLD[2],GEM_GOLD[3],1)
            else s.qGemTex:SetVertexColor(GEM_SILVER[1],GEM_SILVER[2],GEM_SILVER[3],1) end
            s.qGemBg:Show(); s.qGemTex:Show()
        end
    else
        s.qGemTex:Hide(); s.qGemBg:Hide(); s.qGemStar:Hide(); s.qGemLbl:Hide()
    end
    if db.ShowBorder and meta and meta.borderColor then
        local bc=meta.borderColor; s.frame:SetBackdropBorderColor(bc[1],bc[2],bc[3],bc[4] or 1)
    end
end

local function UpdateStructCDText(s)
    if not s or not s.cdText or not s.itemId then return end
    if DB().ShowCooldownText==false then s.cdText:SetText(""); return end
    s.cdText:SetText(FormatCD(GetCD(s.itemId)))
end

-- ---------------------------------------------------------------
-- Buff Window — persistent container for custom timer icons
-- ---------------------------------------------------------------
local function SetBD(f,r,g,b,a,er,eg,eb,ea)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    f:SetBackdropColor(r or 0,g or 0,b or 0,a or 1)
    f:SetBackdropBorderColor(er or 0,eg or 0,eb or 0,ea or 1)
end

local _buffWin   = nil   -- container frame
local _buffSlots = {}    -- {frame, endTime, duration, ticker, key, slot}
local _dragBox   = nil   -- visible placeholder shown when unlocked and no icons active

local function GetBuffWinDB()
    local d = ConsumableTrackerDB
    if not d.BuffWindow then d.BuffWindow = {} end
    local bw = d.BuffWindow
    for k,v in pairs(GLOBAL_DEFAULTS.BuffWindow) do if bw[k]==nil then bw[k]=v end end
    return bw
end

local function ApplyBuffIconStyle(entry)
    local bw = GetBuffWinDB()
    local f  = entry.frame
    local iw = bw.IconW or 44
    local ih = bw.IconH or 44
    f:SetSize(iw, ih)
    f:SetFrameStrata(bw.IconStrata or "HIGH")

    -- Border — read from the active window's settings (use window 1 as reference)
    local d = ConsumableTrackerDB
    local windb = d and d.Windows and d.Windows[1] or {}
    local style = windb.BorderStyle or "solid"
    local showBorder = windb.ShowBorder ~= false and style ~= "none"
    local bc = windb.BorderColor or {0,0,0,1}
    local r,g,b,a = bc[1],bc[2],bc[3],bc[4] or 1
    local bs = math.max(1, windb.BorderSize or 1)

    if not f._borders then
        local function MakeLine() return f:CreateTexture(nil,"OVERLAY") end
        f._borders = {MakeLine(), MakeLine(), MakeLine(), MakeLine()}
    end
    local top,bot,lft,rgt = f._borders[1],f._borders[2],f._borders[3],f._borders[4]

    local inset = 0
    if showBorder then
        if style == "solid" then
            if f.SetBackdrop then f:SetBackdrop(nil) end
            for _,ln in ipairs(f._borders) do ln:Show() end
            top:SetColorTexture(r,g,b,a); top:SetHeight(bs)
            top:SetPoint("TOPLEFT",f,"TOPLEFT",0,0); top:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,0)
            bot:SetColorTexture(r,g,b,a); bot:SetHeight(bs)
            bot:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",0,0); bot:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",0,0)
            lft:SetColorTexture(r,g,b,a); lft:SetWidth(bs)
            lft:SetPoint("TOPLEFT",f,"TOPLEFT",0,0); lft:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",0,0)
            rgt:SetColorTexture(r,g,b,a); rgt:SetWidth(bs)
            rgt:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,0); rgt:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",0,0)
            inset = bs
        else
            for _,ln in ipairs(f._borders) do ln:Hide() end
            local edgePath = BORDER_STYLES[style] or BORDER_STYLES.tooltip
            local edgeSize = math.max(4, bs * 4)
            if f.SetBackdrop then
                f:SetBackdrop({edgeFile=edgePath, edgeSize=edgeSize})
                f:SetBackdropBorderColor(r,g,b,a)
            end
            inset = math.floor(edgeSize * 0.3)
        end
    else
        for _,ln in ipairs(f._borders) do ln:Hide() end
        if f.SetBackdrop then f:SetBackdrop(nil) end
    end

    -- Icon inset by border
    f._ico:ClearAllPoints()
    f._ico:SetPoint("TOPLEFT",f,"TOPLEFT",inset,-inset)
    f._ico:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-inset,inset)

    -- Label position: top or bottom
    f._lbl:SetShown(bw.ShowLabel ~= false)
    f._lbl:SetWidth(iw); f._lbl:ClearAllPoints()
    if bw.LabelPos == "BOTTOM" then
        f._lbl:SetPoint("TOP",f,"BOTTOM",0,-2)
    else
        f._lbl:SetPoint("BOTTOM",f,"TOP",0,2)
    end
    f._lbl:SetJustifyH("CENTER")
    -- CD text on cdFrame (always above swipe)
    if f._cdFrame then f._cdFrame:SetAllPoints(f) end
    f._cd:SetShown(bw.CDTextShow ~= false)
    local font = (bw.CDTextFont and bw.CDTextFont ~= "") and bw.CDTextFont or STANDARD_TEXT_FONT
    f._cd:SetFont(font, bw.CDTextSize or 14, bw.CDTextFlag or "OUTLINE")
    f._cd:ClearAllPoints()
    local anchor = bw.CDTextAnchor or "CENTER"
    local parent = f._cdFrame or f
    f._cd:SetPoint(anchor, parent, anchor, bw.CDTextX or 0, bw.CDTextY or 0)
    -- Swipe
    if bw.ShowSwipe ~= false then
        f._swipe:SetDrawSwipe(true)
        f._swipe:SetSwipeColor(0,0,0,(bw.SwipeAlpha or 65)/100)
        f._swipe:SetReverse(bw.SwipeInverse or false)
    else
        f._swipe:SetDrawSwipe(false)
    end
end

local function LayoutBuffIcons()
    if not _buffWin then return end
    local bw  = GetBuffWinDB()
    local iw  = bw.IconW or 44
    local ih  = bw.IconH or 44
    local sp  = bw.Spacing or 4
    local rsp = bw.RowSpacing or 4
    local maxPR = bw.MaxIconsPerRow or 0
    local lblH = (bw.ShowLabel ~= false) and 12 or 0

    local mainGrow = GROW[bw.GrowDir or "RIGHT"] or GROW["RIGHT"]
    local wrapGrow = GROW[bw.WrapGrowDirection or bw.GrowDir or "RIGHT"] or GROW["RIGHT"]
    local wrapDir  = bw.WrapDirection or "DOWN"
    local wrapAnchor = bw.WrapAnchor or "FIRST"

    local mainHoriz = (bw.GrowDir=="RIGHT" or bw.GrowDir=="LEFT" or not bw.GrowDir)
    local rowOffX, rowOffY
    if mainHoriz then
        rowOffX = 0; rowOffY = (wrapDir=="DOWN") and -rsp or rsp
    else
        rowOffX = (wrapDir=="DOWN") and rsp or -rsp; rowOffY = 0
    end
    local newRowMyPoint, newRowToPoint
    if mainHoriz then
        if wrapDir=="DOWN" then newRowMyPoint="TOP";    newRowToPoint="BOTTOM"
        else                    newRowMyPoint="BOTTOM"; newRowToPoint="TOP" end
    else
        if wrapDir=="DOWN" then newRowMyPoint="LEFT";   newRowToPoint="RIGHT"
        else                    newRowMyPoint="RIGHT";  newRowToPoint="LEFT" end
    end

    -- Collect visible entries
    local active = {}
    for _,e in ipairs(_buffSlots) do
        if e.frame:IsShown() then table.insert(active, e) end
    end

    -- Sort if requested
    local sortMode = bw.SortMode or "normal"
    if sortMode == "duration_asc" then
        table.sort(active, function(a,b)
            return (a.endTime or 0) < (b.endTime or 0)
        end)
    elseif sortMode == "duration_desc" then
        table.sort(active, function(a,b)
            return (a.endTime or 0) > (b.endTime or 0)
        end)
    end

    if #active == 0 then
        if _dragBox then _dragBox:SetShown(not bw.Locked); _dragBox:SetSize(iw, ih+lblH) end
        _buffWin:SetSize(iw, ih+lblH)
        return
    end
    if _dragBox then _dragBox:Hide() end

    -- Always re-apply saved anchor to keep window in correct position
    local _bwraw = ConsumableTrackerDB and ConsumableTrackerDB.BuffWindow
    _buffWin:ClearAllPoints()
    do
        local _li_atf = (_bwraw and _bwraw.AnchorToFrame) or "UIParent"
        local _li_scr = _li_atf == "UIParent"
        local _li_sap = (_bwraw and _bwraw.ScreenAnchorPoint) or "CENTER"
        local _li_ap  = _li_scr and _li_sap or ((_bwraw and _bwraw.AnchorPoint) or "CENTER")
        local _li_atp = _li_scr and _li_sap or ((_bwraw and _bwraw.AnchorToPoint) or "CENTER")
        _buffWin:SetPoint(_li_ap, ResolveFrame(_li_atf), _li_atp,
            (_bwraw and _bwraw.X ~= nil) and _bwraw.X or 0,
            (_bwraw and _bwraw.Y ~= nil) and _bwraw.Y or -100)
    end

    -- First icon anchored to buff window
    local first = active[1]
    first.frame:SetSize(iw,ih)
    first.frame:ClearAllPoints()
    first.frame:SetPoint("TOPLEFT", _buffWin, "TOPLEFT", 0, -lblH)

    local rowAnchorFrame = first.frame
    local rowFirstFrame  = first.frame
    local rowLastFrame   = first.frame
    local posInRow = 1
    local currentGrow = mainGrow

    for i=2,#active do
        local f = active[i].frame
        f:SetSize(iw,ih); f:ClearAllPoints()
        if maxPR>0 and posInRow>=maxPR then
            rowAnchorFrame = (wrapAnchor=="LAST") and rowLastFrame or rowFirstFrame
            f:SetPoint(newRowMyPoint, rowAnchorFrame, newRowToPoint, rowOffX, rowOffY)
            rowFirstFrame=f; rowLastFrame=f; posInRow=1; currentGrow=wrapGrow
        else
            local prev = active[i-1].frame
            f:SetPoint(currentGrow.myPoint, prev, currentGrow.toPoint,
                currentGrow.ox*sp, currentGrow.oy*sp)
            posInRow=posInRow+1; rowLastFrame=f
        end
    end
end

local function BuildBuffWindow()
    if _buffWin then return end
    local bw = GetBuffWinDB()
    local iw = bw.IconW or 44
    local ih = bw.IconH or 44

    local f = CreateFrame("Frame","FabsBuffWindow",UIParent)
    f:SetSize(iw, ih)
    f:SetFrameStrata(bw.IconStrata or "HIGH"); f:SetFrameLevel(150)
    f:SetClampedToScreen(true); f:SetMovable(true)
    f:EnableMouse(true)

    f:SetScript("OnMouseDown",function(self,b)
        if b=="LeftButton" and not GetBuffWinDB().Locked then self:StartMoving() end
    end)
    f:SetScript("OnMouseUp",function(self)
        self:StopMovingOrSizing()
        local _,_,_,x,y = self:GetPoint(1)
        if x then
            local bwd = GetBuffWinDB()
            -- Dragging always produces UIParent-relative coords.
            -- Always store CENTER/CENTER so it never drifts to TOPRIGHT.
            bwd.AnchorPoint   = "CENTER"
            bwd.AnchorToPoint = "CENTER"
            bwd.AnchorToFrame = "UIParent"
            bwd.X=math.floor((x or 0)+0.5); bwd.Y=math.floor((y or 0)+0.5)
        end
    end)

    local db = CreateFrame("Frame",nil,f,"BackdropTemplate")
    db:SetAllPoints(f)
    SetBD(db,0.10,0.10,0.18,0.70,0.35,0.35,0.70)
    local dlbl = db:CreateFontString(nil,"OVERLAY")
    dlbl:SetFont(STANDARD_TEXT_FONT,8,"OUTLINE")
    dlbl:SetTextColor(0.7,0.7,1,0.8); dlbl:SetText("Buff\nWindow")
    dlbl:SetPoint("CENTER",db,"CENTER",0,0); dlbl:SetJustifyH("CENTER")
    db:Hide()
    _dragBox = db

    -- Apply saved position — read directly from DB, never use defaults for position
    -- so a saved anchor is never overwritten by GLOBAL_DEFAULTS values
    f:ClearAllPoints()
    local _bwraw = ConsumableTrackerDB and ConsumableTrackerDB.BuffWindow
    local _atf  = (_bwraw and _bwraw.AnchorToFrame) or "UIParent"
    local _isScr = _atf == "UIParent"
    local _sap  = (_bwraw and _bwraw.ScreenAnchorPoint) or "CENTER"
    local _apt  = _isScr and _sap or ((_bwraw and _bwraw.AnchorPoint) or "CENTER")
    local _atp  = _isScr and _sap or ((_bwraw and _bwraw.AnchorToPoint) or "CENTER")
    local _bwx  = (_bwraw and _bwraw.X ~= nil) and _bwraw.X or 0
    local _bwy  = (_bwraw and _bwraw.Y ~= nil) and _bwraw.Y or -100
    f:SetPoint(_apt, ResolveFrame(_atf), _atp, _bwx, _bwy)

    if not bw.Enabled then f:Hide() end
    _buffWin = f

    -- ── Persistent frame registry ────────────────────────────────────────────
    -- Each unique key gets ONE frame created out of combat and reused forever.
    -- Frames are never destroyed or returned to a pool, so combat never blocks us.
    -- ─────────────────────────────────────────────────────────────────────────
    local _persistFrames = {}  -- [key] = frame

    local function MakeBuffFrame(key)
        if _persistFrames[key] then return _persistFrames[key] end
        local pf = CreateFrame("Frame",nil,_buffWin,"BackdropTemplate")
        pf:SetFrameLevel(_buffWin:GetFrameLevel()+5)
        SetBD(pf,0.06,0.06,0.08,0.0,0,0,0,0)
        local ico = pf:CreateTexture(nil,"BACKGROUND")
        ico:SetAllPoints(pf); ico:SetTexCoord(0.08,0.92,0.08,0.92); pf._ico=ico
        local swipe = CreateFrame("Cooldown",nil,pf,"CooldownFrameTemplate")
        swipe:SetAllPoints(pf); swipe:SetDrawEdge(false)
        swipe:SetHideCountdownNumbers(true); swipe:Clear(); pf._swipe=swipe
        local cdFrame = CreateFrame("Frame",nil,pf)
        cdFrame:SetAllPoints(pf); cdFrame:SetFrameLevel(pf:GetFrameLevel()+20)
        local _bwSt = GetBuffWinDB().IconStrata or "HIGH"
        cdFrame:SetFrameStrata(_STRATA_UP[_bwSt] or _bwSt)
        local cd = cdFrame:CreateFontString(nil,"OVERLAY")
        cd:SetFont(STANDARD_TEXT_FONT,14,"OUTLINE"); cd:SetTextColor(1,1,1,1)
        cd:SetPoint("CENTER",cdFrame,"CENTER",0,0); pf._cdFrame=cdFrame; pf._cd=cd
        local lbl = pf:CreateFontString(nil,"OVERLAY")
        lbl:SetFont(STANDARD_TEXT_FONT,7,"OUTLINE"); lbl:SetTextColor(0.75,0.75,0.75,1)
        lbl:SetPoint("BOTTOM",pf,"TOP",0,2); lbl:SetJustifyH("CENTER"); pf._lbl=lbl
        pf:EnableMouse(true)
        pf:SetScript("OnMouseDown",function(_,b)
            if b=="RightButton" then pf:Hide(); LayoutBuffIcons() end
        end)
        pf:Hide()
        _persistFrames[key] = pf
        return pf
    end

    -- Pre-create frames for all currently tracked/equipped items.
    -- Extracted to a function so it can be re-called on world entry and gear changes.
    local function PreCreateBuffFrames()
        local bwd = GetBuffWinDB()
        for _, entry in ipairs(bwd.TrackedItems or {}) do
            if entry.itemId and entry.itemId > 0 then
                MakeBuffFrame("tracked_"..entry.itemId)
            end
        end
        local MID = CT.MIDNIGHT_S1_ONUSE
        if MID then
            for slot = 1, 17 do
                local itemId = GetInventoryItemID("player", slot)
                if itemId and itemId > 0 and MID[itemId] then
                    MakeBuffFrame("midnight_"..itemId)
                end
            end
        end
    end
    -- Run at build time (out of combat, safe to CreateFrame)
    C_Timer.After(0.1, PreCreateBuffFrames)
    -- Expose so PLAYER_ENTERING_WORLD and PLAYER_EQUIPMENT_CHANGED can re-run it
    CT._PreCreateBuffFrames = PreCreateBuffFrames

    -- Expose so ShowCustomBuffIcon can reach the frame registry
    CT._GetOrMakeBuffFrame = function(key)
        -- If frame already exists, return it (safe in combat)
        if _persistFrames[key] then return _persistFrames[key] end
        -- Frame doesn't exist yet — can only create out of combat
        if InCombatLockdown() then return nil end
        return MakeBuffFrame(key)
    end

    -- ── CD start-time tracking (replaces bool-gate) ───────────────────────────
    -- Stores the startTime of the most recently seen CD for each item.
    -- Icon fires ONLY when startTime changes — immune to zone transitions,
    -- resurrections, and re-logins. No PrePopulate needed on zone entry.
    local _buffItemLastStart  = {}  -- ["tracked_<id>"]  = lastStartTime
    local _midnightLastStart  = {}  -- ["midnight_<id>"] = lastStartTime

    -- Seed start times on first load so we never fire for a CD that was
    -- already running before the addon loaded.
    local function PrePopulateCDState()
        local bwd2 = GetBuffWinDB()
        local MID2 = CT.MIDNIGHT_S1_ONUSE
        for _, entry in ipairs(bwd2.TrackedItems or {}) do
            local id = entry.itemId
            if id and id > 0 then
                local s,d,en = C_Item.GetItemCooldown(id)
                s=s or 0; d=d or 0
                if en~=0 and d>=1.5 and s>0 and (s+d)>GetTime() then
                    _buffItemLastStart["tracked_"..id] = s
                end
            end
        end
        if MID2 then
            for slot = 1, 17 do
                local itemId = GetInventoryItemID("player", slot)
                if itemId and itemId > 0 and MID2[itemId] then
                    local info = MID2[itemId]
                    local minCD = math.max((info.cooldown or 0)*0.5, 1.5)
                    local s,d,en = C_Item.GetItemCooldown(itemId)
                    s=s or 0; d=d or 0
                    if en~=0 and d>=minCD and s>0 and (s+d)>GetTime() then
                        _midnightLastStart["midnight_"..itemId] = s
                    end
                end
            end
        end
    end
    PrePopulateCDState()
    -- Only expose for login/reload — NOT called on zone entry
    CT._PrePopulateCDState = PrePopulateCDState

    -- TrackedItems ticker — start-time based
    C_Timer.NewTicker(0.1, function()
        if not _buffWin then return end
        local bwd = GetBuffWinDB()
        if not bwd.Enabled then return end
        if UnitIsDeadOrGhost("player") then return end
        for _, entry in ipairs(bwd.TrackedItems or {}) do
            local id = entry.itemId
            if id and id > 0 then
                local key = "tracked_"..id
                if entry.enabled == false then
                    _buffItemLastStart[key] = nil
                else
                    local s,d,en = C_Item.GetItemCooldown(id)
                    s=s or 0; d=d or 0
                    local cdActive = en~=0 and d>=1.5 and s>0 and (s+d)>GetTime()
                    if cdActive then
                        if s ~= (_buffItemLastStart[key] or 0) then
                            -- New CD start time — trinket was just used
                            _buffItemLastStart[key] = s
                            if CT.ShowCustomBuffIcon then
                                CT.ShowCustomBuffIcon(key, id,
                                    entry.label or (GetItemInfo(id) or ("Item "..id)),
                                    entry.duration or 0)
                            end
                        end
                    else
                        -- CD expired — clear so next use is detected
                        _buffItemLastStart[key] = nil
                    end
                end
            end
        end
    end)

    -- Midnight S1 auto-track ticker — start-time based
    C_Timer.NewTicker(0.1, function()
        if not _buffWin then return end
        local bwd = GetBuffWinDB()
        if not bwd.Enabled or not bwd.MidnightAutoTrackEnabled then return end
        if UnitIsDeadOrGhost("player") then return end
        local trackEnabled = bwd.MidnightAutoTrack or {}
        local MID = CT.MIDNIGHT_S1_ONUSE
        if not MID then return end
        for slot = 1, 17 do
            local itemId = GetInventoryItemID("player", slot)
            if itemId and itemId > 0 then
                local info = MID[itemId]
                if info and info.duration and info.duration > 0 and trackEnabled[itemId] ~= false then
                    local key = "midnight_"..itemId
                    local minCD = math.max((info.cooldown or 0)*0.5, 1.5)
                    local s,d,en = C_Item.GetItemCooldown(itemId)
                    s=s or 0; d=d or 0
                    local cdActive = en~=0 and d>=minCD and s>0 and (s+d)>GetTime()
                    if cdActive then
                        if s ~= (_midnightLastStart[key] or 0) then
                            _midnightLastStart[key] = s
                            if CT.ShowCustomBuffIcon then
                                CT.ShowCustomBuffIcon(key, itemId, info.label, info.duration)
                            end
                        end
                    else
                        _midnightLastStart[key] = nil
                    end
                end
            end
        end
    end)

    LayoutBuffIcons()
end

local function GetOrCreateBuffEntry(key)
    for _,e in ipairs(_buffSlots) do if e.key==key then return e end end
    -- Get the persistent frame for this key
    local getFrame = CT._GetOrMakeBuffFrame
    local pf = getFrame and getFrame(key)
    if not pf then return nil end  -- in combat and frame wasn't pre-created
    local entry = {frame=pf, key=key}
    table.insert(_buffSlots, entry)
    return entry
end

local function ShowCustomBuffIcon(key, itemId, label, duration, preFetchedTex)
    if not _buffWin then BuildBuffWindow() end
    local bw = GetBuffWinDB()
    if not bw.Enabled then return end
    if not duration or duration <= 0 then return end

    local entry = GetOrCreateBuffEntry(key)
    if not entry then return end
    local f = entry.frame

    local tex = preFetchedTex or GetTex(itemId) or select(10,GetItemInfo(itemId))
    if tex then f._ico:SetTexture(tex) else f._ico:SetColorTexture(0.3,0.3,0.3,1) end
    f._lbl:SetText(label or "")

    -- Re-wrap entry slot for ApplyBuffIconStyle compatibility
    entry.slot = {type="item", label=label}
    ApplyBuffIconStyle(entry)

    if bw.ShowSwipe ~= false then
        f._swipe:SetCooldown(GetTime(), duration)
    else
        f._swipe:Clear()
    end

    entry.duration = duration
    entry.endTime  = GetTime() + duration
    f:Show()
    LayoutBuffIcons()

    if entry.ticker then entry.ticker:Cancel() end
    local _lastReorder = 0
    entry.ticker = C_Timer.NewTicker(0.05, function()
        if not f:IsShown() then entry.ticker:Cancel(); return end
        local now = GetTime()
        local remaining = entry.endTime - now
        if remaining <= 0 then
            f:Hide(); entry.ticker:Cancel()
            -- Remove from active slots list but keep frame alive for next use
            for i,e in ipairs(_buffSlots) do
                if e==entry then table.remove(_buffSlots,i); break end
            end
            LayoutBuffIcons(); return
        end
        if bw.CDTextShow ~= false then
            f._cd:SetText(math.ceil(remaining).."s")
        else
            f._cd:SetText("")
        end
        local sm = GetBuffWinDB().SortMode or "normal"
        if sm ~= "normal" and now - _lastReorder >= 1.0 then
            _lastReorder = now; LayoutBuffIcons()
        end
    end)
end

function CT.RefreshBuffWindow()
    if not _buffWin then BuildBuffWindow(); return end
    local bw = GetBuffWinDB()
    _buffWin:SetShown(bw.Enabled ~= false)
    local _bwraw = ConsumableTrackerDB and ConsumableTrackerDB.BuffWindow
    _buffWin:ClearAllPoints()
    do
        local _rf_atf = (_bwraw and _bwraw.AnchorToFrame) or "UIParent"
        local _rf_scr = _rf_atf=="UIParent"
        local _rf_sap = (_bwraw and _bwraw.ScreenAnchorPoint) or "CENTER"
        local _rf_ap  = _rf_scr and _rf_sap or ((_bwraw and _bwraw.AnchorPoint) or "CENTER")
        local _rf_atp = _rf_scr and _rf_sap or ((_bwraw and _bwraw.AnchorToPoint) or "CENTER")
        _buffWin:SetPoint(_rf_ap, ResolveFrame(_rf_atf), _rf_atp,
            (_bwraw and _bwraw.X ~= nil) and _bwraw.X or 0,
            (_bwraw and _bwraw.Y ~= nil) and _bwraw.Y or -100)
    end
    for _,e in ipairs(_buffSlots) do ApplyBuffIconStyle(e) end
    LayoutBuffIcons()
end

CT.ShowCustomBuffIcon = ShowCustomBuffIcon
CT.BuildBuffWindow    = BuildBuffWindow
CT.GetBuffSlots       = function() return _buffSlots end

    -- Clear visible icons on zone entry/death. Start-time tables are intentionally
    -- NOT reset here — if the CD start time hasn't changed, the icon won't
    -- re-fire. This is correct: the buff was consumed before zoning.
    CT._ClearActiveBuffIcons = function()
        for _, entry in ipairs(_buffSlots) do
            if entry.ticker then entry.ticker:Cancel(); entry.ticker = nil end
            if entry.frame  then entry.frame:Hide() end
        end
        -- Clear in-place: do NOT reassign _buffSlots = {} here.
        -- Reassigning breaks the upvalue shared with GetOrCreateBuffEntry
        -- and other closures, leaving them holding a stale reference.
        for i = #_buffSlots, 1, -1 do _buffSlots[i] = nil end
        LayoutBuffIcons()
    end


-- Populated when SPELL_UPDATE_COOLDOWN / UNIT_SPELLCAST_SUCCEEDED fire.
-- API reads are valid at event time; ticker only does GetTime() math.
-- ---------------------------------------------------------------
local spellCDCache = {}  -- [spellId] = {start=N, dur=N}

local function ReadSpellCD(id)
    local st, du = 0, 0
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, id)
        if ok and info then
            st = tonumber(tostring(info.startTime)) or 0
            du = tonumber(tostring(info.duration))  or 0
        end
    end
    if du == 0 and GetSpellCooldown then
        local ok, a, b = pcall(GetSpellCooldown, id)
        if ok then st = tonumber(tostring(a)) or 0; du = tonumber(tostring(b)) or 0 end
    end
    return st, du
end

local function CacheAllSpellCDs()
    if not iconStructs then return end
    local now = GetTime()
    for _,s in ipairs(iconStructs) do
        if s.spellId then
            local id = s.spellId
            local st, du = ReadSpellCD(id)
            -- issecretvalue: TWW native taint detection (ElvUI/oUF pattern)
            -- If values are tainted (mount noise etc), keep existing cache untouched
            if issecretvalue and (issecretvalue(du) or issecretvalue(st)) then
                -- tainted read — preserve cache, let time-based expiry handle it
            elseif du > 1.5 and (st + du) > now then
                spellCDCache[id] = {start=st, dur=du}
            else
                -- Only clear if genuinely expired by time
                local c = spellCDCache[id]
                if not c or (c.start + c.dur) <= now then
                    spellCDCache[id] = nil
                end
            end
        end
    end
end

local _cacheSpellPending = false
local _cacheAllRef = CacheAllSpellCDs  -- capture local ref for timer closure
local function CacheAllSpellCDsDebounced()
    if _cacheSpellPending then return end
    _cacheSpellPending = true
    C_Timer.After(0.1, function()
        _cacheSpellPending = false
        _cacheAllRef()
    end)
end

-- ---------------------------------------------------------------
-- Update: spell icon
-- ---------------------------------------------------------------
local function Untaint(v) return tonumber(tostring(v)) or 0 end

local function UpdateSpellStruct(s)
    if not s or not s.spellId then return end
    local db=s.winDef or DB().Windows[1] or DB(); local id=s.spellId
    local tex=GetSpellTex(id)
    if tex and tex~=s._lastTex then s.iconTex:SetTexture(tex); ApplyZoomToStruct(s); s._lastTex=tex end

    local cached = spellCDCache[id]
    local now = GetTime()

    if cached and (cached.start + cached.dur) > now then
        local st, du = cached.start, cached.dur
        -- Only reset swipe when start/dur actually change
        if st~=s._lastCDStart or du~=s._lastCDDur then
            s.cdFrame:SetCooldown(st, du)
            s._lastCDStart=st; s._lastCDDur=du
        end
        local desat = db.DesatOnCooldown or false
        if desat~=s._lastDesat then s.iconTex:SetDesaturated(desat); s._lastDesat=desat end
        s.cachedCDStart = st
        s.cachedCDDur   = du
    else
        -- Cache miss or expired — try a live read
        local st, du = ReadSpellCD(id)
        local onCD = du > 1.5 and st > 0 and (st + du) > now
        if onCD then
            spellCDCache[id] = {start=st, dur=du}
            if st~=s._lastCDStart or du~=s._lastCDDur then
                s.cdFrame:SetCooldown(st, du)
                s._lastCDStart=st; s._lastCDDur=du
            end
            local desat = db.DesatOnCooldown or false
            if desat~=s._lastDesat then s.iconTex:SetDesaturated(desat); s._lastDesat=desat end
            s.cachedCDStart = st
            s.cachedCDDur   = du
        elseif du == 0 and st == 0 then
            -- API returned nothing (mount noise, protected API, etc).
            -- Keep whatever we have — let time-based expiry in CacheAllSpellCDs handle it.
            -- Only clear if our own cached time has run out.
            local c = spellCDCache[id]
            if not c or (c.start + c.dur) <= now then
                if s._lastCDDur~=0 then
                    s.cdFrame:Clear(); s._lastCDStart=0; s._lastCDDur=0
                end
                if s._lastDesat~=false then s.iconTex:SetDesaturated(false); s._lastDesat=false end
                s.cachedCDStart = nil; s.cachedCDDur = nil
            end
        else
            -- Explicit non-CD (du<=1.5 GCD or truly zero)
            spellCDCache[id] = nil
            if s._lastCDDur~=0 then
                s.cdFrame:Clear(); s._lastCDStart=0; s._lastCDDur=0
            end
            if s._lastDesat~=false then s.iconTex:SetDesaturated(false); s._lastDesat=false end
            s.cachedCDStart = nil; s.cachedCDDur = nil
        end
    end

    local _c,_mc = GetSpellChargeInfo(id)
    local charges    = _c  and tonumber(tostring(_c))  or nil
    local maxCharges = _mc and tonumber(tostring(_mc)) or nil
    if charges and maxCharges and maxCharges>1 then
        if charges==0 then s.countText:SetText("0"); s.countText:SetTextColor(1,0.3,0.3,1)
        else s.countText:SetText(tostring(charges)); s.countText:SetTextColor(1,1,1,1) end
        s.countText:SetShown(db.ShowCount~=false)
    else s.countText:SetText(""); s.countText:SetShown(false) end
    s.qGemTex:Hide(); s.qGemBg:Hide(); s.qGemStar:Hide(); s.qGemLbl:Hide()
end

local function UpdateSpellStructCDText(s)
    if not s or not s.cdText or not s.spellId then return end
    if DB().ShowCooldownText==false then s.cdText:SetText(""); return end
    local st = s.cachedCDStart
    local du = s.cachedCDDur
    if not st or not du then s.cdText:SetText(""); return end
    local txt = FormatCD(st, du)
    if txt == "" then
        s.cachedCDStart = nil
        s.cachedCDDur   = nil
    end
    s.cdText:SetText(txt)
end

-- ---------------------------------------------------------------
-- Update: equipment slot icon
-- ---------------------------------------------------------------
local function UpdateEquipStruct(s)
    if not s or not s.equipSlot then return end
    local db=s.winDef or DB().Windows[1] or DB()
    local itemId=GetInventoryItemID("player",s.equipSlot)
    if not itemId or itemId==0
       or not ItemHasOnUse(itemId)
       or (db.EquipBlacklist and db.EquipBlacklist[itemId]) then
        s.frame:Hide(); return
    end
    s.frame:Show()
    s.itemId=itemId
    local tex=GetTex(itemId)
    if tex and tex~=s._lastTex then s.iconTex:SetTexture(tex); ApplyZoomToStruct(s); s._lastTex=tex end
    local start,dur=GetCD(itemId)
    local onCD=dur>0 and start>0 and (start+dur)-GetTime()>0
    local desat=onCD and (db.DesatOnCooldown or false)
    if desat~=s._lastDesat then s.iconTex:SetDesaturated(desat); s._lastDesat=desat end
    if dur~=s._lastCDDur or start~=s._lastCDStart then
        if dur>0 and start>0 then s.cdFrame:SetCooldown(start,dur) else s.cdFrame:Clear() end
        s._lastCDStart=start; s._lastCDDur=dur
    end
    s.countText:SetText(""); s.countText:SetShown(false)
    s.qGemTex:Hide(); s.qGemBg:Hide(); s.qGemStar:Hide(); s.qGemLbl:Hide()
end

local function UpdateEquipStructCDText(s)
    if not s or not s.cdText or not s.equipSlot then return end
    if DB().ShowCooldownText==false then s.cdText:SetText(""); return end
    local itemId=GetInventoryItemID("player",s.equipSlot)
    if not itemId or itemId==0 then s.cdText:SetText(""); return end
    s.cdText:SetText(FormatCD(GetCD(itemId)))
end

-- ---------------------------------------------------------------
-- Frame arrays
-- ---------------------------------------------------------------
local addonInitialized=false

-- ---------------------------------------------------------------
-- Layout: multi-row wrap with independent row-grow direction
-- ---------------------------------------------------------------
local function LayoutWindowFrames(win, structs)
    if not structs or #structs==0 then return end
    local iw  = win.IconWidth  or 44
    local ih  = win.IconHeight or 44
    local sp  = win.GrowSpacing or 4
    local rsp = win.RowSpacing  or 4
    local maxPR = win.MaxIconsPerRow or 0

    local mainGrow = GROW[win.GrowDirection or "RIGHT"] or GROW["RIGHT"]
    local wrapGrow = GROW[win.WrapGrowDirection or win.GrowDirection or "RIGHT"] or GROW["RIGHT"]
    local wrapDir  = win.WrapDirection or "DOWN"
    local wrapAnchor = win.WrapAnchor or "FIRST"

    local mainHoriz = (win.GrowDirection=="RIGHT" or win.GrowDirection=="LEFT" or
                       win.GrowDirection==nil or win.GrowDirection=="")
    local rowOffX, rowOffY
    if mainHoriz then
        rowOffX = 0
        rowOffY = (wrapDir=="DOWN") and -rsp or rsp
    else
        rowOffX = (wrapDir=="DOWN") and rsp or -rsp
        rowOffY = 0
    end

    local newRowMyPoint, newRowToPoint
    if mainHoriz then
        if wrapDir=="DOWN" then newRowMyPoint="TOP";    newRowToPoint="BOTTOM"
        else                    newRowMyPoint="BOTTOM"; newRowToPoint="TOP" end
    else
        if wrapDir=="DOWN" then newRowMyPoint="LEFT";   newRowToPoint="RIGHT"
        else                    newRowMyPoint="RIGHT";  newRowToPoint="LEFT" end
    end

    local first = structs[1]
    first.frame:SetSize(iw,ih)
    first.frame:ClearAllPoints()
    -- Give this window's anchor frame a global name so other windows can anchor to it
    local winIdx = 1
    for i,w in ipairs(ConsumableTrackerDB.Windows or {}) do
        if w==win then winIdx=i; break end
    end
    local gName = "FabsWin_"..winIdx
    _G[gName] = first.frame
    first.frame:SetPoint(win.AnchorPoint or "CENTER", ResolveFrame(win.AnchorToFrame),
        win.AnchorToPoint or "CENTER", win.X or 0, win.Y or 0)

    local rowAnchorFrame = first.frame
    local posInRow = 1
    local rowFirstFrame = first.frame
    local rowLastFrame  = first.frame
    local currentGrow = mainGrow

    for i=2,#structs do
        local s=structs[i]
        s.frame:SetSize(iw,ih)
        s.frame:ClearAllPoints()

        if maxPR>0 and posInRow>=maxPR then
            rowAnchorFrame = (wrapAnchor=="LAST") and rowLastFrame or rowFirstFrame
            s.frame:SetPoint(newRowMyPoint, rowAnchorFrame, newRowToPoint, rowOffX, rowOffY)
            rowFirstFrame = s.frame; rowLastFrame = s.frame
            posInRow = 1; currentGrow = wrapGrow
        else
            local prev = structs[i-1].frame
            s.frame:SetPoint(currentGrow.myPoint, prev, currentGrow.toPoint,
                currentGrow.ox*sp, currentGrow.oy*sp)
            posInRow = posInRow+1; rowLastFrame = s.frame
        end
    end
end

-- Keep old name as alias for anything that calls it directly
local function LayoutAllFrames()
    for winIdx, state in ipairs(windowStates) do
        local win = DB().Windows[winIdx]
        if win and state.structs then
            LayoutWindowFrames(win, state.structs)
        end
    end
end

local function ApplyAllSettings()
    for _,s in ipairs(iconStructs) do ApplyAllToStruct(s) end
    LayoutAllFrames()
end

local function UpdateAllIcons()
    for _,s in ipairs(iconStructs) do
        local slot=s.slotRef; if not slot then return end
        if slot.type=="healthstone" then
            s.itemId=ActiveItemID(); UpdateStruct(s)
        elseif slot.type=="group" then
            local id=ResolveGroup(slot)
            if id then
                s.itemId=id; UpdateStruct(s)
            elseif s.itemId then
                UpdateStruct(s)
            end
        elseif slot.type=="spell" then
            UpdateSpellStruct(s)
        elseif slot.type=="item" then
            UpdateStruct(s)
        elseif slot.type=="equip" then
            UpdateEquipStruct(s)
        end
    end
end

-- ---------------------------------------------------------------
-- Migration: convert old flat DB to multi-window structure
-- ---------------------------------------------------------------
local function MigrateToWindows()
    local d = DB()
    -- If Windows already set up with at least one window that has Slots, we're done
    if d.Windows and #d.Windows > 0 and d.Windows[1].Slots then
        for _,w in ipairs(d.Windows) do EnsureWinDefaults(w) end
        return
    end
    -- First time: build window 1 from old top-level keys + UnifiedIcons
    d.Windows = {}
    local w1 = {}
    for k,_ in pairs(WIN_DEFAULTS) do
        if k=="Slots" then
            -- Use UnifiedIcons if it exists, otherwise empty
            local src = d.UnifiedIcons
            w1.Slots = (type(src)=="table" and #src>0) and src or {}
        elseif d[k] ~= nil then
            w1[k] = d[k]
        end
    end
    w1.Name = "Main Window"
    w1.Locked = false  -- always start unlocked after migration
    EnsureWinDefaults(w1)
    -- Fresh install: add healthstone to window 1
    if #w1.Slots == 0 then
        table.insert(w1.Slots, {type="healthstone", enabled=true, label="Healthstone"})
    end
    table.insert(d.Windows, w1)
    -- Apply global defaults
    for k,v in pairs(GLOBAL_DEFAULTS) do
        if d[k]==nil then
            if type(v)=="table" then d[k]={}; for tk,tv in pairs(v) do d[k][tk]=tv end
            else d[k]=v end
        end
    end
end

-- ---------------------------------------------------------------
-- Build one slot struct (shared across windows)
-- ---------------------------------------------------------------
local function BuildSlotStruct(slot, win, winIdx)
    local _,playerRace =UnitRace("player")
    local _,playerClass=UnitClass("player")
    local skip=false

    if slot.type=="group" then
        local hasAny=false
        for pi=1,4 do if slot["p"..pi] and slot["p"..pi]>0 then hasAny=true; break end end
        if not hasAny then skip=true end
    elseif slot.type=="spell" then
        local raceOk =(not slot.race)  or slot.race==playerRace
        local classOk=(not slot.class) or slot.class==playerClass
        local knownId = raceOk and classOk and BestKnownSpellId(slot.spellId)
        if not knownId then skip=true end
        slot._resolvedSpellId = knownId
    elseif slot.type=="equip" then
        local itemId=slot.slot and GetInventoryItemID("player",slot.slot)
        local db=DB()
        if not itemId or itemId==0 then skip=true
        elseif not ItemHasOnUse(itemId) then skip=true
        elseif db.EquipBlacklist and db.EquipBlacklist[itemId] then skip=true
        end
    end
    if skip or slot.enabled==false then return nil end

    local s=MakeIconStruct(nil,UIParent)
    s.slotRef=slot
    s.winDef=win
    s.winIdx=winIdx
    local cap=s

    s.frame:EnableMouse(true)
    s.frame:SetScript("OnMouseDown",function(_,btn)
        if btn=="RightButton" then CT:ToggleGUI() end
    end)

    local function ShowTip(frame,fn)
        if not DB().ShowTooltips then return end
        GameTooltip:SetOwner(frame,"ANCHOR_RIGHT"); fn(); GameTooltip:Show()
    end
    s.frame:SetScript("OnLeave",function() GameTooltip:Hide() end)

    if slot.type=="healthstone" then
        s.itemId=ActiveItemID(); s.isMain=true
        local capS=s
        s.frame:SetScript("OnEnter",function() ShowTip(capS.frame,function() GameTooltip:SetItemByID(capS.itemId) end) end)
        cap.ticker=C_Timer.NewTicker(0.1,function()
            cap.itemId=ActiveItemID()
            UpdateStructCDText(cap); UpdateStruct(cap)
        end)

    elseif slot.type=="group" then
        s.itemId=ResolveGroup(slot)
        local capSlot=slot
        local capS=s
        s.frame:SetScript("OnEnter",function()
            if capS.itemId then ShowTip(capS.frame,function() GameTooltip:SetItemByID(capS.itemId) end) end
        end)
        cap.ticker=C_Timer.NewTicker(0.1,function()
            -- Re-resolve each tick so icon/gem/count reflects actual bag contents
            local newId=ResolveGroup(capSlot)
            cap.itemId=newId
            -- Detect item just used: cooldown start changed to ~now
            if newId then
                local _s,_d,_en=C_Item.GetItemCooldown(newId)
                _s=_s or 0; _d=_d or 0
                local _cdOn=_d>1.5 and _s>0 and (_s+_d)>GetTime() and _en~=0
                local dur2=capSlot.customTimerDuration
                if dur2 and dur2>0 and _cdOn and not cap._cdWasActive then
                    local _key="group_slot_"..tostring(capSlot)
                    ShowCustomBuffIcon(_key, newId, capSlot.label or "", dur2)
                end
                cap._cdWasActive=_cdOn
            end
            UpdateStructCDText(cap)
            UpdateStruct(cap)
        end)

    elseif slot.type=="spell" then
        s.spellId = slot._resolvedSpellId or slot.spellId
        local capSpellId=s.spellId
        local capS=s
        s.frame:SetScript("OnEnter",function() ShowTip(s.frame,function() GameTooltip:SetSpellByID(capSpellId) end) end)

        s.frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        s.frame:RegisterEvent("SPELL_UPDATE_CHARGES")
        s.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        s.frame:SetScript("OnEvent", function(self, event)
            local now = GetTime()
            local st, du

            local charges = C_Spell and C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(capSpellId)
            if charges then
                if issecretvalue and issecretvalue(charges) then return end
                local ok
                ok, st, du = pcall(function() return charges.cooldownStartTime, charges.cooldownDuration end)
                if not ok then return end
            else
                local cd = C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(capSpellId)
                if not cd then return end
                if issecretvalue and issecretvalue(cd) then return end
                local ok
                ok, st, du = pcall(function() return cd.startTime, cd.duration end)
                if not ok then return end
            end

            if not st or not du then return end
            if issecretvalue and (issecretvalue(st) or issecretvalue(du)) then return end

            if du > 1.5 and (st + du) > now then
                spellCDCache[capSpellId] = {start=st, dur=du}
            else
                local c = spellCDCache[capSpellId]
                if not c or (c.start + c.dur) <= now then
                    spellCDCache[capSpellId] = nil
                end
            end

            local c = spellCDCache[capSpellId]
            if c and (c.start + c.dur) > now then
                if c.start~=capS._lastCDStart or c.dur~=capS._lastCDDur then
                    capS.cdFrame:SetCooldown(c.start, c.dur)
                    capS._lastCDStart=c.start; capS._lastCDDur=c.dur
                end
                capS.cachedCDStart=c.start; capS.cachedCDDur=c.dur
            else
                if capS._lastCDDur~=0 then
                    capS.cdFrame:Clear()
                    capS._lastCDStart=0; capS._lastCDDur=0
                    capS.cachedCDStart=nil; capS.cachedCDDur=nil
                end
            end
        end)

        cap.ticker=C_Timer.NewTicker(0.1,function()
            UpdateSpellStructCDText(cap)
            local c = spellCDCache[cap.spellId]
            local now = GetTime()
            if c and (c.start + c.dur) <= now then
                spellCDCache[cap.spellId]=nil
                if cap._lastCDDur~=0 then
                    cap.cdFrame:Clear(); cap._lastCDStart=0; cap._lastCDDur=0
                    cap.iconTex:SetDesaturated(false); cap._lastDesat=false
                    cap.cachedCDStart=nil; cap.cachedCDDur=nil
                end
            end
        end)

    elseif slot.type=="item" then
        s.itemId=slot.itemId
        local capId=slot.itemId
        local capSlot=slot
        s.frame:SetScript("OnEnter",function() ShowTip(s.frame,function() GameTooltip:SetItemByID(capId) end) end)
        cap.ticker=C_Timer.NewTicker(0.1,function()
            local dur2=capSlot.customTimerDuration
            if dur2 and dur2>0 then
                local _s,_d,_en=C_Item.GetItemCooldown(capId)
                _s=_s or 0; _d=_d or 0
                local _cdOn=_d>1.5 and _s>0 and (_s+_d)>GetTime() and _en~=0
                if _cdOn and not cap._cdWasActive then
                    local _key="item_slot_"..tostring(capSlot)
                    ShowCustomBuffIcon(_key, capId, capSlot.label or "", dur2)
                end
                cap._cdWasActive=_cdOn
            end
            UpdateStructCDText(cap); UpdateStruct(cap)
        end)

    elseif slot.type=="equip" then
        s.equipSlot=slot.slot
        s.itemId=GetInventoryItemID("player",slot.slot)
        local capSlot=slot
        local capSlotNum=slot.slot
        s.frame:SetScript("OnEnter",function() ShowTip(s.frame,function() GameTooltip:SetInventoryItem("player",capSlotNum) end) end)
        cap.ticker=C_Timer.NewTicker(0.1,function()
            cap.itemId=GetInventoryItemID("player",capSlotNum)
            if cap.itemId then
                local _s,_d,_en=C_Item.GetItemCooldown(cap.itemId)
                _s=_s or 0; _d=_d or 0
                local _cdOn=_d>1.5 and _s>0 and (_s+_d)>GetTime() and _en~=0
                local dur2=capSlot.customTimerDuration
                if dur2 and dur2>0 and _cdOn and not cap._cdWasActive then
                    local _key="equip_slot_"..tostring(capSlot)
                    ShowCustomBuffIcon(_key, cap.itemId, capSlot.label or "", dur2)
                end
                cap._cdWasActive=_cdOn
            end
            UpdateEquipStruct(cap)
            UpdateEquipStructCDText(cap)
        end)
    end

    ApplyAllToStruct(s)
    RegisterWithMasque(s)

    -- Pre-populate _cdWasActive so items already on CD at login/reload
    -- don't fire a false buff icon on the first ticker tick.
    do
        local _now = GetTime()
        local _checkId
        if slot.type=="group" then _checkId=ResolveGroup(slot)
        elseif slot.type=="item" then _checkId=slot.itemId
        elseif slot.type=="equip" then _checkId=slot.slot and GetInventoryItemID("player",slot.slot) end
        if _checkId then
            local _sv,_dv,_env=C_Item.GetItemCooldown(_checkId)
            _sv=_sv or 0; _dv=_dv or 0
            s._cdWasActive=(_env~=0 and _dv>1.5 and _sv>0 and (_sv+_dv)>_now)
        end
    end

    s.frame:Show()
    return s
end

-- ---------------------------------------------------------------
-- Build all windows
-- ---------------------------------------------------------------
local function BuildAllFrames()
    -- ── Save actual frame positions before teardown ──────────────────────────
    -- FabsWin_N globals point to the first icon frame of each window.
    -- Read their real screen position NOW before we hide/destroy them,
    -- then write those values back into win.X/Y so LayoutWindowFrames
    -- never reads stale profile data.
    local d0 = DB()
    if d0 and d0.Windows then
        for wi = 1, #d0.Windows do
            local gf = _G["FabsWin_"..wi]
            if gf and gf:IsVisible() then
                local w = d0.Windows[wi]
                if (w.AnchorToFrame or "UIParent") == "UIParent" then
                    local pt,_,rpt,fx,fy = gf:GetPoint(1)
                    if pt then
                        w.AnchorPoint   = pt
                        w.AnchorToPoint = rpt
                        w.AnchorToFrame = "UIParent"
                        w.X = math.floor(fx+0.5)
                        w.Y = math.floor(fy+0.5)
                    end
                end
            end
        end
    end
    -- Save buff window position too (skip if anchored to another frame)
    local bwf = _G["FabsBuffWindow"]
    if bwf and bwf:IsVisible() and d0 and d0.BuffWindow then
        local bw = d0.BuffWindow
        if (bw.AnchorToFrame or "UIParent") == "UIParent" then
            local pt,_,rpt,fx,fy = bwf:GetPoint(1)
            if pt then
                bw.AnchorPoint   = pt
                bw.AnchorToPoint = rpt
                bw.AnchorToFrame = "UIParent"
                bw.X = math.floor(fx+0.5)
                bw.Y = math.floor(fy+0.5)
            end
        end
    end
    -- ─────────────────────────────────────────────────────────────────────────

    -- Tear down existing
    for _,s in ipairs(iconStructs) do
        if s.ticker then s.ticker:Cancel(); s.ticker=nil end
        s.frame:UnregisterAllEvents()
        s.frame:Hide()
    end
    iconStructs={}
    windowStates={}

    MigrateToWindows()
    local d=DB()

    for winIdx,win in ipairs(d.Windows or {}) do
        EnsureWinDefaults(win)
        local state = {structs={}}
        windowStates[winIdx] = state

        for _,slot in ipairs(win.Slots or {}) do
            local s = BuildSlotStruct(slot, win, winIdx)
            if s then
                table.insert(state.structs, s)
                table.insert(iconStructs, s)
            end
        end

        -- Set up drag on first icon of this window
        if #state.structs > 0 then
            local f = state.structs[1].frame
            f:SetMovable(true); f:SetClampedToScreen(true)
            f:RegisterForDrag(win.Locked and "" or "LeftButton")
            local capWin=win; local capWinIdx=winIdx
            f:SetScript("OnDragStart",function(self)
                if not capWin.Locked then self:StartMoving() end
            end)
            f:SetScript("OnDragStop",function(self)
                self:StopMovingOrSizing()
                local point,_,relPoint,x,y=self:GetPoint(1)
                -- Dragging always produces UIParent-relative coords.
                -- Force CENTER/CENTER so the anchor points never drift to TOPRIGHT.
                capWin.AnchorPoint   = "CENTER"
                capWin.AnchorToPoint = "CENTER"
                capWin.AnchorToFrame = "UIParent"
                capWin.X=math.floor(x+0.5); capWin.Y=math.floor(y+0.5)
                CT:SyncPositionGUI()
            end)
        end

        LayoutWindowFrames(win, state.structs)
    end

    UpdateAllIcons()
end

-- ---------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------
function CT:Refresh()
    if #iconStructs==0 then return end
    ApplyAllSettings(); UpdateAllIcons()
    local d=DB()
    for winIdx,state in ipairs(windowStates) do
        local win=d.Windows[winIdx]
        if win and state.structs and #state.structs>0 then
            local f=state.structs[1].frame
            f:RegisterForDrag(win.Locked and "" or "LeftButton")
        end
    end
end

function CT:RefreshLayout()
    pcall(BuildAllFrames)
end
CT._windowStates = windowStates  -- expose for GUI lock toggle

function CT:SyncPositionGUI() end

-- ---------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------
local function CreateMainIcon()
    BuildAllFrames()
    addonInitialized=true
    C_Timer.After(0.5,function() if #iconStructs>0 then LayoutAllFrames() end end)
end

local ev=CreateFrame("Frame","CTEventFrame")
local function OnEvent(_,event,...)
    if event=="ADDON_LOADED" then
        if ...~="FabsResourceTracker" then return end
        ConsumableTrackerDB=ConsumableTrackerDB or {}
        local d=ConsumableTrackerDB
        -- Apply global defaults
        for k,v in pairs(GLOBAL_DEFAULTS) do
            if d[k]==nil then
                if type(v)=="table" then d[k]={}; for tk,tv in pairs(v) do d[k][tk]=tv end
                else d[k]=v end
            end
        end
        if type(d.EquipBlacklist)~="table" then d.EquipBlacklist={} end
        if type(d.SectionOrder)~="table"   then d.SectionOrder={"racials","defensives","consumables","gear"} end

        -- Old pre-UnifiedIcons migration: consolidate into UnifiedIcons on d first
        if not d._unifiedMigrated then
            d.UnifiedIcons = d.UnifiedIcons or {}
            if #d.UnifiedIcons==0 then
                table.insert(d.UnifiedIcons,{type="healthstone",enabled=true,label="Healthstone"})
                for _,g in ipairs(d.CustomGroups or {}) do
                    table.insert(d.UnifiedIcons,{type="group",enabled=(g.enabled~=false),label=g.label or "",
                        meta=g.meta,p1=g.p1,p2=g.p2,p3=g.p3,p4=g.p4})
                end
                for _,s in ipairs(d.RacialGroups or {}) do
                    table.insert(d.UnifiedIcons,{type="spell",enabled=(s.enabled~=false),label=s.label or "",
                        spellId=s.spellId,race=s.race,class=s.class})
                end
                for _,i in ipairs(d.OnUseItems or {}) do
                    table.insert(d.UnifiedIcons,{type="item",enabled=(i.enabled~=false),label=i.label or "",itemId=i.itemId})
                end
            end
            d._unifiedMigrated=true
        end
        if type(d.UnifiedIcons)=="table" and #d.UnifiedIcons==0 then
            table.insert(d.UnifiedIcons,{type="healthstone",enabled=true,label="Healthstone"})
        end

        -- Old key migrations
        if d.ShowQualityBadge~=nil and d.ShowQualityGem==nil then d.ShowQualityGem=d.ShowQualityBadge; d.ShowQualityBadge=nil end
        if d.DesaturateOnCooldown~=nil and d.DesatOnCooldown==nil then d.DesatOnCooldown=d.DesaturateOnCooldown; d.DesaturateOnCooldown=nil end

        -- MigrateToWindows is called inside BuildAllFrames

    elseif event=="PLAYER_LOGIN" then
        if not DB().FontPath then DB().FontPath=STANDARD_TEXT_FONT end
        CreateMainIcon()
        C_Timer.After(0.1, function()
            if CT._CreateMinimapButton then CT._CreateMinimapButton() end
            if CT.BuildBuffWindow then CT.BuildBuffWindow() end
        end)

    elseif event=="PLAYER_ENTERING_WORLD" then
        if not addonInitialized then
            if not DB().FontPath then DB().FontPath=STANDARD_TEXT_FONT end
            C_Timer.After(0.3,CreateMainIcon)
        else
            C_Timer.After(0.1,UpdateAllIcons)
        end
        -- Re-create frames for any newly equipped Midnight items and re-sync CD state.
        -- Use 0.5s delay to let gear/item data fully load after the loading screen.
        C_Timer.After(0.5, function()
            -- Clear displayed icons; start-time tables are kept so a CD that
            -- was already running before zoning does NOT re-fire its icon.
            if CT._ClearActiveBuffIcons then CT._ClearActiveBuffIcons() end
            if CT._PreCreateBuffFrames then CT._PreCreateBuffFrames() end
            -- Intentionally NOT calling PrePopulateCDState here:
            -- start-time tracking handles zone-entry correctly on its own.
            if CT.RefreshBuffWindow then CT.RefreshBuffWindow() end
            local _now2 = GetTime()
            for _,s in ipairs(iconStructs or {}) do
                local slot = s.slotRef
                if slot then
                    local _id
                    if slot.type=="group" then _id=ResolveGroup(slot)
                    elseif slot.type=="item" then _id=slot.itemId
                    elseif slot.type=="equip" then _id=s.itemId end
                    if _id then
                        local _sv,_dv,_env=C_Item.GetItemCooldown(_id)
                        _sv=_sv or 0; _dv=_dv or 0
                        s._cdWasActive=(_env~=0 and _dv>1.5 and _sv>0 and (_sv+_dv)>_now2)
                    else
                        s._cdWasActive=nil
                    end
                end
            end
        end)

    elseif event=="PLAYER_EQUIPMENT_CHANGED" then
        local changedSlot = ...
        -- Pre-create buff frame for any newly equipped Midnight S1 item
        -- Use a short delay so item data is loaded before we call GetInventoryItemID
        C_Timer.After(0.3, function()
            if CT._PreCreateBuffFrames then CT._PreCreateBuffFrames() end
        end)
        if changedSlot then
            local relevant=false
            for _,win in ipairs(DB().Windows or {}) do
                for _,slot in ipairs(win.Slots or {}) do
                    if slot.type=="equip" and slot.slot==changedSlot then
                        relevant=true; break
                    end
                end
                if relevant then break end
            end
            if relevant then
                C_Timer.After(0.2,function() CT:RefreshLayout() end)
            end
        end

    elseif event=="PLAYER_SPECIALIZATION_CHANGED" then
        if ...=="player" and not InCombatLockdown() then
            C_Timer.After(0.2, function() CT:RefreshLayout() end)
            C_Timer.After(0.3, function() if CT._UpdateMinimapIcon then CT._UpdateMinimapIcon() end end)
        end
    elseif event=="UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellId = ...
        if unit=="player" then
            CacheAllSpellCDsDebounced()
            if spellId then
                local baseDurMs = GetSpellBaseCooldown and GetSpellBaseCooldown(spellId)
                if baseDurMs and baseDurMs > 1500 then
                    local du = baseDurMs / 1000
                    local st = GetTime()
                    for _,s in ipairs(iconStructs or {}) do
                        if s.spellId then
                            local origId = s.slotRef and s.slotRef.spellId
                            if s.spellId==spellId or origId==spellId then
                                spellCDCache[s.spellId] = {start=st, dur=du}
                                local slot = s.slotRef
                                if slot and slot.customTimerDuration and slot.customTimerDuration > 0 then
                                    local _key="spell_slot_"..tostring(slot)
                                    ShowCustomBuffIcon(_key, s.spellId, slot.label or "", slot.customTimerDuration, GetSpellTex(s.spellId))
                                end
                            end
                        end
                    end
                else
                    -- No base CD (e.g. racials like Shadowmeld) — still fire custom timer if set
                    for _,s in ipairs(iconStructs or {}) do
                        if s.spellId then
                            local origId = s.slotRef and s.slotRef.spellId
                            if s.spellId==spellId or origId==spellId then
                                local slot = s.slotRef
                                if slot and slot.customTimerDuration and slot.customTimerDuration > 0 then
                                    local _key="spell_slot_"..tostring(slot)
                                    ShowCustomBuffIcon(_key, s.spellId, slot.label or "", slot.customTimerDuration, GetSpellTex(s.spellId))
                                end
                            end
                        end
                    end
                end
            end
            C_Timer.After(0.05, UpdateAllIcons)
        end
    elseif event=="PLAYER_DEAD" then
        if CT._ClearActiveBuffIcons then CT._ClearActiveBuffIcons() end
    elseif event=="PLAYER_ALIVE" then
        -- After res, re-seed start times so first use always triggers icon
        C_Timer.After(0.3, function()
            if CT._PrePopulateCDState then CT._PrePopulateCDState() end
        end)
    elseif event=="SPELL_UPDATE_COOLDOWN" then
        CacheAllSpellCDsDebounced()
    elseif event=="PLAYER_REGEN_DISABLED" then
        -- Entering combat: cache immediately before API lock kicks in
        CacheAllSpellCDs()
    elseif event=="TRAIT_CONFIG_UPDATED" or event=="SPELLS_CHANGED" then
        if not InCombatLockdown() then
            C_Timer.After(0.3,function() CT:RefreshLayout() end)
        end
    elseif event=="BAG_UPDATE" or event=="ITEM_COUNT_CHANGED" or event=="ITEM_DATA_LOAD_RESULT" then
        C_Timer.After(0.1,UpdateAllIcons)
    end
end

ev:RegisterEvent("ADDON_LOADED");             ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD");    ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("BAG_UPDATE");               ev:RegisterEvent("ITEM_COUNT_CHANGED")
ev:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED"); ev:RegisterEvent("SPELLS_CHANGED")
ev:RegisterEvent("TRAIT_CONFIG_UPDATED");     ev:RegisterEvent("ITEM_DATA_LOAD_RESULT")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED"); ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_DEAD");              ev:RegisterEvent("PLAYER_ALIVE")
ev:SetScript("OnEvent",OnEvent)

SLASH_CT1="/ct"; SLASH_CT2="/consume"; SLASH_CT3="/consumabletracker"
SlashCmdList["CT"]=function(msg)
    local cmd=msg and msg:lower():match("^%s*(%S+)") or ""
    if cmd=="minimap" then
        CT:ToggleMinimapButton()
    elseif cmd=="minimapdbg" then
        local btn = CT.MinimapButton
        if not btn then print("FRT: MinimapButton is NIL"); return end
        print("FRT MinimapButton debug:")
        print("  Shown: "..tostring(btn:IsShown()))
        print("  Strata: "..tostring(btn:GetFrameStrata()))
        print("  Level: "..tostring(btn:GetFrameLevel()))
        print("  MouseEnabled: "..tostring(btn:IsMouseEnabled()))
        print("  CT.ToggleGUI exists: "..tostring(CT.ToggleGUI~=nil))
        -- Test fire it directly
        print("  Direct call CT:ToggleGUI now...")
        if CT.ToggleGUI then CT:ToggleGUI() else print("  CT.ToggleGUI is nil!") end
    elseif cmd=="itemdbg" then
        local arg = msg and msg:match("%S+%s+(%S+)")
        local id = tonumber(arg)
        if not id then print("FRT: Usage: /ct itemdbg <itemID>"); return end
        print("FRT item debug for ID: "..id)
        -- GetItemInfoInstant
        local n1,l1,q1,il1,rq1,t1,st1,sl1,it1,tex1,sp1 = GetItemInfoInstant(id)
        print("  GetItemInfoInstant:")
        print("    name="..tostring(n1).." quality="..tostring(q1).." tex="..tostring(tex1))
        -- GetItemInfo
        local n2,l2,q2,il2,rq2,t2,st2,ml2,sl2,tex2,sp2 = GetItemInfo(id)
        print("  GetItemInfo:")
        print("    name="..tostring(n2).." quality="..tostring(q2).." ilvl="..tostring(il2).." tex="..tostring(tex2))
        -- ITEM_QUALITY_COLORS
        if q2 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q2] then
            local c=ITEM_QUALITY_COLORS[q2]
            print("  ITEM_QUALITY_COLORS["..q2.."]: r="..tostring(c.r).." g="..tostring(c.g).." b="..tostring(c.b).." hex="..tostring(c.hex))
        else
            print("  ITEM_QUALITY_COLORS: table="..(ITEM_QUALITY_COLORS and "exists" or "NIL").." q2="..tostring(q2))
        end
        -- C_Item
        C_Item.RequestLoadItemDataByID(id)
        C_Timer.After(1, function()
            local n3,_,q3,il3 = GetItemInfo(id)
            print("  After 1s GetItemInfo: name="..tostring(n3).." quality="..tostring(q3).." ilvl="..tostring(il3))
        end)
        -- Reset buff window position to center-top
        local d = ConsumableTrackerDB
        if d and d.BuffWindow then
            d.BuffWindow.AnchorPoint="TOP"; d.BuffWindow.AnchorToPoint="TOP"
            d.BuffWindow.AnchorToFrame="UIParent"; d.BuffWindow.X=0; d.BuffWindow.Y=-100
            if CT.RefreshBuffWindow then CT.RefreshBuffWindow() end
            print("|cFFFFD700Fabs Resource Tracker|r: Buff window reset to top-center.")
        end
    elseif cmd=="debug" then
        -- Print state of all spell structs + raw API values
        local function p(s) print("|cFF3D7AB8FRT|r "..s) end
        local function Untaint2(v) return tonumber(tostring(v)) or 0 end
        p("=== DEBUG (inCombat="..(InCombatLockdown() and "YES" or "NO")..") ===")
        local found=0
        for _,s in ipairs(iconStructs) do
            if s.spellId then
                found=found+1
                local id=s.spellId
                -- Legacy API
                local ls,ld=0,0
                if GetSpellCooldown then
                    local ok,a,b=pcall(GetSpellCooldown,id)
                    if ok then ls,ld=a or 0,b or 0 end
                end
                -- C_Spell API
                local cs,cd=0,0
                if C_Spell and C_Spell.GetSpellCooldown then
                    local ok,info=pcall(C_Spell.GetSpellCooldown,id)
                    if ok and info then
                        cs=Untaint2(info.startTime); cd=Untaint2(info.duration)
                    end
                end
                local cached_s = spellCDCache[id] and string.format("%.1f",spellCDCache[id].start) or "nil"
                local cached_d = spellCDCache[id] and string.format("%.1f",spellCDCache[id].dur)   or "nil"
                local now=GetTime()
                local rem_leg = (ls+ld>0) and string.format("%.1f",math.max(0,(ls+ld)-now)) or "0"
                local rem_cs  = (cs+cd>0) and string.format("%.1f",math.max(0,(cs+cd)-now)) or "0"
                local baseDurMs = GetSpellBaseCooldown and GetSpellBaseCooldown(id)
                local baseDur = baseDurMs and (baseDurMs/1000) or 0
                p(string.format("Spell %d [%s]: Legacy=%.1f/%.1f(rem %s) C_Spell=%.1f/%.1f(rem %s) cache=%s/%s base=%.1fs text='%s'",
                    id, C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or "?",
                    ls,ld,rem_leg, cs,cd,rem_cs,
                    cached_s,cached_d, baseDur,
                    s.cdText and s.cdText:GetText() or "nil"))
            end
        end
        if found==0 then p("No spell structs found.") end
        p("=== END ===")
    else
        CT:ToggleGUI()
    end
end

-- ---------------------------------------------------------------
-- Minimap button (merged from Minimap.lua)
-- ---------------------------------------------------------------
local MINIMAP_RADIUS = 80
local function AngleToPos(angle)
    local rad=math.rad(angle)
    return math.cos(rad)*MINIMAP_RADIUS, math.sin(rad)*MINIMAP_RADIUS
end
local function PosToAngle(x,y) return math.deg(math.atan2(y,x)) end
local function PlaceButton(btn,angle)
    btn:ClearAllPoints()
    local x,y=AngleToPos(angle)
    btn:SetPoint("CENTER",Minimap,"CENTER",x,y)
end

local function CreateMinimapButton()
    if CT.MinimapButton then return end  -- already created, don't duplicate
    local db=ConsumableTrackerDB
    if db.MinimapAngle==nil then db.MinimapAngle=225 end

    -- ── LibDataBroker / LibDBIcon path ──────────────────────────────────
    -- If these libs are present (loaded by another addon), register with them.
    -- This makes the button appear in TitanPanel, ChocolateBar, Bazooka, etc.
    -- and respects any addon that hides minimap buttons via LibDBIcon.
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    local LDBI = LibStub and LibStub("LibDBIcon-1.0", true)

    if LDB and LDBI then
        local broker = LDB:NewDataObject("FabsResourceTracker", {
            type  = "launcher",
            label = "Fabs Resource Tracker",
            icon  = "Interface\\AddOns\\FabsResourceTracker\\icon",
            OnClick = function(_, mouseBtn)
                if mouseBtn == "LeftButton" then
                    if CT.ToggleGUI then CT:ToggleGUI() end
                end
            end,
            OnTooltipShow = function(tip)
                tip:AddLine("|cFFFFD700Fabs Resource Tracker|r")
                tip:AddLine(" ")
                tip:AddLine("Tracks your cooldowns across multiple icon windows.",0.85,0.85,0.85)
                tip:AddLine("Consumables, flasks, phials, potions, defensives,",0.85,0.85,0.85)
                tip:AddLine("racials and on-use gear — all in one place.",0.85,0.85,0.85)
                tip:AddLine(" ")
                tip:AddLine("|cFFAAAAAA[Left-click]|r  Open / close settings",0.9,0.9,0.9)
            end,
        })
        -- minimap settings stored in db.LDBIcon (LibDBIcon needs its own table)
        if not db.LDBIcon then db.LDBIcon = {} end
        LDBI:Register("FabsResourceTracker", broker, db.LDBIcon)
        -- Expose the LibDBIcon button as our MinimapButton
        CT.MinimapButton = LDBI:GetMinimapButton("FabsResourceTracker")
        CT._usingLDB = true
        return
    end

    -- ── Fallback: manual minimap button ─────────────────────────────────
    local btn=CreateFrame("Button","CTMinimapButton",Minimap)
    btn:SetSize(28,28); btn:SetFrameStrata("MEDIUM"); btn:SetFrameLevel(8)
    btn:SetClampedToScreen(false)
    btn:EnableMouse(true)

    -- Icon only — no bg, no mask, no ring
    local icon=btn:CreateTexture(nil,"ARTWORK")
    icon:SetAllPoints(btn)
    icon:SetTexture("Interface\\AddOns\\FabsResourceTracker\\icon")
    icon:SetTexCoord(0,1,0,1)
    btn._icon=icon

    -- Subtle glow on hover (icon-sized, not a ring)
    local hl=btn:CreateTexture(nil,"HIGHLIGHT"); hl:SetAllPoints(btn)
    hl:SetColorTexture(1,1,1,0.18)

    btn:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_BOTTOMLEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("|cFFFFD700Fabs Resource Tracker|r",1,1,1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Tracks your cooldowns across multiple icon windows.",0.85,0.85,0.85)
        GameTooltip:AddLine("Consumables, flasks, phials, potions, defensives,",0.85,0.85,0.85)
        GameTooltip:AddLine("racials and on-use gear — all in one place.",0.85,0.85,0.85)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFFAAAAAA[Left-click]|r  Open / close settings",0.9,0.9,0.9)
        GameTooltip:AddLine("|cFFAAAAAA[Right-click]|r  Hide this button  (/ct minimap to restore)",0.9,0.9,0.9)
        GameTooltip:AddLine("|cFFAAAAAA[Drag]|r  Reposition around minimap",0.9,0.9,0.9)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave",function() GameTooltip:Hide() end)

    local _mouseDownX, _mouseDownY = 0, 0
    local _dragging = false
    btn:SetScript("OnMouseDown", function(self, b)
        if b == "LeftButton" then
            _mouseDownX, _mouseDownY = GetCursorPosition()
            _dragging = false
            self:SetScript("OnUpdate", function()
                local cx, cy = GetCursorPosition()
                if not _dragging and (math.abs(cx-_mouseDownX) > 10 or math.abs(cy-_mouseDownY) > 10) then
                    _dragging = true
                end
                if _dragging then
                    local mx, my = Minimap:GetCenter()
                    local sc = UIParent:GetEffectiveScale()
                    local angle = PosToAngle(cx/sc-mx, cy/sc-my)
                    ConsumableTrackerDB.MinimapAngle = angle
                    PlaceButton(self, angle)
                end
            end)
        elseif b == "RightButton" then
            ConsumableTrackerDB.MinimapHidden = true; self:Hide()
            print("|cFFFFD700Fabs Resource Tracker|r: Minimap button hidden. "
                  .."|cFFFFD700/ct minimap|r to restore.")
        end
    end)
    btn:SetScript("OnMouseUp", function(self, b)
        self:SetScript("OnUpdate", nil)
        if b == "LeftButton" and not _dragging then
            -- Defer to next frame via C_Timer.After(0).
            -- This breaks out of the mouse-event chain entirely, so WoW
            -- cannot propagate the click to the newly-built GUI frame
            -- underneath — which was causing the double-click requirement
            -- on the first open after every reload / zone transition.
            C_Timer.After(0, function()
                if CT.ToggleGUI then CT:ToggleGUI() end
            end)
        end
        _dragging = false
    end)
    PlaceButton(btn,db.MinimapAngle)
    if db.MinimapHidden then btn:Hide() end
    CT.MinimapButton=btn
    return btn
end

local function UpdateMinimapIcon()
    if not CT.MinimapButton then return end
    local tex = "Interface\\AddOns\\FabsResourceTracker\\icon"
    if CT._usingLDB then
        local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
        local broker = LDB and LDB:GetDataObjectByName("FabsResourceTracker")
        if broker then broker.icon = tex end
        if CT.MinimapButton and CT.MinimapButton.icon then
            CT.MinimapButton.icon:SetTexture(tex)
        end
    elseif CT.MinimapButton._icon then
        CT.MinimapButton._icon:SetTexture(tex)
    end
end

-- Exposed so PLAYER_LOGIN handler can call after these locals are defined
CT._CreateMinimapButton = function() CreateMinimapButton(); UpdateMinimapIcon() end
CT._UpdateMinimapIcon   = function() UpdateMinimapIcon() end

function CT:ToggleMinimapButton()
    local db=ConsumableTrackerDB
    if CT._usingLDB then
        -- LibDBIcon manages show/hide via its own saved vars (db.LDBIcon.hide)
        local LDBI = LibStub and LibStub("LibDBIcon-1.0", true)
        if LDBI then
            if LDBI:IsHidden("FabsResourceTracker") then
                LDBI:Show("FabsResourceTracker"); db.MinimapHidden=false
            else
                LDBI:Hide("FabsResourceTracker"); db.MinimapHidden=true
            end
        end
        return
    end
    if not CT.MinimapButton then return end
    if CT.MinimapButton:IsShown() then
        db.MinimapHidden=true; CT.MinimapButton:Hide()
    else
        db.MinimapHidden=false; CT.MinimapButton:Show()
    end
end
