import Testing
@testable import SnapCore

@Suite struct LocationFreshnessTests {
    @Test func freshAndAccurateIsUsable() {
        #expect(LocationFreshness.isUsable(age: 5, accuracy: 10))
    }
    @Test func boundariesAreInclusive() {
        #expect(LocationFreshness.isUsable(age: 60, accuracy: 100))
    }
    @Test func tooOldIsNot() {
        #expect(!LocationFreshness.isUsable(age: 61, accuracy: 10))
    }
    @Test func tooCoarseIsNot() {
        #expect(!LocationFreshness.isUsable(age: 5, accuracy: 101))
    }
    @Test func invalidAccuracyIsNot() {
        #expect(!LocationFreshness.isUsable(age: 5, accuracy: 0))
        #expect(!LocationFreshness.isUsable(age: 5, accuracy: -1))
    }
}
