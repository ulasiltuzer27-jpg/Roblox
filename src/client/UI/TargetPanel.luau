--!nonstrict
-- Soygun panosu: soyulabilir kasalar, birikimleri ve savunma güçleri.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Core.Format)
local Net = require(script.Parent.Parent.Controllers.Net)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local TargetPanel = {}

function TargetPanel.mount(parent: Instance)
	local panel = Widgets.panel(parent, "Soygun Panosu", UDim2.fromOffset(620, 480))

	local info = Widgets.text({
		Text = "Kasalar yükleniyor...",
		TextColor3 = Theme.color.textDim,
		TextSize = 13,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 1,
		Parent = panel.content,
		ZIndex = 6,
	})

	local list = Widgets.frame({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = panel.content,
		ZIndex = 6,
	})
	Widgets.list(Enum.FillDirection.Vertical, 6).Parent = list

	local function render(targets)
		list:ClearAllChildren()
		Widgets.list(Enum.FillDirection.Vertical, 6).Parent = list

		if #targets == 0 then
			info.Text = "Şu an soyulabilir kasa yok. Birazdan tekrar bak."
			return
		end
		local botCount = 0
		for _, target in targets do
			if target.bot then
				botCount += 1
			end
		end
		info.Text = if botCount > 0
			then `{#targets} kasa · sunucuda az oyuncu var, NPC kasaları da listelendi`
			else `{#targets} kasa listelendi · liste 5 saniyede bir yenilenir`

		for _, target in targets do
			local status = if target.bot
				then "🤖 NPC kasası"
				elseif target.online then "🟢 çevrimiçi"
				else "⚪ çevrimdışı"
			local subtitle = `{Format.short(target.stash)} birikim · savunma {target.defenseScore} · {status}`
			local row = Widgets.row(list, target.displayName, subtitle, "SOY", function()
				local response = Net.invoke("StartHeist", { targetUserId = target.userId })
				if response.ok then
					panel.setOpen(false)
				end
			end)

			if not target.canRob then
				row.button.Text = "—"
				row.button.BackgroundColor3 = Theme.color.panel
				row.subtitle.Text = `{subtitle}  ·  {target.reasonText}`
				row.root.BackgroundTransparency = 0.45
			end
		end
	end

	State.TargetsChanged:connect(render)

	-- Panel açıkken listeyi taze tut.
	task.spawn(function()
		while true do
			task.wait(5)
			if panel.isOpen() then
				State.refreshTargets()
			end
		end
	end)

	return panel
end

return TargetPanel
