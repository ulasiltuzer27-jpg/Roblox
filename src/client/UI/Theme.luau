--!strict
-- Görsel dil. Renkler tek yerde ki yeni panel eklemek tasarım kararı gerektirmesin.
local Theme = {}

Theme.color = {
	background = Color3.fromRGB(14, 15, 20),
	panel = Color3.fromRGB(22, 24, 32),
	panelAlt = Color3.fromRGB(30, 33, 43),
	stroke = Color3.fromRGB(52, 56, 72),
	text = Color3.fromRGB(238, 240, 248),
	textDim = Color3.fromRGB(150, 156, 174),
	accent = Color3.fromRGB(122, 60, 255),
	good = Color3.fromRGB(92, 200, 122),
	bad = Color3.fromRGB(255, 84, 108),
	warn = Color3.fromRGB(255, 176, 48),
	coin = Color3.fromRGB(255, 200, 64),
	alarm = Color3.fromRGB(255, 64, 88),
}

Theme.font = {
	title = Enum.Font.GothamBold,
	body = Enum.Font.Gotham,
	number = Enum.Font.GothamBold,
}

Theme.padding = 10
Theme.corner = 10

function Theme.toastColor(kind: string): Color3
	if kind == "good" then
		return Theme.color.good
	elseif kind == "bad" then
		return Theme.color.bad
	elseif kind == "warn" then
		return Theme.color.warn
	end
	return Theme.color.accent
end

return Theme
