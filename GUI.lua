-- FabsResourceTracker / GUI.lua
CT = CT or {}

local GUIFrame=nil

local W=820; local H=760; local TITLE_H=34; local SIDE_W=172; local SCRL_W=11
local PAGE_W=W-SIDE_W-SCRL_W-3; local ML=16; local EW=PAGE_W-ML-6

-- Live font registry: all GUI font strings register here so size changes apply instantly
local _guiFontStrings={}  -- {fs=fontString, base=baseSize}
local function GFS() return ConsumableTrackerDB and ConsumableTrackerDB.GUIFontSize or 11 end
local function GFSReg(fs,base)
    -- Register a font string for live resize; base is the size it was created at (11 default)
    table.insert(_guiFontStrings,{fs=fs,base=base or 11})
    return fs
end
local function GFSApplyAll()
    local scale=GFS()/11
    for _,entry in ipairs(_guiFontStrings) do
        if entry.fs and entry.fs.GetFont then
            local path,_,flags=entry.fs:GetFont()
            if path then entry.fs:SetFont(path,math.max(6,math.floor(entry.base*scale+0.5)),flags or "") end
        end
    end
end
-- Return the currently selected window's settings (for pages 1-3 which are per-window)
local _guiBuilding = false  -- suppresses CT:Refresh during page init
local _selectedWinIdx = 1   -- which window pages 1-3 currently edit
local function WinDB()
    local d = ConsumableTrackerDB
    if not d then return {} end
    -- Ensure Windows table exists and has at least one window
    if not d.Windows or #d.Windows == 0 then
        d.Windows = d.Windows or {}
        -- Bootstrap window 1 from existing top-level keys
        local w1 = { Name="Main Window", Slots=d.UnifiedIcons or {} }
        -- Copy any per-window settings that already exist at top level
        local WIN_KEYS = {
            "IconWidth","IconHeight","IconZoom","KeepAspectRatio","IconSkin","IconStrata",
            "ShowBorder","BorderSize","BorderColor","SwipeAlpha","DesatOnCooldown",
            "ShowQualityGem","GemSize","GemAnchor","GemShape",
            "AnchorPoint","AnchorToFrame","AnchorToPoint","X","Y","Locked",
            "ShowCount","CountTextSize","CountAnchor","CountTextX","CountTextY",
            "ShowCooldownText","CooldownTextSize","CooldownTextX","CooldownTextY","CooldownAnchor",
            "ScaleCDTextByIcon","FontPath","FontFlag","FontShadow",
            "GrowDirection","GrowSpacing","MaxIconsPerRow",
            "WrapDirection","WrapGrowDirection","WrapAnchor","RowSpacing",
        }
        for _,k in ipairs(WIN_KEYS) do
            if d[k] ~= nil then w1[k] = d[k] end
        end
        table.insert(d.Windows, w1)
    end
    -- Clamp selected index
    if _selectedWinIdx > #d.Windows then _selectedWinIdx = 1 end
    return d.Windows[_selectedWinIdx]
end
local function GDB() return ConsumableTrackerDB end

-- Returns true if a spell/equip/item slot already exists in the specified window
local function SlotExistsInWin(win, slotType, keyField, keyVal)
    for _,s in ipairs(win.Slots or {}) do
        if s.type==slotType and s[keyField]==keyVal then return true end
    end
    return false
end
-- Returns the window index where the slot already lives, or nil
local function SlotExistsInAnyWindow(slotType, keyField, keyVal)
    local d=ConsumableTrackerDB; if not d or not d.Windows then return nil end
    for wi,win in ipairs(d.Windows) do
        if SlotExistsInWin(win, slotType, keyField, keyVal) then return wi end
    end
    return nil
end



-- Equipment slots ordered as user requested
local EQUIP_SLOT_LIST={
    {label="Head",      slot=1},  {label="Neck",      slot=2},
    {label="Shoulders", slot=3},  {label="Back",       slot=15},
    {label="Chest",     slot=5},  {label="Wrist",      slot=9},
    {label="Hands",     slot=10}, {label="Belt",        slot=6},
    {label="Boots",     slot=8},  {label="Ring 1",      slot=11},
    {label="Ring 2",    slot=12}, {label="Trinket 1",   slot=13},
    {label="Trinket 2", slot=14}, {label="Main-Hand",   slot=16},
    {label="Off-Hand",  slot=17},
}
local SLOT_BY_NUMBER={}
for _,v in ipairs(EQUIP_SLOT_LIST) do SLOT_BY_NUMBER[v.slot]=v.label end

-- Type badge colours
local TYPE_COLORS={
    healthstone={0.60,0.20,0.80},
    group=      {0.24,0.49,0.73},
    spell=      {0.25,0.75,0.25},
    item=       {0.85,0.45,0.10},
    equip=      {0.10,0.65,0.65},
}
local TYPE_LABELS={healthstone="HS",group="GR",spell="SP",item="IT",equip="EQ"}

local function ClassHex()
    local _,cls=UnitClass("player")
    local cc=cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    if cc then return string.format("%02x%02x%02x",cc.r*255,cc.g*255,cc.b*255) end
    return "4d9aff"
end

local function BD(f,r,g,b,a,er,eg,eb,ea)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    f:SetBackdropColor(r or 0,g or 0,b or 0,a or 1)
    f:SetBackdropBorderColor(er or 0,eg or 0,eb or 0,ea or 1)
end

local function WHeader(page,text,y)
    local sep=page:CreateTexture(nil,"ARTWORK"); sep:SetHeight(1); sep:SetColorTexture(0.15,0.15,0.15,1)
    sep:SetPoint("TOPLEFT",page,"TOPLEFT",0,-y); sep:SetWidth(PAGE_W); y=y+5
    local fs=page:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    fs:SetText("|cFF"..ClassHex()..text.."|r")
    fs:SetPoint("TOP",page,"TOP",0,-y); fs:SetWidth(PAGE_W); fs:SetJustifyH("CENTER")
    GFSReg(fs,13)
    return y+24
end
local function WTip(page,text,x,y)
    local fs=page:CreateFontString(nil,"OVERLAY"); fs:SetFont("Fonts\\ARIALN.TTF",10,""); fs:SetTextColor(0.50,0.50,0.50,1)
    GFSReg(fs,10)
    fs:SetText(text); fs:SetPoint("TOP",page,"TOP",0,-y); fs:SetWidth(PAGE_W); fs:SetJustifyH("CENTER"); return y+16
end
local function WCheck(page,label,x,y,getV,setV)
    local cb=CreateFrame("CheckButton",nil,page,"BackdropTemplate")
    cb:SetSize(18,18); cb:SetPoint("TOPLEFT",page,"TOPLEFT",x-2,-(y-1))
    BD(cb,0.08,0.08,0.08,1,0.40,0.40,0.40)
    local check=cb:CreateTexture(nil,"OVERLAY")
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:SetAllPoints(); check:SetAlpha(0)
    local function Refresh()
        local v=getV()~=false
        check:SetAlpha(v and 1 or 0)
        if v then BD(cb,0.12,0.25,0.40,1,0.24,0.49,0.73) else BD(cb,0.08,0.08,0.08,1,0.40,0.40,0.40) end
    end
    Refresh()
    cb:SetScript("OnClick",function()
        setV(not (getV()~=false)); Refresh(); if CT.Refresh and not _guiBuilding then CT:Refresh() end
    end)
    cb:SetScript("OnLeave",function() Refresh() end)
    local lbl=page:CreateFontString(nil,"OVERLAY"); lbl:SetFont("Fonts\\ARIALN.TTF",GFS(),"")
    GFSReg(lbl,11)
    lbl:SetTextColor(0.90,0.90,0.90,1); lbl:SetText(label)
    lbl:SetPoint("TOP",page,"TOP",0,-y)
    lbl:SetWidth(PAGE_W); lbl:SetHeight(18); lbl:SetJustifyH("CENTER"); lbl:SetJustifyV("MIDDLE")
    return y+24
end
local function WSlider(page,label,minV,maxV,x,y,getV,setV,w,step)
    w=w or EW; step=step or 1
    local function Fmt(v)
        if step<0.05 then return string.format("%.2f",v)
        elseif step<0.5 then return string.format("%.1f",v)
        else return tostring(math.floor(v+0.5)) end
    end
    local function Snap(v) v=math.max(minV,math.min(maxV,v)); return math.floor(v/step+0.5)*step end
    local lbl=page:CreateFontString(nil,"OVERLAY"); lbl:SetFont("Fonts\\ARIALN.TTF",GFS(),""); lbl:SetTextColor(0.9,0.9,0.9,1)
    GFSReg(lbl,11)
    lbl:SetText(label); lbl:SetPoint("TOP",page,"TOP",0,-y); lbl:SetWidth(PAGE_W); lbl:SetJustifyH("CENTER")
    local vb=CreateFrame("EditBox",nil,page,"InputBoxTemplate"); vb:SetSize(64,19); vb:SetPoint("TOPLEFT",page,"TOPLEFT",x+w-64,-(y+1))
    GFSReg(vb,11)
    vb:SetAutoFocus(false)
    vb:SetTextColor(1.0,0.82,0.0,1); vb:SetTextInsets(4,4,0,0); vb:SetJustifyH("CENTER")
    local tr=CreateFrame("Frame",nil,page,"BackdropTemplate"); tr:SetPoint("TOPLEFT",page,"TOPLEFT",x,-(y+24)); tr:SetSize(w,8)
    BD(tr,0.09,0.09,0.09,1,0.22,0.22,0.22)
    local fill=tr:CreateTexture(nil,"ARTWORK"); fill:SetColorTexture(0.24,0.49,0.73,1)
    fill:SetPoint("TOPLEFT",tr,"TOPLEFT",1,-1); fill:SetPoint("BOTTOMLEFT",tr,"BOTTOMLEFT",1,1); fill:SetWidth(1)
    local lmi=page:CreateFontString(nil,"OVERLAY"); lmi:SetFont("Fonts\\ARIALN.TTF",9,""); lmi:SetTextColor(0.45,0.45,0.45,1)
    lmi:SetText(Fmt(minV)); lmi:SetPoint("TOPLEFT",tr,"BOTTOMLEFT",0,-2)
    local lma=page:CreateFontString(nil,"OVERLAY"); lma:SetFont("Fonts\\ARIALN.TTF",9,""); lma:SetTextColor(0.45,0.45,0.45,1)
    lma:SetText(Fmt(maxV)); lma:SetPoint("TOPRIGHT",tr,"BOTTOMRIGHT",0,-2)
    local sl=CreateFrame("Slider",nil,page); sl:SetPoint("TOPLEFT",tr,"TOPLEFT",0,4); sl:SetPoint("TOPRIGHT",tr,"TOPRIGHT",0,4)
    sl:SetHeight(16); sl:SetMinMaxValues(minV,maxV); sl:SetValueStep(step); sl:SetObeyStepOnDrag(true)
    sl:SetOrientation("HORIZONTAL"); sl:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local th=sl:GetThumbTexture(); th:SetSize(8,16); th:SetColorTexture(0.24,0.49,0.73,1)
    local busy=false
    local function Refill(v) local tw=tr:GetWidth()-2; if tw>1 then fill:SetWidth(math.max(1,tw*((v-minV)/math.max(0.001,maxV-minV)))) end end
    local function Sync(v)
        if busy then return end; busy=true; v=Snap(v); sl:SetValue(v); vb:SetText(Fmt(v)); Refill(v); setV(v)
        if CT.Refresh and not _guiBuilding then CT:Refresh() end; busy=false
    end
    sl:SetScript("OnValueChanged",function(_,v) Sync(v) end)
    vb:SetScript("OnEnterPressed",function(sv) Sync(tonumber(sv:GetText()) or getV()); sv:ClearFocus() end)
    vb:SetScript("OnEscapePressed",function(sv) sv:SetText(Fmt(getV())); sv:ClearFocus() end)
    sl:SetValue(getV()); vb:SetText(Fmt(getV())); Refill(getV())
    C_Timer.After(0.08,function() Refill(getV()) end)
    return y+56
end
local function WColor(page,label,x,y,getC,setC)
    local lbl=page:CreateFontString(nil,"OVERLAY"); lbl:SetFont("Fonts\\ARIALN.TTF",GFS(),""); lbl:SetTextColor(0.9,0.9,0.9,1)
    lbl:SetText(label); lbl:SetPoint("TOP",page,"TOP",0,-y); lbl:SetWidth(PAGE_W); lbl:SetJustifyH("CENTER")
    local sw=CreateFrame("Button",nil,page,"BackdropTemplate"); sw:SetSize(50,16); sw:SetPoint("TOPLEFT",page,"TOPLEFT",ML,-y)
    local function Ref() local c=getC(); BD(sw,c[1],c[2],c[3],c[4] or 1,0.22,0.22,0.22) end; Ref()
    sw:SetScript("OnClick",function()
        local c=getC(); local prev={c[1],c[2],c[3],c[4] or 1}
        local function Apply() local r,g,b=ColorPickerFrame:GetColorRGB(); local a=1-(ColorPickerFrame:GetColorAlpha() or 0)
            setC({r,g,b,a}); Ref(); if CT.Refresh and not _guiBuilding then CT:Refresh() end end
        ColorPickerFrame:SetupColorPickerAndShow({swatchFunc=Apply,opacityFunc=Apply,
            cancelFunc=function() setC(prev); Ref(); if CT.Refresh and not _guiBuilding then CT:Refresh() end end,
            hasOpacity=true,opacity=1-(c[4] or 1),r=c[1],g=c[2],b=c[3]})
    end)
    sw:SetScript("OnEnter",function() sw:SetBackdropBorderColor(0.24,0.49,0.73,1) end)
    sw:SetScript("OnLeave",function() Ref() end)
    return y+24
