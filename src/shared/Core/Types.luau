--!strict
-- Tüm paylaşılan veri şekilleri. Sunucu profili, ağ üzerinden giden paketler
-- ve istemci state'i aynı tiplere bakar.
export type Treasure = {
	uid: string,
	rarity: string,
	mutation: string,
	crate: string,
	foundAt: number,
}

export type Stats = {
	cratesOpened: number,
	heistsWon: number,
	heistsFailed: number,
	timesRobbed: number,
	coinsStolen: number,
	coinsLost: number,
	biggestSteal: number,
}

export type Boost = {
	multiplier: number,
	expiresAt: number,
}

export type Profile = {
	version: number,
	coins: number,
	tokens: number,
	rebirths: number,
	zone: string,

	crates: { [string]: number },
	treasures: { [string]: Treasure },
	placed: { string },

	upgrades: { [string]: number },
	defenses: { [string]: number },

	stash: number,
	lastIncomeAt: number,
	lastSeenAt: number,

	shieldUntil: number,
	jailUntil: number,
	lastRobbedAt: number,
	robbedBy: { [string]: number },

	boosts: { [string]: Boost },
	purchases: { [string]: boolean },
	daily: { day: number, lastClaimAt: number },
	tutorial: { step: number, done: boolean },
	stats: Stats,
}

-- İstemciye gönderilen kasa özeti (kendi kasan ve hedef kasalar için aynı şekil).
export type VaultSummary = {
	userId: number,
	displayName: string,
	netWorth: number,
	incomePerSecond: number,
	stash: number,
	defenseScore: number,
	slots: number,
	online: boolean,
	shielded: boolean,
	treasureCount: number,
}

export type LaserSpec = {
	id: number,
	z: number,
	axis: "horizontal" | "vertical",
	span: number,
	speed: number,
	phase: number,
	alarmPerSecond: number,
}

export type TrapSpec = {
	id: number,
	z: number,
	x: number,
	radius: number,
	rootSeconds: number,
	alarmOnTrigger: number,
}

export type SensorSpec = {
	id: number,
	z: number,
	x: number,
	radius: number,
	alarmPerSecond: number,
}

export type GuardSpec = {
	id: number,
	z: number,
	patrolHalfWidth: number,
	speed: number,
	viewRange: number,
	viewAngle: number,
	alarmPerSecond: number,
}

export type DoorSpec = {
	z: number,
	stages: number,
	windowSeconds: number,
}

export type Layout = {
	seed: number,
	segments: number,
	length: number,
	width: number,
	lasers: { LaserSpec },
	traps: { TrapSpec },
	sensors: { SensorSpec },
	guards: { GuardSpec },
	door: DoorSpec,
	checkpoints: { number },
}

export type HeistResult = {
	success: boolean,
	reason: string,
	coins: number,
	share: number,
	perfect: boolean,
	treasure: Treasure?,
	targetUserId: number,
	targetName: string,
	durationSeconds: number,
}

return {}
