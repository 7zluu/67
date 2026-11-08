--!nonstrict
-- ╔══════════════════════════════════════════════════╗
-- ║              SpiritUI  v1.0.o                   ║
-- ║         a clean ui lib from scratch             ║
-- ╚══════════════════════════════════════════════════╝

local TweenService     = game:GetService("TweenService")
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TextService      = game:GetService("TextService")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local IsMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

-- ══════════════════════════════════════════════════
--  ROOT TABLE
-- ══════════════════════════════════════════════════
local SpiritUI = {}
SpiritUI.__index  = SpiritUI
SpiritUI.Version  = "1.0.0"
SpiritUI.Flags    = {}
SpiritUI._Windows = {}

-- ══════════════════════════════════════════════════
--  GLOBAL ENV HELPER
-- ══════════════════════════════════════════════════
local function GetGlobalEnv()
	local ok, g = pcall(function()
		if getgenv then return getgenv() end
		return _G
	end)
	return (ok and g) or _G
end

do
	local env   = GetGlobalEnv()
	local prev  = env.__SpiritUI_Unload
	env.__SpiritUI_Unload = nil
	if type(prev) == "function" then pcall(prev) end
end

-- ══════════════════════════════════════════════════
--  JANITOR
-- ══════════════════════════════════════════════════
local Janitor = {}
Janitor.__index = Janitor

function Janitor.new()
	return setmetatable({ _items = {}, _dead = false }, Janitor)
end

function Janitor:Add(item)
	if self._dead then
		local t = typeof(item)
		if t == "RBXScriptConnection" then item:Disconnect()
		elseif t == "Instance"         then item:Destroy() end
		return item
	end
	table.insert(self._items, item)
	return item
end

function Janitor:Destroy()
	if self._dead then return end
	self._dead = true
	for i = #self._items, 1, -1 do
		local item    = self._items[i]
		self._items[i] = nil
		local t       = typeof(item)
		if     t == "RBXScriptConnection"              then pcall(function() item:Disconnect() end)
		elseif t == "Instance"                         then pcall(function() item:Destroy()    end)
		elseif t == "function"                         then pcall(item)
		elseif t == "table" and type(item.Destroy) == "function" then pcall(function() item:Destroy() end)
		end
	end
end

local LibJanitor = Janitor.new()

-- ══════════════════════════════════════════════════
--  SIGNAL
-- ══════════════════════════════════════════════════
local function MakeSignal()
	local listeners = {}
	return {
		Fire = function(...)
			for _, fn in ipairs(table.clone(listeners)) do
				task.spawn(fn, ...)
			end
		end,
		Connect = function(fn)
			table.insert(listeners, fn)
			return {
				Disconnect = function()
					local i = table.find(listeners, fn)
					if i then table.remove(listeners, i) end
				end,
			}
		end,
		Clear = function() table.clear(listeners) end,
	}
end

-- ══════════════════════════════════════════════════
--  MATH UTILS
-- ══════════════════════════════════════════════════
local function SafeClamp(v, lo, hi)
	if hi < lo then return lo end
	return math.clamp(v, lo, hi)
end

local function SafeAlpha(v, mn, mx)
	local range = mx - mn
	if range == 0 then return 0 end
	return math.clamp((v - mn) / range, 0, 1)
end

local function SnapToStep(raw, mn, mx, step)
	if step <= 0 then step = 1 end
	local snapped = math.floor((raw - mn) / step + 0.5) * step + mn
	snapped = math.clamp(snapped, mn, mx)
	local decimals = 0
	local probe = step
	while decimals < 6 and math.abs(probe - math.floor(probe + 0.5)) > 1e-9 do
		probe    = probe * 10
		decimals = decimals + 1
	end
	local factor = 10 ^ decimals
	return math.floor(snapped * factor + (snapped >= 0 and 0.5 or -0.5)) / factor
end

local function FormatNum(v)
	if math.abs(v - math.floor(v + 0.5)) < 1e-9 then
		return tostring(math.floor(v + 0.5))
	end
	return string.format("%.4g", v)
end

-- ══════════════════════════════════════════════════
--  EXECUTOR FILE HELPERS
-- ══════════════════════════════════════════════════
local ASSETS = "SpiritUI/Assets"

local function HasFn(name)
	local ok, fn = pcall(function()
		if getgenv then
			local v = getgenv()[name]
			if type(v) == "function" then return v end
		end
		if getfenv then
			local v = getfenv(1)[name]
			if type(v) == "function" then return v end
		end
		return _G[name]
	end)
	if ok and type(fn) == "function" then return fn end
	return nil
end

local fn_isfolder    = HasFn("isfolder")
local fn_makefolder  = HasFn("makefolder")
local fn_isfile      = HasFn("isfile")
local fn_writefile   = HasFn("writefile")
local fn_readfile    = HasFn("readfile")
local fn_delfile     = HasFn("delfile")
local fn_listfiles   = HasFn("listfiles")
local fn_customasset = HasFn("getcustomasset") or HasFn("getsynasset")

local function EnsureFolder()
	if not (fn_isfolder and fn_makefolder) then return false end
	pcall(function()
		if not fn_isfolder("SpiritUI")  then fn_makefolder("SpiritUI")  end
		if not fn_isfolder(ASSETS) then fn_makefolder(ASSETS) end
	end)
	return true
end

local function ReadFile(path)
	if not (fn_isfile and fn_readfile) then return nil end
	local ok, exists = pcall(fn_isfile, path)
	if not ok or not exists then return nil end
	local ok2, data = pcall(fn_readfile, path)
	return ok2 and data or nil
end

local function WriteFile(path, data)
	if not fn_writefile then return false end
	EnsureFolder()
	return pcall(fn_writefile, path, data) and true or false
end

local function DeleteFile(path)
	if not (fn_isfile and fn_delfile) then return end
	local ok, ex = pcall(fn_isfile, path)
	if ok and ex then pcall(fn_delfile, path) end
end

local function SafeConfigName(name)
	return tostring(name):gsub("[^%w_%-]", "_")
end

-- ══════════════════════════════════════════════════
--  THEME
-- ══════════════════════════════════════════════════
local function LoadFonts()
	local ok, f = pcall(function()
		return {
			Regular  = Font.new("rbxasset://fonts/families/Figtree.json", Enum.FontWeight.Regular,  Enum.FontStyle.Normal),
			SemiBold = Font.new("rbxasset://fonts/families/Figtree.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
			Bold     = Font.new("rbxasset://fonts/families/Figtree.json", Enum.FontWeight.Bold,     Enum.FontStyle.Normal),
		}
	end)
	if ok and f then return f end
	return {
		Regular  = Font.fromEnum(Enum.Font.Gotham),
		SemiBold = Font.fromEnum(Enum.Font.GothamSemibold),
		Bold     = Font.fromEnum(Enum.Font.GothamBold),
	}
end

local Fonts = LoadFonts()

SpiritUI.Theme = {
	-- surfaces
	Background     = Color3.fromRGB(13, 13, 13),
	Surface        = Color3.fromRGB(20, 20, 20),
	SurfaceAlt     = Color3.fromRGB(28, 28, 28),
	Border         = Color3.fromRGB(50, 50, 50),

	-- text
	Text           = Color3.fromRGB(242, 242, 242),
	TextDim        = Color3.fromRGB(140, 140, 148),
	TextFaint      = Color3.fromRGB(80, 80, 85),

	-- accent
	Accent         = Color3.fromRGB(130, 100, 255),
	AccentDim      = Color3.fromRGB(90, 68, 180),
	Danger         = Color3.fromRGB(240, 80, 80),
	Success        = Color3.fromRGB(80, 210, 120),
	Warning        = Color3.fromRGB(240, 170, 60),

	-- fonts
	Font           = Fonts.SemiBold,
	FontRegular    = Fonts.Regular,
	FontBold       = Fonts.Bold,
	MeasureFont    = Enum.Font.GothamSemibold,

	-- sizing
	CornerLg       = 14,
	CornerMd       = 8,
	CornerSm       = 6,
	Margin         = 12,

	-- anim
	Fast           = 0.14,
	Medium         = 0.26,
	Slow           = 0.4,

	-- blur
	Blur           = true,
}

function SpiritUI:SetTheme(overrides)
	for k, v in pairs(overrides) do
		self.Theme[k] = v
	end
end

-- ══════════════════════════════════════════════════
--  Z-INDEX LAYERS
-- ══════════════════════════════════════════════════
local Z = {
	Glass    = 0,
	Window   = 1,
	Content  = 2,
	Header   = 3,
	Backdrop = 390,
	Popup    = 400,
	PopupTop = 410,
	Toast    = 600,
	Modal    = 800,
	ModalTop = 810,
}

-- ══════════════════════════════════════════════════
--  ROOT SCREENGUI
-- ══════════════════════════════════════════════════
local function BuildRoot()
	local parent = PlayerGui
	local gethui = HasFn("gethui")
	if gethui then
		local ok, container = pcall(gethui)
		if ok and container then parent = container end
	end

	local stale = parent:FindFirstChild("SpiritUI")
	if stale then stale:Destroy() end

	local sg = Instance.new("ScreenGui")
	sg.Name             = "SpiritUI"
	sg.ResetOnSpawn     = false
	sg.IgnoreGuiInset   = false
	sg.DisplayOrder     = 9999
	sg.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
	sg.Parent           = parent
	return sg
end

SpiritUI._Root = BuildRoot()

-- ══════════════════════════════════════════════════
--  UI SCALE
-- ══════════════════════════════════════════════════
local SCALE_BASE = IsMobile and 380 or 720
local SCALE_MIN  = IsMobile and 1.0  or 0.72
local SCALE_MAX  = IsMobile and 1.5  or 1.3

local function ViewportSize()
	local root = SpiritUI._Root
	if root and root.AbsoluteSize.X > 0 then return root.AbsoluteSize end
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1280, 720)
end

local function ComputeScale()
	return SafeClamp(ViewportSize().Y / SCALE_BASE, SCALE_MIN, SCALE_MAX)
end

local GlobalScale      = Instance.new("UIScale")
GlobalScale.Name       = "GlobalScale"
GlobalScale.Scale      = ComputeScale()
GlobalScale.Parent     = SpiritUI._Root

local function GetScale() return GlobalScale.Scale end

local function RefreshScale()
	GlobalScale.Scale = ComputeScale()
end

local function WatchCam(cam)
	if not cam then return end
	LibJanitor:Add(cam:GetPropertyChangedSignal("ViewportSize"):Connect(RefreshScale))
end
WatchCam(workspace.CurrentCamera)
LibJanitor:Add(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	WatchCam(workspace.CurrentCamera)
	RefreshScale()
end))