end
local _openDrop=nil
local function WDropdown(page,label,items,x,y,w,getV,setV)
    w=w or 200
    if label and label~="" then
        local fs=page:CreateFontString(nil,"OVERLAY"); fs:SetFont("Fonts\\ARIALN.TTF",GFS(),"")
        fs:SetTextColor(0.9,0.9,0.9,1); fs:SetText(label); fs:SetPoint("TOP",page,"TOP",0,-y); fs:SetWidth(PAGE_W); fs:SetJustifyH("CENTER"); y=y+16
    end
    local bar=CreateFrame("Button",nil,page,"BackdropTemplate"); bar:SetSize(w,20); bar:SetPoint("TOPLEFT",page,"TOPLEFT",x,-y)
    BD(bar,0.09,0.09,0.09,1,0.22,0.22,0.22)
    local cur=bar:CreateFontString(nil,"OVERLAY"); cur:SetFont("Fonts\\ARIALN.TTF",GFS(),""); cur:SetTextColor(0.9,0.9,0.9,1)
    cur:SetPoint("LEFT",bar,"LEFT",6,0); cur:SetPoint("RIGHT",bar,"RIGHT",-18,0); cur:SetJustifyH("LEFT")
    local arr=bar:CreateFontString(nil,"OVERLAY"); arr:SetFont("Fonts\\ARIALN.TTF",GFS(),""); arr:SetTextColor(0.5,0.5,0.5,1)
    arr:SetText("v"); arr:SetPoint("RIGHT",bar,"RIGHT",-5,0)
    local function GL(v) for _,it in ipairs(items) do if it.value==v then return it.label end end; return tostring(v or "") end
    cur:SetText(GL(getV()))
    bar:SetScript("OnClick",function()
        if _openDrop then _openDrop:Hide(); if _openDrop==bar._pop then _openDrop=nil; return end; _openDrop=nil end
        local IH=18; local vis=math.min(#items,10)
        local pop=CreateFrame("Frame",nil,UIParent,"BackdropTemplate"); pop:SetWidth(w); pop:SetHeight(vis*IH+2)
        pop:SetPoint("TOPLEFT",bar,"BOTTOMLEFT",0,-1); pop:SetFrameStrata("TOOLTIP"); pop:SetFrameLevel(300)
        BD(pop,0.08,0.08,0.08,1,0.24,0.49,0.73)
        local clip=CreateFrame("Frame",nil,pop); clip:SetClipsChildren(true)
        clip:SetPoint("TOPLEFT",pop,"TOPLEFT",1,-1); clip:SetPoint("BOTTOMRIGHT",pop,"BOTTOMRIGHT",-1,1)
        local inner=CreateFrame("Frame",nil,clip); inner:SetWidth(w-2); inner:SetHeight(#items*IH); inner:SetPoint("TOPLEFT")
        inner:EnableMouseWheel(true); local off=0
        inner:SetScript("OnMouseWheel",function(_,d)
            off=math.max(0,math.min(math.max(0,#items*IH-vis*IH),off-d*IH*2)); inner:SetPoint("TOPLEFT",clip,"TOPLEFT",0,off)
        end)
        for i,it in ipairs(items) do
            local row=CreateFrame("Button",nil,inner,"BackdropTemplate")
            row:SetPoint("TOPLEFT",inner,"TOPLEFT",0,-(i-1)*IH); row:SetPoint("TOPRIGHT",inner,"TOPRIGHT",0,-(i-1)*IH); row:SetHeight(IH)
            local act=(it.value==getV()); BD(row,act and 0.18 or 0.09,act and 0.37 or 0.09,act and 0.58 or 0.09,1,0,0,0)
            local rl=row:CreateFontString(nil,"OVERLAY"); rl:SetFont("Fonts\\ARIALN.TTF",GFS(),""); rl:SetTextColor(0.9,0.9,0.9,1)
            rl:SetText(it.label); rl:SetPoint("LEFT",row,"LEFT",6,0)
            row:SetScript("OnEnter",function() row:SetBackdropColor(0.18,0.18,0.18,1); rl:SetTextColor(1,1,1,1) end)
            row:SetScript("OnLeave",function() row:SetBackdropColor(act and 0.18 or 0.09,act and 0.37 or 0.09,act and 0.58 or 0.09,1); rl:SetTextColor(0.9,0.9,0.9,1) end)
            row:SetScript("OnClick",function() setV(it.value); cur:SetText(it.label); if CT.Refresh and not _guiBuilding then CT:Refresh() end; pop:Hide(); _openDrop=nil end)
        end
        bar._pop=pop; _openDrop=pop
    end)
    return y+28,bar,cur
end
local function WButton(page,label,x,y,w,h,onClick)
    w=w or 130; h=h or 22
    local b=CreateFrame("Button",nil,page,"BackdropTemplate"); b:SetSize(w,h); b:SetPoint("TOPLEFT",page,"TOPLEFT",x,-y)
    BD(b,0.11,0.11,0.11,1,0.22,0.22,0.22)
    local l=b:CreateFontString(nil,"OVERLAY"); l:SetFont("Fonts\\ARIALN.TTF",GFS(),""); l:SetTextColor(0.9,0.9,0.9,1)
    l:SetText(label); l:SetAllPoints(); l:SetJustifyH("CENTER")
    b:SetScript("OnLeave",function() BD(b,0.11,0.11,0.11,1,0.22,0.22,0.22); l:SetTextColor(0.9,0.9,0.9,1) end)
    b:SetScript("OnClick",onClick); return y+h+8
end

-- Data tables
local ANCHORS={{label="CENTER",value="CENTER"},{label="TOP",value="TOP"},{label="BOTTOM",value="BOTTOM"},
    {label="LEFT",value="LEFT"},{label="RIGHT",value="RIGHT"},{label="TOPLEFT",value="TOPLEFT"},
    {label="TOPRIGHT",value="TOPRIGHT"},{label="BOTTOMLEFT",value="BOTTOMLEFT"},{label="BOTTOMRIGHT",value="BOTTOMRIGHT"}}
local ANCHOR_FRAMES={{label="Screen (UIParent)",value="UIParent"},{label="Player Frame",value="PlayerFrame"},
    {label="Target Frame",value="TargetFrame"},{label="Focus Frame",value="FocusFrame"},
    {label="Target of Target",value="TargetTargetFrame"},{label="Minimap",value="Minimap"},
    {label="ElvUI Player",value="ElvUF_Player"},{label="ElvUI Target",value="ElvUF_Target"},
    {label="ElvUI Focus",value="ElvUF_Focus"},{label="Custom (see below)",value="_custom_"}}
local GROW_DIRS={{label="Right",value="RIGHT"},{label="Left",value="LEFT"},{label="Up",value="UP"},{label="Down",value="DOWN"}}
local FONT_FLAGS={{label="Outline",value="OUTLINE"},{label="Thick Outline",value="THICKOUTLINE"},{label="Monochrome",value="MONOCHROME"},{label="None",value=""}}

local function BuildFontList()
    local list,seen={},{}
    local AP="Interface\\AddOns\\FabsResourceTracker\\"
    local function Add(lbl,path) if not seen[path] then seen[path]=true; table.insert(list,{label=lbl,value=path}) end end
    Add("Expressway (bundled)",AP.."Expressway.ttf"); Add("Arial Narrow","Fonts\\ARIALN.TTF")
    Add("Friz Quadrata","Fonts\\FRIZQT__.TTF"); Add("Morpheus","Fonts\\MORPHEUS.TTF"); Add("Skurri","Fonts\\skurri.TTF")
    if ElvUI and ElvUI[1] and ElvUI[1].media then local m=ElvUI[1].media
        if m.normFont then Add("ElvUI Normal",m.normFont) end
        if m.combatFont then Add("ElvUI Combat",m.combatFont) end end
    local LSM=LibStub and LibStub("LibSharedMedia-3.0",true)
    if LSM then for nm,path in pairs(LSM:HashTable("font") or {}) do Add(nm,path) end end
    table.sort(list,function(a,b) return a.label<b.label end); return list
end

-- ============================================================
-- Order Arrows — tune these constants to adjust placement
-- ============================================================

-- Overall compound frame
local ARROW_BTN_W     = 26    -- width of each individual button (up or down)
local ARROW_BTN_H     = 24    -- height of each individual button
local ARROW_GAP       = 2     -- gap in pixels between the two buttons
local ARROW_RIGHT_PAD = 4     -- distance from right edge of parent row
local ARROW_VERT_PAD  = 0     -- extra vertical nudge of whole compound (+ = up, - = down)

-- Up arrow icon
local UP_ICON_W    = 16   -- texture width
local UP_ICON_H    = 16   -- texture height
local UP_ICON_OX   = 1    -- X offset from button center (+ = right, - = left)
local UP_ICON_OY   = 2    -- Y offset from button center (+ = up,   - = down)

-- Down arrow icon
local DN_ICON_W    = 16   -- texture width
local DN_ICON_H    = 16   -- texture height
local DN_ICON_OX   = 1    -- X offset from button center (+ = right, - = left)
local DN_ICON_OY   = -6   -- Y offset from button center (+ = up,   - = down)

local ARROW_W = ARROW_BTN_W * 2 + ARROW_GAP  -- total compound width
local ARROW_H = ARROW_BTN_H

local function MakeOrderArrows(parent, ROW_H, onUp, onDown)
    local compound = CreateFrame("Frame", nil, parent)
    compound:SetSize(ARROW_W, ARROW_H)
    compound:ClearAllPoints()
    local parentH = ROW_H or 46
    local yOff = -(parentH / 2 - ARROW_H / 2) + ARROW_VERT_PAD
    compound:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -ARROW_RIGHT_PAD, yOff)
    compound:EnableMouse(false)

    local function MkBtn(icon, ox, oy, iw, ih, onClickFn)
        local btn = CreateFrame("Button", nil, compound, "BackdropTemplate")
        btn:SetSize(ARROW_BTN_W, ARROW_BTN_H)
        BD(btn, 0.10, 0.10, 0.14, 1, 0.28, 0.28, 0.40)
        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(icon)
        tex:SetSize(iw, ih)
        tex:SetPoint("CENTER", btn, "CENTER", ox, oy)
        local hi = btn:CreateTexture(nil, "HIGHLIGHT")
        hi:SetAllPoints(btn); hi:SetColorTexture(1, 1, 1, 0.12)
        btn:SetScript("OnEnter", function()
            btn:SetBackdropColor(0.18, 0.37, 0.58, 1)
            btn:SetBackdropBorderColor(0.35, 0.60, 0.90, 1)
        end)
        btn:SetScript("OnLeave", function()
            BD(btn, 0.10, 0.10, 0.14, 1, 0.28, 0.28, 0.40)
        end)
        btn:SetScript("OnClick", onClickFn)
        return btn
    end

    local upBtn = MkBtn("Interface\\Buttons\\Arrow-Up-Up",
        UP_ICON_OX, UP_ICON_OY, UP_ICON_W, UP_ICON_H, onUp)
    upBtn:SetPoint("LEFT", compound, "LEFT", 0, 0)

    local sep = compound:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(0.22, 0.22, 0.30, 1)
    sep:SetSize(1, ARROW_BTN_H)
    sep:SetPoint("LEFT", compound, "LEFT", ARROW_BTN_W + math.floor(ARROW_GAP/2), 0)

    local dnBtn = MkBtn("Interface\\Buttons\\Arrow-Down-Up",
        DN_ICON_OX, DN_ICON_OY, DN_ICON_W, DN_ICON_H, onDown)
    dnBtn:SetPoint("LEFT", compound, "LEFT", ARROW_BTN_W + ARROW_GAP, 0)

    return upBtn, dnBtn, compound
end

-- ============================================================
-- PAGE 1: Icon & Border
-- ============================================================
local function BuildPageIcon(page)
    local y=10
    y=WHeader(page,"Icon Size",y)
    y=WTip(page,"Supports 0.01 decimals (e.g. 44.91).",ML,y)
    y=WSlider(page,"Width", 12,64,ML,y,function() return WinDB().IconWidth  end,function(v) WinDB().IconWidth=v  end,EW,0.01)
    y=WSlider(page,"Height",12,64,ML,y,function() return WinDB().IconHeight end,function(v) WinDB().IconHeight=v end,EW,0.01)
    y=WHeader(page,"Icon Crop / Zoom",y)
    y=WSlider(page,"Zoom  (0 = raw  /  higher = crop edges)",0,20,ML,y,function() return WinDB().IconZoom or 0 end,function(v) WinDB().IconZoom=v end,EW)
    y=WCheck(page,"Keep aspect ratio",ML,y,function() return WinDB().KeepAspectRatio~=false end,function(v) WinDB().KeepAspectRatio=v end)
    y=WHeader(page,"Cooldown Swipe",y)
    y=WCheck(page,"Hide GCD  (suppress short ≤1.5s cooldowns)",ML,y,function() return WinDB().HideGCD~=false end,function(v) WinDB().HideGCD=v end)
    y=WSlider(page,"Swipe opacity  (0 = transparent  /  100 = fully opaque)",0,100,ML,y,function() return WinDB().SwipeAlpha or 65 end,function(v) WinDB().SwipeAlpha=v end,EW)
    y=WHeader(page,"Desaturate",y)
    y=WCheck(page,"Desaturate while on cooldown",ML,y,function() return WinDB().DesatOnCooldown or false end,function(v) WinDB().DesatOnCooldown=v end)
    y=WTip(page,"Items always desaturate when count is 0.",ML,y)
    y=WCheck(page,"Show tooltip on hover",ML,y,function() return GDB().ShowTooltips~=false end,function(v) GDB().ShowTooltips=v end)
    y=WHeader(page,"Border",y)
    y=WCheck(page,"Show border",ML,y,function() return WinDB().ShowBorder~=false end,function(v) WinDB().ShowBorder=v end)
    y=WDropdown(page,"Border style:",{
        {label="No border",      value="none"},
        {label="Solid colour",   value="solid"},
        {label="Tooltip",        value="tooltip"},
        {label="Achievement",    value="achievement"},
        {label="Dialog",         value="dialog"},
        {label="Glow",           value="glow"},
        {label="Party frame",    value="party"},
    },ML,y,220,
        function() return WinDB().BorderStyle or "solid" end,
        function(v) WinDB().BorderStyle=v end)
    y=WSlider(page,"Border thickness",1,10,ML,y,function() return WinDB().BorderSize or 1 end,function(v) WinDB().BorderSize=v end,EW)
    y=WColor(page,"Default border colour",ML,y,function() return WinDB().BorderColor or {0,0,0,1} end,function(c) WinDB().BorderColor=c end)
end

-- ============================================================

local function FlashBtn(btn, lbl, successText, originalText, origR, origG, origB, origBr, origBg, origBb)
    BD(btn, 0.06,0.28,0.06,1, 0.20,0.80,0.20)
    lbl:SetTextColor(0.4,1,0.4,1); lbl:SetText(successText or "Added!")
    C_Timer.After(1.5, function()
        if btn and btn.GetObjectType then
            BD(btn, origR or 0.11, origG or 0.11, origB or 0.11, 1, origBr or 0.22, origBg or 0.22, origBb or 0.22)
            lbl:SetTextColor(0.25,0.75,0.25,1); lbl:SetText(originalText)
        end
    end)
end
local function FlashBtnErr(btn, lbl, errText, originalText, origR, origG, origB, origBr, origBg, origBb)
    BD(btn, 0.28,0.06,0.06,1, 0.80,0.20,0.20)
    lbl:SetTextColor(1,0.4,0.4,1); lbl:SetText(errText or "Already added")
    C_Timer.After(1.5, function()
        if btn and btn.GetObjectType then
            BD(btn, origR or 0.11, origG or 0.11, origB or 0.11, 1, origBr or 0.22, origBg or 0.22, origBb or 0.22)
            lbl:SetTextColor(0.25,0.75,0.25,1); lbl:SetText(originalText)
        end
    end)
end

local function BuildPagePosition(page)
    local y=10
    y=WHeader(page,"Anchor",y)
    y=WDropdown(page,"Anchor to frame preset:",ANCHOR_FRAMES,ML,y,270,
        function() for _,it in ipairs(ANCHOR_FRAMES) do if it.value==WinDB().AnchorToFrame then return it.value end end; return "_custom_" end,
        function(v) if v~="_custom_" then WinDB().AnchorToFrame=v end end)
    local cfLbl=page:CreateFontString(nil,"OVERLAY"); cfLbl:SetFont("Fonts\\ARIALN.TTF",GFS(),""); cfLbl:SetTextColor(0.9,0.9,0.9,1)
    cfLbl:SetText("Custom frame name:"); cfLbl:SetPoint("TOPLEFT",page,"TOPLEFT",ML,-y); cfLbl:SetWidth(EW); y=y+16
    local cfBox=CreateFrame("EditBox",nil,page,"InputBoxTemplate"); cfBox:SetSize(270,20); cfBox:SetPoint("TOPLEFT",page,"TOPLEFT",ML,-y)
    cfBox:SetAutoFocus(false)
    cfBox:SetTextColor(0.9,0.9,0.9,1); cfBox:SetTextInsets(6,6,0,0); cfBox:SetText(WinDB().AnchorToFrame or "UIParent")
    cfBox:SetScript("OnEscapePressed",function(sv) sv:ClearFocus() end)
    cfBox:SetScript("OnEnterPressed",function(sv) WinDB().AnchorToFrame=sv:GetText(); if CT.Refresh and not _guiBuilding then CT:Refresh() end; sv:ClearFocus() end)
    y=y+28; y=WTip(page,"e.g. PlayerFrame, ElvUF_Player, Minimap, UIParent",ML,y)
    local apLbl=page:CreateFontString(nil,"OVERLAY"); apLbl:SetFont("Fonts\\ARIALN.TTF",GFS(),""); apLbl:SetTextColor(0.9,0.9,0.9,1); apLbl:SetText("Icon anchor:"); apLbl:SetPoint("TOPLEFT",page,"TOPLEFT",ML,-y)
    local rpLbl=page:CreateFontString(nil,"OVERLAY"); rpLbl:SetFont("Fonts\\ARIALN.TTF",GFS(),""); rpLbl:SetTextColor(0.9,0.9,0.9,1); rpLbl:SetText("Target point:"); rpLbl:SetPoint("TOPLEFT",page,"TOPLEFT",ML+260,-y); y=y+16
    WDropdown(page,"",ANCHORS,ML,y,240,function() return WinDB().AnchorPoint or "CENTER" end,function(v) WinDB().AnchorPoint=v end)
    WDropdown(page,"",ANCHORS,ML+260,y,240,function() return WinDB().AnchorToPoint or "CENTER" end,function(v) WinDB().AnchorToPoint=v end); y=y+28

    -- ---- Window-to-Window Anchor ----
    y=WHeader(page,"Anchor to Another Window",y)
    y=WTip(page,"Snap this window to another Fabs Resource Tracker window.",ML,y)

    -- Build a list of other windows dynamically
    local function GetOtherWindows()
        local list={}; local d=ConsumableTrackerDB; if not d or not d.Windows then return list end
        for i,w in ipairs(d.Windows) do
            if d.Windows[i]~=WinDB() then
                table.insert(list,{label=(w.Name or "Window "..i).." (FabsWin_"..i..")", value="FabsWin_"..i})
            end
        end
        if #list==0 then table.insert(list,{label="No other windows",value=""}) end
        return list
    end

    local winAnchorTarget=""
    local winAnchorMyPt="LEFT"
    local winAnchorTheirPt="RIGHT"

    -- Target window dropdown
    local wtLbl=page:CreateFontString(nil,"OVERLAY"); wtLbl:SetFont("Fonts\\ARIALN.TTF",GFS(),""); wtLbl:SetTextColor(0.9,0.9,0.9,1)
    wtLbl:SetText("Attach to window:"); wtLbl:SetPoint("TOP",page,"TOP",0,-y); wtLbl:SetWidth(PAGE_W); wtLbl:SetJustifyH("CENTER"); y=y+16
    local wtBar=CreateFrame("Button",nil,page,"BackdropTemplate"); wtBar:SetSize(220,20); wtBar:SetPoint("TOPLEFT",page,"TOPLEFT",ML,-y)
    BD(wtBar,0.09,0.09,0.09,1,0.22,0.22,0.22)
    local wtCur=wtBar:CreateFontString(nil,"OVERLAY"); wtCur:SetFont("Fonts\\ARIALN.TTF",GFS(),""); wtCur:SetTextColor(0.9,0.9,0.9,1)
    wtCur:SetPoint("LEFT",wtBar,"LEFT",6,0); wtCur:SetPoint("RIGHT",wtBar,"RIGHT",-18,0); wtCur:SetJustifyH("LEFT")
    wtCur:SetText("Select window...")
    local wtArr=wtBar:CreateFontString(nil,"OVERLAY"); wtArr:SetFont("Fonts\\ARIALN.TTF",9,""); wtArr:SetTextColor(0.5,0.5,0.5,1); wtArr:SetText("v"); wtArr:SetPoint("RIGHT",wtBar,"RIGHT",-4,0)
    wtBar:SetScript("OnClick",function()
        local items=GetOtherWindows(); local menu={}
        for _,it in ipairs(items) do
            if it.value~="" then
                local capV=it.value; local capL=it.label
                table.insert(menu,{label=capL, onClick=function()
                    winAnchorTarget=capV; wtCur:SetText(capL)
                end})
            end
        end
        if #menu>0 then CT._ShowDropMenu(wtBar,menu)
        else ShowStat("|cFFFF9900No other windows to anchor to|r") end
    end); y=y+28

    -- My anchor point / their anchor point
    local maLbl=page:CreateFontString(nil,"OVERLAY"); maLbl:SetFont("Fonts\\ARIALN.TTF",GFS(),""); maLbl:SetTextColor(0.9,0.9,0.9,1); maLbl:SetText("My point:"); maLbl:SetPoint("TOPLEFT",page,"TOPLEFT",ML,-y)
    local taLbl=page:CreateFontString(nil,"OVERLAY"); taLbl:SetFont("Fonts\\ARIALN.TTF",GFS(),""); taLbl:SetTextColor(0.9,0.9,0.9,1); taLbl:SetText("Their point:"); taLbl:SetPoint("TOPLEFT",page,"TOPLEFT",ML+200,-y); y=y+16

    local _,_,myPtDrop=WDropdown(page,"",ANCHORS,ML,y,180,function() return winAnchorMyPt end,function(v) winAnchorMyPt=v end)
    local _,_,thPtDrop=WDropdown(page,"",ANCHORS,ML+200,y,180,function() return winAnchorTheirPt end,function(v) winAnchorTheirPt=v end)
    y=y+30

    -- Apply button
    local applyWABtn=CreateFrame("Button",nil,page,"BackdropTemplate"); applyWABtn:SetSize(EW,24); applyWABtn:SetPoint("TOPLEFT",page,"TOPLEFT",ML,-y)
    BD(applyWABtn,0.08,0.14,0.22,1,0.24,0.49,0.73)
    local awl=applyWABtn:CreateFontString(nil,"OVERLAY"); awl:SetFont("Fonts\\ARIALN.TTF",GFS(),""); awl:SetTextColor(0.5,0.8,1.0,1)
    awl:SetText("Apply Window Anchor"); awl:SetAllPoints(); awl:SetJustifyH("CENTER")
    applyWABtn:SetScript("OnEnter",function() applyWABtn:SetBackdropColor(0.12,0.22,0.38,1); applyWABtn:SetBackdropBorderColor(0.35,0.65,1.0,1); awl:SetTextColor(1,1,1,1) end)
    applyWABtn:SetScript("OnLeave",function() BD(applyWABtn,0.08,0.14,0.22,1,0.24,0.49,0.73); awl:SetTextColor(0.5,0.8,1.0,1) end)
    applyWABtn:SetScript("OnClick",function()
        if not winAnchorTarget or winAnchorTarget=="" then ShowStat("|cFFFF4444Select a target window first|r"); return end
        WinDB().AnchorToFrame = winAnchorTarget
        WinDB().AnchorPoint   = winAnchorMyPt
        WinDB().AnchorToPoint = winAnchorTheirPt
        WinDB().X = 0; WinDB().Y = 0
        cfBox:SetText(winAnchorTarget)
        -- RefreshLayout (full rebuild) so FabsWin_ globals are registered in window order
        if CT.RefreshLayout then CT:RefreshLayout() end
        if CT.SyncPositionGUI then CT.SyncPositionGUI() end
        FlashBtn(applyWABtn,awl,"Anchored!","Apply Window Anchor",0.08,0.14,0.22,0.24,0.49,0.73)
    end); y=y+30
    y=WHeader(page,"Offset",y)
    local slX,vbX,slY,vbY
    local function MkPosSlider(lbl,isX)
        local minV,maxV=isX and -1500 or -1000,isX and 1500 or 1000
        local getV=isX and function() return WinDB().X or 0 end or function() return WinDB().Y or 0 end
        local setV=isX and function(v) WinDB().X=v end or function(v) WinDB().Y=v end; local w=EW
        local function Fmt(v) return tostring(math.floor(v+0.5)) end
        local function Snap(v) return math.floor(v+0.5) end
        local lbl2=page:CreateFontString(nil,"OVERLAY"); lbl2:SetFont("Fonts\\ARIALN.TTF",GFS(),""); lbl2:SetTextColor(0.9,0.9,0.9,1); lbl2:SetText(lbl); lbl2:SetPoint("TOPLEFT",page,"TOPLEFT",0,-y); lbl2:SetWidth(w+ML); lbl2:SetJustifyH("CENTER")
        local vb=CreateFrame("EditBox",nil,page,"InputBoxTemplate"); vb:SetSize(64,19); vb:SetPoint("TOPLEFT",page,"TOPLEFT",ML+w-64,-(y+1))
        vb:SetAutoFocus(false); vb:SetFont("Fonts\\ARIALN.TTF",GFS(),""); vb:SetTextColor(1.0,0.82,0.0,1); vb:SetTextInsets(4,4,0,0); vb:SetJustifyH("CENTER")
        local tr=CreateFrame("Frame",nil,page,"BackdropTemplate"); tr:SetPoint("TOPLEFT",page,"TOPLEFT",ML,-(y+24)); tr:SetSize(w,8); BD(tr,0.09,0.09,0.09,1,0.22,0.22,0.22)
        local fill=tr:CreateTexture(nil,"ARTWORK"); fill:SetColorTexture(0.24,0.49,0.73,1); fill:SetPoint("TOPLEFT",tr,"TOPLEFT",1,-1); fill:SetPoint("BOTTOMLEFT",tr,"BOTTOMLEFT",1,1); fill:SetWidth(1)
        local lmi2=page:CreateFontString(nil,"OVERLAY"); lmi2:SetFont("Fonts\\ARIALN.TTF",9,""); lmi2:SetTextColor(0.45,0.45,0.45,1); lmi2:SetText(Fmt(minV)); lmi2:SetPoint("TOPLEFT",tr,"BOTTOMLEFT",0,-2)
        local lma2=page:CreateFontString(nil,"OVERLAY"); lma2:SetFont("Fonts\\ARIALN.TTF",9,""); lma2:SetTextColor(0.45,0.45,0.45,1); lma2:SetText(Fmt(maxV)); lma2:SetPoint("TOPRIGHT",tr,"BOTTOMRIGHT",0,-2)
        local sl=CreateFrame("Slider",nil,page); sl:SetPoint("TOPLEFT",tr,"TOPLEFT",0,4); sl:SetPoint("TOPRIGHT",tr,"TOPRIGHT",0,4)
        sl:SetHeight(16); sl:SetMinMaxValues(minV,maxV); sl:SetValueStep(1); sl:SetObeyStepOnDrag(true); sl:SetOrientation("HORIZONTAL"); sl:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
        local th=sl:GetThumbTexture(); th:SetSize(8,16); th:SetColorTexture(0.24,0.49,0.73,1)
        local busy=false
        local function Refill(v) local tw=tr:GetWidth()-2; if tw>1 then fill:SetWidth(math.max(1,tw*((v-minV)/math.max(1,maxV-minV)))) end end
        local function Sync(v) if busy then return end; busy=true; v=Snap(math.max(minV,math.min(maxV,v))); sl:SetValue(v); vb:SetText(Fmt(v)); Refill(v); setV(v); if CT.Refresh and not _guiBuilding then CT:Refresh() end; busy=false end
        sl:SetScript("OnValueChanged",function(_,v) Sync(v) end)
        vb:SetScript("OnEnterPressed",function(sv) Sync(tonumber(sv:GetText()) or getV()); sv:ClearFocus() end)
        sl:SetValue(getV()); vb:SetText(Fmt(getV())); Refill(getV()); C_Timer.After(0.08,function() Refill(getV()) end)
        return sl,vb,y+56
    end
    slX,vbX,y=MkPosSlider("X offset",true); slY,vbY,y=MkPosSlider("Y offset",false)
    CT.SyncPositionGUI=function()
        local d=WinDB(); local function Fv(v) return tostring(math.floor(v+0.5)) end
        slX:SetValue(d.X or 0); vbX:SetText(Fv(d.X or 0)); slY:SetValue(d.Y or 0); vbY:SetText(Fv(d.Y or 0))
    end
    y=WHeader(page,"Layout",y)
    y=WDropdown(page,"Grow direction:",GROW_DIRS,ML,y,180,function() return WinDB().GrowDirection or "RIGHT" end,function(v) WinDB().GrowDirection=v; if not _guiBuilding then CT:RefreshLayout() end end)
    y=WSlider(page,"Spacing between icons",0,40,ML,y,function() return WinDB().GrowSpacing or 4 end,function(v) WinDB().GrowSpacing=v; if not _guiBuilding then CT:RefreshLayout() end end,EW)
    y=WHeader(page,"Row Wrap",y)
    y=WTip(page,"Limit icons per row. Extra rows grow in the wrap direction.",ML,y)
    y=WSlider(page,"Max icons per row  (0 = no wrap)",0,30,ML,y,function() return WinDB().MaxIconsPerRow or 0 end,function(v)
        WinDB().MaxIconsPerRow=math.floor(v+0.5); if not _guiBuilding then CT:RefreshLayout() end
    end,EW)
    y=WSlider(page,"Row spacing",0,60,ML,y,function() return WinDB().RowSpacing or 4 end,function(v)
        WinDB().RowSpacing=math.floor(v+0.5); if not _guiBuilding then CT:RefreshLayout() end
    end,EW)
    y=WDropdown(page,"Wrap direction  (where new rows appear):",
        {{label="Down",value="DOWN"},{label="Up",value="UP"}},
        ML,y,200,
        function() return WinDB().WrapDirection or "DOWN" end,
        function(v) WinDB().WrapDirection=v; if not _guiBuilding then CT:RefreshLayout() end end)
    y=WDropdown(page,"Row grow direction  (icon order within each wrapped row):",
        GROW_DIRS,ML,y,200,
        function() return WinDB().WrapGrowDirection or "RIGHT" end,
        function(v) WinDB().WrapGrowDirection=v; if not _guiBuilding then CT:RefreshLayout() end end)
    y=WDropdown(page,"Row start alignment:",
        {{label="Align with first icon of previous row",value="FIRST"},
         {label="Align with last icon of previous row", value="LAST"}},
        ML,y,360,
        function() return WinDB().WrapAnchor or "FIRST" end,
        function(v) WinDB().WrapAnchor=v; if not _guiBuilding then CT:RefreshLayout() end end)
    y=WHeader(page,"Options",y)
    y=WCheck(page,"Lock position (disable dragging)",ML,y,function() return WinDB().Locked end,function(v)
        WinDB().Locked=v
        -- Update drag on the first icon of this window immediately
        local d2=ConsumableTrackerDB
        if d2 and d2.Windows then
            for wi,win in ipairs(d2.Windows) do
                if win==db then
                    local state=CT._windowStates and CT._windowStates[wi]
                    if state and state.structs and #state.structs>0 then
                        state.structs[1].frame:RegisterForDrag(v and "" or "LeftButton")
                    end
                    break
                end
            end
        end
    end)
    y=WTip(page,"Drag the first icon on screen -- saves automatically and updates sliders above.",ML,y)
    y=WButton(page,"Reset Position",ML,y,140,22,function()
        WinDB().AnchorPoint="CENTER"; WinDB().AnchorToFrame="UIParent"; WinDB().AnchorToPoint="CENTER"; WinDB().X=0; WinDB().Y=-220
        if CT.Refresh and not _guiBuilding then CT:Refresh() end; if CT.SyncPositionGUI then CT.SyncPositionGUI() end
    end)
    y=WHeader(page,"Frame Strata",y)
    y=WTip(page,"Lower strata = behind unit frame text.",ML,y)
    y=WDropdown(page,"Icon strata:",{{label="Background",value="BACKGROUND"},{label="Low",value="LOW"},{label="Medium",value="MEDIUM"},{label="High",value="HIGH"},{label="Dialog",value="DIALOG"}},ML,y,200,function() return WinDB().IconStrata or "MEDIUM" end,function(v) WinDB().IconStrata=v end)
end

-- ============================================================
-- PAGE 3: Text & Font
-- ============================================================
local function BuildPageText(page)
    local y=10
    y=WHeader(page,"Cooldown Countdown",y)
    y=WCheck(page,"Show cooldown countdown",ML,y,function() return WinDB().ShowCooldownText~=false end,function(v) WinDB().ShowCooldownText=v end)
    y=WSlider(page,"Font size",8,40,ML,y,function() return WinDB().CooldownTextSize or 13 end,function(v) WinDB().CooldownTextSize=v end,EW)
    y=WDropdown(page,"Anchor point:",ANCHORS,ML,y,200,function() return WinDB().CooldownAnchor or "CENTER" end,function(v) WinDB().CooldownAnchor=v end)
    y=WSlider(page,"X offset",-200,200,ML,y,function() return WinDB().CooldownTextX or 0 end,function(v) WinDB().CooldownTextX=v end,EW)
    y=WSlider(page,"Y offset",-200,200,ML,y,function() return WinDB().CooldownTextY or 0 end,function(v) WinDB().CooldownTextY=v end,EW)
    y=WHeader(page,"Stack Count",y)
    y=WCheck(page,"Show stack count",ML,y,function() return WinDB().ShowCount~=false end,function(v) WinDB().ShowCount=v end)
    y=WSlider(page,"Font size",6,28,ML,y,function() return WinDB().CountTextSize or 12 end,function(v) WinDB().CountTextSize=v end,EW)
    y=WDropdown(page,"Anchor point:",ANCHORS,ML,y,180,function() return WinDB().CountAnchor or "BOTTOMRIGHT" end,function(v) WinDB().CountAnchor=v end)
    y=WSlider(page,"X offset",-100,100,ML,y,function() return WinDB().CountTextX or -2 end,function(v) WinDB().CountTextX=v end,EW)
    y=WSlider(page,"Y offset",-100,100,ML,y,function() return WinDB().CountTextY or 2 end,function(v) WinDB().CountTextY=v end,EW)
    y=WHeader(page,"Quality Gem",y)
    y=WCheck(page,"Show quality gem (set per item in the Icons tab)",ML,y,function() return WinDB().ShowQualityGem~=false end,function(v) WinDB().ShowQualityGem=v end)
    y=WSlider(page,"Gem size",4,24,ML,y,function() return WinDB().GemSize or 14 end,function(v) WinDB().GemSize=v end,EW)
    y=WDropdown(page,"Gem position:",{{label="Top Left",value="TOPLEFT"},{label="Top Right",value="TOPRIGHT"},{label="Bottom Left",value="BOTTOMLEFT"},{label="Bottom Right",value="BOTTOMRIGHT"}},ML,y,180,function() return WinDB().GemAnchor or "TOPLEFT" end,function(v) WinDB().GemAnchor=v end)
    y=WDropdown(page,"Gem shape:",{{label="Circle",value="circle"},{label="Star",value="star"}},ML,y,180,function() return WinDB().GemShape or "circle" end,function(v) WinDB().GemShape=v end)
    y=WTip(page,"[N]=None  [G]=Gold  [S]=Silver  [F]=F letter (Fleeting). Set in the Icons tab.",ML,y)
    y=WHeader(page,"Font",y)
    y=WDropdown(page,"Font face:",BuildFontList(),ML,y,310,function() return WinDB().FontPath or STANDARD_TEXT_FONT end,function(v) WinDB().FontPath=v end)
    y=WDropdown(page,"Font style:",FONT_FLAGS,ML,y,220,function() return WinDB().FontFlag or "OUTLINE" end,function(v) WinDB().FontFlag=v end)
    y=WHeader(page,"Settings UI Font",y)
    y=WTip(page,"Changes the font size inside this settings window. Reload UI to apply fully.",ML,y)
    local _guiFontRebuildPending=false
    y=WSlider(page,"UI font size",8,16,ML,y,function() return GDB().GUIFontSize or 11 end,function(v)
        local newSize=math.floor(v+0.5)
        if GDB().GUIFontSize==newSize then return end
        GDB().GUIFontSize=newSize
        if not _guiFontRebuildPending then
            _guiFontRebuildPending=true
            C_Timer.After(0.1,function()
                _guiFontRebuildPending=false
                GFSApplyAll()
            end)
        end
    end,EW)
end

-- ============================================================
-- Defensive spell + racial data (sourced from BetterCooldownManager Data.lua)
-- ============================================================
local CT_DEFENSIVE_SPELLS = {
    DEATHKNIGHT={
        BLOOD=  {[48707]="Anti-Magic Shell",[48792]="Icebound Fortitude",[55233]="Vampiric Blood",[49028]="Dancing Rune Weapon",[48743]="Death Pact",[49039]="Lichborne",[51052]="Anti-Magic Zone"},
        FROST=  {[48707]="Anti-Magic Shell",[48792]="Icebound Fortitude",[48743]="Death Pact",[49039]="Lichborne",[51052]="Anti-Magic Zone"},
        UNHOLY= {[48707]="Anti-Magic Shell",[48792]="Icebound Fortitude",[48743]="Death Pact",[49039]="Lichborne",[51052]="Anti-Magic Zone"},
    },
    DEMONHUNTER={
        HAVOC=    {[198589]="Blur",[196718]="Darkness",[196555]="Netherwalk"},
        VENGEANCE={[203720]="Demon Spikes",[204021]="Fiery Brand",[191427]="Metamorphosis",[196718]="Darkness"},
        DEVOURER= {[198589]="Blur",[196718]="Darkness"},
    },
    DRUID={
        BALANCE=    {[22812]="Barkskin",[5487]="Bear Form",[22842]="Frenzied Regeneration",[108238]="Renewal"},
        FERAL=      {[22812]="Barkskin",[61336]="Survival Instincts",[5487]="Bear Form",[22842]="Frenzied Regeneration",[108238]="Renewal"},
        GUARDIAN=   {[22812]="Barkskin",[61336]="Survival Instincts",[22842]="Frenzied Regeneration",[102558]="Incarnation: Guardian of Ursoc",[200851]="Rage of the Sleeper"},
        RESTORATION={[22812]="Barkskin",[5487]="Bear Form",[22842]="Frenzied Regeneration",[108238]="Renewal",[102342]="Ironbark"},
    },
    EVOKER={
        DEVASTATION= {[363916]="Obsidian Scales",[374348]="Renewing Blaze",[374227]="Zephyr"},
        AUGMENTATION={[363916]="Obsidian Scales",[374348]="Renewing Blaze",[374227]="Zephyr"},
        PRESERVATION={[363916]="Obsidian Scales",[374348]="Renewing Blaze",[374227]="Zephyr",[370960]="Emerald Communion",[357170]="Time Dilation",[363534]="Rewind"},
    },
    HUNTER={
        BEASTMASTERY={[264735]="Survival of the Fittest",[109304]="Exhilaration",[186265]="Aspect of the Turtle"},
        MARKSMANSHIP={[264735]="Survival of the Fittest",[109304]="Exhilaration",[186265]="Aspect of the Turtle"},
        SURVIVAL=    {[264735]="Survival of the Fittest",[109304]="Exhilaration",[186265]="Aspect of the Turtle"},
    },
    MAGE={
        ARCANE={[45438]="Ice Block",[342245]="Alter Time",[235450]="Prismatic Barrier",[110959]="Greater Invisibility"},
        FIRE=  {[45438]="Ice Block",[342245]="Alter Time",[235313]="Blazing Barrier",[110959]="Greater Invisibility"},
        FROST= {[45438]="Ice Block",[342245]="Alter Time",[11426]="Ice Barrier",[110959]="Greater Invisibility"},
    },
    MONK={
        BREWMASTER={[322507]="Celestial Brew",[115203]="Fortifying Brew",[122278]="Dampen Harm",[122783]="Diffuse Magic",[115176]="Zen Meditation"},
        MISTWEAVER= {[243435]="Fortifying Brew",[122278]="Dampen Harm",[122783]="Diffuse Magic",[116849]="Life Cocoon"},
        WINDWALKER= {[243435]="Fortifying Brew",[122470]="Touch of Karma",[122278]="Dampen Harm",[122783]="Diffuse Magic"},
    },
    PALADIN={
        HOLY=       {[642]="Divine Shield",[498]="Divine Protection",[31821]="Aura Mastery",[1022]="Blessing of Protection",[204018]="Blessing of Spellwarding",[633]="Lay on Hands"},
        PROTECTION= {[53600]="Shield of the Righteous",[31850]="Ardent Defender",[86659]="Guardian of Ancient Kings",[642]="Divine Shield",[633]="Lay on Hands",[204018]="Blessing of Spellwarding"},
        RETRIBUTION={[642]="Divine Shield",[184662]="Shield of Vengeance",[205191]="Eye for an Eye",[1022]="Blessing of Protection",[204018]="Blessing of Spellwarding",[633]="Lay on Hands"},
    },
    PRIEST={
        DISCIPLINE={[17]="Power Word: Shield",[19236]="Desperate Prayer",[33206]="Pain Suppression",[62618]="Power Word: Barrier",[586]="Fade"},
        HOLY=      {[17]="Power Word: Shield",[19236]="Desperate Prayer",[47788]="Guardian Spirit",[586]="Fade"},
        SHADOW=    {[17]="Power Word: Shield",[19236]="Desperate Prayer",[47585]="Dispersion",[586]="Fade"},
    },
    ROGUE={
        ASSASSINATION={[1966]="Feint",[31224]="Cloak of Shadows",[5277]="Evasion",[185311]="Crimson Vial",[1856]="Vanish"},
        OUTLAW=       {[1966]="Feint",[31224]="Cloak of Shadows",[5277]="Evasion",[185311]="Crimson Vial",[1856]="Vanish"},
        SUBTLETY=     {[1966]="Feint",[31224]="Cloak of Shadows",[5277]="Evasion",[185311]="Crimson Vial",[1856]="Vanish"},
    },
    SHAMAN={
        ELEMENTAL=  {[108271]="Astral Shift",[108270]="Stone Bulwark Totem",[198103]="Earth Elemental"},
        ENHANCEMENT={[108271]="Astral Shift",[108270]="Stone Bulwark Totem",[198103]="Earth Elemental"},
        RESTORATION={[108271]="Astral Shift",[108270]="Stone Bulwark Totem",[198103]="Earth Elemental",[98008]="Spirit Link Totem",[198838]="Earthen Wall Totem"},
    },
    WARLOCK={
        AFFLICTION= {[104773]="Unending Resolve",[108416]="Dark Pact",[6789]="Mortal Coil"},
        DEMONOLOGY= {[104773]="Unending Resolve",[108416]="Dark Pact",[6789]="Mortal Coil"},
        DESTRUCTION={[104773]="Unending Resolve",[108416]="Dark Pact",[6789]="Mortal Coil"},
    },
    WARRIOR={
        ARMS=      {[118038]="Die by the Sword",[97462]="Rallying Cry",[386208]="Defensive Stance",[23920]="Spell Reflection"},
        FURY=      {[184364]="Enraged Regeneration",[97462]="Rallying Cry",[386208]="Defensive Stance",[23920]="Spell Reflection"},
        PROTECTION={[2565]="Shield Block",[190456]="Ignore Pain",[871]="Shield Wall",[12975]="Last Stand",[1160]="Demoralizing Shout",[23920]="Spell Reflection",[97462]="Rallying Cry",[184364]="Enraged Regeneration"},
    },
}


-- All racial spell IDs — no race tag needed, IsSpellKnownAny in Main.lua filters by what you've learned
local CT_RACIALS = {
    {id=59752,  label="Will to Survive"},        -- Human
    {id=20594,  label="Stoneform"},              -- Dwarf
    {id=58984,  label="Shadowmeld"},             -- Night Elf
    {id=20589,  label="Escape Artist"},          -- Gnome
    {id=121093, label="Gift of the Naaru"},      -- Draenei
    {id=68992,  label="Darkflight"},             -- Worgen
    {id=107079, label="Quaking Palm"},           -- Pandaren
    {id=357214, label="Wing Buffet"},            -- Dracthyr
    {id=20572,  label="Blood Fury"},             -- Orc
    {id=7744,   label="Will of the Forsaken"},   -- Undead
    {id=20577,  label="Cannibalize"},            -- Undead
    {id=20549,  label="War Stomp"},              -- Tauren
    {id=26297,  label="Berserking"},             -- Troll
    {id=50613,  label="Arcane Torrent"},         -- Blood Elf
    {id=69070,  label="Rocket Jump"},            -- Goblin
    {id=256948, label="Spatial Rift"},           -- Void Elf
    {id=255647, label="Light's Judgment"},       -- Lightforged Draenei
    {id=265221, label="Fireblood"},              -- Dark Iron Dwarf
    {id=287712, label="Haymaker"},               -- Kul Tiran
    {id=312924, label="Hyper Organic Light Originator"}, -- Mechagnome
    {id=436344, label="Azerite Surge"},          -- Earthen
    {id=260364, label="Arcane Pulse"},           -- Nightborne
    {id=255654, label="Bull Rush"},              -- Highmountain Tauren
    {id=274738, label="Ancestral Call"},         -- Mag'har Orc
    {id=291944, label="Regeneratin'"},           -- Zandalari Troll
    {id=312411, label="Bag of Tricks"},          -- Vulpera
}

-- ============================================================
-- PAGE 4: All Icons (unified)
-- ============================================================
local unifiedListHolder=nil
local rebuildUnifiedList=nil
local groupCollapsed={}
local presetBtns={}  -- module-level so rebuildUnifiedList can refresh them

-- ---------------------------------------------------------------
-- Midnight consumable preset groups
-- Priority: P1=FleетingGold, P2=FleetingSilver, P3=Gold, P4=Silver
-- Groups without fleeting: P1=Gold, P2=Silver
-- Gem: F=Fleeting, G=Gold, S=Silver
-- ---------------------------------------------------------------
local MIDNIGHT_PRESETS = {
    -- COMBAT POTIONS
    { category="Combat Potions", label="Light's Potential",          gem="gold",
      whitelist={241308,241309,245897,245898},
      p1=245898, p2=245897, p3=241308, p4=241309,
      meta={[245898]={gemColor="F"}, [245897]={gemColor="F"}, [241308]={gemColor="gold"}, [241309]={gemColor="silver"}}},
    { category="Combat Potions", label="Potion of Zealotry",         gem="gold",
      whitelist={241296,241297,245900,245901},
      p1=245901, p2=245900, p3=241296, p4=241297,
      meta={[245901]={gemColor="F"}, [245900]={gemColor="F"}, [241296]={gemColor="gold"}, [241297]={gemColor="silver"}}},
    { category="Combat Potions", label="Potion of Recklessness",     gem="gold",
      whitelist={241288,241289},
      p1=241288, p2=241289,
      meta={[241288]={gemColor="gold"}, [241289]={gemColor="silver"}}},
    { category="Combat Potions", label="Draught of Rampant Abandon", gem="gold",
      whitelist={241292,241293},
      p1=241292, p2=241293,
      meta={[241292]={gemColor="gold"}, [241293]={gemColor="silver"}}},
    -- HEALTH POTIONS
    { category="Health Potions", label="Silvermoon Health Potion",   gem="silver",
      whitelist={241304,241305},
      p1=241304, p2=241305,
      meta={[241304]={gemColor="gold"}, [241305]={gemColor="silver"}}},
    { category="Health Potions", label="Refreshing Serum",           gem="silver",
      whitelist={241306,241307},
      p1=241306, p2=241307,
      meta={[241306]={gemColor="gold"}, [241307]={gemColor="silver"}}},
    { category="Health Potions", label="Amani Extract",              gem="silver",
      whitelist={241298,241299},
      p1=241298, p2=241299,
      meta={[241298]={gemColor="gold"}, [241299]={gemColor="silver"}}},
    -- DEFENSIVE POTIONS
    { category="Defensive Potions", label="Light's Preservation",   gem="silver",
      whitelist={241286,241287},
      p1=241286, p2=241287,
      meta={[241286]={gemColor="gold"}, [241287]={gemColor="silver"}}},
    -- PHIALS
    { category="Phials", label="Haranir Phial of Finesse",           gem="gold",
      whitelist={241310,241311},
      p1=241310, p2=241311,
      meta={[241310]={gemColor="gold"}, [241311]={gemColor="silver"}}},
    { category="Phials", label="Haranir Phial of Ingenuity",         gem="gold",
      whitelist={241312,241313},
      p1=241312, p2=241313,
      meta={[241312]={gemColor="gold"}, [241313]={gemColor="silver"}}},
    { category="Phials", label="Haranir Phial of Perception",        gem="gold",
      whitelist={241316,241317},
      p1=241316, p2=241317,
      meta={[241316]={gemColor="gold"}, [241317]={gemColor="silver"}}},
    -- FLASKS
    { category="Flasks", label="Flask of Thalassian Resistance",     gem="gold",
      whitelist={241320,241321,245926,245927},
      p1=245926, p2=245927, p3=241320, p4=241321,
      meta={[245926]={gemColor="F"}, [245927]={gemColor="F"}, [241320]={gemColor="gold"}, [241321]={gemColor="silver"}}},
    { category="Flasks", label="Flask of the Magisters",             gem="gold",
      whitelist={241322,241323,245932,245933},
      p1=245933, p2=245932, p3=241322, p4=241323,
      meta={[245933]={gemColor="F"}, [245932]={gemColor="F"}, [241322]={gemColor="gold"}, [241323]={gemColor="silver"}}},
    { category="Flasks", label="Flask of the Blood Knights",         gem="gold",
      whitelist={241324,241325,245930,245931},
      p1=245931, p2=245930, p3=241324, p4=241325,
      meta={[245931]={gemColor="F"}, [245930]={gemColor="F"}, [241324]={gemColor="gold"}, [241325]={gemColor="silver"}}},
    { category="Flasks", label="Flask of the Shattered Sun",         gem="gold",
      whitelist={241326,241327,245928,245929},
      p1=245929, p2=245928, p3=241326, p4=241327,
      meta={[245929]={gemColor="F"}, [245928]={gemColor="F"}, [241326]={gemColor="gold"}, [241327]={gemColor="silver"}}},
}
-- Build a quick lookup: itemId → preset index (for whitelist validation)
local PRESET_ITEM_TO_IDX = {}
for i,pg in ipairs(MIDNIGHT_PRESETS) do
    for _,id in ipairs(pg.whitelist) do
        PRESET_ITEM_TO_IDX[id] = i
    end
end

-- Flash an add button green/red and restore after delay


-- PAGE 2: Position
-- ============================================================
-- Flash helpers — defined early so all page builders can use them
local function BuildPageAllIcons(page)
    local db=ConsumableTrackerDB; local y=10

    y=WHeader(page,"All Icons",y)

    -- Window selector: choose which window's icons are being managed
    local winLbl=page:CreateFontString(nil,"OVERLAY"); winLbl:SetFont("Fonts\\ARIALN.TTF",GFS(),""); winLbl:SetTextColor(0.9,0.9,0.9,1)
    winLbl:SetText("Managing window:"); winLbl:SetPoint("TOPLEFT",page,"TOPLEFT",ML,-y); GFSReg(winLbl)
    local winDropF=CreateFrame("Frame",nil,page,"BackdropTemplate"); winDropF:SetSize(200,22); winDropF:SetPoint("TOPLEFT",page,"TOPLEFT",ML+130,-y+2)
    BD(winDropF,0.08,0.08,0.08,1,0.35,0.35,0.35)
    local winDropLbl=winDropF:CreateFontString(nil,"OVERLAY"); winDropLbl:SetFont("Fonts\\ARIALN.TTF",GFS(),""); winDropLbl:SetTextColor(1,1,1,1); winDropLbl:SetPoint("LEFT",winDropF,"LEFT",6,0); GFSReg(winDropLbl)
    local arr=winDropF:CreateFontString(nil,"OVERLAY"); arr:SetFont("Fonts\\ARIALN.TTF",10,""); arr:SetTextColor(0.5,0.5,0.5,1); arr:SetText("v"); arr:SetPoint("RIGHT",winDropF,"RIGHT",-5,0)
    -- Inline popup - child of page, NEVER a global blocker frame
    local winPopup=CreateFrame("Frame",nil,page,"BackdropTemplate")
    winPopup:SetWidth(202); winPopup:SetPoint("TOPLEFT",winDropF,"BOTTOMLEFT",0,-1)
    winPopup:SetFrameLevel((winDropF:GetFrameLevel() or 10)+20)
    BD(winPopup,0.05,0.05,0.05,1,0.35,0.35,0.35); winPopup:Hide()
    local function RefreshWinDropLabel()
        local d=ConsumableTrackerDB; if not d or not d.Windows then return end
        local w=d.Windows[_selectedWinIdx]; winDropLbl:SetText((w and w.Name) or "Window 1")
    end
    local function RebuildWinPopup()
        for _,c in ipairs({winPopup:GetChildren()}) do c:Hide(); c:SetParent(nil) end
        local d=ConsumableTrackerDB; if not d or not d.Windows then return end
        local ph=3
        for i,w in ipairs(d.Windows) do
            local ci=i; local sel=(i==_selectedWinIdx)
            local btn=CreateFrame("Button",nil,winPopup,"BackdropTemplate"); btn:SetHeight(24)
            btn:SetPoint("TOPLEFT",winPopup,"TOPLEFT",2,-ph); btn:SetPoint("TOPRIGHT",winPopup,"TOPRIGHT",-2,-ph)
            BD(btn,sel and 0.16 or 0.08,sel and 0.34 or 0.08,sel and 0.55 or 0.08,1,sel and 0.24 or 0.18,sel and 0.49 or 0.18,sel and 0.73 or 0.18,1)
            local bl=btn:CreateFontString(nil,"OVERLAY"); bl:SetFont("Fonts\\ARIALN.TTF",11,""); bl:SetTextColor(1,1,1,1)
            bl:SetPoint("LEFT",btn,"LEFT",8,0); bl:SetText((w.Name or "Window "..i)..(sel and " *" or ""))
            btn:SetScript("OnEnter",function() btn:SetBackdropColor(0.20,0.42,0.65,1) end)
            btn:SetScript("OnLeave",function() btn:SetBackdropColor(sel and 0.16 or 0.08,sel and 0.34 or 0.08,sel and 0.55 or 0.08,1) end)
            btn:SetScript("OnClick",function()
                _selectedWinIdx=ci; winPopup:Hide(); arr:SetText("v")
                RefreshWinDropLabel()
                if rebuildUnifiedList then rebuildUnifiedList() end
            end)
            ph=ph+26
        end
        winPopup:SetHeight(ph+3)
    end
    local winDropBtn=CreateFrame("Button",nil,winDropF); winDropBtn:SetAllPoints()
    winDropBtn:SetScript("OnClick",function()
        if winPopup:IsShown() then winPopup:Hide(); arr:SetText("v")
        else RebuildWinPopup(); winPopup:Show(); arr:SetText("^") end
    end)
    CT._refreshAllIcons_winDrop = function()
        RefreshWinDropLabel()
        if winPopup:IsShown() then RebuildWinPopup() end
    end
    RefreshWinDropLabel(); y=y+30
    local desc=page:CreateFontString(nil,"OVERLAY"); desc:SetFont("Fonts\\ARIALN.TTF",10,""); desc:SetTextColor(0.55,0.55,0.55,1)
    desc:SetText("Use ^ / v to freely reorder all icons on screen regardless of type.")
    desc:SetPoint("TOPLEFT",page,"TOPLEFT",ML,-y); desc:SetWidth(EW); y=y+18

    -- Type legend
    local legOffsets={0,110,220,330,440}
    local legItems={
        {t="HS",c=TYPE_COLORS.healthstone,lbl="Healthstone"},
        {t="GR",c=TYPE_COLORS.group,      lbl="Cons. Group"},
        {t="SP",c=TYPE_COLORS.spell,      lbl="Spell"},
        {t="IT",c=TYPE_COLORS.item,       lbl="Item"},
        {t="EQ",c=TYPE_COLORS.equip,      lbl="Equip Slot"},
    }
    for i,info in ipairs(legItems) do
        local badge=page:CreateFontString(nil,"OVERLAY"); badge:SetFont("Fonts\\ARIALN.TTF",9,"OUTLINE")
        badge:SetTextColor(info.c[1],info.c[2],info.c[3],1); badge:SetText(info.t.." = "..info.lbl)
        badge:SetPoint("TOPLEFT",page,"TOPLEFT",ML+(legOffsets[i] or 0),-y)
    end
    y=y+14

    -- Unified scrollable list
    local listH=280
    local listBG=CreateFrame("Frame",nil,page,"BackdropTemplate"); listBG:SetPoint("TOPLEFT",page,"TOPLEFT",ML,-y); listBG:SetPoint("TOPRIGHT",page,"TOPRIGHT",-ML,-y); listBG:SetHeight(listH); BD(listBG,0.06,0.06,0.06,1,0.18,0.18,0.18)
    local listClip=CreateFrame("Frame",nil,listBG); listClip:SetAllPoints(); listClip:SetClipsChildren(true)
    unifiedListHolder=CreateFrame("Frame",nil,listClip); unifiedListHolder:SetPoint("TOPLEFT"); unifiedListHolder:SetPoint("TOPRIGHT",listClip,"TOPRIGHT"); unifiedListHolder:SetHeight(listH)
    listClip:EnableMouseWheel(true); local scrollY=0
    listClip:SetScript("OnMouseWheel",function(_,d)
        local maxS=math.max(0,(unifiedListHolder:GetHeight() or 0)-listH)
        scrollY=math.max(0,math.min(maxS,scrollY-d*28)); unifiedListHolder:SetPoint("TOPLEFT",listClip,"TOPLEFT",0,scrollY)
    end)
    y=y+listH+10

    -- ============================================================
    -- 3 ADD TABS
    -- ============================================================
    local TAB_H=26
    local tabNames={"Gear On-Use","Consumables","Defensives / Racials","Class Abilities"}
    local tabBtns={}
    local tabPanels={}
    local activeTab=2  -- default to Consumables

    local function ShowTab(idx)
        activeTab=idx
        for i,tb in ipairs(tabBtns) do
            if i==idx then BD(tb,0.18,0.37,0.58,1,0.24,0.49,0.73,1); tb._lbl:SetTextColor(1,1,1,1)
            else BD(tb,0.09,0.09,0.09,1,0.22,0.22,0.22,1); tb._lbl:SetTextColor(0.7,0.7,0.7,1) end
        end
        for i,p in ipairs(tabPanels) do p:SetShown(i==idx) end
    end

    local tabW=math.floor(EW/4)
    for i,name in ipairs(tabNames) do
        local tb=CreateFrame("Button",nil,page,"BackdropTemplate")
        tb:SetSize(tabW,TAB_H); tb:SetPoint("TOPLEFT",page,"TOPLEFT",ML+(i-1)*tabW,-y)
        BD(tb,0.09,0.09,0.09,1,0.22,0.22,0.22)
        local tl=tb:CreateFontString(nil,"OVERLAY"); tl:SetFont("Fonts\\ARIALN.TTF",GFS(),"")
        tl:SetTextColor(0.7,0.7,0.7,1); tl:SetText(name); tl:SetAllPoints(); tl:SetJustifyH("CENTER")
        tb._lbl=tl
        tb:SetScript("OnEnter",function() if i~=activeTab then tb:SetBackdropBorderColor(0.5,0.7,1,1) end end)
        tb:SetScript("OnLeave",function() ShowTab(activeTab) end)
        tb:SetScript("OnClick",function() ShowTab(i) end)
        tabBtns[i]=tb
    end
    y=y+TAB_H

    -- Panel container (all panels sit at same position)
    local panelY=y
    local panelH=600  -- enough for preset groups + add forms
    for i=1,4 do
        local p=CreateFrame("Frame",nil,page); p:SetSize(EW,panelH)
        p:SetPoint("TOPLEFT",page,"TOPLEFT",ML,-panelY); p:Hide()
        tabPanels[i]=p
    end

    -- shared status label anchored below panels
    local statLbl=page:CreateFontString(nil,"OVERLAY"); statLbl:SetFont("Fonts\\ARIALN.TTF",10,"")
    statLbl:SetTextColor(0.5,0.5,0.5,1); statLbl:SetText("")
    statLbl:SetPoint("TOPLEFT",page,"TOPLEFT",ML,-(panelY+panelH+2)); statLbl:SetWidth(EW)
    local function ShowStat(msg) statLbl:SetText(msg); C_Timer.After(3,function() if statLbl then statLbl:SetText("") end end) end

    -- ============================================================
    -- TAB 1: Gear On-Use
    -- ============================================================
    do
        local p=tabPanels[1]; local py=10
        local tip=p:CreateFontString(nil,"OVERLAY"); tip:SetFont("Fonts\\ARIALN.TTF",10,""); tip:SetTextColor(0.55,0.55,0.55,1)
        tip:SetText("Track on-use cooldowns for any equipped gear slot."); tip:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py); tip:SetWidth(EW); py=py+20

        local equipSlotItems={}; for _,v in ipairs(EQUIP_SLOT_LIST) do table.insert(equipSlotItems,{label=v.label,value=v.slot}) end
        local selectedEquipSlot=13
        local _,_,equipDropCur
        _,_,equipDropCur = WDropdown(p,"Equipment slot:",equipSlotItems,0,py,220,function() return selectedEquipSlot end,function(v) selectedEquipSlot=v end)
        py=py+44

        local eAddBtn=CreateFrame("Button",nil,p,"BackdropTemplate"); eAddBtn:SetSize(EW,24); eAddBtn:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py)
        BD(eAddBtn,0.11,0.11,0.11,1,0.22,0.22,0.22)
        local eal=eAddBtn:CreateFontString(nil,"OVERLAY"); eal:SetFont("Fonts\\ARIALN.TTF",GFS(),""); eal:SetTextColor(0.25,0.75,0.25,1); eal:SetText("+ Add Gear Slot"); eal:SetAllPoints(); eal:SetJustifyH("CENTER")
        eAddBtn:SetScript("OnEnter",function() eAddBtn:SetBackdropColor(0.06,0.18,0.06,1); eAddBtn:SetBackdropBorderColor(0.25,0.75,0.25,1); eal:SetTextColor(1,1,1,1) end)
        eAddBtn:SetScript("OnLeave",function() BD(eAddBtn,0.11,0.11,0.11,1,0.22,0.22,0.22); eal:SetTextColor(0.25,0.75,0.25,1) end)
        local function FlashAddBtn(success)
            if success then
                BD(eAddBtn,0.06,0.28,0.06,1,0.20,0.80,0.20); eal:SetTextColor(0.4,1,0.4,1); eal:SetText("Added!")
            else
                BD(eAddBtn,0.28,0.06,0.06,1,0.80,0.20,0.20); eal:SetTextColor(1,0.4,0.4,1)
            end
            C_Timer.After(1.5,function()
                BD(eAddBtn,0.11,0.11,0.11,1,0.22,0.22,0.22); eal:SetTextColor(0.25,0.75,0.25,1); eal:SetText("+ Add Gear Slot")
            end)
        end
        eAddBtn:SetScript("OnClick",function()
            if type(WinDB().Slots)~="table" then WinDB().Slots={} end
            local slotName=SLOT_BY_NUMBER[selectedEquipSlot] or ("Slot "..selectedEquipSlot)
            -- Check if already in THIS window
            if SlotExistsInWin(WinDB(), "equip", "slot", selectedEquipSlot) then
                FlashAddBtn(false); ShowStat("|cFFFF9900"..slotName.." already in this window|r"); return
            end
            -- Check if in another window — auto-move it here
            local existWi=SlotExistsInAnyWindow("equip","slot",selectedEquipSlot)
            if existWi then
                local srcWin=ConsumableTrackerDB.Windows[existWi]
                for i,s in ipairs(srcWin.Slots or {}) do
                    if s.type=="equip" and s.slot==selectedEquipSlot then
                        table.remove(srcWin.Slots,i)
                        table.insert(WinDB().Slots,s)
                        FlashAddBtn(true); ShowStat("|cFFFFD700Moved "..slotName.." from Window "..existWi.."|r")
                        CT:RefreshLayout(); if rebuildUnifiedList then rebuildUnifiedList() end
                        return
                    end
                end
            end
            table.insert(WinDB().Slots,{type="equip",enabled=true,label=slotName,slot=selectedEquipSlot})
            FlashAddBtn(true); ShowStat("|cFF44FF44Added: "..slotName.."|r")
            CT:RefreshLayout(); if rebuildUnifiedList then rebuildUnifiedList() end
        end)
        py=py+32

        -- Blacklist section
        local bsep=p:CreateTexture(nil,"ARTWORK"); bsep:SetHeight(1); bsep:SetColorTexture(0.20,0.20,0.20,1)
        bsep:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py); bsep:SetWidth(EW); py=py+10

        local blHdr=p:CreateFontString(nil,"OVERLAY"); blHdr:SetFont("Fonts\\ARIALN.TTF",GFS(),"OUTLINE")
        blHdr:SetTextColor(0.85,0.45,0.10,1); blHdr:SetText("Blacklist  (hide specific items from all gear slots)")
        blHdr:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py); py=py+20

        local blTip=p:CreateFontString(nil,"OVERLAY"); blTip:SetFont("Fonts\\ARIALN.TTF",10,""); blTip:SetTextColor(0.45,0.45,0.45,1)
        blTip:SetText("Enter the item ID of any on-use item you never want tracked."); blTip:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py); blTip:SetWidth(EW); py=py+18

        -- Blacklist item list
        local blListBG=CreateFrame("Frame",nil,p,"BackdropTemplate"); blListBG:SetSize(EW,80); blListBG:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py)
        BD(blListBG,0.06,0.06,0.06,1,0.18,0.18,0.18); py=py+88
        local blClip=CreateFrame("Frame",nil,blListBG); blClip:SetAllPoints(); blClip:SetClipsChildren(true)
        local blHolder=CreateFrame("Frame",nil,blClip); blHolder:SetPoint("TOPLEFT"); blHolder:SetPoint("TOPRIGHT",blClip,"TOPRIGHT"); blHolder:SetHeight(80)
        blClip:EnableMouseWheel(true); local blScrollY=0
        blClip:SetScript("OnMouseWheel",function(_,d)
            local maxS=math.max(0,(blHolder:GetHeight() or 0)-80)
            blScrollY=math.max(0,math.min(maxS,blScrollY-d*20)); blHolder:SetPoint("TOPLEFT",blClip,"TOPLEFT",0,blScrollY)
        end)

        local function RebuildBlacklist()
            for _,c in next,{blHolder:GetChildren()} do c:Hide(); c:SetParent(nil) end
            for _,r in next,{blHolder:GetRegions()} do r:Hide() end
            local bl=GDB().EquipBlacklist or {}
            local by=0; local BRH=22
            local any=false
            for idKey,_ in pairs(bl) do
                any=true
                local id=tonumber(idKey) or idKey
                local row=CreateFrame("Frame",nil,blHolder,"BackdropTemplate")
                row:SetPoint("TOPLEFT",blHolder,"TOPLEFT",2,-by); row:SetPoint("TOPRIGHT",blHolder,"TOPRIGHT",-2,-by); row:SetHeight(BRH)
                BD(row,0.10,0.10,0.10,1,0.22,0.22,0.22)
                local nm=GetItemInfo(id); local itx=select(10,GetItemInfo(id))
                local ico=row:CreateTexture(nil,"ARTWORK"); ico:SetSize(16,16); ico:SetPoint("LEFT",row,"LEFT",3,0); ico:SetTexCoord(0.07,0.93,0.07,0.93)
                if itx then ico:SetTexture(itx) else ico:SetColorTexture(0.3,0.3,0.3,1) end
                local lbl2=row:CreateFontString(nil,"OVERLAY"); lbl2:SetFont("Fonts\\ARIALN.TTF",10,""); lbl2:SetTextColor(0.9,0.9,0.9,1)
                lbl2:SetText((nm or ("Item "..tostring(id))).." ["..tostring(id).."]")
                lbl2:SetPoint("LEFT",row,"LEFT",24,0); lbl2:SetPoint("RIGHT",row,"RIGHT",-30,0)
                local remBtn=CreateFrame("Button",nil,row,"BackdropTemplate"); remBtn:SetSize(22,18); remBtn:SetPoint("RIGHT",row,"RIGHT",-2,0)
                BD(remBtn,0.12,0.12,0.12,1,0.22,0.22,0.22)
                local rl=remBtn:CreateFontString(nil,"OVERLAY"); rl:SetFont("Fonts\\ARIALN.TTF",9,""); rl:SetTextColor(0.80,0.22,0.22,1); rl:SetText("x"); rl:SetAllPoints(); rl:SetJustifyH("CENTER")
                remBtn:SetScript("OnLeave",function() BD(remBtn,0.12,0.12,0.12,1,0.22,0.22,0.22); rl:SetTextColor(0.80,0.22,0.22,1) end)
                local capId=id; remBtn:SetScript("OnClick",function()
                    GDB().EquipBlacklist[capId]=nil; CT:RefreshLayout(); RebuildBlacklist()
                end)
                by=by+BRH+2
            end
            if not any then
                local hint=blHolder:CreateFontString(nil,"OVERLAY"); hint:SetFont("Fonts\\ARIALN.TTF",10,""); hint:SetTextColor(0.35,0.35,0.35,1)
                hint:SetText("  No items blacklisted."); hint:SetPoint("TOPLEFT",blHolder,"TOPLEFT",4,-8)
                by=22
            end
            blHolder:SetHeight(math.max(by,22))
        end
        RebuildBlacklist()

        -- Drag-to-blacklist drop zone
        local dragZone=CreateFrame("Frame",nil,p,"BackdropTemplate")
        dragZone:SetSize(EW,36); dragZone:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py)
        BD(dragZone,0.06,0.04,0.02,1,0.40,0.25,0.08)
        dragZone:EnableMouse(true)
        local dzLbl=dragZone:CreateFontString(nil,"OVERLAY"); dzLbl:SetFont("Fonts\\ARIALN.TTF",10,""); dzLbl:SetTextColor(0.60,0.40,0.15,1)
        dzLbl:SetText("Drag an item here to blacklist it"); dzLbl:SetPoint("CENTER")
        local function DoBlacklistItem(itemId)
            if not itemId or itemId <= 0 then return end
            if type(GDB().EquipBlacklist)~="table" then GDB().EquipBlacklist={} end
            GDB().EquipBlacklist[itemId]=true
            local nm=C_Item.GetItemInfo(itemId) or ("ID "..itemId)
            dzLbl:SetText("|cFF44FF44Blacklisted: "..nm.."|r")
            C_Timer.After(2,function() dzLbl:SetText("Drag an item here to blacklist it") end)
            CT:RefreshLayout(); RebuildBlacklist()
        end
        dragZone:SetScript("OnReceiveDrag",function()
            local infoType,itemId=GetCursorInfo()
            if infoType=="item" and itemId then
                ClearCursor()
                DoBlacklistItem(itemId)
            end
        end)
        dragZone:SetScript("OnMouseDown",function()
            local infoType,itemId=GetCursorInfo()
            if infoType=="item" and itemId then
                ClearCursor()
                DoBlacklistItem(itemId)
            end
        end)
        dragZone:SetScript("OnEnter",function()
            dragZone:SetBackdropColor(0.10,0.07,0.03,1)
            dragZone:SetBackdropBorderColor(0.85,0.55,0.15,1)
        end)
        dragZone:SetScript("OnLeave",function() BD(dragZone,0.06,0.04,0.02,1,0.40,0.25,0.08) end)
        py=py+44

        local blIdLbl=p:CreateFontString(nil,"OVERLAY"); blIdLbl:SetFont("Fonts\\ARIALN.TTF",GFS(),""); blIdLbl:SetTextColor(0.9,0.9,0.9,1); blIdLbl:SetText("Or type Item ID:")
        blIdLbl:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py); py=py+16
        local blIdBox=CreateFrame("EditBox",nil,p,"InputBoxTemplate"); blIdBox:SetSize(120,20); blIdBox:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py)
        blIdBox:SetAutoFocus(false); blIdBox:SetFont("Fonts\\ARIALN.TTF",GFS(),""); blIdBox:SetTextColor(0.9,0.9,0.9,1); blIdBox:SetTextInsets(6,6,0,0); blIdBox:SetText("")
        local blAddBtn=CreateFrame("Button",nil,p,"BackdropTemplate"); blAddBtn:SetSize(110,20); blAddBtn:SetPoint("LEFT",blIdBox,"RIGHT",6,0)
        BD(blAddBtn,0.11,0.11,0.11,1,0.22,0.22,0.22)
        local bal=blAddBtn:CreateFontString(nil,"OVERLAY"); bal:SetFont("Fonts\\ARIALN.TTF",GFS(),""); bal:SetTextColor(0.85,0.45,0.10,1); bal:SetText("+ Blacklist"); bal:SetAllPoints(); bal:SetJustifyH("CENTER")
        blAddBtn:SetScript("OnEnter",function() blAddBtn:SetBackdropColor(0.20,0.10,0.03,1); blAddBtn:SetBackdropBorderColor(0.85,0.45,0.10,1); bal:SetTextColor(1,1,1,1) end)
        blAddBtn:SetScript("OnLeave",function() BD(blAddBtn,0.11,0.11,0.11,1,0.22,0.22,0.22); bal:SetTextColor(0.85,0.45,0.10,1) end)
        local function DoBlacklist()
            local rawId=blIdBox:GetText():match("^%s*(%d+)%s*$"); local id=tonumber(rawId)
            if not id or id<=0 then ShowStat("|cFFFF4444Invalid item ID|r"); return end
            if type(GDB().EquipBlacklist)~="table" then GDB().EquipBlacklist={} end
            GDB().EquipBlacklist[id]=true; blIdBox:SetText("")
            ShowStat("|cFFFF9900Blacklisted item "..id.."|r")
            CT:RefreshLayout(); RebuildBlacklist()
        end
        blAddBtn:SetScript("OnClick",DoBlacklist)
        blIdBox:SetScript("OnEnterPressed",function() DoBlacklist(); blIdBox:ClearFocus() end)
    end

    -- ============================================================
    -- TAB 2: Consumables
    -- ============================================================
    do
        local p=tabPanels[2]; local py=10
        local tip=p:CreateFontString(nil,"OVERLAY"); tip:SetFont("Fonts\\ARIALN.TTF",10,""); tip:SetTextColor(0.55,0.55,0.55,1)
        tip:SetText("Track consumables by item ID. Use groups (GR) for priority fallbacks."); tip:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py); tip:SetWidth(EW); py=py+20

        -- ── Declare shared selection state FIRST so all closures below can use it ──
        local selGrpSlot=nil       -- identity ref to selected group slot
        local selGrpIdx=nil        -- current db index (refreshed on each call)
        local selPriority=1
        local selectedHrow=nil     -- hrow frame currently highlighted white

        -- ── Midnight Preset Groups ──
        local preHdr=p:CreateFontString(nil,"OVERLAY"); preHdr:SetFont("Fonts\\ARIALN.TTF",GFS(),"OUTLINE")
        preHdr:SetTextColor(1,0.82,0,1); preHdr:SetText("Midnight Preset Groups"); preHdr:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py); preHdr:SetWidth(EW); preHdr:SetJustifyH("CENTER"); py=py+16
        local preTip=p:CreateFontString(nil,"OVERLAY"); preTip:SetFont("Fonts\\ARIALN.TTF",9,""); preTip:SetTextColor(0.45,0.45,0.45,1)
        preTip:SetText("Pre-filled with Midnight consumables. P1=Fleeting Gold  P2=Fleeting Silver  P3=Gold  P4=Silver"); preTip:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py); preTip:SetWidth(EW); preTip:SetJustifyH("CENTER"); py=py+14

        -- Group by category
        local catOrder={"Combat Potions","Health Potions","Defensive Potions","Phials","Flasks"}
        local catColors={
            ["Combat Potions"]   ={0.85,0.30,0.10},
            ["Health Potions"]   ={0.20,0.70,0.20},
            ["Defensive Potions"]={0.20,0.50,0.85},
            ["Phials"]           ={0.60,0.20,0.85},
            ["Flasks"]           ={0.85,0.65,0.10},
        }

        local function IsPresetAddedInAnyWindow(presetLabel)
            local d=ConsumableTrackerDB; if not d or not d.Windows then return nil end
            for wi,win in ipairs(d.Windows) do
                for _,s in ipairs(win.Slots or {}) do
                    if s.type=="group" and s._preset==presetLabel then return wi end
                end
            end
            return nil
        end

        local function IsPresetAdded(presetLabel)
            return IsPresetAddedInAnyWindow(presetLabel) == _selectedWinIdx
        end

        presetBtns={}  -- reset module-level table

        local function AddPreset(pg)
            if type(WinDB().Slots)~="table" then WinDB().Slots={} end
            if IsPresetAdded(pg.label) then ShowStat("|cFFFF9900"..pg.label.." already in this window|r"); return end
            -- Auto-move from another window
            local existWi=IsPresetAddedInAnyWindow(pg.label)
            if existWi then
                local srcWin=ConsumableTrackerDB.Windows[existWi]
                for i,s in ipairs(srcWin.Slots or {}) do
                    if s.type=="group" and s._preset==pg.label then
                        table.remove(srcWin.Slots,i)
                        table.insert(WinDB().Slots,s)
                        ShowStat("|cFFFFD700Moved "..pg.label.." from Window "..existWi.."|r")
                        CT:RefreshLayout()
                        C_Timer.After(0.1, function() if rebuildUnifiedList then rebuildUnifiedList() end end)
                        return
                    end
                end
            end
            local slot={type="group", enabled=true, label=pg.label, _preset=pg.label, meta={}}
            if pg.p1 then slot.p1=pg.p1 end
            if pg.p2 then slot.p2=pg.p2 end
            if pg.p3 then slot.p3=pg.p3 end
            if pg.p4 then slot.p4=pg.p4 end
            for id,m in pairs(pg.meta) do slot.meta[id]={gemColor=m.gemColor} end
            for _,id in ipairs(pg.whitelist) do C_Item.RequestLoadItemDataByID(id) end
            table.insert(WinDB().Slots, slot)
            CT:RefreshLayout()
            C_Timer.After(0.1, function()
                if rebuildUnifiedList then rebuildUnifiedList() end
            end)
            -- Refresh button states
            for _,entry in ipairs(presetBtns) do
                if entry.preset==pg.label and entry.refresh then
                    entry.refresh()
                end
            end
        end

        for _,cat in ipairs(catOrder) do
            local cc=catColors[cat] or {0.5,0.5,0.5}
            -- Category header
            local catRow=CreateFrame("Frame",nil,p,"BackdropTemplate")
            catRow:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py); catRow:SetPoint("TOPRIGHT",p,"TOPRIGHT",0,-py); catRow:SetHeight(18)
            BD(catRow,cc[1]*0.15,cc[2]*0.15,cc[3]*0.15,1,cc[1]*0.5,cc[2]*0.5,cc[3]*0.5)
            local stripe=catRow:CreateTexture(nil,"ARTWORK"); stripe:SetColorTexture(cc[1],cc[2],cc[3],1); stripe:SetWidth(3); stripe:SetHeight(18); stripe:SetPoint("LEFT",catRow,"LEFT",0,0)
            local catLbl=catRow:CreateFontString(nil,"OVERLAY"); catLbl:SetFont("Fonts\\ARIALN.TTF",9,"OUTLINE"); catLbl:SetTextColor(cc[1]*1.5+0.1,cc[2]*1.5+0.1,cc[3]*1.5+0.1,1); catLbl:SetText(cat:upper()); catLbl:SetPoint("CENTER",catRow,"CENTER",0,0); catLbl:SetWidth(EW); catLbl:SetJustifyH("CENTER")
            py=py+20

            -- Preset rows for this category
            for _,pg in ipairs(MIDNIGHT_PRESETS) do
                if pg.category==cat then
                    local capPg=pg
                    local row=CreateFrame("Frame",nil,p,"BackdropTemplate")
                    row:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py); row:SetPoint("TOPRIGHT",p,"TOPRIGHT",0,-py); row:SetHeight(22)

                    local nameLbl=row:CreateFontString(nil,"OVERLAY"); nameLbl:SetFont("Fonts\\ARIALN.TTF",10,"")
                    nameLbl:SetText(pg.label); nameLbl:SetPoint("CENTER",row,"CENTER",0,0); nameLbl:SetWidth(EW); nameLbl:SetJustifyH("CENTER")

                    local addBtn=CreateFrame("Button",nil,row,"BackdropTemplate"); addBtn:SetSize(60,16); addBtn:SetPoint("RIGHT",row,"RIGHT",-4,0)
                    local btnLbl=addBtn:CreateFontString(nil,"OVERLAY"); btnLbl:SetFont("Fonts\\ARIALN.TTF",9,""); btnLbl:SetPoint("CENTER")

                    local function RefreshPresetRow()
                        local isAdded=IsPresetAdded(capPg.label)
                        BD(row, isAdded and 0.06 or 0.08, isAdded and 0.14 or 0.08, isAdded and 0.06 or 0.08, 1,
                               isAdded and 0.20 or 0.18, isAdded and 0.45 or 0.18, isAdded and 0.20 or 0.18, 1)
                        BD(addBtn, isAdded and 0.06 or 0.10, isAdded and 0.14 or 0.10, isAdded and 0.06 or 0.10, 1,
                                   isAdded and 0.20 or 0.22, isAdded and 0.45 or 0.22, isAdded and 0.20 or 0.22, 1)
                        nameLbl:SetTextColor(isAdded and 0.5 or 0.9, 0.9, isAdded and 0.5 or 0.9, 1)
                        btnLbl:SetText(isAdded and "[Added]" or "+ Add")
                        btnLbl:SetTextColor(isAdded and 0.4 or 0.7, isAdded and 1 or 0.9, isAdded and 0.4 or 0.7, 1)
                    end
                    RefreshPresetRow()

                    addBtn:SetScript("OnEnter",function()
                        if not IsPresetAdded(capPg.label) then
                            addBtn:SetBackdropColor(0.08,0.22,0.08,1); btnLbl:SetTextColor(1,1,1,1)
                        end
                    end)
                    addBtn:SetScript("OnLeave",function() RefreshPresetRow() end)
                    addBtn:SetScript("OnClick",function()
                        if IsPresetAdded(capPg.label) then
                            ShowStat("|cFFFF9900"..capPg.label.." already in list|r"); return
                        end
                        AddPreset(capPg)
                        -- Show [Added] for 5s then revert
                        btnLbl:SetText("[Added]"); btnLbl:SetTextColor(0.4,1,0.4,1)
                        C_Timer.After(5, function()
                            if btnLbl and btnLbl:GetText()=="[Added]" then
                                RefreshPresetRow()
                            end
                        end)
                    end)

                    table.insert(presetBtns,{btn=addBtn,lbl=btnLbl,preset=pg.label,refresh=RefreshPresetRow})
                    py=py+24
                end
            end
            py=py+4
        end

        -- Separator before manual section
        local preManSep=p:CreateTexture(nil,"ARTWORK"); preManSep:SetHeight(1); preManSep:SetColorTexture(0.20,0.20,0.20,1)
        preManSep:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py); preManSep:SetWidth(EW); py=py+10
        local preManHdr=p:CreateFontString(nil,"OVERLAY"); preManHdr:SetFont("Fonts\\ARIALN.TTF",GFS(),"OUTLINE"); preManHdr:SetTextColor(0.9,0.9,0.9,1)
        preManHdr:SetText("Custom Groups"); preManHdr:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py); py=py+18

        -- ── Healthstone ──
        local hsBtn=CreateFrame("Button",nil,p,"BackdropTemplate"); hsBtn:SetSize(EW,24); hsBtn:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py)
        BD(hsBtn,0.18,0.07,0.25,1,0.60,0.20,0.80,1)
        local hsl=hsBtn:CreateFontString(nil,"OVERLAY"); hsl:SetFont("Fonts\\ARIALN.TTF",GFS(),""); hsl:SetTextColor(0.85,0.55,1.0,1); hsl:SetText("+ Add Healthstone"); hsl:SetAllPoints(); hsl:SetJustifyH("CENTER")
        hsBtn:SetScript("OnEnter",function() hsBtn:SetBackdropColor(0.28,0.12,0.38,1); hsBtn:SetBackdropBorderColor(0.85,0.55,1.0,1); hsl:SetTextColor(1,1,1,1) end)
        hsBtn:SetScript("OnLeave",function() BD(hsBtn,0.18,0.07,0.25,1,0.60,0.20,0.80,1); hsl:SetTextColor(0.85,0.55,1.0,1) end)
        hsBtn:SetScript("OnClick",function()
            if type(WinDB().Slots)~="table" then WinDB().Slots={} end
            -- Check current window
            for _,s in ipairs(WinDB().Slots) do if s.type=="healthstone" then ShowStat("|cFFFF9900Healthstone already in this window|r"); return end end
            -- Check other windows — auto-move
            local d=ConsumableTrackerDB
            if d and d.Windows then
                for wi,win in ipairs(d.Windows) do
                    if wi~=_selectedWinIdx then
                        for i,s in ipairs(win.Slots or {}) do
                            if s.type=="healthstone" then
                                table.remove(win.Slots,i)
                                table.insert(WinDB().Slots,s)
                                ShowStat("|cFFFFD700Moved Healthstone from Window "..wi.."|r")
                                CT:RefreshLayout(); if rebuildUnifiedList then rebuildUnifiedList() end
                                return
                            end
                        end
                    end
                end
            end
            table.insert(WinDB().Slots,{type="healthstone",enabled=true,label="Healthstone"})
            FlashBtn(hsBtn,hsl,"Added!","+ Add Healthstone",0.18,0.07,0.25,0.60,0.20,0.80)
            CT:RefreshLayout(); if rebuildUnifiedList then rebuildUnifiedList() end
        end)
        py=py+32

        -- ── New Group button ──
        local grpAddBtn=CreateFrame("Button",nil,p,"BackdropTemplate"); grpAddBtn:SetSize(EW,24); grpAddBtn:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py)
        BD(grpAddBtn,0.11,0.11,0.11,1,0.22,0.22,0.22)
        local gal=grpAddBtn:CreateFontString(nil,"OVERLAY"); gal:SetFont("Fonts\\ARIALN.TTF",GFS(),""); gal:SetTextColor(0.25,0.75,0.25,1); gal:SetText("+ New Consumable Group"); gal:SetAllPoints(); gal:SetJustifyH("CENTER")
        grpAddBtn:SetScript("OnEnter",function() grpAddBtn:SetBackdropColor(0.06,0.18,0.06,1); grpAddBtn:SetBackdropBorderColor(0.25,0.75,0.25,1); gal:SetTextColor(1,1,1,1) end)
        grpAddBtn:SetScript("OnLeave",function() BD(grpAddBtn,0.11,0.11,0.11,1,0.22,0.22,0.22); gal:SetTextColor(0.25,0.75,0.25,1) end)
        grpAddBtn:SetScript("OnClick",function()
            if type(WinDB().Slots)~="table" then WinDB().Slots={} end
            local lbl="Group "..(#WinDB().Slots+1)
            local newGrp={type="group",enabled=true,label=lbl,meta={}}
            table.insert(WinDB().Slots,newGrp)
            FlashBtn(grpAddBtn,gal,"Created!","+ New Consumable Group")
            ShowStat("|cFF44FF44Created "..lbl.."|r")
            CT:RefreshLayout(); if rebuildUnifiedList then rebuildUnifiedList() end
        end)
        py=py+32

        -- ── Separator ──
        local sep1=p:CreateTexture(nil,"ARTWORK"); sep1:SetHeight(1); sep1:SetColorTexture(0.18,0.18,0.18,1)
        sep1:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py); sep1:SetWidth(EW); py=py+8

        -- ── "Adding to:" banner — shown above the add form, updated when group selected ──
        local addGrpBanner=CreateFrame("Frame",nil,p,"BackdropTemplate")
        addGrpBanner:SetSize(EW,24); addGrpBanner:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py); py=py+28
        BD(addGrpBanner,0.08,0.08,0.08,1,0.30,0.30,0.30)
        local addGrpBannerLbl=addGrpBanner:CreateFontString(nil,"OVERLAY"); addGrpBannerLbl:SetFont("Fonts\\ARIALN.TTF",GFS(),"OUTLINE")
        addGrpBannerLbl:SetAllPoints(); addGrpBannerLbl:SetJustifyH("CENTER")
        addGrpBannerLbl:SetTextColor(0.45,0.45,0.45,1)
        addGrpBannerLbl:SetText("<- Click a group row in the list to select it")

        -- ── Add item form ──
        local iHdr=p:CreateFontString(nil,"OVERLAY"); iHdr:SetFont("Fonts\\ARIALN.TTF",GFS(),"OUTLINE"); iHdr:SetTextColor(0.85,0.45,0.10,1)
        iHdr:SetText("Add item to selected group"); iHdr:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py); py=py+18

        local iIdLbl=p:CreateFontString(nil,"OVERLAY"); iIdLbl:SetFont("Fonts\\ARIALN.TTF",10,""); iIdLbl:SetTextColor(0.7,0.7,0.7,1); iIdLbl:SetText("Item ID:")
        iIdLbl:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py); py=py+14
        local iIdBox=CreateFrame("EditBox",nil,p,"InputBoxTemplate"); iIdBox:SetSize(120,20); iIdBox:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py)
        iIdBox:SetAutoFocus(false); iIdBox:SetFont("Fonts\\ARIALN.TTF",GFS(),""); iIdBox:SetTextColor(0.9,0.9,0.9,1); iIdBox:SetTextInsets(6,6,0,0); iIdBox:SetText("")
        iIdBox:SetScript("OnEscapePressed",function(sv) sv:ClearFocus() end)
        local iStatLbl=p:CreateFontString(nil,"OVERLAY"); iStatLbl:SetFont("Fonts\\ARIALN.TTF",10,"")
        iStatLbl:SetTextColor(0.5,0.5,0.5,1); iStatLbl:SetText("")
        iStatLbl:SetPoint("LEFT",iIdBox,"RIGHT",8,0); iStatLbl:SetWidth(EW-130)
        local function ShowItemStat(msg) iStatLbl:SetText(msg); C_Timer.After(4,function() if iStatLbl then iStatLbl:SetText("") end end) end
        py=py+26

        local iPriLbl=p:CreateFontString(nil,"OVERLAY"); iPriLbl:SetFont("Fonts\\ARIALN.TTF",10,""); iPriLbl:SetTextColor(0.7,0.7,0.7,1); iPriLbl:SetText("Priority:")
        iPriLbl:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py); py=py+14
        local iSelPri=1; local ipriBtns={}
        local function SetIPriBtn(n) iSelPri=n; for i,b in ipairs(ipriBtns) do if i==n then BD(b,0.24,0.49,0.73,1,0.24,0.49,0.73,1) else BD(b,0.09,0.09,0.09,1,0.22,0.22,0.22,1) end end end
        for i=1,4 do
            local b=CreateFrame("Button",nil,p,"BackdropTemplate"); b:SetSize(30,20); b:SetPoint("TOPLEFT",p,"TOPLEFT",(i-1)*34,-py)
            BD(b,i==1 and 0.24 or 0.09,i==1 and 0.49 or 0.09,i==1 and 0.73 or 0.09,1,i==1 and 0.24 or 0.22,i==1 and 0.49 or 0.22,i==1 and 0.73 or 0.22,1)
            local bl=b:CreateFontString(nil,"OVERLAY"); bl:SetFont("Fonts\\ARIALN.TTF",10,""); bl:SetTextColor(1,1,1,1); bl:SetText(tostring(i)); bl:SetAllPoints(); bl:SetJustifyH("CENTER")
            local ci=i; b:SetScript("OnClick",function() SetIPriBtn(ci) end); ipriBtns[i]=b
        end; py=py+26

        local iGemLbl=p:CreateFontString(nil,"OVERLAY"); iGemLbl:SetFont("Fonts\\ARIALN.TTF",10,""); iGemLbl:SetTextColor(0.7,0.7,0.7,1); iGemLbl:SetText("Gem:")
        iGemLbl:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py); py=py+14
        local iGemSel="none"; local igemBtns={}
        local gemDefs3={{key="none",label="N",r=0.35,g=0.35,b=0.35},{key="gold",label="G",r=1.00,g=0.82,b=0.00},{key="silver",label="S",r=0.80,g=0.80,b=0.85},{key="F",label="F",r=0.80,g=0.60,b=0.10}}
        local function RefIGemBtns() for _,gbi in ipairs(igemBtns) do local act=(iGemSel==gbi.key)
            BD(gbi.btn,act and gbi.r*0.6 or 0.09,act and gbi.g*0.6 or 0.09,act and gbi.b*0.6 or 0.09,1,act and gbi.r or 0.22,act and gbi.g or 0.22,act and gbi.b or 0.22,1)
            gbi.lbl:SetTextColor(act and 1 or 0.45,act and 1 or 0.45,act and 1 or 0.45,1) end end
        for i,gd in ipairs(gemDefs3) do
            local gb=CreateFrame("Button",nil,p,"BackdropTemplate"); gb:SetSize(30,20); gb:SetPoint("TOPLEFT",p,"TOPLEFT",(i-1)*34,-py)
            BD(gb,0.09,0.09,0.09,1,0.22,0.22,0.22)
            local gl=gb:CreateFontString(nil,"OVERLAY"); gl:SetFont("Fonts\\ARIALN.TTF",10,""); gl:SetText(gd.label); gl:SetAllPoints(); gl:SetJustifyH("CENTER"); gl:SetTextColor(0.45,0.45,0.45,1)
            table.insert(igemBtns,{btn=gb,lbl=gl,key=gd.key,r=gd.r,g=gd.g,b=gd.b})
            local cgk=gd.key; gb:SetScript("OnClick",function() iGemSel=cgk; RefIGemBtns() end)
            gb:SetScript("OnLeave",function() RefIGemBtns() end)
        end; RefIGemBtns(); py=py+26

        local iBorderLbl=p:CreateFontString(nil,"OVERLAY"); iBorderLbl:SetFont("Fonts\\ARIALN.TTF",10,""); iBorderLbl:SetTextColor(0.7,0.7,0.7,1); iBorderLbl:SetText("Border colour:")
        iBorderLbl:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py)
        local iBorderColor={0,0,0,1}
        local iBSW=CreateFrame("Button",nil,p,"BackdropTemplate"); iBSW:SetSize(40,16); iBSW:SetPoint("LEFT",iBorderLbl,"RIGHT",6,0)
        local function RefIBSW() BD(iBSW,iBorderColor[1],iBorderColor[2],iBorderColor[3],1,iBorderColor[1]*1.5+0.15,iBorderColor[2]*1.5+0.15,iBorderColor[3]*1.5+0.15) end; RefIBSW()
        iBSW:SetScript("OnClick",function()
            local prev={iBorderColor[1],iBorderColor[2],iBorderColor[3],iBorderColor[4] or 1}
            local function Apply() local r,g,b=ColorPickerFrame:GetColorRGB(); iBorderColor={r,g,b,1}; RefIBSW() end
            ColorPickerFrame:SetupColorPickerAndShow({swatchFunc=Apply,opacityFunc=Apply,cancelFunc=function() iBorderColor=prev; RefIBSW() end,hasOpacity=false,r=iBorderColor[1],g=iBorderColor[2],b=iBorderColor[3]})
        end)
        iBSW:SetScript("OnLeave",function() RefIBSW() end)
        py=py+28

        local iAddBtn=CreateFrame("Button",nil,p,"BackdropTemplate"); iAddBtn:SetSize(EW,24); iAddBtn:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py)
        BD(iAddBtn,0.11,0.11,0.11,1,0.22,0.22,0.22)
        local ial=iAddBtn:CreateFontString(nil,"OVERLAY"); ial:SetFont("Fonts\\ARIALN.TTF",GFS(),""); ial:SetTextColor(0.25,0.75,0.25,1); ial:SetText("+ Add to Group"); ial:SetAllPoints(); ial:SetJustifyH("CENTER")
        iAddBtn:SetScript("OnEnter",function() iAddBtn:SetBackdropColor(0.06,0.18,0.06,1); iAddBtn:SetBackdropBorderColor(0.25,0.75,0.25,1); ial:SetTextColor(1,1,1,1) end)
        iAddBtn:SetScript("OnLeave",function() BD(iAddBtn,0.11,0.11,0.11,1,0.22,0.22,0.22); ial:SetTextColor(0.25,0.75,0.25,1) end)
        -- Persistent override confirm popup (parented to UIParent to avoid scroll clipping)
        local confirmPopup = CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
        confirmPopup:SetSize(EW+40,36); confirmPopup:SetFrameStrata("DIALOG"); confirmPopup:SetFrameLevel(200)
        BD(confirmPopup,0.10,0.07,0.03,1,0.55,0.35,0.08)
        local cpLbl = confirmPopup:CreateFontString(nil,"OVERLAY"); cpLbl:SetFont("Fonts\\ARIALN.TTF",11,"OUTLINE")
        cpLbl:SetTextColor(1,0.78,0.2,1); cpLbl:SetPoint("LEFT",confirmPopup,"LEFT",8,3)
        local cpYes = CreateFrame("Button",nil,confirmPopup,"BackdropTemplate"); cpYes:SetSize(50,20); cpYes:SetPoint("LEFT",confirmPopup,"LEFT",8,-8)
        BD(cpYes,0.08,0.18,0.08,1,0.20,0.50,0.20)
        local cpYL=cpYes:CreateFontString(nil,"OVERLAY"); cpYL:SetFont("Fonts\\ARIALN.TTF",10,""); cpYL:SetTextColor(0.4,1,0.4,1); cpYL:SetText("Override"); cpYL:SetPoint("CENTER")
        cpYes:SetScript("OnEnter",function() cpYes:SetBackdropColor(0.12,0.28,0.12,1) end)
        cpYes:SetScript("OnLeave",function() BD(cpYes,0.08,0.18,0.08,1,0.20,0.50,0.20) end)
        local cpNo = CreateFrame("Button",nil,confirmPopup,"BackdropTemplate"); cpNo:SetSize(44,20); cpNo:SetPoint("LEFT",cpYes,"RIGHT",4,0)
        BD(cpNo,0.18,0.08,0.08,1,0.50,0.20,0.20)
        local cpNL=cpNo:CreateFontString(nil,"OVERLAY"); cpNL:SetFont("Fonts\\ARIALN.TTF",10,""); cpNL:SetTextColor(1,0.4,0.4,1); cpNL:SetText("Cancel"); cpNL:SetPoint("CENTER")
        cpNo:SetScript("OnEnter",function() cpNo:SetBackdropColor(0.28,0.10,0.10,1) end)
        cpNo:SetScript("OnLeave",function() BD(cpNo,0.18,0.08,0.08,1,0.50,0.20,0.20) end)
        cpNo:SetScript("OnClick",function() confirmPopup:Hide(); ShowItemStat("") end)
        confirmPopup:Hide()

        local function DoAddItem()
            local rawId=iIdBox:GetText():match("^%s*(%d+)%s*$"); local id=tonumber(rawId)
            if not id or id<=0 then ShowItemStat("|cFFFF4444Invalid item ID|r"); return end
            if type(WinDB().Slots)~="table" then WinDB().Slots={} end
            local grpSlot=selGrpSlot
            if not grpSlot then
                for i=#WinDB().Slots,1,-1 do if WinDB().Slots[i].type=="group" then grpSlot=WinDB().Slots[i]; break end end
            end
            if not grpSlot then
                grpSlot={type="group",enabled=true,label="Group 1",meta={}}
                table.insert(WinDB().Slots,grpSlot)
            end
            -- Whitelist check: preset groups only accept their own items
            if grpSlot._preset then
                local presetIdx=nil
                for i,pg in ipairs(MIDNIGHT_PRESETS) do if pg.label==grpSlot._preset then presetIdx=i; break end end
                if presetIdx then
                    local pg=MIDNIGHT_PRESETS[presetIdx]
                    local allowed=false
                    for _,wid in ipairs(pg.whitelist) do if wid==id then allowed=true; break end end
                    if not allowed then
                        ShowItemStat("|cFFFF4444That item doesn't belong in "..grpSlot.label.."|r")
                        return
                    end
                end
            end
            local pkey="p"..iSelPri
            local existingId = grpSlot[pkey]
            if existingId and existingId > 0 and existingId ~= id then
                local existName = GetItemInfo(existingId) or ("ID "..existingId)
                cpLbl:SetText("P"..iSelPri.." already has: |cFFFFD700"..existName.."|r  — override?")
                -- Position popup above the add button on screen
                local ax,ay = iAddBtn:GetCenter()
                local sx,sy = UIParent:GetCenter()
                confirmPopup:ClearAllPoints()
                confirmPopup:SetPoint("BOTTOMLEFT",UIParent,"CENTER",(ax or 0)-sx,((ay or 0)-sy)+30)
                -- Wire Yes to do the actual add
                local capGrp=grpSlot; local capId=id; local capPkey=pkey; local capPri=iSelPri
                cpYes:SetScript("OnClick",function()
                    confirmPopup:Hide()
                    capGrp[capPkey]=capId; capGrp.meta=capGrp.meta or {}
                    capGrp.meta[capId]={gemColor=iGemSel,borderColor={iBorderColor[1],iBorderColor[2],iBorderColor[3],iBorderColor[4]}}
                    local nm2=GetItemInfo(capId); ShowItemStat("|cFF44FF44Replaced: "..(nm2 or ("ID "..capId)).." P"..capPri.."|r")
                    iIdBox:SetText(""); C_Item.RequestLoadItemDataByID(capId)
                    CT:RefreshLayout(); if rebuildUnifiedList then rebuildUnifiedList() end
                end)
                confirmPopup:Show()
                ShowItemStat("|cFFFF9900P"..iSelPri.." occupied — confirm override|r")
                return
            end
            -- No conflict — add directly
            grpSlot[pkey]=id; grpSlot.meta=grpSlot.meta or {}
            grpSlot.meta[id]={gemColor=iGemSel,borderColor={iBorderColor[1],iBorderColor[2],iBorderColor[3],iBorderColor[4]}}
            local nm2=GetItemInfo(id); ShowItemStat("|cFF44FF44Added "..(nm2 or ("ID "..id)).." → "..grpSlot.label.." P"..iSelPri.."|r")
            iIdBox:SetText(""); C_Item.RequestLoadItemDataByID(id)
            CT:RefreshLayout(); if rebuildUnifiedList then rebuildUnifiedList() end
        end
        iAddBtn:SetScript("OnClick",DoAddItem)
        iIdBox:SetScript("OnEnterPressed",function() DoAddItem(); iIdBox:ClearFocus() end)
        py=py+32

        -- ── Expose to list builder ──
        CT._setConsGrpIdx=function(idx,lbl,pi,pid)
            selGrpIdx=idx
            selGrpSlot=WinDB().Slots and WinDB().Slots[idx]
            if pi then SetPriBtn(pi) end
            if pid then pIdBox:SetText(tostring(pid)); psl:SetText("Update") end
        end
        CT._selectGroupRow=function(hrow,grpSlot,grpLabel)
            -- Clear previous highlight
            if selectedHrow and selectedHrow~=hrow then
                local tc=TYPE_COLORS["group"] or {0.24,0.49,0.73}
                BD(selectedHrow,0.10,0.10,0.10,1,tc[1]*0.5,tc[2]*0.5,tc[3]*0.5)
            end
            selectedHrow=hrow; selGrpSlot=grpSlot
            -- White border highlight
            BD(hrow,0.12,0.12,0.12,1,1,1,1)
            -- Update banner to show which group is targeted
            addGrpBannerLbl:SetText("Adding to:  |cFFFFFFFF"..grpLabel.."|r")
            addGrpBannerLbl:SetTextColor(0.5,1.0,0.5,1)
            BD(addGrpBanner,0.06,0.14,0.06,1,0.25,0.75,0.25)
        end
    end

    -- ============================================================
    -- TAB 3: Defensives / Racials
    -- ============================================================
    do
        local p=tabPanels[3]; local py=10
        local tip=p:CreateFontString(nil,"OVERLAY"); tip:SetFont("Fonts\\ARIALN.TTF",10,""); tip:SetTextColor(0.55,0.55,0.55,1)
        tip:SetText("Add class defensives for your spec, or all racials. Only learned spells show icons.")
        tip:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py); tip:SetWidth(EW); py=py+20

        -- Add All Class Defensives
        local defBtn=CreateFrame("Button",nil,p,"BackdropTemplate"); defBtn:SetSize(EW,28); defBtn:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py)
        BD(defBtn,0.07,0.12,0.20,1,0.24,0.49,0.73,1)
        local dbl=defBtn:CreateFontString(nil,"OVERLAY"); dbl:SetFont("Fonts\\ARIALN.TTF",GFS(),""); dbl:SetTextColor(0.5,0.8,1.0,1)
        dbl:SetText("+ Add All Class Defensives  (current spec)"); dbl:SetAllPoints(); dbl:SetJustifyH("CENTER")
        defBtn:SetScript("OnEnter",function() defBtn:SetBackdropColor(0.12,0.20,0.35,1); defBtn:SetBackdropBorderColor(0.35,0.65,1.0,1); dbl:SetTextColor(1,1,1,1) end)
        defBtn:SetScript("OnLeave",function() BD(defBtn,0.07,0.12,0.20,1,0.24,0.49,0.73,1); dbl:SetTextColor(0.5,0.8,1.0,1) end)
        defBtn:SetScript("OnClick",function()
            if type(WinDB().Slots)~="table" then WinDB().Slots={} end
            local _,playerClass=UnitClass("player")
            local specIdx=GetSpecialization()
            if not specIdx then ShowStat("|cFFFF4444No specialization active|r"); return end
            -- Must call directly — Lua 5.1 'and' collapses multiple returns to one
            local specID=GetSpecializationInfo(specIdx)
            local specName=select(2,GetSpecializationInfo(specIdx))
            local specToken=specName and specName:upper():gsub("%s+","") or ""
            local spells=CT_DEFENSIVE_SPELLS[playerClass] and CT_DEFENSIVE_SPELLS[playerClass][specToken]
            if not spells then ShowStat("|cFFFF4444No defensives for "..tostring(playerClass).."/"..tostring(specToken).."|r"); return end
            local added=0; local moved=0
            for id,lbl in pairs(spells) do
                -- Check current window first
                if SlotExistsInWin(WinDB(), "spell", "spellId", id) then
                    -- already here, skip
                else
                    local existWi=SlotExistsInAnyWindow("spell","spellId",id)
                    if existWi then
                        -- Move from other window to this one
                        local srcWin=ConsumableTrackerDB.Windows[existWi]
                        for i,s in ipairs(srcWin.Slots or {}) do
                            if s.type=="spell" and s.spellId==id then
                                table.remove(srcWin.Slots,i)
                                table.insert(WinDB().Slots,s)
                                moved=moved+1; break
                            end
                        end
                    else
                        table.insert(WinDB().Slots,{type="spell",enabled=true,label=lbl,spellId=id,class=playerClass})
                        added=added+1
                    end
                end
            end
            if added>0 or moved>0 then
                local msg=""
                if added>0 then msg=msg.."|cFF44FF44Added "..added.."|r " end
                if moved>0 then msg=msg.."|cFFFFD700Moved "..moved.."|r" end
                ShowStat(msg.." defensive(s)")
                FlashBtn(defBtn,dbl,"Added!","+ Add Defensives for My Spec",0.07,0.12,0.20,0.24,0.49,0.73)
                CT:RefreshLayout(); if rebuildUnifiedList then rebuildUnifiedList() end
            else ShowStat("|cFFFF9900All defensives already in this window|r") end
        end)
        py=py+36

        -- Add All Racials
        local racBtn=CreateFrame("Button",nil,p,"BackdropTemplate"); racBtn:SetSize(EW,28); racBtn:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py)
        BD(racBtn,0.07,0.18,0.07,1,0.25,0.75,0.25,1)
        local ral=racBtn:CreateFontString(nil,"OVERLAY"); ral:SetFont("Fonts\\ARIALN.TTF",GFS(),""); ral:SetTextColor(0.25,0.85,0.25,1)
        ral:SetText("+ Add All Racials  (filtered to your race automatically)"); ral:SetAllPoints(); ral:SetJustifyH("CENTER")
        racBtn:SetScript("OnEnter",function() racBtn:SetBackdropColor(0.10,0.26,0.10,1); racBtn:SetBackdropBorderColor(0.35,1.0,0.35,1); ral:SetTextColor(1,1,1,1) end)
        racBtn:SetScript("OnLeave",function() BD(racBtn,0.07,0.18,0.07,1,0.25,0.75,0.25,1); ral:SetTextColor(0.25,0.85,0.25,1) end)
        racBtn:SetScript("OnClick",function()
            if type(WinDB().Slots)~="table" then WinDB().Slots={} end
            local added=0; local moved=0
            for _,r in ipairs(CT_RACIALS) do
                if SlotExistsInWin(WinDB(), "spell", "spellId", r.id) then
                    -- already here
                else
                    local existWi=SlotExistsInAnyWindow("spell","spellId",r.id)
                    if existWi then
                        local srcWin=ConsumableTrackerDB.Windows[existWi]
                        for i,s in ipairs(srcWin.Slots or {}) do
                            if s.type=="spell" and s.spellId==r.id then
                                table.remove(srcWin.Slots,i)
                                table.insert(WinDB().Slots,s)
                                moved=moved+1; break
                            end
                        end
                    else
                        table.insert(WinDB().Slots,{type="spell",enabled=true,label=r.label,spellId=r.id})
                        added=added+1
                    end
                end
            end
            if added>0 or moved>0 then
                local msg=""
                if added>0 then msg=msg.."|cFF44FF44Added "..added.."|r " end
                if moved>0 then msg=msg.."|cFFFFD700Moved "..moved.."|r" end
                ShowStat(msg.." racial(s)")
                FlashBtn(racBtn,ral,"Added!","+ Add All Racials  (filtered to your race automatically)",0.07,0.18,0.07,0.25,0.75,0.25)
                CT:RefreshLayout(); if rebuildUnifiedList then rebuildUnifiedList() end
            else ShowStat("|cFFFF9900All racials already in this window|r") end
        end)
        py=py+36

        local sep=p:CreateTexture(nil,"ARTWORK"); sep:SetHeight(1); sep:SetColorTexture(0.20,0.20,0.20,1)
        sep:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py); sep:SetWidth(EW); py=py+10

        local manLbl=p:CreateFontString(nil,"OVERLAY"); manLbl:SetFont("Fonts\\ARIALN.TTF",10,""); manLbl:SetTextColor(0.55,0.55,0.55,1)
        manLbl:SetText("Or add a custom spell manually:"); manLbl:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py); py=py+18

        local spellType="racial"
        local typeRacialBtn=CreateFrame("Button",nil,p,"BackdropTemplate"); typeRacialBtn:SetSize(90,22); typeRacialBtn:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py)
        local function RefST()
            BD(typeRacialBtn,0.18,0.37,0.58,1,0.24,0.49,0.73,1)
        end
        local rtl=typeRacialBtn:CreateFontString(nil,"OVERLAY"); rtl:SetFont("Fonts\\ARIALN.TTF",10,""); rtl:SetTextColor(1,1,1,1); rtl:SetText("Racial"); rtl:SetAllPoints(); rtl:SetJustifyH("CENTER")
        typeRacialBtn:SetScript("OnClick",function() spellType="racial"; RefST() end)
        RefST(); py=py+30

        local sIdLbl=p:CreateFontString(nil,"OVERLAY"); sIdLbl:SetFont("Fonts\\ARIALN.TTF",GFS(),""); sIdLbl:SetTextColor(0.9,0.9,0.9,1); sIdLbl:SetText("Spell ID:")
        sIdLbl:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py); py=py+16
        local sIdBox=CreateFrame("EditBox",nil,p,"InputBoxTemplate"); sIdBox:SetSize(EW,20); sIdBox:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py)
        sIdBox:SetAutoFocus(false); sIdBox:SetFont("Fonts\\ARIALN.TTF",GFS(),""); sIdBox:SetTextColor(0.9,0.9,0.9,1); sIdBox:SetTextInsets(6,6,0,0); sIdBox:SetText("")
        sIdBox:SetScript("OnEscapePressed",function(sv) sv:ClearFocus() end)
        py=py+26
        local sAddBtn=CreateFrame("Button",nil,p,"BackdropTemplate"); sAddBtn:SetSize(EW,24); sAddBtn:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py)
        BD(sAddBtn,0.11,0.11,0.11,1,0.22,0.22,0.22)
        local sal=sAddBtn:CreateFontString(nil,"OVERLAY"); sal:SetFont("Fonts\\ARIALN.TTF",GFS(),""); sal:SetTextColor(0.25,0.75,0.25,1); sal:SetText("+ Add Spell"); sal:SetAllPoints(); sal:SetJustifyH("CENTER")
        sAddBtn:SetScript("OnEnter",function() sAddBtn:SetBackdropColor(0.06,0.18,0.06,1); sAddBtn:SetBackdropBorderColor(0.25,0.75,0.25,1); sal:SetTextColor(1,1,1,1) end)
        sAddBtn:SetScript("OnLeave",function() BD(sAddBtn,0.11,0.11,0.11,1,0.22,0.22,0.22); sal:SetTextColor(0.25,0.75,0.25,1) end)
        local function DoAddSpell()
            local rawId=sIdBox:GetText():match("^%s*(%d+)%s*$"); local id=tonumber(rawId)
            if not id or id<=0 then ShowStat("|cFFFF4444Invalid spell ID|r"); return end
            if type(WinDB().Slots)~="table" then WinDB().Slots={} end
            -- Block re-add in same window
            if SlotExistsInWin(WinDB(), "spell", "spellId", id) then
                ShowStat("|cFFFF9900Already in this window|r"); return
            end
            -- Auto-move from another window
            local existWi=SlotExistsInAnyWindow("spell","spellId",id)
            if existWi then
                local srcWin=ConsumableTrackerDB.Windows[existWi]
                for i,s in ipairs(srcWin.Slots or {}) do
                    if s.type=="spell" and s.spellId==id then
                        table.remove(srcWin.Slots,i)
                        table.insert(WinDB().Slots,s)
                        ShowStat("|cFFFFD700Moved from Window "..existWi.."|r")
                        CT:RefreshLayout(); if rebuildUnifiedList then rebuildUnifiedList() end
                        sIdBox:SetText(""); return
                    end
                end
            end
            local lbl=(C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or ("Spell "..id)
            local _,race=UnitRace("player"); local _,class=UnitClass("player")
            local entry={type="spell",enabled=true,label=lbl,spellId=id}
            if spellType=="racial" then entry.race=race; ShowStat("|cFF44FF44Added racial: "..lbl.."|r")
            else entry.class=class; ShowStat("|cFF44FF44Added class ability: "..lbl.."|r") end
            table.insert(WinDB().Slots,entry); sIdBox:SetText("")
            FlashBtn(sAddBtn,sal,"Added!","+ Add Spell / Ability")
            CT:RefreshLayout(); if rebuildUnifiedList then rebuildUnifiedList() end
        end
        sAddBtn:SetScript("OnClick",DoAddSpell)
        sIdBox:SetScript("OnEnterPressed",function() DoAddSpell(); sIdBox:ClearFocus() end)
    end

    -- ============================================================
    -- TAB 4: Class Abilities
    -- ============================================================
    do
        local p=tabPanels[4]; local py=10

        local hdr=p:CreateFontString(nil,"OVERLAY"); hdr:SetFont("Fonts\\ARIALN.TTF",GFS()+1,"OUTLINE")
        hdr:SetTextColor(0.55,0.85,1.0,1); hdr:SetText("Class Abilities")
        hdr:SetPoint("TOP",p,"TOP",0,-py); hdr:SetWidth(EW); hdr:SetJustifyH("CENTER"); py=py+20

        local tip=p:CreateFontString(nil,"OVERLAY"); tip:SetFont("Fonts\\ARIALN.TTF",10,""); tip:SetTextColor(0.5,0.5,0.5,1)
        tip:SetText("Add a class ability by Spell ID. It will appear in the Class Abilities section of the list above.")
        tip:SetPoint("TOP",p,"TOP",0,-py); tip:SetWidth(EW); tip:SetJustifyH("CENTER"); py=py+28

        local caIdLbl=p:CreateFontString(nil,"OVERLAY"); caIdLbl:SetFont("Fonts\\ARIALN.TTF",GFS(),""); caIdLbl:SetTextColor(0.9,0.9,0.9,1)
        caIdLbl:SetText("Spell ID:"); caIdLbl:SetPoint("TOP",p,"TOP",0,-py); caIdLbl:SetWidth(EW); caIdLbl:SetJustifyH("CENTER"); py=py+16

        local caIdBox=CreateFrame("EditBox",nil,p,"InputBoxTemplate"); caIdBox:SetSize(EW,20); caIdBox:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py)
        caIdBox:SetAutoFocus(false); caIdBox:SetFont("Fonts\\ARIALN.TTF",GFS(),""); caIdBox:SetTextColor(0.9,0.9,0.9,1); caIdBox:SetTextInsets(6,6,0,0); caIdBox:SetText("")
        caIdBox:SetScript("OnEscapePressed",function(sv) sv:ClearFocus() end); py=py+26

        local caAddBtn=CreateFrame("Button",nil,p,"BackdropTemplate"); caAddBtn:SetSize(EW,24); caAddBtn:SetPoint("TOPLEFT",p,"TOPLEFT",0,-py)
        BD(caAddBtn,0.08,0.14,0.22,1,0.24,0.49,0.73)
        local cal=caAddBtn:CreateFontString(nil,"OVERLAY"); cal:SetFont("Fonts\\ARIALN.TTF",GFS(),""); cal:SetTextColor(0.5,0.8,1.0,1)
        cal:SetText("+ Add Class Ability"); cal:SetAllPoints(); cal:SetJustifyH("CENTER")
        caAddBtn:SetScript("OnEnter",function() caAddBtn:SetBackdropColor(0.12,0.22,0.38,1); caAddBtn:SetBackdropBorderColor(0.35,0.65,1.0,1); cal:SetTextColor(1,1,1,1) end)
        caAddBtn:SetScript("OnLeave",function() BD(caAddBtn,0.08,0.14,0.22,1,0.24,0.49,0.73); cal:SetTextColor(0.5,0.8,1.0,1) end)

        local function DoAddCA()
            local rawId=caIdBox:GetText():match("^%s*(%d+)%s*$"); local id=tonumber(rawId)
            if not id or id<=0 then ShowStat("|cFFFF4444Invalid spell ID|r"); return end
            if type(WinDB().Slots)~="table" then WinDB().Slots={} end
            if SlotExistsInWin(WinDB(),"spell","spellId",id) then
                FlashBtnErr(caAddBtn,cal,"Already added","+ Add Class Ability",0.08,0.14,0.22,0.24,0.49,0.73); return
            end
            local existWi=SlotExistsInAnyWindow("spell","spellId",id)
            if existWi then
                local srcWin=ConsumableTrackerDB.Windows[existWi]
                for i,s in ipairs(srcWin.Slots or {}) do
                    if s.type=="spell" and s.spellId==id then
                        table.remove(srcWin.Slots,i); table.insert(WinDB().Slots,s)
                        FlashBtn(caAddBtn,cal,"Moved!","+ Add Class Ability",0.08,0.14,0.22,0.24,0.49,0.73)
                        caIdBox:SetText(""); CT:RefreshLayout()
                        if rebuildUnifiedList then rebuildUnifiedList() end; return
                    end
                end
            end
            local lbl=(C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or ("Spell "..id)
            local _,class=UnitClass("player")
            table.insert(WinDB().Slots,{type="spell",spellType="classability",enabled=true,label=lbl,spellId=id,class=class})
            caIdBox:SetText(""); FlashBtn(caAddBtn,cal,"Added!","+ Add Class Ability",0.08,0.14,0.22,0.24,0.49,0.73)
            ShowStat("|cFF44FF44Added class ability: "..lbl.."|r")
            CT:RefreshLayout()
            if rebuildUnifiedList then rebuildUnifiedList() end
        end
        caAddBtn:SetScript("OnClick",DoAddCA)
        caIdBox:SetScript("OnEnterPressed",function() DoAddCA(); caIdBox:ClearFocus() end)
    end

    -- Show default tab
    ShowTab(activeTab)

    -- ============================================================
    -- Unified list builder — sectioned with collapsible headers
    -- ============================================================
    local sectionCollapsed={racials=true,defensives=true,consumables=true,gear=true,classabilities=true}

    local SECTION_META={
        racials=       {key="racials",       label="Racials",                     color={0.25,0.75,0.25}},
        defensives=    {key="defensives",    label="Defensives  (class-specific)", color={0.24,0.49,0.73}},
        consumables=   {key="consumables",   label="Consumables",                  color={0.85,0.45,0.10}},
        gear=          {key="gear",          label="Gear On-Use",                  color={0.10,0.65,0.65}},
        classabilities={key="classabilities",label="Class Abilities",              color={0.55,0.85,1.00}},
    }

    local function GetSectionOrder()
        if type(GDB().SectionOrder)=="table" and #GDB().SectionOrder==5 then
            return GDB().SectionOrder
        end
        return {"racials","defensives","classabilities","consumables","gear"}
    end

    local function SlotSection(slot)
        if slot.type=="equip" then return "gear" end
        if slot.type=="healthstone" or slot.type=="group" or slot.type=="item" then return "consumables" end
        if slot.type=="spell" then
            if slot.spellType=="classability" then return "classabilities" end
            if slot.class then return "defensives" end
            return "racials"
        end
        return "consumables"
    end

    -- Move all icons belonging to secKey one position earlier/later in the section order,
    -- then reorder WinDB().Slots so icons follow that new section order.
    local function MoveSectionInOrder(secKey, direction)
        local db2=ConsumableTrackerDB
        local order=GetSectionOrder()
        local pos=nil
        for i,k in ipairs(order) do if k==secKey then pos=i; break end end
        if not pos then return end
        local newPos=pos+direction
        if newPos<1 or newPos>#order then return end
        order[pos],order[newPos]=order[newPos],order[pos]
        GDB().SectionOrder=order

        -- Rebuild UnifiedIcons order to match new section order
        local buckets={}
        for _,k in ipairs(order) do buckets[k]={} end
        for _,slot in ipairs(WinDB().Slots or {}) do
            local sec=SlotSection(slot)
            if buckets[sec] then table.insert(buckets[sec],slot)
            else table.insert(buckets["consumables"],slot) end
        end
        local newList={}
        for _,k in ipairs(order) do for _,slot in ipairs(buckets[k]) do table.insert(newList,slot) end end
        WinDB().Slots=newList
        CT:RefreshLayout()
        rebuildUnifiedList()
    end

    rebuildUnifiedList=function()
        if not unifiedListHolder then return end
        for _,child in next,{unifiedListHolder:GetChildren()} do child:Hide(); child:SetParent(nil) end
        for _,reg   in next,{unifiedListHolder:GetRegions()}  do reg:Hide() end

        local icons=WinDB().Slots or {}
        local filter=(CT._searchFilter or ""):lower()
        local ry=0; local ROW_H=46; local PROW_H=54; local GAP=2
        local SECT_H=28

        -- Build sections in DB order
        local order=GetSectionOrder()
        local sectionItems={}
        for _,k in ipairs(order) do sectionItems[k]={} end
        for idx,slot in ipairs(icons) do
            local sec=SlotSection(slot)
            if sectionItems[sec] then table.insert(sectionItems[sec],{idx=idx,slot=slot}) end
        end


        -- Helper: build a custom timer sub-row for any slot type
        local function BuildCustomTimerRow(capturedSlot, capturedIdx, indentX)
            local ctRow=CreateFrame("Frame",nil,unifiedListHolder,"BackdropTemplate")
            ctRow:SetPoint("TOPLEFT",unifiedListHolder,"TOPLEFT",indentX,-ry)
            ctRow:SetPoint("TOPRIGHT",unifiedListHolder,"TOPRIGHT",-2,-ry); ctRow:SetHeight(28)
            BD(ctRow,0.06,0.08,0.06,1,0.14,0.22,0.14)

            local ctLblTxt=ctRow:CreateFontString(nil,"OVERLAY"); ctLblTxt:SetFont("Fonts\\ARIALN.TTF",9,"")
            ctLblTxt:SetTextColor(0.55,0.85,0.55,1); ctLblTxt:SetText("Buff timer (sec):")
            ctLblTxt:SetPoint("LEFT",ctRow,"LEFT",8,0)

            local ctDurBox=CreateFrame("EditBox",nil,ctRow,"InputBoxTemplate"); ctDurBox:SetSize(42,18)
            ctDurBox:SetPoint("LEFT",ctRow,"LEFT",120,0)
            ctDurBox:SetAutoFocus(false); ctDurBox:SetFont("Fonts\\ARIALN.TTF",GFS(),"")
            ctDurBox:SetTextColor(1,0.9,0.3,1); ctDurBox:SetTextInsets(4,4,0,0); ctDurBox:SetJustifyH("CENTER")
            ctDurBox:SetText(capturedSlot.customTimerDuration and tostring(capturedSlot.customTimerDuration) or "")
            ctDurBox:SetScript("OnEscapePressed",function(sv) sv:ClearFocus() end)
            local function SaveDur(sv)
                local v=tonumber(sv:GetText())
                local s=WinDB().Slots[capturedIdx]; if s then s.customTimerDuration=v end
                sv:ClearFocus()
            end
            ctDurBox:SetScript("OnEnterPressed",SaveDur)
            ctDurBox:SetScript("OnEditFocusLost",SaveDur)

            local ctTxtLbl=ctRow:CreateFontString(nil,"OVERLAY"); ctTxtLbl:SetFont("Fonts\\ARIALN.TTF",9,"")
            ctTxtLbl:SetTextColor(0.55,0.85,0.55,1); ctTxtLbl:SetText("label:")
            ctTxtLbl:SetPoint("LEFT",ctRow,"LEFT",172,0)

            local ctTxtBox=CreateFrame("EditBox",nil,ctRow,"InputBoxTemplate"); ctTxtBox:SetSize(90,18)
            ctTxtBox:SetPoint("LEFT",ctRow,"LEFT",210,0)
            ctTxtBox:SetAutoFocus(false); ctTxtBox:SetFont("Fonts\\ARIALN.TTF",GFS(),"")
            ctTxtBox:SetTextColor(0.9,0.9,0.9,1); ctTxtBox:SetTextInsets(4,4,0,0)
            ctTxtBox:SetText(capturedSlot.customTimerText or "")
            ctTxtBox:SetScript("OnEscapePressed",function(sv) sv:ClearFocus() end)
            local function SaveTxt(sv)
                local v=sv:GetText():match("^%s*(.-)%s*$") or ""
                local s=WinDB().Slots[capturedIdx]; if s then s.customTimerText=(v~="" and v or nil) end
                sv:ClearFocus()
            end
            ctTxtBox:SetScript("OnEnterPressed",SaveTxt)
            ctTxtBox:SetScript("OnEditFocusLost",SaveTxt)

            local ctClrBtn=CreateFrame("Button",nil,ctRow,"BackdropTemplate"); ctClrBtn:SetSize(36,18)
            ctClrBtn:SetPoint("LEFT",ctRow,"LEFT",308,0)
            BD(ctClrBtn,0.20,0.08,0.08,1,0.45,0.15,0.15)
            local ctClrL=ctClrBtn:CreateFontString(nil,"OVERLAY"); ctClrL:SetFont("Fonts\\ARIALN.TTF",9,"")
            ctClrL:SetTextColor(1,0.5,0.5,1); ctClrL:SetText("Clear"); ctClrL:SetAllPoints(); ctClrL:SetJustifyH("CENTER")
            ctClrBtn:SetScript("OnClick",function()
                local s=WinDB().Slots[capturedIdx]; if s then s.customTimerDuration=nil; s.customTimerText=nil end
                ctDurBox:SetText(""); ctTxtBox:SetText("")
            end)
            ry=ry+30
        end

        local function DrawIconRow(entry,isLastInSection)
            local idx=entry.idx; local slot=entry.slot
            local tc=TYPE_COLORS[slot.type] or {0.4,0.4,0.4}
            local tl=TYPE_LABELS[slot.type] or "??"
            local isGroup=(slot.type=="group")
            local collapsed = groupCollapsed[idx]
            if collapsed == nil then collapsed = true end  -- collapsed by default

            local hrow=CreateFrame("Frame",nil,unifiedListHolder,"BackdropTemplate")
            hrow:SetPoint("TOPLEFT",unifiedListHolder,"TOPLEFT",0,-ry)
            hrow:SetPoint("TOPRIGHT",unifiedListHolder,"TOPRIGHT",0,-ry); hrow:SetHeight(ROW_H)
            BD(hrow,0.10,0.10,0.10,1,tc[1]*0.5,tc[2]*0.5,tc[3]*0.5)

            local badge=CreateFrame("Frame",nil,hrow,"BackdropTemplate"); badge:SetSize(28,ROW_H-4); badge:SetPoint("LEFT",hrow,"LEFT",2,0)
            BD(badge,tc[1]*0.3,tc[2]*0.3,tc[3]*0.3,1,tc[1],tc[2],tc[3])
            local badgeLbl=badge:CreateFontString(nil,"OVERLAY"); badgeLbl:SetFont("Fonts\\ARIALN.TTF",8,"OUTLINE")
            badgeLbl:SetTextColor(tc[1],tc[2],tc[3],1); badgeLbl:SetText(tl); badgeLbl:SetAllPoints(); badgeLbl:SetJustifyH("CENTER")

            local nextLeft=badge
            if isGroup then
                local tBtn=CreateFrame("Button",nil,hrow,"BackdropTemplate"); tBtn:SetSize(18,18); tBtn:SetPoint("LEFT",badge,"RIGHT",2,0)
                BD(tBtn,0.09,0.09,0.09,1,0.22,0.22,0.22)
                local tLbl=tBtn:CreateFontString(nil,"OVERLAY"); tLbl:SetFont("Fonts\\ARIALN.TTF",10,""); tLbl:SetText(collapsed and "+" or "-"); tLbl:SetAllPoints(); tLbl:SetJustifyH("CENTER")
                local cidx=idx; tBtn:SetScript("OnClick",function() groupCollapsed[cidx]=not groupCollapsed[cidx]; C_Timer.After(0.01,rebuildUnifiedList) end)
                nextLeft=tBtn
            end

            local icoF=CreateFrame("Frame",nil,hrow,"BackdropTemplate"); icoF:SetSize(22,22); icoF:SetPoint("LEFT",nextLeft,"RIGHT",3,0)
            BD(icoF,0.09,0.09,0.09,1,0.22,0.22,0.22)
            local icoTex=icoF:CreateTexture(nil,"ARTWORK"); icoTex:SetAllPoints(); icoTex:SetTexCoord(0.07,0.93,0.07,0.93)
            if slot.type=="healthstone" then
                local tex=GetItemIcon(5512); if tex then icoTex:SetTexture(tex) else icoTex:SetColorTexture(0.3,0.3,0.3,1) end
            elseif slot.type=="group" then
                local activeId; for pi=1,4 do local pid=slot["p"..pi]; if pid and pid>0 then if not activeId then activeId=pid end; if C_Item.GetItemCount(pid,false,true)>0 then activeId=pid; break end end end
                if activeId then local tx=select(10,GetItemInfo(activeId)); if tx then icoTex:SetTexture(tx) else icoTex:SetColorTexture(0.3,0.3,0.3,1) end else icoTex:SetColorTexture(0.3,0.3,0.3,1) end
            elseif slot.type=="spell" then
                local stex=C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(slot.spellId)
                if stex then icoTex:SetTexture(stex) else icoTex:SetColorTexture(0.3,0.3,0.3,1) end
            elseif slot.type=="item" then
                local itx=select(10,GetItemInfo(slot.itemId)); if itx then icoTex:SetTexture(itx) else icoTex:SetColorTexture(0.3,0.3,0.3,1) end
            elseif slot.type=="equip" then
                local eItemId=slot.slot and GetInventoryItemID("player",slot.slot)
                local etx=eItemId and eItemId>0 and select(10,GetItemInfo(eItemId))
                if etx then icoTex:SetTexture(etx) else icoTex:SetColorTexture(0.2,0.2,0.2,1) end
            end

            -- Tooltip on icon hover inside the settings window
            icoF:EnableMouse(true)
            icoF:SetScript("OnEnter",function()
                if slot.type=="healthstone" then
                    GameTooltip:SetOwner(icoF,"ANCHOR_RIGHT"); GameTooltip:SetItemByID(5512); GameTooltip:Show()
                elseif slot.type=="group" then
                    local aid; for pi=1,4 do local pid=slot["p"..pi]; if pid and pid>0 then if not aid then aid=pid end; if C_Item.GetItemCount(pid,false,true)>0 then aid=pid; break end end end
                    if aid then GameTooltip:SetOwner(icoF,"ANCHOR_RIGHT"); GameTooltip:SetItemByID(aid); GameTooltip:Show() end
                elseif slot.type=="item" then
                    GameTooltip:SetOwner(icoF,"ANCHOR_RIGHT"); GameTooltip:SetItemByID(slot.itemId); GameTooltip:Show()
                elseif slot.type=="spell" then
                    local sid=slot._resolvedSpellId or slot.spellId
                    GameTooltip:SetOwner(icoF,"ANCHOR_RIGHT"); GameTooltip:SetSpellByID(sid); GameTooltip:Show()
                elseif slot.type=="equip" then
                    local eItemId=slot.slot and GetInventoryItemID("player",slot.slot)
                    if eItemId and eItemId>0 then
                        GameTooltip:SetOwner(icoF,"ANCHOR_RIGHT"); GameTooltip:SetItemByID(eItemId); GameTooltip:Show()
                    end
                end
            end)
            icoF:SetScript("OnLeave",function() GameTooltip:Hide() end)

            -- Order arrows — section-aware: only swap with the nearest item in the same section
            local capturedIdx=idx
            local capturedSlot=slot  -- identity reference
            local capturedSection=SlotSection(slot)
            local upBtn,dnBtn,arrowCompound=MakeOrderArrows(hrow,ROW_H,
                function()
                    local g=WinDB().Slots
                    local cur=nil; for i,s in ipairs(g) do if s==capturedSlot then cur=i; break end end
                    if not cur then return end
                    -- Find nearest item above in the same section
                    local target=nil
                    for i=cur-1,1,-1 do
                        if SlotSection(g[i])==capturedSection then target=i; break end
                    end
                    if not target then return end
                    g[cur],g[target]=g[target],g[cur]
                    CT:RefreshLayout(); rebuildUnifiedList()
                end,
                function()
                    local g=WinDB().Slots
                    local cur=nil; for i,s in ipairs(g) do if s==capturedSlot then cur=i; break end end
                    if not cur then return end
                    -- Find nearest item below in the same section
                    local target=nil
                    for i=cur+1,#g do
                        if SlotSection(g[i])==capturedSection then target=i; break end
                    end
                    if not target then return end
                    g[cur],g[target]=g[target],g[cur]
                    CT:RefreshLayout(); rebuildUnifiedList()
                end)

            local delB=CreateFrame("Button",nil,hrow,"BackdropTemplate"); delB:SetSize(22,22); delB:SetPoint("RIGHT",arrowCompound,"LEFT",-3,0)
            BD(delB,0.12,0.12,0.12,1,0.22,0.22,0.22)
            local dl=delB:CreateFontString(nil,"OVERLAY"); dl:SetFont("Fonts\\ARIALN.TTF",12,""); dl:SetTextColor(0.80,0.22,0.22,1); dl:SetText("x"); dl:SetAllPoints(); dl:SetJustifyH("CENTER")
            delB:SetScript("OnLeave",function() BD(delB,0.12,0.12,0.12,1,0.22,0.22,0.22); dl:SetTextColor(0.80,0.22,0.22,1) end)
            local delSlot=slot; delB:SetScript("OnClick",function()
                local g=WinDB().Slots
                for i,s in ipairs(g) do if s==delSlot then table.remove(g,i); break end end
                CT:RefreshLayout(); rebuildUnifiedList()
            end)

            -- Enable/disable button — declared first so mvB can reposition it
            local enBtn=CreateFrame("Button",nil,hrow,"BackdropTemplate"); enBtn:SetSize(40,20); enBtn:SetPoint("RIGHT",delB,"LEFT",-4,0)
            local enOn=slot.enabled~=false
            BD(enBtn,enOn and 0.07 or 0.09,enOn and 0.14 or 0.09,enOn and 0.22 or 0.09,1,enOn and 0.24 or 0.22,enOn and 0.49 or 0.22,enOn and 0.73 or 0.22,1)
            local enL=enBtn:CreateFontString(nil,"OVERLAY"); enL:SetFont("Fonts\\ARIALN.TTF",9,""); enL:SetText(enOn and "ON" or "OFF"); enL:SetAllPoints(); enL:SetJustifyH("CENTER")
            enL:SetTextColor(enOn and 0.24 or 0.5,enOn and 0.73 or 0.5,enOn and 1.0 or 0.5,1)
            enBtn:SetScript("OnClick",function()
                local s2=WinDB().Slots[capturedIdx]; if not s2 then return end
                s2.enabled=not(s2.enabled~=false); local now=s2.enabled~=false
                BD(enBtn,now and 0.07 or 0.09,now and 0.14 or 0.09,now and 0.22 or 0.09,1,now and 0.24 or 0.22,now and 0.49 or 0.22,now and 0.73 or 0.22,1)
                enL:SetText(now and "ON" or "OFF"); enL:SetTextColor(now and 0.24 or 0.5,now and 0.73 or 0.5,now and 1.0 or 0.5,1)
                CT:RefreshLayout(); rebuildUnifiedList()
            end)

            -- Move to window — always uses live DB so works for all icon types
            local function HasMultipleWindows()
                local d=ConsumableTrackerDB; return d and d.Windows and #d.Windows > 1
            end
            if HasMultipleWindows() then
                local mvB=CreateFrame("Button",nil,hrow,"BackdropTemplate"); mvB:SetSize(26,20); mvB:SetPoint("RIGHT",delB,"LEFT",-2,0)
                BD(mvB,0.08,0.10,0.18,1,0.20,0.28,0.45)
                local mvL=mvB:CreateFontString(nil,"OVERLAY"); mvL:SetFont("Fonts\\ARIALN.TTF",8,""); mvL:SetTextColor(0.6,0.8,1,1); mvL:SetText("->W"); mvL:SetAllPoints(); mvL:SetJustifyH("CENTER")
                mvB:SetScript("OnEnter",function() mvB:SetBackdropColor(0.14,0.20,0.35,1) end)
                mvB:SetScript("OnLeave",function() BD(mvB,0.08,0.10,0.18,1,0.20,0.28,0.45) end)
                local mvSlot=slot
                mvB:SetScript("OnClick",function()
                    local d=ConsumableTrackerDB; if not d or not d.Windows then return end
                    local menu={}
                    for wi,w in ipairs(d.Windows) do
                        if wi~=_selectedWinIdx then
                            local capW=w
                            table.insert(menu,{label=(w.Name or "Window "..wi), onClick=function()
                                local srcSlots=WinDB().Slots
                                for i,s in ipairs(srcSlots) do
                                    if s==mvSlot then table.remove(srcSlots,i); break end
                                end
                                capW.Slots = capW.Slots or {}
                                table.insert(capW.Slots, mvSlot)
                                CT:RefreshLayout(); rebuildUnifiedList()
                            end})
                        end
                    end
                    CT._ShowDropMenu(mvB, menu)
                end)
                enBtn:ClearAllPoints(); enBtn:SetPoint("RIGHT",mvB,"LEFT",-4,0)
            end

            local nm=hrow:CreateFontString(nil,"OVERLAY"); nm:SetFont("Fonts\\ARIALN.TTF",GFS(),""); nm:SetTextColor(1,1,1,1)
            local nameStr=slot.label~="" and slot.label or (slot.type=="equip" and (SLOT_BY_NUMBER[slot.slot] or "Slot") or slot.type)
            local extra=""
            if slot.type=="spell" then
                -- Show active (resolved) spell ID — may differ from primary if an alt variant is known
                local activeId=slot._resolvedSpellId or slot.spellId
                local known=false; if IsPlayerSpell then local ok,r=pcall(IsPlayerSpell,activeId); if ok and r then known=true end end
                -- Also check alt IDs for display
                if not known then
                    -- Try alts for display purposes (mirrors BestKnownSpellId logic)
                    local ALTS={[121093]={28880,59542,59543,59544,59545,59547,59548,370626,416250},[20572]={33697,33702},[50613]={25046,28730,69179,80483,129597,155145,202719,232633}}
                    if ALTS[slot.spellId] then
                        for _,alt in ipairs(ALTS[slot.spellId]) do
                            if IsPlayerSpell then local ok,r=pcall(IsPlayerSpell,alt); if ok and r then activeId=alt; known=true; break end end
                        end
                    end
                end
                local idStr=" |cFF444466["..tostring(activeId).."]|r"
                if slot.race then extra=" |cFF555555[Racial: "..slot.race.."]|r"..idStr
                elseif slot.class then extra=" |cFF555555[Class: "..slot.class.."]|r"..idStr
                else extra=idStr end
                if not known then extra=extra.." |cFFFF4444(not known)|r" end
            elseif slot.type=="equip" then
                extra=" |cFF555555["..(SLOT_BY_NUMBER[slot.slot] or "Slot "..tostring(slot.slot)).."]|r"
            elseif slot.type=="item" then
                extra=" |cFF444466["..tostring(slot.itemId).."]|r"
            elseif slot.type=="group" then
                local cnt=0; for pi=1,4 do if slot["p"..pi] and slot["p"..pi]>0 then cnt=cnt+1 end end
                extra=" |cFF555555["..cnt.."/4 slots]|r"
            end
            nm:SetText(nameStr..extra)
            nm:SetPoint("LEFT",icoF,"RIGHT",5,0)

            -- For group rows: show inline rename editbox instead of static label
            if isGroup then
                nm:Hide()  -- hide static label, replace with edit box
                local renameBox=CreateFrame("EditBox",nil,hrow,"BackdropTemplate")
                renameBox:SetHeight(20); renameBox:SetAutoFocus(false)
                renameBox:SetFont("Fonts\\ARIALN.TTF",GFS(),""); renameBox:SetTextColor(1,1,1,1)
                renameBox:SetTextInsets(4,4,0,0); renameBox:SetText(slot.label~="" and slot.label or "Group")
                BD(renameBox,0,0,0,0,0,0,0,0)  -- transparent by default
                renameBox:SetScript("OnEditFocusGained",function() BD(renameBox,0.07,0.07,0.07,1,0.24,0.49,0.73,1) end)
                renameBox:SetScript("OnEditFocusLost",function()
                    BD(renameBox,0,0,0,0,0,0,0,0)
                    local newLbl=renameBox:GetText():match("^%s*(.-)%s*$") or ""
                    if newLbl~="" then
                        local s=WinDB().Slots[capturedIdx]; if s then s.label=newLbl end
                    end
                end)
                renameBox:SetScript("OnEnterPressed",function() renameBox:ClearFocus() end)
                renameBox:SetScript("OnEscapePressed",function()
                    renameBox:SetText(slot.label~="" and slot.label or "Group"); renameBox:ClearFocus()
                end)
                renameBox:SetPoint("LEFT",icoF,"RIGHT",5,0); renameBox:SetPoint("RIGHT",enBtn,"LEFT",-6,0)

                -- Also keep the [N/4 slots] count visible as a separate label on right of box
                local cntLbl=hrow:CreateFontString(nil,"OVERLAY"); cntLbl:SetFont("Fonts\\ARIALN.TTF",GFS()-1,"")
                cntLbl:SetTextColor(0.45,0.45,0.45,1); cntLbl:SetText(extra)
                cntLbl:SetPoint("RIGHT",enBtn,"LEFT",-6,0); cntLbl:SetJustifyH("RIGHT")
                renameBox:SetPoint("RIGHT",cntLbl,"LEFT",-4,0)  -- override right anchor to not overlap count
            end  -- if isGroup

            -- For consumable items: gem (N/G/S/F) and border colour controls inline on the row
            if slot.type~="group" then
                nm:SetPoint("RIGHT",enBtn,"LEFT",-6,0); nm:SetJustifyH("LEFT")
            end
            if slot.type=="item" then
                slot.meta=slot.meta or {}
                local itemId=slot.itemId
                slot.meta[itemId]=slot.meta[itemId] or {}
                local metaRef=slot.meta[itemId]

                -- Border colour swatch
                local bsw=CreateFrame("Button",nil,hrow,"BackdropTemplate"); bsw:SetSize(22,14)
                bsw:SetPoint("RIGHT",enBtn,"LEFT",-4,0)
                local function RefBSW2() local c=metaRef.borderColor or {0.15,0.15,0.15,1}; BD(bsw,c[1],c[2],c[3],1,c[1]*1.5,c[2]*1.5,c[3]*1.5) end; RefBSW2()
                local cmeta2=metaRef
                bsw:SetScript("OnClick",function()
                    local c=cmeta2.borderColor or {0,0,0,1}; local prev={c[1],c[2],c[3],c[4] or 1}
                    local function Apply() local r,g,b=ColorPickerFrame:GetColorRGB(); local a=1-(ColorPickerFrame:GetColorAlpha() or 0); cmeta2.borderColor={r,g,b,a}; RefBSW2(); CT:RefreshLayout() end
                    ColorPickerFrame:SetupColorPickerAndShow({swatchFunc=Apply,opacityFunc=Apply,cancelFunc=function() cmeta2.borderColor=prev; RefBSW2(); CT:RefreshLayout() end,hasOpacity=true,opacity=1-(c[4] or 1),r=c[1],g=c[2],b=c[3]})
                end)
                bsw:SetScript("OnLeave",function() RefBSW2() end)

                -- Gem buttons N/G/S/F
                local gemDefs2={{key="none",label="N",r=0.35,g=0.35,b=0.35},{key="gold",label="G",r=1.00,g=0.82,b=0.00},{key="silver",label="S",r=0.80,g=0.80,b=0.85},{key="F",label="F",r=0.80,g=0.60,b=0.10}}
                local gemRefs2={}; local rightRef2=bsw; local cmeta3=metaRef
                local function RefGemBtns2() local curGem=cmeta3.gemColor or "none"
                    for _,gbi in ipairs(gemRefs2) do local act=(curGem==gbi.key)
                        BD(gbi.btn,act and gbi.r*0.6 or 0.09,act and gbi.g*0.6 or 0.09,act and gbi.b*0.6 or 0.09,1,act and gbi.r or 0.22,act and gbi.g or 0.22,act and gbi.b or 0.22,1)
                        gbi.lbl:SetTextColor(act and 1 or 0.45,act and 1 or 0.45,act and 1 or 0.45,1) end end
                for _,gd in ipairs(gemDefs2) do
                    local gb=CreateFrame("Button",nil,hrow,"BackdropTemplate"); gb:SetSize(18,18); gb:SetPoint("RIGHT",rightRef2,"LEFT",-2,0)
                    local curAct=(cmeta3.gemColor or "none")==gd.key
                    BD(gb,curAct and gd.r*0.6 or 0.09,curAct and gd.g*0.6 or 0.09,curAct and gd.b*0.6 or 0.09,1,curAct and gd.r or 0.22,curAct and gd.g or 0.22,curAct and gd.b or 0.22,1)
                    local gl2=gb:CreateFontString(nil,"OVERLAY"); gl2:SetFont("Fonts\\ARIALN.TTF",9,""); gl2:SetTextColor(curAct and 1 or 0.45,curAct and 1 or 0.45,curAct and 1 or 0.45,1); gl2:SetText(gd.label); gl2:SetAllPoints(); gl2:SetJustifyH("CENTER")
                    table.insert(gemRefs2,{btn=gb,lbl=gl2,key=gd.key,r=gd.r,g=gd.g,b=gd.b})
                    gb:SetScript("OnLeave",function() RefGemBtns2() end)
                    local cgkey=gd.key; local capIdx2=capturedIdx; local capItemId=itemId
                    gb:SetScript("OnClick",function()
                        local s=WinDB().Slots[capIdx2]; if not s then return end
                        s.meta=s.meta or {}; s.meta[capItemId]=s.meta[capItemId] or {}
                        s.meta[capItemId].gemColor=cgkey; RefGemBtns2(); CT:RefreshLayout()
                    end)
                    rightRef2=gb
                end
                RefGemBtns2()
                nm:SetPoint("RIGHT",rightRef2,"LEFT",-6,0); nm:SetJustifyH("LEFT")
            end

            if isGroup then
                hrow:EnableMouse(true)
                local capSlotRef=slot; local capHrow=hrow
                hrow:SetScript("OnMouseDown",function()
                    ShowTab(2)
                    local lbl=capSlotRef.label~="" and capSlotRef.label or "Group "..capturedIdx
                    if CT._setConsGrpIdx then CT._setConsGrpIdx(capturedIdx,lbl,nil,nil) end
                    if CT._selectGroupRow then CT._selectGroupRow(capHrow,capSlotRef,lbl) end
                end)
            end

            ry=ry+ROW_H+GAP

            -- Custom timer row for spells (racials, defensives, class abilities) and equip
            if slot.type=="spell" or slot.type=="equip" then
                BuildCustomTimerRow(slot, capturedIdx, 4)
            end

            -- P1-P4 sub-rows
            if isGroup and not collapsed then
                for pi=1,4 do
                    local prow=CreateFrame("Button",nil,unifiedListHolder,"BackdropTemplate")
                    prow:SetPoint("TOPLEFT",unifiedListHolder,"TOPLEFT",30,-ry)
                    prow:SetPoint("TOPRIGHT",unifiedListHolder,"TOPRIGHT",-2,-ry); prow:SetHeight(PROW_H)
                    BD(prow,0.08,0.08,0.08,1,0.16,0.16,0.16)

                    -- P# badge on left, full height
                    local pbadge=prow:CreateFontString(nil,"OVERLAY"); pbadge:SetFont("Fonts\\ARIALN.TTF",GFS(),"OUTLINE")
                    pbadge:SetTextColor(0.24,0.49,0.73,1); pbadge:SetText("P"..pi)
                    pbadge:SetPoint("LEFT",prow,"LEFT",5,0)

                    local pid=slot["p"..pi]
                    if pid and pid>0 then
                        -- Item icon
                        local piico=prow:CreateTexture(nil,"ARTWORK"); piico:SetSize(18,18)
                        piico:SetPoint("LEFT",prow,"LEFT",28,0); piico:SetTexCoord(0.07,0.93,0.07,0.93)
                        local pitx=select(10,GetItemInfo(pid)); if pitx then piico:SetTexture(pitx) else piico:SetColorTexture(0.3,0.3,0.3,1) end

                        -- Tooltip on icon
                        prow:SetScript("OnEnter",function()
                            GameTooltip:SetOwner(prow,"ANCHOR_RIGHT"); GameTooltip:SetItemByID(pid); GameTooltip:Show()
                        end)
                        prow:SetScript("OnLeave",function() GameTooltip:Hide(); prow:SetBackdropColor(0.08,0.08,0.08,1) end)

                        -- Item name top-right area
                        local iname=GetItemInfo(pid)
                        local inm=prow:CreateFontString(nil,"OVERLAY"); inm:SetFont("Fonts\\ARIALN.TTF",GFS(),"")
                        inm:SetTextColor(1,1,1,1); inm:SetText((iname or ("ID: "..pid)).." |cFF444466["..pid.."]|r")
                        inm:SetPoint("TOPLEFT",prow,"TOPLEFT",50,-4)
                        inm:SetPoint("TOPRIGHT",prow,"TOPRIGHT",-6,-4)
                        inm:SetJustifyH("LEFT")

                        -- Bottom row: x button on far right
                        local prem=CreateFrame("Button",nil,prow,"BackdropTemplate"); prem:SetSize(22,20)
                        prem:SetPoint("BOTTOMRIGHT",prow,"BOTTOMRIGHT",-2,3)
                        BD(prem,0.12,0.12,0.12,1,0.22,0.22,0.22)
                        local prl=prem:CreateFontString(nil,"OVERLAY"); prl:SetFont("Fonts\\ARIALN.TTF",9,"")
                        prl:SetTextColor(0.80,0.22,0.22,1); prl:SetText("x"); prl:SetAllPoints(); prl:SetJustifyH("CENTER")
                        prem:SetScript("OnLeave",function() BD(prem,0.12,0.12,0.12,1,0.22,0.22,0.22); prl:SetTextColor(0.80,0.22,0.22,1) end)
                        local pgik,ppkey=idx,"p"..pi
                        prem:SetScript("OnClick",function() local s3=WinDB().Slots[pgik]; if not s3 then return end; s3[ppkey]=nil; CT:RefreshLayout(); rebuildUnifiedList() end)

                        -- Border swatch
                        slot.meta=slot.meta or {}; slot.meta[pid]=slot.meta[pid] or {}; local metaRef=slot.meta[pid]
                        local bsw=CreateFrame("Button",nil,prow,"BackdropTemplate"); bsw:SetSize(26,16)
                        bsw:SetPoint("BOTTOMRIGHT",prem,"BOTTOMLEFT",-3,2)
                        local function RefBSW() local c=metaRef.borderColor or {0.15,0.15,0.15,1}; BD(bsw,c[1],c[2],c[3],1,math.min(1,c[1]*1.5+0.1),math.min(1,c[2]*1.5+0.1),math.min(1,c[3]*1.5+0.1)) end; RefBSW()
                        local cmeta2=metaRef; bsw:SetScript("OnClick",function()
                            local c=cmeta2.borderColor or {0,0,0,1}; local prev={c[1],c[2],c[3],c[4] or 1}
                            local function Apply() local r,g,b=ColorPickerFrame:GetColorRGB(); local a=1-(ColorPickerFrame:GetColorAlpha() or 0); cmeta2.borderColor={r,g,b,a}; RefBSW(); CT:RefreshLayout() end
                            ColorPickerFrame:SetupColorPickerAndShow({swatchFunc=Apply,opacityFunc=Apply,cancelFunc=function() cmeta2.borderColor=prev; RefBSW(); CT:RefreshLayout() end,hasOpacity=true,opacity=1-(c[4] or 1),r=c[1],g=c[2],b=c[3]})
                        end)
                        bsw:SetScript("OnLeave",function() RefBSW() end)

                        -- Gem buttons N/G/S/F
                        local gemDefs={{key="none",label="N",r=0.35,g=0.35,b=0.35},{key="gold",label="G",r=1.00,g=0.82,b=0.00},{key="silver",label="S",r=0.80,g=0.80,b=0.85},{key="F",label="F",r=0.80,g=0.60,b=0.10}}
                        local rightRef=bsw; local gemRefs={}; local cmeta3=metaRef
                        local function RefGemBtns() local curGem=cmeta3.gemColor or "none"
                            for _,gbi in ipairs(gemRefs) do local act=(curGem==gbi.key)
                                BD(gbi.btn,act and gbi.r*0.6 or 0.09,act and gbi.g*0.6 or 0.09,act and gbi.b*0.6 or 0.09,1,act and gbi.r or 0.22,act and gbi.g or 0.22,act and gbi.b or 0.22,1)
                                gbi.lbl:SetTextColor(act and 1 or 0.45,act and 1 or 0.45,act and 1 or 0.45,1) end end
                        for _,gd in ipairs(gemDefs) do
                            local gb=CreateFrame("Button",nil,prow,"BackdropTemplate"); gb:SetSize(22,16)
                            gb:SetPoint("BOTTOMRIGHT",rightRef,"BOTTOMLEFT",-2,0)
                            local curAct=(cmeta3.gemColor or "none")==gd.key
                            BD(gb,curAct and gd.r*0.6 or 0.09,curAct and gd.g*0.6 or 0.09,curAct and gd.b*0.6 or 0.09,1,curAct and gd.r or 0.22,curAct and gd.g or 0.22,curAct and gd.b or 0.22,1)
                            local gl2=gb:CreateFontString(nil,"OVERLAY"); gl2:SetFont("Fonts\\ARIALN.TTF",9,""); gl2:SetTextColor(curAct and 1 or 0.45,curAct and 1 or 0.45,curAct and 1 or 0.45,1); gl2:SetText(gd.label); gl2:SetAllPoints(); gl2:SetJustifyH("CENTER")
                            table.insert(gemRefs,{btn=gb,lbl=gl2,key=gd.key,r=gd.r,g=gd.g,b=gd.b})
                            gb:SetScript("OnLeave",function() RefGemBtns() end)
                            local cgkey=gd.key; local cgik=idx
                            gb:SetScript("OnClick",function() local s=WinDB().Slots[cgik]; if not s then return end; s.meta=s.meta or {}; s.meta[pid]=s.meta[pid] or {}; s.meta[pid].gemColor=cgkey; RefGemBtns(); CT:RefreshLayout() end)
                            rightRef=gb
                        end
                        RefGemBtns()

                        -- Priority move buttons P1-P4 (to reassign this item to a different slot)
                        local priLblT=prow:CreateFontString(nil,"OVERLAY"); priLblT:SetFont("Fonts\\ARIALN.TTF",9,"")
                        priLblT:SetTextColor(0.45,0.45,0.45,1); priLblT:SetText("Move to:")
                        priLblT:SetPoint("BOTTOMLEFT",prow,"BOTTOMLEFT",50,5)
                        local prevPBtn=priLblT
                        for pj=1,4 do
                            local pb=CreateFrame("Button",nil,prow,"BackdropTemplate"); pb:SetSize(22,16)
                            pb:SetPoint("LEFT",prevPBtn,"RIGHT",3,0)
                            local isActive=(pj==pi)
                            BD(pb,isActive and 0.24 or 0.09,isActive and 0.49 or 0.09,isActive and 0.73 or 0.09,1,isActive and 0.24 or 0.22,isActive and 0.49 or 0.22,isActive and 0.73 or 0.22,1)
                            local pbl=pb:CreateFontString(nil,"OVERLAY"); pbl:SetFont("Fonts\\ARIALN.TTF",9,""); pbl:SetTextColor(1,1,1,1); pbl:SetText(tostring(pj)); pbl:SetAllPoints(); pbl:SetJustifyH("CENTER")
                            if not isActive then
                                local fromPi,toPj=pi,pj
                                local capGrpSlot=slot  -- identity ref to group slot
                                pb:SetScript("OnClick",function()
                                    -- Use identity ref - safe across index changes
                                    local fromKey="p"..fromPi; local toKey="p"..toPj
                                    local existing=capGrpSlot[toKey]
                                    capGrpSlot[toKey]=capGrpSlot[fromKey]
                                    capGrpSlot[fromKey]=existing
                                    CT:RefreshLayout(); rebuildUnifiedList()
                                end)
                                pb:SetScript("OnLeave",function() BD(pb,0.09,0.09,0.09,1,0.22,0.22,0.22) end)
                            end
                            prevPBtn=pb
                        end

                    else
                        local empty=prow:CreateFontString(nil,"OVERLAY"); empty:SetFont("Fonts\\ARIALN.TTF",GFS(),""); empty:SetTextColor(0.32,0.32,0.32,1)
                        empty:SetText("empty — go to Consumables tab to set P"..pi); empty:SetPoint("LEFT",prow,"LEFT",42,0); empty:SetPoint("RIGHT",prow,"RIGHT",-10,0); empty:SetJustifyV("MIDDLE")
                        local cpgi2,cppi2=idx,pi
                        prow:SetScript("OnClick",function()
                            ShowTab(2)
                            if CT._setConsGrpIdx then CT._setConsGrpIdx(cpgi2,slot.label~="" and slot.label or "Group "..cpgi2,cppi2,nil) end
                        end)
                        prow:SetScript("OnEnter",function() prow:SetBackdropColor(0.11,0.11,0.11,1) end)
                        prow:SetScript("OnLeave",function() prow:SetBackdropColor(0.08,0.08,0.08,1) end)
                    end
                    ry=ry+PROW_H+1
                end

                -- Custom Timer row for this group
                BuildCustomTimerRow(slot, capturedIdx, 30)

                ry=ry+4
            end
        end -- DrawIconRow

        -- Apply search filter — show flat list without sections
        if filter~="" then
            local filtered={}
            for idx,slot in ipairs(icons) do
                local lbl=(slot.label or ""):lower()
                local typ=(slot.type or ""):lower()
                local sid=slot.spellId and tostring(slot.spellId) or ""
                local spname=""
                if slot.spellId and C_Spell and C_Spell.GetSpellName then
                    spname=(C_Spell.GetSpellName(slot.spellId) or ""):lower()
                end
                if lbl:find(filter,1,true) or typ:find(filter,1,true)
                   or sid:find(filter,1,true) or spname:find(filter,1,true) then
                    table.insert(filtered,{idx=idx,slot=slot})
                end
            end
            if #filtered==0 then
                local hint=unifiedListHolder:CreateFontString(nil,"OVERLAY"); hint:SetFont("Fonts\\ARIALN.TTF",10,""); hint:SetTextColor(0.4,0.4,0.4,1)
                hint:SetText("No results for \""..filter.."\""); hint:SetPoint("TOPLEFT",unifiedListHolder,"TOPLEFT",8,-10); hint:SetWidth(EW); ry=30
            else
                for _,entry in ipairs(filtered) do DrawIconRow(entry,false) end
            end
            unifiedListHolder:SetHeight(math.max(ry,10))
            return
        end

        -- Draw each section with collapsible header + order arrows
        for si,secKey in ipairs(order) do
            local sec=SECTION_META[secKey]
            if sec then
            local items=sectionItems[secKey] or {}
            local sc=sec.color
            local collapsed=sectionCollapsed[secKey]
            local count=#items

            local secRow=CreateFrame("Button",nil,unifiedListHolder,"BackdropTemplate")
            secRow:SetPoint("TOPLEFT",unifiedListHolder,"TOPLEFT",0,-ry)
            secRow:SetPoint("TOPRIGHT",unifiedListHolder,"TOPRIGHT",0,-ry); secRow:SetHeight(SECT_H)
            BD(secRow,sc[1]*0.18,sc[2]*0.18,sc[3]*0.18,1,sc[1]*0.6,sc[2]*0.6,sc[3]*0.6)

            local stripe=secRow:CreateTexture(nil,"ARTWORK"); stripe:SetColorTexture(sc[1],sc[2],sc[3],1)
            stripe:SetWidth(3); stripe:SetHeight(SECT_H); stripe:SetPoint("LEFT",secRow,"LEFT",0,0)

            local arrow=secRow:CreateFontString(nil,"OVERLAY"); arrow:SetFont("Fonts\\ARIALN.TTF",GFS(),"OUTLINE")
            arrow:SetTextColor(sc[1],sc[2],sc[3],1)
            arrow:SetText(collapsed and "  +" or "  -"); arrow:SetPoint("LEFT",secRow,"LEFT",6,0)

            local sLbl=secRow:CreateFontString(nil,"OVERLAY"); sLbl:SetFont("Fonts\\ARIALN.TTF",GFS(),"OUTLINE")
            sLbl:SetTextColor(1,1,1,1)
            sLbl:SetText(sec.label.."  |cFF888888("..count..")|r")
            sLbl:SetPoint("LEFT",secRow,"LEFT",28,0)

            -- Section order arrows (^ v) — compound frame, clicks handled inside MakeOrderArrows
            local csk=secKey
            local _,_,secArrows=MakeOrderArrows(secRow, SECT_H,
                function() MoveSectionInOrder(csk,-1) end,
                function() MoveSectionInOrder(csk, 1) end)
            secRow:SetScript("OnEnter",function() secRow:SetBackdropColor(sc[1]*0.3,sc[2]*0.3,sc[3]*0.3,1) end)
            secRow:SetScript("OnLeave",function() BD(secRow,sc[1]*0.18,sc[2]*0.18,sc[3]*0.18,1,sc[1]*0.6,sc[2]*0.6,sc[3]*0.6) end)
            secRow:SetScript("OnClick",function() sectionCollapsed[csk]=not sectionCollapsed[csk]; rebuildUnifiedList() end)

            ry=ry+SECT_H+2

            if not collapsed then
                if count==0 then
                    local none=unifiedListHolder:CreateFontString(nil,"OVERLAY"); none:SetFont("Fonts\\ARIALN.TTF",10,""); none:SetTextColor(0.35,0.35,0.35,1)
                    none:SetText("  None added yet"); none:SetPoint("TOPLEFT",unifiedListHolder,"TOPLEFT",8,-ry); none:SetWidth(EW)
                    ry=ry+18
                else
                    for _,entry in ipairs(items) do
                        DrawIconRow(entry)
                    end
                end
                ry=ry+4
            end
            end -- if sec
        end

        unifiedListHolder:SetHeight(math.max(ry,10))
        -- Refresh preset button states so [Added]/[+ Add] is always current
        for _,entry in ipairs(presetBtns) do
            if entry.refresh then entry.refresh() end
        end
    end
    rebuildUnifiedList()
    CT._guiCallbacks=CT._guiCallbacks or {}; CT._guiCallbacks.rebuildAll=rebuildUnifiedList
end


-- ============================================================
-- PAGE 7: Buff Window
-- ============================================================
local function BuildPageBuffWindow(page)
    local y=10
    local function BWD() return ConsumableTrackerDB and ConsumableTrackerDB.BuffWindow or {} end
    local function Refresh() if CT.RefreshBuffWindow then CT.RefreshBuffWindow() end end

    y=WHeader(page,"Buff Window",y)
    y=WCheck(page,"Enable Buff Window",ML,y,
        function() return BWD().Enabled~=false end,
        function(v) BWD().Enabled=v; Refresh() end)
    y=WCheck(page,"Lock position  (unlock to see drag box)",ML,y,
        function() return BWD().Locked or false end,
        function(v) BWD().Locked=v; Refresh() end)

    y=WHeader(page,"Icon Size",y)
    y=WSlider(page,"Width",12,120,ML,y,
        function() return BWD().IconW or 44 end,
        function(v) BWD().IconW=v; Refresh() end, EW)
    y=WSlider(page,"Height",12,120,ML,y,
        function() return BWD().IconH or 44 end,
        function(v) BWD().IconH=v; Refresh() end, EW)
    y=WSlider(page,"Spacing between icons",0,30,ML,y,
        function() return BWD().Spacing or 4 end,
        function(v) BWD().Spacing=v; Refresh() end, EW)
    y=WDropdown(page,"Grow direction:",
        {{label="Right",value="RIGHT"},{label="Left",value="LEFT"},
         {label="Down",value="DOWN"},{label="Up",value="UP"}},
        ML,y,180,
        function() return BWD().GrowDir or "RIGHT" end,
        function(v) BWD().GrowDir=v; Refresh() end)

    y=WHeader(page,"Row Wrap",y)
    y=WTip(page,"Limit icons per row. Extra rows grow in the wrap direction.",ML,y)
    y=WSlider(page,"Max icons per row  (0 = no wrap)",0,20,ML,y,
        function() return BWD().MaxIconsPerRow or 0 end,
        function(v) BWD().MaxIconsPerRow=math.floor(v+0.5); Refresh() end, EW)
    y=WSlider(page,"Row spacing",0,60,ML,y,
        function() return BWD().RowSpacing or 4 end,
        function(v) BWD().RowSpacing=math.floor(v+0.5); Refresh() end, EW)
    y=WDropdown(page,"Wrap direction  (where new rows appear):",
        {{label="Down",value="DOWN"},{label="Up",value="UP"},
         {label="Right",value="RIGHT"},{label="Left",value="LEFT"}},
        ML,y,200,
        function() return BWD().WrapDirection or "DOWN" end,
        function(v) BWD().WrapDirection=v; Refresh() end)
    y=WDropdown(page,"Row grow direction  (icon order in wrapped rows):",
        {{label="Right",value="RIGHT"},{label="Left",value="LEFT"},
         {label="Down",value="DOWN"},{label="Up",value="UP"}},
        ML,y,200,
        function() return BWD().WrapGrowDirection or "RIGHT" end,
        function(v) BWD().WrapGrowDirection=v; Refresh() end)
    y=WDropdown(page,"Row start alignment:",
        {{label="Align with first icon of previous row",value="FIRST"},
         {label="Align with last icon of previous row", value="LAST"}},
        ML,y,360,
        function() return BWD().WrapAnchor or "FIRST" end,
        function(v) BWD().WrapAnchor=v; Refresh() end)
    y=WDropdown(page,"Frame strata:",
        {{label="Background",value="BACKGROUND"},{label="Low",value="LOW"},
         {label="Medium",value="MEDIUM"},{label="High",value="HIGH"},
         {label="Dialog",value="DIALOG"},{label="Fullscreen",value="FULLSCREEN"},
         {label="Tooltip",value="TOOLTIP"}},
        ML,y,180,
        function() return BWD().IconStrata or "HIGH" end,
        function(v) BWD().IconStrata=v; Refresh() end)
    y=WDropdown(page,"Icon order:",
        {{label="Normal  (order they appeared)",    value="normal"},
         {label="Shortest duration first",           value="duration_asc"},
         {label="Longest duration first",            value="duration_desc"}},
        ML,y,280,
        function() return BWD().SortMode or "normal" end,
        function(v) BWD().SortMode=v; Refresh() end)

    y=WHeader(page,"Name Label",y)
    y=WCheck(page,"Show potion name near icon",ML,y,
        function() return BWD().ShowLabel~=false end,
        function(v) BWD().ShowLabel=v; Refresh() end)
    y=WDropdown(page,"Label position:",
        {{label="Above icon",value="TOP"},{label="Below icon",value="BOTTOM"}},
        ML,y,180,
        function() return BWD().LabelPos or "TOP" end,
        function(v) BWD().LabelPos=v; Refresh() end)

    y=WHeader(page,"Cooldown Text",y)
    y=WCheck(page,"Show countdown text on icon",ML,y,
        function() return BWD().CDTextShow~=false end,
        function(v) BWD().CDTextShow=v; Refresh() end)
    y=WSlider(page,"Font size",6,40,ML,y,
        function() return BWD().CDTextSize or 14 end,
        function(v) BWD().CDTextSize=v; Refresh() end, EW)
    y=WDropdown(page,"Font style:",FONT_FLAGS,ML,y,220,
        function() return BWD().CDTextFlag or "OUTLINE" end,
        function(v) BWD().CDTextFlag=v; Refresh() end)
    y=WDropdown(page,"Text anchor:",ANCHORS,ML,y,180,
        function() return BWD().CDTextAnchor or "CENTER" end,
        function(v) BWD().CDTextAnchor=v; Refresh() end)
    y=WSlider(page,"X offset",-100,100,ML,y,
        function() return BWD().CDTextX or 0 end,
        function(v) BWD().CDTextX=v; Refresh() end, EW)
    y=WSlider(page,"Y offset",-100,100,ML,y,
        function() return BWD().CDTextY or 0 end,
        function(v) BWD().CDTextY=v; Refresh() end, EW)

    y=WHeader(page,"Cooldown Swipe",y)
    y=WCheck(page,"Show swipe overlay",ML,y,
        function() return BWD().ShowSwipe~=false end,
        function(v) BWD().ShowSwipe=v; Refresh() end)
    y=WSlider(page,"Swipe opacity  (0 = transparent / 100 = fully opaque)",0,100,ML,y,
        function() return BWD().SwipeAlpha or 65 end,
        function(v) BWD().SwipeAlpha=v; Refresh() end, EW)
    y=WCheck(page,"Inverse swipe direction",ML,y,
        function() return BWD().SwipeInverse or false end,
        function(v) BWD().SwipeInverse=v; Refresh() end)

    y=WHeader(page,"Anchor",y)
    y=WTip(page,"Anchor to screen or to another tracker window.",ML,y)

    -- Anchor to another window
    local function GetOtherWinItems()
        local items={{label="Screen (UIParent)",value="UIParent"}}
        local d=ConsumableTrackerDB; if d and d.Windows then
            for i,w in ipairs(d.Windows) do
                table.insert(items,{label=(w.Name or "Window "..i),value="FabsWin_"..i})
            end
        end
        return items
    end
    y=WDropdown(page,"Anchor to:",GetOtherWinItems(),ML,y,270,
        function() return BWD().AnchorToFrame or "UIParent" end,
        function(v) BWD().AnchorToFrame=v; Refresh() end)
    local apLbl=page:CreateFontString(nil,"OVERLAY"); apLbl:SetFont("Fonts\\ARIALN.TTF",GFS(),""); apLbl:SetTextColor(0.9,0.9,0.9,1)
    apLbl:SetText("Window point:"); apLbl:SetPoint("TOPLEFT",page,"TOPLEFT",ML,-y)
    local rpLbl=page:CreateFontString(nil,"OVERLAY"); rpLbl:SetFont("Fonts\\ARIALN.TTF",GFS(),""); rpLbl:SetTextColor(0.9,0.9,0.9,1)
    rpLbl:SetText("Screen point:"); rpLbl:SetPoint("TOPLEFT",page,"TOPLEFT",ML+260,-y); y=y+16
    WDropdown(page,"",ANCHORS,ML,y,240,
        function() return BWD().AnchorPoint or "TOP" end,
        function(v) BWD().AnchorPoint=v; Refresh() end)
    WDropdown(page,"",ANCHORS,ML+260,y,240,
        function() return BWD().AnchorToPoint or "TOP" end,
        function(v) BWD().AnchorToPoint=v; Refresh() end)
    y=y+28
    y=WSlider(page,"X offset",-1500,1500,ML,y,
        function() return BWD().X or 0 end,
        function(v) BWD().X=v; Refresh() end, EW)
    y=WSlider(page,"Y offset",-1000,1000,ML,y,
        function() return BWD().Y or -100 end,
        function(v) BWD().Y=v; Refresh() end, EW)

    local resetBtn=CreateFrame("Button",nil,page,"BackdropTemplate"); resetBtn:SetSize(EW,24); resetBtn:SetPoint("TOPLEFT",page,"TOPLEFT",ML,-y)
    BD(resetBtn,0.12,0.08,0.08,1,0.35,0.18,0.18)
    local rl=resetBtn:CreateFontString(nil,"OVERLAY"); rl:SetFont("Fonts\\ARIALN.TTF",GFS(),""); rl:SetTextColor(1,0.6,0.6,1)
    rl:SetText("Reset to top-center"); rl:SetAllPoints(); rl:SetJustifyH("CENTER")
    resetBtn:SetScript("OnEnter",function() resetBtn:SetBackdropColor(0.22,0.10,0.10,1); rl:SetTextColor(1,1,1,1) end)
    resetBtn:SetScript("OnLeave",function() BD(resetBtn,0.12,0.08,0.08,1,0.35,0.18,0.18); rl:SetTextColor(1,0.6,0.6,1) end)
    resetBtn:SetScript("OnClick",function()
        local bw=BWD(); bw.AnchorPoint="TOP"; bw.AnchorToPoint="TOP"
        bw.AnchorToFrame="UIParent"; bw.X=0; bw.Y=-100; Refresh()
    end); y=y+32

    -- Active tracked icons list
    y=WHeader(page,"Active Tracked Icons",y)
    y=WTip(page,"Icons currently configured with a custom timer. Right-click an icon in-game to dismiss it.",ML,y)

    local listHolder=CreateFrame("Frame",nil,page)
    listHolder:SetPoint("TOPLEFT",page,"TOPLEFT",ML,-y); listHolder:SetWidth(EW)

    local function RebuildTrackedList()
        for _,c in ipairs({listHolder:GetChildren()}) do c:Hide(); c:SetParent(nil) end
        local d=ConsumableTrackerDB; if not d or not d.Windows then listHolder:SetHeight(1); return end
        local rows=0
        for wi,win in ipairs(d.Windows) do
            for _,slot in ipairs(win.Slots or {}) do
                if slot.type=="group" and slot.customTimerDuration and slot.customTimerDuration>0 then
                    local row=CreateFrame("Frame",nil,listHolder,"BackdropTemplate")
                    row:SetSize(EW,22); row:SetPoint("TOPLEFT",listHolder,"TOPLEFT",0,-rows*24)
                    BD(row,0.08,0.10,0.08,1,0.18,0.30,0.18)
                    local lbl=row:CreateFontString(nil,"OVERLAY"); lbl:SetFont("Fonts\\ARIALN.TTF",GFS(),"")
                    lbl:SetTextColor(0.8,1,0.8,1); lbl:SetText(slot.label or "?")
                    lbl:SetPoint("LEFT",row,"LEFT",6,0)
                    local dur=row:CreateFontString(nil,"OVERLAY"); dur:SetFont("Fonts\\ARIALN.TTF",9,"")
                    dur:SetTextColor(0.5,0.8,0.5,1)
                    local txt=(slot.customTimerDuration or "?").."s"
                    if slot.customTimerText and slot.customTimerText~="" then txt=txt.."  label: \""..slot.customTimerText.."\"" end
                    txt=txt.."  |cFF444488[Win "..wi.."]|r"
                    dur:SetText(txt); dur:SetPoint("RIGHT",row,"RIGHT",-6,0)
                    rows=rows+1
                end
            end
        end
        if rows==0 then
            local hint=listHolder:CreateFontString(nil,"OVERLAY"); hint:SetFont("Fonts\\ARIALN.TTF",10,""); hint:SetTextColor(0.4,0.4,0.4,1)
            hint:SetText("No groups with custom timers set yet.\nExpand a consumable group in All Icons to add one.")
            hint:SetPoint("TOPLEFT",listHolder,"TOPLEFT",0,0); hint:SetWidth(EW); hint:SetJustifyH("CENTER")
            listHolder:SetHeight(36)
        else
            listHolder:SetHeight(rows*24)
        end
    end

    local RebuildItemList  -- forward declared, defined below

    -- Rebuild when page is shown (registered via CT hook set in BuildGUI)
    CT._rebuildBuffPageList = function()
        RebuildTrackedList()
        if RebuildItemList then RebuildItemList() end
        if CT._rebuildMidnightList then CT._rebuildMidnightList() end
    end
    RebuildTrackedList()
    y=y+listHolder:GetHeight()+8

    -- ── Tracked Gear Items ──────────────────────────────────────────────
    y=WHeader(page,"Tracked Item IDs",y)
    y=WTip(page,"Add specific item IDs to track in the buff window. When you use the item its buff icon appears with the timer you set.",ML,y)

    local function BWD2() local d=ConsumableTrackerDB; return d and d.BuffWindow or {} end

    -- Add form FIRST (above the list)
    local addRow=CreateFrame("Frame",nil,page,"BackdropTemplate"); addRow:SetSize(EW,28); addRow:SetPoint("TOPLEFT",page,"TOPLEFT",ML,-y)
    BD(addRow,0.06,0.06,0.10,1,0.20,0.20,0.35)

    local idLbl=addRow:CreateFontString(nil,"OVERLAY"); idLbl:SetFont("Fonts\\ARIALN.TTF",9,""); idLbl:SetTextColor(0.7,0.7,0.9,1); idLbl:SetText("Item ID:"); idLbl:SetPoint("LEFT",addRow,"LEFT",6,0)
    local idBox=CreateFrame("EditBox",nil,addRow,"InputBoxTemplate"); idBox:SetSize(60,18); idBox:SetPoint("LEFT",addRow,"LEFT",54,0)
    idBox:SetAutoFocus(false); idBox:SetFont("Fonts\\ARIALN.TTF",GFS(),""); idBox:SetTextColor(1,0.9,0.3,1); idBox:SetTextInsets(4,4,0,0); idBox:SetJustifyH("CENTER")
    idBox:SetScript("OnEscapePressed",function(sv) sv:ClearFocus() end)

    local durLbl2=addRow:CreateFontString(nil,"OVERLAY"); durLbl2:SetFont("Fonts\\ARIALN.TTF",9,""); durLbl2:SetTextColor(0.7,0.7,0.9,1); durLbl2:SetText("sec:"); durLbl2:SetPoint("LEFT",addRow,"LEFT",122,0)
    local durBox=CreateFrame("EditBox",nil,addRow,"InputBoxTemplate"); durBox:SetSize(40,18); durBox:SetPoint("LEFT",addRow,"LEFT",148,0)
    durBox:SetAutoFocus(false); durBox:SetFont("Fonts\\ARIALN.TTF",GFS(),""); durBox:SetTextColor(1,0.9,0.3,1); durBox:SetTextInsets(4,4,0,0); durBox:SetJustifyH("CENTER")
    durBox:SetScript("OnEscapePressed",function(sv) sv:ClearFocus() end)

    local lblLbl=addRow:CreateFontString(nil,"OVERLAY"); lblLbl:SetFont("Fonts\\ARIALN.TTF",9,""); lblLbl:SetTextColor(0.7,0.7,0.9,1); lblLbl:SetText("label:"); lblLbl:SetPoint("LEFT",addRow,"LEFT",196,0)
    local lblBox=CreateFrame("EditBox",nil,addRow,"InputBoxTemplate"); lblBox:SetSize(80,18); lblBox:SetPoint("LEFT",addRow,"LEFT",232,0)
    lblBox:SetAutoFocus(false); lblBox:SetFont("Fonts\\ARIALN.TTF",GFS(),""); lblBox:SetTextColor(0.9,0.9,0.9,1); lblBox:SetTextInsets(4,4,0,0)
    lblBox:SetScript("OnEscapePressed",function(sv) sv:ClearFocus() end)

    local addBtn=CreateFrame("Button",nil,addRow,"BackdropTemplate"); addBtn:SetSize(44,20); addBtn:SetPoint("RIGHT",addRow,"RIGHT",-4,0)
    BD(addBtn,0.08,0.16,0.08,1,0.20,0.55,0.20)
    local al=addBtn:CreateFontString(nil,"OVERLAY"); al:SetFont("Fonts\\ARIALN.TTF",10,""); al:SetTextColor(0.4,1,0.4,1); al:SetText("+ Add"); al:SetAllPoints(); al:SetJustifyH("CENTER")
    addBtn:SetScript("OnEnter",function() addBtn:SetBackdropColor(0.10,0.26,0.10,1); addBtn:SetBackdropBorderColor(0.35,1,0.35,1); al:SetTextColor(1,1,1,1) end)
    addBtn:SetScript("OnLeave",function() BD(addBtn,0.08,0.16,0.08,1,0.20,0.55,0.20); al:SetTextColor(0.4,1,0.4,1) end)
    addBtn:SetScript("OnClick",function()
        local id=tonumber(idBox:GetText())
        if not id or id<=0 then ShowStat("|cFFFF4444Invalid item ID|r"); return end
        local dur=tonumber(durBox:GetText())
        local lbl=lblBox:GetText():match("^%s*(.-)%s*$") or ""
        local bwd=BWD2()
        if not bwd.TrackedItems then bwd.TrackedItems={} end
        for _,e in ipairs(bwd.TrackedItems) do
            if e.itemId==id then ShowStat("|cFFFF9900Item already tracked|r"); return end
        end
        table.insert(bwd.TrackedItems,{itemId=id, duration=dur, label=lbl~="" and lbl or nil})
        idBox:SetText(""); durBox:SetText(""); lblBox:SetText("")
        FlashBtn(addBtn,al,"Added!","+ Add",0.08,0.16,0.08,0.20,0.55,0.20)
        RebuildItemList()
    end)
    y=y+34

    -- Item list BELOW the add form
    local itemListHolder=CreateFrame("Frame",nil,page)
    itemListHolder:SetPoint("TOPLEFT",page,"TOPLEFT",ML,-y); itemListHolder:SetWidth(EW)
    itemListHolder:SetHeight(1)
    local ROW_H_I = 26

    -- Quality colour lookup: maps item quality index to RGB
    local QUALITY_COLORS = {
        [0]={0.62,0.62,0.62}, -- Poor (grey)
        [1]={1,1,1},           -- Common (white)
        [2]={0.12,1,0},        -- Uncommon (green)
        [3]={0,0.44,0.87},     -- Rare (blue)
        [4]={0.64,0.21,0.93},  -- Epic (purple)
        [5]={1,0.5,0},         -- Legendary (orange)
        [6]={0.9,0.8,0.5},     -- Artifact
        [7]={0,0.8,1},         -- Heirloom
    }

    RebuildItemList = function()
        for _,c in ipairs({itemListHolder:GetChildren()}) do c:Hide(); c:SetParent(nil) end
        local items = BWD2().TrackedItems or {}
        if #items == 0 then
            local hint=itemListHolder:CreateFontString(nil,"OVERLAY"); hint:SetFont("Fonts\\ARIALN.TTF",10,""); hint:SetTextColor(0.4,0.4,0.4,1)
            hint:SetText("No items added yet."); hint:SetPoint("TOPLEFT",itemListHolder,"TOPLEFT",0,0); hint:SetWidth(EW); hint:SetJustifyH("CENTER")
            itemListHolder:SetHeight(22); return
        end
        local rh = ROW_H_I + 4
        for i, entry in ipairs(items) do
            local ci = i
            -- Request item data load (async) — fires ITEM_DATA_LOAD_RESULT when ready
            C_Item.RequestLoadItemDataByID(entry.itemId)

            local row=CreateFrame("Frame",nil,itemListHolder,"BackdropTemplate")
            row:SetSize(EW, rh-2); row:SetPoint("TOPLEFT",itemListHolder,"TOPLEFT",0,-(i-1)*rh)
            BD(row,0.08,0.08,0.12,1,0.20,0.20,0.35)

            -- Item icon with tooltip
            local icoF=CreateFrame("Frame",nil,row); icoF:SetSize(rh-4,rh-4); icoF:SetPoint("LEFT",row,"LEFT",3,0)
            icoF:EnableMouse(true)
            local icoTex=icoF:CreateTexture(nil,"ARTWORK"); icoTex:SetAllPoints(icoF); icoTex:SetTexCoord(0.08,0.92,0.08,0.92)

            -- Get item data - GetItemInfoInstant is unreliable in TWW, use GetItemInfo
            C_Item.RequestLoadItemDataByID(entry.itemId)
            local iname, _, iquality = GetItemInfo(entry.itemId)
            -- Texture via C_Item API (reliable)
            local itex = C_Item.GetItemIconByID and C_Item.GetItemIconByID(entry.itemId)

            if itex then icoTex:SetTexture(itex) else icoTex:SetColorTexture(0.3,0.3,0.3,1) end
            local capId = entry.itemId

            -- Find which slot this item is equipped in (for upgraded tooltip)
            local function FindEquippedSlot(id)
                for slot=1,19 do
                    if GetInventoryItemID("player",slot)==id then return slot end
                end
            end

            icoF:SetScript("OnEnter",function(self)
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                local slot = FindEquippedSlot(capId)
                if slot then
                    GameTooltip:SetInventoryItem("player", slot)
                else
                    GameTooltip:SetItemByID(capId)
                end
                GameTooltip:Show()
            end)
            icoF:SetScript("OnLeave",function() GameTooltip:Hide() end)

            -- Quality colour via WoW's own ITEM_QUALITY_COLORS table
            local nameLbl=row:CreateFontString(nil,"OVERLAY"); nameLbl:SetFont("Fonts\\ARIALN.TTF",GFS(),"")
            nameLbl:SetTextColor(0.9,0.9,0.9,1)
            nameLbl:SetText(iname or "Loading...")
            nameLbl:SetPoint("LEFT",icoF,"RIGHT",5,0); nameLbl:SetPoint("RIGHT",row,"RIGHT",-38,0); nameLbl:SetJustifyH("LEFT")
            row._nameLbl = nameLbl
            row._capId   = entry.itemId

            -- Duration
            local durLbl=row:CreateFontString(nil,"OVERLAY"); durLbl:SetFont("Fonts\\ARIALN.TTF",9,"")
            durLbl:SetTextColor(0.5,0.8,0.5,1); durLbl:SetText((entry.duration or "auto").."s")
            durLbl:SetPoint("RIGHT",row,"RIGHT",-70,0)

            -- Enable/disable toggle
            local togBtn=CreateFrame("Button",nil,row,"BackdropTemplate"); togBtn:SetSize(32,18); togBtn:SetPoint("RIGHT",row,"RIGHT",-34,0)
            local isOn=entry.enabled~=false
            BD(togBtn,isOn and 0.07 or 0.09,isOn and 0.14 or 0.09,isOn and 0.22 or 0.09,1,
                       isOn and 0.24 or 0.22,isOn and 0.49 or 0.22,isOn and 0.73 or 0.22,1)
            local togL=togBtn:CreateFontString(nil,"OVERLAY"); togL:SetFont("Fonts\\ARIALN.TTF",9,"")
            togL:SetText(isOn and "ON" or "OFF"); togL:SetAllPoints(); togL:SetJustifyH("CENTER")
            togL:SetTextColor(isOn and 0.5 or 0.5,isOn and 1.0 or 0.5,isOn and 1.0 or 0.5,1)
            local capCI2=ci
            togBtn:SetScript("OnClick",function()
                local bwd=BWD2(); if not bwd.TrackedItems then return end
                local e=bwd.TrackedItems[capCI2]; if not e then return end
                e.enabled=not(e.enabled~=false); local now2=e.enabled~=false
                BD(togBtn,now2 and 0.07 or 0.09,now2 and 0.14 or 0.09,now2 and 0.22 or 0.09,1,
                           now2 and 0.24 or 0.22,now2 and 0.49 or 0.22,now2 and 0.73 or 0.22,1)
                togL:SetText(now2 and "ON" or "OFF")
                togL:SetTextColor(now2 and 0.5 or 0.5,now2 and 1.0 or 0.5,now2 and 1.0 or 0.5,1)
            end)

            -- Remove button
            local remBtn=CreateFrame("Button",nil,row,"BackdropTemplate"); remBtn:SetSize(28,18); remBtn:SetPoint("RIGHT",row,"RIGHT",-3,0)
            BD(remBtn,0.25,0.06,0.06,1,0.55,0.12,0.12)
            local rl=remBtn:CreateFontString(nil,"OVERLAY"); rl:SetFont("Fonts\\ARIALN.TTF",9,"OUTLINE"); rl:SetTextColor(1,0.4,0.4,1); rl:SetText("X"); rl:SetAllPoints(); rl:SetJustifyH("CENTER")
            remBtn:SetScript("OnEnter",function() remBtn:SetBackdropColor(0.45,0.08,0.08,1); rl:SetTextColor(1,1,1,1) end)
            remBtn:SetScript("OnLeave",function() BD(remBtn,0.25,0.06,0.06,1,0.55,0.12,0.12); rl:SetTextColor(1,0.4,0.4,1) end)
            remBtn:SetScript("OnClick",function()
                local bwd=BWD2(); if bwd.TrackedItems then table.remove(bwd.TrackedItems,ci) end
                RebuildItemList()
            end)
        end
        itemListHolder:SetHeight(#items * rh)

        -- When item data arrives, refresh any rows still showing "Loading..."
        C_Timer.After(0.5, function()
            if not itemListHolder or not itemListHolder:IsShown() then return end
            for _,row in ipairs({itemListHolder:GetChildren()}) do
                if row._nameLbl and row._capId then
                    local n = GetItemInfo(row._capId)
                    if n then row._nameLbl:SetText(n) end
                end
            end
        end)
    end
    RebuildItemList()
    y=y+itemListHolder:GetHeight()+8

    y=WTip(page,"Tip: /ct buffwin to reset position if off-screen.",ML,y)

    -- ============================================================
    -- Midnight Season 1 Auto-Track
    -- ============================================================
    y=WHeader(page,"Midnight S1 Auto-Track",y)
    y=WTip(page,"Auto-shows a buff icon when you use an equipped Midnight S1 on-use item. Only items with a buff duration fire an icon.",ML,y)
    y=WCheck(page,"Enable Midnight S1 auto-tracking",ML,y,
        function() return BWD().MidnightAutoTrackEnabled or false end,
        function(v) BWD().MidnightAutoTrackEnabled=v; Refresh() end)

    local midHolder=CreateFrame("Frame",nil,page)
    midHolder:SetPoint("TOPLEFT",page,"TOPLEFT",ML,-y); midHolder:SetWidth(EW)

    local function RebuildMidnightList()
        for _,c in ipairs({midHolder:GetChildren()}) do c:Hide(); c:SetParent(nil) end
        for _,r in ipairs({midHolder:GetRegions()}) do r:Hide() end
        local MID=CT.MIDNIGHT_S1_ONUSE
        if not MID then midHolder:SetHeight(22); return end
        local bwd=BWD()
        if not bwd.MidnightAutoTrack then bwd.MidnightAutoTrack={} end
        local trackEnabled=bwd.MidnightAutoTrack
        local ry=0; local MRH=28; local found=false
        for slot=1,17 do
            local itemId=GetInventoryItemID("player",slot)
            if itemId and itemId>0 then
                local info=MID[itemId]
                if info then
                    found=true
                    local capId=itemId
                    local isEnabled=trackEnabled[itemId]~=false
                    local row=CreateFrame("Frame",nil,midHolder,"BackdropTemplate")
                    row:SetSize(EW,MRH-2); row:SetPoint("TOPLEFT",midHolder,"TOPLEFT",0,-ry)
                    BD(row,0.08,0.08,0.12,1,0.20,0.20,0.35)

                    local icoF=CreateFrame("Frame",nil,row); icoF:SetSize(MRH-4,MRH-4); icoF:SetPoint("LEFT",row,"LEFT",3,0)
                    local icoTex=icoF:CreateTexture(nil,"ARTWORK"); icoTex:SetAllPoints(icoF); icoTex:SetTexCoord(0.08,0.92,0.08,0.92)
                    C_Item.RequestLoadItemDataByID(itemId)
                    local itex=C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemId)
                    if itex then icoTex:SetTexture(itex) else icoTex:SetColorTexture(0.3,0.3,0.3,1) end
                    icoF:EnableMouse(true)
                    icoF:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetItemByID(capId); GameTooltip:Show() end)
                    icoF:SetScript("OnLeave",function() GameTooltip:Hide() end)

                    local slotTag=(slot==13 and " |cFF888888[Trinket 1]|r" or slot==14 and " |cFF888888[Trinket 2]|r" or "")
                    local durStr=info.duration>0 and ("  |cFF558855"..info.duration.."s buff|r") or "  |cFF555555instant|r"
                    local lbl=row:CreateFontString(nil,"OVERLAY"); lbl:SetFont("Fonts\\ARIALN.TTF",GFS(),"")
                    lbl:SetTextColor(isEnabled and 0.9 or 0.4,isEnabled and 0.9 or 0.4,isEnabled and 0.9 or 0.4,1)
                    lbl:SetText(info.label..slotTag..durStr)
                    lbl:SetPoint("LEFT",icoF,"RIGHT",5,0); lbl:SetPoint("RIGHT",row,"RIGHT",-68,0); lbl:SetJustifyH("LEFT")

                    local togBtn=CreateFrame("Button",nil,row,"BackdropTemplate"); togBtn:SetSize(58,20); togBtn:SetPoint("RIGHT",row,"RIGHT",-4,0)
                    BD(togBtn,isEnabled and 0.07 or 0.09,isEnabled and 0.14 or 0.09,isEnabled and 0.22 or 0.09,1,
                               isEnabled and 0.24 or 0.22,isEnabled and 0.49 or 0.22,isEnabled and 0.73 or 0.22,1)
                    local togL=togBtn:CreateFontString(nil,"OVERLAY"); togL:SetFont("Fonts\\ARIALN.TTF",9,"")
                    togL:SetText(isEnabled and "Tracking" or "Disabled"); togL:SetAllPoints(); togL:SetJustifyH("CENTER")
                    togL:SetTextColor(isEnabled and 0.5 or 0.5,isEnabled and 1.0 or 0.5,isEnabled and 1.0 or 0.5,1)
                    local capIdT=itemId
                    togBtn:SetScript("OnClick",function()
                        local bwd2=BWD(); if not bwd2.MidnightAutoTrack then bwd2.MidnightAutoTrack={} end
                        local cur=bwd2.MidnightAutoTrack[capIdT]~=false
                        bwd2.MidnightAutoTrack[capIdT]=not cur
                        local now2=bwd2.MidnightAutoTrack[capIdT]
                        BD(togBtn,now2 and 0.07 or 0.09,now2 and 0.14 or 0.09,now2 and 0.22 or 0.09,1,
                                   now2 and 0.24 or 0.22,now2 and 0.49 or 0.22,now2 and 0.73 or 0.22,1)
                        togL:SetText(now2 and "Tracking" or "Disabled")
                        togL:SetTextColor(now2 and 0.5 or 0.5,now2 and 1.0 or 0.5,now2 and 1.0 or 0.5,1)
                        lbl:SetTextColor(now2 and 0.9 or 0.4,now2 and 0.9 or 0.4,now2 and 0.9 or 0.4,1)
                    end)
                    ry=ry+MRH
                end
            end
        end
        if not found then
            local hint=midHolder:CreateFontString(nil,"OVERLAY"); hint:SetFont("Fonts\\ARIALN.TTF",10,""); hint:SetTextColor(0.4,0.4,0.4,1)
            hint:SetText("No Midnight S1 on-use items currently equipped."); hint:SetPoint("TOPLEFT",midHolder,"TOPLEFT",0,0); hint:SetWidth(EW); hint:SetJustifyH("CENTER")
            midHolder:SetHeight(22)
        else
            midHolder:SetHeight(ry)
        end
    end
    CT._rebuildMidnightList=RebuildMidnightList
    RebuildMidnightList()
    y=y+midHolder:GetHeight()+8
