--!nonstrict
-- Köşe bildirimleri ve sunucu duyuruları.
local TweenService = game:GetService("TweenService")

local Net = require(script.Parent.Parent.Controllers.Net)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local Toast = {}

local MAX_TOASTS = 4

function Toast.mount(parent: Instance)
	local stack = Widgets.frame({
		Name = "Toasts",
		Size = UDim2.fromOffset(300, 260),
		Position = UDim2.new(1, -16, 1, -120),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local layout = Widgets.list(Enum.FillDirection.Vertical, 6)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Parent = stack

	local banner = Widgets.frame({
		Name = "Announce",
		Size = UDim2.fromOffset(620, 44),
		Position = UDim2.new(0.5, 0, 0, 96),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.color.panelAlt,
		BackgroundTransparency = 1,
		Parent = parent,
	}, { Widgets.corner(10) })

	local bannerText = Widgets.text({
		Text = "",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.font.title,
		TextSize = 17,
		TextTransparency = 1,
		Parent = banner,
	})

	local nextOrder = 0

	local function show(text: string, kind: string)
		nextOrder += 1
		local card = Widgets.frame({
			Size = UDim2.fromOffset(290, 46),
			LayoutOrder = nextOrder,
			BackgroundColor3 = Theme.color.panel,
			Parent = stack,
		}, { Widgets.corner(8), Widgets.stroke(Theme.toastColor(kind)) })

		Widgets.text({
			Text = text,
			Size = UDim2.new(1, -20, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			TextWrapped = true,
			TextSize = 14,
			Parent = card,
		})

		while #stack:GetChildren() > MAX_TOASTS + 1 do
			local oldest = nil
			for _, child in stack:GetChildren() do
				if child:IsA("Frame") and (not oldest or child.LayoutOrder < oldest.LayoutOrder) then
					oldest = child
				end
			end
			if oldest then
				oldest:Destroy()
			else
				break
			end
		end

		task.delay(4.5, function()
			if card.Parent then
				TweenService:Create(card, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
				task.wait(0.35)
				card:Destroy()
			end
		end)
	end

	local announceQueue = {}
	local announcing = false

	local function drainAnnouncements()
		if announcing then
			return
		end
		announcing = true
		task.spawn(function()
			while #announceQueue > 0 do
				local entry = table.remove(announceQueue, 1)
				bannerText.Text = entry.text
				bannerText.TextColor3 = if entry.color
					then Color3.fromRGB(table.unpack(entry.color))
					else Theme.color.text
				TweenService:Create(banner, TweenInfo.new(0.25), { BackgroundTransparency = 0.1 }):Play()
				TweenService:Create(bannerText, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
				task.wait(3.5)
				TweenService:Create(banner, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
				TweenService:Create(bannerText, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
				task.wait(0.4)
			end
			announcing = false
		end)
	end

	Net.on("Toast", function(payload)
		show(payload.text, payload.kind or "info")
	end)

	Net.on("Announce", function(payload)
		table.insert(announceQueue, payload)
		drainAnnouncements()
	end)

	Net.on("Robbed", function(payload)
		local suffix = if payload.treasure then ` ve {payload.treasure} hazineni aldı!` else "!"
		table.insert(announceQueue, { text = `🚨 {payload.thief} kasanı soydu{suffix}`, color = { 255, 84, 108 } })
		drainAnnouncements()
	end)

	return { show = show }
end

return Toast
