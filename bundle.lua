--[[
 /$$$$$$$$           /$$                     /$$          
|_____ $$           | $$                    |__/          
     /$$/   /$$$$$$ | $$  /$$$$$$   /$$$$$$  /$$  /$$$$$$$
    /$$/   /$$__  $$| $$ |____  $$ /$$__  $$| $$ /$$_____/
   /$$/   | $$   $$| $$  /$$$$$$$| $$  __/| $$|  $$$$$$ 
  /$$/    | $$  | $$| $$ /$$__  $$| $$      | $$ ____  $$
 /$$$$$$$$|  $$$$$$/| $$|  $$$$$$$| $$      | $$ /$$$$$$$/  @QMX
|________/ ______/ |__/ _______/|__/      |__/|_______/ 
                                                        
]]--
-- Bundled/Compiled By Zolaris


local __modules = {}
local __cache = {}

local function __require(name)
	local cached = __cache[name]
	if cached ~= nil then
		return cached
	end
	local factory = __modules[name]
	if not factory then
		error("Zolaris bundle: missing module " .. name)
	end
	local module = factory()
	__cache[name] = module
	return module
end

-- ===== Client.lua =====
__modules["Client"] = function()
	--[[
		Zolaris-Client :: Client
		Builds the whole panel and owns the runtime behaviour:
		window chrome, sidebar navigation, feature pages, toasts and hotkeys.
	]]

	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local GuiService = game:GetService("GuiService")

	local Theme = __require("Theme")
	local UIKit = __require("UIKit")
	local Icons = __require("Icons")
	local Config = __require("Config")
	local Effects = __require("Effects")
	local Registry = __require("Registry")

	local Client = {}

	local TABS = {
		{ Key = "Home", Icon = "home" },
		{ Key = "Favorites", Icon = "star" },
		{ Key = "Combat", Icon = "crosshair" },
		{ Key = "Render", Icon = "eye" },
		{ Key = "Utility", Icon = "bolt" },
		{ Key = "Leaderboards", Icon = "bars" },
		{ Key = "Settings", Icon = "gear" },
	}

	local state = {
		gui = nil,
		root = nil,
		shell = nil,
		window = nil,
		sidebar = nil,
		content = nil,
		titleLabel = nil,
		fpsValue = nil,
		moduleLabel = nil,
		tierLabel = nil,
		tierButton = nil,
		searchBox = nil,
		searchCount = nil,
		searchStroke = nil,
		errorDot = nil,
		activityDot = nil,
		connectionDot = nil,
		pages = {},
		tabButtons = {},
		tabOrder = {},
		tabList = nil,
		toastContainer = nil,
		toasts = {},
		restorePill = nil,
		currentTab = "Home",
		scale = 1,
		dragOffset = Vector2.zero,
		accentBinders = {},
		playerRows = {},
		statLabels = {},
		initialized = false,
	}

	local FONT_BODY = Theme.Fonts.Regular
	local FONT_MEDIUM = Theme.Fonts.Medium
	local FONT_SEMI = Theme.Fonts.SemiBold
	local FONT_BOLD = Theme.Fonts.Bold

	local function indexOf(list, value)
		for index, entry in ipairs(list) do
			if entry == value then
				return index
			end
		end
		return nil
	end

	local function clearList(list)
		for index = #list, 1, -1 do
			list[index] = nil
		end
	end

	local function bindAccent(binder)
		table.insert(state.accentBinders, binder)
	end

	local function applyAccent(color)
		Theme.Colors.Accent = color
		Theme.Colors.AccentLight = color:Lerp(Color3.fromRGB(255, 255, 255), 0.28)
		Theme.Colors.AccentSoft = color:Lerp(Color3.fromRGB(255, 255, 255), 0.52)
		Theme.Colors.AccentDeep = color:Lerp(Color3.fromRGB(0, 0, 0), 0.2)
		for _, binder in ipairs(state.accentBinders) do
			pcall(binder, color)
		end
	end

	local function isInteractiveObject(object)
		if object:IsA("TextButton") or object:IsA("TextBox") then
			return true
		end
		local name = object.Name
		return name == "Toggle" or name == "Knob" or name == "Slider" or name == "Track"
	end

	local function isInteractiveAt(position)
		local ok, objects = pcall(function()
			return GuiService:GetGuiObjectsAtPosition(position.X, position.Y)
		end)
		if not ok or type(objects) ~= "table" then
			return false
		end
		for _, object in ipairs(objects) do
			if isInteractiveObject(object) then
				return true
			end
		end
		return false
	end

	local function tween(object, goals, duration)
		local enabled = Config.GetSetting("animations") ~= false
		UIKit.tween(object, goals, enabled and (duration or 0.18) or 0)
	end

	local function flashDot(dot, color)
		if not dot then
			return
		end
		dot.BackgroundColor3 = color
		task.delay(0.9, function()
			if dot and dot.Parent then
				tween(dot, { BackgroundColor3 = Theme.Colors.Glass }, 0.3)
			end
		end)
	end

	function Client.Notify(text, kind)
		if not state.toastContainer then
			return
		end
		local color = Theme.Colors.AccentLight
		local iconName = "check"
		if kind == "error" then
			color = Theme.Colors.Danger
			iconName = "close"
		elseif kind == "warn" then
			color = Theme.Colors.Warning
			iconName = "shield"
		elseif kind == "info" then
			color = Theme.Colors.AccentSoft
			iconName = "sparkles"
		end

		local toast = UIKit.frame(state.toastContainer, {
			Name = "Toast",
			Size = UDim2.fromOffset(300, 36),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			BackgroundColor3 = Theme.Colors.Panel,
			BackgroundTransparency = 0.05,
			CornerRadius = 9,
			Stroke = { Color = color, Transparency = 0.55, Thickness = 1 },
			ZIndex = 30,
		})

		local icon = UIKit.icon(toast, iconName, 14, color)
		icon.Position = UDim2.fromOffset(13, 11)

		UIKit.label(toast, {
			Name = "Text",
			Text = text,
			TextSize = 10,
			TextColor3 = Theme.Colors.TextPrimary,
			Font = FONT_MEDIUM,
			Position = UDim2.fromOffset(36, 8),
			Size = UDim2.fromOffset(252, 20),
			ZIndex = 31,
		})

		table.insert(state.toasts, toast)
		local function restack()
			for index, entry in ipairs(state.toasts) do
				entry.Position = UDim2.new(0.5, 0, 1, -(index - 1) * 42)
			end
		end
		restack()

		UIKit.fade(toast, 0, 0.18)

		task.delay(2.4, function()
			if not toast.Parent then
				return
			end
			UIKit.fade(toast, 1, 0.28)
			tween(toast, { Position = UDim2.new(0.5, 0, 1, 14) }, 0.28)
			task.delay(0.34, function()
				local index = indexOf(state.toasts, toast)
				if index then
					table.remove(state.toasts, index)
				end
				if toast.Parent then
					toast:Destroy()
				end
				restack()
			end)
		end)
	end

	local function buildWindow()
		local gui = Instance.new("ScreenGui")
		gui.Name = "ZolarisClient"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = false
		gui.DisplayOrder = 100
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		state.gui = gui

		local root = UIKit.frame(gui, {
			Name = "Root",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 1,
		})
		state.root = root

		local shell = UIKit.frame(root, {
			Name = "Shell",
			Size = UDim2.fromOffset(Theme.Window.Width, Theme.Window.Height),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 1,
		})
		state.shell = shell

		local scaleInstance = Instance.new("UIScale")
		scaleInstance.Scale = 1
		scaleInstance.Parent = shell
		state.scaleInstance = scaleInstance

		local shadow = UIKit.frame(shell, {
			Name = "Shadow",
			Size = UDim2.fromOffset(Theme.Window.Width, Theme.Window.Height),
			Position = UDim2.fromOffset(0, Theme.Window.ShadowOffset),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.55,
			CornerRadius = Theme.Window.Radius + 2,
			ZIndex = 1,
		})
		state.shadow = shadow

		local window = UIKit.frame(shell, {
			Name = "Window",
			Size = UDim2.fromOffset(Theme.Window.Width, Theme.Window.Height),
			BackgroundColor3 = Theme.Colors.WindowTop,
			CornerRadius = Theme.Window.Radius,
			ClipsDescendants = true,
			ZIndex = 2,
		})
		state.window = window

		UIKit.gradient(window, Theme.Colors.WindowTop, Theme.Colors.WindowBottom, 90)

		local mid = UIKit.gradient(window, Theme.Colors.WindowMid, Theme.Colors.WindowMid, 90)
		mid.Offset = Vector2.new(0, 0.42)
		mid.Name = "MidGradient"

		UIKit.glow(window, {
			Name = "GlowRight",
			Size = UDim2.fromOffset(420, 340),
			Position = UDim2.fromOffset(556, 252),
			Color = Theme.Colors.Accent,
			InnerTransparency = 0.82,
			OuterTransparency = 0.99,
			BaseSize = 90,
			Step = 14,
			ZIndex = 1,
		})

		UIKit.glow(window, {
			Name = "GlowTop",
			Size = UDim2.fromOffset(400, 300),
			Position = UDim2.fromOffset(520, -180),
			Color = Theme.Colors.Accent,
			InnerTransparency = 0.86,
			OuterTransparency = 0.99,
			BaseSize = 80,
			Step = 12,
			ZIndex = 1,
		})

		UIKit.glow(window, {
			Name = "GlowLeft",
			Size = UDim2.fromOffset(420, 380),
			Position = UDim2.fromOffset(120, -140),
			Color = Theme.Colors.Accent,
			InnerTransparency = 0.84,
			OuterTransparency = 0.99,
			BaseSize = 90,
			Step = 13,
			ZIndex = 1,
		})

		return window
	end

	local function layoutTabs()
		local count = #state.tabOrder
		if count == 0 then
			return
		end
		local pitch = Theme.Sizes.TabGap
		if count > 1 then
			local available = 300 - Theme.Sizes.TabHeight
			pitch = math.min(Theme.Sizes.TabGap, math.floor(available / (count - 1)))
		end
		for index, key in ipairs(state.tabOrder) do
			local entry = state.tabButtons[key]
			if entry then
				entry.button.Position = UDim2.fromOffset(0, (index - 1) * pitch)
			end
		end
	end

	local function addTabButton(key, iconName)
		local button = UIKit.button(state.tabList, {
			Name = "Tab_" .. key,
			Size = UDim2.fromOffset(166, Theme.Sizes.TabHeight),
			Position = UDim2.fromOffset(0, 0),
			BackgroundColor3 = Theme.Colors.Glass,
			BackgroundTransparency = 1,
			Text = "",
			CornerRadius = 8,
			ZIndex = 4,
		})

		local gradient = UIKit.gradient(button, Theme.Colors.TabActiveTop, Theme.Colors.TabActiveBottom, 90)
		gradient.Transparency = NumberSequence.new(1)
		bindAccent(function(color)
			gradient.Color = ColorSequence.new(color, color:Lerp(Color3.fromRGB(0, 0, 0), 0.2))
		end)

		local icon = UIKit.icon(button, iconName or "sparkles", Theme.Sizes.TabIcon, Theme.Colors.TextDim)
		icon.Position = UDim2.fromOffset(11, 10)

		local label = UIKit.label(button, {
			Name = "Label",
			Text = key,
			TextSize = Theme.Text.TabLabel,
			Font = FONT_MEDIUM,
			TextColor3 = Theme.Colors.TextSecondary,
			Position = UDim2.fromOffset(34, 8),
			Size = UDim2.fromOffset(120, 18),
			ZIndex = 5,
		})

		state.tabButtons[key] = { button = button, icon = icon, label = label, gradient = gradient }

		button.MouseButton1Click:Connect(function()
			Client.SetTab(key)
		end)

		UIKit.hover(button, function()
			if state.currentTab ~= key then
				tween(button, { BackgroundTransparency = 0.93 }, 0.15)
			end
		end, function()
			if state.currentTab ~= key then
				tween(button, { BackgroundTransparency = 1 }, 0.15)
			end
		end)

		return button
	end

	local function buildSidebar(window)
		local sidebar = UIKit.frame(window, {
			Name = "Sidebar",
			Size = UDim2.fromOffset(Theme.Sidebar.Width, Theme.Sidebar.Height),
			Position = UDim2.fromOffset(Theme.Sidebar.Offset, Theme.Sidebar.Offset),
			BackgroundColor3 = Theme.Colors.SidebarTop,
			BackgroundTransparency = 0.12,
			CornerRadius = Theme.Sidebar.Radius,
			Stroke = { Color = Theme.Colors.Glass, Transparency = 0.9, Thickness = 1 },
			ZIndex = 3,
		})
		UIKit.gradient(sidebar, Theme.Colors.SidebarTop, Theme.Colors.SidebarBottom, 90)
		state.sidebar = sidebar

		local logoBox = UIKit.frame(sidebar, {
			Name = "Logo",
			Size = UDim2.fromOffset(Theme.Sizes.LogoBox, Theme.Sizes.LogoBox),
			Position = UDim2.fromOffset(16, 16),
			BackgroundColor3 = Theme.Colors.LogoTop,
			CornerRadius = 10,
			ZIndex = 4,
		})
		local logoGradient = UIKit.gradient(logoBox, Theme.Colors.LogoTop, Theme.Colors.LogoBottom, 90)
		bindAccent(function(color)
			logoGradient.Color = ColorSequence.new(color:Lerp(Color3.fromRGB(255, 255, 255), 0.52), color:Lerp(Color3.fromRGB(0, 0, 0), 0.1))
		end)

		local logoIcon = UIKit.icon(logoBox, "logo", 20, Theme.Colors.Glass)
		logoIcon.Position = UDim2.fromOffset(9, 9)

		UIKit.label(sidebar, {
			Name = "BrandTitle",
			Text = "Zolaris-Client",
			TextSize = Theme.Text.BrandTitle,
			Font = FONT_BOLD,
			TextColor3 = Theme.Colors.TextPrimary,
			Position = UDim2.fromOffset(62, 12),
			Size = UDim2.fromOffset(120, 22),
			ZIndex = 4,
		})

		UIKit.label(sidebar, {
			Name = "BrandSubtitle",
			Text = "Pre-release",
			TextSize = Theme.Text.BrandSubtitle,
			Font = FONT_SEMI,
			TextColor3 = Theme.Colors.AccentLight,
			Position = UDim2.fromOffset(63, 33),
			Size = UDim2.fromOffset(80, 12),
			ZIndex = 4,
		})

		local search = UIKit.frame(sidebar, {
			Name = "Search",
			Size = UDim2.fromOffset(166, Theme.Sizes.SearchHeight),
			Position = UDim2.fromOffset(12, 70),
			BackgroundColor3 = Theme.Colors.SearchBg,
			BackgroundTransparency = 0.55,
			CornerRadius = 8,
			ZIndex = 4,
		})
		local searchStroke = UIKit.stroke(search, Theme.Colors.Glass, 0.94, 1)
		state.searchStroke = searchStroke

		local searchIcon = UIKit.icon(search, "search", 14, Theme.Colors.TextDim)
		searchIcon.Position = UDim2.fromOffset(11, 9)

		local searchBox = UIKit.textbox(search, {
			Name = "SearchBox",
			Text = "",
			PlaceholderText = "Search...",
			PlaceholderColor3 = Theme.Colors.TextDim,
			TextColor3 = Theme.Colors.TextSecondary,
			TextSize = Theme.Text.Search,
			Font = FONT_BODY,
			Position = UDim2.fromOffset(33, 6),
			Size = UDim2.fromOffset(88, 20),
			ZIndex = 5,
		})
		state.searchBox = searchBox

		local count = UIKit.label(search, {
			Name = "Count",
			Text = "",
			TextSize = 9,
			Font = FONT_SEMI,
			TextColor3 = Theme.Colors.AccentLight,
			Position = UDim2.fromOffset(120, 6),
			Size = UDim2.fromOffset(34, 20),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 5,
		})
		state.searchCount = count

		searchBox.Focused:Connect(function()
			tween(search, { BackgroundTransparency = 0.35 }, 0.15)
			tween(searchStroke, { Color = Theme.Colors.Accent }, 0.15)
		end)
		searchBox.FocusLost:Connect(function()
			tween(search, { BackgroundTransparency = 0.55 }, 0.15)
			tween(searchStroke, { Color = Theme.Colors.Glass }, 0.15)
		end)

		local tabList = UIKit.frame(sidebar, {
			Name = "TabList",
			Size = UDim2.fromOffset(166, 300),
			Position = UDim2.fromOffset(12, 118),
			BackgroundTransparency = 1,
			ZIndex = 4,
		})
		state.tabList = tabList

		for _, tab in ipairs(TABS) do
			table.insert(state.tabOrder, tab.Key)
			addTabButton(tab.Key, tab.Icon)
		end
		layoutTabs()

		local config = UIKit.frame(sidebar, {
			Name = "ConfigCard",
			Size = UDim2.fromOffset(166, 73),
			Position = UDim2.fromOffset(12, 428),
			BackgroundColor3 = Theme.Colors.Panel,
			BackgroundTransparency = 0.55,
			CornerRadius = 8,
			ZIndex = 4,
		})

		UIKit.label(config, {
			Name = "ConfigLabel",
			Text = "CLIENT CONFIG",
			TextSize = Theme.Text.ConfigLabel,
			Font = FONT_BOLD,
			TextColor3 = Theme.Colors.TextDim,
			Position = UDim2.fromOffset(12, 10),
			Size = UDim2.fromOffset(90, 11),
			ZIndex = 5,
		})

		local tier = UIKit.button(config, {
			Name = "Tier",
			Text = "Non-Premium",
			TextSize = Theme.Text.ConfigTier,
			Font = FONT_SEMI,
			TextColor3 = Theme.Colors.TextPrimary,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 24),
			Size = UDim2.fromOffset(110, 17),
			ZIndex = 5,
		})
		state.tierLabel = tier
		tier.MouseButton1Click:Connect(function()
			local premium = not Config.GetSetting("premium")
			Config.SetSetting("premium", premium)
			tier.Text = premium and "Premium" or "Non-Premium"
			tier.TextColor3 = premium and Theme.Colors.AccentLight or Theme.Colors.TextPrimary
			Config.Save()
			Client.Notify(premium and "Premium tier enabled" or "Premium tier disabled", premium and "success" or "info")
		end)

		local modules = UIKit.label(config, {
			Name = "Modules",
			Text = "0 Modules",
			TextSize = Theme.Text.ConfigMeta,
			Font = FONT_BODY,
			TextColor3 = Theme.Colors.TextDim,
			Position = UDim2.fromOffset(12, 48),
			Size = UDim2.fromOffset(80, 13),
			ZIndex = 5,
		})
		state.moduleLabel = modules

		local reset = UIKit.button(config, {
			Name = "ResetAll",
			Text = "Reset All",
			TextSize = Theme.Text.ConfigMeta,
			Font = FONT_SEMI,
			TextColor3 = Theme.Colors.Danger,
			TextXAlignment = Enum.TextXAlignment.Right,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(112, 47),
			Size = UDim2.fromOffset(42, 14),
			ZIndex = 5,
		})
		reset.MouseButton1Click:Connect(function()
			Client.ResetAll()
		end)

		return sidebar
	end

	local function buildHeader(window)
		local title = UIKit.label(window, {
			Name = "PageTitle",
			Text = "Home",
			TextSize = Theme.Text.WindowTitle,
			Font = FONT_BOLD,
			TextColor3 = Theme.Colors.TextPrimary,
			Position = UDim2.fromOffset(Theme.Content.OffsetX, 26),
			Size = UDim2.fromOffset(320, 30),
			ZIndex = 4,
		})
		state.titleLabel = title

		local fpsPill = UIKit.frame(window, {
			Name = "FpsPill",
			Size = UDim2.fromOffset(Theme.Sizes.FpsPillWidth, Theme.Sizes.FpsPillHeight),
			Position = UDim2.fromOffset(Theme.Window.Width - Theme.Sizes.WindowControlWidth - Theme.Sizes.FpsPillWidth - 12, 19),
			BackgroundColor3 = Theme.Colors.SidebarTop,
			BackgroundTransparency = 0.12,
			CornerRadius = 10,
			Stroke = { Color = Theme.Colors.Glass, Transparency = 0.9, Thickness = 1 },
			ZIndex = 4,
		})
		UIKit.gradient(fpsPill, Theme.Colors.SidebarTop, Theme.Colors.SidebarBottom, 90)

		UIKit.label(fpsPill, {
			Name = "FpsLabel",
			Text = "FPS:",
			TextSize = Theme.Text.Fps,
			Font = FONT_BODY,
			TextColor3 = Theme.Colors.TextDim,
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.fromOffset(26, 15),
			ZIndex = 5,
		})

		local fpsValue = UIKit.label(fpsPill, {
			Name = "FpsValue",
			Text = "0",
			TextSize = Theme.Text.FpsValue,
			Font = FONT_SEMI,
			TextColor3 = Theme.Colors.TextPrimary,
			Position = UDim2.fromOffset(38, 8),
			Size = UDim2.fromOffset(34, 15),
			ZIndex = 5,
		})
		state.fpsValue = fpsValue

		local function statusDot(x, color)
			local holder = UIKit.frame(fpsPill, {
				Size = UDim2.fromOffset(9, 9),
				Position = UDim2.fromOffset(x, 11),
				BackgroundColor3 = color,
				CornerRadius = 5,
				ZIndex = 5,
			})
			UIKit.glow(holder, {
				Size = UDim2.fromOffset(22, 22),
				Position = UDim2.fromOffset(-7, -7),
				Color = color,
				InnerTransparency = 0.5,
				OuterTransparency = 1,
				BaseSize = 8,
				Step = 3,
				ZIndex = 4,
			})
			return holder
		end

		state.errorDot = statusDot(94, Theme.Colors.Glass)
		state.activityDot = statusDot(112, Theme.Colors.Glass)
		state.connectionDot = statusDot(130, Theme.Colors.Glass)
		state.connectionDot.BackgroundColor3 = Theme.Colors.Success

		local controls = UIKit.frame(window, {
			Name = "WindowControls",
			Size = UDim2.fromOffset(Theme.Sizes.WindowControlWidth, Theme.Sizes.WindowControlHeight),
			Position = UDim2.fromOffset(Theme.Window.Width - Theme.Sizes.WindowControlWidth - 4, 19),
			BackgroundColor3 = Theme.Colors.SidebarTop,
			BackgroundTransparency = 0.12,
			CornerRadius = 10,
			Stroke = { Color = Theme.Colors.Glass, Transparency = 0.9, Thickness = 1 },
			ZIndex = 4,
		})
		UIKit.gradient(controls, Theme.Colors.SidebarTop, Theme.Colors.SidebarBottom, 90)

		local minimize = UIKit.button(controls, {
			Name = "Minimize",
			Size = UDim2.fromOffset(40, 23),
			Position = UDim2.fromOffset(4, 4),
			BackgroundTransparency = 1,
			Text = "",
			CornerRadius = 7,
			ZIndex = 5,
		})
		local minimizeIcon = UIKit.icon(minimize, "minimize", 14, Theme.Colors.TextSecondary)
		minimizeIcon.Position = UDim2.fromOffset(13, 5)
		minimize.MouseButton1Click:Connect(function()
			Client.Minimize()
		end)
		UIKit.hover(minimize, function()
			Icons.SetColor(minimizeIcon, Theme.Colors.TextPrimary)
		end, function()
			Icons.SetColor(minimizeIcon, Theme.Colors.TextSecondary)
		end)

		local close = UIKit.button(controls, {
			Name = "Close",
			Size = UDim2.fromOffset(40, 23),
			Position = UDim2.fromOffset(48, 4),
			BackgroundTransparency = 1,
			Text = "",
			CornerRadius = 7,
			ZIndex = 5,
		})
		local closeIcon = UIKit.icon(close, "close", 14, Theme.Colors.TextSecondary)
		closeIcon.Position = UDim2.fromOffset(13, 5)
		close.MouseButton1Click:Connect(function()
			Client.Toggle(false)
		end)
		UIKit.hover(close, function()
			Icons.SetColor(closeIcon, Theme.Colors.Danger)
		end, function()
			Icons.SetColor(closeIcon, Theme.Colors.TextSecondary)
		end)
	end

	local function createPage(key)
		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "Page_" .. key
		scroll.Size = UDim2.fromScale(1, 1)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollingDirection = Enum.ScrollingDirection.Y
		scroll.ScrollBarThickness = 4
		scroll.ScrollBarImageColor3 = Theme.Colors.Accent
		scroll.ScrollBarImageTransparency = 0.45
		scroll.CanvasSize = UDim2.fromOffset(0, 0)
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.ZIndex = 3
		scroll.Visible = false
		scroll.ClipsDescendants = true
		scroll.Parent = state.content
		bindAccent(function(color)
			scroll.ScrollBarImageColor3 = color
		end)

		local list = UIKit.frame(scroll, {
			Name = "List",
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
			ZIndex = 3,
		})
		list.AutomaticSize = Enum.AutomaticSize.Y

		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, Theme.Content.PaddingTop)
		padding.PaddingBottom = UDim.new(0, Theme.Content.PaddingBottom)
		padding.PaddingRight = UDim.new(0, 6)
		padding.Parent = list

		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, Theme.Content.CardGap)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		layout.Parent = list

		state.pages[key] = { key = key, frame = scroll, list = list, cards = {} }
		return state.pages[key]
	end

	local function buildContent(window)
		local content = UIKit.frame(window, {
			Name = "Content",
			Size = UDim2.fromOffset(Theme.Content.Width, Theme.Window.Height - Theme.Content.Top - 20),
			Position = UDim2.fromOffset(Theme.Content.OffsetX, Theme.Content.Top),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = 3,
		})
		state.content = content

		for _, tab in ipairs(TABS) do
			createPage(tab.Key)
		end
	end

	local layoutCounters = setmetatable({}, { __mode = "k" })

	local function createCard(parent, record)
		layoutCounters[parent] = (layoutCounters[parent] or 0) + 1

		local card = UIKit.frame(parent, {
			Name = "Card_" .. record.Id,
			Size = UDim2.new(1, 0, 0, Theme.Content.CardHeight),
			BackgroundColor3 = Theme.Colors.Glass,
			BackgroundTransparency = 0.92,
			CornerRadius = 10,
			ZIndex = 4,
		})
		card.LayoutOrder = 100 + layoutCounters[parent]

				local hoverGradient = UIKit.gradient(card, Theme.Colors.HoverTop, Theme.Colors.HoverBottom, 90)
		hoverGradient.Transparency = NumberSequence.new(1)
		hoverGradient.Enabled = false
		bindAccent(function(color)
		hovergradient.Transparency = NumberSequence.new(1)	
		bindAccent(function(color)
			hoverGradient.Color = ColorSequence.new(color, color:Lerp(Color3.fromRGB(0, 0, 0), 0.2))
		end)

		local iconBox = UIKit.frame(card, {
			Name = "IconBox",
			Size = UDim2.fromOffset(Theme.Sizes.CardIconBox, Theme.Sizes.CardIconBox),
			Position = UDim2.fromOffset(12, 15),
			BackgroundColor3 = Theme.Colors.IconTop,
			CornerRadius = 10,
			ZIndex = 5,
		})
		local iconGradient = UIKit.gradient(iconBox, Theme.Colors.IconTop, Theme.Colors.IconBottom, 90)
		bindAccent(function(color)
			iconGradient.Color = ColorSequence.new(color:Lerp(Color3.fromRGB(255, 255, 255), 0.22), color:Lerp(Color3.fromRGB(0, 0, 0), 0.12))
		end)

		local icon = UIKit.icon(iconBox, record.Icon, Theme.Sizes.CardIcon, Theme.Colors.Glass)
		icon.Position = UDim2.fromOffset(11, 11)

		local title = UIKit.label(card, {
			Name = "Title",
			Text = record.Title,
			TextSize = Theme.Text.CardTitle,
			Font = FONT_SEMI,
			TextColor3 = Theme.Colors.TextTitle,
			Position = UDim2.fromOffset(62, 15),
			Size = UDim2.fromOffset(400, 17),
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 5,
		})

		local description = UIKit.label(card, {
			Name = "Description",
			Text = record.Description,
			TextSize = Theme.Text.CardDescription,
			Font = FONT_BODY,
			TextColor3 = Theme.Colors.TextMuted,
			Position = UDim2.fromOffset(62, 33),
			Size = UDim2.fromOffset(500, 14),
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 5,
		})

		local favorite = UIKit.button(card, {
			Name = "Favorite",
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.fromOffset(560, 8),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 5,
		})
		local favoriteIcon = UIKit.icon(favorite, "star", 13, Theme.Colors.TextDim)
		favoriteIcon.Position = UDim2.fromOffset(2, 2)

		local view = {
			record = record,
			frame = card,
			control = nil,
		}

		local function paintFavorite()
			local active = record.Favorite
			Icons.SetColor(favoriteIcon, active and Theme.Colors.AccentLight or Theme.Colors.TextDim)
			favoriteIcon.Rotation = active and 0 or 0
		end
		paintFavorite()

		favorite.MouseButton1Click:Connect(function()
			Registry.SetFavorite(record.Id, not record.Favorite)
			paintFavorite()
		end)

				local hoverGradientEnabled = false
		local function applyHover(hovering)
			if hovering then
				hoverGradientEnabled = true
				hoverGradient.Enabled = true
				hoverGradient.Transparency = NumberSequence.new(0.45)
				tween(card, { BackgroundColor3 = Theme.Colors.HoverTop, BackgroundTransparency = 0.82 }, 0.18)
			else
				hoverGradientEnabled = false
				tween(card, { BackgroundColor3 = Theme.Colors.Glass, BackgroundTransparency = 0.92 }, 0.18)
				task.delay(0.18, function()
					if not hoverGradientEnabled and hoverGradient and hoverGradient.Parent then
						hoverGradient.Enabled = false
					end
				end)
			end
		end

		UIKit.hover(card, function()
			applyHover(true)
		end, function()
			applyHover(false)
		end)

		if record.Kind == "slider" then
			local valueLabel = UIKit.label(card, {
				Name = "Value",
				Text = "",
				TextSize = 9,
				Font = FONT_SEMI,
				TextColor3 = Theme.Colors.AccentLight,
				Position = UDim2.fromOffset(496, 45),
				Size = UDim2.fromOffset(150, 12),
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 5,
			})

			local slider = UIKit.slider(card, {
				Width = 150,
				Min = record.Min or 0,
				Max = record.Max or 100,
				Step = record.Step or 1,
				Value = tonumber(record.Value) or (record.Min or 0),
				Position = UDim2.fromOffset(496, 18),
				OnChanged = function(value)
					Registry.SetValue(record.Id, value)
				end,
			})
			slider.frame.Position = UDim2.fromOffset(496, 18)

			description.Size = UDim2.fromOffset(420, 14)

			view.control = slider
			view.Update = function()
				slider.SetValue(record.Value, true)
				if record.Format then
					valueLabel.Text = string.format(record.Format, record.Value)
				else
					valueLabel.Text = tostring(record.Value)
				end
			end
		elseif record.Kind == "button" then
			description.Size = UDim2.fromOffset(470, 14)

			local button = UIKit.button(card, {
				Name = "Action",
				Text = record.ActionLabel or "Run",
				TextSize = 10,
				Font = FONT_SEMI,
				TextColor3 = Theme.Colors.TextPrimary,
				Size = UDim2.fromOffset(92, 26),
				Position = UDim2.fromOffset(554, 22),
				BackgroundColor3 = Theme.Colors.Glass,
				BackgroundTransparency = 0.9,
				CornerRadius = 7,
				Stroke = { Color = Theme.Colors.Glass, Transparency = 0.8, Thickness = 1 },
				ZIndex = 5,
			})
			UIKit.hover(button, function()
				tween(button, { BackgroundTransparency = 0.78 }, 0.15)
				tween(button, { TextColor3 = Theme.Colors.AccentLight }, 0.15)
			end, function()
				tween(button, { BackgroundTransparency = 0.9 }, 0.15)
				tween(button, { TextColor3 = Theme.Colors.TextPrimary }, 0.15)
			end)
			button.MouseButton1Click:Connect(function()
				Client.RunFeature(record)
			end)

			view.control = button
			view.Update = function()
				button.Text = record.ActionLabel or "Run"
			end
		else
			description.Size = UDim2.fromOffset(486, 14)

			local toggle = UIKit.toggle(card, {
				Position = UDim2.fromOffset(591, 25),
				ZIndex = 6,
			})
			toggle.frame.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					Registry.SetValue(record.Id, not record.Value)
				end
			end)

			view.control = toggle
			view.Update = function()
				toggle:Set(record.Value, true)
			end
		end

		view.Update()
		table.insert(record.Views, view)
		return view
	end

	local function clearPageCards(key)
		local page = state.pages[key]
		if not page then
			return
		end
		for _, view in ipairs(page.cards) do
			for _, recordView in ipairs(view.record.Views) do
				local index = indexOf(recordView, view)
				if index then
					table.remove(recordView, index)
				end
			end
			if view.frame.Parent then
				view.frame:Destroy()
			end
		end
		clearList(page.cards)
	end

	local function rebuildFavorites()
		local page = state.pages.Favorites
		if not page then
			return
		end
		clearPageCards("Favorites")

		local favorites = Registry.Favorites()
		if #favorites == 0 then
			local empty = UIKit.frame(page.list, {
				Name = "EmptyState",
				Size = UDim2.new(1, 0, 0, 64),
				BackgroundColor3 = Theme.Colors.Glass,
				BackgroundTransparency = 0.93,
				CornerRadius = 10,
				ZIndex = 4,
			})
			empty.LayoutOrder = 100
			local icon = UIKit.icon(empty, "star", 18, Theme.Colors.TextDim)
			icon.Position = UDim2.fromOffset(14, 23)
			UIKit.label(empty, {
				Text = "No favourites yet",
				TextSize = 11,
				Font = FONT_SEMI,
				TextColor3 = Theme.Colors.TextSecondary,
				Position = UDim2.fromOffset(44, 14),
				Size = UDim2.fromOffset(240, 16),
				ZIndex = 5,
			})
			UIKit.label(empty, {
				Text = "Tap the star on any feature to pin it here.",
				TextSize = 9,
				Font = FONT_BODY,
				TextColor3 = Theme.Colors.TextDim,
				Position = UDim2.fromOffset(44, 31),
				Size = UDim2.fromOffset(280, 14),
				ZIndex = 5,
			})
			return
		end

		for _, record in ipairs(favorites) do
			local view = createCard(page.list, record)
			table.insert(page.cards, view)
		end
	end

	local function refreshPage(key)
		local page = state.pages[key]
		if not page then
			return
		end
		for _, view in ipairs(page.cards) do
			view.Update()
		end
	end

	local function buildHomePage()
		local page = state.pages.Home
		if not page then
			return
		end

		local stats = UIKit.frame(page.list, {
			Name = "Stats",
			Size = UDim2.new(1, 0, 0, 62),
			BackgroundTransparency = 1,
			ZIndex = 4,
		})
		stats.LayoutOrder = 0

		local function tile(x, label, value, iconName)
			local holder = UIKit.frame(stats, {
				Size = UDim2.fromOffset(211, 62),
				Position = UDim2.fromOffset(x, 0),
				BackgroundColor3 = Theme.Colors.Glass,
				BackgroundTransparency = 0.92,
				CornerRadius = 10,
				ZIndex = 4,
			})
			local icon = UIKit.icon(holder, iconName, 16, Theme.Colors.AccentLight)
			icon.Position = UDim2.fromOffset(14, 23)
			UIKit.label(holder, {
				Text = label,
				TextSize = 8,
				Font = FONT_BOLD,
				TextColor3 = Theme.Colors.TextDim,
				Position = UDim2.fromOffset(40, 14),
				Size = UDim2.fromOffset(150, 12),
				ZIndex = 5,
			})
			local valueLabel = UIKit.label(holder, {
				Text = value,
				TextSize = 13,
				Font = FONT_SEMI,
				TextColor3 = Theme.Colors.TextPrimary,
				Position = UDim2.fromOffset(40, 30),
				Size = UDim2.fromOffset(160, 18),
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 5,
			})
			state.statLabels[label] = valueLabel
			return holder
		end

		tile(0, "PLAYER", Effects.GetPlayerName(), "person")
		tile(226, "PING", tostring(Effects.GetPing()) .. " ms", "bolt")
		tile(452, "SERVER", Effects.GetServerId(), "cube")

		local quick = UIKit.frame(page.list, {
			Name = "QuickActions",
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundTransparency = 1,
			ZIndex = 4,
		})
		quick.LayoutOrder = 1

		local function quickButton(x, text, iconName, callback)
			local button = UIKit.button(quick, {
				Size = UDim2.fromOffset(211, 34),
				Position = UDim2.fromOffset(x, 0),
				BackgroundColor3 = Theme.Colors.Glass,
				BackgroundTransparency = 0.92,
				CornerRadius = 9,
				Text = "",
				ZIndex = 4,
			})
			local icon = UIKit.icon(button, iconName, 14, Theme.Colors.AccentLight)
			icon.Position = UDim2.fromOffset(14, 10)
			UIKit.label(button, {
				Text = text,
				TextSize = 10,
				Font = FONT_MEDIUM,
				TextColor3 = Theme.Colors.TextSecondary,
				Position = UDim2.fromOffset(36, 7),
				Size = UDim2.fromOffset(160, 20),
				ZIndex = 5,
			})
			button.MouseButton1Click:Connect(callback)
			UIKit.hover(button, function()
				tween(button, { BackgroundTransparency = 0.86 }, 0.15)
			end, function()
				tween(button, { BackgroundTransparency = 0.92 }, 0.15)
			end)
			return button
		end

		quickButton(0, "Copy position", "tag", function()
			local text = Effects.CopyPosition()
			Client.Notify("Copied " .. text, "success")
		end)
		quickButton(226, "Toggle panel", "minimize", function()
			Client.Toggle()
		end)
		quickButton(452, "Reset config", "reset", function()
			Client.ResetAll()
		end)
	end

	local function buildLeaderboardsPage()
		local page = state.pages.Leaderboards
		if not page then
			return
		end

		local header = UIKit.frame(page.list, {
			Name = "Header",
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = Theme.Colors.Glass,
			BackgroundTransparency = 0.92,
			CornerRadius = 10,
			ZIndex = 4,
		})
		header.LayoutOrder = 0

		UIKit.label(header, {
			Text = "SERVER PLAYERS",
			TextSize = 8,
			Font = FONT_BOLD,
			TextColor3 = Theme.Colors.TextDim,
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.fromOffset(200, 12),
			ZIndex = 5,
		})
		local countLabel = UIKit.label(header, {
			Text = "",
			TextSize = 10,
			Font = FONT_SEMI,
			TextColor3 = Theme.Colors.AccentLight,
			Position = UDim2.fromOffset(460, 6),
			Size = UDim2.fromOffset(180, 14),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 5,
		})
		state.statLabels["PLAYERS"] = countLabel

		UIKit.label(header, {
			Text = "PING",
			TextSize = 8,
			Font = FONT_BOLD,
			TextColor3 = Theme.Colors.TextDim,
			Position = UDim2.fromOffset(440, 26),
			Size = UDim2.fromOffset(200, 12),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 5,
		})
		UIKit.label(header, {
			Text = "ACCOUNT",
			TextSize = 8,
			Font = FONT_BOLD,
			TextColor3 = Theme.Colors.TextDim,
			Position = UDim2.fromOffset(120, 26),
			Size = UDim2.fromOffset(200, 12),
			ZIndex = 5,
		})

		local rows = UIKit.frame(page.list, {
			Name = "Rows",
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 4,
		})
		rows.LayoutOrder = 1

		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 8)
		layout.Parent = rows

		state.playerRows = { container = rows }
		state.statLabels["PLAYERS"] = countLabel

		local function renderPlayers()
			local players = Effects.GetPlayers()
			if state.statLabels["PLAYERS"] then
				state.statLabels["PLAYERS"].Text = string.format("%d in server", #players)
			end
			for _, row in ipairs(state.playerRows.entries or {}) do
				if row.frame.Parent then
					row.frame:Destroy()
				end
			end
			state.playerRows.entries = {}
			for index, entry in ipairs(players) do
				local row = UIKit.frame(rows, {
					Size = UDim2.new(1, 0, 0, 34),
					BackgroundColor3 = Theme.Colors.Glass,
					BackgroundTransparency = 0.94,
					CornerRadius = 8,
					ZIndex = 4,
				})
				row.LayoutOrder = index

				local badge = UIKit.frame(row, {
					Size = UDim2.fromOffset(22, 22),
					Position = UDim2.fromOffset(10, 6),
					BackgroundColor3 = Theme.Colors.Accent,
					BackgroundTransparency = 0.7,
					CornerRadius = 7,
					ZIndex = 5,
				})
				UIKit.label(badge, {
					Text = tostring(index),
					TextSize = 10,
					Font = FONT_BOLD,
					TextColor3 = Theme.Colors.TextPrimary,
					Position = UDim2.fromOffset(0, 3),
					Size = UDim2.fromOffset(22, 16),
					TextXAlignment = Enum.TextXAlignment.Center,
					ZIndex = 6,
				})

				UIKit.label(row, {
					Text = entry.Name,
					TextSize = 11,
					Font = FONT_SEMI,
					TextColor3 = Theme.Colors.TextPrimary,
					Position = UDim2.fromOffset(42, 8),
					Size = UDim2.fromOffset(260, 16),
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = 5,
				})
				UIKit.label(row, {
					Text = entry.Account .. (entry.Local and "  (you)" or ""),
					TextSize = 9,
					Font = FONT_BODY,
					TextColor3 = Theme.Colors.TextDim,
					Position = UDim2.fromOffset(42, 21),
					Size = UDim2.fromOffset(260, 12),
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = 5,
				})

				local pingColor = entry.Ping < 120 and Theme.Colors.Success
					or (entry.Ping < 250 and Theme.Colors.Warning or Theme.Colors.Danger)
				UIKit.label(row, {
					Text = entry.Ping .. " ms",
					TextSize = 10,
					Font = FONT_SEMI,
					TextColor3 = pingColor,
					Position = UDim2.fromOffset(500, 8),
					Size = UDim2.fromOffset(150, 18),
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex = 5,
				})

				table.insert(state.playerRows.entries, { frame = row })
			end
		end

		state.renderPlayers = renderPlayers
		renderPlayers()
	end

	local function createSettingRow(parent, title, description, order, builder)
		local row = UIKit.frame(parent, {
			Name = "Row_" .. title,
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundColor3 = Theme.Colors.Glass,
			BackgroundTransparency = 0.92,
			CornerRadius = 10,
			ZIndex = 4,
		})
		row.LayoutOrder = order

		UIKit.label(row, {
			Text = title,
			TextSize = 11,
			Font = FONT_SEMI,
			TextColor3 = Theme.Colors.TextPrimary,
			Position = UDim2.fromOffset(14, 10),
			Size = UDim2.fromOffset(300, 16),
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 5,
		})
		UIKit.label(row, {
			Text = description,
			TextSize = 9,
			Font = FONT_BODY,
			TextColor3 = Theme.Colors.TextMuted,
			Position = UDim2.fromOffset(14, 27),
			Size = UDim2.fromOffset(330, 14),
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 5,
		})

		local holder = UIKit.frame(row, {
			Size = UDim2.fromOffset(250, 56),
			Position = UDim2.fromOffset(405, 0),
			BackgroundTransparency = 1,
			ZIndex = 5,
		})
		builder(holder, row)
		return row
	end

	local function buildSettingsPage()
		local page = state.pages.Settings
		if not page then
			return
		end

		local function section(title, order)
			local holder = UIKit.frame(page.list, {
				Name = "Section_" .. title,
				Size = UDim2.new(1, 0, 0, 0),
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				ZIndex = 4,
			})
			holder.LayoutOrder = order
			UIKit.label(holder, {
				Text = title,
				TextSize = 9,
				Font = FONT_BOLD,
				TextColor3 = Theme.Colors.TextDim,
				Position = UDim2.fromOffset(2, 2),
				Size = UDim2.fromOffset(240, 14),
				ZIndex = 5,
			})
			local rows = UIKit.frame(holder, {
				Size = UDim2.new(1, 0, 0, 0),
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				Position = UDim2.fromOffset(0, 18),
				ZIndex = 4,
			})
			local layout = Instance.new("UIListLayout")
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Padding = UDim.new(0, 8)
			layout.Parent = rows
			return rows
		end

		local appearance = section("APPEARANCE", 0)

		createSettingRow(appearance, "Accent colour", "Repaints the whole panel palette", 1, function(holder)
			for index, accent in ipairs(Theme.Accents) do
				local swatch = UIKit.button(holder, {
					Size = UDim2.fromOffset(26, 26),
					Position = UDim2.fromOffset(6 + (index - 1) * 32, 15),
					BackgroundColor3 = accent.Color,
					BackgroundTransparency = 0,
					Text = "",
					CornerRadius = 8,
					ZIndex = 6,
				})
				UIKit.hover(swatch, function()
					tween(swatch, { BackgroundTransparency = 0.15 }, 0.15)
				end, function()
					tween(swatch, { BackgroundTransparency = 0 }, 0.15)
				end)
				swatch.MouseButton1Click:Connect(function()
					Config.SetSetting("accent", accent.Name)
					applyAccent(accent.Color)
					Config.Save()
					Client.Notify("Accent set to " .. accent.Name, "success")
				end)
			end
		end)

		createSettingRow(appearance, "Interface scale", "Resizes the client window", 2, function(holder)
			local slider = UIKit.slider(holder, {
				Width = 180,
				Min = 0.75,
				Max = 1.25,
				Step = 0.05,
				Value = Config.GetSetting("scale") or 1,
				Position = UDim2.fromOffset(6, 15),
				OnChanged = function(value)
					Config.SetSetting("scale", value)
					Client.UpdateScale()
				end,
			})
			local label = UIKit.label(holder, {
				Text = "",
				TextSize = 9,
				Font = FONT_SEMI,
				TextColor3 = Theme.Colors.AccentLight,
				Position = UDim2.fromOffset(192, 15),
				Size = UDim2.fromOffset(50, 16),
				ZIndex = 6,
			})
			local function refresh()
				label.Text = string.format("%.2fx", Config.GetSetting("scale") or 1)
			end
			refresh()
		end)

		createSettingRow(appearance, "Panel opacity", "Fades the client background", 3, function(holder)
			local slider = UIKit.slider(holder, {
				Width = 180,
				Min = 0.6,
				Max = 1,
				Step = 0.05,
				Value = Config.GetSetting("opacity") or 1,
				Position = UDim2.fromOffset(6, 15),
				OnChanged = function(value)
					Config.SetSetting("opacity", value)
					Client.UpdateOpacity()
				end,
			})
			local label = UIKit.label(holder, {
				Text = string.format("%d%%", math.floor((Config.GetSetting("opacity") or 1) * 100)),
				TextSize = 9,
				Font = FONT_SEMI,
				TextColor3 = Theme.Colors.AccentLight,
				Position = UDim2.fromOffset(192, 15),
				Size = UDim2.fromOffset(50, 16),
				ZIndex = 6,
			})
			slider.OnChanged = function(value)
				Config.SetSetting("opacity", value)
				label.Text = string.format("%d%%", math.floor(value * 100))
				Client.UpdateOpacity()
			end
		end)

		createSettingRow(appearance, "Animations", "Enables transitions and fades", 4, function(holder)
			local toggle = UIKit.toggle(holder, {
				Position = UDim2.fromOffset(6, 18),
			})
			toggle:Set(Config.GetSetting("animations") ~= false, true)
			toggle.frame.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					local value = not (Config.GetSetting("animations") ~= false)
					Config.SetSetting("animations", value)
					toggle:Set(value, true)
					Config.Save()
				end
			end)
		end)

		createSettingRow(appearance, "Drop shadow", "Ambient shadow under the window", 5, function(holder)
			local toggle = UIKit.toggle(holder, {
				Position = UDim2.fromOffset(6, 18),
			})
			toggle:Set(Config.GetSetting("shadow") ~= false, true)
			toggle.frame.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					local value = not (Config.GetSetting("shadow") ~= false)
					Config.SetSetting("shadow", value)
					toggle:Set(value, true)
					Client.UpdateOpacity()
				end
			end)
		end)

		local clientSection = section("CLIENT", 1)

		createSettingRow(clientSection, "Premium tier", "Unlocks the gold badge", 1, function(holder)
			local toggle = UIKit.toggle(holder, {
				Position = UDim2.fromOffset(6, 18),
			})
			toggle:Set(Config.GetSetting("premium") == true, true)
			toggle.frame.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					local value = not (Config.GetSetting("premium") == true)
					Config.SetSetting("premium", value)
					toggle:Set(value, true)
					if state.tierLabel then
						state.tierLabel.Text = value and "Premium" or "Non-Premium"
						state.tierLabel.TextColor3 = value and Theme.Colors.AccentLight or Theme.Colors.TextPrimary
					end
					Config.Save()
				end
			end)
		end)

		createSettingRow(clientSection, "Save configuration", "Writes the config to disk", 2, function(holder)
			local button = UIKit.button(holder, {
				Text = "Save",
				TextSize = 10,
				Font = FONT_SEMI,
				TextColor3 = Theme.Colors.TextPrimary,
				Size = UDim2.fromOffset(80, 26),
				Position = UDim2.fromOffset(6, 15),
				BackgroundColor3 = Theme.Colors.Glass,
				BackgroundTransparency = 0.9,
				CornerRadius = 7,
				Stroke = { Color = Theme.Colors.Glass, Transparency = 0.8, Thickness = 1 },
				ZIndex = 6,
			})
			button.MouseButton1Click:Connect(function()
				Client.SaveConfig()
				Client.Notify("Configuration saved", "success")
			end)
		end)

		createSettingRow(clientSection, "Load configuration", "Restores the last saved state", 3, function(holder)
			local button = UIKit.button(holder, {
				Text = "Load",
				TextSize = 10,
				Font = FONT_SEMI,
				TextColor3 = Theme.Colors.TextPrimary,
				Size = UDim2.fromOffset(80, 26),
				Position = UDim2.fromOffset(96, 15),
				BackgroundColor3 = Theme.Colors.Glass,
				BackgroundTransparency = 0.9,
				CornerRadius = 7,
				Stroke = { Color = Theme.Colors.Glass, Transparency = 0.8, Thickness = 1 },
				ZIndex = 6,
			})
			button.MouseButton1Click:Connect(function()
				Client.LoadConfig()
				Client.Notify("Configuration loaded", "success")
			end)
		end)

		createSettingRow(clientSection, "Reset configuration", "Turns every feature back off", 4, function(holder)
			local button = UIKit.button(holder, {
				Text = "Reset all",
				TextSize = 10,
				Font = FONT_SEMI,
				TextColor3 = Theme.Colors.Danger,
				Size = UDim2.fromOffset(92, 26),
				Position = UDim2.fromOffset(186, 15),
				BackgroundColor3 = Theme.Colors.Glass,
				BackgroundTransparency = 0.9,
				CornerRadius = 7,
				Stroke = { Color = Theme.Colors.Danger, Transparency = 0.6, Thickness = 1 },
				ZIndex = 6,
			})
			button.MouseButton1Click:Connect(function()
				Client.ResetAll()
			end)
		end)

		local keys = section("HOTKEYS", 2)

		local function hotkeyRow(name, description, keyName, order)
			createSettingRow(keys, name, description, order, function(holder)
				UIKit.label(holder, {
					Text = keyName,
					TextSize = 10,
					Font = FONT_SEMI,
					TextColor3 = Theme.Colors.AccentLight,
					Position = UDim2.fromOffset(6, 20),
					Size = UDim2.fromOffset(160, 18),
					ZIndex = 6,
				})
			end)
		end

		hotkeyRow("Toggle client", "Show or hide the whole panel", "END", 1)
		hotkeyRow("Next tab", "Cycle through the sidebar", "CTRL + TAB", 2)
		hotkeyRow("Reset client", "Reset every feature", "CTRL + R", 3)
	end

	function Client.AddTab(key, iconName)
		if state.pages[key] then
			return key
		end
		if not state.tabList then
			return nil
		end

		createPage(key)
		table.insert(state.tabOrder, key)
		addTabButton(key, iconName or "sparkles")
		layoutTabs()
		Client.Notify("Tab " .. key .. " created", "success")
		return key
	end

	function Client.RemoveTab(key)
		local page = state.pages[key]
		if not page or key == "Home" or key == "Settings" then
			return
		end
		for _, view in ipairs(page.cards) do
			for _, recordView in ipairs(view.record.Views) do
				local index = indexOf(recordView, view)
				if index then
					table.remove(recordView, index)
				end
			end
			if view.frame.Parent then
				view.frame:Destroy()
			end
		end
		if page.frame.Parent then
			page.frame:Destroy()
		end
		state.pages[key] = nil
		state.tabButtons[key] = nil
		for index, tabKey in ipairs(state.tabOrder) do
			if tabKey == key then
				table.remove(state.tabOrder, index)
				break
			end
		end
		layoutTabs()
		if state.currentTab == key then
			Client.SetTab("Home")
		end
	end

	function Client.AddFeatureCard(tabName, title, description, iconId, callback, options)
		options = options or {}
		if not state.pages[tabName] then
			Client.AddTab(tabName, options.icon)
		end
		local tabs = options.tabs or { tabName }
		local record = Registry.Add({
			id = options.id,
			tab = tabName,
			tabs = tabs,
			title = title,
			description = description,
			icon = iconId,
			kind = options.kind or "toggle",
			value = options.value,
			default = options.default,
			min = options.min,
			max = options.max,
			step = options.step,
			format = options.format,
			callback = callback,
		})

		for _, key in ipairs(tabs) do
			local page = state.pages[key]
			if page then
				local view = createCard(page.list, record)
				table.insert(page.cards, view)
			end
		end

		Client.UpdateModuleCount()
		return record
	end

	function Client.AddFeatureButton(tabName, title, description, iconId, callback, label)
		return Client.AddFeatureCard(tabName, title, description, iconId, callback, {
			kind = "button",
			actionLabel = label or "Run",
		})
	end

	function Client.AddFeatureSlider(tabName, title, description, iconId, options, callback)
		options = options or {}
		options.kind = "slider"
		return Client.AddFeatureCard(tabName, title, description, iconId, callback, options)
	end

	function Client.RunFeature(record)
		if not record then
			return
		end
		if record.Kind == "button" then
			Client.Invoke(record, nil)
		else
			Registry.SetValue(record.Id, not record.Value)
		end
	end

	function Client.Invoke(record, value)
		if not record or not record.Callback then
			return
		end
		local ok, err = pcall(record.Callback, value)
		if not ok then
			flashDot(state.errorDot, Theme.Colors.Danger)
			Client.Notify("Callback failed: " .. tostring(err), "error")
			return
		end
		flashDot(state.activityDot, Theme.Colors.Warning)
	end

	function Client.UpdateModuleCount()
		if state.moduleLabel then
			state.moduleLabel.Text = string.format("%d Modules", Registry.Count())
		end
	end

	function Client.SetTab(key, instant)
		local page = state.pages[key]
		if not page then
			return
		end
		local previousKey = state.currentTab

		if previousKey == key and not instant then
			return
		end

		for tabKey, entry in pairs(state.tabButtons) do
			local active = tabKey == key
			local button = entry.button
			tween(button, { BackgroundTransparency = active and 0.65 or 1 }, 0.16)
			tween(entry.gradient, { Transparency = active and 0 or 1 }, 0.16)
			Icons.SetColor(entry.icon, active and Theme.Colors.AccentSoft or Theme.Colors.TextDim)
			tween(entry.label, { TextColor3 = active and Theme.Colors.TextPrimary or Theme.Colors.TextSecondary }, 0.16)
		end

		state.currentTab = key
		state.titleLabel.Text = key

		local previousPage = state.pages[previousKey]
		if previousPage and previousPage ~= page then
			UIKit.fade(previousPage.frame, 1, 0.12)
			tween(previousPage.frame, { Position = UDim2.fromOffset(-10, 0) }, 0.12)
			task.delay(0.13, function()
				if state.currentTab ~= previousKey and previousPage.frame then
					previousPage.frame.Visible = false
					previousPage.frame.Position = UDim2.fromOffset(0, 0)
				end
			end)
		end

		page.frame.Visible = true
		page.frame.Position = UDim2.fromOffset(10, 0)
		UIKit.fade(page.frame, 0, 0.2)
		tween(page.frame, { Position = UDim2.fromOffset(0, 0) }, 0.2)

		task.delay(0.2, function()
			refreshPage(key)
		end)

		Config.Set("tab", key)
	end

	function Client.UpdateScale()
		local camera = workspace.CurrentCamera
		local screen = camera and camera.ViewportSize or Vector2.new(1920, 1080)
		local fit = math.min(1, screen.X / 980, screen.Y / 620)
		local userScale = Config.GetSetting("scale") or 1
		state.scale = fit * userScale
		if state.scaleInstance then
			tween(state.scaleInstance, { Scale = state.scale }, 0.2)
		end
	end

	function Client.UpdateOpacity()
		local opacity = Config.GetSetting("opacity") or 1
		if state.window then
			tween(state.window, { BackgroundTransparency = 1 - opacity }, 0.2)
		end
		if state.sidebar then
			tween(state.sidebar, { BackgroundTransparency = 0.12 + (1 - opacity) * 0.4 }, 0.2)
		end
		if state.shadow then
			local shadowEnabled = Config.GetSetting("shadow") ~= false
			tween(state.shadow, { BackgroundTransparency = shadowEnabled and 0.55 or 1 }, 0.2)
		end
	end

	function Client.SaveConfig()
		local saved = Config.Save()
		Client.Notify(saved and "Configuration saved" or "No filesystem available", saved and "success" or "warn")
	end

	function Client.LoadConfig()
		local loaded = Config.Load()
		if loaded then
			Client.ApplyConfig()
			Client.Notify("Configuration loaded", "success")
		else
			Client.Notify("No saved configuration found", "warn")
		end
	end

	function Client.ApplyConfig()
		local features = Config.Data.features or {}
		local favorites = Config.Data.favorites or {}
		for _, record in ipairs(Registry.Order) do
			local saved = features[record.Id]
			if saved ~= nil then
				record.Value = saved
				record.HasOverride = true
				record.Favorite = favorites[record.Id] == true
				Client.Invoke(record, record.Value)
				for _, view in ipairs(record.Views) do
					view.Update()
				end
			end
		end
		rebuildFavorites()
		Client.UpdateModuleCount()
	end

	function Client.ResetAll()
		if state.resetting then
			return
		end
		state.resetting = true

		for _, record in ipairs(Registry.Order) do
			record.Value = record.Default
			record.HasOverride = false
			record.Favorite = false
			Client.Invoke(record, record.Value)
			for _, view in ipairs(record.Views) do
				view.Update()
			end
		end

		Config.Reset()
		Config.Save()
		rebuildFavorites()
		state.resetting = false
		Client.Notify("All features reset", "warn")
	end

	function Client.Minimize()
		if not state.window then
			return
		end
		state.window.Visible = false
		if not state.restorePill then
			local pill = UIKit.button(state.root, {
				Name = "Restore",
				Size = UDim2.fromOffset(46, 46),
				Position = UDim2.new(1, -24, 1, -24),
				AnchorPoint = Vector2.new(1, 1),
				BackgroundColor3 = Theme.Colors.Accent,
				BackgroundTransparency = 0.15,
				Text = "",
				CornerRadius = 12,
				ZIndex = 40,
			})
			local icon = UIKit.icon(pill, "logo", 22, Theme.Colors.Glass)
			icon.Position = UDim2.fromOffset(12, 12)
			pill.MouseButton1Click:Connect(function()
				state.window.Visible = true
				pill.Visible = false
			end)
			state.restorePill = pill
		end
		state.restorePill.Visible = true
	end

	function Client.Toggle(force)
		local visible = state.gui.Enabled
		if force == nil then
			force = not visible
		end
		state.gui.Enabled = force
		if force then
			Client.Notify("Client enabled", "info")
		else
			Client.Notify("Client disabled - press END to reopen", "warn")
		end
	end

	local function applySearch(query)
		query = string.lower(query or "")
		local total = 0
		local matchedTab = nil

		for key, page in pairs(state.pages) do
			for _, view in ipairs(page.cards) do
				local record = view.record
				local hit = query == ""
					or string.find(string.lower(record.Title), query, 1, true) ~= nil
					or string.find(string.lower(record.Description), query, 1, true) ~= nil
				view.frame.Visible = hit
				if hit then
					total += 1
					if not matchedTab then
						matchedTab = key
					end
				end
			end
		end

		if state.searchCount then
			state.searchCount.Text = query == "" and "" or tostring(total)
		end

		if query == "" or not matchedTab then
			return
		end

		local currentHasMatch = false
		for _, view in ipairs(state.pages[state.currentTab].cards) do
			if view.frame.Visible then
				currentHasMatch = true
				break
			end
		end
		if not currentHasMatch then
			Client.SetTab(matchedTab)
		end
	end

	local function hookInput()
		UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if input.KeyCode == Enum.KeyCode.End then
				Client.Toggle()
			elseif input.KeyCode == Enum.KeyCode.Tab and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				local index = 1
				for position, tab in ipairs(TABS) do
					if tab.Key == state.currentTab then
						index = position
						break
					end
				end
				local nextIndex = (index % #TABS) + 1
				Client.SetTab(TABS[nextIndex].Key)
			elseif input.KeyCode == Enum.KeyCode.R and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				Client.ResetAll()
			end
		end)

		local dragging = false
		local dragStart = Vector2.zero

		state.shell.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			if isInteractiveAt(input.Position) then
				return
			end
			dragging = true
			dragStart = input.Position
		end)

		UserInputService.InputChanged:Connect(function(input)
			if not dragging then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local camera = workspace.CurrentCamera
			local screen = camera and camera.ViewportSize or Vector2.new(1920, 1080)
			local offset = state.dragOffset + (input.Position - dragStart)
			local limitX = math.max(screen.X / 2 - 80, 0)
			local limitY = math.max(screen.Y / 2 - 60, 0)
			offset = Vector2.new(math.clamp(offset.X, -limitX, limitX), math.clamp(offset.Y, -limitY, limitY))
			state.dragOffset = offset
			state.shell.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)

		local frames = 0
		local elapsed = 0
		RunService.Heartbeat:Connect(function(delta)
			frames += 1
			elapsed += delta
			if elapsed >= 0.5 then
				if state.fpsValue then
					state.fpsValue.Text = tostring(math.floor(frames / elapsed))
				end
				frames = 0
				elapsed = 0
			end
		end)

		task.spawn(function()
			while state.initialized do
				task.wait(1)
				if not state.initialized then
					break
				end
				if state.statLabels["PING"] then
					state.statLabels["PING"].Text = tostring(Effects.GetPing()) .. " ms"
				end
				if state.renderPlayers then
					state.renderPlayers()
				end
			end
		end)
	end

	local function registerFeatures()
		Client.AddFeatureCard("Combat", "Field of View", "Widen or narrow the camera field of view.", "target", function(value)
			Effects.SetCameraFov(value)
		end, {
			kind = "slider",
			tabs = { "Combat", "Home" },
			id = "combat_fov",
			min = 60,
			max = 110,
			step = 1,
			value = 70,
			format = "%d deg",
		})

		Client.AddFeatureCard("Combat", "Crosshair Overlay", "Draw a precision crosshair on screen.", "crosshair", function(value)
			Effects.SetCrosshair(value)
		end, {
			tabs = { "Combat", "Home" },
			id = "combat_crosshair",
		})

		Client.AddFeatureCard("Combat", "Mouse Sensitivity", "Scales camera mouse delta.", "speed", function(value)
			Effects.SetMouseSensitivity(value)
		end, {
			kind = "slider",
			id = "combat_sensitivity",
			min = 0.2,
			max = 2,
			step = 0.1,
			value = 1,
			format = "%.1fx",
		})

		Client.AddFeatureCard("Combat", "Freeze Camera", "Locks the camera where it stands.", "camera", function(value)
			Effects.SetFreezeCamera(value)
		end, {
			id = "combat_freeze_camera",
		})

		Client.AddFeatureCard("Render", "Camera Zoom", "Changes the distance of the camera.", "camera", function(value)
			Effects.SetCameraZoom(value)
		end, {
			kind = "slider",
			tabs = { "Render", "Home" },
			id = "render_zoom",
			min = 0.5,
			max = 10,
			step = 0.5,
			value = 1,
			format = "%.1fx",
		})

		Client.AddFeatureCard("Render", "Brightness", "Raises the local lighting brightness.", "sun", function(value)
			Effects.SetBrightness(value)
		end, {
			kind = "slider",
			id = "render_brightness",
			min = 0,
			max = 3,
			step = 0.1,
			value = 1,
			format = "%.1f",
		})

		Client.AddFeatureCard("Render", "Time of Day", "Sets the local clock of the world.", "clock", function(value)
			Effects.SetTimeOfDay(value)
		end, {
			kind = "slider",
			id = "render_time",
			min = 0,
			max = 24,
			step = 0.5,
			value = 14,
			format = "%.1f h",
		})

		Client.AddFeatureCard("Render", "Remove Fog", "Clears the distance fog for the client.", "eye", function(value)
			Effects.SetRemoveFog(value)
		end, {
			id = "render_fog",
		})

		Client.AddFeatureCard("Render", "Hide Player List", "Hides the Roblox player list.", "person", function(value)
			Effects.SetHidePlayerList(value)
		end, {
			id = "render_playerlist",
		})

		Client.AddFeatureCard("Render", "Hide Health", "Hides the Roblox health bar.", "shield", function(value)
			Effects.SetHideHealth(value)
		end, {
			id = "render_health",
		})

		Client.AddFeatureCard("Render", "Hide Chat", "Hides the Roblox chat window.", "folder", function(value)
			Effects.SetHideChat(value)
		end, {
			id = "render_chat",
		})

		Client.AddFeatureCard("Render", "Hide Core UI", "Hides every built in Roblox interface.", "sparkles", function(value)
			Effects.SetHideCoreGui(value)
		end, {
			tabs = { "Render", "Home" },
			id = "render_coreui",
		})

		Client.AddFeatureCard("Utility", "Walk Speed", "Local walk speed of your character.", "speed", function(value)
			Effects.SetWalkSpeed(value)
		end, {
			kind = "slider",
			tabs = { "Utility", "Home" },
			id = "utility_walkspeed",
			min = 0,
			max = 120,
			step = 1,
			value = 16,
			format = "%d",
		})

		Client.AddFeatureCard("Utility", "Jump Power", "Local jump power of your character.", "bolt", function(value)
			Effects.SetJumpPower(value)
		end, {
			kind = "slider",
			id = "utility_jumppower",
			min = 0,
			max = 250,
			step = 5,
			value = 50,
			format = "%d",
		})

		Client.AddFeatureCard("Utility", "Auto Jump", "Keeps the character jumping over obstacles.", "chevronRight", function(value)
			Effects.SetAutoJump(value)
		end, {
			id = "utility_autojump",
		})

		Client.AddFeatureCard("Utility", "Gravity", "Local gravity of the workspace.", "cube", function(value)
			Effects.SetGravity(value)
		end, {
			kind = "slider",
			id = "utility_gravity",
			min = 0,
			max = 500,
			step = 1,
			value = 196.2,
			format = "%.1f",
		})

		Client.AddFeatureCard("Utility", "Copy Position", "Copies your local position to the clipboard.", "tag", function()
			Client.Notify("Copied " .. Effects.CopyPosition(), "success")
		end, {
			kind = "button",
			id = "utility_copyposition",
			actionLabel = "Copy",
		})

		Client.AddFeatureCard("Utility", "Reset Configuration", "Turns every feature back to default.", "reset", function()
			Client.ResetAll()
		end, {
			kind = "button",
			id = "utility_reset",
			actionLabel = "Reset",
		})

		Client.AddFeatureCard("Utility", "Toggle Panel", "Shows or hides the client window.", "minimize", function()
			Client.Toggle()
		end, {
			kind = "button",
			id = "utility_toggle",
			actionLabel = "Toggle",
		})
	end

	function Client.Build()
		if state.initialized then
			return Client
		end

		Config.Load()

		local accentName = Config.GetSetting("accent")
		for _, accent in ipairs(Theme.Accents) do
			if accent.Name == accentName then
				applyAccent(accent.Color)
				break
			end
		end

		local window = buildWindow()
		buildSidebar(window)
		buildHeader(window)
		buildContent(window)

		state.toastContainer = UIKit.frame(window, {
			Name = "Toasts",
			Size = UDim2.fromOffset(320, 140),
			Position = UDim2.new(0.5, 0, 1, -14),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			ClipsDescendants = false,
			ZIndex = 30,
		})

		registerFeatures()
		buildHomePage()
		buildLeaderboardsPage()
		buildSettingsPage()

		Registry.OnChanged(function(record)
			if record.HasOverride then
				Config.Data.features[record.Id] = record.Value
			end
			Config.Data.favorites[record.Id] = record.Favorite
			for _, view in ipairs(record.Views) do
				view.Update()
			end
			if record.FavoriteChanged then
				record.FavoriteChanged = false
				rebuildFavorites()
			end
			Client.Invoke(record, record.Value)
			Client.UpdateModuleCount()
			Config.Save()
		end)

		state.searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			task.wait(0.12)
			applySearch(state.searchBox.Text)
		end)

		state.initialized = true

		Client.UpdateScale()
		Client.UpdateOpacity()
		Client.UpdateModuleCount()
		rebuildFavorites()

		hookInput()

		Client.ApplyConfig()

		local initialTab = Config.Get("tab")
		if state.pages[initialTab] then
			Client.SetTab(initialTab, true)
		else
			Client.SetTab("Home", true)
		end

		state.titleLabel.Text = state.currentTab

		return Client
	end

	function Client.Destroy()
		state.initialized = false
		UIKit.disposeConnections()
		if state.gui then
			state.gui:Destroy()
		end
	end

	return Client

