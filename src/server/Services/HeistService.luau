--!nonstrict
-- Soygunun kendisi. Oturum sunucuda yaşar: koridor sunucuda kurulur,
-- hırsızın konumu sunucuda okunur, alarm sunucuda dolar. İstemciden gelen
-- tek şey hareket modu tercihi ve kapıdaki tuş basımı.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Core.Economy)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Heist = require(ReplicatedStorage.Shared.Core.Heist)
local Layout = require(ReplicatedStorage.Shared.Core.Layout)
local Loot = require(ReplicatedStorage.Shared.Core.Loot)
local Signal = require(ReplicatedStorage.Shared.Core.Signal)
local Validate = require(ReplicatedStorage.Shared.Core.Validate)
local ArenaService = require(ServerScriptService.Server.Services.ArenaService)
local Contexts = require(ServerScriptService.Server.Services.Contexts)
local CorridorBuilder = require(ServerScriptService.Server.Services.CorridorBuilder)
local DataService = require(ServerScriptService.Server.Services.DataService)
local EventService = require(ServerScriptService.Server.Services.EventService)
local NetService = require(ServerScriptService.Server.Services.NetService)
local NotificationService = require(ServerScriptService.Server.Services.NotificationService)
local SyncService = require(ServerScriptService.Server.Services.SyncService)
local VaultService = require(ServerScriptService.Server.Services.VaultService)

local HEIST = Config.Balance.Heist
local CORRIDOR = Config.Balance.Corridor
local MOVEMENT = Config.Balance.Movement

local HeistService = {}

HeistService.Finished = Signal.new() -- (player, result)

local sessions: { [number]: any } = {}

local NOISE = {
	sneak = MOVEMENT.noiseSneak,
	walk = MOVEMENT.noiseWalk,
	sprint = MOVEMENT.noiseSprint,
}
local SPEED = {
	sneak = MOVEMENT.sneakSpeed,
	walk = MOVEMENT.walkSpeed,
	sprint = MOVEMENT.sprintSpeed,
}

local function characterOf(player: Player)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil, nil
	end
	return humanoid, root
end

local function pushTick(session)
	NetService.push(session.player, "HeistTick", {
		alarm = session.alarm,
		alarmCapacity = HEIST.alarmCapacity,
		secondsLeft = math.max(0, session.deadline - os.clock()),
		progress = math.clamp(session.progress / session.layout.length, 0, 1),
		mode = session.mode,
		atDoor = session.atDoor,
		doorStage = session.doorStage,
		doorStages = session.layout.door.stages,
		doorStartedAt = session.doorStartedAt,
		doorWindow = session.layout.door.windowSeconds,
		rooted = os.clock() < session.rootedUntil,
	})
end

-- Koridordaki tehlikelerin o an ürettiği toplam alarm hızı.
local function detectionRate(session, localPosition: Vector3, speed: number): number
	local rate = 0
	local clock = session.clock
	local noise = NOISE[session.mode] or 1

	for _, entry in session.corridor.lasers do
		local spec = entry.spec
		if math.abs(localPosition.Z - spec.z) > 1.8 then
			continue
		end
		local offset = Layout.laserOffset(spec, clock)
		if spec.axis == "horizontal" then
			-- Yatay ışın yukarı aşağı süpürür; gövde yüksekliğine denk gelirse yakalar.
			if math.abs((localPosition.Y + 2.5) - (CORRIDOR.height / 2 + offset)) < 2.6 then
				rate += spec.alarmPerSecond
			end
		elseif math.abs(localPosition.X - offset) < 2.2 then
			rate += spec.alarmPerSecond
		end
	end

	for _, entry in session.corridor.sensors do
		local spec = entry.spec
		local distance = (Vector3.new(spec.x, localPosition.Y, spec.z) - localPosition).Magnitude
		if distance <= spec.radius then
			-- Duruyorsan sensör seni zor görür; koşarsan bağırır.
			local motion = math.clamp(speed / MOVEMENT.walkSpeed, 0.08, 2)
			rate += spec.alarmPerSecond * noise * motion
		end
	end

	for _, entry in session.corridor.guards do
		local spec = entry.spec
		local guardPosition = session.corridor.origin:PointToObjectSpace(entry.part.Position)
		local toThief = localPosition - guardPosition
		local distance = toThief.Magnitude
		if distance > spec.viewRange or distance < 0.1 then
			continue
		end
		-- Bekçi X ekseninde devriye geziyor; baktığı yön hareket yönü.
		local facing = if math.cos(clock * spec.speed / spec.patrolHalfWidth) >= 0 then 1 else -1
		local direction = Vector3.new(facing, 0, 0)
		local angle = math.acos(math.clamp(direction:Dot(toThief.Unit), -1, 1))
		if angle <= spec.viewAngle then
			rate += spec.alarmPerSecond
		end
	end

	return rate * Heist.stealthFactor(session.stealthUpgrade)
