--!nonstrict
-- Liderlik tabloları.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Core.Format)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local LeaderboardPanel = {}

function LeaderboardPanel.mount(parent: Instance)
	local panel = Widgets.panel(parent, "Sıralama", UDim2.fromOffset(560, 480))

	local body = Widgets.frame({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = panel.content,
		ZIndex = 6,
	})
	Widgets.list(Enum.FillDirection.Vertical, 10).Parent = body

	local function render(boards)
		body:ClearAllChildren()
		Widgets.list(Enum.FillDirection.Vertical, 10).Parent = body

		if not boards or #boards == 0 then
			Widgets.text({
				Text = "Tablolar hazırlanıyor...",
				TextColor3 = Theme.color.textDim,
				Size = UDim2.new(1, 0, 0, 20),
				Parent = body,
				ZIndex = 6,
			})
			return
		end

		for _, board in boards do
			Widgets.text({
				Text = board.title,
				Font = Theme.font.title,
				TextSize = 15,
				Size = UDim2.new(1, 0, 0, 22),
				Parent = body,
				ZIndex = 6,
			})

			if #board.entries == 0 then
				Widgets.text({
					Text = "Henüz kimse yok. İlk sen ol.",
					TextColor3 = Theme.color.textDim,
					TextSize = 13,
					Size = UDim2.new(1, 0, 0, 18),
					Parent = body,
					ZIndex = 6,
				})
			end

			for _, entry in board.entries do
				local row = Widgets.frame({
					Size = UDim2.new(1, 0, 0, 28),
					BackgroundColor3 = Theme.color.panelAlt,
					Parent = body,
					ZIndex = 6,
				}, { Widgets.corner(6) })

				Widgets.text({
					Text = `#{entry.rank}  {entry.name}`,
					TextSize = 13,
					Size = UDim2.new(1, -120, 1, 0),
					Position = UDim2.fromOffset(10, 0),
					Parent = row,
					ZIndex = 7,
				})

				Widgets.text({
					Text = Format.short(entry.value),
					TextSize = 13,
					TextColor3 = Theme.color.coin,
					TextXAlignment = Enum.TextXAlignment.Right,
					Size = UDim2.fromOffset(100, 28),
					Position = UDim2.new(1, -110, 0, 0),
					Parent = row,
					ZIndex = 7,
				})
			end
		end
	end

	State.LeaderboardChanged:connect(render)
	render(State.leaderboard)
	return panel
end

return LeaderboardPanel
