--!nonstrict
-- Bölgeye göre ışık ve atmosfer.
--
-- Lighting sunucuda değil istemcide ayarlanıyor: aynı sunucuda farklı
-- bölgelerde oyuncular var ve Lighting global. Herkesin kendi bölgesinin
-- havasını görmesi ancak böyle mümkün.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local AmbienceController = {}

local TRANSITION = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local current: string? = nil

local function color3(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function ensure(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = Lighting
	return instance
end

function AmbienceController.apply(zoneId: string)
	if zoneId == current or not Config.Map.ZoneById[zoneId] then
		return
	end
	current = zoneId
	local theme = Config.Map.theme(zoneId)

	Lighting.ClockTime = theme.clockTime
	Lighting.GlobalShadows = true
	Lighting.Technology = Enum.Technology.ShadowMap
	Lighting.Brightness = 2

	-- Renk geçişleri ani olmasın: bölge değişimi bir "an" gibi hissedilsin.
	TweenService:Create(Lighting, TRANSITION, {
		Ambient = color3(theme.ambient),
		OutdoorAmbient = color3(theme.ambient),
		FogColor = color3(theme.fogColor),
		FogEnd = theme.fogEnd,
		FogStart = theme.fogEnd * 0.25,
	}):Play()

	local atmosphere = ensure("Atmosphere", "VaultAtmosphere") :: Atmosphere
	TweenService:Create(atmosphere, TRANSITION, {
		Density = 0.32,
		Color = color3(theme.fogColor),
		Decay = color3(theme.accent),
		Glare = 0.2,
		Haze = 1.4,
	}):Play()

	local bloom = ensure("BloomEffect", "VaultBloom") :: BloomEffect
	bloom.Intensity = 0.65
	bloom.Size = 22
	bloom.Threshold = 1.35

	local correction = ensure("ColorCorrectionEffect", "VaultColor") :: ColorCorrectionEffect
	TweenService:Create(correction, TRANSITION, {
		Saturation = 0.08,
		Contrast = 0.12,
		TintColor = color3(theme.glow):Lerp(Color3.new(1, 1, 1), 0.86),
	}):Play()
end

function AmbienceController.init()
	State.Changed:connect(function(profile)
		if profile and profile.zone then
			AmbienceController.apply(profile.zone)
		end
	end)
	if State.profile and State.profile.zone then
		AmbienceController.apply(State.profile.zone)
	end
end

return AmbienceController
