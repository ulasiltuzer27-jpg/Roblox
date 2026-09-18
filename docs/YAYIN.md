# Yayın Kontrol Listesi ve 1000 Oyuncu Meselesi

## Önce dürüst kısım

Hiçbir fikir 1000 eşzamanlı oyuncuyu garanti etmez. Roblox'ta yayınlanan
oyunların büyük çoğunluğu hiçbir zaman üç haneli sayıyı görmez. "Vault Heist"
fikri iyi ve kanıtlanmış bir türün üstünde duruyor, ama tek başına bir fikir
bu sayıyı getirmez.

Getiren şey şu üçlü: **ilk 60 saniye**, **ertesi gün dönüş**, **düzenli
güncelleme**. Bu depodaki kararların çoğu bu üçüne hizmet ediyor. Aşağıda
hangisinin kodda karşılığı olduğunu ve neyin hâlâ senin işin olduğunu
ayırdım.

---

## Yayın öncesi teknik liste

### Zorunlu

- [ ] **Monetizasyon ID'leri**: `src/shared/Config/Monetization.luau` içindeki
      bütün `assetId = 0` alanlarını Creator Dashboard'daki gerçek ID'lerle
      değiştir. Başka hiçbir dosyada ID geçmiyor.
      (`Config.spec` içindeki "asset id'leri girilmeli" testi bilerek
      yer tutucuyu bekliyor; ID'leri girince kırmızıya döner — düzeltmeyi
      unutmadığının kanıtı olarak testi güncelle.)
- [ ] **API Services**: Game Settings → Security → *Enable Studio Access to
      API Services* ve yayındaki oyunda DataStore erişimi açık olmalı.
      Kapalıyken oyun çalışır ama kayıt bellekte tutulur ve sunucu kapanınca
      gider (`DataService` konsola uyarı basar).
- [ ] **MessagingService**: sunucular arası duyurular (Prizma bulundu vb.)
      buna bağlı. Kapalıysa sunucu içi duyurular çalışmaya devam eder.
- [ ] **Gerçek sunucuda test**: Studio'da tek oyuncuyla soygun döngüsü
      yarım kalır. İki hesapla (ya da Team Test) en az bir kez:
      kasa kur → soyul → soy → yakalan → hapis → rebirth.
- [ ] **Mobil test**: arayüz dokunmatikle çalışıyor, soygun ekranında
      Sinsi/Normal/Koşu düğmeleri ve kapı için "KIR" düğmesi var. Yine de
      gerçek telefonda bir kez baştan sona oyna: buton boyutları ve
      kamera açısı ancak orada anlaşılıyor.

### Şiddetle önerilen

- [ ] **İkon ve thumbnail**: keşfet sayfasındaki tıklama oranını bunlar
      belirliyor. Lazer koridoru + "SOYGUN" okunabilirliği yüksek bir
      görsel verir.
- [ ] **Oyun adı ve açıklama**: arama terimlerini içersin
      ("steal", "heist", "vault", "obby").
- [ ] **Tanıtım kodları**: `src/shared/Config/Codes.luau` içinde üç kod
      hazır. Tanıtımcıya kod vereceksen listeye ekle, oyuncu Mağaza
      panelinden giriyor. (Global kullanım limiti yok — kod başına toplam
      kullanım sınırı istiyorsan ayrı bir DataStore sayacı gerekir.)
- [ ] **Analitik**: `AnalyticsService` açılış hunisini ve ekonomi akışını
      gönderiyor (Katıldı → İlk sandık → İlk soygun → İlk rebirth).
      Creator Dashboard'da bu huninin nerede kırıldığına bak.

---

## İlk 60 saniye

Kodda karşılığı olan:

- 250 coin + 3 ücretsiz Ahşap Sandıkla başlama
- Sandıktan çıkan hazinenin boş yuvaya **kendiliğinden** yerleşmesi
  (oyuncu "yerleştirme" mekaniğini öğrenmeden önce geliri görüyor)
- 4 adımlık, her adımı ödüllü, gerçek oynanış olaylarıyla ilerleyen eğitim
- Alt bardaki düğmelerle her panele tek tıkla erişim (kiosklara yürümek
  zorunlu değil)
- İkinci sandık için gereken süre ~37 saniye

Senin işin: ilk oturumu izle. Birinin yanına otur, oynat, sus ve not al.
Nerede duraksıyor? Hangi düğmeyi arıyor? Bu 20 dakikalık iş, dashboard'daki
hiçbir grafikten daha çok şey söyler.

