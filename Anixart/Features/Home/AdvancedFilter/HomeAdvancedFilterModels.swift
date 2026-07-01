import Foundation

struct HomeFilterOption<Value: Hashable>: Identifiable, Hashable {
    let id: Value
    let title: String
}

enum HomeAdvancedFilterCatalog {
    static let countries = ["Япония", "Китай"]

    static let categories: [HomeFilterOption<Int64>] = [
        HomeFilterOption(id: 1, title: "Сериал"),
        HomeFilterOption(id: 2, title: "Полнометражный фильм"),
        HomeFilterOption(id: 3, title: "OVA"),
        HomeFilterOption(id: 4, title: "Дорама")
    ]

    static let profileListExclusions: [HomeFilterOption<Int>] = [
        HomeFilterOption(id: 0, title: "Избранное"),
        HomeFilterOption(id: 1, title: "Смотрю"),
        HomeFilterOption(id: 2, title: "В планах"),
        HomeFilterOption(id: 3, title: "Просмотрено"),
        HomeFilterOption(id: 4, title: "Отложено"),
        HomeFilterOption(id: 5, title: "Брошено")
    ]

    static let seasons: [HomeFilterOption<Int>] = [
        HomeFilterOption(id: 1, title: "Зима"),
        HomeFilterOption(id: 2, title: "Весна"),
        HomeFilterOption(id: 3, title: "Лето"),
        HomeFilterOption(id: 4, title: "Осень")
    ]

    static let episodePresets: [HomeFilterOption<Int>] = [
        HomeFilterOption(id: 1, title: "От 1 до 12"),
        HomeFilterOption(id: 2, title: "От 13 до 25"),
        HomeFilterOption(id: 3, title: "От 26 до 100"),
        HomeFilterOption(id: 4, title: "Больше 100")
    ]

    static let statuses: [HomeFilterOption<Int64>] = [
        HomeFilterOption(id: 1, title: "Вышел"),
        HomeFilterOption(id: 2, title: "Выходит"),
        HomeFilterOption(id: 3, title: "Анонс")
    ]

    static let episodeDurationPresets: [HomeFilterOption<Int>] = [
        HomeFilterOption(id: 1, title: "До 10 минут"),
        HomeFilterOption(id: 2, title: "До 30 минут"),
        HomeFilterOption(id: 3, title: "Более 30 минут")
    ]

    static let ageRatings: [HomeFilterOption<Int>] = [
        HomeFilterOption(id: 1, title: "0+"),
        HomeFilterOption(id: 2, title: "6+"),
        HomeFilterOption(id: 3, title: "12+"),
        HomeFilterOption(id: 4, title: "16+"),
        HomeFilterOption(id: 5, title: "18+")
    ]

    static let sortOptions: [HomeFilterOption<Int>] = [
        HomeFilterOption(id: 0, title: "По дате добавления"),
        HomeFilterOption(id: 1, title: "По рейтингу"),
        HomeFilterOption(id: 2, title: "По годам"),
        HomeFilterOption(id: 3, title: "По популярности")
    ]

    static let genres = [
        "авангард", "гурман", "драма", "комедия", "повседневность", "приключения", "романтика", "сверхъестественное", "спорт", "тайна", "триллер", "ужасы", "фантастика", "фэнтези", "экшен", "эротика", "этти", "детское", "дзёсей", "сэйнэн", "сёдзё", "сёдзё-ай", "сёнен", "сёнен-ай", "CGDCT", "антропоморфизм", "боевые искусства", "вампиры", "взрослые персонажи", "видеоигры", "военное", "выживание", "гарем", "гонки", "городское фэнтези", "гэг-юмор", "детектив", "жестокость", "забота о детях", "злодейка", "игра с высокими ставками", "идолы (жен.)", "идолы (муж.)", "изобразительное искусство", "исполнительское искусство", "исторический", "исэкай", "иясикэй", "командный спорт", "космос", "кроссдрессинг", "культура отаку", "любовный многоугольник", "магическая смена пола", "махо-сёдзё", "медицина", "меха", "мифология", "музыка", "образовательное", "организованная преступность", "пародия", "питомцы", "психологическое", "путешествие во времени", "работа", "реверс-гарем", "реинкарнация", "романтический подтекст", "самураи", "спортивные единоборства", "стратегические игры", "супер сила", "удостоено наград", "хулиганы", "школа", "шоу-бизнес"
    ]

