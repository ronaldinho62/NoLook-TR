<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/wordmark-white.svg">
    <img src="docs/images/wordmark.svg" alt="NoLook" height="56">
  </picture>
</p>

<p align="center"><b>NoLook TR</b>: Bilgisayarında, telefonunda ve tarayıcında spoilerleri gizle, siteleri ve uygulamaları engelle.<br><a href="https://github.com/ronaldinho62/NoLook-TR/releases/latest">Son sürümü indir</a></p>

> Bu depo, [ItsZedK/NoLook](https://github.com/ItsZedK/NoLook) projesinin **Türkçe çatalıdır (fork)**. Uygulama, tarayıcı eklentisi, Android engelleyicisi ve Windows kurulum sihirbazı Türkçeye çevrildi; GTA 6 spoiler listesine Türkçe kelimeler eklendi. Özgün proje GPLv3 lisanslıdır, bu çatal da öyledir.

![Windows'ta çalışan NoLook](docs/images/home.png)

NoLook ile anahtar kelimelerden, sitelerden ve uygulamalardan oluşan **engeller** oluşturursun. Bir engel açıkken eşleşen gönderi ve videolar bulanıklaştırılır ya da gizlenir, engellenen siteler açılmaz, seçtiğin uygulamalar kapatılır.

Farklı şeyler için farklı engeller oluşturabilir, her birine ayrı zamanlama koyabilir ya da kapatmayı zorlaştıran bir kilit ekleyebilirsin.

## Bu Türkçe sürümde neler farklı?

- **Tamamen Türkçe arayüz.** Uygulama, tarayıcı eklentisi, Android bildirimleri ve kurulum sihirbazı Türkçe. Sistem dilin İngilizce değilse uygulama Türkçe açılır; Ayarlar > Dil bölümünden İngilizceye geçebilirsin.
- **Türkçe GTA 6 spoiler kelimeleri.** Hazır "GTA 6 spoilerleri" listesinde İngilizce kelimelerin yanında "final", "sonu", "öldü", "ihanet", "sızıntı", "hamile", "tutuklandı", "bitirdim" gibi 80'den fazla Türkçe spoiler kelimesi ve kalıbı var.
- **Türkçe ekleri yakalayan kelimeler.** Bir kelimenin sonuna `*` koyarsan ekli halleri de yakalanır: `final*` yazınca "finali", "finalde", "finaline" de gizlenir. `*` olmadan yalnızca kelimenin kendisi eşleşir.
- **Büyük/küçük İ-I düzeltmesi.** "İHANET", "ihanet" ile; "SIZINTI", "sızıntı" ile eşleşir.
- **İstisnalar.** Ayarlar > İstisnalar bölümüne kendi kanalını veya hesabını (`youtube.com/@kanalin`, `x.com/hesabin`) eklersen, o kanalın video ve gönderileri ana sayfada, aramada ve önerilerde de gizlenmez; kendi kanal sayfanda hiçbir şey gizlenmez. Eklenti menüsündeki **İstisnalara ekle** düğmesi (ve Ayarlar > **Bu kanalı istisna yap**) açık olan kanalı, videonun sahibini ya da X profilini tek tıkla ekler. Kilitli engellerin delinmemesi için bir sitenin tamamı (`x.com` gibi) istisna yapılamaz ve istisnalar site engellemeyi etkilemez. Şimdilik yalnızca tarayıcıda çalışır; Android uygulamasında ve YouTube Shorts raflarında geçerli değildir.
- **Sistem tepsisinde başlatma.** Windows ile açılınca NoLook pencere göstermeden sistem tepsisinde başlar (Ayarlar > Bu bilgisayarda > Sistem tepsisinde başlat).
- **Güncellemeler bu depodan gelir.** Uygulama yeni sürümleri bu deponun [Releases](https://github.com/ronaldinho62/NoLook-TR/releases) sayfasından denetler.
- **Eklenti mağazadan değil, klasörden kurulur.** Chrome Web Mağazası'ndaki NoLook eklentisi özgün (İngilizce) sürümdür ve Türkçe `*` kelimelerini tanımaz. Uygulama, Türkçe eklentiyi kendi klasöründen kurmanı adım adım anlatır.

## Özellikler

### Anahtar kelimeleri ve spoilerleri gizle

NoLook gönderileri, yorumları ve videoları bir engele eklediğin kelimeler için kontrol eder. Eşleşen içerik bulanıklaştırılır ya da gizlenir; yine de görmek istersen **Göster**'e tıklayabilirsin.

Her engelde üç tür kelime vardır:

- **Anahtar kelimeler** her zaman eşleşme sayılır.
- **Spoiler kelimeleri** yalnızca gönderi aynı zamanda bir anahtar kelimeden ya da ilgili bir konudan bahsediyorsa sayılır.
- **Konu kelimeleri** spoiler kelimelerine bağlam sağlar, ama tek başlarına hiçbir şeyi gizlemez.

Bu sayede "final" ya da "sızıntı" gibi kelimeleri, her yerde karşına çıkmadan engelleyebilirsin. Örneğin "öldü" kelimesi "Lucia girişte öldü" gönderisini gizler, ama GTA ile ilgisi olmayan bir haberi gizlemez.

![NoLook'un X'te gizlediği bir gönderi](docs/images/blur.png)

### Siteleri engelle

Bir sitenin tamamını ya da yalnızca belirli bölümlerini engelleyebilirsin. Örneğin Reddit'in geri kalanını engellemeden yalnızca `reddit.com/r/GTA6` adresini engelleyebilirsin.

### Uygulamaları engelle

NoLook, Windows ve Android'de seçtiğin uygulamaları kapatabilir. Android'de uygulamaların içindeki eşleşen gönderileri de örtebilir.

### Kilitler ve zamanlamalar

Her engelin kendi ayarları vardır. Kilitsiz bırakabilir, belirli bir tarihe kadar açık tutabilir ya da erken kapatmak için bekleme süresi veya bir cümle yazma şartı koyabilirsin.

Belirli gün ve saatler için zamanlama ayarlayabilir, sınırlı sayıda acil kilit açma hakkı tanıyıp tanımamayı seçebilirsin.

![NoLook'ta engel oluşturma](docs/images/new-block.png)

### Geçmiş ve cihaz eşitleme

NoLook neleri gizlediğini, hangi siteleri veya uygulamaları engellediğini ve bir engelin kilidini ne zaman açtığını kaydeder.

Engellerini eşit tutmak için cihazlarını aynı Wi-Fi ağında bir QR koduyla eşleştirebilirsin. Engelleri `.nolook` dosyası olarak dışa ve içe aktarmak da mümkün.

### Hazır listeler

Hazır "GTA 6 spoilerleri" listesiyle başlayabilir ya da kendi engelini sıfırdan oluşturabilirsin.

NoLook TR, Türkçe ve İngilizce kullanılabilir.

## Tarayıcı eklentisi

Tarayıcı eklentisi tek başına da çalışır. NoLook uygulamasını kurmadan da açılır penceresinden engel oluşturabilir, anahtar kelime ve site ekleyebilir, her şeyi yönetebilirsin.

Uygulamayı kurduğunda eklenti, uygulamada oluşturduğun engelleri kullanır. Böylece kilitler ve zamanlamalar gibi özelliklere erişirsin ve NoLook neyin engellendiğinin geçmişini tutabilir.

Eklenti Chrome, Edge ve Firefox için hazırlandı; Brave, Opera, Opera GX ve Vivaldi için kurulum adımları da uygulamada var. Türkçe eklenti, uygulamanın kurulduğu klasördeki `extension` klasöründen yüklenir; uygulama içindeki **Ayarlar > Tarayıcı eklentileri** bölümü bunu adım adım gösterir.

## Platformlar

| Platform | Özellikler |
|---|---|
| Windows | Tam uygulama, uygulama engelleme ve tarayıcı eklentisi |
| Android | Uygulama engelleme, site engelleme ve içerik örtme |
| macOS | Uygulama ve tarayıcı eklentisi |
| Linux | Uygulama ve tarayıcı eklentisi |

Uygulama engelleme şu an yalnızca Windows ve Android'de var. Bu Türkçe çatalın hazır kurulum dosyası şimdilik yalnızca **Windows** için yayımlanıyor; diğer platformlar için aşağıdaki "Kaynaktan derleme" bölümüne bak.

![Android'de NoLook](docs/images/phone.png)

### Android izinleri

NoLook, tarayıcı adreslerini kontrol etmek, engellenen uygulamaları algılamak ve ekrandaki eşleşen içeriği örtmek için Android'in Erişilebilirlik hizmetini kullanır. Engelleme özelliklerinin çalışması için bu gereklidir.

NoLook'u APK'dan kurarken Android kısıtlanmış ayarlara izin vermeni isteyebilir. İsterse NoLook'un Uygulama bilgisi sayfasını aç, sağ üstteki üç noktaya dokun ve **Kısıtlanmış ayarlara izin ver**'i seç.

## İndirme

Son sürümü [GitHub Releases](https://github.com/ronaldinho62/NoLook-TR/releases/latest) sayfasından indir.

| Dosya | Açıklama |
|---|---|
| `NoLook-setup.exe` | Windows kurulum sihirbazı (önerilen) |
| `NoLook-windows.zip` | Kurulumsuz Windows sürümü |

**Windows:** Kurulum sihirbazını çalıştır. NoLook ilk kurulumda sana yol gösterir. Kurulum dosyası dijital olarak imzalı olmadığı için Windows SmartScreen "Windows bilgisayarınızı korudu" uyarısı gösterebilir; **Ek bilgi > Yine de çalıştır** ile devam edebilirsin.

Özgün NoLook ile bu Türkçe sürümü aynı bilgisayarda birlikte kurma. İkisi aynı ayar klasörünü ve aynı tarayıcı bağlantısını kullanır.

## Gizlilik

NoLook hesap gerektirmez ve engellerini saklamak için bir sunucu kullanmaz.

Engellerin, ayarların ve geçmişin cihazında tutulur. Cihazları eşleştirdiğinde engeller doğrudan yerel Wi-Fi ağın üzerinden paylaşılır.

Uygulama güncellemeler için GitHub'ı denetler. Gezinme etkinliğin ve engellenen içerik hiçbir sunucuya gönderilmez.

## Kaynaktan derleme

NoLook, uygulama ve ortak mantık için Flutter ve Dart, tarayıcı eklentisi için TypeScript kullanır.

### Gereksinimler

- Flutter 3.47.9
- Node.js 22 veya daha yenisi
- Android derlemeleri için Android SDK ve Java
- Flutter'ın istediği platforma özel derleme araçları
- Windows kurulum sihirbazı için Inno Setup 6

### Derleme

Tarayıcı eklentisini derle:

```bash
cd extension
npm ci
npm run build
```

Sürüm paketleme betikleri `tools/` klasöründe. `v` ile başlayan bir etiket (ör. `v0.1.1`) gönderildiğinde `.github/workflows/desktop.yml` Windows, macOS ve Linux derlemelerini yapar ve Windows dosyalarını otomatik olarak bir GitHub sürümüne ekler.

### Proje yapısı

| Klasör | İçerik |
|---|---|
| `app/` | Flutter uygulaması ve Android engelleyicisi |
| `core/` | Ortak engelleme kuralları, eşleştirme, kilitler, zamanlamalar ve eşitleme |
| `extension/` | Chrome, Edge ve Firefox tarayıcı eklentisi |
| `host/` | Uygulamayı eklentiye bağlayan yerel mesajlaşma yardımcısı |
| `tools/` | Derleme ve sürüm betikleri |

## Lisans

NoLook, [GNU Genel Kamu Lisansı v3.0](LICENSE) altında özgür ve açık kaynaklıdır. Bu Türkçe çatal da aynı lisansla dağıtılır; özgün yazar [ItsZedK](https://github.com/ItsZedK)'dir.

Outfit ve Syne yazı tipleri SIL Open Font License, Material Symbols simgeleri Apache License 2.0 ile lisanslıdır.

## Destek

Bir hata mı buldun ya da önerin mi var? Bu Türkçe sürümle ilgili sorunlar için [buradan bir issue aç](https://github.com/ronaldinho62/NoLook-TR/issues).
