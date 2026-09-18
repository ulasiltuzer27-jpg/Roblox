--!strict
-- 7 günlük seri. 7. gün bilerek büyük: "yarın da gir" duygusu retention'ın kendisi.
export type DailyReward = {
	day: number,
	coins: number?,
	crates: { [string]: number }?,
	tokens: number?,
	shieldSeconds: number?,
	label: string,
}

local DailyRewards = {}

DailyRewards.ResetHours = 20 -- son ödülden 20 saat sonra sıradaki gün açılır
DailyRewards.StreakBreakHours = 48 -- 48 saat girmezsen seri sıfırlanır

DailyRewards.List = {
	{ day = 1, coins = 500, label = "500 coin" },
	{ day = 2, crates = { wood = 3 }, label = "3 Ahşap Sandık" },
	{ day = 3, coins = 5000, label = "5.000 coin" },
	{ day = 4, shieldSeconds = 900, label = "15 dk kasa kilidi" },
	{ day = 5, crates = { iron = 3 }, label = "3 Demir Sandık" },
	{ day = 6, coins = 50000, label = "50.000 coin" },
	{ day = 7, tokens = 1, crates = { iron = 5 }, label = "1 jeton + 5 Demir Sandık" },
} :: { DailyReward }

function DailyRewards.forDay(day: number): DailyReward
	local index = ((day - 1) % #DailyRewards.List) + 1
	return DailyRewards.List[index]
end

return DailyRewards
