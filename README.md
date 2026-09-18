# Vault Heist — Kasa Soygunu

Roblox için "kendi kasanı kur, başkasınınkini soy" oyunu. Sandık açıp nadir
ve mutasyonlu hazineler topluyorsun, bunlar sen oyunda olmasan bile pasif
gelir üretiyor; diğer oyuncular lazer koridorundan geçip birikimini çalmaya
çalışıyor.

Bu depo oyunun **çalışan kod tabanı**: denge sayıları, sunucu mantığı,
istemci arayüzü, prosedürel soygun koridoru ve Roblox olmadan koşan testler.

## Ana döngü

1. **Sandık aç** — nadirlik + mutasyon zarı sunucuda atılır (Sıradan → Gizli,
   Normal → Prizma). Çıkan hazine boş yuva varsa kasana kendiliğinden girer.
2. **Kasanı kur** — hazineler saniyelik gelir üretir. Gelir cebe değil
   *kasadaki birikime* gider ve toplanana kadar çalınabilir.
3. **Savun** — lazer, kapan, hareket sensörü, bekçi NPC, kasa kapısı.
   Her savunma soygun koridorunu uzatır ve alarmı hızlandırır.
4. **Soy** — başkasının kasasına gir, prosedürel koridoru geç, kapıdaki
   kilit zamanlamasını tuttur, payını al. Yakalanırsan hapis.
5. **Yükselt / rebirth** — yuva, gelir, şans, sinsilik; sonra sıfırla ve
   kalıcı çarpanla yeni bölgeleri aç.

Her 10 dakikada bir sunucu eventi (Altın Saat, Kasa Fırtınası, Mutasyon
Yağmuru, Şanslı Sandıklar, Bekçi Grevi) tüm sunucularda **aynı anda** başlar.

## Hızlı başlangıç

```bash
# Araçlar (rokit.toml içindeki sürümler)
rokit install

# Studio'ya bağlan
rojo serve            # Studio'da Rojo eklentisinden Connect
# veya tek dosya üret
rojo build -o VaultHeist.rbxlx
```

Studio'da **Game Settings → Security → Enable Studio Access to API Services**
açık olmalı; kapalıysa oyun yine çalışır ama kayıt bellek içinde tutulur
(sunucu kapanınca gider).

## Komutlar

| Komut | Ne yapar |
|---|---|
| `./scripts/test.sh` | Oyun matematiğinin testlerini koşar (141 test, Roblox gerekmez) |
| `./scripts/check.sh` | Bütün `.luau` dosyalarını derleyerek sözdizimini doğrular |
| `./scripts/balance.sh` | Denge raporu: sandık geri ödeme süreleri, rebirth eşikleri, maliyet tabloları |
| `./scripts/sim.sh` | Ekonomi simülasyonu: dört oyuncu arketipi, Monte Carlo, ölçüt uyarıları + grafikler |

Testler `luau` ikilisiyle koşar. PATH'te değilse: `LUAU_BIN=/yol/luau ./scripts/test.sh`

## Yapı

```
src/shared/Config/    Bütün denge sayıları (nadirlik, sandık, savunma, event, ücret)
src/shared/Core/      Saf oyun matematiği -- Roblox API'si yok, bu yüzden test edilebilir
src/shared/Net/       Remote tanımları
src/server/Services/  Kayıt, ekonomi, soygun oturumu, dünya, monetizasyon
src/client/           Arayüz ve girdi
tests/                Core + Config testleri
tools/                Denge raporu ve config dışa aktarımı
sim/                  Python ekonomi simülasyonu (oyunun kendi sayılarını okur)
docs/                 Tasarım, ekonomi, mimari, yayın kontrol listesi
```

Denge değişikliği yapacaksan tek durağın `src/shared/Config/`. Sayıları
değiştir, `./scripts/balance.sh` ile etkisini gör, `./scripts/test.sh` ile
tutarlılığı doğrula.

## Yayına çıkmadan önce

`src/shared/Config/Monetization.luau` içindeki bütün `assetId = 0` alanları
yer tutucu. Creator Dashboard'da gamepass ve developer product oluşturup
ID'leri oraya yaz — başka hiçbir dosyada ID geçmiyor. ID'ler girilene kadar
mağaza "Yakında" gösterir ve satın alma penceresi açılmaz.

Tam liste: [docs/YAYIN.md](docs/YAYIN.md)

## Dokümanlar

- [docs/TASARIM.md](docs/TASARIM.md) — oynanış kararları ve neden öyle
- [docs/EKONOMI.md](docs/EKONOMI.md) — ekonomi, ilerleme eğrisi, denge ayarı
- [docs/MIMARI.md](docs/MIMARI.md) — kod mimarisi, veri akışı, güvenlik modeli
- [docs/YAYIN.md](docs/YAYIN.md) — yayın kontrol listesi ve 1000 oyuncu meselesi
- [docs/STUDIO_TEST.md](docs/STUDIO_TEST.md) — Studio'da elle test listesi
- [docs/PAZARLAMA.md](docs/PAZARLAMA.md) — ikon/thumbnail brief'i, açıklama, video metinleri, creator mesajı
- [tools/studio/](tools/studio/) — Marketplace model denetimi ve harita kurucu
- [tools/blender/](tools/blender/) — low-poly model üretimi
