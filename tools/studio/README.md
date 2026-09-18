# Studio Araçları

Bu klasördeki dosyalar oyunun parçası **değil**. Studio'da Command Bar'a
yapıştırılıp bir kez çalıştırılan yardımcılar.

| Dosya | Ne yapar |
|---|---|
| `asset_audit.luau` | Marketplace modelini script/backdoor için tarar ve temizler |
| `build_map.luau` | Asset ID listesinden haritayı kurar, hizalar, ışık ve atmosferi ayarlar |

## Marketplace modeli eklerken sıra

1. Modeli Studio'ya import et (henüz Workspace'e koyma, ServerStorage'da dursun)
2. Explorer'da modeli seç
3. `asset_audit.luau` içeriğini Command Bar'a yapıştır, Enter
4. Output'u oku. Script varsa silinecek — bu normaldir, dekoratif modelin
   script'e ihtiyacı yoktur
5. Temizse Workspace'e taşı

**Neden bu kadar dikkat:** Marketplace modellerine gizlenen backdoor'lar,
sunucunda uzaktan kod çalıştırıp oyuncu verisini veya Robux gelirini ele
geçirebilir. Tarayıcı bilinen desenleri yakalar ama garanti vermez;
**script'leri silmek** tek gerçekten güvenli yol.

## Haritayı kurarken

1. Creator Store'dan beğendiğin modellerin asset ID'lerini topla
2. `build_map.luau` içindeki `ASSETS` tablosunu doldur
3. Command Bar'a yapıştır, Enter
4. Model yerleşince `asset_audit.luau` ile tekrar tara (script'ler
   yerleştirme sırasında da temizleniyor ama iki kontrol iyidir)
5. Beğenmediğin yerleşimi elle düzelt, sonra yerini kaydet (Save to Roblox)
