--!strict
-- İstemciden gelen her şeyin geçtiği kapı.
--
-- Neden ayrı bir modül: `math.clamp(math.floor(tonumber(x)), 1, 10)` masum
-- görünüyor ama x = "nan" ise sonuç nan'dır ve nan profile yazılınca kayıt
-- kalıcı olarak bozulur. Tip kontrolü tek yerde toplanmazsa bu hata her yeni
-- eylemde yeniden yazılıyor.
local Validate = {}

-- NaN ve sonsuz değerleri eleyen sayı kontrolü.
function Validate.finite(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value then -- NaN
		return nil
	end
	if value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

-- Tam sayı, aralık içinde. Aralık dışı reddedilir (sessizce kırpılmaz):
-- istemci 10.000 sandık istiyorsa bu bir hata ya da saldırıdır, 10'a
-- yuvarlayıp devam etmek ikisini de gizler.
function Validate.integer(value: any, min: number, max: number): number?
	local number = Validate.finite(value)
	if not number then
		return nil
	end
	local floored = math.floor(number)
	if floored < min or floored > max then
		return nil
	end
	return floored
end

-- Aralık dışını kırpan hâli. Yalnızca kırpmanın gerçekten zararsız olduğu
-- yerlerde kullanılmalı (ör. yuva sırası).
function Validate.clampedInteger(value: any, min: number, max: number, default: number): number
	local number = Validate.finite(value)
	if not number then
		return default
	end
	return math.clamp(math.floor(number), min, max)
end

Validate.MaxIdentifierLength = 64

-- Kimlik dizgisi: kısa, yazdırılabilir, kontrol karakteri yok.
function Validate.identifier(value: any, maxLength: number?): string?
	if type(value) ~= "string" then
		return nil
	end
	local limit = maxLength or Validate.MaxIdentifierLength
	if #value == 0 or #value > limit then
		return nil
	end
	if value:find("[%c]") then
		return nil
	end
	return value
end

-- Dizi: eleman sayısı sınırlı ve her eleman doğrulamadan geçiyor.
-- Sınır önemli: istemci 100.000 elemanlı liste gönderip sunucuyu
-- döngüde tutabilir.
function Validate.list<T>(value: any, maxCount: number, item: (any) -> T?): { T }?
	if type(value) ~= "table" then
		return nil
	end

	local result = {}
	local count = 0
	for index = 1, maxCount + 1 do
		local entry = (value :: any)[index]
		if entry == nil then
			break
		end
		count += 1
		if count > maxCount then
			return nil
		end
		local validated = item(entry)
		if validated == nil then
			return nil
		end
		table.insert(result, validated)
	end

	if count == 0 then
		return nil
	end
	return result
end

-- Bir değerin tanımlı kümede olup olmadığı.
function Validate.oneOf(value: any, allowed: { [string]: any }): string?
	local identifier = Validate.identifier(value)
	if not identifier then
		return nil
	end
	if allowed[identifier] == nil then
		return nil
	end
	return identifier
end

-- Kayda yazılan sayıların akla uygunluğu. Bozuk kayıt yüklenince
-- (nan, sonsuz, negatif para) oyun sessizce çökmesin.
function Validate.sanitizeNumber(value: any, default: number, min: number?): number
	local number = Validate.finite(value)
	if not number then
		return default
	end
	if min and number < min then
		return min
	end
	return number
end

return Validate