end

local function checkTraps(session, localPosition: Vector3)
	for _, entry in session.corridor.traps do
		local spec = entry.spec
		if session.triggeredTraps[spec.id] then
			continue
		end
		local flat = Vector3.new(localPosition.X - spec.x, 0, localPosition.Z - spec.z)
		if flat.Magnitude <= spec.radius then
			session.triggeredTraps[spec.id] = true
			session.rootedUntil = os.clock() + spec.rootSeconds
			session.alarm = math.min(HEIST.alarmCapacity, session.alarm + spec.alarmOnTrigger)
			entry.part.Color = Color3.fromRGB(255, 64, 64)

			local humanoid = select(1, characterOf(session.player))
			if humanoid then
				humanoid.WalkSpeed = 0
			end
			NotificationService.toast(session.player, "Kapana bastın!", "warn")
		end
	end
end

local function applyMoveSpeed(session)
	local humanoid = select(1, characterOf(session.player))
	if not humanoid then
		return
	end
	if os.clock() < session.rootedUntil then
		humanoid.WalkSpeed = 0
		return
	end
	humanoid.WalkSpeed = SPEED[session.mode] or MOVEMENT.walkSpeed
end

local function cleanup(session)
	if session.corridor then
		session.corridor.model:Destroy()
	end
	if session.arenaIndex then
		ArenaService.release(session.arenaIndex)
	end

	local humanoid, root = characterOf(session.player)
	if humanoid then
		humanoid.WalkSpeed = MOVEMENT.walkSpeed
	end
	if root and session.returnCFrame then
		session.player.Character:PivotTo(session.returnCFrame)
	end
	sessions[session.player.UserId] = nil
end

local function finish(session, success: boolean, reason: string)
	if session.ended then
		return
	end
	session.ended = true

	local player = session.player
	local profile = DataService.get(player)
	local perfect = success and Heist.isPerfect(session.peakAlarm)
	local duration = os.clock() - session.startedAt

	local result = {
		success = success,
		reason = reason,
		perfect = perfect,
		coins = 0,
		share = 0,
		treasure = nil,
		targetName = session.targetName,
		durationSeconds = math.floor(duration),
	}

	if profile then
		local runtime = DataService.runtime(player)
		runtime.lastHeistAt = os.time()
		runtime.targetHistory[session.targetUserId] = os.time()

		if success then
			local share = Heist.stealShare({
				carryUpgrade = profile.upgrades.carry or 0,
				perfect = perfect,
				defenseScore = session.defenseScore,
				ownerOnline = session.targetOnline,
				eventShareMultiplier = EventService.effects().stealShareMultiplier,
			})
			local takeTreasure = perfect and math.random() < HEIST.perfectTreasureStealChance
			local coins, treasure = VaultService.applySteal(session.targetUserId, share, takeTreasure)

			profile.coins += coins
			profile.stats.heistsWon += 1
			profile.stats.coinsStolen += coins
			profile.stats.biggestSteal = math.max(profile.stats.biggestSteal, coins)

			if treasure then
				profile.treasures[treasure.uid] = treasure
				VaultService.autoPlace(player, profile, treasure.uid)
			end

			result.coins = coins
			result.share = share
			result.treasure = treasure

			VaultService.notifyRobbed(session.targetUserId, player.DisplayName, coins, treasure)

			if perfect and coins > 0 then
				NotificationService.announce(
					`🕶️ {player.DisplayName}, {session.targetName} kasasını alarm çaldırmadan soydu: {Format.short(coins)} coin!`,
					{ 0, 255, 214 }
				)
			end
		else
			profile.stats.heistsFailed += 1
			if reason == "caught" or reason == "left" then
				profile.jailUntil = os.time() + Heist.jailSeconds(Contexts.hasPass(player, "vip"))
				local target = VaultService.findTarget(session.targetUserId)
				if target then
					VaultService.grantBounty(session.targetUserId, Heist.caughtBounty(target.profile.stash))
				end
			end
		end
		SyncService.markDirty(player)
	end

	if player.Parent then
		NetService.push(player, "HeistEnd", {
			success = result.success,
			reason = result.reason,
			perfect = result.perfect,
			coins = result.coins,
			share = result.share,
			treasureName = if result.treasure then Loot.displayName(result.treasure) else nil,
			targetName = result.targetName,
			durationSeconds = result.durationSeconds,
			jailSecondsLeft = if profile then math.max(0, profile.jailUntil - os.time()) else 0,
		})
	end

	cleanup(session)
	HeistService.Finished:fire(player, result)