    static let sources = [
        "Оригинал", "Манга", "Веб-манга", "Енкома", "Ранобэ", "Новелла", "Веб-новелла", "Игра", "Визуальная новелла", "Карточная игра", "Книга", "Книга с картинками", "Музыка", "Радио", "Более одного", "Другое"
    ]

    static let studios = [
        "A-1 Pictures", "A.C.G.T", "ACTAS, Inc", "ACiD FiLM", "AIC A.S.T.A", "AIC PLUS", "AIC Spirits", "AIC", "Animac", "ANIMATE", "Aniplex", "ARMS", "Artland", "ARTMIC Studios", "Asahi Production", "Asia-Do", "ASHI", "Asread", "Asmik Ace", "Aubeck", "BM Entertainment", "Bandai Visua", "Barnum Studio", "Bee Train", "BeSTACK", "Blender Foundation", "Bones", "Brains Base", "Bridge", "Cinema Citrus", "Chaos Project", "Cherry Lips", "David Production", "Daume", "Doumu", "Dax International", "DLE INC", "Digital Frontier", "Digital Works", "Diomedea", "DIRECTIONS Inc", "Dogakobo", "Dofus", "Encourage Films", "Feel", "Fifth Avenue", "Five Ways", "Fuji TV", "Foursome", "GRAM Studio", "G&G Entertainment", "Gainax", "GANSIS", "Gathering", "Gonzino", "Gonzo", "GoHands", "Green Bunny", "Group TAC", "Hal Film Maker", "Hasbro Studios", "h.m.p", "Himajin", "Hoods Entertainment", "Idea Factory", "J.C.Staff", "KANSAI", "Kaname Production", "Kitty Films", "Knack", "Kokusai Eigasha", "KSS (студия)", "Kyoto Animation", "Lemon Heart", "LMD", "Madhouse Studios", "Magic Bus", "Manglobe Inc.", "Manpuku Jinja", "MAPPA", "Milky", "Minamimachi Bugyosho", "Media Blasters", "Mook Animation", "Moonrock", "MOVIC", "Mushi Productions", "Natural High", "Nippon Animation", "Nomad", "Lerche", "OB Planning", "Office AO", "Ordet", "Oriental Light and Magic", "OLM Inc.", "P.A. Works", "Palm Studio", "Pastel", "Phoenix Entertainment", "Picture Magic", "Pink", "Pink Pineapple", "Planet", "Plum", "PPM", "Primastea", "Production I.G", "Project No.9", "Radix", "Rikuentai", "Robot", "Satelight", "Seven", "Seven Arcs", "Shaft", "Silver Link", "Shinei Animation", "Shogakukan Music & Digital Entertainment", "Soft on Demand", "Starchild Records", "Studio 9 Maiami", "Studio Tulip", "Studio 4°C", "Studio e.go!", "Studio A.P.P.P", "Studio Barcelona", "Studio Blanc", "Studio Comet", "Studio Deen", "Studio Fantasia", "Studio Flag", "Studio Gallop", "Studio Ghibli", "Studio Guts", "Studio Gokumi", "Studio Rikka", "Studio Hibari", "Studio Junio", "Studio Khara", "Studio Live", "Studio Matrix", "Studio Pierrot", "Studio Egg", "Sunrise", "Synergy SP", "Synergy Japan", "Tatsunoko Production", "Tele-Cartoon Japan", "Telecom Animation Film", "Tezuka Productions", "The Answer Studio", "TMS", "TNK", "Toei Animation", "Tokyo Kids", "TYO Animations", "Transarts", "Triangle Staff", "Trinet Entertainment", "Ufotable", "Vega Entertainment", "Victor Entertainment", "Viewworks", "White Fox", "Wonder Farm", "XEBEC-M2", "Xebec", "Yumeta Company", "Zexcs", "Zuiyo Eizo", "8bit"
    ]

    static func title<Value>(for id: Value?, in options: [HomeFilterOption<Value>]) -> String? where Value: Hashable {
        guard let id else { return nil }
        return options.first { $0.id == id }?.title
    }
}

