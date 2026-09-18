# Studio Test Listesi

Oyun açılırken Studio'da otomatik bir açılış kontrolü çalışıyor (Output
penceresine bakın): denge dosyalarının tutarlılığı, ağın kurulması, DataStore
erişimi ve satın alma ID'leri makine tarafından kontrol ediliyor.

Bu doküman, **makinenin kontrol edemediği** kısım için. Sırayla git,
her maddeyi bizzat oyna.

## Hazırlık

- [ ] `rojo serve` çalışıyor ve Studio bağlı
- [ ] **Game Settings → Security → Enable Studio Access to API Services** açık
      (kapalıysa açılış kontrolü uyarı basar; oyun çalışır ama kayıt gitmez)
- [ ] Output penceresi açık — açılış kontrolünün çıktısı oraya düşüyor

## Tek oyunculu tur (5 dakika)

1. **İlk 60 saniye**
   - [ ] Oyuna girer girmez kendi kasanın önünde doğuyorsun
   - [ ] Sol üstte para, sağ üstte kasa birikimi görünüyor
   - [ ] Eğitim ipucu 1. adımı gösteriyor ("Sandığını aç")
   - [ ] Alt bardan **Sandıklar** → 3 ücretsiz Ahşap Sandık envanterde
   - [ ] **AÇ** → hazine kartı beliriyor, "Kasana yerleştirildi" yazıyor
   - [ ] Kasa birikimi saymaya başlıyor, kasandaki kaidede hazine görünüyor

2. **Temel döngü**
   - [ ] **TOPLA** → birikim cebe geçiyor, eğitim 2. adıma atlıyor
   - [ ] Sandık al → aç → yuvalar dolunca "Envanterine eklendi" yazıyor
   - [ ] **Kasam** panelinde hazineler görünüyor, yerleştir/çıkar/sat çalışıyor
   - [ ] **Savunma** panelinden Lazer Izgarası alınıyor, eğitim 3. adıma geçiyor

3. **Soygun (NPC kasası)**
   - [ ] **Soygun** panelinde 🤖 NPC kasaları listeleniyor (sunucu boşsa)
   - [ ] **SOY** → koridora ışınlanıyorsun, üstte hedef ve süre görünüyor
   - [ ] Lazere girince alarm çubuğu doluyor, çıkınca düşüyor
   - [ ] Ctrl (sinsi) ve Shift (koşu) hız ve gürültüyü değiştiriyor
   - [ ] Kapana basınca yerinde sabitleniyorsun
   - [ ] Kapıya varınca kilit mini oyunu açılıyor, **E** ile deniyorsun
   - [ ] Başarılı olunca sonuç kartı çıkıyor, para hesabına geçiyor
   - [ ] Bilerek alarmı doldur → yakalanıyorsun, hapis süresi işliyor

4. **İlerleme**
   - [ ] **Savunma & Yükseltme** panelinde yükseltmeler alınabiliyor
   - [ ] Servet rebirth eşiğine ulaşınca Rebirth düğmesi aktifleşiyor
   - [ ] Rebirth sonrası: para/hazine sıfır, savunmalar duruyor, çarpan arttı
   - [ ] **Mağaza** açılıyor; ID girilmemiş ürünler "Yakında" gösteriyor
   - [ ] Kod alanına `KASA` yaz → ödül geliyor, ikinci kez çalışmıyor

5. **Eventler**
   - [ ] Üstteki event bandı sıradaki eventi ve süreyi gösteriyor
   - [ ] Event başlayınca duyuru bandı iniyor ve etki uygulanıyor
     (Altın Saat'te gelir iki katına çıkmalı)

## İki oyunculu tur (en kritik kısım)

Studio'da **Test → Clients and Servers → 2 Players → Start**.

- [ ] İki oyuncu da kendi parseline yerleşiyor
- [ ] Oyuncu A'nın kasasında birikim varken B, A'yı listede görüyor
- [ ] B soyguna girince A'ya "B kasana giriyor!" bildirimi düşüyor
- [ ] B başarılı olunca A'nın birikimi azalıyor ve A kırmızı bant görüyor
- [ ] A'nın kalkanı devreye giriyor (60 sn boyunca tekrar soyulamıyor)
- [ ] B aynı kasaya hemen tekrar giremiyor ("çok yakın zamanda girdin")
- [ ] B yakalanınca A'ya tazminat yazılıyor
- [ ] A çıkıp tekrar girince serveti ve hazineleri duruyor (kayıt çalışıyor)

## Çıkmadan önce

- [ ] Output'ta kırmızı hata yok
- [ ] Oyuncu çıkınca "kaydedilemedi" uyarısı yok
- [ ] Aynı hesapla iki sunucuya aynı anda girmeyi dene → ikincisi nazikçe
      atılmalı ("Kasan başka bir sunucuda açık görünüyor")

## Not düşülecekler

Her tur sonunda şunları not al; bunlar denge ayarının girdisi:

- İlk ödülü almak kaç saniye sürdü?
- Neyi aramak zorunda kaldın, hangi düğmeyi bulamadın?
- Soygun koridoru çok kolay mı çok zor mu geldi?
- Soyulmak sinir bozucu muydu, yoksa "tamam, savunma alayım" mı dedirtti?