end

-- ===== Config.lua =====
__modules["Config"] = function()
	--[[
		Zolaris-Client :: Config
		Persists feature states, favourites and appearance settings.
		Uses the executor filesystem when available and silently degrades to memory otherwise.
	]]

	local HttpService = game:GetService("HttpService")

	local Config = {}

	local function copyTable(source)
		local copy = {}
		for key, value in pairs(source) do
			copy[key] = value
		end
		return copy
	end

	local FILE_NAME = "zolaris_client_config.json"

	local DEFAULT_SETTINGS = {
		accent = "Violet",
		scale = 1,
		opacity = 1,
		animations = true,
		shadow = true,
		premium = false,
	}

	Config.Data = {
		features = {},
		favorites = {},
		settings = copyTable(DEFAULT_SETTINGS),
		tab = "Home",
	}

	local function readFile(path)
		if type(readfile) ~= "function" then
			return nil
		end
		local ok, data = pcall(readfile, path)
		if not ok or type(data) ~= "string" then
			return nil
		end
		return data
	end

	local function writeFile(path, data)
		if type(writefile) ~= "function" then
			return false
		end
		return (pcall(writefile, path, data))
	end

	function Config.Get(key, fallback)
		local value = Config.Data[key]
		if value == nil then
			return fallback
		end
		return value
	end

	function Config.Set(key, value)
		Config.Data[key] = value
	end

	function Config.GetSetting(key)
		return Config.Data.settings[key]
	end

	function Config.SetSetting(key, value)
		Config.Data.settings[key] = value
	end

	function Config.Reset()
		Config.Data.features = {}
		Config.Data.favorites = {}
		Config.Data.settings = copyTable(DEFAULT_SETTINGS)
	end

	function Config.Save()
		local ok, encoded = pcall(HttpService.JSONEncode, Config.Data)
		if not ok then
			return false
		end
		return writeFile(FILE_NAME, encoded)
	end

	function Config.Load()
		local raw = readFile(FILE_NAME)
		if not raw then
			return false
		end
		local ok, decoded = pcall(HttpService.JSONDecode, raw)
		if not ok or type(decoded) ~= "table" then
			return false
		end
		if type(decoded.features) == "table" then
			Config.Data.features = decoded.features
		end
		if type(decoded.favorites) == "table" then
			Config.Data.favorites = decoded.favorites
		end
		if type(decoded.settings) == "table" then
			for key, value in pairs(decoded.settings) do
				Config.Data.settings[key] = value
			end
		end
		if type(decoded.tab) == "string" then
			Config.Data.tab = decoded.tab
		end
		return true
	end

	return Config