end

-- ============================================================
-- PAGE 5: Minimap
-- ============================================================
local function BuildPageMinimap(page)
    local db=ConsumableTrackerDB; local y=10
    y=WHeader(page,"Minimap Button",y)
    y=WCheck(page,"Show minimap button",ML,y,function() return not db.MinimapHidden end,function(v) db.MinimapHidden=not v; if CT.MinimapButton then if v then CT.MinimapButton:Show() else CT.MinimapButton:Hide() end end end)
    y=WTip(page,"Left-click opens settings. Right-click hides it. Drag to reposition around the minimap edge.",ML,y)
    y=WTip(page,"If LibDataBroker + LibDBIcon are loaded (TitanPanel, ChocolateBar, etc.) the button registers with them automatically.",ML,y)
    y=WButton(page,"Reset Minimap Position",ML,y,180,22,function()
        db.MinimapAngle=225; if CT.MinimapButton then local rad=math.rad(225); CT.MinimapButton:ClearAllPoints(); CT.MinimapButton:SetPoint("CENTER",Minimap,"CENTER",math.cos(rad)*80,math.sin(rad)*80) end
    end)
end

-- ============================================================
-- PAGE 8: Information
-- ============================================================
local function BuildPageInfo(page)
    local y=18
    local fnt="Fonts\\ARIALN.TTF"
    local NOTE_W = PAGE_W - 60
    local LINE_W = PAGE_W - 40

    -- Estimate number of wrapped lines given text width and font size
    local function estLines(text, width, size)
        local charsPerLine = math.floor(width / (size * 0.55))
        local lines = 1
        local col = 0
        for word in text:gmatch("%S+") do
            if col + #word + 1 > charsPerLine then lines = lines + 1; col = #word
            else col = col + #word + 1 end
        end
        return lines
    end

    local function InfoHeader(text)
        local sep=page:CreateTexture(nil,"ARTWORK"); sep:SetHeight(1)
        sep:SetColorTexture(0.20,0.20,0.20,1)
        sep:SetPoint("TOPLEFT",page,"TOPLEFT",0,-y); sep:SetWidth(PAGE_W); y=y+10
        local fs=page:CreateFontString(nil,"OVERLAY")
        fs:SetFont(fnt,15,""); fs:SetTextColor(0.35,0.72,1.0,1)
        fs:SetText(text); fs:SetPoint("TOP",page,"TOP",0,-y)
        fs:SetWidth(PAGE_W); fs:SetJustifyH("CENTER")
        y=y+28
    end

    local function InfoLine(text)
        local fs=page:CreateFontString(nil,"OVERLAY")
        fs:SetFont(fnt,13,""); fs:SetTextColor(0.90,0.90,0.90,1)
        fs:SetText(text); fs:SetPoint("TOP",page,"TOP",0,-y)
        fs:SetWidth(LINE_W); fs:SetJustifyH("CENTER")
        local n = estLines(text, LINE_W, 13)
        y=y+n*18+12
    end

    local function InfoNote(text)
        local fs=page:CreateFontString(nil,"OVERLAY")
        fs:SetFont(fnt,12,""); fs:SetTextColor(0.62,0.62,0.62,1)
        fs:SetText(text); fs:SetPoint("TOP",page,"TOP",0,-y)
        fs:SetWidth(NOTE_W); fs:SetJustifyH("CENTER")
        local n = estLines(text, NOTE_W, 12)
        y=y+n*17+10
    end

    local function Gap() y=y+14 end

    InfoHeader("Welcome to Fabs Resource Tracker")
    InfoLine("This addon tracks cooldowns and resources as movable icon windows on screen.")
    InfoLine("You can have multiple windows, each with their own icons, size, position and appearance.")
    InfoLine("To get started: go to All Icons and add your consumables, racials or defensives,\nthen use Position to place the window on screen.")
    Gap()

    InfoHeader("Icon & Border")
    InfoLine("Controls the look of icons in the selected window.")
    InfoNote("Zoom — 0 shows the full raw icon. Higher values crop toward the center, removing the default texture border.")
    InfoNote("Border styles — No border, Solid colour (sharp pixel lines), or WoW built-in edges like Tooltip, Dialog or Glow.")
    InfoNote("Hide GCD — suppresses the short 1.5s global cooldown flash after each cast.")
    InfoNote("Desaturate on Cooldown — greys out the icon while it is on cooldown.")
    Gap()

    InfoHeader("Position")
    InfoLine("Controls where the selected window sits on screen.")
    InfoNote("Unlock the window first to drag it freely, then lock it once placed.")
    InfoNote("Anchor to UIParent (screen) or to another tracker window so they move together.")
    InfoNote("Use the X and Y offset sliders to fine-tune position after choosing an anchor point.")
    Gap()

    InfoHeader("Text & Font")
    InfoLine("Controls text displayed on the icons.")
    InfoNote("Cooldown countdown — the number shown while an ability is on cooldown. Configurable font, size and position.")
    InfoNote("Stack count — shows how many of a consumable you have in your bags.")
    InfoNote("Quality Gem — a coloured dot or star showing Gold, Silver or Fleeting potion quality.")
    Gap()

    InfoHeader("All Icons")
    InfoLine("This is where you add everything you want to track.")
    InfoNote("Gear On-Use — tracks equipped item slots (Trinket 1, Trinket 2, etc.). Updates automatically when you swap gear.")
    InfoNote("Consumables — potion groups with up to 4 fallback items. The addon shows the best one you have in your bags.")
    InfoNote("Defensives / Racials — add spells by ID. Racials and class defensives have presets listed for easy adding.")
    InfoNote("Class Abilities — add any spell by ID to track its cooldown.")
    InfoNote("Buff Timer — every icon has a green timer row. Enter seconds to show a buff icon in the Buff Window when you use it.")
    Gap()

    InfoHeader("Windows")
    InfoLine("Create multiple independent icon windows.")
    InfoNote("Each window has its own icons, appearance and position settings.")
    InfoNote("The strip at the top of Appearance pages switches which window you are editing.")
    InfoNote("You can anchor one window to another so they stay together when moved.")
    Gap()

    InfoHeader("Buff Window")
    InfoLine("A floating window showing buff icons when custom timers fire.")
    InfoNote("Unlock it to see the blue placeholder box. Drag it where you want, then lock it.")
    InfoNote("Grow direction — choose whether new icons stack right, left, up or down.")
    InfoNote("Tracked Item IDs — add trinket or on-use item IDs with a custom duration. A buff icon appears whenever you use that item, regardless of which slot it is in. Hover the item icon for its tooltip.")
    InfoNote("Right-click any active buff icon in-game to dismiss it early.")
    Gap()

    InfoHeader("Slash Commands")
    InfoNote("/ct  —  open or close the settings window")
    InfoNote("/ct minimap  —  restore the minimap button if hidden")
    InfoNote("/ct buffwin  —  reset the Buff Window to the top-center of screen")
    InfoNote("/ct debug  —  print cooldown debug info for all tracked spells")
