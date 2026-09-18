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
| Ahşap | 250 | 6 | 37 sn | 37 sn |
| Demir | 5.000 | 19 | 4:12 | 4:12 |
| Neon | 60.000 | 102 | 9:44 | 6:46 |
| Glitch | 750.000 | 430 | 29:00 | 11:50 |
| Boşluk | 12.000.000 | 1.940 | 1:42:57 | 20:35 |

"Bölge çarpanıyla" sütunu, o bölgeye ulaşmış oyuncunun tipik çarpanını
(bölge bonusu × rebirth) hesaba katıyor — gerçekte hissedilen süre bu.

**Asıl darboğaz para değil yuva sayısı.** Taban 6 yuva, yükseltmeyle +8,
gamepass ile +4, tavan 18. Üst kademe sandık, dolu bir yuvayı daha iyisiyle
değiştirdiği için değerli. Bu yüzden erken sandıkların "çok verimli"
görünmesi sorun değil: 6 yuvayı Ahşapla doldurduktan sonra ilerlemenin tek
yolu daha iyi sandık.

## Rebirth

```
gereken servet = 1.000.000 × 5.5^rebirth
kalıcı çarpan  = 1 + 0.25 × rebirth
```

| Rebirth | Gereken servet | Çarpan | Açılan bölge |
|---|---|---|---|
| 1 | 1M | x1.25 | Neon Şehir |
| 2 | 5.5M | x1.5 | |
| 3 | 30M | x1.75 | Glitch Sektörü |
| 4 | 166M | x2 | |
| 6 | 5B | x2.5 | Boşluk Kasası |

Bu eşik tahmin değil, ölçüm: `tests/specs/Progression.spec.luau` gerçek
loot ve ekonomi fonksiyonlarıyla oyuncu simüle ediyor. 25 tohumluk örneklemde
ortanca servet **5 dakikada 158K, 10 dakikada 445K, 15 dakikada 1.0M,
20 dakikada 1.66M**. 1M eşiği ilk rebirth'ü 15-20 dakikaya koyuyor — oyuncu
rebirth'ten önce soygun dahil bütün döngüyü bir kez görsün diye.

İlk ölçümde eşik 150K'daydı ve ortanca oyuncu **8 dakikada** rebirth
yapabiliyordu; simülasyon bunu yakaladı. Denge değiştirirsen bu testler
kırılacak — kırılması "yanlış" demek değil, "kararı yeniden ver" demek.

Sıfırlananlar: coin, hazineler, yükseltmeler. **Savunmalar kalır** — aksi
halde rebirth sonrası kasan savunmasız kalır ve hemen soyulursun. Ayrıca
10 dakikalık kalkan veriliyor.

Rebirth ayrıca jeton veriyor (n'inci rebirth → n jeton). Jetonlar yalnızca
Fırtına Sandığı'nda (3 jeton, sadece Efsanevi+) harcanıyor.

## Soygun ekonomisi

```
pay = 0.22 + çanta yükseltmesi (seviye başına +%2)
    + 0.15 (mükemmel soygun)
pay × = (1 - min(0.5, savunma puanı / 400))
pay × = event çarpanı
pay × = 0.5 (hedef çevrimdışıysa)
tavan = %60 (Kasa Fırtınası'nda %75)
```

Savunma puanı = Σ(seviye × ağırlık × 10) × savunma yükseltmesi × VIP Kilit
(x1.35) × çevrimdışı bonusu (x1.25) × event çarpanı.

Örnek: savunmasız kasadan %22, iyi savunulmuş kasadan (puan 400+) %11,
çevrimdışı iyi savunulmuş kasadan %5.5 alınıyor.

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

## Denge ayarı yaparken

1. `src/shared/Config/` içinde sayıyı değiştir
2. `./scripts/balance.sh` — geri ödeme süreleri ve eşikler ne oldu?
3. `./scripts/test.sh` — tutarlılık testleri (bilinmeyen id, negatif
   maliyet, bozuk ödül tanımı) kırıldı mı?

Canlıda izlenecek sayılar:

- **Ortalama oturum süresi** — 2-3 dakikalık döngü tutuyor mu
- **Soygun / oturum oranı** — 1'in altındaysa hedef bulunamıyor demektir
- **Soyulma sonrası çıkış oranı** — yüksekse korumalar yetersiz
- **İlk rebirth'e kadar geçen süre** — hedef 15-25 dakika
- **Sandık açma / coin kazanma oranı** — 1'in çok altındaysa enflasyon var