-- ══════════════════════════════════════════════════
--  TWEEN HELPER
-- ══════════════════════════════════════════════════
local function Tween(inst, props, t, style, dir)
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(
			math.max(t or 0.25, 0),
			style or Enum.EasingStyle.Quint,
			dir   or Enum.EasingDirection.Out
		),
		props
	)
	tw:Play()
	return tw
end

-- ══════════════════════════════════════════════════
--  UI BUILDER HELPERS
-- ══════════════════════════════════════════════════
local function Corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or SpiritUI.Theme.CornerLg)
	c.Parent = parent
	return c
end

local function Stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color               = color        or Color3.new(1, 1, 1)
	s.Thickness           = thickness    or 1
	s.Transparency        = transparency or 0.9
	s.ApplyStrokeMode     = Enum.ApplyStrokeMode.Border
	s.Parent              = parent
	return s
end

local function Pad(parent, t, b, l, r)
	local p = Instance.new("UIPadding")
	p.PaddingTop    = UDim.new(0, t or 0)
	p.PaddingBottom = UDim.new(0, b or 0)
	p.PaddingLeft   = UDim.new(0, l or 0)
	p.PaddingRight  = UDim.new(0, r or 0)
	p.Parent = parent
	return p
end

local function ListLayout(parent, dir, h, v, padding, sort)
	local l = Instance.new("UIListLayout")
	l.FillDirection       = dir     or Enum.FillDirection.Vertical
	l.HorizontalAlignment = h       or Enum.HorizontalAlignment.Left
	l.VerticalAlignment   = v       or Enum.VerticalAlignment.Top
	l.Padding             = UDim.new(0, padding or 0)
	l.SortOrder           = sort    or Enum.SortOrder.LayoutOrder
	l.Parent              = parent
	return l
end

local function Frame(parent, props)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.BorderSizePixel        = 0
	for k, v in pairs(props or {}) do f[k] = v end
	f.Parent = parent
	return f
end

local function Label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.BorderSizePixel        = 0
	l.TextXAlignment         = Enum.TextXAlignment.Left
	l.FontFace               = SpiritUI.Theme.FontRegular
	l.TextColor3             = SpiritUI.Theme.Text
	l.TextSize               = 13
	for k, v in pairs(props or {}) do l[k] = v end
	l.Parent = parent
	return l
end

local function Image(parent, props)
	local i = Instance.new("ImageLabel")
	i.BackgroundTransparency = 1
	i.BorderSizePixel        = 0
	for k, v in pairs(props or {}) do i[k] = v end
	i.Parent = parent
	return i
end

-- text measurement
local MeasureCache = {}
local FUDGE = 1.06
local function MeasureText(text, size, maxW)
	text = tostring(text or "")
	maxW = maxW or 10000
	local key = text .. "\1" .. size .. "\1" .. math.floor(maxW)
	if MeasureCache[key] then return MeasureCache[key].X, MeasureCache[key].Y end
	local ok, bounds = pcall(function()
		return TextService:GetTextSize(text, size, SpiritUI.Theme.MeasureFont, Vector2.new(maxW, 100000))
	end)
	local w, h
	if ok and bounds then
		w = math.ceil(bounds.X * FUDGE)
		h = math.ceil(bounds.Y)
	else
		w = math.ceil(#text * size * 0.55)
		h = size + 2
	end
	MeasureCache[key] = Vector2.new(w, h)
	return w, h
end

-- scrollbar thumb
local function AddScrollThumb(scroll, thumbParent, janitor)
	local thumb = Frame(thumbParent, {
		Name                 = "Thumb",
		BackgroundColor3     = SpiritUI.Theme.TextDim,
		BackgroundTransparency = 0.3,
		AnchorPoint          = Vector2.new(1, 0),
		Size                 = UDim2.new(0, 3, 0, 40),
		Visible              = false,
		ZIndex               = (scroll.ZIndex or 0) + 6,
	})
	Corner(thumb, 2)

	local MARGIN = 4
	janitor:Add(RunService.Heartbeat:Connect(function()
		if not thumbParent.Visible then thumb.Visible = false return end
		local wH = scroll.AbsoluteWindowSize.Y
		local cH = scroll.AbsoluteCanvasSize.Y
		local ov = cH - wH
		if ov <= 8 or wH <= 0 then thumb.Visible = false return end
		local trackH = wH - MARGIN * 2
		if trackH <= 0 then thumb.Visible = false return end
		local pPos = thumbParent.AbsolutePosition
		local pSz  = thumbParent.AbsoluteSize
		if pSz.X <= 0 or pSz.Y <= 0 then thumb.Visible = false return end
		local thumbH = math.min(trackH, math.max(30, trackH * (wH / cH)))
		local maxY   = trackH - thumbH
		local ratio  = math.clamp(scroll.CanvasPosition.Y / ov, 0, 1)
		local topY   = (scroll.AbsolutePosition.Y - pPos.Y) + MARGIN + maxY * ratio
		local rightX = (scroll.AbsolutePosition.X + scroll.AbsoluteSize.X) - pPos.X - MARGIN
		thumb.Visible  = true
		thumb.Size     = UDim2.new(0, 3, thumbH / pSz.Y, 0)
		thumb.Position = UDim2.new(rightX / pSz.X, 0, topY / pSz.Y, 0)
	end))
	return thumb
end

-- ══════════════════════════════════════════════════
--  ACRYLIC BLUR SYSTEM
-- ══════════════════════════════════════════════════
local DOF_NAME          = "SpiritUI_DOF"
local ACRYLIC_DIST      = 0.001
local ACRYLIC_TRANSP    = 0.98
local AcrylicDOF        = nil
local AcrylicControllers = {}
local CameraConns       = {}
local AcrylicOff        = false

local function DisconnectCams()
	for i = #CameraConns, 1, -1 do
		CameraConns[i]:Disconnect()
		CameraConns[i] = nil
	end
end

local function EnsureDOF()
	if AcrylicDOF and AcrylicDOF.Parent then return AcrylicDOF end
	local stale = Lighting:FindFirstChild(DOF_NAME)
	if stale then stale:Destroy() end
	local dof = Instance.new("DepthOfFieldEffect")
	dof.Name          = DOF_NAME
	dof.FarIntensity  = 0
	dof.FocusDistance = 0.05
	dof.InFocusRadius = 0.1
	dof.NearIntensity = 1
	dof.Enabled       = false
	dof.Parent        = Lighting
	AcrylicDOF = dof
	LibJanitor:Add(dof)
	return dof
end

local function RefreshDOF()
	if AcrylicOff then return end
	local dof = EnsureDOF()
	dof.Enabled = SpiritUI.Theme.Blur ~= false and #AcrylicControllers > 0
end

local function UpdateAllAcrylic()
	for i = #AcrylicControllers, 1, -1 do
		local c = AcrylicControllers[i]
		if c.Destroyed then table.remove(AcrylicControllers, i)
		else c:Update() end
	end
end

local function BindAcrylicCam(cam)
	DisconnectCams()
	if not cam then return end
	local function conn(prop)
		table.insert(CameraConns, cam:GetPropertyChangedSignal(prop):Connect(UpdateAllAcrylic))
	end
	conn("CFrame"); conn("ViewportSize"); conn("FieldOfView")
	UpdateAllAcrylic()
end

local function CreateAcrylic(guiObject)
	local folder       = Instance.new("Folder")
	folder.Name        = "SpiritUI_AcrylicWin"

	local part         = Instance.new("Part")
	part.Name          = "Glass"
	part.Anchored      = true
	part.CanCollide    = false
	part.CanQuery      = false
	part.CanTouch      = false
	part.CastShadow    = false
	part.Locked        = true
	part.Material      = Enum.Material.Glass
	part.Color         = Color3.new(0, 0, 0)
	part.Reflectance   = 0
	part.Size          = Vector3.new(1, 1, 0.001)
	part.Transparency  = 1
	part.Parent        = folder

	local mesh         = Instance.new("SpecialMesh")
	mesh.Name          = "AcrylicMesh"
	mesh.MeshType      = Enum.MeshType.Brick
	mesh.Offset        = Vector3.new(0, 0, -0.000001)
	mesh.Scale         = Vector3.new(1, 1, 0.001)
	mesh.Parent        = part

	local controller = {
		Gui         = guiObject,
		Folder      = folder,
		Part        = part,
		Mesh        = mesh,
		Connections = {},
		Destroyed   = false,
	}

	function controller:Update()
		if self.Destroyed then return end
		local camera = workspace.CurrentCamera
		local gui    = self.Gui
		if not camera or not gui or not gui.Parent then
			self.Part.Transparency = 1; return
		end
		if self.Folder.Parent ~= camera then
			self.Folder.Parent = camera
		end
		local sz      = gui.AbsoluteSize
		local visible = SpiritUI.Theme.Blur ~= false
			and gui.Visible and sz.X > 2 and sz.Y > 2
		self.Part.Transparency = visible and ACRYLIC_TRANSP or 1
		if not visible then return end

		local inset     = math.clamp(camera.ViewportSize.Y * 0.012, 8, 18)
		local pos       = gui.AbsolutePosition + Vector2.new(inset, inset)
		local panelSize = Vector2.new(math.max(1, sz.X - inset*2), math.max(1, sz.Y - inset*2))

		local function S2W(pt)
			local ray = camera:ScreenPointToRay(pt.X, pt.Y)
			return ray.Origin + ray.Direction * ACRYLIC_DIST
		end

		local tl = S2W(pos)
		local tr = S2W(pos + Vector2.new(panelSize.X, 0))
		local br = S2W(pos + panelSize)
		local w  = (tr - tl).Magnitude
		local h  = (br - tr).Magnitude
		local rc = camera:GetRenderCFrame()

		self.Part.CFrame = CFrame.fromMatrix(
			(tl + br) / 2, rc.XVector, rc.YVector, rc.ZVector
		)
		self.Mesh.Scale = Vector3.new(w, h, 0.001)
	end

	function controller:Destroy()
		if self.Destroyed then return end
		self.Destroyed = true
		for _, c in ipairs(self.Connections) do c:Disconnect() end
		table.clear(self.Connections)
		local idx = table.find(AcrylicControllers, self)
		if idx then table.remove(AcrylicControllers, idx) end
		if self.Folder then self.Folder:Destroy() end
		RefreshDOF()
	end

	for _, prop in ipairs({ "AbsolutePosition", "AbsoluteSize", "Visible" }) do
		table.insert(controller.Connections,
			guiObject:GetPropertyChangedSignal(prop):Connect(function() controller:Update() end))
	end
	table.insert(controller.Connections, guiObject.AncestryChanged:Connect(function()
		if not guiObject.Parent then controller:Destroy() end
	end))

	table.insert(AcrylicControllers, controller)
	RefreshDOF()
	controller:Update()
	return controller
end

BindAcrylicCam(workspace.CurrentCamera)
LibJanitor:Add(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	BindAcrylicCam(workspace.CurrentCamera)
end))
LibJanitor:Add(function() DisconnectCams() end)