end

-- ============================================================
-- Simple drop menu helper
-- ============================================================
local _openDropMenu = nil  -- singleton: only one drop menu open at a time

function CT._ShowDropMenu(anchor, items)
    -- Toggle: if this anchor already has an open menu, close it
    if _openDropMenu then
        local prev = _openDropMenu
        _openDropMenu = nil  -- clear BEFORE Hide so OnHide doesn't double-clear
        local wasAnchor = prev._anchor == anchor
        prev:Hide()
        if wasAnchor then return end  -- toggled closed
    end

    local mf = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    mf._anchor = anchor
    mf:SetFrameStrata("TOOLTIP"); mf:SetFrameLevel(200)
    mf:SetWidth(200); BD(mf,0.06,0.06,0.06,1,0.35,0.35,0.35)
    local my = 4
    for _,item in ipairs(items) do
        local btn = CreateFrame("Button", nil, mf, "BackdropTemplate")
        btn:SetHeight(26); btn:SetPoint("TOPLEFT",mf,"TOPLEFT",2,-my); btn:SetPoint("TOPRIGHT",mf,"TOPRIGHT",-2,-my)
        BD(btn,0.08,0.08,0.08,0,0,0,0,0)
        local lbl = btn:CreateFontString(nil,"OVERLAY"); lbl:SetFont("Fonts\\ARIALN.TTF",11,""); lbl:SetTextColor(0.9,0.9,0.9,1); lbl:SetPoint("LEFT",btn,"LEFT",8,0); lbl:SetText(item.label)
        local capFn = item.onClick
        btn:SetScript("OnClick",function() mf:Hide(); _openDropMenu=nil; if capFn then capFn() end end)
        btn:SetScript("OnEnter",function() BD(btn,0.18,0.37,0.58,0.9,0.24,0.49,0.73,1); lbl:SetTextColor(1,1,1,1) end)
        btn:SetScript("OnLeave",function() BD(btn,0.08,0.08,0.08,0,0,0,0,0); lbl:SetTextColor(0.9,0.9,0.9,1) end)
        my = my + 28
    end
    mf:SetHeight(my + 4)
    mf:ClearAllPoints()
    local _,ay = anchor:GetCenter()
    if ay and ay < GetScreenHeight()/2 then
        mf:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2)
    else
        mf:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    end
    mf:SetScript("OnHide", function() _openDropMenu = nil end)
    _openDropMenu = mf
    mf:Show()
