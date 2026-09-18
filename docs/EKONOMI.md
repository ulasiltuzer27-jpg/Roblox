# Ekonomi ve Denge

Bütün sayılar `src/shared/Config/` altında. Bu doküman sayıların *neden*
öyle olduğunu ve neyi değiştirince neyin bozulduğunu anlatıyor.

Güncel tabloları görmek için: `./scripts/balance.sh`

## Gelir formülü

```
hazine geliri   = nadirlik.baseIncome × mutasyon.multiplier
kasa geliri/sn  = Σ(yerleştirilmiş hazineler) × çarpanlar

çarpanlar = (1 + gelir yükseltmesi)      -- seviye başına +%8, 25 seviye
          × (1 + 0.25 × rebirth)
          × (1 + bölge bonusu)            -- %0 / %15 / %40 / %100
          × (2 eğer "2x Gelir" gamepass)
          × event çarpanı                 -- Altın Saat'te 2
```

Çarpanlar çarpımsal. Tam donanımlı bir oyuncu (25. seviye gelir, 6 rebirth,
Boşluk bölgesi, gamepass, Altın Saat) taban gelirinin **~40 katını** üretir.
Bu bilinçli: üst seviye oyuncunun kasası, yeni oyuncu için çekici bir hedef
olacak kadar dolu olsun.

## Nadirlik ve mutasyon

| Nadirlik | Gelir/sn | | Mutasyon | Çarpan | Şans |
|---|---|---|---|---|---|
| Sıradan | 1 | | Normal | x1 | %80 |
| Alışılmadık | 4 | | Altın | x2.5 | %15 |
| Nadir | 16 | | Neon | x6 | %4 |
| Epik | 70 | | Glitch | x15 | 1/125 |
| Efsanevi | 300 | | Boşluk | x40 | 1/555 |
| Mitik | 1.400 | | Prizma | x150 | 1/5.000 |
| Gizli | 7.500 | | | | |

Nadirlik ~4.5x adımlarla, mutasyon 2.5x-150x arası. İkisi çarpıldığı için en
tepe (Gizli + Prizma = 1.125.000/sn) ile taban (Sıradan + Normal = 1/sn)
arasında bir milyon kat fark var — "chase" duygusunun kaynağı bu.

Beklenen mutasyon çarpanı **x1.637**. Yani bir sandığın ortalama değeri,
mutasyonsuz değerinin 1.64 katı.

### Şans çarpanı nasıl işliyor

```
w' = w × şans^((nadirlik sırası - 2) × 0.5)
```

Şans yalnızca **Nadir ve üstünü** büker; Sıradan/Alışılmadık ağırlığı sabit
kalır. Böylece şans yükseltmesi çöpü azaltmaz, tepeyi yükseltir. Panelde
gösterilen yüzdeler tam olarak bu fonksiyondan okunuyor — ekrandaki oran ile
atılan zar aynı (test: `Loot.spec`).

## Sandık fiyatlandırması

Kural: bir sandık, o kademenin beklenen gelirine göre kabaca **1-30 dakikada**
kendini ödesin.

| Sandık | Fiyat | Beklenen gelir/sn | Geri ödeme | Bölge çarpanıyla |
|---|---|---|---|---|
| Ahşap | 600 | 7 | 1.5 dk | 1.5 dk |
| Demir | 5.000 | 20 | 4.2 dk | 4.2 dk |
| Neon | 60.000 | 103 | 9.7 dk | 4.5 dk |
| Glitch | 750.000 | 431 | 29 dk | 8.3 dk |
| Boşluk | 7.000.000 | 1.940 | 60 dk | 7.5 dk |
| Kuantum | 150.000.000 | 4.692 | 8.9 saat | 30 dk |

"Bölge çarpanıyla" sütunu, o bölgeye ulaşmış oyuncunun tipik çarpanını
(bölge bonusu × rebirth) hesaba katıyor — gerçekte hissedilen süre bu.

**Asıl darboğaz para değil yuva sayısı.** Taban 6 yuva, yükseltmeyle +8,
gamepass ile +4, tavan 18. Üst kademe sandık, dolu bir yuvayı daha iyisiyle
değiştirdiği için değerli. Bu yüzden erken sandıkların "çok verimli"
görünmesi sorun değil: 6 yuvayı Ahşapla doldurduktan sonra ilerlemenin tek
yolu daha iyi sandık.

## Rebirth

```
gereken servet = 250.000 × 5.5^rebirth
kalıcı çarpan  = 1 + 0.25 × rebirth
```

| Rebirth | Gereken servet | Çarpan | Açılan bölge |
|---|---|---|---|
| 1 | 250K | x1.25 | |
| 2 | 1.4M | x1.5 | Neon Şehir |
| 3 | 7.6M | x1.75 | |
| 6 | 1.3B | x2.5 | Glitch Sektörü |
| 12 | 30T | x4 | Boşluk Kasası |
| 20 | 14Qa | x6 | Kuantum Kasa |

Eşikler tahmin değil ölçüm: `sim/` altındaki simülasyon gerçek loot ve
ekonomi fonksiyonlarıyla dört oyuncu arketipini koşturuyor. Ölçülen tempo
(oyun içinde geçen dakika, ortanca oyuncu):

| Arketip | 1. rebirth | 3. rebirth | 6. rebirth |
|---|---|---|---|
| Ara sıra giren (24 dk/gün) | 12 dk | 60 dk | 156 dk |
| Düzenli oyuncu (75 dk/gün) | 24 dk | 75 dk | 193 dk |
| Hardcore (240 dk/gün) | 16 dk | 81 dk | 240 dk |
| Ödeme yapan | 12 dk | 43 dk | 108 dk |

