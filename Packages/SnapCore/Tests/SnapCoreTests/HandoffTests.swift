import Testing
@testable import SnapCore

@Suite struct HandoffTests {
    @Test func theOriginalImageTypeIsTheFirstImageOffered() {
        // Photos offers the original first; a JPEG rendition may follow.
        #expect(Handoff.imageType(in: ["public.heic", "public.jpeg"]) == "public.heic")
        #expect(Handoff.imageType(in: ["public.url", "public.jpeg"]) == "public.jpeg")
    }
    @Test func nothingWithoutAnImage() {
        #expect(Handoff.imageType(in: ["public.url", "public.plain-text"]) == nil)
        #expect(Handoff.imageType(in: []) == nil)
        #expect(Handoff.imageType(in: ["not a type"]) == nil)
    }
}