end

local function step(session, deltaTime: number)
	if session.ended then
		return
	end
	if not session.player.Parent then
		finish(session, false, "left")
		return
	end

	local humanoid, root = characterOf(session.player)
	if not humanoid or not root then
		finish(session, false, "down")
		return
	end

	session.clock += deltaTime
	CorridorBuilder.animate(session.corridor, session.clock, CORRIDOR.height)

	local localPosition = session.corridor.origin:PointToObjectSpace(root.Position)

	-- Hız doğrulaması: sunucunun yürüyüş hızını aşan sıçramalar geri alınır.
	local traveled = 0
	if session.lastPosition then
		traveled = (Vector3.new(localPosition.X, 0, localPosition.Z) - Vector3.new(
			session.lastPosition.X,
			0,
			session.lastPosition.Z
		)).Magnitude
		-- Tolerans tik başına değil, tek seferlik küçük bir pay olmalı:
		-- 12 stud'luk pay 20 Hz'de saniyede 240 stud'luk ışınlanmaya izin
		-- veriyordu, yani anti-cheat hiçbir şey yakalamıyordu.
		local allowed = Config.Balance.AntiCheat.maxHorizontalSpeed * deltaTime
			+ Config.Balance.AntiCheat.positionToleranceStuds
		if traveled > allowed then
			session.violations += 1
			session.player.Character:PivotTo(session.corridor.origin * CFrame.new(session.lastPosition))
			if session.violations >= Config.Balance.AntiCheat.maxViolations then
				finish(session, false, "caught")
				return
			end
			return
		end
	end

	local speed = if deltaTime > 0 then traveled / deltaTime else 0
	session.lastPosition = localPosition
	session.progress = math.max(session.progress, localPosition.Z)

	checkTraps(session, localPosition)
	applyMoveSpeed(session)

	local rate = detectionRate(session, localPosition, speed)
	session.alarm = Heist.stepAlarm(session.alarm, rate, deltaTime)
	session.peakAlarm = math.max(session.peakAlarm, session.alarm)

	if Heist.isCaught(session.alarm) then
		finish(session, false, "caught")
		return
	end

	-- Kapıya varınca kilit aşaması başlar.
	if not session.atDoor and localPosition.Z >= session.layout.length - 7 then
		session.atDoor = true
		session.doorStartedAt = Workspace:GetServerTimeNow()
	end

	if os.clock() >= session.deadline then
		finish(session, false, "timeout")
		return
	end

	session.tickAccumulator += deltaTime
	if session.tickAccumulator >= 0.15 then
		session.tickAccumulator = 0
		pushTick(session)
	end
end