struct HomeCustomFilterSettings: Codable, Equatable {
    var tabTitle: String = "Моя вкладка"
    var country: String?
    var categoryId: Int64?
    var genres: [String] = []
    var isGenresExcludeModeEnabled: Bool = false
    var profileListExclusions: [Int] = []
    var typeIds: [Int64] = []
    var studio: String?
    var source: String?
    var startYear: Int?
    var endYear: Int?
    var season: Int?
    var episodesPreset: Int?
    var statusId: Int64?
    var episodeDurationPreset: Int?
    var ageRatings: [Int] = []
    var sort: Int = 0

    static let empty = HomeCustomFilterSettings()
    static let storageKey = "homeCustomFilterSettings"

    enum CodingKeys: String, CodingKey {
        case tabTitle
        case country
        case categoryId
        case genres
        case isGenresExcludeModeEnabled
        case profileListExclusions
        case typeIds
        case studio
        case source
        case startYear
        case endYear
        case season
        case episodesPreset
        case statusId
        case episodeDurationPreset
        case ageRatings
        case sort

        case oldCountry = "country_id"
        case oldCategory = "category"
        case oldExcludedProfileLists = "excludedProfileLists"
        case oldVoiceovers = "voiceovers"
        case oldStudio = "studio_id"
        case oldSource = "source_id"
        case oldStartYear = "year_start"
        case oldEndYear = "year_end"
        case oldMinEpisodes = "minEpisodes"
        case oldMaxEpisodes = "maxEpisodes"
        case oldStatus = "status"
        case oldMinDuration = "minDuration"
        case oldMaxDuration = "maxDuration"
    }

    init() {}

