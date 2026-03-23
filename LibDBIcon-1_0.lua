-- LibDBIcon-1.0 (Updated for modern WoW)
local DBICON10 = "LibDBIcon-1.0"
local DBICON10_MINOR = 45

if not LibStub then error(DBICON10 .. " requires LibStub.") end
local ldb = LibStub("LibDataBroker-1.1", true)
if not ldb then error(DBICON10 .. " requires LibDataBroker-1.1.") end
local lib = LibStub:NewLibrary(DBICON10, DBICON10_MINOR)
if not lib then return end

lib.objects = lib.objects or {}
lib.callbackRegistered = lib.callbackRegistered or nil
lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)
lib.notCreated = lib.notCreated or {}
lib.radius = lib.radius or 5
lib.tooltip = lib.tooltip or CreateFrame("GameTooltip", "LibDBIconTooltip", UIParent, "GameTooltipTemplate")
local next, Minimap = next, Minimap
local isDraggingButton = false

function lib:IconCallback(event, name, key, value)
	if lib.objects[name] then
		if key == "icon" then
			lib.objects[name].icon:SetTexture(value)
		elseif key == "iconCoords" then
			lib.objects[name].icon:SetTexCoord(unpack(value))
		elseif key == "iconR" then
			local _, g, b = lib.objects[name].icon:GetVertexColor()
			lib.objects[name].icon:SetVertexColor(value, g, b)
		elseif key == "iconG" then
			local r, _, b = lib.objects[name].icon:GetVertexColor()
			lib.objects[name].icon:SetVertexColor(r, value, b)
		elseif key == "iconB" then
			local r, g = lib.objects[name].icon:GetVertexColor()
			lib.objects[name].icon:SetVertexColor(r, g, value)
		end
	end
end
if not lib.callbackRegistered then
	ldb.RegisterCallback(lib, "LibDataBroker_AttributeChanged__icon", "IconCallback")
	ldb.RegisterCallback(lib, "LibDataBroker_AttributeChanged__iconCoords", "IconCallback")
	ldb.RegisterCallback(lib, "LibDataBroker_AttributeChanged__iconR", "IconCallback")
	ldb.RegisterCallback(lib, "LibDataBroker_AttributeChanged__iconG", "IconCallback")
	ldb.RegisterCallback(lib, "LibDataBroker_AttributeChanged__iconB", "IconCallback")
	lib.callbackRegistered = true
end

local function getAnchors(frame)
	local x, y = frame:GetCenter()
	if not x or not y then return "CENTER" end
	local hhalf = (x > UIParent:GetWidth()*2/3) and "RIGHT" or (x < UIParent:GetWidth()/3) and "LEFT" or ""
	local vhalf = (y > UIParent:GetHeight()/2) and "TOP" or "BOTTOM"
	return vhalf..hhalf, frame, (vhalf == "TOP" and "BOTTOM" or "TOP")..hhalf
end

local function onEnter(self)
	if isDraggingButton then return end

	local obj = self.dataObject
	if obj.OnTooltipShow then
		lib.tooltip:SetOwner(self, "ANCHOR_NONE")
		lib.tooltip:SetPoint(getAnchors(self))
		obj.OnTooltipShow(lib.tooltip)
		lib.tooltip:Show()
	elseif obj.OnEnter then
		obj.OnEnter(self)
	end
end

local function onLeave(self)
	lib.tooltip:Hide()
	local obj = self.dataObject
	if obj.OnLeave then
		obj.OnLeave(self)
	end
end

local onDragStart, onDragStop
do
	local function updatePosition(button, position)
		local angle = math.rad(position or 0)
		local x = math.cos(angle) * lib.radius
		local y = math.sin(angle) * lib.radius
		button:SetPoint("CENTER", Minimap, "CENTER", x, y)
	end

	function onDragStart(self)
		isDraggingButton = true
		lib.tooltip:Hide()
		self:LockHighlight()
		self:SetScript("OnUpdate", function(self)
			local mx, my = Minimap:GetCenter()
			local px, py = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			px, py = px / scale, py / scale
			local pos = math.deg(math.atan2(py - my, px - mx)) % 360
			self.db.minimapPos = pos
			updatePosition(self, pos)
		end)
	end

	function onDragStop(self)
		isDraggingButton = false
		self:SetScript("OnUpdate", nil)
		self:UnlockHighlight()
	end
end

local onClick = function(self, b)
	if self.dataObject.OnClick then
		self.dataObject.OnClick(self, b)
	end
end

local function createButton(name, object, db)
	local button = CreateFrame("Button", "LibDBIcon10_"..name, Minimap)
	button.dataObject = object
	button.db = db
	button:SetFrameStrata("MEDIUM")
	button:SetSize(31, 31)
	button:SetFrameLevel(8)
	button:RegisterForClicks("anyUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture(136477)
	
	local overlay = button:CreateTexture(nil, "OVERLAY")
	overlay:SetSize(53, 53)
	overlay:SetTexture(136430)
	overlay:SetPoint("TOPLEFT")
	
	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetSize(20, 20)
	background:SetTexture(136467)
	background:SetPoint("TOPLEFT", 7, -5)
	
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(17, 17)
	icon:SetTexture(object.icon)
	icon:SetPoint("TOPLEFT", 7, -6)
	button.icon = icon

	button:SetScript("OnEnter", onEnter)
	button:SetScript("OnLeave", onLeave)
	button:SetScript("OnClick", onClick)
	button:SetScript("OnDragStart", onDragStart)
	button:SetScript("OnDragStop", onDragStop)

	lib.objects[name] = button

	if not db.hide then
		button:Show()
		local angle = math.rad(db.minimapPos or 0)
		local x = math.cos(angle) * lib.radius
		local y = math.sin(angle) * lib.radius
		button:SetPoint("CENTER", Minimap, "CENTER", x, y)
	else
		button:Hide()
	end
end

function lib:Register(name, object, db)
	if not object.icon then error("Can't register LDB objects without icons set!") end
	if lib.objects[name] or lib.notCreated[name] then error("Already registered") end
	if not db or not db.hide then
		createButton(name, object, db or {})
	else
		lib.notCreated[name] = {object, db}
	end
end

function lib:Hide(name)
	if not lib.objects[name] then return end
	lib.objects[name]:Hide()
end

function lib:Show(name)
	local obj = lib.objects[name]
	if obj then
		obj:Show()
		local angle = math.rad(obj.db.minimapPos or 0)
		local x = math.cos(angle) * lib.radius  
		local y = math.sin(angle) * lib.radius
		obj:ClearAllPoints()
		obj:SetPoint("CENTER", Minimap, "CENTER", x, y)
	elseif lib.notCreated[name] then
		createButton(name, lib.notCreated[name][1], lib.notCreated[name][2])
		lib.notCreated[name] = nil
	end
end

function lib:GetMinimapButton(name)
	return lib.objects[name]
end