Sıfırlananlar: coin, hazineler, yükseltmeler. **Savunmalar kalır** — aksi
halde rebirth sonrası kasan savunmasız kalır ve hemen soyulursun. Ayrıca
10 dakikalık kalkan veriliyor.

Rebirth ayrıca jeton veriyor (n'inci rebirth → n jeton). Jetonlar yalnızca
Fırtına Sandığı'nda (3 jeton, sadece Efsanevi+) harcanıyor.

## Satış ekonomisi

```
varlık değeri  = gelir/sn × 120        (servet hesabı bunu kullanır)
satış geliri   = varlık değeri × 0.25   (nakde çevirme oranı)
```

İkisi bilerek ayrı. İlk sürümde satış oranı 1.0'dı ve Ahşap Sandık 250
coin'e satılırken içinden çıkan hazinenin ortalama satış değeri 1.080
coin'di: **sandık alıp hazineyi satmak tek başına para basıyordu** ve
kasaya hazine koymanın hiçbir anlamı kalmıyordu. Simülasyon yakaladı.

Kural: beklenen satış iadesi / sandık fiyatı oranı hiçbir sandıkta 0.6'yı
geçmemeli. `tests/specs/Config.spec.luau` bunu en yüksek şans çarpanında
bile doğruluyor.

| Sandık | Fiyat | Beklenen iade | Oran |
|---|---|---|---|
| Ahşap | 600 | 199 | 0.33 |
| Demir | 5.000 | 594 | 0.12 |
| Neon | 60.000 | 3.08K | 0.05 |
| Glitch | 750.000 | 12.9K | 0.02 |

## Soygun ekonomisi

```
pay = 0.22 + çanta yükseltmesi (seviye başına +%2)
    + 0.15 (mükemmel soygun)
pay × = (1 - min(0.65, savunma puanı / 800))
pay × = event çarpanı
pay × = 0.5 (hedef çevrimdışıysa)
tavan = %60 (Kasa Fırtınası'nda %75)
```

Savunma puanı = Σ(seviye × ağırlık × 10) × savunma yükseltmesi × VIP Kilit
(x1.35) × çevrimdışı bonusu (x1.25) × event çarpanı.

Bölen ilk sürümde 400 ve tavan 0.5'ti: direnç 200 puanda doluyordu, oysa
tam donanımlı bir kasa ~800 puan üretiyor — yani savunma harcamasının
dörtte üçü çalınan paya hiç etki etmiyordu. Şimdi eğri yatırımın tamamı
boyunca anlamlı:

| Savunma puanı | Çevrimdışı kayıp |
|---|---|
| 0 | %11.0 |
| 100 | %9.6 |
| 250 | %7.6 |
| 520+ | %3.9 (tavan) |

Yakalanan hırsız 25 saniye hapis yatıyor (VIP ile 12.5) ve kasa sahibine
birikimin %5'i tazminat yazılıyor — **savunma yatırımının geri dönüşü bu**.

## Para çıkışları (sink)

Idle oyunlarda enflasyon, oyunun ömrünü bitiren şey. Çıkışlar:

- Sandıklar (ana çıkış — gelirin büyük kısmı buraya gider)
- Savunmalar: hepsi tam seviye ~17.7M coin
- Yükseltmeler: hepsi tam seviye ~482M coin
- Rebirth: coin ve hazineleri tamamen siler
- Soygun: para oyuncular arasında el değiştirir, **yaratılmaz**

Soygunun para yaratmaması önemli. Tek istisna NPC kasaları (birikimleri
yoktan var edilir) — bu yüzden birikimleri hırsızın kendi gelirine bağlı ve
`maxStashMultiplier` ile tavanlı, ayrıca yalnızca sunucuda az gerçek hedef
varken listeye giriyorlar.

## Çevrimdışı gelir dengesi

İlk ölçümde çevrimdışı verim %50 ve tavan 8 saatti. Sonuç: düzenli
oyuncunun gelirinin **%82'si** çevrimdışından geliyordu — yani oyuna girip
oynamanın ekonomik karşılığı yoktu, en verimli strateji "gir, topla, çık"
oluyordu. Oturum süresi ve ertesi gün dönüşü keşfet algoritmasının baktığı
metrikler olduğu için bu doğrudan bir büyüme sorunu.

Verim %25'e, tavan 6 saate çekildi. Şimdi düzenli oyuncunun gelirinin
%36'sı, hardcore oyuncunun %82'si oyundayken kazanılıyor.

## Denge ayarı yaparken

1. `src/shared/Config/` içinde sayıyı değiştir
2. `./scripts/balance.sh` — geri ödeme süreleri ve eşikler ne oldu?
3. `./scripts/sim.sh` — arketipler nereye gidiyor, ölçüt uyarısı var mı?
4. `./scripts/test.sh` — tutarlılık ve tempo testleri kırıldı mı?

`./scripts/sim.sh` dengede otomatik ölçüt kontrolü yapıyor: sandık geri
ödeme süresi, ilk rebirth temposu, içerik tüketimi, al-sat kârlılığı,
soygun gelirinin payı ve çevrimiçi gelirin payı. Uyarı çıkarsa rapor
sebebini yazıyor.

Canlıda izlenecek sayılar:

- **Ortalama oturum süresi** — 2-3 dakikalık döngü tutuyor mu
- **Soygun / oturum oranı** — 1'in altındaysa hedef bulunamıyor demektir
- **Soyulma sonrası çıkış oranı** — yüksekse korumalar yetersiz
- **İlk rebirth'e kadar geçen süre** — hedef 15-25 dakika
- **Sandık açma / coin kazanma oranı** — 1'in çok altındaysa enflasyon var
