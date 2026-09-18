--!strict
-- Tek giriş noktası: `local Config = require(ReplicatedStorage.Shared.Config)`
-- Alt modüller de servis ağacı üzerinden çözülüyor; projedeki tek require
-- kuralı bu olsun diye `script.X` kısayolu bilerek kullanılmıyor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigFolder = ReplicatedStorage.Shared.Config

local Config = {
	Balance = require(ConfigFolder.Balance),
	Codes = require(ConfigFolder.Codes),
	Crates = require(ConfigFolder.Crates),
	DailyRewards = require(ConfigFolder.DailyRewards),
	Defenses = require(ConfigFolder.Defenses),
	Monetization = require(ConfigFolder.Monetization),
	Mutations = require(ConfigFolder.Mutations),
	Rarities = require(ConfigFolder.Rarities),
	Rebirth = require(ConfigFolder.Rebirth),
	ServerEvents = require(ConfigFolder.ServerEvents),
	Upgrades = require(ConfigFolder.Upgrades),
	Zones = require(ConfigFolder.Zones),
}

return Config