function HeistService.start(player: Player, payload: any): (boolean, any)
	local profile = DataService.get(player)
	if not profile then
		return false, "Profil yüklenmedi."
	end
	if sessions[player.UserId] then
		return false, "Zaten bir soygundasın."
	end

	-- NPC kasaları negatif kimlik taşıyor, gerçek oyuncular pozitif.
	local targetUserId = Validate.integer(payload and payload.targetUserId, -1000, 2 ^ 53)
	if not targetUserId or targetUserId == 0 then
		return false, "Hedef seçilmedi."
	end

	local target = VaultService.findTarget(targetUserId)
	if not target then
		return false, "Bu kasa artık erişilebilir değil."
	end

	local runtime = DataService.runtime(player)
	local canRob, reason = Heist.canRob({
		userId = player.UserId,
		netWorth = Economy.netWorth(profile),
		jailUntil = profile.jailUntil,
		lastHeistAt = runtime.lastHeistAt,
		lastTargetAt = runtime.targetHistory[targetUserId] or 0,
	}, {
		userId = targetUserId,
		netWorth = Economy.netWorth(target.profile),
		stash = target.profile.stash,
		shieldUntil = target.profile.shieldUntil,
		lastRobbedAt = target.profile.lastRobbedAt,
	}, os.time())

	if not canRob then
		return false, Heist.ReasonText[reason]
	end

	local humanoid, root = characterOf(player)
	if not humanoid or not root then
		return false, "Karakterin hazır değil."
	end

	local arenaIndex, origin = ArenaService.acquire()
	if not arenaIndex then
		return false, "Şu an tüm koridorlar dolu, birazdan dene."
	end

	local effects = EventService.effects()
	local defenseContext = Contexts.defense(target.profile, target.online, target.vipLock)
	local layout = Layout.generate(math.random(1, 2147483646), {
		defenses = target.profile.defenses,
		guardsDisabled = effects.guardsDisabled == true,
		defenseMultiplier = effects.defenseMultiplier,
	})

	local corridor = CorridorBuilder.build(layout, origin, ArenaService.container())

	local session = {
		player = player,
		targetUserId = targetUserId,
		targetName = target.name,
		targetOnline = target.online,
		layout = layout,
		corridor = corridor,
		arenaIndex = arenaIndex,
		defenseScore = Heist.defenseScore(defenseContext),
		stealthUpgrade = profile.upgrades.stealth or 0,

		alarm = 0,
		peakAlarm = 0,
		progress = 0,
		clock = 0,
		mode = "walk",
		violations = 0,
		triggeredTraps = {},
		rootedUntil = 0,
		atDoor = false,
		doorStage = 0,
		doorStartedAt = 0,
		lastPosition = nil,
		tickAccumulator = 0,
		startedAt = os.clock(),
		deadline = os.clock() + HEIST.timeLimitSeconds,
		returnCFrame = player.Character:GetPivot(),
		ended = false,
	}
	sessions[player.UserId] = session

	player.Character:PivotTo(corridor.spawnCFrame)
	humanoid.WalkSpeed = MOVEMENT.walkSpeed

	NetService.push(player, "HeistStart", {
		layout = layout,
		targetName = target.name,
		targetUserId = targetUserId,
		defenseScore = math.floor(session.defenseScore),
		stash = math.floor(target.profile.stash),
		timeLimit = HEIST.timeLimitSeconds,
		ownerOnline = target.online,
	})

	local targetPlayer = Players:GetPlayerByUserId(targetUserId)
	if targetPlayer then
		NotificationService.toast(targetPlayer, `{player.DisplayName} kasana giriyor!`, "warn")
	end

	return true, { started = true }
end

function HeistService.abort(player: Player): (boolean, any)
	local session = sessions[player.UserId]
	if not session then
		return false, "Aktif soygunun yok."
	end
	finish(session, false, "aborted")
	return true
end

function HeistService.setMode(player: Player, payload: any)
	local session = sessions[player.UserId]
	if not session then
		return
	end
	local mode = payload and payload.mode
	if mode ~= "sneak" and mode ~= "walk" and mode ~= "sprint" then
		return
	end
	session.mode = mode
	applyMoveSpeed(session)
end

-- Kapıdaki zamanlama denemesi. İşaretçinin yeri sunucu saatinden hesaplanır;
-- istemci yalnızca "bastım" diyor.
function HeistService.doorAttempt(player: Player)
	local session = sessions[player.UserId]
	if not session or not session.atDoor or session.ended then
		return
	end

	local elapsed = Workspace:GetServerTimeNow() - session.doorStartedAt
	if Layout.doorHit(elapsed, session.layout.door.windowSeconds) then
		session.doorStage += 1
		session.doorStartedAt = Workspace:GetServerTimeNow()
		if session.doorStage >= session.layout.door.stages then
			finish(session, true, "cracked")
			return
		end
		NotificationService.toast(player, `Kilit {session.doorStage}/{session.layout.door.stages}`, "good")
	else
		session.alarm = math.min(HEIST.alarmCapacity, session.alarm + 20)
		session.peakAlarm = math.max(session.peakAlarm, session.alarm)
		session.doorStartedAt = Workspace:GetServerTimeNow()
		NotificationService.toast(player, "Kilit tutmadı, alarm yükseldi!", "warn")
		if Heist.isCaught(session.alarm) then
			finish(session, false, "caught")
		end
	end
	pushTick(session)
end

function HeistService.isInHeist(player: Player): boolean
	return sessions[player.UserId] ~= nil
end

function HeistService.init()
	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player.UserId]
		if session then
			finish(session, false, "left")
		end
	end)

	-- Sabit adım: her karede değil saniyede 20 kez. Algılama için fazlasıyla
	-- yeterli, 12 eşzamanlı koridorun parça hareketini de ucuzlatıyor.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		accumulator += deltaTime
		if accumulator < STEP_INTERVAL then
			return
		end
		local elapsed = accumulator
		accumulator = 0

		for _, session in sessions do
			local ok, err = pcall(step, session, elapsed)
			if not ok then
				warn("[HeistService] adım hatası:", err)
				finish(session, false, "error")
			end
		end
	end)
end

return HeistService
