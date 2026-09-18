# Mimari

## Katmanlar

```
src/shared/Config/   Saf veri. Denge sayıları. Hiçbir mantık yok.
src/shared/Core/     Saf fonksiyonlar. Roblox API'si yok -> test edilebilir.
src/shared/Net/      Remote tanımları (tek RemoteFunction + iki RemoteEvent).
src/server/Services/ Durum, kayıt, otorite.
src/client/          Arayüz ve girdi. Hiçbir oyun kararı vermez.
```

Kural: **Core hiçbir zaman Roblox servisi çağırmaz.** Loot zarı, alarm
matematiği, çalınan pay, koridor üreteci, event zamanlaması — hepsi saf
fonksiyon. Bu yüzden 132 test gerçek Roblox olmadan koşuyor ve denge
değişikliği anında doğrulanabiliyor.

Bağımlılıklar servis ağacı üzerinden çözülüyor
(`require(ReplicatedStorage.Shared.Core.Loot)`), `script.Parent` zinciri
yerine. Tek kural olduğu için test köprüsü de bunu makine olarak çevirebiliyor.

## Ağ yüzeyi

Üç remote var, hepsi `Shared/Net/Remotes.luau` içinde tanımlı:

| Remote | Yön | Kullanım |
|---|---|---|
| `Action` (RemoteFunction) | istemci → sunucu | cevap bekleyen istekler (sandık al, soygun başlat...) |
| `Input` (RemoteEvent) | istemci → sunucu | soygun sırasındaki sık sinyaller (hareket modu, kapı tuşu) |
| `Push` (RemoteEvent) | sunucu → istemci | profil, bildirim, event durumu, soygun tiki |

Tek kapıdan geçmesinin sebebi: hız sınırlama, hata yalıtımı ve doğrulama
tek yerde toplanıyor (`NetService`). Jeton kovası: eylemler için saniyede 8
(patlama 20), girdiler için saniyede 30. Aşan istek sessizce düşüyor.

Sunucudaki her eylem işleyicisi `(ok, dataOrError)` döndürüyor; `pcall` ile
sarılı, hata istemciye sızmıyor.

## Otorite modeli

| Karar | Kim verir |
|---|---|
| Sandıktan ne çıkacağı | Sunucu (`Loot.roll`) |
| Hırsızın koridordaki konumu | Sunucu (karakterin gerçek konumu okunuyor) |
| Alarmın dolması | Sunucu (20 Hz sabit adım) |
| Kapı işaretçisinin yeri | Sunucu (`Workspace:GetServerTimeNow()`) |
| Hareket modu (sinsi/normal/koşu) | İstemci söyler, sunucu `WalkSpeed`'i uygular |
| Fiyat, maliyet, sahiplik | Sunucu |

İstemci hiçbir sonucu üretmiyor, yalnızca gösteriyor. Kontrol noktası
bildirimi diye bir mekanizma yok — ilerleme karakterin konumundan okunuyor,
böylece "checkpoint spam" saldırısı mümkün değil.

Hız doğrulaması: `AntiCheat.maxHorizontalSpeed` (40 stud/sn) + tolerans
aşılırsa oyuncu son geçerli konuma geri alınıyor; üç ihlalde soygun
yakalanmış sayılıyor.

## Kayıt (DataService)

DataStore anahtarı başına saklanan yapı:

```lua
{ data = <profil>, lock = { jobId = "...", at = <zaman> }, updatedAt = <zaman> }
```

- **Oturum kilidi**: profil yüklenirken kilit alınır. Başka sunucu tutuyorsa
  10 kez, 6 saniye arayla denenir; olmuyorsa oyuncu nazikçe atılır. Kilit
  15 dakika sonra bayatlar (sunucu çökerse profil kilitli kalmaz).
- **Otomatik kayıt** 120 saniyede bir, `BindToClose` kapanışta bekler.
- **Şema göçü**: `ProfileTemplate.reconcile` eksik alanları doldurur,
  tanımsız savunma/yükseltme id'lerini temizler, envanterde olmayan
  yerleştirilmiş hazineleri düşürür.
