# CS2 Kasa Açıcı 📦

Eğlence amaçlı, tarayıcıda çalışan bir **Counter-Strike 2 kasa açma simülatörü**.
Gerçek para, gerçek eşya veya kumar yoktur. Bakiye tamamen sanaldır.

## Nasıl çalıştırılır?

1. ZIP'i bir klasöre çıkar.
2. `index.html` dosyasına çift tıkla (Chrome, Edge, Firefox, Opera...).

Kurulum gerekmez. Skin görselleri Steam'in sunucusundan geldiği için **internet bağlantısı** gerekir.
İlerlemen (bakiye, envanter, istatistikler) tarayıcının `localStorage` alanına kaydedilir.

## Neler var?

| Bölüm | Açıklama |
|---|---|
| 📦 **Kasalar** | 46 silah kasası (CS:GO Weapon Case'den Fever Case'e, terminaller dahil), 164 hatıra paketi, 102 çıkartma kapsülü, 139 imza kapsülü, arma/rozet/grafiti/müzik kiti kutuları ve 61 koleksiyon kutusu. Toplam **539 kasa/paket**. |
| 🔪 **Tüm skinler** | 2.126 silah/bıçak/eldiven skini + çıkartmalar, ajanlar, süsler… toplam **12.701 eşya**. Doppler / Gamma Doppler fazları (Ruby, Sapphire, Black Pearl, Emerald) ayrı ayrı. |
| 🎰 **Kasa açma** | CS2 tarzı dönen şerit, aynı anda 1–5 kasa, hızlı mod, ücretsiz "Deneme" modu, ★ nadir eşyada altın kart ve açılış efekti, `Boşluk` tuşu ile açma. |
| ⚔ **Item Fight** | Kasa savaşları: 1v1, 1v1v1, 1v1v1v1 ve 2v2. Botların açtığı savaşlara katıl ya da kendi savaşını kur (50 tura kadar). **Crazy Mod**'da en düşük değer kazanır. Kazanan tüm eşyaları alır. |
| ⬆ **Upgrader** | Eşyalarını ve/veya bakiyeni koy, daha pahalı bir skin seç. Şans oranını gösteren çark. |
| 🔁 **Takas Sözleşmesi** | CS2'deki gibi 10 eşya → bir üst kalite (aynı koleksiyon). **5 Örtülü → ★ bıçak/eldiven**. Float, girdilerin ortalamasına göre hesaplanır. |
| 🎒 **Envanter** | Float, desen tohumu, StatTrak™, hatıra, 💎 Blue Gem desenleri. Toplu satış, filtre ve sıralama. |
| 📖 **Katalog** | Oyundaki tüm eşyalar, aşınma bazında fiyat tablosu ve bulunduğu kasalar. |
| 👤 **Profil** | Silver I'den Global Elite'e rütbe, kâr/zarar, en iyi düşüş, son hareketler, ayarlar. |

## Oranlar

Gerçek CS2 oranları kullanılır:

| Kalite | Şans |
|---|---|
| Askeri Sınıf (mavi) | %79,92 |
| Yasaklı (mor) | %15,98 |
| Gizli (pembe) | %3,20 |
| Örtülü (kırmızı) | %0,64 |
| ★ Nadir Özel Eşya | %0,26 |

StatTrak™ şansı %10'dur. Hatıra paketlerinde ve koleksiyonlarda her kalite bir öncekinden 5 kat nadirdir.
Float değerleri CS2'nin aşınma dağılımına göre üretilir.

## Fiyatlar hakkında

Fiyatlar **tahminidir**; gerçek piyasa fiyatı değildir. Kaliteye, silaha, kasanın yaşına, aşınmaya,
StatTrak™/hatıra durumuna göre hesaplanır. Bazı ünlü skinler (Dragon Lore, Howl, Gungnir, Fire Serpent…)
gerçeğe yakın sabit fiyatlara sahiptir. Kasa fiyatları, kasanın beklenen değerine göre otomatik belirlenir
(yaklaşık %92 geri dönüş).

## Verileri güncelleme

Valve yeni kasa çıkardığında verileri yenilemek için (Python 3 gerekir):

```bash
python3 tools/build_data.py
```

Bu komut [ByMykel/CSGO-API](https://github.com/ByMykel/CSGO-API) verilerini indirir ve `js/data.js` dosyasını yeniden oluşturur.

## Dosya yapısı

```
index.html          ana sayfa
css/style.css       tasarım
js/data.js          tüm kasa ve eşya verisi (otomatik üretilir)
js/economy.js       fiyatlar, oranlar, çekiliş
js/state.js         bakiye, envanter, kayıt
js/reel.js          dönen şerit animasyonu
js/sound.js         sesler (WebAudio, dosya gerektirmez)
js/pages/*.js       sayfalar (kasalar, Item Fight, upgrader, takas, envanter, katalog, profil)
tools/build_data.py veri derleyici
```

---

Counter-Strike 2 ve tüm eşya görselleri Valve Corporation'a aittir. Bu proje Valve ile bağlantılı değildir.
