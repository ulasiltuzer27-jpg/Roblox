# Güvenlik ve Sağlamlık

Para kazandıran bir oyunda exploit ve veri kaybı, kötü dengeden daha hızlı
öldürür. Bu doküman neyin nasıl korunduğunu ve **neyin korunmadığını**
yazıyor.

## Otorite: istemci hiçbir şeye karar vermez

| Karar | Kim verir | Nerede |
|---|---|---|
| Sandıktan ne çıkacağı | Sunucu | `Core/Loot.roll` |
| Fiyat, maliyet, sahiplik | Sunucu | `CrateService`, `DefenseService` |
| Hırsızın koridordaki konumu | Sunucu (karakterin gerçek konumu okunur) | `HeistService.step` |
| Alarmın dolması | Sunucu, 20 Hz sabit adım | `HeistService.detectionRate` |
| Kapı işaretçisinin yeri | Sunucu (`Workspace:GetServerTimeNow`) | `HeistService.doorAttempt` |
| Çalınan pay | Sunucu | `Core/Heist.stealShare` |
| Hareket modu | İstemci söyler, sunucu `WalkSpeed`'i uygular | `HeistService.setMode` |

İstemciden gelen **tek** şey: hangi eylemi istediği, hangi hareket modunu
seçtiği ve kapıda tuşa bastığı an. Başka hiçbir şey.

Kontrol noktası bildirimi diye bir mekanizma bilerek **yok** — ilerleme
karakterin gerçek konumundan okunuyor, bu yüzden "checkpoint spam" diye bir
saldırı yüzeyi oluşmuyor.

## Ağ girişi: tek kapı, tek doğrulama

Üç remote var (`Shared/Net/Remotes`), hepsi `NetService`'ten geçiyor:

- **Hız sınırı**: jeton kovası. Eylemler saniyede 8 (patlama 20), soygun
  girdileri saniyede 30. Aşan istek sessizce düşer.
- **Hata yalıtımı**: her işleyici `pcall` içinde; sunucu hatası istemciye
  sızmaz, sadece loglanır.
- **Tip doğrulama**: `Core/Validate` üzerinden.

### Validate neden ayrı bir modül

```lua
local amount = math.clamp(math.floor(tonumber(payload.amount) or 1), 1, 10)
```

Bu satır masum görünüyor. Ama `payload.amount = "nan"` gönderilirse
`tonumber("nan")` → nan, `math.floor(nan)` → nan, `math.clamp(nan, 1, 10)`
→ **nan**. Sonra `profile.crates[id] = (mevcut) + nan` çalışıyor ve kayıt
kalıcı olarak bozuluyor — oyuncu bir daha düzgün oynayamıyor.

`Validate` bunu ve benzerlerini tek yerde kapatıyor:

| Fonksiyon | Ne yapar |
|---|---|
| `finite` | NaN ve sonsuzu eler |
| `integer(value, min, max)` | Aralık dışını **reddeder** (sessizce kırpmaz) |
| `clampedInteger` | Kırpmanın gerçekten zararsız olduğu yerler için |
| `identifier` | Dizgi, uzunluk sınırlı, kontrol karakteri yok |
| `list(value, max, item)` | Eleman sayısı sınırlı — sınırsız liste sunucuyu döngüde tutar |
| `oneOf` | Değer tanımlı kümede mi |
| `sanitizeNumber` | Bozuk kayıttan gelen sayıyı güvenli değere çeker |

Aralık dışını kırpmak yerine reddetmek bilinçli: istemci 10.000 sandık
istiyorsa bu ya hata ya saldırıdır, 10'a yuvarlayıp devam etmek ikisini de
gizler.

## Anti-cheat: konum doğrulaması

Karakterin fiziği istemcide; hırsız teorik olarak kendini kapıya
ışınlayabilir. Sunucu her tikte yatay yer değiştirmeyi ölçüyor:

```
izin verilen = maxHorizontalSpeed × dt + positionToleranceStuds
```

Aşılırsa oyuncu son geçerli konuma geri alınıyor; `maxViolations` (3) ihlalde
soygun yakalanmış sayılıyor.

**Düzeltilen hata:** tolerans 12 stud'du ve her tike ekleniyordu. 20 Hz'de
bu, saniyede 240 stud'luk ışınlanmaya izin veriyor demekti — anti-cheat
pratikte hiçbir şey yakalamıyordu. Şimdi 3 stud (ağ gecikmesi payı).