- **DataStore erişimi yoksa** (Studio'da API kapalı) bellek içi sahte
  depoya düşer ve uyarı basar; oyun yine oynanır.

### Çevrimdışı oyuncudan çalmak

Sunucudan ayrılan oyuncunun kasası 10 dakika daha soyulabilir kalıyor
(aksi halde herkes "soyulmamak için çık" oynardı). Çalınan para
`DataService.mutateOffline` ile doğrudan kayda yazılıyor:

```
UpdateAsync -> kilit başka sunucuda mı? -> evetse dokunma, hayırsa uygula
```

Kilit başka sunucudaysa soygun sonuçsuz kalıyor. Veri kaybı riskini almak
yerine nadir bir "hedef başka sunucuda" durumunu kabul ediyoruz.

## Soygun oturumu

```
StartHeist
  -> Heist.canRob (hedef seçimi kuralları, tek doğruluk kaynağı)
  -> ArenaService.acquire()          arena yuvası (12 eşzamanlı)
  -> Layout.generate(seed, savunma)  deterministik koridor verisi
  -> CorridorBuilder.build()         veriden parçalar
  -> karakteri arenaya ışınla, HeistStart yayınla
  -> 20 Hz döngü: lazer/sensör/bekçi/kapan -> alarm -> HeistTick
  -> kapıda zamanlama -> başarı | alarm dolu -> yakalandı | süre doldu
  -> VaultService.applySteal / hapis + tazminat
  -> koridoru yık, arenayı bırak, karakteri geri ışınla, HeistEnd
```

`Layout.generate` saf ve tohumla deterministik: aynı tohum aynı koridoru
üretiyor. Bu hem test edilebilirlik hem de ileride istemci tarafı tahmin
(prediction) eklemek için önemli.

## Servis bağımlılıkları

Döngüsel require yok. Sıra `init.server.luau` içinde açıkça yazılı:

```
NetService -> NotificationService -> EventService -> SyncService
  -> MonetizationService -> VaultService -> IncomeService -> HeistService
  -> LeaderboardService -> TutorialService -> WorldService
  -> (en son) DataService   çünkü kurulur kurulmaz oyuncuları yüklemeye başlar
```

Gamepass sahipliği `DataService.runtime(player).gamepasses` içinde tutuluyor;
böylece `SyncService`'in `MonetizationService`'e bağımlı olması gerekmiyor
(döngüsel require'dan kaçınmanın somut sebebi).

`Contexts.luau` bütün çarpanların toplandığı yer — "bu bonus nereden geliyor"
sorusunun tek cevabı.

## İstemci

```
Net       -> remote köprüsü, kanal dağıtımı
State     -> sunucudan gelen anlık görüntü + sinyaller
UI/*      -> panellerin her biri State.Changed'e abone
```

Profil güncellemeleri toplu gönderiliyor (`SyncService`, 0.4 sn aralık):
her coin artışı için paket üretilmiyor. Servisler yalnızca
`SyncService.markDirty(player)` çağırıyor.

## Test altyapısı

Standalone Luau her modülü kendi global tablosuyla yüklediği için `game`
enjekte edilemiyor. Bu yüzden `scripts/prepare_tests.py` kaynakları
`build/test/` altına kopyalarken require yollarını göreli yollara çeviriyor:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")   -- silinir
require(ReplicatedStorage.Shared.Core.Loot)  ->  require("../shared/Core/Loot")
```

Kaynak dosyalar olduğu gibi kalıyor — dönüşüm yalnızca test kopyasında.
Dönüşüm bozulursa testler yüklenemiyor ve gürültülü şekilde patlıyor.

## Bilinen sınırlar

- Liderlik tablosu `OrderedDataStore` kullanıyor; 25 kayıt, 60 saniyede bir
  yenileniyor. Oyuncu sayısı büyürse yazma kotası izlenmeli.
- Koridor parçaları sunucuda hareket ediyor (20 Hz). 12 eşzamanlı soygun
  × ~10 lazer = 120 parça; daha fazlası gerekirse lazer hareketi istemciye
  taşınıp sunucuda yalnızca analitik konum hesabı bırakılabilir
  (`Layout.laserOffset` zaten saf fonksiyon, ikisi de aynı sonucu verir).
- Hub ve parseller kod ile kuruluyor. Sanatsal harita geldiğinde
  `WorldService` yerine Rojo ile modeller bağlanabilir; parsel atama mantığı
  aynı kalır.
