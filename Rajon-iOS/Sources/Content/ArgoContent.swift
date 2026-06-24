import Foundation

/// Oyunun bütün argo/sokak dili içeriği burada toplanır.
/// Küfür dozu yüksek tutulur; ırkçılık/nefret vb. red sebebi içerik YOK.
enum Argo {

    // Adam lakapları (rasgele üretim için)
    static let lakaplar: [String] = [
        "Topal Cemal", "Şişko Memo", "Jilet Selim", "Deli Bekir", "Kör Sülo",
        "Bıçkın Davut", "Çakal Necmi", "Sıska Rıfat", "Boğa Hayri", "Tetik Adem",
        "Maganda Kadir", "Sinsi Vedat", "Gergedan Tunç", "Çıyan Orhan", "Kanlı Zeki",
        "Pala Hüsmen", "Dazlak Ferit", "Yılan Yusuf", "Kasap İlyas", "Gece Servet",
        "Dişçi Niyazi", "Çakmak Burhan", "Asfalt Coşkun", "Demir Lütfi", "Cingöz Remzi",
        "Hortum Sabri", "Kurşun Mahmut", "Sırık Veli", "Manyak Turgut", "Hain Şükrü",
        "Tek Kol Halis", "Sazan Avcısı Kemal", "Beton Recep", "Tilki Galip", "Kobra Sami"
    ]

    // Dövüşte adamın basacağı laflar (taunt) — sıradan adamlar
    static let tauntSokak: [String] = [
        "Lan it, sıranı bil!",
        "Bu mahalle benim ulan!",
        "Gel gel, korkma, ısırmam... yalan ısırırım.",
        "Anan baban ağlasın şimdi.",
        "Sıçtın oğlum sıçtın.",
        "Hadi gaza gel bakem.",
        "Bu kadar mıydı kabadayılığın?",
        "Yürü git, harcamayayım seni."
    ]

    static let tauntSert: [String] = [
        "Ananı ağlatmaya geldim, ağlatacağım.",
        "Senin gibi otuz tane gömdüm bu sokağa.",
        "Diz çök de belki yarım kalırsın.",
        "Bugün son günün şerefsiz.",
        "Mezar taşına ismini ben kazırım.",
        "Konuşma lan, sus da öl.",
        "Bu işin sonu ya hapis ya tabut — sana tabut.",
        "Param da var adamım da, sende ne var?"
    ]

    static let tauntEfsane: [String] = [
        "Ben bu şehrin kabusuyum oğlum.",
        "Adımı duyunca polis bile yön değiştirir.",
        "Sen daha doğmadan ben patrondum.",
        "Diz çök, belki ölümün rahat olur.",
        "Bu şehir benim, sen kiracısın.",
        "Bana kurşun işlemez, ben kurşunum."
    ]

    // Oyuncu kazandığında ekibin atacağı laflar
    static let zaferLaf: [String] = [
        "Yat aşağı! Bu sokak artık bizim.",
        "Haraç bizden sorulur ulan!",
        "Gördün mü kabadayılığı? Topla şunları.",
        "Bi' dahaki sefere selam ver geç.",
        "Cebini boşalt, ders parası."
    ]

    // Oyuncu kaybettiğinde
    static let yenilgiLaf: [String] = [
        "Dağıldık abi, dağıldık... toparlanıp geri geliyoruz.",
        "Bu sefer yedik, ama defter kapanmadı.",
        "Adamlar sağlammış. Daha sert ekip lazım.",
        "Kaç lan kaç, sonra hesaplaşırız."
    ]

    // İşletme / haraç isimleri
    static let racketIsimleri: [(String, Int, Int)] = [
        // (ad, dk başına temel üretim, temel yükseltme maliyeti)
        ("Köşedeki Kıraathane", 40, 250),
        ("Tefeci Masası", 90, 600),
        ("Oto Sanayi 'Parçacı'", 160, 1_400),
        ("Gece Kulübü Inferno", 320, 3_200),
        ("Liman Ambarı", 600, 7_500),
        ("Kumarhane Baht", 1_100, 16_000)
    ]

    // Rakip çete isimleri ve fısıltıları
    static let ceteler: [(String, String)] = [
        ("Sıçan Sokağı Çetesi", "Üç beş kapkaççı. Isınma turu."),
        ("Hortumcular", "Mazot ve mazot... ve biraz da kan."),
        ("Beyoğlu Tahsildarları", "Esnafın belası, senin de olacaklar."),
        ("Liman Kabadayıları", "Konteynerlerin altından ceset çıkar."),
        ("Kanlı Bıçaklılar", "İsimleri kadar pis bir ekip."),
        ("Gece Bekçileri", "Şehir uyurken onlar çalışır."),
        ("Demir Eldivenler", "Yumrukları beton, kalpleri taş."),
        ("Son Tabut Ailesi", "Buraya kadar geldiysen vasiyetini yaz.")
    ]

    // Teçhizat / silah isimleri (ikon, isim havuzu)
    static let silahlar: [(String, String)] = [
        ("Paslı Kelebek Bıçak", "bolt.fill"),
        ("Sustalı", "bolt.fill"),
        ("Beyzbol Sopası", "figure.boxing"),
        ("Pirinç Muşta", "figure.boxing"),
        ("Av Tüfeği", "scope"),
        ("Toplu Tabanca", "scope"),
        ("Susturuculu", "scope"),
        ("Pompalı", "scope"),
        ("Kalashnikov", "scope"),
        ("Kurşun Geçirmez Yelek", "shield.lefthalf.filled"),
        ("Deri Mont", "shield.lefthalf.filled"),
        ("Altın Saat", "crown.fill"),
    ]

    static func rastlakap() -> String { lakaplar.randomElement()! }
    static func rastSilah() -> (String, String) { silahlar.randomElement()! }

    static func taunt(for r: Rarity) -> String {
        switch r {
        case .sokak, .tetikci: return tauntSokak.randomElement()!
        case .kabadayi, .patron: return tauntSert.randomElement()!
        case .efsane: return tauntEfsane.randomElement()!
        }
    }
}
