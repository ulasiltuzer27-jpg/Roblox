# Tasarım Notları

Fikrin kendisi netti; bu doküman koda dönüşürken verilen kararları ve
nedenlerini yazıyor. Çoğu karar "steal" türünün bilinen sorunlarına karşı
alınmış önlemler.

## Gerilim nereden geliyor: birikim vs. cep

Hazineler para üretir ama para doğrudan cebe gitmez, **kasadaki birikime**
(stash) yazılır. Birikim toplanana kadar çalınabilir; toplandığı an
güvendedir.

Bunun sonucu: oyuncu her an küçük bir karar veriyor. "Şimdi toplayayım mı,
yoksa biraz daha birikip 2 katına mı çıksın?" Oyundan çıkarken de aynı soru
var. Tek satırlık kural ama oyunun bütün gerilimi burada.

- Çevrimiçi birikim tavanı: 2 saatlik gelir (dolunca üretim durur — geri
  gelmek için sebep)
- Çevrimdışı kazanç: 8 saate kadar, %50 verimle (gamepass ile 12 saat)

## Soyulmak oyunu bıraktırmasın diye

Steal oyunlarının en büyük kaybı, soyulan oyuncunun bir daha girmemesi.
Alınan önlemler:

| Önlem | Değer | Neden |
|---|---|---|
| Kasa bekleme süresi | 90 sn | aynı kasa arka arkaya boşaltılamaz |
| Soyulma sonrası kalkan | 60 sn | üst üste vurulma yok |
| Aynı hedefe tekrar girme | 5 dk | tek bir oyuncuyu takip edip avlamak zor |
| Yeni oyuncu koruması | 5.000 servet altı | ilk dakikalar dokunulmaz |
| Alt sınır | hedefin serveti, hırsızın yarısından az olamaz | zenginler yenileri avlayamaz (yukarı doğru soygun serbest) |
| Çevrimdışı savunma | +%25 savunma, çalınan pay yarıya iner | çıkmak cezalandırılmasın |
| En değerli hazine | çalınamaz | "gurur eşyası" hep kalır |
| Tazminat | yakalanan hırsız, birikimin %5'ini kasa sahibine bırakır | savunmaya yatırım kârlı |

Savunma en fazla payı yarıya indirebilir — yani hiçbir kasa "soyulmaz"
olmaz. Aksi halde üst seviye oyuncular hedef listesinden çıkar ve oyunun
yarısı ölür.

## Soygun: obby değil, gerilim

Koridor tohumdan (seed) üretiliyor: savunma seviyeleri bölüm sayısını,
tehlike sayısını ve alarm hızını belirliyor. 3-8 bölüm, 24 stud'luk parçalar.

- **Lazer** — süpürerek geçiyor, ışında kaldığın sürece alarm dolar
- **Hareket sensörü** — menzilindeyken *hızına göre* alarm doldurur;
  durursan neredeyse görmez
- **Kapan** — 1-2 saniye yerinde sabitler, tam da lazerin geçtiği anda
- **Bekçi NPC** — görüş konisi, alarmın en hızlı dolduğu kaynak
- **Kasa kapısı** — koridorun sonunda zamanlama testi; kademe sayısı
  savunma seviyesiyle artıyor

Alarm 100'e ulaşırsa yakalanırsın. Kaynak yokken alarm saniyede 9 düşüyor —
"saklan, bekle, geç" oynanışı işe yarasın diye. Alarm hiç %25'in üstüne
çıkmadıysa **mükemmel soygun**: pay +%15 ve %50 ihtimalle hedefin
hazinelerinden birini de kaparsın.

Hareket modları: `Ctrl` sinsi (yavaş, gürültü %35), normal, `Shift` koşu
(hızlı, gürültü %180). Sensörlü koridorda koşmak intihar, lazerli koridorda
yavaşlık ölüm — koridorun yapısı hangi modu seçeceğini belirliyor.

### Neden koridoru sunucu kuruyor

