--!nonstrict
-- Sürekli ekranda duran kısım: para, birikim, event sayacı, eğitim ipucu
-- ve panelleri açan alt bar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Core.Format)
local Net = require(script.Parent.Parent.Controllers.Net)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local Hud = {}

function Hud.mount(parent: Instance, panels: { [string]: any })
	-- Üst sol: para göstergeleri
	local stats = Widgets.frame({
		Name = "Stats",
		Size = UDim2.fromOffset(260, 86),
		Position = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Theme.color.panel,
		BackgroundTransparency = 0.1,
		Parent = parent,
	}, { Widgets.corner(12), Widgets.stroke() })

	local coinLabel = Widgets.text({
		Text = "0",
		Font = Theme.font.number,
		TextSize = 24,
		TextColor3 = Theme.color.coin,
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.fromOffset(12, 8),
		Parent = stats,
	})

	local incomeLabel = Widgets.text({
		Text = "0/sn",
		TextColor3 = Theme.color.textDim,
		TextSize = 13,
		Size = UDim2.new(1, -24, 0, 18),
		Position = UDim2.fromOffset(12, 38),
		Parent = stats,
	})

	local worthLabel = Widgets.text({
		Text = "Servet 0",
		TextColor3 = Theme.color.textDim,
		TextSize = 13,
		Size = UDim2.new(1, -24, 0, 18),
		Position = UDim2.fromOffset(12, 58),
		Parent = stats,
	})

	-- Sağ üst: kasa birikimi + topla
	local stash = Widgets.frame({
		Name = "Stash",
		Size = UDim2.fromOffset(240, 108),
		Position = UDim2.new(1, -16, 0, 16),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.color.panel,
		BackgroundTransparency = 0.1,
		Parent = parent,
	}, { Widgets.corner(12), Widgets.stroke() })

	Widgets.text({
		Text = "KASA BİRİKİMİ",
		TextColor3 = Theme.color.textDim,
		TextSize = 12,
		Size = UDim2.new(1, -24, 0, 16),
		Position = UDim2.fromOffset(12, 8),
		Parent = stash,
	})

	local stashLabel = Widgets.text({
		Text = "0",
		Font = Theme.font.number,
		TextSize = 22,
		Size = UDim2.new(1, -24, 0, 26),
		Position = UDim2.fromOffset(12, 24),
		Parent = stash,
	})

	local barHolder = Widgets.frame({
		Size = UDim2.new(1, -24, 0, 14),
		Position = UDim2.fromOffset(12, 52),
		BackgroundTransparency = 1,
		Parent = stash,
	})
	local _, setStashBar = Widgets.bar(barHolder, Theme.color.good)

	local collectButton = Widgets.button({
		Text = "TOPLA",
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.fromOffset(12, 70),
		BackgroundColor3 = Theme.color.good,
		Parent = stash,
	}, function()
		local response = Net.invoke("CollectStash")
		if not response.ok then
			warn(response.error)
		end
	end)

	-- Üst orta: aktif event
	local eventBanner = Widgets.frame({
		Name = "Event",
		Size = UDim2.fromOffset(420, 52),
		Position = UDim2.new(0.5, 0, 0, 16),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.color.panel,
		BackgroundTransparency = 0.1,
		Parent = parent,
	}, { Widgets.corner(12), Widgets.stroke() })

	local eventTitle = Widgets.text({
		Text = "",
		Font = Theme.font.title,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 22),
		Position = UDim2.fromOffset(10, 6),
		Parent = eventBanner,
	})

	local eventSub = Widgets.text({
		Text = "",
		TextColor3 = Theme.color.textDim,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.fromOffset(10, 28),
		Parent = eventBanner,
	})

	-- Eğitim ipucu: ilk 60 saniyenin yol göstericisi
	local tutorial = Widgets.frame({
		Name = "Tutorial",
		Size = UDim2.fromOffset(320, 64),
		Position = UDim2.fromOffset(16, 112),
		BackgroundColor3 = Theme.color.panel,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = parent,
	}, { Widgets.corner(12), Widgets.stroke(Theme.color.accent) })

	local tutorialTitle = Widgets.text({
		Text = "",
		Font = Theme.font.title,
		TextSize = 15,
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(12, 8),
		Parent = tutorial,
	})

	local tutorialHint = Widgets.text({
		Text = "",
		TextColor3 = Theme.color.textDim,
		TextSize = 13,
		TextWrapped = true,
		Size = UDim2.new(1, -20, 0, 32),
		Position = UDim2.fromOffset(12, 28),
		Parent = tutorial,
	})

	-- Alt bar: panel düğmeleri
	local dock = Widgets.frame({
		Name = "Dock",
		Size = UDim2.fromOffset(700, 52),
		Position = UDim2.new(0.5, 0, 1, -16),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Theme.color.panel,
		BackgroundTransparency = 0.1,
		Parent = parent,
	}, { Widgets.corner(12), Widgets.stroke() })

	local dockLayout = Widgets.list(Enum.FillDirection.Horizontal, 8)
	dockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	dockLayout.Parent = dock
	Widgets.padding(8).Parent = dock

	local buttons = {
		{ key = "crates", text = "Sandıklar" },
		{ key = "vault", text = "Kasam" },
		{ key = "defense", text = "Savunma" },
		{ key = "targets", text = "Soygun" },
		{ key = "shop", text = "Mağaza" },
		{ key = "leaderboard", text = "Sıralama" },
	}

	for index, entry in buttons do
		Widgets.button({
			Text = entry.text,
			Size = UDim2.fromOffset(106, 36),
			LayoutOrder = index,
			BackgroundColor3 = Theme.color.panelAlt,
			Parent = dock,
		}, function()
			for key, panel in panels do
				if key == entry.key then
					panel.toggle()
				else
					panel.setOpen(false)
				end
			end
			if entry.key == "targets" then
				State.refreshTargets()
			end
		end)
	end

	local function renderProfile(profile)
		if not profile then
			return
		end
		coinLabel.Text = `🪙 {Format.short(profile.coins)}`
		incomeLabel.Text = `{Format.short(profile.incomePerSecond)}/sn · {profile.tokens} jeton`
		worthLabel.Text = `Servet {Format.short(profile.netWorth)} · {profile.rebirths} rebirth`

		stashLabel.Text = Format.short(profile.stash)
		setStashBar(if profile.stashCap > 0 then profile.stash / profile.stashCap else 0)
		collectButton.Text = if profile.stash > 0 then `TOPLA ({Format.short(profile.stash)})` else "TOPLA"

		if profile.shieldSecondsLeft > 0 then
			stash.BackgroundColor3 = Theme.color.panel
			stashLabel.TextColor3 = Theme.color.good
		else
			stashLabel.TextColor3 = Theme.color.text
		end
	end

	local function renderEvent(event)
		if not event then
			return
		end
		local color = Color3.fromRGB(table.unpack(event.color))
		if event.phase == "active" then
			eventTitle.Text = `⚡ {event.name}`
			eventTitle.TextColor3 = color
			eventSub.Text = `{event.tagline}  ·  {Format.time(event.secondsLeft)}`
			eventBanner.Visible = true
		elseif event.phase == "warning" then
			eventTitle.Text = `{event.name} yaklaşıyor`
			eventTitle.TextColor3 = Theme.color.textDim
			eventSub.Text = `{Format.time(event.secondsLeft)} sonra başlıyor`
			eventBanner.Visible = true
		else
			eventTitle.Text = "Sıradaki event"
			eventTitle.TextColor3 = Theme.color.textDim
			eventSub.Text = `{event.name} · {Format.time(event.secondsLeft)}`
			eventBanner.Visible = true
		end
	end

	local function renderTutorial(payload)
		if not payload or payload.done then
			tutorial.Visible = false
			return
		end
		tutorial.Visible = true
		tutorialTitle.Text = `{payload.step}/{payload.total} · {payload.title}`
		tutorialHint.Text = payload.hint
	end

	State.Changed:connect(renderProfile)
	State.EventChanged:connect(renderEvent)
	State.TutorialChanged:connect(renderTutorial)
	renderProfile(State.profile)
	renderEvent(State.event)
	renderTutorial(State.tutorial)

	return { collectButton = collectButton }
end

return Hud