local function DestroyAllAcrylic()
	for i = #AcrylicControllers, 1, -1 do AcrylicControllers[i]:Destroy() end
	table.clear(AcrylicControllers)
end

function SpiritUI:SetBlur(enabled)
	SpiritUI.Theme.Blur = enabled
	RefreshDOF()
	UpdateAllAcrylic()
end

-- ══════════════════════════════════════════════════
--  POPUP MANAGER
-- ══════════════════════════════════════════════════
local ActivePopupClose = nil

local function RegisterPopupOpen(fn)
	if ActivePopupClose and ActivePopupClose ~= fn then
		local prev = ActivePopupClose
		ActivePopupClose = nil
		prev()
	end
	ActivePopupClose = fn
end

local function RegisterPopupClose(fn)
	if ActivePopupClose == fn then ActivePopupClose = nil end
end

local function ClosePopup()
	if ActivePopupClose then
		local fn = ActivePopupClose
		ActivePopupClose = nil
		fn()
	end
end

local function MakeBackdrop(onClose)
	local bd = Instance.new("TextButton")
	bd.Name                 = "Backdrop"
	bd.Text                 = ""
	bd.AutoButtonColor      = false
	bd.BackgroundTransparency = 1
	bd.BorderSizePixel      = 0
	bd.Size                 = UDim2.fromScale(1, 1)
	bd.ZIndex               = Z.Backdrop
	bd.Parent               = SpiritUI._Root
	bd.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			onClose()
		end
	end)
	return bd
end

-- ══════════════════════════════════════════════════
--  NOTIFICATIONS
-- ══════════════════════════════════════════════════
local NotifyHolder = nil
SpiritUI._NotifyCount = 0
SpiritUI.Config = { MaxNotifications = 6 }

local function GetNotifyHolder()
	if NotifyHolder and NotifyHolder.Parent then return NotifyHolder end
	local holder = Frame(SpiritUI._Root, {
		Name         = "NotifyHolder",
		AnchorPoint  = Vector2.new(1, 1),
		Position     = UDim2.new(1, -14, 1, -14),
		Size         = UDim2.new(0, 280, 1, -28),
		ZIndex       = Z.Toast,
	})
	ListLayout(holder, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom, 8)

	local maxN = SpiritUI.Config.MaxNotifications
	LibJanitor:Add(RunService.Heartbeat:Connect(function()
		local children = holder:GetChildren()
		local count = 0
		for _, c in ipairs(children) do
			if c:IsA("GuiObject") then count += 1 end
		end
		local used  = 0
		local shown = 0
		for _, entry in ipairs(children) do
			if entry:IsA("GuiObject") then
				local needed = entry.AbsoluteSize.Y
				local fits   = (used + needed) <= holder.AbsoluteSize.Y and shown < maxN
				entry.Visible = fits
				if fits then used += needed; shown += 1 end
			end
		end
	end))

	NotifyHolder = holder
	return holder
end

local NColors = {
	info    = Color3.fromRGB(100, 160, 255),
	success = Color3.fromRGB(90,  210, 130),
	warning = Color3.fromRGB(255, 185, 70),
	error   = Color3.fromRGB(255, 90,  90),
}