Hırsızın konumunu sunucu okuyor, alarmı sunucu dolduruyor, kapı işaretçisini
sunucu hesaplıyor. İstemciden gelen tek şey **hareket modu tercihi** ve
**"tuşa bastım" sinyali**. Kontrol noktası bildirimi diye bir şey yok;
ilerleme karakterin gerçek konumundan okunuyor.

Hız doğrulaması: sunucunun izin verdiği hızın üstündeki sıçramalar geri
alınıyor, üç ihlalde soygun yakalanmış sayılıyor.

Her soygun kendi arenasında (birbirinden 500 stud uzakta, haritanın altında)
geçiyor; aynı anda 12 soygun mümkün.

## İlk 60 saniye

Yeni oyuncu 250 coin ve 3 ücretsiz Ahşap Sandıkla başlıyor. Sandık açar
açmaz hazine boş yuvaya kendiliğinden yerleşiyor ve gelir akmaya başlıyor —
"yerleştir" adımını oyuncuya öğretmeden önce ödülü gösteriyoruz.

Eğitim 4 adım ve her adımın kendi ödülü var: sandık aç → birikim topla →
savunma kur → bir kasa soy. Adımlar gerçek oynanış olaylarıyla ilerliyor,
"ileri" düğmesiyle değil.

Ölçüm: ilk sandık ~10 saniyede açılıyor, ikinci Ahşap Sandık için gereken
süre ~37 saniye (`./scripts/balance.sh`).

## Boş sunucu problemi

Soygun döngüsü diğer oyunculara bağlı. İlk 1000 oyuncuya giden yolda
sunucular çoğu zaman boş olacak — bu haliyle oyunun yarısı çalışmaz.

Çözüm: yeterli gerçek hedef yoksa listeye **NPC kasaları** giriyor
("Terk Edilmiş Kasa", "Şehir Bankası Deposu"...). Listede 🤖 ile açıkça
etiketleniyorlar, sahte oyuncu gibi gösterilmiyorlar. Birikimleri hırsızın
kendi gelirine göre ölçekleniyor (tavanlı), savunmaları rebirth sayısıyla
güçleniyor. Böylece tek başına giren biri de tam döngüyü yaşıyor.

## Eventler

10 dakikalık tur, son 2 dakikası event, 30 saniye önce uyarı. Zamanlama
duvar saatinden (`os.time()`) hesaplandığı için **bütün sunucularda aynı anda
aynı event** başlıyor — arkadaşına "gel, Kasa Fırtınası var" demek anlamlı.

| Event | Etki |
|---|---|
| Altın Saat | gelir x2 |
| Kasa Fırtınası | çalınan pay x2, savunmalar %25 zayıf |
| Mutasyon Yağmuru | mutasyon şansı x2 |
| Şanslı Sandıklar | nadirlik şansı +%50, sandıklar %25 indirimli |
| Bekçi Grevi | bütün bekçiler kapalı, pay +%25 |

## Paylaşılabilir anlar

Klip ve ekran görüntüsü üreten yerler bilinçli seçildi:

- Efsanevi+ nadirlik veya Glitch+ mutasyon → **sunucular arası** duyuru
- Mükemmel soygun → sunucu geneli duyuru ("alarm çaldırmadan soydu")
- Soyulma → kurbanın ekranında kırmızı bant, kim ne kadar aldı
- Prizma mutasyonu 1/5000 — tam olarak "klip çekilecek" nadirlikte

## Neyi bilerek yapmadık

- **Takım soygunu** — ilginç ama ilk sürümü ikiye katlar; koridor altyapısı
  çok oyunculuya hazır (arena başına tek oturum yerine liste tutulabilir)
- **Kasa dekorasyonu / tema** — güçlü bir tutundurucu ama önce temel döngü
- **Ticaret** — dolandırıcılık ve bot ekonomisi riski, şimdilik yok
- **Mobil özel yerleşim** — dokunmatik kontroller var (soygun ekranında
  mod düğmeleri, kapı düğmesi) ama panel yerleşimi küçük ekran için
  yeniden düzenlenmedi