## Ertesi gün dönüş

Kodda karşılığı olan:

- Çevrimdışı gelir (8 saat, %50 verim) — "girince beni para bekliyor"
- 7 günlük artan seri ödülü, 7. gün bilerek büyük
- Birikim tavanı (2 saat) — dolunca üretim durur, geri gelme sebebi
- Her 10 dakikada bir, bütün sunucularda aynı anda başlayan event
- Liderlik tabloları (servet, soygun sayısı, tek seferde en büyük vurgun)

Senin işin: bildirim (Roblox badge/notification) ve sosyal bağ. Arkadaşıyla
oynayan oyuncu, tek oynayandan kat kat daha uzun kalıyor.

## Haftalık güncelleme

Bu kod tabanının en güçlü yanı burası. Haftalık içerik eklemek çoğunlukla
**tek bir config satırı**:

| Ne | Nerede | Efor |
|---|---|---|
| Yeni sandık | `Config/Crates.luau` — bir tablo girdisi | dakikalar |
| Yeni mutasyon | `Config/Mutations.luau` — ağırlık + çarpan | dakikalar |
| Yeni nadirlik | `Config/Rarities.luau` | dakikalar |
| Yeni sunucu eventi | `Config/ServerEvents.luau` — etki alanları hazır | dakikalar |
| Yeni savunma | `Config/Defenses.luau` + koridorda çizim | saatler |
| Yeni bölge | `Config/Zones.luau` | dakikalar |
| Tanıtım kodu | `Config/Codes.luau` | dakikalar |

Her değişiklikten sonra `./scripts/balance.sh` ile geri ödeme sürelerine,
`./scripts/test.sh` ile tutarlılığa bak. Config testleri bilinmeyen id,
bozuk ödül tanımı, ters giden maliyet eğrisi gibi klasik hataları yakalıyor.

Öneri: **haftanın belirli bir günü** güncelleme yayınla ve bunu oyun
açıklamasında duyur. Oyuncu ne zaman geleceğini bilsin.

## Tanıtım

- Roblox'un kendi reklamları (Sponsored Experiences): ilk 1000'e ulaşmanın
  en öngörülebilir yolu, ama pahalı. Küçük bütçeyle test et, tıklama ve
  tutundurma oranına bak, ancak ikisi de iyiyse ölçekle.
- Küçük YouTube/TikTok oyun tanıtımcıları: kod vererek anlaş. Kod sistemi
  hazır. Büyük kanallar yerine 5-50 bin abonelik, o türü oynayan kanallar
  daha iyi dönüş veriyor.
- Kendi klip malzemen: oyun zaten paylaşılabilir anlar üretiyor (Prizma
  duyurusu, mükemmel soygun duyurusu, soyulma bandı). Bunları ekran
  kaydıyla toplayıp kısa video yapmak reklamdan ucuz.

## Yayın sonrası ilk hafta: neye bak

| Sayı | Hedef | Kötüyse ne anlama gelir |
|---|---|---|
| Ortalama oturum süresi | 8+ dakika | döngü tutmuyor ya da ilk dakika kayıp |
| D1 dönüş | %15+ | geri gelme sebebi zayıf |
| Huni: Katıldı → İlk sandık | %90+ | eğitim ya da arayüz engelliyor |
| Huni: İlk sandık → İlk soygun | %50+ | soygun keşfedilmiyor veya hedef yok |
| Soyulma sonrası çıkış | %20'nin altı | korumalar yetersiz, ceza çok sert |
| İlk rebirth süresi | 15-25 dakika | ekonomi çok yavaş ya da çok hızlı |

Bu sayılar kötüyse **yeni içerik eklemek çözmez**. Önce huninin kırıldığı
yeri düzelt.

---

## Bilinen eksikler (yayın öncesi karar ver)

1. **Ses** — hiç ses yok. Alarm sesi, lazer vızıltısı ve sandık açılışı
   oyunun hissini kat kat artırır, maliyeti düşüktür.
2. **Sanatsal harita** — hub ve parseller kod ile kuruluyor, işlevsel ama
   sade. `WorldService` yerine Rojo ile model bağlanabilir.
3. **Kod kullanım limiti** — kodlar oyuncu başına bir kez çalışıyor, global
   toplam limiti yok.
4. **Takım soygunu / ticaret** — bilinçli olarak kapsam dışı
   (bkz. [TASARIM.md](TASARIM.md)).
