--!strict
-- Sayı ve süre biçimleme. UI'da her yerde bu kullanılır ki "1.2M" her ekranda aynı görünsün.
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.short(value: number): string
	local sign = value < 0 and "-" or ""
	local absolute = math.abs(value)
	if absolute < 1000 then
		return sign .. tostring(math.floor(absolute))
	end
	local index = math.min(math.floor(math.log(absolute, 1000)), #SUFFIXES - 1)
	local scaled = absolute / 1000 ^ index
	-- log yuvarlaması sınırda (tam 1000, 1e6 ...) bir basamak şaşabiliyor.
	if scaled >= 1000 and index < #SUFFIXES - 1 then
		index += 1
		scaled /= 1000
	end
	local text = if scaled < 10 then string.format("%.2f", scaled)
		elseif scaled < 100 then string.format("%.1f", scaled)
		else string.format("%.0f", scaled)
	-- Sondaki gereksiz sıfırları at: 1.50K -> 1.5K (ama "100" -> "1" olmasın)
	if text:find("%.") then
		text = text:gsub("%.?0+$", "")
	end
	return sign .. text .. SUFFIXES[index + 1]
end

function Format.comma(value: number): string
	local text = tostring(math.floor(math.abs(value)))
	local result = text:reverse():gsub("(%d%d%d)", "%1."):reverse()
	result = result:gsub("^%.", "")
	return (value < 0 and "-" or "") .. result
end

function Format.time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor(seconds % 3600 / 60)
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

function Format.percent(value: number, decimals: number?): string
	return string.format("%." .. tostring(decimals or 0) .. "f%%", value * 100)
end

-- Arayüzdeki etiketlerde RichText açık: oyuncu adı gibi dışarıdan gelen
-- metinler etiket olarak yorumlanabilir. Roblox ad kuralları < karakterine
-- izin vermiyor ama duyuru metinleri kod değişikliğiyle başka kaynaklardan
-- da beslenebilir; kaçırmak ucuz, unutmak pahalı.
function Format.escapeRichText(text: string): string
	local escaped = text:gsub("&", "&amp;")
	escaped = escaped:gsub("<", "&lt;")
	escaped = escaped:gsub(">", "&gt;")
	return escaped
end

-- 0.0002 gibi şansları "1 / 5000" diye göstermek daha anlaşılır oluyor.
function Format.odds(probability: number): string
	if probability <= 0 then
		return "-"
	end
	if probability >= 0.01 then
		return Format.percent(probability, 2)
	end
	return "1 / " .. Format.short(math.floor(1 / probability))
end

return Format
