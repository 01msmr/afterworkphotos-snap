import Foundation

public enum Language: String, Sendable {
    case en, de
    /// The system language at launch: German if it starts with "de".
    public static func from(systemCode: String) -> Language {
        systemCode.lowercased().hasPrefix("de") ? .de : .en
    }
}

public enum Strings {
    public enum Key: CaseIterable, Sendable {
        case name, loc, date, retake, post, retry, postSent, sendingError, empty
    }
    public static func t(_ key: Key, _ lang: Language) -> String {
        switch (key, lang) {
        case (.name, _):          "name"
        case (.loc, .en):         "loc"
        case (.loc, .de):         "ort"
        case (.date, .en):        "date"
        case (.date, .de):        "datum"
        case (.retake, .en):      "RETAKE"
        case (.retake, .de):      "NOCHMAL"
        case (.post, .en):        "POST"
        case (.post, .de):        "POSTEN"
        case (.retry, .en):       "RETRY"
        case (.retry, .de):       "ERNEUT"
        case (.postSent, .en):    "Post sent."
        case (.postSent, .de):    "Gesendet."
        case (.sendingError, .en): "SENDING ERROR"
        case (.sendingError, .de): "SENDEFEHLER"
        case (.empty, _):         "-"
        }
    }
}