## Kayıt: oturum kilidi ve göç

DataStore anahtarı başına:

```lua
{ data = <profil>, lock = { jobId = "...", at = <zaman> }, updatedAt = <zaman> }
```

- **Oturum kilidi**: aynı profil iki sunucuda aynı anda yazılamaz. Kilit
  başka sunucudaysa 10 kez, 6 saniye arayla denenir; olmazsa oyuncu nazikçe
  atılır. Kilit 15 dakika sonra bayatlar (sunucu çökerse profil kilitli kalmaz).
- **Otomatik kayıt** 120 saniyede bir, `BindToClose` kapanışta bekler.
- **Çevrimdışı oyuncudan çalma** `UpdateAsync` içinde kilidi kontrol eder;
  kilit başka sunucudaysa soygun sonuçsuz kalır. Veri kaybı riskini almak
  yerine nadir bir "hedef başka sunucuda" durumunu kabul ediyoruz.

### Bozuk kayıt yüklenirse

`ProfileTemplate.reconcile` her yüklemede:

- eksik alanları şablondan tamamlar
- **tipi tutmayan alanı** şablon değeriyle değiştirir (`coins` bir tablo
  olarak gelirse aritmetik hata oyuncuyu tamamen kilitler)
- NaN, sonsuz ve negatif sayıları güvenli değere çeker
- gelecekten gelen zaman damgalarını bugüne çeker
- tanımsız nadirlik/mutasyon taşıyan hazineleri düşürür
- envanterde olmayan yerleştirilmiş hazineleri temizler
- makbuz listesini 50 ile sınırlar (kayıt boyutu sınırsız büyümesin)

## Satın alma

- `ProcessReceipt` makbuz kimliğini profile yazıyor; aynı makbuz iki kez
  işlenmiyor.
- Profil yüklenmemişse `NotProcessedYet` dönüyor — Roblox tekrar deniyor,
  ödül kaybolmuyor.
- Gamepass sahipliği oturum başında bir kez sorgulanıp önbelleğe alınıyor;
  satın alma anında güncelleniyor.
- Tek seferlik ürünler (Başlangıç Paketi) mağazada "ALINDI" gösteriliyor ve
  pencere bir daha açılmıyor.

## Arayüz: RichText kaçırma

Bütün metin etiketlerinde `RichText` açık. Dışarıdan gelen metinler (oyuncu
adları) duyurulara ve bildirimlere giriyor. Roblox ad kuralları `<`
karakterine izin vermiyor ama bu koruma Roblox'un kuralına bağlı olmamalı:
`Format.escapeRichText` duyuru ve bildirim metinlerinde uygulanıyor.

## Marketplace modelleri

`tools/studio/asset_audit.luau` import edilen modeli tarar ve script'leri
siler. Tarayıcı `require(<sayı>)`, `getfenv`, `loadstring`, `HttpService`,
`DataStoreService`, obfuskasyon desenleri ve şüpheli isimleri arar.

**Tarayıcı bir garanti değil.** Yeni ya da yeterince gizlenmiş bir backdoor
kaçabilir. Tek gerçekten güvenli yaklaşım: **dekoratif modelde hiç script
bırakmamak.** Araç varsayılan olarak hepsini siliyor.

## Korunmayanlar (bilinçli)

- **Kasa listesindeki bilgiler** (servet, birikim, savunma puanı) diğer
  oyunculara açık. Hedef seçimi için gerekli, hassas veri değil.
- **Hız hilesi tam engellenemez.** Konum doğrulaması sıçramaları yakalar
  ama fizik istemcide olduğu sürece kusursuz koruma yok. Soygun kısa ve
  ödülü sınırlı olduğu için bu kabul edilebilir bir risk.
- **Kod kullanım limiti yok.** Kodlar oyuncu başına bir kez çalışıyor ama
  global toplam sınırı yok; sızan bir kod herkes tarafından kullanılabilir.
- **Sunucular arası duyuru doğrulanmıyor.** `MessagingService` konusuna
  yalnızca kendi oyunun yazabildiği için risk düşük.

## Değişiklik yaparken

Yeni bir eylem eklerken:

1. `Remotes.Actions` içine adını ekle
2. İşleyiciyi `NetService.register` ile bağla
3. **Her payload alanını `Validate` üzerinden geçir** — tip kontrolü
   yapmadan hiçbir değeri profile yazma
4. Sunucunun karar verdiğinden emin ol: istemci fiyat, miktar ya da sonuç
   göndermemeli