end

-- ============================================================
-- Page 6: Windows
-- ============================================================
local function BuildPageWindows(page, onWindowsChanged)
    local y = 10
    y = WHeader(page, "Windows", y)
    y = WTip(page, "Each window has its own icons, position and appearance settings. The first window is always the default — icons return here if a window is deleted.", ML, y)
    y = y + 4

    local listF = CreateFrame("Frame", nil, page)
    listF:SetPoint("TOPLEFT", page, "TOPLEFT", ML, -y)
    listF:SetPoint("TOPRIGHT", page, "TOPRIGHT", -6, -y)
    listF:SetHeight(10) -- grows dynamically
    y = y + 10 -- spacing before list

    local function RebuildWindowList()
        -- Clear old rows
        for _,c in ipairs({listF:GetChildren()}) do c:Hide() end

        local d = ConsumableTrackerDB
        if not d or not d.Windows then return end
        local ry = 0

        for wi, win in ipairs(d.Windows) do
            local capWi = wi; local capWin = win
            local row = CreateFrame("Frame", nil, listF, "BackdropTemplate")
            row:SetPoint("TOPLEFT", listF, "TOPLEFT", 0, -ry)
            row:SetPoint("TOPRIGHT", listF, "TOPRIGHT", 0, -ry)
            row:SetHeight(36)
            BD(row, 0.08, 0.08, 0.08, 1, wi == _selectedWinIdx and 0.24 or 0.18, wi == _selectedWinIdx and 0.49 or 0.18, wi == _selectedWinIdx and 0.73 or 0.18, 1)

            -- Window number badge
            local badge = row:CreateFontString(nil,"OVERLAY"); badge:SetFont("Fonts\\ARIALN.TTF",10,"OUTLINE")
            badge:SetTextColor(0.6,0.6,0.6,1); badge:SetText(wi); badge:SetPoint("LEFT",row,"LEFT",8,0)

            -- Window name (editable on double-click)
            local nameLbl = row:CreateFontString(nil,"OVERLAY"); nameLbl:SetFont("Fonts\\ARIALN.TTF",12,"")
            nameLbl:SetTextColor(wi==1 and 1 or 0.9, wi==1 and 0.82 or 0.9, wi==1 and 0 or 0.9, 1)
            nameLbl:SetText((win.Name or "Window "..wi)..(wi==1 and " (default)" or ""))
            nameLbl:SetPoint("LEFT",row,"LEFT",28,0)

            -- Slot count — anchored relative to lockBtn after it's created

            -- Lock indicator
            -- Lock toggle button (shown for all windows)
            local lockBtn = CreateFrame("Button",nil,row,"BackdropTemplate"); lockBtn:SetSize(50,20)
            lockBtn:SetPoint("RIGHT",row,"RIGHT",-4,0)
            local isLocked = win.Locked
            BD(lockBtn, isLocked and 0.20 or 0.08, isLocked and 0.10 or 0.08, 0.08, 1,
                        isLocked and 0.55 or 0.25, isLocked and 0.25 or 0.25, 0.10, 1)
            local lockLbl = lockBtn:CreateFontString(nil,"OVERLAY"); lockLbl:SetFont("Fonts\\ARIALN.TTF",10,"OUTLINE")
            lockLbl:SetTextColor(isLocked and 1 or 0.5, isLocked and 0.7 or 0.5, 0.1, 1)
            lockLbl:SetText(isLocked and "Locked" or "Unlock"); lockLbl:SetPoint("CENTER")
            lockBtn:SetScript("OnClick",function()
                capWin.Locked = not capWin.Locked
                CT:Refresh(); RebuildWindowList()
            end)

            -- Slot count — left of lock button
            local slots = win.Slots or {}
            local cntLbl = row:CreateFontString(nil,"OVERLAY"); cntLbl:SetFont("Fonts\\ARIALN.TTF",10,"")
            cntLbl:SetTextColor(0.5,0.5,0.5,1); cntLbl:SetText(#slots.." icon"..(#slots==1 and "" or "s"))
            cntLbl:SetPoint("RIGHT",lockBtn,"LEFT",-8,0)

            -- Select button (whole row)
            local selBtn = CreateFrame("Button",nil,row)
            selBtn:SetPoint("TOPLEFT",row,"TOPLEFT",0,0); selBtn:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",-84,0)
            selBtn:SetScript("OnClick",function()
                _selectedWinIdx = capWi
                if CT._refreshAllIcons_winDrop then CT._refreshAllIcons_winDrop() end
                -- Rebuild entire GUI so pages 1-3 get fresh db references for new window
                if CT._RebuildGUIToPage then CT._RebuildGUIToPage(6)
                elseif CT._RebuildGUI then CT._RebuildGUI() end
            end)
            selBtn:SetScript("OnEnter",function() if capWi~=_selectedWinIdx then row:SetBackdropColor(0.12,0.12,0.12,1) end end)
            selBtn:SetScript("OnLeave",function() if capWi~=_selectedWinIdx then BD(row,0.08,0.08,0.08,1,0.18,0.18,0.18,1) end end)

            -- Rename button
            local renBtn = CreateFrame("Button",nil,row,"BackdropTemplate"); renBtn:SetSize(56,22)
            renBtn:SetPoint("RIGHT",lockBtn,"LEFT",-4,0); BD(renBtn,0.12,0.12,0.12,1,0.35,0.35,0.35)
            local renLbl = renBtn:CreateFontString(nil,"OVERLAY"); renLbl:SetFont("Fonts\\ARIALN.TTF",10,""); renLbl:SetTextColor(0.8,0.8,0.8,1); renLbl:SetText("Rename"); renLbl:SetPoint("CENTER")
            renBtn:SetScript("OnClick",function()
                local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
                popup:SetSize(280, 60); popup:SetFrameStrata("TOOLTIP"); popup:SetFrameLevel(300)
                popup:SetPoint("CENTER", UIParent, "CENTER")
                BD(popup, 0.06, 0.06, 0.06, 1, 0.35, 0.35, 0.35)
                popup:EnableMouse(true); popup:SetMovable(true)
                popup:SetScript("OnMouseDown", function(self) self:StartMoving() end)
                popup:SetScript("OnMouseUp",   function(self) self:StopMovingOrSizing() end)
                local ptitle = popup:CreateFontString(nil,"OVERLAY"); ptitle:SetFont("Fonts\\ARIALN.TTF",11,""); ptitle:SetTextColor(0.9,0.9,0.9,1); ptitle:SetText("Rename window:"); ptitle:SetPoint("TOPLEFT",popup,"TOPLEFT",10,-8)
                local box = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
                box:SetSize(180, 22); box:SetPoint("TOPLEFT",popup,"TOPLEFT",10,-28)
                box:SetAutoFocus(true); box:SetText(capWin.Name or ""); box:HighlightText()
                box:SetMaxLetters(40)
                local okBtn = CreateFrame("Button", nil, popup, "BackdropTemplate")
                okBtn:SetSize(50, 22); okBtn:SetPoint("LEFT", box, "RIGHT", 6, 0)
                BD(okBtn, 0.10, 0.20, 0.10, 1, 0.20, 0.45, 0.20)
                local okL = okBtn:CreateFontString(nil,"OVERLAY"); okL:SetFont("Fonts\\ARIALN.TTF",10,""); okL:SetTextColor(0.4,1,0.4,1); okL:SetText("OK"); okL:SetPoint("CENTER")
                local function DoRename()
                    local nm = box:GetText()
                    if nm and nm~="" then capWin.Name=nm end
                    popup:Hide()
                    RebuildWindowList(); onWindowsChanged()
                end
                okBtn:SetScript("OnClick", DoRename)
                box:SetScript("OnEnterPressed", DoRename)
                box:SetScript("OnEscapePressed", function() popup:Hide() end)
                popup:Show()
                box:SetFocus()
            end)

            -- Delete button (not for window 1)
            if wi > 1 then
                local delBtn = CreateFrame("Button",nil,row,"BackdropTemplate"); delBtn:SetSize(28,22)
                delBtn:SetPoint("RIGHT",row,"RIGHT",-4,0); BD(delBtn,0.25,0.06,0.06,1,0.55,0.12,0.12)
                local delLbl = delBtn:CreateFontString(nil,"OVERLAY"); delLbl:SetFont("Fonts\\FRIZQT__.TTF",13,"OUTLINE"); delLbl:SetTextColor(1,0.4,0.4,1); delLbl:SetText("X"); delLbl:SetPoint("CENTER")
                delBtn:SetScript("OnEnter",function() delBtn:SetBackdropColor(0.45,0.08,0.08,1); delBtn:SetBackdropBorderColor(1,0.3,0.3,1); delLbl:SetTextColor(1,1,1,1) end)
                delBtn:SetScript("OnLeave",function() BD(delBtn,0.25,0.06,0.06,1,0.55,0.12,0.12); delLbl:SetTextColor(1,0.4,0.4,1) end)
                delBtn:SetScript("OnClick",function()
                    -- Move all slots back to window 1
                    local w1 = d.Windows[1]; w1.Slots = w1.Slots or {}
                    for _,slot in ipairs(capWin.Slots or {}) do
                        table.insert(w1.Slots, slot)
                    end
                    table.remove(d.Windows, capWi)
                    if _selectedWinIdx >= capWi then
                        _selectedWinIdx = math.max(1, _selectedWinIdx - 1)
                    end
                    CT:RefreshLayout(); RebuildWindowList(); onWindowsChanged()
                end)
                -- Move lock button left of delete
                lockBtn:ClearAllPoints(); lockBtn:SetPoint("RIGHT",delBtn,"LEFT",-4,0)
            end

            row:Show(); ry = ry + 40
        end

        listF:SetHeight(math.max(10, ry))
    end

    listF.Rebuild = RebuildWindowList
    RebuildWindowList()

    -- Position list below header
    listF:SetPoint("TOPLEFT", page, "TOPLEFT", ML, -y)
    y = y + 10

    -- New Window button
    local newWinRow = CreateFrame("Frame", nil, page, "BackdropTemplate")
    newWinRow:SetPoint("TOPLEFT", listF, "BOTTOMLEFT", 0, -10)
    newWinRow:SetPoint("TOPRIGHT", listF, "BOTTOMRIGHT", 0, -10)
    newWinRow:SetHeight(32)
    BD(newWinRow, 0.05, 0.12, 0.05, 1, 0.15, 0.35, 0.15)
    local newBtn = CreateFrame("Button", nil, newWinRow)
    newBtn:SetAllPoints()
    local newLbl = newWinRow:CreateFontString(nil,"OVERLAY"); newLbl:SetFont("Fonts\\ARIALN.TTF",12,""); newLbl:SetTextColor(0.4,1.0,0.4,1); newLbl:SetText("+ New Window"); newLbl:SetPoint("CENTER")
    newBtn:SetScript("OnClick",function()
        local d = ConsumableTrackerDB; if not d or not d.Windows then return end
        local newWin = {}
        -- Copy current selected window's appearance settings and current anchor,
        -- so a new window starts where the current one is instead of centering.
        local srcWin = d.Windows[_selectedWinIdx] or d.Windows[1] or {}
        for k,v in pairs(srcWin) do
            if k ~= "Slots" and k ~= "Name" then
                if type(v) == "table" then
                    local copy = {}
                    for ck, cv in pairs(v) do copy[ck] = cv end
                    newWin[k] = copy
                else
                    newWin[k] = v
                end
            end
        end
        newWin.Name = "Window "..(#d.Windows+1)
        newWin.Slots = {}
        newWin.AnchorPoint = newWin.AnchorPoint or srcWin.AnchorPoint or "CENTER"
        newWin.AnchorToFrame = newWin.AnchorToFrame or srcWin.AnchorToFrame or "UIParent"
        newWin.AnchorToPoint = newWin.AnchorToPoint or srcWin.AnchorToPoint or "CENTER"
        newWin.X = (newWin.X ~= nil) and newWin.X or (srcWin.X or 0)
        newWin.Y = (newWin.Y ~= nil) and newWin.Y or (srcWin.Y or 0)
        newWin.Locked = false
        table.insert(d.Windows, newWin)
        -- Don't switch selected window — user stays on current window
        -- They can click the new window row to switch to it
        CT:RefreshLayout(); RebuildWindowList(); onWindowsChanged()
    end)
    newBtn:SetScript("OnEnter",function() newWinRow:SetBackdropColor(0.08,0.20,0.08,1) end)
    newBtn:SetScript("OnLeave",function() BD(newWinRow,0.05,0.12,0.05,1,0.15,0.35,0.15) end)
end

-- ============================================================
-- Build main window
-- ============================================================
-- ============================================================
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


local function BuildGUI()
    _guiBuilding = true
    local frame=CreateFrame("Frame","CTSettingsFrame",UIParent,"BackdropTemplate")
    frame:SetSize(W,H); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG"); frame:SetFrameLevel(100)
    frame:SetMovable(true); frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetScript("OnHide", function()
        if _openDrop then _openDrop:Hide(); _openDrop=nil end
        if _openDropMenu then _openDropMenu:Hide(); _openDropMenu=nil end
    end)
    BD(frame,0.05,0.05,0.05,0.94,0,0,0)
    local tb=CreateFrame("Frame",nil,frame,"BackdropTemplate")
    tb:SetPoint("TOPLEFT",frame,"TOPLEFT",1,-1); tb:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-1,-1); tb:SetHeight(TITLE_H)
    BD(tb,0.02,0.02,0.02,1,0,0,0); tb:EnableMouse(true)
    tb:SetScript("OnMouseDown",function() frame:StartMoving() end); tb:SetScript("OnMouseUp",function() frame:StopMovingOrSizing() end)
    local tfs=tb:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); tfs:SetText("|cFF"..ClassHex().."Fabs Resource Tracker|r Settings"); tfs:SetPoint("LEFT",tb,"LEFT",14,0)
    local xBtn=CreateFrame("Button",nil,tb,"UIPanelCloseButton"); xBtn:SetPoint("RIGHT",tb,"RIGHT",-2,0); xBtn:SetSize(28,28); xBtn:SetScript("OnClick",function() frame:Hide() end)

    -- Search box in title bar
    local searchBox=CreateFrame("EditBox",nil,tb,"InputBoxTemplate")
    searchBox:SetSize(160,20); searchBox:SetPoint("RIGHT",xBtn,"LEFT",-6,0)
    searchBox:SetAutoFocus(false); searchBox:SetFont("Fonts\\ARIALN.TTF",11,""); searchBox:SetTextColor(0.9,0.9,0.9,1); searchBox:SetTextInsets(6,6,0,0)
    local searchHint=searchBox:CreateFontString(nil,"OVERLAY"); searchHint:SetFont("Fonts\\ARIALN.TTF",10,""); searchHint:SetTextColor(0.35,0.35,0.35,1); searchHint:SetText("Search icons..."); searchHint:SetPoint("LEFT",searchBox,"LEFT",5,0)
    local _searchText=""
    searchBox:SetScript("OnEditFocusGained",function() searchHint:Hide() end)
    searchBox:SetScript("OnEditFocusLost",function() if searchBox:GetText()=="" then searchHint:Show() end end)
    searchBox:SetScript("OnEscapePressed",function()
        searchBox:SetText(""); searchBox:ClearFocus(); searchHint:Show()
        CT._searchFilter=""; _searchText=""
        if rebuildUnifiedList then rebuildUnifiedList() end
    end)
    searchBox:SetScript("OnTextChanged",function()
        local t=searchBox:GetText():lower()
        if t~="" then searchHint:Hide() else searchHint:SetShown(not searchBox:HasFocus()) end
        if t==_searchText then return end
        _searchText=t
        CT._searchFilter=t
        -- Switch to All Icons page when searching
        if t~="" and CT._switchToAllIcons then CT._switchToAllIcons() end
        if rebuildUnifiedList then rebuildUnifiedList() end
    end)

    -- Window selector strip below title bar (for pages 1-3)
    local winStrip = CreateFrame("Frame",nil,frame,"BackdropTemplate")
    winStrip:SetPoint("TOPLEFT",frame,"TOPLEFT",SIDE_W+2,-TITLE_H)
    winStrip:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-1,-TITLE_H)
    winStrip:SetHeight(28)
    BD(winStrip,0.03,0.03,0.03,1,0.12,0.12,0.12)
    local wsLbl = winStrip:CreateFontString(nil,"OVERLAY"); wsLbl:SetFont("Fonts\\ARIALN.TTF",10,""); wsLbl:SetTextColor(0.5,0.5,0.5,1); wsLbl:SetText("Editing window:"); wsLbl:SetPoint("LEFT",winStrip,"LEFT",10,0)
    local wsDropF = CreateFrame("Frame",nil,winStrip,"BackdropTemplate"); wsDropF:SetSize(160,20); wsDropF:SetPoint("LEFT",winStrip,"LEFT",100,0); BD(wsDropF,0.10,0.10,0.10,1,0.30,0.30,0.30)
    local wsDropLbl = wsDropF:CreateFontString(nil,"OVERLAY"); wsDropLbl:SetFont("Fonts\\ARIALN.TTF",10,""); wsDropLbl:SetTextColor(1,1,1,1); wsDropLbl:SetPoint("LEFT",wsDropF,"LEFT",5,0)
    local function RefreshWinStripLabel()
        local d=ConsumableTrackerDB; if not d or not d.Windows then return end
        local w=d.Windows[_selectedWinIdx]; wsDropLbl:SetText(w and (w.Name or "Window ".._selectedWinIdx) or "Window 1")
    end
    local wsDropBtn = CreateFrame("Button",nil,wsDropF); wsDropBtn:SetAllPoints()
    wsDropBtn:SetScript("OnClick",function()
        local d=ConsumableTrackerDB; if not d or not d.Windows then return end
        local menu={}
        for i,w in ipairs(d.Windows) do
            local ci=i; table.insert(menu,{label=(w.Name or "Window "..i), onClick=function()
                _selectedWinIdx=ci; RefreshWinStripLabel()
                if CT._RebuildGUI then CT._RebuildGUI() end
            end})
        end
        CT._ShowDropMenu(wsDropF, menu)
    end)
    RefreshWinStripLabel()

    local side=CreateFrame("Frame",nil,frame,"BackdropTemplate"); side:SetPoint("TOPLEFT",frame,"TOPLEFT",1,-TITLE_H); side:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",1,1); side:SetWidth(SIDE_W)
    BD(side,0.04,0.04,0.04,1,0.12,0.12,0.12)
    local sep=frame:CreateTexture(nil,"ARTWORK"); sep:SetColorTexture(0.15,0.15,0.15,1); sep:SetWidth(1)
    sep:SetPoint("TOPLEFT",frame,"TOPLEFT",SIDE_W+1,-TITLE_H); sep:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",SIDE_W+1,1)
    -- Content area offset by winStrip height for pages 1-3
    local contF=CreateFrame("Frame",nil,frame); contF:SetPoint("TOPLEFT",frame,"TOPLEFT",SIDE_W+2,-TITLE_H-28); contF:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-1,1)
    local scTrack=CreateFrame("Frame",nil,contF,"BackdropTemplate"); scTrack:SetWidth(SCRL_W); scTrack:SetPoint("TOPRIGHT",contF,"TOPRIGHT",0,0); scTrack:SetPoint("BOTTOMRIGHT",contF,"BOTTOMRIGHT",0,0); BD(scTrack,0.06,0.06,0.06,1,0.12,0.12,0.12)
    local clip=CreateFrame("Frame",nil,contF); clip:SetClipsChildren(true); clip:SetPoint("TOPLEFT",contF,"TOPLEFT",0,0); clip:SetPoint("BOTTOMLEFT",contF,"BOTTOMLEFT",0,0); clip:SetWidth(PAGE_W); clip:EnableMouseWheel(true)
    local scBar=CreateFrame("Slider",nil,contF); scBar:SetWidth(SCRL_W); scBar:SetOrientation("VERTICAL"); scBar:SetPoint("TOPRIGHT",contF,"TOPRIGHT",0,0); scBar:SetPoint("BOTTOMRIGHT",contF,"BOTTOMRIGHT",0,0)
    scBar:SetMinMaxValues(0,0); scBar:SetValueStep(1); scBar:SetValue(0); scBar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local scTh=scBar:GetThumbTexture(); scTh:SetSize(7,48); scTh:SetColorTexture(0.24,0.49,0.73,0.85)
    local pH=CreateFrame("Frame",nil,clip); pH:SetWidth(PAGE_W); pH:SetHeight(2000); pH:SetPoint("TOPLEFT"); pH:EnableMouseWheel(true)
    local scrollPos=0
    local function ScrollTo(v) local _,mx=scBar:GetMinMaxValues(); v=math.max(0,math.min(mx or 0,v)); scrollPos=v; scBar:SetValue(v); pH:SetPoint("TOPLEFT",clip,"TOPLEFT",0,v) end
    scBar:SetScript("OnValueChanged",function(_,v) ScrollTo(v) end)
    local function Wheel(_,d) ScrollTo(scrollPos-d*30) end
    clip:SetScript("OnMouseWheel",Wheel); pH:SetScript("OnMouseWheel",Wheel)
    -- Clicking the scroll background clears any focused EditBox
    pH:EnableMouse(true)
    pH:SetScript("OnMouseDown",function() if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then GetCurrentKeyBoardFocus():ClearFocus() end end)
    local pages={}
    local function MkPage() local p=CreateFrame("Frame",nil,pH); p:SetAllPoints(pH); p:Hide(); return p end
    pages[1]=MkPage(); BuildPageIcon(pages[1])
    pages[2]=MkPage(); BuildPagePosition(pages[2])
    pages[3]=MkPage(); BuildPageText(pages[3])
    pages[4]=MkPage(); BuildPageAllIcons(pages[4])
    pages[5]=MkPage(); BuildPageMinimap(pages[5])
    pages[6]=MkPage(); BuildPageWindows(pages[6], function()
        -- When windows change, refresh win strip label, All Icons dropdown, and icon list
        RefreshWinStripLabel()
        if CT._refreshAllIcons_winDrop then CT._refreshAllIcons_winDrop() end
        if rebuildUnifiedList then rebuildUnifiedList() end
    end)
    pages[7]=MkPage(); BuildPageBuffWindow(pages[7])
    pages[8]=MkPage(); BuildPageInfo(pages[8])
    pages[9]=MkPage(); BuildPageProfiles(pages[9])
    local pageH={1350,1600,1400,1800,300,600,2000,2800,1200}
    local activePage=1
    local function ShowPage(idx)
        activePage=idx
        -- Win strip only visible for per-window pages 1-3
        winStrip:SetShown(idx<=3)
        -- Adjust contF top anchor (must ClearAllPoints first to avoid dual-anchor collapse)
        contF:ClearAllPoints()
        if idx<=3 then
            contF:SetPoint("TOPLEFT",frame,"TOPLEFT",SIDE_W+2,-TITLE_H-28)
        else
            contF:SetPoint("TOPLEFT",frame,"TOPLEFT",SIDE_W+2,-TITLE_H)
        end
        contF:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-1,1)
        for i,pg in ipairs(pages) do pg:SetShown(i==idx) end; ScrollTo(0)
        local clipH=clip:GetHeight() or (H-TITLE_H-2); scBar:SetMinMaxValues(0,math.max(0,(pageH[idx] or 1200)-clipH))
        if idx==4 and rebuildUnifiedList then rebuildUnifiedList() end
        if idx==6 then
            -- Refresh windows list
            for _,c in ipairs({pages[6]:GetChildren()}) do
                if c.Rebuild then c.Rebuild() end
            end
        end
        if idx==7 and CT._rebuildBuffPageList then CT._rebuildBuffPageList() end
    end
    local sideItems={}
    local function UpdateSide()
        for _,btn in ipairs(sideItems) do
            if btn._pageIdx==activePage then BD(btn,0.18,0.37,0.58,1,0,0,0); btn._lbl:SetTextColor(1,1,1,1)
            else BD(btn,0.04,0.04,0.04,1,0.12,0.12,0.12); btn._lbl:SetTextColor(0.80,0.80,0.80,1) end
        end
    end
    CT._switchToAllIcons = function() ShowPage(4); UpdateSide() end
    local sidebarLayout={
        {type="header",text="APPEARANCE"},
        {type="page",name="Icon & Border",pageIdx=1},
        {type="page",name="Position",pageIdx=2},
        {type="page",name="Text & Font",pageIdx=3},
        {type="gap"},
        {type="header",text="ICONS"},
        {type="page",name="All Icons",pageIdx=4},
        {type="gap"},
        {type="header",text="OTHER"},
        {type="page",name="Windows",pageIdx=6},
        {type="page",name="Minimap",pageIdx=5},
        {type="page",name="Buff Window",pageIdx=7},
        {type="gap"},
        {type="page",name="Information",pageIdx=8},
        {type="gap"},
        {type="page",name="Profiles",pageIdx=9},
    }
    local sy=0
    for _,item in ipairs(sidebarLayout) do
        if item.type=="header" then
            local hdr=CreateFrame("Frame",nil,side,"BackdropTemplate"); hdr:SetPoint("TOPLEFT",side,"TOPLEFT",0,-sy); hdr:SetPoint("TOPRIGHT",side,"TOPRIGHT",0,-sy); hdr:SetHeight(22)
            BD(hdr,0.03,0.03,0.03,1,0.12,0.12,0.12)
            local stripe=hdr:CreateTexture(nil,"ARTWORK"); stripe:SetColorTexture(0.24,0.49,0.73,1); stripe:SetWidth(3); stripe:SetHeight(14); stripe:SetPoint("LEFT",hdr,"LEFT",0,0)
            local hl=hdr:CreateFontString(nil,"OVERLAY"); hl:SetFont("Fonts\\ARIALN.TTF",9,""); hl:SetTextColor(0.55,0.55,0.55,1); hl:SetText(item.text); hl:SetPoint("LEFT",hdr,"LEFT",10,0)
            sy=sy+24
        elseif item.type=="gap" then
            sy=sy+6
        else
            local pi=item.pageIdx
            local sb=CreateFrame("Button",nil,side,"BackdropTemplate"); sb:SetPoint("TOPLEFT",side,"TOPLEFT",0,-sy); sb:SetPoint("TOPRIGHT",side,"TOPRIGHT",0,-sy); sb:SetHeight(40)
            BD(sb,0.04,0.04,0.04,1,0.12,0.12,0.12)
            local stripe=sb:CreateTexture(nil,"ARTWORK"); stripe:SetColorTexture(0.24,0.49,0.73,1); stripe:SetWidth(3); stripe:SetHeight(20); stripe:SetPoint("LEFT",sb,"LEFT",0,0)
            local sl2=sb:CreateFontString(nil,"OVERLAY"); sl2:SetFont("Fonts\\ARIALN.TTF",12,""); sl2:SetTextColor(0.8,0.8,0.8,1); sl2:SetText(item.name); sl2:SetPoint("LEFT",sb,"LEFT",12,0)
            sb._lbl=sl2; sb._pageIdx=pi
            sb:SetScript("OnClick",function() activePage=pi; ShowPage(pi); UpdateSide() end)
            sb:SetScript("OnEnter",function() if pi~=activePage then sb:SetBackdropColor(0.10,0.10,0.10,1) end end)
            sb:SetScript("OnLeave",function() if pi~=activePage then BD(sb,0.04,0.04,0.04,1,0.12,0.12,0.12) end end)
            table.insert(sideItems,sb); sy=sy+40
        end
    end
    local bot=CreateFrame("Frame",nil,frame,"BackdropTemplate"); bot:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",1,1); bot:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-1,1); bot:SetHeight(22); BD(bot,0.02,0.02,0.02,1,0,0,0)
    local botLine=bot:CreateTexture(nil,"ARTWORK"); botLine:SetColorTexture(0.24,0.49,0.73,0.3); botLine:SetHeight(1); botLine:SetPoint("TOPLEFT",bot,"TOPLEFT"); botLine:SetPoint("TOPRIGHT",bot,"TOPRIGHT")
    local botL=bot:CreateFontString(nil,"OVERLAY"); botL:SetFont("Fonts\\ARIALN.TTF",10,""); botL:SetTextColor(0.40,0.40,0.40,1); botL:SetPoint("CENTER",bot)
    botL:SetText("/ct  -  /consumable  -  Right-click any icon to open settings")
    ShowPage(_rebuildRestorePage or 1); _rebuildRestorePage=1; UpdateSide(); GUIFrame=frame
    local alreadyReg=false
    for _,v in ipairs(UISpecialFrames) do if v=="CTSettingsFrame" then alreadyReg=true; break end end
    if not alreadyReg then table.insert(UISpecialFrames,"CTSettingsFrame") end
    C_Timer.After(0.05, function() _guiBuilding = false end)
end

local _rebuilding=false
local _rebuildRestorePage = 1  -- which page to show after a rebuild

local function RebuildGUI()
    if _rebuilding then return end
    _rebuilding=true
    if GUIFrame then GUIFrame:Hide(); GUIFrame=nil end
    if CTSettingsFrame then CTSettingsFrame:Hide(); CTSettingsFrame=nil end
    BuildGUI()
    GUIFrame:Show()
    C_Timer.After(0.1,function() _rebuilding=false end)
end
CT._RebuildGUI=RebuildGUI

-- Rebuild and navigate to a specific page afterwards
function CT._RebuildGUIToPage(pageIdx)
    _rebuildRestorePage = pageIdx or 1
    RebuildGUI()
end

function CT:ToggleGUI()
    if not GUIFrame then
        local ok, err = pcall(BuildGUI)
        if not ok then
            print("|cFFFF4444FRT GUI Error:|r " .. tostring(err))
            return
        end
    end
    if not GUIFrame then print("|cFFFF4444FRT:|r BuildGUI ran but GUIFrame is still nil"); return end
    if GUIFrame:IsShown() then GUIFrame:Hide() else GUIFrame:Show() end
end
