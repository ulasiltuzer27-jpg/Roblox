--!nonstrict
-- Soygun ekranı: alarm çubuğu, süre, ilerleme, kapı kilidi ve sonuç kartı.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage.Shared.Core.Format)
local Layout = require(ReplicatedStorage.Shared.Core.Layout)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local HeistOverlay = {}

function HeistOverlay.mount(parent: Instance, callbacks: { abort: () -> (), door: () -> () })
	local root = Widgets.frame({
		Name = "Heist",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
		ZIndex = 10,
	})

	-- Üst bilgi: hedef, süre
	local top = Widgets.frame({
		Size = UDim2.fromOffset(420, 64),
		Position = UDim2.new(0.5, 0, 0, 16),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.color.panel,
		BackgroundTransparency = 0.15,
		Parent = root,
		ZIndex = 11,
	}, { Widgets.corner(12), Widgets.stroke(Theme.color.bad) })

	local targetLabel = Widgets.text({
		Text = "",
		Font = Theme.font.title,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 24),
		Position = UDim2.fromOffset(10, 6),
		Parent = top,
		ZIndex = 12,
	})

	local timerLabel = Widgets.text({
		Text = "",
		TextColor3 = Theme.color.textDim,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(10, 32),
		Parent = top,
		ZIndex = 12,
	})

	-- Alt: alarm + ilerleme
	local bottom = Widgets.frame({
		Size = UDim2.fromOffset(520, 96),
		Position = UDim2.new(0.5, 0, 1, -16),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Theme.color.panel,
		BackgroundTransparency = 0.15,
		Parent = root,
		ZIndex = 11,
	}, { Widgets.corner(12), Widgets.stroke() })

	local alarmText = Widgets.text({
		Text = "ALARM",
		TextSize = 12,
		TextColor3 = Theme.color.textDim,
		Size = UDim2.new(1, -24, 0, 16),
		Position = UDim2.fromOffset(12, 8),
		Parent = bottom,
		ZIndex = 12,
	})

	local alarmHolder = Widgets.frame({
		Size = UDim2.new(1, -24, 0, 14),
		Position = UDim2.fromOffset(12, 26),
		BackgroundTransparency = 1,
		Parent = bottom,
		ZIndex = 12,
	})
	local _, setAlarm = Widgets.bar(alarmHolder, Theme.color.alarm)

	local progressHolder = Widgets.frame({
		Size = UDim2.new(1, -24, 0, 10),
		Position = UDim2.fromOffset(12, 50),
		BackgroundTransparency = 1,
		Parent = bottom,
		ZIndex = 12,
	})
	local _, setProgress = Widgets.bar(progressHolder, Theme.color.good)

	local modeLabel = Widgets.text({
		Text = "",
		TextSize = 12,
		TextColor3 = Theme.color.textDim,
		Size = UDim2.new(1, -24, 0, 16),
		Position = UDim2.fromOffset(12, 68),
		Parent = bottom,
		ZIndex = 12,
	})

	Widgets.button({
		Text = "Vazgeç",
		Size = UDim2.fromOffset(86, 26),
		Position = UDim2.new(1, -98, 0, 64),
		BackgroundColor3 = Theme.color.panelAlt,
		Parent = bottom,
		ZIndex = 12,
	}, callbacks.abort)

	-- Kapı kilidi mini oyunu
	local door = Widgets.frame({
		Size = UDim2.fromOffset(420, 110),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.color.panel,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = root,
		ZIndex = 12,
	}, { Widgets.corner(12), Widgets.stroke(Theme.color.accent) })

	local doorTitle = Widgets.text({
		Text = "KASA KAPISI",
		Font = Theme.font.title,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(10, 8),
		Parent = door,
		ZIndex = 13,
	})

	local track = Widgets.frame({
		Size = UDim2.new(1, -40, 0, 26),
		Position = UDim2.fromOffset(20, 34),
		BackgroundColor3 = Theme.color.panelAlt,
		Parent = door,
		ZIndex = 13,
	}, { Widgets.corner(6) })

	local zone = Widgets.frame({
		Size = UDim2.fromScale(0.2, 1),
		Position = UDim2.fromScale(0.4, 0),
		BackgroundColor3 = Theme.color.good,
		BackgroundTransparency = 0.35,
		Parent = track,
		ZIndex = 14,
	}, { Widgets.corner(6) })

	local marker = Widgets.frame({
		Size = UDim2.new(0, 4, 1, 4),
		Position = UDim2.fromScale(0, 0),
		AnchorPoint = Vector2.new(0.5, 0.05),
		BackgroundColor3 = Theme.color.text,
		Parent = track,
		ZIndex = 15,
	}, { Widgets.corner(2) })

	Widgets.button({
		Text = "[E] KIR",
		Size = UDim2.new(1, -40, 0, 30),
		Position = UDim2.fromOffset(20, 68),
		BackgroundColor3 = Theme.color.accent,
		Parent = door,
		ZIndex = 13,
	}, callbacks.door)

	-- Sonuç kartı
	local result = Widgets.frame({
		Size = UDim2.fromOffset(420, 200),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.color.panel,
		Visible = false,
		Parent = parent,
		ZIndex = 20,
	}, { Widgets.corner(14), Widgets.stroke() })

	local resultTitle = Widgets.text({
		Text = "",
		Font = Theme.font.title,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.fromOffset(10, 18),
		Parent = result,
		ZIndex = 21,
	})

	local resultBody = Widgets.text({
		Text = "",
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -40, 0, 90),
		Position = UDim2.fromOffset(20, 62),
		Parent = result,
		ZIndex = 21,
	})

	Widgets.button({
		Text = "Tamam",
		Size = UDim2.fromOffset(160, 34),
		Position = UDim2.new(0.5, -80, 1, -46),
		Parent = result,
		ZIndex = 21,
	}, function()
		result.Visible = false
	end)

	local state = { doorStartedAt = 0, doorWindow = 1, atDoor = false }

	local connection = RunService.RenderStepped:Connect(function()
		if not state.atDoor or not root.Visible then
			return
		end
		local elapsed = Workspace:GetServerTimeNow() - state.doorStartedAt
		local alpha = Layout.doorMarker(elapsed)
		marker.Position = UDim2.fromScale(alpha, 0)
	end)

	local overlay = {}

	function overlay.start(payload)
		root.Visible = true
		result.Visible = false
		state.atDoor = false
		door.Visible = false
		targetLabel.Text = `{payload.targetName} kasası`
		timerLabel.Text = `Savunma {payload.defenseScore} · Birikim {Format.short(payload.stash)}`
		setAlarm(0)
		setProgress(0)
	end

	function overlay.tick(payload)
		setAlarm(payload.alarm / payload.alarmCapacity)
		setProgress(payload.progress)
		timerLabel.Text = `{Format.time(payload.secondsLeft)} · alarm %{math.floor(payload.alarm)}`
		alarmText.Text = if payload.alarm > 70 then "ALARM — ÇEKİL!" else "ALARM"
		alarmText.TextColor3 = if payload.alarm > 70 then Theme.color.bad else Theme.color.textDim

		local modeText = ({ sneak = "Sinsi (yavaş, sessiz)", walk = "Normal", sprint = "Koşu (gürültülü)" })[payload.mode]
		modeLabel.Text = `{modeText}  ·  Ctrl: sinsi, Shift: koşu{if payload.rooted then "  ·  KAPANA SIKIŞTIN" else ""}`

		state.atDoor = payload.atDoor
		state.doorStartedAt = payload.doorStartedAt
		state.doorWindow = payload.doorWindow
		door.Visible = payload.atDoor

		if payload.atDoor then
			local halfWidth = Layout.doorHalfWidth(payload.doorWindow)
			zone.Size = UDim2.fromScale(halfWidth * 2, 1)
			zone.Position = UDim2.fromScale(0.5 - halfWidth, 0)
			doorTitle.Text = `KASA KAPISI · kilit {payload.doorStage}/{payload.doorStages}`
		end
	end

	function overlay.finish(payload)
		root.Visible = false
		state.atDoor = false
		result.Visible = true

		if payload.success then
			resultTitle.Text = if payload.perfect then "MÜKEMMEL SOYGUN" else "SOYGUN BAŞARILI"
			resultTitle.TextColor3 = Theme.color.good
			local lines = {
				`{payload.targetName} kasasından <b>{Format.short(payload.coins)}</b> coin aldın.`,
				`Pay: %{math.floor(payload.share * 100)} · Süre: {payload.durationSeconds} sn`,
			}
			if payload.treasureName then
				table.insert(lines, `Ayrıca <b>{payload.treasureName}</b> hazinesini kaptın!`)
			end
			resultBody.Text = table.concat(lines, "\n")
		else
			local reasons = {
				caught = "Yakalandın! Bekçiler seni hapse attı.",
				timeout = "Süre doldu, kasadan elin boş çıktın.",
				aborted = "Soygunu bıraktın.",
				down = "Karakterin dayanamadı.",
				left = "Soygun yarıda kaldı.",
				error = "Bir şeyler ters gitti.",
			}
			resultTitle.Text = "SOYGUN BAŞARISIZ"
			resultTitle.TextColor3 = Theme.color.bad
			local text = reasons[payload.reason] or "Soygun başarısız."
			if payload.jailSecondsLeft > 0 then
				text ..= `\nHapis: {Format.time(payload.jailSecondsLeft)}`
			end
			resultBody.Text = text
		end

		result.BackgroundTransparency = 1
		TweenService:Create(result, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
	end

	function overlay.isActive(): boolean
		return root.Visible
	end

	function overlay.destroy()
		connection:Disconnect()
	end

	return overlay
end

return HeistOverlay
