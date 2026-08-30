import Testing
import Foundation
@testable import SnapCore

@Suite struct NameSuggestionsTests {
    let thumb = Data([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3])

    @Test func requestShape() throws {
        let r = NameSuggestions.request(thumbnail: thumb, language: .de, key: "k")
        #expect(r.httpMethod == "POST")
        #expect(r.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(r.value(forHTTPHeaderField: "x-api-key") == "k")
        #expect(r.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(r.timeoutInterval == 30)
        let json = try JSONSerialization.jsonObject(with: r.httpBody!) as! [String: Any]
        #expect(json["model"] as? String == "claude-haiku-4-5")
        let system = json["system"] as! String
        #expect(system.contains("six"))
        #expect(system.contains("German"))
        let msgs = json["messages"] as! [[String: Any]]
        let content = msgs[0]["content"] as! [[String: Any]]
        let img = content[0]["source"] as! [String: Any]
        #expect(img["data"] as? String == thumb.base64EncodedString())
    }

    private func reply(_ text: String) -> Data {
        let obj: [String: Any] = ["content": [["type": "text", "text": text]]]
        return try! JSONSerialization.data(withJSONObject: obj)
    }

    @Test func parsesACleanArray() {
        let names = NameSuggestions.parse(reply(#"["White keyboard","desk","keys on desk","White keyboard","Sun over tree ","x","y"]"#))
        #expect(names == ["white keyboard", "desk", "keys on desk", "sun over tree", "x", "y"])
    }
    @Test func parsesProseAroundTheArray() {
        let names = NameSuggestions.parse(reply(#"Here you go: ["forest", "trees"] — hope that helps"#))
        #expect(names == ["forest", "trees"])
    }
    @Test func fewerThanSixIsFine() {
        #expect(NameSuggestions.parse(reply(#"["rails"]"#)) == ["rails"])
    }
    @Test func garbageIsEmpty() {
        #expect(NameSuggestions.parse(Data("nope".utf8)) == [])
        #expect(NameSuggestions.parse(reply("no array here")) == [])
    }
    @Test func bracketInsideAStringIsNotTakenAsTheClose() {
        let names = NameSuggestions.parse(reply(#"["a ] bracket","b"]"#))
        #expect(names == ["a ] bracket", "b"])
    }
    @Test func skipsAnEarlierBracketThatIsNotTheArray() {
        let names = NameSuggestions.parse(reply(#"see [1]: ["forest","trees"]"#))
        #expect(names == ["forest", "trees"])
    }
}
