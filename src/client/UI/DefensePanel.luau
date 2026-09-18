--!nonstrict
-- Savunmalar ve kasa yükseltmeleri. Rebirth düğmesi de burada:
-- oyuncu "neyi yükselteceğim" kararını tek ekranda versin.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Net = require(script.Parent.Parent.Controllers.Net)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local DefensePanel = {}

local function section(parent: Instance, title: string, order: number)
	local label = Widgets.text({
		Text = title,
		Font = Theme.font.title,
		TextSize = 15,
		TextColor3 = Theme.color.textDim,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = order,
		Parent = parent,
		ZIndex = 6,
	})
	return label
end

function DefensePanel.mount(parent: Instance)
	local panel = Widgets.panel(parent, "Savunma & Yükseltme", UDim2.fromOffset(620, 520))
	local rows = {}

	section(panel.content, "KASA SAVUNMALARI", 1)
	for index, defense in Config.Defenses.List do
		local row = Widgets.row(panel.content, defense.name, defense.description, "Yükselt", function()
			Net.invoke("BuyDefense", { defenseId = defense.id })
		end)
		row.root.LayoutOrder = 1 + index
		table.insert(rows, { kind = "defense", id = defense.id, row = row })
	end

	section(panel.content, "KASA YÜKSELTMELERİ", 100)
	for index, upgrade in Config.Upgrades.List do
		local row = Widgets.row(panel.content, upgrade.name, upgrade.description, "Yükselt", function()
			Net.invoke("BuyUpgrade", { upgradeId = upgrade.id })
		end)
		row.root.LayoutOrder = 100 + index
		table.insert(rows, { kind = "upgrade", id = upgrade.id, row = row })
	end

	section(panel.content, "REBIRTH", 200)
	local rebirthRow = Widgets.row(panel.content, "Rebirth", "", "Yap", function()
		Net.invoke("Rebirth")
	end)
	rebirthRow.root.LayoutOrder = 201

	local function refresh()
		local profile = State.profile
		if not profile then
			return
		end

		for _, entry in rows do
			if entry.kind == "defense" then
				local defense = Config.Defenses.get(entry.id)
				local level = profile.defenses[entry.id] or 0
				entry.row.title.Text = `{defense.name}  <font color="rgb(150,156,174)">Sv. {level}/{defense.maxLevel}</font>`
				if level >= defense.maxLevel then
					entry.row.subtitle.Text = "En üst seviye."
					entry.row.button.Text = "TAM"
					entry.row.button.BackgroundColor3 = Theme.color.panel
				else
					local cost = Config.Defenses.upgradeCost(entry.id, level)
					entry.row.subtitle.Text = defense.description
					entry.row.button.Text = Format.short(cost)
					entry.row.button.BackgroundColor3 = if profile.coins >= cost
						then Theme.color.accent
						else Theme.color.panel
				end
			else
				local upgrade = Config.Upgrades.get(entry.id)
				local level = profile.upgrades[entry.id] or 0
				entry.row.title.Text = `{upgrade.name}  <font color="rgb(150,156,174)">Sv. {level}/{upgrade.maxLevel}</font>`
				if level >= upgrade.maxLevel then
					entry.row.subtitle.Text = "En üst seviye."
					entry.row.button.Text = "TAM"
					entry.row.button.BackgroundColor3 = Theme.color.panel
				else
					local cost = Config.Upgrades.cost(entry.id, level)
					entry.row.subtitle.Text = upgrade.description
					entry.row.button.Text = Format.short(cost)
					entry.row.button.BackgroundColor3 = if profile.coins >= cost
						then Theme.color.accent
						else Theme.color.panel
				end
			end
		end

		local requirement = profile.rebirthRequirement
		local ready = profile.netWorth >= requirement
		rebirthRow.title.Text = `Rebirth {profile.rebirths} → {profile.rebirths + 1}`
		rebirthRow.subtitle.Text = if ready
			then `Hazır! Kalıcı gelir x{Config.Rebirth.multiplier(profile.rebirths + 1)}`
			else `{Format.short(requirement)} servet gerekiyor (şu an {Format.short(profile.netWorth)})`
		rebirthRow.button.BackgroundColor3 = if ready then Theme.color.warn else Theme.color.panel
	end

	State.Changed:connect(refresh)
	refresh()
	return panel
end

return DefensePanel