function SpiritUI:Notify(opts)
	opts = opts or {}
	local title    = opts.Title    or "Notification"
	local text     = opts.Text     or ""
	local duration = opts.Duration or 4
	local kind     = opts.Type     or "info"
	local color    = opts.Color    or NColors[kind] or SpiritUI.Theme.Accent
	local iconImg  = opts.Icon     or ""

	local holder = GetNotifyHolder()
	SpiritUI._NotifyCount += 1

	local dismissed = false
	local card, acrylicCtrl

	-- card
	card = Frame(holder, {
		Name                 = "Toast_" .. SpiritUI._NotifyCount,
		BackgroundColor3     = SpiritUI.Theme.Surface,
		BackgroundTransparency = 1,
		BorderSizePixel      = 0,
		ClipsDescendants     = true,
		AutomaticSize        = Enum.AutomaticSize.Y,
		Size                 = UDim2.new(1, 0, 0, 0),
		LayoutOrder          = SpiritUI._NotifyCount,
		ZIndex               = Z.Toast,
		Visible              = false,
	})
	Corner(card, 12)
	local cStroke = Stroke(card, Color3.new(1,1,1), 1, 1)
	local cScale  = Instance.new("UIScale"); cScale.Scale = 0.9; cScale.Parent = card
	Pad(card, 10, 10, 12, 12)
	ListLayout(card, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top, 5)

	-- header row
	local header = Frame(card, {
		AutomaticSize = Enum.AutomaticSize.XY,
		Size          = UDim2.fromOffset(0, 0),
		LayoutOrder   = 1,
		ZIndex        = Z.Toast + 1,
	})
	ListLayout(header, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center, 7)

	if iconImg ~= "" then
		Image(header, {
			Image              = iconImg,
			ImageColor3        = color,
			ImageTransparency  = 1,
			Size               = UDim2.fromOffset(14, 14),
			LayoutOrder        = 1,
			ZIndex             = Z.Toast + 1,
		})
	end

	local titleLbl = Label(header, {
		FontFace         = SpiritUI.Theme.Font,
		Text             = title,
		TextColor3       = SpiritUI.Theme.Text,
		TextTransparency = 1,
		TextSize         = 13,
		AutomaticSize    = Enum.AutomaticSize.XY,
		Size             = UDim2.fromOffset(0, 13),
		LayoutOrder      = 2,
		ZIndex           = Z.Toast + 1,
	})

	local bodyLbl
	if text ~= "" then
		bodyLbl = Label(card, {
			FontFace         = SpiritUI.Theme.FontRegular,
			Text             = text,
			TextColor3       = SpiritUI.Theme.TextDim,
			TextTransparency = 1,
			TextSize         = 12,
			TextWrapped      = true,
			AutomaticSize    = Enum.AutomaticSize.Y,
			Size             = UDim2.new(1, 0, 0, 12),
			LayoutOrder      = 2,
			ZIndex           = Z.Toast + 1,
		})
	end

	-- progress bar
	local barBg = Frame(card, {
		BackgroundColor3     = SpiritUI.Theme.SurfaceAlt,
		BackgroundTransparency = 1,
		Size                 = UDim2.new(1, 0, 0, 2),
		LayoutOrder          = 3,
		ZIndex               = Z.Toast + 1,
	})
	Corner(barBg, 2)
	local bar = Frame(barBg, {
		BackgroundColor3     = color,
		BackgroundTransparency = 1,
		AnchorPoint          = Vector2.new(0, 0.5),
		Position             = UDim2.new(0, 0, 0.5, 0),
		Size                 = UDim2.fromScale(1, 1),
		ZIndex               = Z.Toast + 2,
	})
	Corner(bar, 2)

	local function dismiss()
		if dismissed then return end
		dismissed = true
		local h = card.AbsoluteSize.Y / GetScale()
		card.AutomaticSize = Enum.AutomaticSize.None
		card.Size = UDim2.new(1, 0, 0, h)
		Tween(card,   { BackgroundTransparency = 1 }, 0.16)
		Tween(cStroke,{ Transparency           = 1 }, 0.16)
		Tween(cScale, { Scale = 0.9 }, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		Tween(titleLbl, { TextTransparency = 1 }, 0.16)
		if bodyLbl then Tween(bodyLbl, { TextTransparency = 1 }, 0.16) end
		task.delay(0.1, function()
			if card and card.Parent then
				Tween(card, { Size = UDim2.new(1, 0, 0, 0) }, 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			end
		end)
		task.delay(0.32, function()
			if acrylicCtrl then acrylicCtrl:Destroy() end
			if card and card.Parent then card:Destroy() end
		end)
	end

	-- show
	task.spawn(function()
		task.wait()
		card.Visible   = true
		acrylicCtrl    = CreateAcrylic(card)
		Tween(card,    { BackgroundTransparency = 0.22 }, 0.28)
		Tween(cStroke, { Transparency           = 0.78 }, 0.28)
		Tween(cScale,  { Scale = 1 }, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		Tween(titleLbl,{ TextTransparency = 0 }, 0.28)
		Tween(barBg,   { BackgroundTransparency = 0.8  }, 0.28)
		Tween(bar,     { BackgroundTransparency = 0    }, 0.28)
		if bodyLbl then Tween(bodyLbl, { TextTransparency = 0 }, 0.28) end

		Tween(bar, { Size = UDim2.fromScale(0, 1) }, duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
		task.delay(duration, dismiss)
	end)

	return { Dismiss = dismiss }
end

-- ══════════════════════════════════════════════════
--  WINDOW
-- ══════════════════════════════════════════════════
function SpiritUI:CreateWindow(opts)
	opts = opts or {}
	local title    = opts.Title    or "SpiritUI"
	local subtitle = opts.Subtitle or ""
	local size     = opts.Size     or Vector2.new(520, 400)
	local position = opts.Position
	local minSize  = opts.MinSize  or Vector2.new(300, 200)
	local iconImg  = opts.Icon     or ""

	local winJanitor = Janitor.new()
	table.insert(SpiritUI._Windows, { _janitor = winJanitor, _destroyed = false })

	-- ── outer frame (shadow + container) ──
	local vp = ViewportSize()
	local startPos
	if position then
		startPos = UDim2.fromOffset(position.X, position.Y)
	else
		startPos = UDim2.fromOffset(
			math.floor((vp.X - size.X) / 2),
			math.floor((vp.Y - size.Y) / 2)
		)
	end

	local shadow = Frame(SpiritUI._Root, {
		Name        = "SpiritWin_" .. title,
		Size        = UDim2.fromOffset(size.X, size.Y),
		Position    = startPos,
		ZIndex      = Z.Window,
	})
	winJanitor:Add(shadow)

	-- shadow effect
	local shadowImg = Image(shadow, {
		Image            = "rbxassetid://6014261993",
		ImageColor3      = Color3.new(0, 0, 0),
		ImageTransparency = 0.5,
		ScaleType        = Enum.ScaleType.Slice,
		SliceCenter      = Rect.new(49, 49, 450, 450),
		Size             = UDim2.new(1, 24, 1, 24),
		Position         = UDim2.fromOffset(-12, -6),
		ZIndex           = Z.Window - 1,
	})

	-- main window frame
	local win = Frame(shadow, {
		Name                 = "Main",
		BackgroundColor3     = SpiritUI.Theme.Background,
		BackgroundTransparency = 0,
		BorderSizePixel      = 0,
		Size                 = UDim2.fromScale(1, 1),
		ZIndex               = Z.Window,
		ClipsDescendants     = true,
	})
	Corner(win, SpiritUI.Theme.CornerLg)
	Stroke(win, SpiritUI.Theme.Border, 1, 0.6)

	local acrylicCtrl = CreateAcrylic(win)
	winJanitor:Add(function() acrylicCtrl:Destroy() end)

	-- ── HEADER ──────────────────────────────────────
	local header = Frame(win, {
		Name             = "Header",
		BackgroundColor3 = SpiritUI.Theme.Surface,
		BackgroundTransparency = 0,
		Size             = UDim2.new(1, 0, 0, 44),
		ZIndex           = Z.Header,
		BorderSizePixel  = 0,
	})
	Stroke(header, SpiritUI.Theme.Border, 1, 0.75)
	-- bottom stroke only via child frame
	local headerLine = Frame(header, {
		BackgroundColor3     = SpiritUI.Theme.Border,
		BackgroundTransparency = 0,
		Size                 = UDim2.new(1, 0, 0, 1),
		Position             = UDim2.new(0, 0, 1, -1),
		ZIndex               = Z.Header + 1,
	})

	-- icon + title
	local headerLeft = Frame(header, {
		Size         = UDim2.new(1, -80, 1, 0),
		Position     = UDim2.fromOffset(12, 0),
		ZIndex       = Z.Header + 1,
	})
	ListLayout(headerLeft, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center, 8)

	if iconImg ~= "" then
		Image(headerLeft, {
			Image   = iconImg,
			Size    = UDim2.fromOffset(18, 18),
			ZIndex  = Z.Header + 2,
		})
	end

	local titleBlock = Frame(headerLeft, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size          = UDim2.fromOffset(0, 44),
		ZIndex        = Z.Header + 1,
	})
	ListLayout(titleBlock, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center, 1)

	Label(titleBlock, {
		FontFace  = SpiritUI.Theme.Font,
		Text      = title,
		TextColor3 = SpiritUI.Theme.Text,
		TextSize  = 14,
		AutomaticSize = Enum.AutomaticSize.X,
		Size      = UDim2.fromOffset(0, 16),
		ZIndex    = Z.Header + 2,
	})
	if subtitle ~= "" then
		Label(titleBlock, {
			FontFace   = SpiritUI.Theme.FontRegular,
			Text       = subtitle,
			TextColor3 = SpiritUI.Theme.TextDim,
			TextSize   = 11,
			AutomaticSize = Enum.AutomaticSize.X,
			Size       = UDim2.fromOffset(0, 12),
			ZIndex     = Z.Header + 2,
		})
	end

	-- close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name              = "Close"
	closeBtn.Text              = ""
	closeBtn.AutoButtonColor   = false
	closeBtn.BackgroundColor3  = Color3.fromRGB(255, 80, 80)
	closeBtn.BackgroundTransparency = 0.3
	closeBtn.BorderSizePixel   = 0
	closeBtn.AnchorPoint       = Vector2.new(1, 0.5)
	closeBtn.Position          = UDim2.new(1, -12, 0.5, 0)
	closeBtn.Size              = UDim2.fromOffset(14, 14)
	closeBtn.ZIndex            = Z.Header + 2
	closeBtn.Parent            = header
	Corner(closeBtn, 7)

	local minimizeBtn = Instance.new("TextButton")
	minimizeBtn.Name            = "Minimize"
	minimizeBtn.Text            = ""
	minimizeBtn.AutoButtonColor = false
	minimizeBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 50)
	minimizeBtn.BackgroundTransparency = 0.3
	minimizeBtn.BorderSizePixel = 0
	minimizeBtn.AnchorPoint     = Vector2.new(1, 0.5)
	minimizeBtn.Position        = UDim2.new(1, -32, 0.5, 0)
	minimizeBtn.Size            = UDim2.fromOffset(14, 14)
	minimizeBtn.ZIndex          = Z.Header + 2
	minimizeBtn.Parent          = header
	Corner(minimizeBtn, 7)

	-- ── BODY (tab bar + content) ─────────────────────
	local body = Frame(win, {
		Name     = "Body",
		Position = UDim2.new(0, 0, 0, 44),
		Size     = UDim2.new(1, 0, 1, -44),
		ZIndex   = Z.Content,
	})

	-- sidebar
	local sidebar = Frame(body, {
		Name                 = "Sidebar",
		BackgroundColor3     = SpiritUI.Theme.Surface,
		BackgroundTransparency = 0,
		Size                 = UDim2.new(0, 130, 1, 0),
		ZIndex               = Z.Content,
		BorderSizePixel      = 0,
	})
	-- sidebar right border
	Frame(sidebar, {
		BackgroundColor3     = SpiritUI.Theme.Border,
		BackgroundTransparency = 0,
		Size                 = UDim2.new(0, 1, 1, 0),
		Position             = UDim2.new(1, -1, 0, 0),
		ZIndex               = Z.Content + 1,
	})

	local sideScroll = Instance.new("ScrollingFrame")
	sideScroll.Name                     = "SideScroll"
	sideScroll.BackgroundTransparency   = 1
	sideScroll.BorderSizePixel          = 0
	sideScroll.Size                     = UDim2.new(1, 0, 1, -8)
	sideScroll.Position                 = UDim2.fromOffset(0, 8)
	sideScroll.ScrollBarThickness       = 0
	sideScroll.ScrollBarImageTransparency = 1
	sideScroll.CanvasSize               = UDim2.fromOffset(0, 0)
	sideScroll.AutomaticCanvasSize      = Enum.AutomaticSize.Y
	sideScroll.ZIndex                   = Z.Content + 1
	sideScroll.Parent                   = sidebar
	Pad(sideScroll, 0, 8, 8, 8)
	local sideList = ListLayout(sideScroll, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top, 2)

	-- content area
	local contentArea = Frame(body, {
		Name     = "ContentArea",
		Position = UDim2.new(0, 130, 0, 0),
		Size     = UDim2.new(1, -130, 1, 0),
		ZIndex   = Z.Content,
	})

	-- ── DRAG ────────────────────────────────────────
	local dragging      = false
	local dragOffset    = Vector2.new()
	local dragConn1, dragConn2

	header.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			dragging   = true
			dragOffset = Vector2.new(
				shadow.AbsolutePosition.X - inp.Position.X,
				shadow.AbsolutePosition.Y - inp.Position.Y
			)
			ClosePopup()
		end
	end)

	dragConn1 = UserInputService.InputChanged:Connect(function(inp)
		if not dragging then return end
		if inp.UserInputType == Enum.UserInputType.MouseMovement
			or inp.UserInputType == Enum.UserInputType.Touch then
			local vsize = ViewportSize()
			local newX  = SafeClamp(inp.Position.X + dragOffset.X, 0, vsize.X - shadow.AbsoluteSize.X)
			local newY  = SafeClamp(inp.Position.Y + dragOffset.Y, 0, vsize.Y - shadow.AbsoluteSize.Y)
			shadow.Position = UDim2.fromOffset(newX, newY)
		end
	end)

	dragConn2 = UserInputService.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	winJanitor:Add(dragConn1)
	winJanitor:Add(dragConn2)

	-- ── MINIMIZE ────────────────────────────────────
	local minimized = false
	minimizeBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		if minimized then
			Tween(shadow, { Size = UDim2.fromOffset(shadow.AbsoluteSize.X / GetScale(), 44) }, SpiritUI.Theme.Medium)
		else
			Tween(shadow, { Size = UDim2.fromOffset(size.X, size.Y) }, SpiritUI.Theme.Medium)
		end
	end)

	-- ── CLOSE ───────────────────────────────────────
	local function destroyWindow()
		Tween(shadow, { Size = UDim2.fromOffset(shadow.AbsoluteSize.X / GetScale(), 0) }, 0.18,
			Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.delay(0.2, function()
			winJanitor:Destroy()
		end)
	end

	closeBtn.MouseEnter:Connect(function() Tween(closeBtn, { BackgroundTransparency = 0.1 }, 0.1) end)
	closeBtn.MouseLeave:Connect(function() Tween(closeBtn, { BackgroundTransparency = 0.3 }, 0.1) end)
	closeBtn.MouseButton1Click:Connect(destroyWindow)

	minimizeBtn.MouseEnter:Connect(function() Tween(minimizeBtn, { BackgroundTransparency = 0.1 }, 0.1) end)
	minimizeBtn.MouseLeave:Connect(function() Tween(minimizeBtn, { BackgroundTransparency = 0.3 }, 0.1) end)

	-- open animation
	shadow.Size = UDim2.fromOffset(size.X, 0)
	Tween(shadow, { Size = UDim2.fromOffset(size.X, size.Y) }, SpiritUI.Theme.Medium)

	-- ── TAB SYSTEM ──────────────────────────────────
	local tabs = {}
	local activeTab = nil

	local function SetActiveTab(tab)
		if activeTab == tab then return end
		if activeTab then
			Tween(activeTab._btn, { BackgroundTransparency = 1 }, SpiritUI.Theme.Fast)
			Tween(activeTab._btnLabel, { TextTransparency = 0.4 }, SpiritUI.Theme.Fast)
			if activeTab._btnIcon then Tween(activeTab._btnIcon, { ImageTransparency = 0.4 }, SpiritUI.Theme.Fast) end
			activeTab._page.Visible = false
		end
		activeTab = tab
		Tween(tab._btn, { BackgroundTransparency = 0.88 }, SpiritUI.Theme.Fast)
		Tween(tab._btnLabel, { TextTransparency = 0 }, SpiritUI.Theme.Fast)
		if tab._btnIcon then Tween(tab._btnIcon, { ImageTransparency = 0 }, SpiritUI.Theme.Fast) end
		tab._page.Visible = true
	end

	local Window = {}
	Window._janitor = winJanitor
	Window._shadow  = shadow
	Window._tabs    = tabs

	function Window:Destroy()
		destroyWindow()
	end

	function Window:AddTab(tabOpts)
		tabOpts = tabOpts or {}
		local tabTitle = tabOpts.Title or ("Tab " .. (#tabs + 1))
		local tabIcon  = tabOpts.Icon  or ""

		-- sidebar button
		local btn = Instance.new("TextButton")
		btn.Name                 = "Tab_" .. tabTitle
		btn.Text                 = ""
		btn.AutoButtonColor      = false
		btn.BackgroundColor3     = SpiritUI.Theme.Accent
		btn.BackgroundTransparency = 1
		btn.BorderSizePixel      = 0
		btn.Size                 = UDim2.new(1, 0, 0, 32)
		btn.ZIndex               = Z.Content + 2
		btn.Parent               = sideScroll
		Corner(btn, SpiritUI.Theme.CornerMd)

		local btnInner = Frame(btn, {
			Size    = UDim2.fromScale(1, 1),
			ZIndex  = Z.Content + 2,
		})
		ListLayout(btnInner, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center, 7)
		Pad(btnInner, 0, 0, 10, 10)

		local btnIcon
		if tabIcon ~= "" then
			btnIcon = Image(btnInner, {
				Image             = tabIcon,
				ImageColor3       = SpiritUI.Theme.Text,
				ImageTransparency = 0.4,
				Size              = UDim2.fromOffset(14, 14),
				ZIndex            = Z.Content + 3,
			})
		end

		local btnLabel = Label(btnInner, {
			FontFace         = SpiritUI.Theme.Font,
			Text             = tabTitle,
			TextColor3       = SpiritUI.Theme.Text,
			TextTransparency = 0.4,
			TextSize         = 12,
			AutomaticSize    = Enum.AutomaticSize.X,
			Size             = UDim2.fromOffset(0, 32),
			ZIndex           = Z.Content + 3,
		})

		-- page (content scroll)
		local page = Instance.new("ScrollingFrame")
		page.Name                      = "Page_" .. tabTitle
		page.BackgroundTransparency    = 1
		page.BorderSizePixel           = 0
		page.Size                      = UDim2.fromScale(1, 1)
		page.ScrollBarThickness        = 0
		page.ScrollBarImageTransparency = 1
		page.CanvasSize                = UDim2.fromOffset(0, 0)
		page.AutomaticCanvasSize       = Enum.AutomaticSize.Y
		page.ZIndex                    = Z.Content + 1
		page.Visible                   = false
		page.Parent                    = contentArea
		Pad(page, 10, 10, 10, 10)

		local pageList = ListLayout(page, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top, 6)

		AddScrollThumb(page, contentArea, winJanitor)

		local tab = {
			_btn      = btn,
			_btnLabel = btnLabel,
			_btnIcon  = btnIcon,
			_page     = page,
			_pageList = pageList,
		}
		table.insert(tabs, tab)

		btn.MouseButton1Click:Connect(function() SetActiveTab(tab) end)
		btn.MouseEnter:Connect(function()
			if activeTab ~= tab then Tween(btn, { BackgroundTransparency = 0.95 }, SpiritUI.Theme.Fast) end
		end)
		btn.MouseLeave:Connect(function()
			if activeTab ~= tab then Tween(btn, { BackgroundTransparency = 1 }, SpiritUI.Theme.Fast) end
		end)

		if #tabs == 1 then SetActiveTab(tab) end

		-- ────────────────────────────────────────────
		--  SECTION
		-- ────────────────────────────────────────────
		local Tab = {}

		function Tab:AddSection(sectionOpts)
			sectionOpts = sectionOpts or {}
			local sTitle = sectionOpts.Title or ""

			local sectionFrame = Frame(page, {
				Name          = "Section",
				AutomaticSize = Enum.AutomaticSize.Y,
				Size          = UDim2.new(1, 0, 0, 0),
				ZIndex        = Z.Content + 2,
			})
			ListLayout(sectionFrame, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top, 4)

			if sTitle ~= "" then
				local row = Frame(sectionFrame, {
					AutomaticSize = Enum.AutomaticSize.Y,
					Size          = UDim2.new(1, 0, 0, 0),
					ZIndex        = Z.Content + 2,
				})
				ListLayout(row, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center, 8)

				Label(row, {
					FontFace   = SpiritUI.Theme.Font,
					Text       = sTitle,
					TextColor3 = SpiritUI.Theme.TextDim,
					TextSize   = 10,
					AutomaticSize = Enum.AutomaticSize.X,
					Size       = UDim2.fromOffset(0, 10),
					ZIndex     = Z.Content + 3,
				})

				Frame(row, {
					BackgroundColor3     = SpiritUI.Theme.Border,
					BackgroundTransparency = 0,
					Size                 = UDim2.new(1, -MeasureText(sTitle, 10) - 20, 0, 1),
					ZIndex               = Z.Content + 2,
				})
			end

			-- shared row builder
			local function MakeRow(label, desc)
				local row = Frame(sectionFrame, {
					Name          = "Row_" .. tostring(label),
					BackgroundColor3     = SpiritUI.Theme.SurfaceAlt,
					BackgroundTransparency = 0.3,
					AutomaticSize = Enum.AutomaticSize.Y,
					Size          = UDim2.new(1, 0, 0, 0),
					ZIndex        = Z.Content + 2,
				})
				Corner(row, SpiritUI.Theme.CornerSm)
				Pad(row, 8, 8, 10, 10)

				local leftSide = Frame(row, {
					AutomaticSize = Enum.AutomaticSize.Y,
					Size          = UDim2.new(0.6, 0, 0, 0),
					ZIndex        = Z.Content + 3,
				})
				ListLayout(leftSide, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center, 2)

				Label(leftSide, {
					FontFace   = SpiritUI.Theme.Font,
					Text       = label or "",
					TextColor3 = SpiritUI.Theme.Text,
					TextSize   = 12,
					AutomaticSize = Enum.AutomaticSize.Y,
					Size       = UDim2.new(1, 0, 0, 12),
					TextWrapped = true,
					ZIndex     = Z.Content + 4,
				})
				if desc and desc ~= "" then
					Label(leftSide, {
						FontFace   = SpiritUI.Theme.FontRegular,
						Text       = desc,
						TextColor3 = SpiritUI.Theme.TextDim,
						TextSize   = 10,
						AutomaticSize = Enum.AutomaticSize.Y,
						Size       = UDim2.new(1, 0, 0, 10),
						TextWrapped = true,
						ZIndex     = Z.Content + 4,
					})
				end

				local rightSide = Frame(row, {
					AnchorPoint   = Vector2.new(1, 0.5),
					Position      = UDim2.new(1, -10, 0.5, 0),
					AutomaticSize = Enum.AutomaticSize.XY,
					Size          = UDim2.fromOffset(0, 0),
					ZIndex        = Z.Content + 3,
				})
				ListLayout(rightSide, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center, 4)

				return row, rightSide
			end

			local Section = {}

			-- ── BUTTON ──────────────────────────────
			function Section:AddButton(bOpts)
				bOpts = bOpts or {}
				local lbl  = bOpts.Title    or "Button"
				local desc = bOpts.Description or ""
				local cb   = bOpts.Callback  or function() end

				local row, rightSide = MakeRow(lbl, desc)
				row.BackgroundTransparency = 0.5

				local btn2 = Instance.new("TextButton")
				btn2.Name              = "Btn"
				btn2.Text              = bOpts.ButtonText or "Execute"
				btn2.AutoButtonColor   = false
				btn2.BackgroundColor3  = SpiritUI.Theme.Accent
				btn2.BackgroundTransparency = 0.1
				btn2.BorderSizePixel   = 0
				btn2.FontFace          = SpiritUI.Theme.Font
				btn2.TextColor3        = Color3.new(1,1,1)
				btn2.TextSize          = 11
				btn2.AutomaticSize     = Enum.AutomaticSize.X
				btn2.Size              = UDim2.fromOffset(0, 24)
				btn2.ZIndex            = Z.Content + 4
				btn2.Parent            = rightSide
				Corner(btn2, SpiritUI.Theme.CornerSm)
				Pad(btn2, 0, 0, 10, 10)

				btn2.MouseEnter:Connect(function()
					Tween(btn2, { BackgroundTransparency = 0 }, SpiritUI.Theme.Fast)
				end)
				btn2.MouseLeave:Connect(function()
					Tween(btn2, { BackgroundTransparency = 0.1 }, SpiritUI.Theme.Fast)
				end)
				btn2.MouseButton1Click:Connect(function()
					task.spawn(cb)
					local orig = btn2.BackgroundColor3
					Tween(btn2, { BackgroundColor3 = SpiritUI.Theme.Success }, 0.1)
					task.delay(0.3, function()
						Tween(btn2, { BackgroundColor3 = orig }, 0.2)
					end)
				end)

				return { SetText = function(_, t) btn2.Text = t end }
			end

			-- ── TOGGLE ──────────────────────────────
			function Section:AddToggle(tOpts)
				tOpts = tOpts or {}
				local lbl  = tOpts.Title       or "Toggle"
				local desc = tOpts.Description  or ""
				local def  = tOpts.Default      or false
				local flag = tOpts.Flag
				local cb   = tOpts.Callback     or function() end

				local state = def
				if flag and SpiritUI.Flags[flag] ~= nil then
					state = SpiritUI.Flags[flag]
				end

				local row, rightSide = MakeRow(lbl, desc)

				-- track
				local track = Frame(rightSide, {
					BackgroundColor3     = state and SpiritUI.Theme.Accent or SpiritUI.Theme.SurfaceAlt,
					BackgroundTransparency = 0,
					Size                 = UDim2.fromOffset(36, 20),
					ZIndex               = Z.Content + 4,
				})
				Corner(track, 10)
				Stroke(track, SpiritUI.Theme.Border, 1, 0.5)

				local knob = Frame(track, {
					BackgroundColor3     = Color3.new(1,1,1),
					BackgroundTransparency = 0,
					AnchorPoint          = Vector2.new(0.5, 0.5),
					Position             = state and UDim2.new(0, 28, 0.5, 0) or UDim2.new(0, 10, 0.5, 0),
					Size                 = UDim2.fromOffset(14, 14),
					ZIndex               = Z.Content + 5,
				})
				Corner(knob, 7)

				local function UpdateVisual(s, animate)
					local t = animate and SpiritUI.Theme.Fast or 0
					Tween(track, { BackgroundColor3 = s and SpiritUI.Theme.Accent or SpiritUI.Theme.SurfaceAlt }, t)
					Tween(knob,  { Position = s and UDim2.new(0, 28, 0.5, 0) or UDim2.new(0, 10, 0.5, 0) }, t)
				end

				local function Toggle()
					state = not state
					if flag then SpiritUI.Flags[flag] = state end
					UpdateVisual(state, true)
					task.spawn(cb, state)
				end

				track.InputBegan:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1
						or inp.UserInputType == Enum.UserInputType.Touch then
						Toggle()
					end
				end)

				local Toggle_API = {}
				function Toggle_API:Set(v)
					state = v
					if flag then SpiritUI.Flags[flag] = state end
					UpdateVisual(state, true)
				end
				function Toggle_API:Get() return state end

				return Toggle_API
			end

			-- ── SLIDER ──────────────────────────────
			function Section:AddSlider(sOpts)
				sOpts = sOpts or {}
				local lbl  = sOpts.Title       or "Slider"
				local desc = sOpts.Description  or ""
				local mn   = sOpts.Min          or 0
				local mx   = sOpts.Max          or 100
				local def  = sOpts.Default      or mn
				local step = sOpts.Step         or 1
				local flag = sOpts.Flag
				local cb   = sOpts.Callback     or function() end
				local unit = sOpts.Unit         or ""

				local value = def
				if flag and SpiritUI.Flags[flag] ~= nil then
					value = SpiritUI.Flags[flag]
				end
				value = SafeClamp(value, mn, mx)

				local row, rightSide = MakeRow(lbl, desc)
				row.AutomaticSize = Enum.AutomaticSize.None
				row.Size = UDim2.new(1, 0, 0, 44)

				-- value label
				local valLabel = Label(rightSide, {
					FontFace   = SpiritUI.Theme.FontRegular,
					Text       = FormatNum(value) .. unit,
					TextColor3 = SpiritUI.Theme.TextDim,
					TextSize   = 11,
					AutomaticSize = Enum.AutomaticSize.X,
					Size       = UDim2.fromOffset(0, 11),
					ZIndex     = Z.Content + 4,
				})

				-- track bar  (full width at bottom of row)
				local trackBg = Frame(row, {
					Name                 = "Track",
					BackgroundColor3     = SpiritUI.Theme.SurfaceAlt,
					BackgroundTransparency = 0,
					AnchorPoint          = Vector2.new(0, 1),
					Position             = UDim2.new(0, 10, 1, -8),
					Size                 = UDim2.new(1, -20, 0, 4),
					ZIndex               = Z.Content + 4,
				})
				Corner(trackBg, 2)

				local fill = Frame(trackBg, {
					BackgroundColor3     = SpiritUI.Theme.Accent,
					BackgroundTransparency = 0,
					AnchorPoint          = Vector2.new(0, 0.5),
					Position             = UDim2.new(0, 0, 0.5, 0),
					Size                 = UDim2.new(SafeAlpha(value, mn, mx), 0, 1, 0),
					ZIndex               = Z.Content + 5,
				})
				Corner(fill, 2)

				local handle = Frame(trackBg, {
					BackgroundColor3     = Color3.new(1,1,1),
					BackgroundTransparency = 0,
					AnchorPoint          = Vector2.new(0.5, 0.5),
					Position             = UDim2.new(SafeAlpha(value, mn, mx), 0, 0.5, 0),
					Size                 = UDim2.fromOffset(12, 12),
					ZIndex               = Z.Content + 6,
				})
				Corner(handle, 6)

				local sliding = false

				local function SetValue(alpha)
					local raw     = mn + alpha * (mx - mn)
					value         = SnapToStep(raw, mn, mx, step)
					local a2      = SafeAlpha(value, mn, mx)
					fill.Size     = UDim2.new(a2, 0, 1, 0)
					handle.Position = UDim2.new(a2, 0, 0.5, 0)
					valLabel.Text = FormatNum(value) .. unit
					if flag then SpiritUI.Flags[flag] = value end
					task.spawn(cb, value)
				end

				trackBg.InputBegan:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1
						or inp.UserInputType == Enum.UserInputType.Touch then
						sliding = true
						local alpha = SafeAlpha(inp.Position.X, trackBg.AbsolutePosition.X,
							trackBg.AbsolutePosition.X + trackBg.AbsoluteSize.X)
						SetValue(alpha)
					end
				end)

				winJanitor:Add(UserInputService.InputChanged:Connect(function(inp)
					if not sliding then return end
					if inp.UserInputType == Enum.UserInputType.MouseMovement
						or inp.UserInputType == Enum.UserInputType.Touch then
						local alpha = SafeAlpha(inp.Position.X, trackBg.AbsolutePosition.X,
							trackBg.AbsolutePosition.X + trackBg.AbsoluteSize.X)
						SetValue(alpha)
					end
				end))

				winJanitor:Add(UserInputService.InputEnded:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1
						or inp.UserInputType == Enum.UserInputType.Touch then
						sliding = false
					end
				end))

				local Slider_API = {}
				function Slider_API:Set(v)
					value = SafeClamp(v, mn, mx)
					SetValue(SafeAlpha(value, mn, mx))
				end
				function Slider_API:Get() return value end
				return Slider_API
			end

			-- ── DROPDOWN ────────────────────────────
			function Section:AddDropdown(dOpts)
				dOpts = dOpts or {}
				local lbl     = dOpts.Title       or "Dropdown"
				local desc    = dOpts.Description  or ""
				local items   = dOpts.Items        or {}
				local def     = dOpts.Default      or (items[1] or "")
				local flag    = dOpts.Flag
				local cb      = dOpts.Callback     or function() end
				local multi   = dOpts.MultiSelect  or false

				local selected = multi and {} or def
				if multi then
					if type(def) == "table" then selected = def else selected = {def} end
				end
				if flag and SpiritUI.Flags[flag] ~= nil then selected = SpiritUI.Flags[flag] end

				local row, rightSide = MakeRow(lbl, desc)

				local dropBtn = Instance.new("TextButton")
				dropBtn.Name               = "DropBtn"
				dropBtn.Text               = ""
				dropBtn.AutoButtonColor    = false
				dropBtn.BackgroundColor3   = SpiritUI.Theme.SurfaceAlt
				dropBtn.BackgroundTransparency = 0
				dropBtn.BorderSizePixel    = 0
				dropBtn.Size               = UDim2.fromOffset(140, 24)
				dropBtn.ZIndex             = Z.Content + 4
				dropBtn.Parent             = rightSide
				Corner(dropBtn, SpiritUI.Theme.CornerSm)
				Stroke(dropBtn, SpiritUI.Theme.Border, 1, 0.5)
				Pad(dropBtn, 0, 0, 8, 8)

				local dropInner = Frame(dropBtn, {
					Size = UDim2.fromScale(1, 1),
					ZIndex = Z.Content + 4,
				})
				ListLayout(dropInner, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center, 4)

				local dropLabel = Label(dropInner, {
					FontFace   = SpiritUI.Theme.FontRegular,
					TextColor3 = SpiritUI.Theme.Text,
					TextSize   = 11,
					AutomaticSize = Enum.AutomaticSize.None,
					Size       = UDim2.new(1, -18, 1, 0),
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex     = Z.Content + 5,
				})

				local dropArrow = Label(dropInner, {
					FontFace   = SpiritUI.Theme.FontBold,
					Text       = "▾",
					TextColor3 = SpiritUI.Theme.TextDim,
					TextSize   = 12,
					Size       = UDim2.fromOffset(14, 24),
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex     = Z.Content + 5,
				})

				local function GetDisplayText()
					if multi then
						if #selected == 0 then return "None" end
						return table.concat(selected, ", ")
					else
						return tostring(selected)
					end
				end

				dropLabel.Text = GetDisplayText()

				local listOpen   = false
				local listFrame  = nil
				local listBdrop  = nil

				local function CloseList()
					if not listOpen then return end
					listOpen = false
					RegisterPopupClose(CloseList)
					Tween(dropArrow, { Rotation = 0 }, SpiritUI.Theme.Fast)
					if listFrame then
						Tween(listFrame, { BackgroundTransparency = 1 }, 0.12)
						task.delay(0.14, function()
							if listFrame then listFrame:Destroy(); listFrame = nil end
							if listBdrop then listBdrop:Destroy(); listBdrop = nil end
						end)
					end
				end

				local function OpenList()
					if listOpen then CloseList() return end
					listOpen = true
					RegisterPopupOpen(CloseList)
					Tween(dropArrow, { Rotation = 180 }, SpiritUI.Theme.Fast)

					listBdrop = MakeBackdrop(CloseList)

					listFrame = Frame(SpiritUI._Root, {
						Name                 = "DropList",
						BackgroundColor3     = SpiritUI.Theme.Surface,
						BackgroundTransparency = 1,
						BorderSizePixel      = 0,
						Size                 = UDim2.fromOffset(140, math.min(#items * 28 + 8, 180)),
						ZIndex               = Z.Popup,
						ClipsDescendants     = true,
					})
					Corner(listFrame, SpiritUI.Theme.CornerMd)
					Stroke(listFrame, SpiritUI.Theme.Border, 1, 0.5)

					local absPos = dropBtn.AbsolutePosition
					local absSize = dropBtn.AbsoluteSize
					local vsize = ViewportSize()
					local listH = math.min(#items * 28 + 8, 180)
					local posY
					if absPos.Y + absSize.Y + listH + 4 < vsize.Y then
						posY = absPos.Y + absSize.Y + 4
					else
						posY = absPos.Y - listH - 4
					end
					listFrame.Position = UDim2.fromOffset(absPos.X, posY)

					local listScroll = Instance.new("ScrollingFrame")
					listScroll.BackgroundTransparency   = 1
					listScroll.BorderSizePixel           = 0
					listScroll.Size                      = UDim2.fromScale(1, 1)
					listScroll.ScrollBarThickness        = 0
					listScroll.ScrollBarImageTransparency = 1
					listScroll.CanvasSize                = UDim2.fromOffset(0, 0)
					listScroll.AutomaticCanvasSize       = Enum.AutomaticSize.Y
					listScroll.ZIndex                    = Z.Popup + 1
					listScroll.Parent                    = listFrame
					Pad(listScroll, 4, 4, 4, 4)
					ListLayout(listScroll, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top, 2)

					for _, item in ipairs(items) do
						local isSelected = multi and table.find(selected, item) ~= nil or selected == item
						local itemBtn = Instance.new("TextButton")
						itemBtn.Name               = "Item_" .. tostring(item)
						itemBtn.Text               = ""
						itemBtn.AutoButtonColor    = false
						itemBtn.BackgroundColor3   = SpiritUI.Theme.Accent
						itemBtn.BackgroundTransparency = isSelected and 0.85 or 1
						itemBtn.BorderSizePixel    = 0
						itemBtn.Size               = UDim2.new(1, 0, 0, 26)
						itemBtn.ZIndex             = Z.Popup + 2
						itemBtn.Parent             = listScroll
						Corner(itemBtn, SpiritUI.Theme.CornerSm)
						Pad(itemBtn, 0, 0, 8, 8)

						Label(itemBtn, {
							FontFace   = SpiritUI.Theme.FontRegular,
							Text       = tostring(item),
							TextColor3 = isSelected and SpiritUI.Theme.Text or SpiritUI.Theme.TextDim,
							TextSize   = 11,
							Size       = UDim2.fromScale(1, 1),
							ZIndex     = Z.Popup + 3,
						})

						itemBtn.MouseEnter:Connect(function()
							Tween(itemBtn, { BackgroundTransparency = 0.8 }, SpiritUI.Theme.Fast)
						end)
						itemBtn.MouseLeave:Connect(function()
							local sel = multi and table.find(selected, item) ~= nil or selected == item
							Tween(itemBtn, { BackgroundTransparency = sel and 0.85 or 1 }, SpiritUI.Theme.Fast)
						end)
						itemBtn.MouseButton1Click:Connect(function()
							if multi then
								local idx = table.find(selected, item)
								if idx then table.remove(selected, idx)
								else table.insert(selected, item) end
							else
								selected = item
								CloseList()
							end
							dropLabel.Text = GetDisplayText()
							if flag then SpiritUI.Flags[flag] = selected end
							task.spawn(cb, selected)
						end)
					end

					Tween(listFrame, { BackgroundTransparency = 0 }, 0.14)
				end

				dropBtn.MouseButton1Click:Connect(OpenList)
				dropBtn.MouseEnter:Connect(function()
					Tween(dropBtn, { BackgroundTransparency = 0.5 }, SpiritUI.Theme.Fast)
				end)
				dropBtn.MouseLeave:Connect(function()
					Tween(dropBtn, { BackgroundTransparency = 0 }, SpiritUI.Theme.Fast)
				end)

				local Drop_API = {}
				function Drop_API:Set(v)
					selected = v
					dropLabel.Text = GetDisplayText()
					if flag then SpiritUI.Flags[flag] = selected end
				end
				function Drop_API:Get() return selected end
				function Drop_API:SetItems(newItems)
					items = newItems
					if not multi and not table.find(items, selected) then
						selected = items[1] or ""
						dropLabel.Text = GetDisplayText()
					end
				end
				return Drop_API
			end

			-- ── TEXTBOX ─────────────────────────────
			function Section:AddTextbox(tOpts)
				tOpts = tOpts or {}
				local lbl     = tOpts.Title       or "Textbox"
				local desc    = tOpts.Description  or ""
				local def     = tOpts.Default      or ""
				local plc     = tOpts.Placeholder  or ""
				local flag    = tOpts.Flag
				local numeric = tOpts.Numeric      or false
				local cb      = tOpts.Callback     or function() end

				local value = def
				if flag and SpiritUI.Flags[flag] ~= nil then value = tostring(SpiritUI.Flags[flag]) end

				local row, rightSide = MakeRow(lbl, desc)

				local box = Instance.new("TextBox")
				box.Name                   = "Textbox"
				box.BackgroundColor3       = SpiritUI.Theme.SurfaceAlt
				box.BackgroundTransparency = 0
				box.BorderSizePixel        = 0
				box.FontFace               = SpiritUI.Theme.FontRegular
				box.TextColor3             = SpiritUI.Theme.Text
				box.PlaceholderColor3      = SpiritUI.Theme.TextFaint
				box.PlaceholderText        = plc
				box.Text                   = value
				box.TextSize               = 11
				box.ClearTextOnFocus       = false
				box.TextTruncate           = Enum.TextTruncate.AtEnd
				box.Size                   = UDim2.fromOffset(140, 24)
				box.ZIndex                 = Z.Content + 4
				box.Parent                 = rightSide
				Corner(box, SpiritUI.Theme.CornerSm)
				Stroke(box, SpiritUI.Theme.Border, 1, 0.5)
				Pad(box, 0, 0, 8, 8)

				local focusStroke = Stroke(box, SpiritUI.Theme.Accent, 1, 1)

				box.Focused:Connect(function()
					Tween(focusStroke, { Transparency = 0 }, SpiritUI.Theme.Fast)
				end)
				box.FocusLost:Connect(function(enterPressed)
					Tween(focusStroke, { Transparency = 1 }, SpiritUI.Theme.Fast)
					local v = box.Text
					if numeric then
						local n = tonumber(v)
						if not n then box.Text = value; return end
						v = tostring(n)
						box.Text = v
					end
					value = v
					if flag then SpiritUI.Flags[flag] = value end
					task.spawn(cb, value, enterPressed)
				end)

				local Box_API = {}
				function Box_API:Set(v) box.Text = tostring(v); value = tostring(v) end
				function Box_API:Get() return value end
				return Box_API
			end

			-- ── KEYBIND ─────────────────────────────
			function Section:AddKeybind(kOpts)
				kOpts = kOpts or {}
				local lbl    = kOpts.Title      or "Keybind"
				local desc   = kOpts.Description or ""
				local def    = kOpts.Default    or Enum.KeyCode.Unknown
				local flag   = kOpts.Flag
				local cb     = kOpts.Callback   or function() end
				local holdCb = kOpts.HoldCallback

				local boundKey = def
				if flag and SpiritUI.Flags[flag] ~= nil then
					boundKey = SpiritUI.Flags[flag]
				end

				local row, rightSide = MakeRow(lbl, desc)

				local kbBtn = Instance.new("TextButton")
				kbBtn.Name               = "KeybindBtn"
				kbBtn.AutoButtonColor    = false
				kbBtn.BackgroundColor3   = SpiritUI.Theme.SurfaceAlt
				kbBtn.BackgroundTransparency = 0
				kbBtn.BorderSizePixel    = 0
				kbBtn.FontFace           = SpiritUI.Theme.FontRegular
				kbBtn.TextColor3         = SpiritUI.Theme.Text
				kbBtn.TextSize           = 11
				kbBtn.Text               = boundKey == Enum.KeyCode.Unknown and "None" or boundKey.Name
				kbBtn.Size               = UDim2.fromOffset(80, 24)
				kbBtn.ZIndex             = Z.Content + 4
				kbBtn.Parent             = rightSide
				Corner(kbBtn, SpiritUI.Theme.CornerSm)
				Stroke(kbBtn, SpiritUI.Theme.Border, 1, 0.5)

				local listening  = false
				local listenStk  = Stroke(kbBtn, SpiritUI.Theme.Accent, 1, 1)

				kbBtn.MouseButton1Click:Connect(function()
					listening   = not listening
					kbBtn.Text  = listening and "..." or (boundKey == Enum.KeyCode.Unknown and "None" or boundKey.Name)
					Tween(listenStk, { Transparency = listening and 0 or 1 }, SpiritUI.Theme.Fast)
				end)

				winJanitor:Add(UserInputService.InputBegan:Connect(function(inp, gpe)
					if gpe then return end
					if listening then
						if inp.UserInputType == Enum.UserInputType.Keyboard then
							boundKey  = inp.KeyCode
							listening = false
							kbBtn.Text = boundKey == Enum.KeyCode.Unknown and "None" or boundKey.Name
							Tween(listenStk, { Transparency = 1 }, SpiritUI.Theme.Fast)
							if flag then SpiritUI.Flags[flag] = boundKey end
						end
					else
						if inp.UserInputType == Enum.UserInputType.Keyboard
							and inp.KeyCode == boundKey
							and boundKey ~= Enum.KeyCode.Unknown then
							task.spawn(cb)
						end
					end
				end))

				if holdCb then
					winJanitor:Add(UserInputService.InputEnded:Connect(function(inp)
						if inp.UserInputType == Enum.UserInputType.Keyboard
							and inp.KeyCode == boundKey
							and boundKey ~= Enum.KeyCode.Unknown then
							task.spawn(holdCb)
						end
					end))
				end

				local Kb_API = {}
				function Kb_API:Set(key)
					boundKey   = key
					kbBtn.Text = boundKey == Enum.KeyCode.Unknown and "None" or boundKey.Name
				end
				function Kb_API:Get() return boundKey end
				return Kb_API
			end

			-- ── COLOR PICKER ────────────────────────
			function Section:AddColorPicker(cOpts)
				cOpts = cOpts or {}
				local lbl  = cOpts.Title       or "Color"
				local desc = cOpts.Description  or ""
				local def  = cOpts.Default      or Color3.fromRGB(255, 100, 100)
				local flag = cOpts.Flag
				local cb   = cOpts.Callback    or function() end

				local color = def
				if flag and SpiritUI.Flags[flag] ~= nil then color = SpiritUI.Flags[flag] end

				local row, rightSide = MakeRow(lbl, desc)

				local preview = Frame(rightSide, {
					BackgroundColor3 = color,
					BackgroundTransparency = 0,
					Size             = UDim2.fromOffset(28, 20),
					ZIndex           = Z.Content + 4,
				})
				Corner(preview, SpiritUI.Theme.CornerSm)
				Stroke(preview, SpiritUI.Theme.Border, 1, 0.4)

				local pickerOpen = false
				local pickerFrame = nil
				local pickerBdrop = nil

				local function ClosePicker()
					if not pickerOpen then return end
					pickerOpen = false
					RegisterPopupClose(ClosePicker)
					if pickerFrame then pickerFrame:Destroy(); pickerFrame = nil end
					if pickerBdrop then pickerBdrop:Destroy(); pickerBdrop = nil end
				end

				local function OpenPicker()
					if pickerOpen then ClosePicker() return end
					pickerOpen = true
					RegisterPopupOpen(ClosePicker)
					pickerBdrop = MakeBackdrop(ClosePicker)

					local h, s, v2 = color:ToHSV()

					pickerFrame = Frame(SpiritUI._Root, {
						BackgroundColor3     = SpiritUI.Theme.Surface,
						BackgroundTransparency = 0,
						BorderSizePixel      = 0,
						Size                 = UDim2.fromOffset(200, 220),
						ZIndex               = Z.Popup,
					})
					Corner(pickerFrame, SpiritUI.Theme.CornerMd)
					Stroke(pickerFrame, SpiritUI.Theme.Border, 1, 0.4)
					Pad(pickerFrame, 10, 10, 10, 10)
					ListLayout(pickerFrame, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top, 8)

					local abs = preview.AbsolutePosition
					local vsize = ViewportSize()
					local px = math.min(abs.X, vsize.X - 210)
					local py = abs.Y + 24
					if py + 230 > vsize.Y then py = abs.Y - 230 end
					pickerFrame.Position = UDim2.fromOffset(px, py)

					-- SV panel
					local svPanel = Frame(pickerFrame, {
						BackgroundColor3     = Color3.fromHSV(h, 1, 1),
						BackgroundTransparency = 0,
						Size                 = UDim2.new(1, 0, 0, 120),
						ZIndex               = Z.Popup + 1,
						ClipsDescendants     = true,
					})
					Corner(svPanel, SpiritUI.Theme.CornerSm)

					local grad1 = Instance.new("UIGradient")
					grad1.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
						ColorSequenceKeypoint.new(1, Color3.new(1,1,1)),
					})
					grad1.Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0),
						NumberSequenceKeypoint.new(1, 1),
					})
					grad1.Parent = svPanel

					local svOverlay = Frame(svPanel, {
						BackgroundColor3     = Color3.new(0,0,0),
						BackgroundTransparency = 0,
						Size                 = UDim2.fromScale(1, 1),
						ZIndex               = Z.Popup + 2,
					})
					Corner(svOverlay, SpiritUI.Theme.CornerSm)
					local grad2 = Instance.new("UIGradient")
					grad2.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.new(0,0,0)),
						ColorSequenceKeypoint.new(1, Color3.new(0,0,0)),
					})
					grad2.Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(1, 0),
					})
					grad2.Rotation = 90
					grad2.Parent = svOverlay

					local svCursor = Frame(svPanel, {
						BackgroundColor3     = Color3.new(1,1,1),
						BackgroundTransparency = 0,
						AnchorPoint          = Vector2.new(0.5, 0.5),
						Position             = UDim2.new(s, 0, 1 - v2, 0),
						Size                 = UDim2.fromOffset(10, 10),
						ZIndex               = Z.Popup + 3,
					})
					Corner(svCursor, 5)
					Stroke(svCursor, SpiritUI.Theme.Background, 2, 0)

					-- hue bar
					local hueBar = Frame(pickerFrame, {
						BackgroundColor3     = Color3.new(1,1,1),
						BackgroundTransparency = 0,
						Size                 = UDim2.new(1, 0, 0, 12),
						ZIndex               = Z.Popup + 1,
						ClipsDescendants     = true,
					})
					Corner(hueBar, 4)
					local hueGrad = Instance.new("UIGradient")
					hueGrad.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0/6, Color3.fromHSV(0/6, 1, 1)),
						ColorSequenceKeypoint.new(1/6, Color3.fromHSV(1/6, 1, 1)),
						ColorSequenceKeypoint.new(2/6, Color3.fromHSV(2/6, 1, 1)),
						ColorSequenceKeypoint.new(3/6, Color3.fromHSV(3/6, 1, 1)),
						ColorSequenceKeypoint.new(4/6, Color3.fromHSV(4/6, 1, 1)),
						ColorSequenceKeypoint.new(5/6, Color3.fromHSV(5/6, 1, 1)),
						ColorSequenceKeypoint.new(6/6, Color3.fromHSV(6/6, 1, 1)),
					})
					hueGrad.Parent = hueBar

					local hueCursor = Frame(hueBar, {
						BackgroundColor3     = Color3.new(1,1,1),
						BackgroundTransparency = 0,
						AnchorPoint          = Vector2.new(0.5, 0.5),
						Position             = UDim2.new(h, 0, 0.5, 0),
						Size                 = UDim2.fromOffset(6, 14),
						ZIndex               = Z.Popup + 2,
					})
					Corner(hueCursor, 2)
					Stroke(hueCursor, SpiritUI.Theme.Background, 1.5, 0)

					-- hex input
					local hexRow = Frame(pickerFrame, {
						AutomaticSize = Enum.AutomaticSize.Y,
						Size          = UDim2.new(1, 0, 0, 0),
						ZIndex        = Z.Popup + 1,
					})
					ListLayout(hexRow, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center, 8)

					local hexBox = Instance.new("TextBox")
					hexBox.BackgroundColor3       = SpiritUI.Theme.SurfaceAlt
					hexBox.BackgroundTransparency = 0
					hexBox.BorderSizePixel        = 0
					hexBox.FontFace               = SpiritUI.Theme.FontRegular
					hexBox.TextColor3             = SpiritUI.Theme.Text
					hexBox.PlaceholderText        = "RRGGBB"
					hexBox.TextSize               = 11
					hexBox.ClearTextOnFocus       = false
					hexBox.Size                   = UDim2.fromOffset(120, 24)
					hexBox.ZIndex                 = Z.Popup + 2
					hexBox.Parent                 = hexRow
					Corner(hexBox, SpiritUI.Theme.CornerSm)
					Stroke(hexBox, SpiritUI.Theme.Border, 1, 0.5)
					Pad(hexBox, 0, 0, 8, 8)

					local previewSmall = Frame(hexRow, {
						BackgroundColor3     = color,
						BackgroundTransparency = 0,
						Size                 = UDim2.fromOffset(24, 24),
						ZIndex               = Z.Popup + 2,
					})
					Corner(previewSmall, SpiritUI.Theme.CornerSm)

					local function RGBToHex(c)
						return string.format("%02X%02X%02X",
							math.floor(c.R * 255 + 0.5),
							math.floor(c.G * 255 + 0.5),
							math.floor(c.B * 255 + 0.5))
					end

					local function ApplyColor(nh, ns, nv)
						h, s, v2 = nh, ns, nv
						color = Color3.fromHSV(h, s, v2)
						preview.BackgroundColor3       = color
						previewSmall.BackgroundColor3  = color
						svPanel.BackgroundColor3       = Color3.fromHSV(h, 1, 1)
						svCursor.Position              = UDim2.new(s, 0, 1 - v2, 0)
						hueCursor.Position             = UDim2.new(h, 0, 0.5, 0)
						hexBox.Text                    = RGBToHex(color)
						if flag then SpiritUI.Flags[flag] = color end
						task.spawn(cb, color)
					end

					hexBox.Text = RGBToHex(color)

					local svDragging  = false
					local hueDragging = false

					svPanel.InputBegan:Connect(function(inp)
						if inp.UserInputType == Enum.UserInputType.MouseButton1
							or inp.UserInputType == Enum.UserInputType.Touch then
							svDragging = true
							local ns = SafeAlpha(inp.Position.X, svPanel.AbsolutePosition.X, svPanel.AbsolutePosition.X + svPanel.AbsoluteSize.X)
							local nv = 1 - SafeAlpha(inp.Position.Y, svPanel.AbsolutePosition.Y, svPanel.AbsolutePosition.Y + svPanel.AbsoluteSize.Y)
							ApplyColor(h, ns, nv)
						end
					end)

					hueBar.InputBegan:Connect(function(inp)
						if inp.UserInputType == Enum.UserInputType.MouseButton1
							or inp.UserInputType == Enum.UserInputType.Touch then
							hueDragging = true
							local nh = SafeAlpha(inp.Position.X, hueBar.AbsolutePosition.X, hueBar.AbsolutePosition.X + hueBar.AbsoluteSize.X)
							ApplyColor(nh, s, v2)
						end
					end)

					winJanitor:Add(UserInputService.InputChanged:Connect(function(inp)
						if inp.UserInputType ~= Enum.UserInputType.MouseMovement
							and inp.UserInputType ~= Enum.UserInputType.Touch then return end
						if svDragging then
							local ns = SafeAlpha(inp.Position.X, svPanel.AbsolutePosition.X, svPanel.AbsolutePosition.X + svPanel.AbsoluteSize.X)
							local nv = 1 - SafeAlpha(inp.Position.Y, svPanel.AbsolutePosition.Y, svPanel.AbsolutePosition.Y + svPanel.AbsoluteSize.Y)
							ApplyColor(h, ns, nv)
						elseif hueDragging then
							local nh = SafeAlpha(inp.Position.X, hueBar.AbsolutePosition.X, hueBar.AbsolutePosition.X + hueBar.AbsoluteSize.X)
							ApplyColor(nh, s, v2)
						end
					end))

					winJanitor:Add(UserInputService.InputEnded:Connect(function(inp)
						if inp.UserInputType == Enum.UserInputType.MouseButton1
							or inp.UserInputType == Enum.UserInputType.Touch then
							svDragging = false; hueDragging = false
						end
					end))

					hexBox.FocusLost:Connect(function()
						local hex = hexBox.Text:gsub("[^%x]", ""):sub(1, 6)
						if #hex == 6 then
							local r = tonumber(hex:sub(1,2), 16) / 255
							local g = tonumber(hex:sub(3,4), 16) / 255
							local b = tonumber(hex:sub(5,6), 16) / 255
							local nh, ns, nv = Color3.new(r,g,b):ToHSV()
							ApplyColor(nh, ns, nv)
						else
							hexBox.Text = RGBToHex(color)
						end
					end)
				end

				local btn3 = Instance.new("TextButton")
				btn3.Name              = "ColorBtn"
				btn3.Text              = ""
				btn3.AutoButtonColor   = false
				btn3.BackgroundColor3  = Color3.new(0,0,0)
				btn3.BackgroundTransparency = 1
				btn3.BorderSizePixel   = 0
				btn3.Size              = UDim2.fromScale(1,1)
				btn3.ZIndex            = Z.Content + 5
				btn3.Parent            = preview
				btn3.MouseButton1Click:Connect(OpenPicker)

				local Color_API = {}
				function Color_API:Set(c)
					color = c
					preview.BackgroundColor3 = c
					if flag then SpiritUI.Flags[flag] = c end
				end
				function Color_API:Get() return color end
				return Color_API
			end

			-- ── LABEL ───────────────────────────────
			function Section:AddLabel(text)
				Label(sectionFrame, {
					FontFace   = SpiritUI.Theme.FontRegular,
					Text       = tostring(text or ""),
					TextColor3 = SpiritUI.Theme.TextDim,
					TextSize   = 11,
					TextWrapped = true,
					AutomaticSize = Enum.AutomaticSize.Y,
					Size       = UDim2.new(1, 0, 0, 11),
					ZIndex     = Z.Content + 2,
				})
			end

			-- ── SEPARATOR ───────────────────────────
			function Section:AddSeparator()
				Frame(sectionFrame, {
					BackgroundColor3     = SpiritUI.Theme.Border,
					BackgroundTransparency = 0,
					Size                 = UDim2.new(1, 0, 0, 1),
					ZIndex               = Z.Content + 2,
				})
			end

			return Section
		end

		return Tab
	end

	return Window
