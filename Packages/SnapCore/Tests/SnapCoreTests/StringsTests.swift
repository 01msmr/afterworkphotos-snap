import Testing
@testable import SnapCore

@Suite struct StringsTests {
    @Test func languageFromSystemCode() {
        #expect(Language.from(systemCode: "de-DE") == .de)
        #expect(Language.from(systemCode: "de") == .de)
        #expect(Language.from(systemCode: "en-GB") == .en)
        #expect(Language.from(systemCode: "fr") == .en)
    }
    @Test func everyKeyHasBothLanguages() {
        for key in Strings.Key.allCases {
            #expect(!Strings.t(key, .en).isEmpty)
            #expect(!Strings.t(key, .de).isEmpty)
        }
    }
    @Test func theTable() {
        #expect(Strings.t(.retake, .de) == "NOCHMAL")
        #expect(Strings.t(.postSent, .en) == "Post sent.")
        #expect(Strings.t(.sendingError, .de) == "SENDEFEHLER")
        #expect(Strings.t(.loc, .de) == "ort")
        #expect(Strings.t(.empty, .en) == "-")
    }
}
