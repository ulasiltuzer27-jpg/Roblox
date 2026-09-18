--!strict
-- Mutasyonlar hazinenin üstüne gelen çarpan katmanı. Asıl "chase" duygusu burada:
-- Prizma 10.000'de 2 -- yani yaklaşık her 5000 sandıkta bir. Klip malzemesi.
export type Mutation = {
	id: string,
	name: string,
	multiplier: number,
	weight: number,
	color: { number },
	announce: boolean,
}

local Mutations = {}

Mutations.List = {
	{ id = "normal", name = "Normal", multiplier = 1, weight = 8000, color = { 200, 200, 210 }, announce = false },
	{ id = "gold", name = "Altın", multiplier = 2.5, weight = 1500, color = { 255, 200, 64 }, announce = false },
	{ id = "neon", name = "Neon", multiplier = 6, weight = 400, color = { 64, 255, 236 }, announce = false },
	{ id = "glitch", name = "Glitch", multiplier = 15, weight = 80, color = { 255, 64, 220 }, announce = true },
	{ id = "void", name = "Boşluk", multiplier = 40, weight = 18, color = { 122, 60, 255 }, announce = true },
	{ id = "prism", name = "Prizma", multiplier = 150, weight = 2, color = { 255, 255, 255 }, announce = true },
} :: { Mutation }

Mutations.ById = {} :: { [string]: Mutation }
for _, mutation in Mutations.List do
	Mutations.ById[mutation.id] = mutation
end

-- "Normal" dışındaki mutasyon şansını artıran çarpanın uygulandığı taban.
Mutations.DefaultId = "normal"

function Mutations.get(id: string): Mutation
	local mutation = Mutations.ById[id]
	assert(mutation, `bilinmeyen mutasyon: {id}`)
	return mutation
end

return Mutations