end

-- ══════════════════════════════════════════════════
--  CONFIG SAVE / LOAD
-- ══════════════════════════════════════════════════
function SpiritUI:SaveConfig(name)
	name = SafeConfigName(name or "default")
	local path = ASSETS .. "/" .. name .. ".json"
	local ok, data = pcall(function()
		return HttpService:JSONEncode(SpiritUI.Flags)
	end)
	if not ok then return false end
	return WriteFile(path, data)
end

function SpiritUI:LoadConfig(name)
	name = SafeConfigName(name or "default")
	local path = ASSETS .. "/" .. name .. ".json"
	local data = ReadFile(path)
	if not data then return false end
	local ok, decoded = pcall(function() return HttpService:JSONDecode(data) end)
	if not ok or type(decoded) ~= "table" then return false end
	for k, v in pairs(decoded) do
		SpiritUI.Flags[k] = v
	end
	return true
end

function SpiritUI:ListConfigs()
	if not fn_listfiles then return {} end
	local ok, files = pcall(fn_listfiles, ASSETS)
	if not ok then return {} end
	local out = {}
	for _, f in ipairs(files) do
		local name = f:match("([^/\\]+)%.json$")
		if name then table.insert(out, name) end
	end
	return out
end

-- ══════════════════════════════════════════════════
--  UNLOAD
-- ══════════════════════════════════════════════════
local function DestroyAllWindows()
	for _, w in ipairs(SpiritUI._Windows) do
		w._destroyed = true
		if w._janitor then w._janitor:Destroy() end
	end
	table.clear(SpiritUI._Windows)
end

SpiritUI._Root.Destroying:Connect(function()
	AcrylicOff = true
	DestroyAllWindows()
	DestroyAllAcrylic()
	LibJanitor:Destroy()
end)

function SpiritUI:Unload()
	ClosePopup()
	AcrylicOff = true
	DestroyAllWindows()
	DestroyAllAcrylic()
	LibJanitor:Destroy()
	if SpiritUI._Root then SpiritUI._Root:Destroy() end
end

do
	local env = GetGlobalEnv()
	env.__SpiritUI_Unload = function()
		pcall(function() SpiritUI:Unload() end)
	end
end

return SpiritUI