end

-- ===== Effects.lua =====
__modules["Effects"] = function()
	--[[
		Zolaris-Client :: Effects
		Plain client side behaviour behind every toggle.
		Everything here only touches properties the local client is allowed to touch,
		so the panel stays a UI project and never becomes game logic.
	]]

	local Players = game:GetService("Players")
	local Lighting = game:GetService("Lighting")
	local UserInputService = game:GetService("UserInputService")

	local Effects = {}

	local player = Players.LocalPlayer

	local humanoidState = {
		WalkSpeed = nil,
		JumpPower = nil,
		AutoJump = nil,
	}

	local crosshairGui = nil
	local characterHooked = false
	local startTime = os.clock()
	local fogState = { start = nil, finish = nil }

	local function getCharacter()
		return player and player.Character
	end

	local function getHumanoid()
		local character = getCharacter()
		if not character then
			return nil
		end
		return character:FindFirstChildOfClass("Humanoid")
	end

	local function applyHumanoidState()
		local humanoid = getHumanoid()
		if not humanoid then
			return
		end
		if humanoidState.WalkSpeed then
			humanoid.WalkSpeed = humanoidState.WalkSpeed
		end
		if humanoidState.JumpPower then
			humanoid.JumpPower = humanoidState.JumpPower
		end
		if humanoidState.AutoJump ~= nil then
			humanoid.AutoJump = humanoidState.AutoJump
		end
	end

	local function hookCharacter()
		if characterHooked or not player then
			return
		end
		characterHooked = true
		player.CharacterAdded:Connect(function()
			task.wait(0.3)
			applyHumanoidState()
		end)
	end

	hookCharacter()

	function Effects.SetWalkSpeed(value)
		humanoidState.WalkSpeed = value
		local humanoid = getHumanoid()
		if humanoid then
			humanoid.WalkSpeed = value
		end
	end

	function Effects.SetJumpPower(value)
		humanoidState.JumpPower = value
		local humanoid = getHumanoid()
		if humanoid then
			humanoid.JumpPower = value
		end
	end

	function Effects.SetAutoJump(enabled)
		humanoidState.AutoJump = enabled
		local humanoid = getHumanoid()
		if humanoid then
			humanoid.AutoJump = enabled
		end
	end

	function Effects.SetGravity(value)
		game.Gravity = value
	end

	function Effects.SetCameraFov(value)
		local camera = workspace.CurrentCamera
		if camera then
			camera.FieldOfView = value
		end
	end

	function Effects.SetCameraZoom(value)
		local camera = workspace.CurrentCamera
		if camera then
			camera.Zoom = value
		end
	end

	function Effects.SetFreezeCamera(enabled)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		camera.CameraType = enabled and Enum.CameraType.Scriptable or Enum.CameraType.Custom
	end

	function Effects.SetBrightness(value)
		Lighting.Brightness = value
	end

	function Effects.SetTimeOfDay(value)
		Lighting.ClockTime = value
	end

	function Effects.SetRemoveFog(enabled)
		if enabled then
			fogState.start = Lighting.FogStart
			fogState.finish = Lighting.FogEnd
			Lighting.FogStart = 0
			Lighting.FogEnd = 100000
		elseif fogState.start ~= nil then
			Lighting.FogStart = fogState.start
			Lighting.FogEnd = fogState.finish
			fogState.start = nil
			fogState.finish = nil
		end
	end

	function Effects.SetHideCoreGui(enabled)
		local starterGui = player and player:FindFirstChildOfClass("PlayerGui")
		if not starterGui then
			return
		end
		pcall(function()
			starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, not enabled)
		end)
	end

	function Effects.SetHidePlayerList(enabled)
		local starterGui = player and player:FindFirstChildOfClass("PlayerGui")
		if not starterGui then
			return
		end
		pcall(function()
			starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not enabled)
		end)
	end

	function Effects.SetHideHealth(enabled)
		local starterGui = player and player:FindFirstChildOfClass("PlayerGui")
		if not starterGui then
			return
		end
		pcall(function()
			starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, not enabled)
		end)
	end

	function Effects.SetHideChat(enabled)
		local starterGui = player and player:FindFirstChildOfClass("PlayerGui")
		if not starterGui then
			return
		end
		pcall(function()
			starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, not enabled)
		end)
	end

	function Effects.SetMouseSensitivity(value)
		UserInputService.MouseDeltaSensitivity = value
	end

	function Effects.SetCrosshair(enabled)
		if enabled then
			if crosshairGui and crosshairGui.Parent then
				crosshairGui.Enabled = true
				return
			end
			crosshairGui = Instance.new("ScreenGui")
			crosshairGui.Name = "ZolarisCrosshair"
			crosshairGui.ResetOnSpawn = false
			crosshairGui.DisplayOrder = 50
			crosshairGui.Parent = player:WaitForChild("PlayerGui")

			local function stroke(name, size, position)
				local frame = Instance.new("Frame")
				frame.Name = name
				frame.Size = size
				frame.Position = position
				frame.AnchorPoint = Vector2.new(0.5, 0.5)
				frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				frame.BackgroundTransparency = 0.15
				frame.BorderSizePixel = 0
				frame.Parent = crosshairGui
			end

			stroke("Up", UDim2.fromOffset(2, 12), UDim2.fromScale(0.5, 0.5))
			stroke("Down", UDim2.fromOffset(2, 12), UDim2.fromScale(0.5, 0.5))
			stroke("Left", UDim2.fromOffset(12, 2), UDim2.fromScale(0.5, 0.5))
			stroke("Right", UDim2.fromOffset(12, 2), UDim2.fromScale(0.5, 0.5))

			local up = crosshairGui:FindFirstChild("Up")
			local down = crosshairGui:FindFirstChild("Down")
			local left = crosshairGui:FindFirstChild("Left")
			local right = crosshairGui:FindFirstChild("Right")
			up.Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(0, -16)
			down.Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(0, 16)
			left.Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(-16, 0)
			right.Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(16, 0)
		else
			if crosshairGui then
				crosshairGui.Enabled = false
			end
		end
	end

	function Effects.CopyPosition()
		local character = getCharacter()
		if not character then
			return "0, 0, 0"
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			return "0, 0, 0"
		end
		local position = root.Position
		local text = string.format("%d, %d, %d", math.floor(position.X), math.floor(position.Y), math.floor(position.Z))
		if type(setclipboard) == "function" then
			pcall(setclipboard, text)
		end
		return text
	end

	function Effects.GetPing()
		if not player then
			return 0
		end
		local ok, ping = pcall(player.GetNetworkPing, player)
		if ok and type(ping) == "number" then
			return math.floor(ping)
		end
		return 0
	end

	function Effects.GetServerId()
		return string.sub(game.JobId, 1, 8)
	end

	function Effects.GetUptime()
		return math.floor(os.clock() - startTime)
	end

	function Effects.GetPlayerName()
		if player and player.DisplayName ~= "" then
			return player.DisplayName
		end
		return "Unknown"
	end

	function Effects.GetPlayerCount()
		return #Players:GetPlayers()
	end

	function Effects.GetPlayers()
		local list = {}
		for _, other in ipairs(Players:GetPlayers()) do
			local ping = 0
			local ok, value = pcall(other.GetNetworkPing, other)
			if ok and type(value) == "number" then
				ping = math.floor(value)
			end
			table.insert(list, {
				Name = other.DisplayName,
				Account = other.Name,
				Ping = ping,
				Local = other == player,
			})
		end
		table.sort(list, function(a, b)
			if a.Ping == b.Ping then
				return a.Name < b.Name
			end
			return a.Ping < b.Ping
		end)
		return list
	end

	return Effects

