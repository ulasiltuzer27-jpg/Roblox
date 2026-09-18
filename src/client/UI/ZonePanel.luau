--!nonstrict
-- Bölgeler: nereye gidebilirsin, ne zaman açılır.
-- Kapılara yürümek zorunda kalmadan da geçiş yapılabilsin diye panel var;
-- haritadaki kapılar aynı işi yapıyor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Net = require(script.Parent.Parent.Controllers.Net)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local ZonePanel = {}

function ZonePanel.mount(parent: Instance)
	local panel = Widgets.panel(parent, "Bölgeler", UDim2.fromOffset(580, 460))
	local rows = {}

	for index, zone in Config.Zones.List do
		local mapZone = Config.Map.ZoneById[zone.id]
		local row = Widgets.row(panel.content, zone.name, mapZone and mapZone.tagline or "", "Git", function()
			local response = Net.invoke("TravelZone", { zoneId = zone.id })
			if response.ok then
				panel.setOpen(false)
			end
		end)
		row.root.LayoutOrder = index
		table.insert(rows, { zone = zone, row = row })
	end

	local function refresh()
		local profile = State.profile
		if not profile then
			return
		end

		for _, entry in rows do
			local zone = entry.zone
			local unlocked = profile.rebirths >= zone.requiredRebirths
			local here = profile.zone == zone.id
			local bonus = math.floor(zone.incomeBonus * 100)

			local suffix = if bonus > 0 then ` · +%{bonus} gelir` else ""
			local mapZone = Config.Map.ZoneById[zone.id]
			entry.row.subtitle.Text = (mapZone and mapZone.tagline or "") .. suffix

			if here then
				entry.row.title.Text = `{zone.name}  <font color="rgb(92,200,122)">buradasın</font>`
				entry.row.button.Text = "BURADASIN"
				entry.row.button.BackgroundColor3 = Theme.color.panel
			elseif unlocked then
				entry.row.title.Text = zone.name
				entry.row.button.Text = "Git"
				entry.row.button.BackgroundColor3 = Theme.color.accent
			else
				entry.row.title.Text = `{zone.name}  <font color="rgb(150,156,174)">🔒</font>`
				entry.row.subtitle.Text = `{zone.requiredRebirths} rebirth gerekiyor `
					.. `(şu an {profile.rebirths}) · sonraki eşik {Format.short(profile.rebirthRequirement)} servet`
				entry.row.button.Text = "KİLİTLİ"
				entry.row.button.BackgroundColor3 = Theme.color.panel
			end
		end
	end

	State.Changed:connect(refresh)
	refresh()
	return panel
end

return ZonePanel
