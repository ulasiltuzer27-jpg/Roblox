--!nonstrict
-- Tüm arayüzü kurar ve dünyadaki kiosklara bağlar.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Net = require(script.Parent.Parent.Controllers.Net)
local State = require(script.Parent.Parent.Controllers.State)
local HeistController = require(script.Parent.Parent.Controllers.HeistController)

local CratePanel = require(script.Parent.CratePanel)
local CrateReveal = require(script.Parent.CrateReveal)
local DefensePanel = require(script.Parent.DefensePanel)
local HeistOverlay = require(script.Parent.HeistOverlay)
local Hud = require(script.Parent.Hud)
local LeaderboardPanel = require(script.Parent.LeaderboardPanel)
local ShopPanel = require(script.Parent.ShopPanel)
local TargetPanel = require(script.Parent.TargetPanel)
local Toast = require(script.Parent.Toast)
local VaultPanel = require(script.Parent.VaultPanel)

local App = {}

function App.mount()
	local screen = Instance.new("ScreenGui")
	screen.Name = "VaultHeistUI"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local panels = {
		crates = CratePanel.mount(screen),
		vault = VaultPanel.mount(screen),
		defense = DefensePanel.mount(screen),
		targets = TargetPanel.mount(screen),
		shop = ShopPanel.mount(screen),
		leaderboard = LeaderboardPanel.mount(screen),
	}

	Toast.mount(screen)
	CrateReveal.mount(screen)
	Hud.mount(screen, panels)

	local overlay = HeistOverlay.mount(screen, {
		abort = HeistController.abort,
		door = HeistController.doorAttempt,
		setMode = HeistController.setMode,
	})
	HeistController.init(overlay)

	-- Dünyadaki kiosklar ilgili paneli açar.
	local promptTargets = {
		["Sandık Dükkanı"] = "crates",
		["Yükseltmeler"] = "defense",
		["Savunmalar"] = "defense",
		["Soygun Panosu"] = "targets",
	}

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if player ~= Players.LocalPlayer then
			return
		end
		local kioskName = prompt.Parent and prompt.Parent.Name
		local key = promptTargets[kioskName]
		if key then
			for name, panel in panels do
				panel.setOpen(name == key)
			end
			if key == "targets" then
				State.refreshTargets()
			end
		elseif kioskName == "Günlük Ödül" then
			Net.invoke("ClaimDaily")
		end
	end)

	return { screen = screen, panels = panels, overlay = overlay }
end

return App
