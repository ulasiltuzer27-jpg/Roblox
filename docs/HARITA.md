# Harita

Beş bölge, hepsi koddan üretiliyor. Geometri saf ve test edilmiş; Roblox
açmadan "parsel zeminin dışında mı", "spawn duvarın içinde mi" gibi sorular
cevaplanabiliyor.

## Neden koddan

İlk hub elle kurulmuştu ve şu hata gözden kaçtı: parseller yarıçap 140'a
dizilmişti ama zemin ±130'du. **Oyuncular kasalarına giderken haritadan
düşüyordu** ve bunu ancak Studio'da yürüyerek görebilirdin.

Şimdi geometri `src/shared/Core/MapLayout.luau` içinde saf fonksiyonlar
olarak üretiliyor ve `tests/specs/MapLayout.spec.luau` her bölge için
kontrol ediyor:

- parseller zeminin ve duvarın içinde mi
- parseller birbirine giriyor mu
- kiosklar üst üste biniyor mu
- spawn boş mu (hiçbir katı parça spawn'a yakın değil)
- kapılar bütün bölgelere açılıyor ve birbirine girmiyor mu
- parça ve ışık bütçesi aşılıyor mu
- bölgeler birbiriyle ve soygun arenalarıyla çakışıyor mu

## Yerleşim anatomisi

Her bölge aynı iskeleti paylaşıyor, tema değişiyor:

```
        ┌──────── dış duvar (sekizgen, r=158) ────────┐
        │   ○ ○ ○ ○  kasa parselleri (r=112)  ○ ○ ○   │
        │ ○                                         ○ │
        │ ○     ╔═══ meydan (sekizgen, r=38) ═══╗   ○ │
        │ ○     ║   kiosklar (r=30, 6 adet)     ║   ○ │
        │ ○     ║      ▲ dikilitaş ▲            ║   ○ │
        │ ○     ║        spawn                  ║   ○ │
        │ ○     ╚═══════════════════════════════╝   ○ │
        │ ○        bölge kapıları (r=54)            ○ │
        │   ○ ○ ○ ○     dekoratif sütunlar (r=138)    │
        └─────────── zemin 340 × 340 ─────────────────┘
```

| Ölçü | Değer | Kural |
|---|---|---|
| Zemin | 340 × 340 | her şeyi içermeli |
| Dış duvar | r = 158, h = 26 | haritadan düşmeyi engeller |
| Dekoratif sütunlar | r = 138 | duvarla parsel arasında |
| Kasa parselleri | r = 112, 24×20 | duvarın içinde, meydana değmez |
| Bölge kapıları | r = 54 | meydanın dışında, parsellerin içinde |
| Meydan | r = 38, +1.5 yükseklik | 3 basamakla zemine bağlanır |
| Kiosklar | r = 30 | meydanın üstünde |
| Dikilitaş | h = 30 | uzaktan görünen işaret noktası |

Sayılar `src/shared/Config/Map.luau` içinde. Değiştirirsen testler
tutarsızlığı söyler.

## Bölgeler

| Bölge | Tema | Parsel | Hava |
|---|---|---|---|
| Merkez Kasa Katı | beton + altın | 24 | karanlık kasa katı, sütunlar |
| Neon Şehir | koyu metal + camgöbeği/magenta | 20 | gece, neon pilonlar ve tabelalar |
| Glitch Sektörü | magenta + yeşil | 16 | eğik kırık bloklar, havada glitch küpleri |
| Boşluk Kasası | mor + cam zemin | 14 | yüzen kristaller, dipsizlik hissi |
| Kuantum Kasa | beyaz + camgöbeği | 12 | iç içe halkalar, temiz geometri |

Parsel sayısı bölgenin beklenen nüfusuna göre azalıyor: ileri bölgelerde
daha az oyuncu olacak, boş parsel denizi kötü görünür.

## Işık ve atmosfer

Işık **istemcide** ayarlanıyor (`AmbienceController`), çünkü `Lighting`
global: aynı sunucuda farklı bölgelerdeki oyuncular kendi bölgelerinin
havasını görsün istiyoruz. Geçişler 1.2 saniyede yumuşuyor.

Işık bütçesi bölge başına **20 PointLight**. İlk sürümde her parsel
çerçevesine ve her sütuna ışık konmuştu: beş bölgede 189 ışık, mobilde
kare hızını düşüren bir sayı. Şimdi 42 (bölge başına 5-12) ve test bunu
koruyor. Neon malzeme zaten parlıyor; ışık sadece gerçekten gereken
yerlerde.

## Bölgeler arası geçiş

Her bölgede diğer dört bölgeye açılan kapılar var (meydanın arkasında yarım
daire). Kapıya yaklaşıp tuşa basmak yeterli; **Bölgeler** paneli aynı işi
yürümeden yapıyor.

Kilitli bölgeler kapıda `🔒 N rebirth` diye görünüyor ve sunucu isteği
reddediyor. Geçişte oyuncunun parseli yeni bölgeye taşınıyor, doğma noktası
güncelleniyor ve karakter ışınlanıyor.

> Bu akış baştan eksikti: `TravelZone` yalnızca profildeki `zone` alanını
> değiştiriyordu, oyuncuyu taşımıyordu ve zaten diğer bölgeler fiziksel
> olarak kurulmuyordu. Bölgeler oyunda erişilemez bir içerikti.

## Yeni bölge eklemek

1. `src/shared/Config/Zones.luau` — bölgeyi, rebirth eşiğini ve dünya
   merkezini ekle (merkezler en az 380 stud arayla)
2. `src/shared/Config/Map.luau` — `Map.Themes` içine bir tema, `Map.Zones`
   içine bir satır
3. Yeni bir süsleme tarzı istiyorsan `MapLayout.buildProps` içine ekle
4. `./scripts/test.sh` — yerleşim testleri yeni bölgeyi kendiliğinden kapsar

Sandık eklemek istersen `Config/Crates.luau` içinde `zone` alanını yeni
bölgeye ayarla.

## Creator Store modelleriyle birleştirmek

Kod ile üretilen harita iskelet; üstüne hazır model koymak serbest.

1. `tools/studio/asset_audit.luau` ile modeli tara (script'leri siler)
2. `tools/studio/build_map.luau` içindeki `ASSETS` tablosuna ekle ve çalıştır
3. Modeller `Workspace.Harita` altına gelir; kod ile üretilen dünya
   `Workspace.Dunya` altındadır — birbirine karışmazlar

Kod üretimini tamamen bırakıp elle harita yapmak istersen `WorldService`
içindeki `buildZone` çağrısını kaldırıp parselleri elle yerleştirmen
yeterli; parsel atama mantığı aynı kalır.

## Yer dosyası notu

`VaultHeist.rbxl` haritayı **içermez**: dünya sunucu açılışında koddan
kuruluyor. Dosyayı Studio'da açtığında Workspace boş görünür, F5'e
bastığında dünya belirir. Bu bilinçli — harita kod, veri değil.