end

-- ===== Icons.lua =====
__modules["Icons"] = function()
	--[[
		Zolaris-Client :: Icons
		Every glyph is drawn procedurally from Frames so the panel needs no image assets.
		Glyphs are authored inside a 16x16 unit box and scaled on creation.
	]]

	local Icons = {}

	local BOX = 16
	local unit = 1

	local function solid(parent, x, y, w, h, color, radius)
		local f = Instance.new("Frame")
		f.Position = UDim2.fromOffset(x * unit, y * unit)
		f.Size = UDim2.fromOffset(w * unit, h * unit)
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.Parent = parent
		if radius and radius > 0 then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, radius * unit)
			c.Parent = f
		end
		return f
	end

	local function outline(parent, x, y, w, h, color, thickness, radius)
		local f = solid(parent, x, y, w, h, Color3.new(1, 1, 1), radius)
		f.BackgroundTransparency = 1
		local s = Instance.new("UIStroke")
		s.Color = color
		s.Thickness = thickness * unit
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = f
		return f
	end

	local function line(parent, x1, y1, x2, y2, thickness, color)
		local dx, dy = x2 - x1, y2 - y1
		local length = math.sqrt(dx * dx + dy * dy)
		local cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
		local f = solid(parent, cx - length / 2, cy - thickness / 2, length, thickness, color)
		f.Rotation = math.deg(math.atan2(dy, dx))
		return f
	end

	local function polyline(parent, points, thickness, color)
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			line(parent, a[1], a[2], b[1], b[2], thickness, color)
		end
	end

	local function circle(parent, cx, cy, r, color)
		return solid(parent, cx - r, cy - r, r * 2, r * 2, color, r)
	end

	local function ring(parent, cx, cy, r, color, thickness)
		return outline(parent, cx - r, cy - r, r * 2, r * 2, color, thickness, r)
	end

	local function dot(parent, cx, cy, r, color)
		return circle(parent, cx, cy, r, color)
	end

	local function arc(parent, cx, cy, r, from, to, color, thickness, steps)
		steps = steps or 14
		local previous
		for i = 0, steps do
			local angle = from + (to - from) * (i / steps)
			local px = cx + math.cos(angle) * r
			local py = cy + math.sin(angle) * r
			if previous then
				line(parent, previous[1], previous[2], px, py, thickness, color)
			end
			previous = { px, py }
		end
		return previous
	end

	local function glyphs()
		local set = {}

		set.home = function(c, col)
			polyline(c, { { 8, 1.6 }, { 1.8, 6.9 } }, 1.7, col)
			polyline(c, { { 8, 1.6 }, { 14.2, 6.9 } }, 1.7, col)
			polyline(c, { { 3.9, 5.7 }, { 3.9, 14.3 } }, 1.7, col)
			polyline(c, { { 12.1, 5.7 }, { 12.1, 14.3 } }, 1.7, col)
			polyline(c, { { 2.6, 14.3 }, { 13.4, 14.3 } }, 1.7, col)
			polyline(c, { { 8, 14.3 }, { 8, 9.6 } }, 1.6, col)
			polyline(c, { { 8, 9.6 }, { 10.2, 9.6 } }, 1.6, col)
		end

		set.star = function(c, col)
			local cx, cy, outer, inner = 8, 8.6, 7.1, 3.0
			local points = {}
			for i = 0, 10 do
				local r = (i % 2 == 0) and outer or inner
				local angle = -math.pi / 2 + i * math.pi / 5
				points[i + 1] = { cx + math.cos(angle) * r, cy + math.sin(angle) * r }
			end
			polyline(c, points, 1.35, col)
		end

		set.crosshair = function(c, col)
			ring(c, 8, 8, 4.4, col, 1.5)
			line(c, 8, 0.6, 8, 3, 1.5, col)
			line(c, 8, 13, 8, 15.4, 1.5, col)
			line(c, 0.6, 8, 3, 8, 1.5, col)
			line(c, 13, 8, 15.4, 8, 1.5, col)
		end

		set.target = function(c, col)
			ring(c, 8, 8, 6.2, col, 1.4)
			ring(c, 8, 8, 3.2, col, 1.4)
			dot(c, 8, 8, 1.1, col)
		end

		set.eye = function(c, col)
			outline(c, 0.9, 4.1, 14.2, 7.8, col, 1.35, 3.9)
			circle(c, 8, 8, 2.3, col)
		end

		set.bolt = function(c, col)
			polyline(c, {
				{ 9.8, 1.4 }, { 4.2, 8.8 }, { 7.6, 8.8 },
				{ 6.0, 14.6 }, { 11.6, 7.0 }, { 8.2, 7.0 }, { 9.8, 1.4 },
			}, 1.5, col)
		end

		set.bars = function(c, col)
			solid(c, 2.2, 9.2, 3.1, 5.6, col, 1.2)
			solid(c, 6.45, 5.4, 3.1, 9.4, col, 1.2)
			solid(c, 10.7, 1.6, 3.1, 13.2, col, 1.2)
		end

		set.gear = function(c, col)
			ring(c, 8, 8, 4.5, col, 1.5)
			ring(c, 8, 8, 1.7, col, 1.3)
			for i = 0, 7 do
				local angle = i * math.pi / 4
				local cos, sin = math.cos(angle), math.sin(angle)
				line(c, 8 + cos * 4.9, 8 + sin * 4.9, 8 + cos * 7.3, 8 + sin * 7.3, 1.6, col)
			end
		end

		set.search = function(c, col)
			ring(c, 6.5, 6.5, 3.7, col, 1.5)
			line(c, 9.2, 9.2, 14.2, 14.2, 1.8, col)
		end

		set.reset = function(c, col)
			local endPoint = arc(c, 8, 8.6, 5.4, math.rad(120), math.rad(400), col, 1.5)
			local tipX, tipY = endPoint[1], endPoint[2]
			local angle = math.rad(120)
			local tx, ty = math.cos(angle), math.sin(angle)
			local px, py = -ty, tx
			line(c, tipX, tipY, tipX + tx * 3.2 + px * 2.4, tipY + ty * 3.2 + py * 2.4, 1.5, col)
			line(c, tipX, tipY, tipX + tx * 3.2 - px * 2.4, tipY + ty * 3.2 - py * 2.4, 1.5, col)
		end

		set.close = function(c, col)
			line(c, 3.4, 3.4, 12.6, 12.6, 1.8, col)
			line(c, 12.6, 3.4, 3.4, 12.6, 1.8, col)
		end

		set.minimize = function(c, col)
			line(c, 3.2, 8, 12.8, 8, 1.8, col)
		end

		set.maximize = function(c, col)
			outline(c, 3.4, 3.4, 9.2, 9.2, col, 1.5, 1.6)
		end

		set.cube = function(c, col)
			polyline(c, { { 8, 1.8 }, { 14, 5.4 }, { 8, 9 }, { 2, 5.4 }, { 8, 1.8 } }, 1.4, col)
			line(c, 2, 5.4, 2, 11.6, 1.4, col)
			line(c, 14, 5.4, 14, 11.6, 1.4, col)
			polyline(c, { { 2, 11.6 }, { 8, 15.2 }, { 14, 11.6 } }, 1.4, col)
		end

		set.sun = function(c, col)
			ring(c, 8, 8, 3.3, col, 1.4)
			for i = 0, 7 do
				local angle = i * math.pi / 4
				local cos, sin = math.cos(angle), math.sin(angle)
				line(c, 8 + cos * 4.6, 8 + sin * 4.6, 8 + cos * 6.9, 8 + sin * 6.9, 1.5, col)
			end
		end

		set.shield = function(c, col)
			polyline(c, {
				{ 8, 1.4 }, { 13.6, 3.9 }, { 13.6, 8.4 },
				{ 8, 14.6 }, { 2.4, 8.4 }, { 2.4, 3.9 }, { 8, 1.4 },
			}, 1.45, col)
			polyline(c, { { 5.6, 8 }, { 7.3, 9.8 }, { 10.7, 6.2 } }, 1.45, col)
		end

		set.person = function(c, col)
			ring(c, 8, 4.4, 2.7, col, 1.45)
			polyline(c, { { 3.4, 14 }, { 4.4, 10.6 }, { 8, 9.2 }, { 11.6, 10.6 }, { 12.6, 14 } }, 1.45, col)
		end

		set.clock = function(c, col)
			ring(c, 8, 8, 6.3, col, 1.45)
			line(c, 8, 8, 8, 4.2, 1.45, col)
			line(c, 8, 8, 10.9, 9.6, 1.45, col)
		end

		set.moon = function(c, col, mask)
			circle(c, 8.2, 8, 5.6, col)
			local maskFrame = circle(c, 11.2, 5.8, 4.6, mask)
			maskFrame.Name = "Mask"
		end

		set.check = function(c, col)
			polyline(c, { { 3.2, 8.4 }, { 6.7, 12 }, { 12.8, 4 } }, 1.8, col)
		end

		set.chevronRight = function(c, col)
			polyline(c, { { 5.6, 3 }, { 10.6, 8 }, { 5.6, 13 } }, 1.7, col)
		end

		set.sparkles = function(c, col)
			line(c, 5.4, 2.4, 5.4, 8.4, 1.5, col)
			line(c, 2.4, 5.4, 8.4, 5.4, 1.5, col)
			line(c, 11, 7.4, 11, 12.4, 1.4, col)
			line(c, 8.5, 9.9, 13.5, 9.9, 1.4, col)
			dot(c, 12.2, 3.4, 1.1, col)
		end

		set.speed = function(c, col)
			polyline(c, { { 4.6, 3 }, { 9, 8 }, { 4.6, 13 } }, 1.7, col)
			polyline(c, { { 9.6, 3 }, { 14, 8 }, { 9.6, 13 } }, 1.7, col)
		end

		set.cpu = function(c, col)
			outline(c, 3.4, 3.4, 9.2, 9.2, col, 1.45, 1.6)
			outline(c, 6.2, 6.2, 3.6, 3.6, col, 1.3, 0.8)
			for i = 1, 3 do
				local offset = 4.4 + (i - 1) * 3.6
				line(c, offset, 1.2, offset, 3.4, 1.3, col)
				line(c, offset, 12.6, offset, 14.8, 1.3, col)
			end
		end

		set.camera = function(c, col)
			outline(c, 1.8, 4.4, 12.4, 8.4, col, 1.45, 1.8)
			ring(c, 8, 8.6, 2.4, col, 1.35)
			solid(c, 5.4, 2.4, 5.2, 2.1, col, 0.8)
		end

		set.folder = function(c, col)
			polyline(c, { { 1.8, 13.2 }, { 1.8, 3.2 }, { 6.4, 3.2 }, { 7.9, 5 }, { 14.2, 5 }, { 14.2, 13.2 }, { 1.8, 13.2 } }, 1.45, col)
		end

		set.tag = function(c, col)
			polyline(c, { { 1.8, 8.2 }, { 8.4, 1.8 }, { 14.2, 1.8 }, { 14.2, 7.6 }, { 7.8, 14.2 }, { 1.8, 8.2 } }, 1.4, col)
			dot(c, 10.9, 5, 1.3, col)
		end

		set.logo = function(c, col)
			ring(c, 8, 8.6, 6.1, col, 1.7)
			dot(c, 5.7, 7.2, 1.25, col)
			dot(c, 10.3, 7.2, 1.25, col)
			polyline(c, { { 5.1, 10.6 }, { 6.6, 12.2 }, { 9.4, 12.2 }, { 10.9, 10.6 } }, 1.5, col)
			line(c, 8, 1.4, 8, 2.6, 1.4, col)
			line(c, 2.2, 4.6, 3.2, 5.4, 1.4, col)
			line(c, 13.8, 4.6, 12.8, 5.4, 1.4, col)
		end

		set.dot = function(c, col)
			dot(c, 8, 8, 3.4, col)
		end

		return set
	end

	local DRAW = glyphs()

	function Icons.has(name)
		return DRAW[name] ~= nil
	end

	function Icons.SetColor(container, color)
		for _, object in ipairs(container:GetDescendants()) do
			if object:IsA("Frame") and object.Name ~= "Mask" then
				object.BackgroundColor3 = color
			elseif object:IsA("UIStroke") then
				object.Color = color
			end
		end
	end

	function Icons.create(parent, name, size, color, maskColor)
		local container = Instance.new("Frame")
		container.Name = "Icon_" .. tostring(name)
		container.BackgroundTransparency = 1
		container.BorderSizePixel = 0
		container.Size = UDim2.fromOffset(size, size)
		container.Parent = parent

		unit = size / BOX
		local draw = DRAW[name] or DRAW.dot
		draw(container, color or Color3.new(1, 1, 1), maskColor or color or Color3.new(1, 1, 1))
		unit = 1

		return container
	end

	return Icons

