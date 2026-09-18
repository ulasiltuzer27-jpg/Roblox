# Blender Model Üretimi

Low-poly kasa, sandık, lazer, kristal ve kaide modellerini kod ile üretip
FBX olarak çıkarır. Bu oyun için low-poly zaten yeterli.

```
blender --background --python tools/blender/make_models.py -- --out tools/blender/out
```

Seçenekler:

| Bayrak | Ne yapar |
|---|---|
| `--out <dizin>` | çıktı dizini (varsayılan `tools/blender/out`) |
| `--only sandik` | yalnızca bir modeli üretir |
| `--combined` | hepsini ayrıca tek FBX'e yazar |

Üretilen modeller: `sandik`, `kasa_kapisi`, `lazer_yayici`, `kristal`,
`kaide`, `kapan`.

## Neden iki dosya

`geometry.py` saf Python: köşe ve yüz listelerini üretir, Blender'a
ihtiyaç duymaz. `make_models.py` yalnızca o veriyi Blender'a aktarır.

Bunun sebebi test edilebilirlik: geometri Blender olmadan doğrulanabiliyor.

```
python3 tools/blender/test_geometry.py
```

Bu test her modelin **kapalı yüzey** olduğunu (her kenar tam iki yüz
tarafından paylaşılıyor — açık kenar Roblox'ta içi görünen model demek),
üçgen sayısının low-poly hedefinde kaldığını ve ölçeğin stud cinsinden
makul olduğunu kontrol eder.

> Not: `make_models.py`'nin Blender tarafı bu depoda çalıştırılarak test
> **edilmedi** (ortamda Blender yok). Geometri tarafı test edildi. İlk
> çalıştırmada bir sorun çıkarsa büyük ihtimalle bpy sürüm farkındandır;
> script Blender 3.6+ ve 4.x API'sine göre yazıldı.

## Ölçek

1 Blender birimi = 1 Roblox stud. Modeller stud cinsinden tasarlandı:

| Model | Boyut (stud) | Üçgen |
|---|---|---|
| sandik | 4.2 × 3.4 × 3.1 | 72 |
| kasa_kapisi | 12.0 × 2.0 × 12.0 | 448 |
| lazer_yayici | 1.4 × 1.4 × 1.8 | 84 |
| kristal | 1.7 × 1.5 × 2.4 | 12 |
| kaide | 2.2 × 2.2 × 2.3 | 176 |
| kapan | 3.8 × 3.8 × 0.2 | 140 |

Zemine oturan modellerin en alt noktası z = 0'dadır; Studio'da y=0'a
koyduğunda doğru oturur.

## Studio'ya import

**Avatar sekmesi → 3D Importer → dosyayı seç.**

Önerilen ayarlar:

- **Rig / Animation**: kapalı (bunlar statik mesh)
- **Import as Model**: açık (çok parçalı modeller MeshPart grubuna dönsün)
- **World Space / Anchor**: import sonrası parçaları Anchored yap
- **Use Imported Materials**: açık; renkler FBX'ten gelir. Neon parlaklığı
  istiyorsan ilgili MeshPart'ın Material'ını Studio'da `Neon` yap
- **Collision Fidelity**: dekoratif parçalarda `Box`, üstünde
  yürünecek parçalarda `Default`

Import sonrası mesh'in `Size` değerini kontrol et; sapma varsa
`Scale` ile düzelt (1 birim = 1 stud hedefiyle üretildiler).

## Renkleri değiştirmek

`make_models.py` içindeki `MATERIALS` tablosu oyunun paletiyle aynı.
Renk değiştirirsen `src/shared/Config` içindeki renklerle tutarlı tut.