    init(
        tabTitle: String = "Моя вкладка",
        country: String? = nil,
        categoryId: Int64? = nil,
        genres: [String] = [],
        isGenresExcludeModeEnabled: Bool = false,
        profileListExclusions: [Int] = [],
        typeIds: [Int64] = [],
        studio: String? = nil,
        source: String? = nil,
        startYear: Int? = nil,
        endYear: Int? = nil,
        season: Int? = nil,
        episodesPreset: Int? = nil,
        statusId: Int64? = nil,
        episodeDurationPreset: Int? = nil,
        ageRatings: [Int] = [],
        sort: Int = 0
    ) {
        self.tabTitle = tabTitle
        self.country = Self.normalizedOptional(country)
        self.categoryId = categoryId
        self.genres = genres
        self.isGenresExcludeModeEnabled = isGenresExcludeModeEnabled
        self.profileListExclusions = profileListExclusions
        self.typeIds = typeIds
        self.studio = Self.normalizedOptional(studio)
        self.source = Self.normalizedOptional(source)
        self.startYear = startYear
        self.endYear = endYear
        self.season = season
        self.episodesPreset = episodesPreset
        self.statusId = statusId
        self.episodeDurationPreset = episodeDurationPreset
        self.ageRatings = ageRatings
        self.sort = sort
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tabTitle = container.decodeLossyString(forKey: .tabTitle) ?? "Моя вкладка"
        country = Self.normalizedOptional(container.decodeLossyString(forKey: .country))
            ?? Self.countryTitle(forLegacyId: container.decodeLossyInt64(forKey: .oldCountry))
        categoryId = container.decodeLossyInt64(forKey: .categoryId) ?? container.decodeLossyInt64(forKey: .oldCategory)
        genres = container.decodeLossyArray([String].self, forKey: .genres) ?? []
        isGenresExcludeModeEnabled = container.decodeLossyBool(forKey: .isGenresExcludeModeEnabled) ?? false
        profileListExclusions = container.decodeLossyArray([Int].self, forKey: .profileListExclusions)
            ?? container.decodeLossyArray([Int].self, forKey: .oldExcludedProfileLists)
            ?? []
        typeIds = container.decodeLossyArray([Int64].self, forKey: .typeIds)
            ?? container.decodeLossyArray([Int64].self, forKey: .oldVoiceovers)
            ?? []
        studio = Self.normalizedOptional(container.decodeLossyString(forKey: .studio))
            ?? Self.catalogValue(atLegacyIndex: container.decodeLossyInt64(forKey: .oldStudio), values: HomeAdvancedFilterCatalog.studios)
        source = Self.normalizedOptional(container.decodeLossyString(forKey: .source))
            ?? Self.catalogValue(atLegacyIndex: container.decodeLossyInt64(forKey: .oldSource), values: HomeAdvancedFilterCatalog.sources)
        startYear = container.decodeLossyInt(forKey: .startYear) ?? container.decodeLossyInt(forKey: .oldStartYear)
        endYear = container.decodeLossyInt(forKey: .endYear) ?? container.decodeLossyInt(forKey: .oldEndYear)
        season = container.decodeLossyInt(forKey: .season)
        episodesPreset = container.decodeLossyInt(forKey: .episodesPreset)
            ?? Self.episodePreset(from: container.decodeLossyInt(forKey: .oldMinEpisodes), to: container.decodeLossyInt(forKey: .oldMaxEpisodes))
        statusId = container.decodeLossyInt64(forKey: .statusId) ?? container.decodeLossyInt64(forKey: .oldStatus)
        episodeDurationPreset = container.decodeLossyInt(forKey: .episodeDurationPreset)
            ?? Self.durationPreset(from: container.decodeLossyInt(forKey: .oldMinDuration), to: container.decodeLossyInt(forKey: .oldMaxDuration))
        ageRatings = container.decodeLossyArray([Int].self, forKey: .ageRatings) ?? []
        sort = container.decodeLossyInt(forKey: .sort) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tabTitle, forKey: .tabTitle)
        try container.encodeIfPresent(country, forKey: .country)
        try container.encodeIfPresent(categoryId, forKey: .categoryId)
        try container.encode(genres, forKey: .genres)
        try container.encode(isGenresExcludeModeEnabled, forKey: .isGenresExcludeModeEnabled)
        try container.encode(profileListExclusions, forKey: .profileListExclusions)
        try container.encode(typeIds, forKey: .typeIds)
        try container.encodeIfPresent(studio, forKey: .studio)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(startYear, forKey: .startYear)
        try container.encodeIfPresent(endYear, forKey: .endYear)
        try container.encodeIfPresent(season, forKey: .season)
        try container.encodeIfPresent(episodesPreset, forKey: .episodesPreset)
        try container.encodeIfPresent(statusId, forKey: .statusId)
        try container.encodeIfPresent(episodeDurationPreset, forKey: .episodeDurationPreset)
        try container.encode(ageRatings, forKey: .ageRatings)
        try container.encode(sort, forKey: .sort)
    }

    var hasActiveFilters: Bool {
        country != nil
            || categoryId != nil
            || !genres.isEmpty
            || isGenresExcludeModeEnabled
            || !profileListExclusions.isEmpty
            || !typeIds.isEmpty
            || studio != nil
            || source != nil
            || startYear != nil
            || endYear != nil
            || season != nil
            || episodesPreset != nil
            || statusId != nil
            || episodeDurationPreset != nil
            || !ageRatings.isEmpty
            || sort != 0
    }

    var isEmpty: Bool { !hasActiveFilters }

    var displayTitle: String {
        let trimmed = tabTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Моя вкладка" : trimmed
    }

    var summaryItems: [String] {
        var items: [String] = []
        if let country { items.append(country) }
        if let category = HomeAdvancedFilterCatalog.title(for: categoryId, in: HomeAdvancedFilterCatalog.categories) { items.append(category) }
        if !genres.isEmpty { items.append("\(genres.count) жанр.") }
        if isGenresExcludeModeEnabled { items.append("Жанры исключаются") }
        if !profileListExclusions.isEmpty { items.append("Исключено списков: \(profileListExclusions.count)") }
        if !typeIds.isEmpty { items.append("Озвучек: \(typeIds.count)") }
        if let studio { items.append(studio) }
        if let source { items.append(source) }
        if startYear != nil || endYear != nil { items.append(yearSummary) }
        if let seasonTitle = HomeAdvancedFilterCatalog.title(for: season, in: HomeAdvancedFilterCatalog.seasons) { items.append(seasonTitle) }
        if let episodeTitle = HomeAdvancedFilterCatalog.title(for: episodesPreset, in: HomeAdvancedFilterCatalog.episodePresets) { items.append(episodeTitle) }
        if let statusTitle = HomeAdvancedFilterCatalog.title(for: statusId, in: HomeAdvancedFilterCatalog.statuses) { items.append(statusTitle) }
        if let durationTitle = HomeAdvancedFilterCatalog.title(for: episodeDurationPreset, in: HomeAdvancedFilterCatalog.episodeDurationPresets) { items.append(durationTitle) }
        if !ageRatings.isEmpty { items.append("Возраст: \(ageRatings.count)") }
        if sort != 0, let sortTitle = HomeAdvancedFilterCatalog.title(for: sort, in: HomeAdvancedFilterCatalog.sortOptions) { items.append(sortTitle) }
        return items
    }

    var validationMessage: String? {
        if let startYear, let endYear, startYear > endYear {
            return "Год начала не может быть больше года окончания."
        }
        return nil
    }

    func toFilterRequestBody() -> JSONValue {
        var fields: [String: JSONValue] = [:]
        if let country { fields["country"] = .string(country) }
        if let categoryId { fields["category_id"] = .number(Double(categoryId)) }
        if !genres.isEmpty { fields["genres"] = .array(genres.map { .string($0) }) }
        if !genres.isEmpty || isGenresExcludeModeEnabled {
            fields["is_genres_exclude_mode_enabled"] = .bool(isGenresExcludeModeEnabled)
        }
        if !profileListExclusions.isEmpty { fields["profile_list_exclusions"] = .array(profileListExclusions.map { .number(Double($0)) }) }
        if !typeIds.isEmpty { fields["types"] = .array(typeIds.map { .number(Double($0)) }) }
        if let studio { fields["studio"] = .string(studio) }
        if let source { fields["source"] = .string(source) }
        if let startYear { fields["start_year"] = .number(Double(startYear)) }
        if let endYear { fields["end_year"] = .number(Double(endYear)) }
        if let season { fields["season"] = .number(Double(season)) }
        applyEpisodePreset(to: &fields)
        if let statusId { fields["status_id"] = .number(Double(statusId)) }
        applyDurationPreset(to: &fields)
        if !ageRatings.isEmpty { fields["age_ratings"] = .array(ageRatings.map { .number(Double($0)) }) }
        if hasActiveFilters || sort != 0 { fields["sort"] = .number(Double(sort)) }
        return .object(fields)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    static func load() -> HomeCustomFilterSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(HomeCustomFilterSettings.self, from: data)
        else {
            return .empty
        }
        return settings
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private var yearSummary: String {
        switch (startYear, endYear) {
        case (let start?, let end?) where start == end:
            return "\(start)"
        case (let start?, let end?):
            return "\(start)-\(end)"
        case (let start?, nil):
            return "С \(start)"
        case (nil, let end?):
            return "До \(end)"
        default:
            return ""
        }
    }

    private func applyEpisodePreset(to fields: inout [String: JSONValue]) {
        switch episodesPreset {
        case 1:
            fields["episodes_from"] = .number(0.0)
            fields["episodes_to"] = .number(12.0)
        case 2:
            fields["episodes_from"] = .number(13.0)
            fields["episodes_to"] = .number(25.0)
        case 3:
            fields["episodes_from"] = .number(26.0)
            fields["episodes_to"] = .number(100.0)
        case 4:
            fields["episodes_from"] = .number(100.0)
        default:
            break
        }
    }

    private func applyDurationPreset(to fields: inout [String: JSONValue]) {
        switch episodeDurationPreset {
        case 1:
            fields["episode_duration_from"] = .number(1.0)
            fields["episode_duration_to"] = .number(10.0)
        case 2:
            fields["episode_duration_from"] = .number(11.0)
            fields["episode_duration_to"] = .number(30.0)
        case 3:
            fields["episode_duration_from"] = .number(31.0)
        default:
            break
        }
    }

    private static func normalizedOptional(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty || trimmed == "Неважно" ? nil : trimmed
    }

    private static func countryTitle(forLegacyId id: Int64?) -> String? {
        switch id {
        case 1:
            return "Япония"
        case 2:
            return "Китай"
        default:
            return nil
        }
    }

    private static func catalogValue(atLegacyIndex id: Int64?, values: [String]) -> String? {
        guard let id, id > 0 else { return nil }
        let index = Int(id - 1)
        guard values.indices.contains(index) else { return nil }
        return normalizedOptional(values[index])
    }

    private static func episodePreset(from: Int?, to: Int?) -> Int? {
        switch (from, to) {
        case (0, 12):
            return 1
        case (13, 25):
            return 2
        case (26, 100):
            return 3
        case (100, nil):
            return 4
        default:
            return nil
        }
    }

    private static func durationPreset(from: Int?, to: Int?) -> Int? {
        switch (from, to) {
        case (1, 10):
            return 1
        case (11, 30):
            return 2
        case (31, nil):
            return 3
        default:
            return nil
        }
    }
}