end

-- ===== Registry.lua =====
__modules["Registry"] = function()
	--[[
		Zolaris-Client :: Registry
		Single source of truth for every feature row shown in the panel.
		Records can live on several tabs at once, which is how the Home page mirrors
		handfuls of features from the other sections without duplicating state.
	]]

	local Registry = {}

	Registry.Records = {}
	Registry.Order = {}
	Registry.ById = {}
	Registry.Listeners = {}

	local function emit(record)
		for _, listener in ipairs(Registry.Listeners) do
			listener(record)
		end
	end

	function Registry.OnChanged(listener)
		table.insert(Registry.Listeners, listener)
	end

	function Registry.Add(spec)
		spec = spec or {}
		local id = spec.id or string.format("feature_%d", #Registry.Order + 1)
		local tabs = spec.tabs or { spec.tab or "Home" }

		local kind = spec.kind or "toggle"
		local defaultValue = spec.value
		if defaultValue == nil then
			defaultValue = spec.default
		end
		if defaultValue == nil then
			defaultValue = kind == "slider" and (spec.min or 0) or false
		end

		local record = {
			Id = id,
			Tabs = tabs,
			Tab = tabs[1],
			Title = spec.title or "Feature",
			Description = spec.description or "",
			Icon = spec.icon or "bolt",
			Kind = kind,
			Value = defaultValue,
			Default = defaultValue,
			HasOverride = false,
			FavoriteChanged = false,
			Min = spec.min,
			Max = spec.max,
			Step = spec.step,
			Format = spec.format,
			Callback = spec.callback,
			Views = {},
		}

		Registry.Records[id] = record
		Registry.ById[id] = record
		table.insert(Registry.Order, record)

		return record
	end

	function Registry.Get(id)
		return Registry.ById[id]
	end

	function Registry.List(tab)
		local list = {}
		for _, record in ipairs(Registry.Order) do
			for _, tabName in ipairs(record.Tabs) do
				if tabName == tab then
					table.insert(list, record)
					break
				end
			end
		end
		return list
	end

	function Registry.Count()
		return #Registry.Order
	end

	function Registry.SetValue(id, value, silent)
		local record = Registry.ById[id]
		if not record then
			return
		end
		record.Value = value
		if not silent then
			record.HasOverride = true
		end
		emit(record)
	end

	function Registry.Toggle(id)
		local record = Registry.ById[id]
		if not record then
			return
		end
		Registry.SetValue(id, not record.Value)
	end

	function Registry.SetFavorite(id, favorite)
		local record = Registry.ById[id]
		if not record then
			return
		end
		record.Favorite = favorite and true or false
		record.FavoriteChanged = true
		emit(record)
	end

	function Registry.IsFavorite(id)
		local record = Registry.ById[id]
		return record and record.Favorite == true
	end

	function Registry.Favorites()
		local list = {}
		for _, record in ipairs(Registry.Order) do
			if record.Favorite then
				table.insert(list, record)
			end
		end
		return list
	end

	function Registry.Reset()
		for _, record in ipairs(Registry.Order) do
			record.Value = record.Default
			record.Favorite = false
			emit(record)
		end
	end

	return Registry

end

-- ===== Theme.lua =====
__modules["Theme"] = function()
	--[[
		Zolaris-Client :: Theme
		Palette, typography and layout metrics lifted 1:1 from Zolaris-Client_WPF.xaml
		Every colour below maps to a hex stop that exists in the WPF document.
	]]

	local Theme = {}

	Theme.Window = {
		Width = 920,
		Height = 557,
		Radius = 14,
		ShadowOffset = 10,
	}

	Theme.Sidebar = {
		Width = 190,
		Height = 540,
		Offset = 8,
		Radius = 12,
		Padding = 12,
	}

	Theme.Content = {
		OffsetX = 222,
		Top = 76,
		Width = 671,
		CardHeight = 70,
		CardGap = 23,
		PaddingTop = 9,
		PaddingBottom = 18,
	}

	Theme.Colors = {
		-- window gradient: #3C3542 -> #302B37 -> #221F28
		WindowTop = Color3.fromRGB(60, 53, 66),
		WindowMid = Color3.fromRGB(48, 43, 55),
		WindowBottom = Color3.fromRGB(34, 31, 40),

		-- sidebar gradient: #2B2734 -> #1E1B25
		SidebarTop = Color3.fromRGB(43, 39, 52),
		SidebarBottom = Color3.fromRGB(30, 27, 37),

		-- panel fills
		Panel = Color3.fromRGB(38, 35, 48),
		SearchBg = Color3.fromRGB(36, 32, 48),
		Glass = Color3.fromRGB(255, 255, 255),

		-- accent ramp
		Accent = Color3.fromRGB(130, 80, 240),
		AccentLight = Color3.fromRGB(167, 139, 250),
		AccentSoft = Color3.fromRGB(196, 181, 253),
		AccentDeep = Color3.fromRGB(109, 40, 217),
		AccentDark = Color3.fromRGB(91, 33, 182),

		-- gradients
		LogoTop = Color3.fromRGB(196, 181, 253),
		LogoBottom = Color3.fromRGB(124, 58, 237),
		IconTop = Color3.fromRGB(183, 148, 246),
		IconBottom = Color3.fromRGB(109, 40, 217),
		TabActiveTop = Color3.fromRGB(139, 92, 246),
		TabActiveBottom = Color3.fromRGB(109, 40, 217),
		HoverTop = Color3.fromRGB(139, 92, 246),
		HoverBottom = Color3.fromRGB(109, 40, 217),

		-- text ramp
		TextPrimary = Color3.fromRGB(247, 245, 255),
		TextTitle = Color3.fromRGB(244, 241, 250),
		TextSecondary = Color3.fromRGB(184, 177, 198),
		TextMuted = Color3.fromRGB(148, 140, 163),
		TextDim = Color3.fromRGB(139, 132, 153),

		-- status
		Danger = Color3.fromRGB(248, 113, 113),
		Warning = Color3.fromRGB(251, 191, 36),
		Success = Color3.fromRGB(52, 211, 153),
	}

	Theme.Fonts = {
		Regular = Enum.Font.Gotham,
		Medium = Enum.Font.GothamMedium,
		SemiBold = Enum.Font.GothamSemibold,
		Bold = Enum.Font.GothamBold,
		Black = Enum.Font.GothamBlack,
	}

	Theme.Text = {
		WindowTitle = 20,
		BrandTitle = 17,
		BrandSubtitle = 8,
		CardTitle = 13,
		CardDescription = 10,
		TabLabel = 11,
		SidebarTitle = 11,
		Search = 10,
		ConfigLabel = 8,
		ConfigTier = 12,
		ConfigMeta = 9,
		Fps = 10,
		FpsValue = 11,
		SectionTitle = 13,
		Body = 11,
		Small = 9,
	}

	Theme.Sizes = {
		LogoBox = 38,
		SearchHeight = 32,
		TabHeight = 34,
		TabGap = 40,
		TabIcon = 14,
		CardIconBox = 40,
		CardIcon = 18,
		ToggleWidth = 55,
		ToggleHeight = 20,
		ToggleKnob = 14,
		FpsPillWidth = 153,
		FpsPillHeight = 31,
		WindowControlWidth = 88,
		WindowControlHeight = 31,
		ToastWidth = 260,
		ToastHeight = 38,
	}

	Theme.Accents = {
		{ Name = "Violet", Color = Color3.fromRGB(130, 80, 240) },
		{ Name = "Indigo", Color = Color3.fromRGB(99, 102, 241) },
		{ Name = "Fuchsia", Color = Color3.fromRGB(217, 70, 239) },
		{ Name = "Cyan", Color = Color3.fromRGB(34, 211, 238) },
		{ Name = "Emerald", Color = Color3.fromRGB(16, 185, 129) },
		{ Name = "Amber", Color = Color3.fromRGB(245, 158, 11) },
		{ Name = "Rose", Color = Color3.fromRGB(244, 63, 94) },
	}

	return Theme

end

-- ===== UIKit.lua =====
__modules["UIKit"] = function()
	--[[
		Zolaris-Client :: UIKit
		Reusable widget factory shared by every panel surface.
		Nothing in here knows about the client layout, it only knows how to build parts.
	]]

	local TweenService = game:GetService("TweenService")
	local UserInputService = game:GetService("UserInputService")

	local Icons = __require("Icons")
	local Theme = __require("Theme")

	local UIKit = {}

	local fadeCache = setmetatable({}, { __mode = "k" })
	local fadeTweens = setmetatable({}, { __mode = "k" })
	local userConnections = {}

	function UIKit.corner(instance, radius)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, radius)
		corner.Parent = instance
		return corner
	end

	function UIKit.stroke(instance, color, transparency, thickness)
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Transparency = transparency or 0
		stroke.Thickness = thickness or 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = instance
		return stroke
	end

	function UIKit.gradient(instance, from, to, rotation)
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new(from, to)
		gradient.Rotation = rotation or 90
		gradient.Parent = instance
		return gradient
	end

	function UIKit.frame(parent, props)
		props = props or {}
		local frame = Instance.new("Frame")
		frame.Name = props.Name or "Frame"
		frame.Size = props.Size or UDim2.fromScale(1, 1)
		frame.Position = props.Position or UDim2.fromOffset(0, 0)
		frame.BackgroundColor3 = props.BackgroundColor3 or Theme.Colors.Panel
		frame.BackgroundTransparency = props.BackgroundTransparency or 0
		frame.BorderSizePixel = 0
		frame.ZIndex = props.ZIndex or 1
		frame.Visible = props.Visible ~= false
		frame.ClipsDescendants = props.ClipsDescendants == true
		if props.AnchorPoint then
			frame.AnchorPoint = props.AnchorPoint
		end
		if props.Rotation then
			frame.Rotation = props.Rotation
		end
		if props.Parent then
			frame.Parent = props.Parent
		end
		if props.CornerRadius then
			UIKit.corner(frame, props.CornerRadius)
		end
		if props.Stroke then
			UIKit.stroke(frame, props.Stroke.Color, props.Stroke.Transparency, props.Stroke.Thickness)
		end
		if props.Gradient then
			UIKit.gradient(frame, props.Gradient[1], props.Gradient[2], props.Gradient[3])
		end
		return frame
	end

	function UIKit.label(parent, props)
		props = props or {}
		local label = Instance.new("TextLabel")
		label.Name = props.Name or "Label"
		label.Size = props.Size or UDim2.fromOffset(120, 18)
		label.Position = props.Position or UDim2.fromOffset(0, 0)
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Font = props.Font or Theme.Fonts.Regular
		label.Text = props.Text or ""
		label.TextSize = props.TextSize or Theme.Text.Body
		label.TextColor3 = props.TextColor3 or Theme.Colors.TextPrimary
		label.TextTransparency = props.TextTransparency or 0
		label.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
		label.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
		label.TextTruncate = props.TextTruncate or Enum.TextTruncate.None
		label.TextWrapped = props.TextWrapped == true
		label.TextStrokeTransparency = 1
		label.RichText = props.RichText == true
		label.ZIndex = props.ZIndex or 1
		label.Visible = props.Visible ~= false
		if props.Parent then
			label.Parent = props.Parent
		end
		return label
	end

	function UIKit.button(parent, props)
		props = props or {}
		local button = Instance.new("TextButton")
		button.Name = props.Name or "Button"
		button.Size = props.Size or UDim2.fromOffset(120, 30)
		button.Position = props.Position or UDim2.fromOffset(0, 0)
		button.BackgroundColor3 = props.BackgroundColor3 or Theme.Colors.Panel
		button.BackgroundTransparency = props.BackgroundTransparency or 0
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Font = props.Font or Theme.Fonts.Medium
		button.Text = props.Text or ""
		button.TextSize = props.TextSize or Theme.Text.Body
		button.TextColor3 = props.TextColor3 or Theme.Colors.TextPrimary
		button.TextTransparency = props.TextTransparency or 0
		button.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center
		button.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
		button.TextWrapped = props.TextWrapped == true
		button.TextTruncate = props.TextTruncate or Enum.TextTruncate.None
		button.TextStrokeTransparency = 1
		button.ZIndex = props.ZIndex or 1
		button.Visible = props.Visible ~= false
		if props.AnchorPoint then
			button.AnchorPoint = props.AnchorPoint
		end
		if props.Parent then
			button.Parent = props.Parent
		end
		if props.CornerRadius then
			UIKit.corner(button, props.CornerRadius)
		end
		if props.Stroke then
			UIKit.stroke(button, props.Stroke.Color, props.Stroke.Transparency, props.Stroke.Thickness)
		end
		if props.Gradient then
			UIKit.gradient(button, props.Gradient[1], props.Gradient[2], props.Gradient[3])
		end
		return button
	end

	function UIKit.textbox(parent, props)
		props = props or {}
		local box = Instance.new("TextBox")
		box.Name = props.Name or "TextBox"
		box.Size = props.Size or UDim2.fromOffset(120, 24)
		box.Position = props.Position or UDim2.fromOffset(0, 0)
		box.BackgroundTransparency = 1
		box.BorderSizePixel = 0
		box.ClearTextOnFocus = false
		box.Font = props.Font or Theme.Fonts.Regular
		box.Text = props.Text or ""
		box.TextSize = props.TextSize or Theme.Text.Search
		box.TextColor3 = props.TextColor3 or Theme.Colors.TextSecondary
		box.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
		box.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
		box.PlaceholderText = props.PlaceholderText or ""
		box.PlaceholderColor3 = props.PlaceholderColor3 or Theme.Colors.TextDim
		box.TextStrokeTransparency = 1
		box.ZIndex = props.ZIndex or 1
		if props.Parent then
			box.Parent = props.Parent
		end
		return box
	end

	function UIKit.icon(parent, name, size, color, maskColor)
		return Icons.create(parent, name, size, color, maskColor)
	end

	function UIKit.tween(object, goals, duration, style, direction)
		local info = TweenInfo.new(
			duration or 0.18,
			style or Enum.EasingStyle.Quad,
			direction or Enum.EasingDirection.Out
		)
		local tween = TweenService:Create(object, info, goals)
		tween:Play()
		return tween
	end

	function UIKit.hover(frame, onEnter, onLeave)
		frame.MouseEnter:Connect(function()
			onEnter()
		end)
		frame.MouseLeave:Connect(function()
			onLeave()
		end)
	end

	function UIKit.glow(parent, props)
		props = props or {}
		local color = props.Color or Theme.Colors.Accent
		local steps = props.Steps or 14
		local base = props.BaseSize or 90
		local step = props.Step or 14
		local innerTransparency = props.InnerTransparency or 0.72
		local outerTransparency = props.OuterTransparency or 0.97

		local holder = UIKit.frame(parent, {
			Name = "Glow",
			Size = props.Size or UDim2.fromOffset(base + step * steps, base + step * steps),
			Position = props.Position or UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			ZIndex = props.ZIndex or 1,
		})

		for i = 0, steps do
			local diameter = base + i * step
			local ratio = i / steps
			local transparency = innerTransparency + (outerTransparency - innerTransparency) * ratio
			local circle = UIKit.frame(holder, {
				Size = UDim2.fromOffset(diameter, diameter),
				Position = UDim2.fromOffset(-step * steps / 2, -step * steps / 2),
				BackgroundColor3 = color,
				BackgroundTransparency = transparency,
				CornerRadius = diameter / 2,
				ZIndex = props.ZIndex or 1,
			})
			circle.Name = "GlowStep" .. i
		end

		return holder
	end

	local function collectFadeTargets(root)
		local targets = {}
		local function visit(object)
			for _, child in ipairs(object:GetChildren()) do
				if child:IsA("GuiObject") then
					table.insert(targets, child)
					visit(child)
				elseif child:IsA("UIStroke") then
					table.insert(targets, child)
				end
			end
		end
		visit(root)
		return targets
	end

	function UIKit.fade(root, amount, duration)
		local previous = fadeTweens[root]
		if previous then
			for _, tween in ipairs(previous) do
				tween:Cancel()
			end
		end

		local tweens = {}
		local targets = collectFadeTargets(root)
		for _, object in ipairs(targets) do
			if not fadeCache[object] then
				local base = { background = 1, text = 1, image = 1, stroke = 1 }
				if object:IsA("GuiObject") then
					base.background = object.BackgroundTransparency
					if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
						base.text = object.TextTransparency
					end
					if object:IsA("ImageLabel") or object:IsA("ImageButton") then
						base.image = object.ImageTransparency
					end
				elseif object:IsA("UIStroke") then
					base.stroke = object.Transparency
				end
				fadeCache[object] = base
			end
		end

		for _, object in ipairs(targets) do
			local base = fadeCache[object]
			local goals = {}
			if object:IsA("GuiObject") then
				goals.BackgroundTransparency = math.clamp(base.background + amount, 0, 1)
				if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
					goals.TextTransparency = math.clamp(base.text + amount, 0, 1)
				end
				if object:IsA("ImageLabel") or object:IsA("ImageButton") then
					goals.ImageTransparency = math.clamp(base.image + amount, 0, 1)
				end
			elseif object:IsA("UIStroke") then
				goals.Transparency = math.clamp(base.stroke + amount, 0, 1)
			end
			local tween = TweenService:Create(
				object,
				TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				goals
			)
			tween:Play()
			table.insert(tweens, tween)
		end

		fadeTweens[root] = tweens
	end

	function UIKit.toggle(parent, props)
		props = props or {}
		local width = props.Width or Theme.Sizes.ToggleWidth
		local height = props.Height or Theme.Sizes.ToggleHeight
		local knobSize = props.KnobSize or Theme.Sizes.ToggleKnob

		local track = UIKit.frame(parent, {
			Name = "Toggle",
			Size = UDim2.fromOffset(width, height),
			Position = props.Position or UDim2.fromOffset(0, 0),
			BackgroundColor3 = Theme.Colors.Glass,
			BackgroundTransparency = 0.96,
			CornerRadius = height / 2,
			Stroke = { Color = Theme.Colors.Glass, Transparency = 0.85, Thickness = 1 },
			ZIndex = props.ZIndex or 3,
		})

		local knob = UIKit.frame(track, {
			Name = "Knob",
			Size = UDim2.fromOffset(knobSize, knobSize),
			Position = UDim2.fromOffset(3, (height - knobSize) / 2),
			BackgroundColor3 = Theme.Colors.TextDim,
			CornerRadius = knobSize / 2,
			ZIndex = (props.ZIndex or 3) + 1,
		})

		local state = {
			frame = track,
			knob = knob,
			On = false,
		}

		function state:Set(value, instant)
			state.On = value and true or false
			local targetX = state.On and (width - knobSize - 3) or 3
			local trackColor = state.On and Theme.Colors.Accent or Theme.Colors.Glass
			local trackTransparency = state.On and 0.08 or 0.96
			local knobColor = state.On and Theme.Colors.Glass or Theme.Colors.TextDim

			if instant then
				knob.Position = UDim2.fromOffset(targetX, (height - knobSize) / 2)
				track.BackgroundColor3 = trackColor
				track.BackgroundTransparency = trackTransparency
				knob.BackgroundColor3 = knobColor
				return
			end

			UIKit.tween(knob, { Position = UDim2.fromOffset(targetX, (height - knobSize) / 2) }, 0.18)
			UIKit.tween(track, {
				BackgroundColor3 = trackColor,
				BackgroundTransparency = trackTransparency,
			}, 0.18)
			UIKit.tween(knob, { BackgroundColor3 = knobColor }, 0.18)
		end

		return state
	end

	function UIKit.slider(parent, props)
		props = props or {}
		local width = props.Width or 150
		local min = props.Min or 0
		local max = props.Max or 100
		local step = props.Step or 1
		local value = props.Value or min

		local container = UIKit.frame(parent, {
			Name = "Slider",
			Size = UDim2.fromOffset(width, 26),
			Position = props.Position or UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			ZIndex = props.ZIndex or 3,
		})

		local track = UIKit.frame(container, {
			Name = "Track",
			Size = UDim2.fromOffset(width, 6),
			Position = UDim2.fromOffset(0, 10),
			BackgroundColor3 = Theme.Colors.Glass,
			BackgroundTransparency = 0.9,
			CornerRadius = 3,
			ZIndex = props.ZIndex or 3,
		})

		local fill = UIKit.frame(track, {
			Name = "Fill",
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Theme.Colors.Accent,
			BackgroundTransparency = 0.15,
			CornerRadius = 3,
			ZIndex = props.ZIndex or 3,
		})

		local knob = UIKit.frame(container, {
			Name = "Knob",
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.fromOffset(0, 6),
			BackgroundColor3 = Theme.Colors.Glass,
			CornerRadius = 7,
			Stroke = { Color = Theme.Colors.AccentLight, Transparency = 0.4, Thickness = 1 },
			ZIndex = (props.ZIndex or 3) + 1,
		})

		local state = {
			frame = container,
			track = track,
			knob = knob,
			Value = value,
			OnChanged = props.OnChanged,
		}

		local function apply(newValue, instant)
			newValue = math.clamp(newValue, min, max)
			newValue = math.floor(newValue / step + 0.5) * step
			newValue = math.clamp(newValue, min, max)
			state.Value = newValue
			local ratio = (max - min) == 0 and 0 or ((newValue - min) / (max - min))
			local knobX = ratio * (width - 14)
			if instant then
				knob.Position = UDim2.fromOffset(knobX, 6)
				fill.Size = UDim2.fromScale(ratio, 1)
			else
				UIKit.tween(knob, { Position = UDim2.fromOffset(knobX, 6) }, 0.12)
				UIKit.tween(fill, { Size = UDim2.fromScale(ratio, 1) }, 0.12)
			end
		end

		local function fromX(x)
			local ratio = math.clamp(x / width, 0, 1)
			apply(min + ratio * (max - min))
			if state.OnChanged then
				state.OnChanged(state.Value)
			end
		end

		track.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				fromX(input.Position.X - track.AbsolutePosition.X)
			end
		end)

		knob.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local dragging = true
			local connection
			connection = UserInputService.InputChanged:Connect(function(changed)
				if not dragging then
					return
				end
				if changed.UserInputType == Enum.UserInputType.MouseMovement or changed.UserInputType == Enum.UserInputType.Touch then
					fromX(changed.Position.X - track.AbsolutePosition.X)
				end
			end)
			table.insert(userConnections, function()
				connection:Disconnect()
			end)
		end)

		state.SetValue = apply
		apply(value, true)
		return state
	end

	userConnections = {}

	function UIKit.trackConnection(callback)
		table.insert(userConnections, callback)
	end

	function UIKit.disposeConnections()
		for _, callback in ipairs(userConnections) do
			pcall(callback)
		end
		for index = #userConnections, 1, -1 do
			userConnections[index] = nil
		end
	end

	return UIKit

end

-- ===== entry =====
--[[
	Zolaris-Client :: entry point
	Drop this LocalScript (and the src folder) into StarterPlayer > StarterPlayerScripts.
	Everything is code based, no instances are needed in the workspace.

	Runtime API (also published to getgenv/shared as `Zolaris`):
		Zolaris.AddFeatureCard("Combat", "Title", "Description", "bolt", function(enabled) end)
		Zolaris.AddTab("Exploit", "target")
		Zolaris.SetTab("Render")
		Zolaris.Notify("hello", "info")
]]

local Client = __require("Client")

local api = Client.Build()
api.api = api

local globals = (getgenv and getgenv()) or (shared and shared()) or nil
if globals then
	globals.Zolaris = api
end

return api

