import Testing
import Foundation
import ImageIO
@testable import SnapCore

@Suite struct SquareCropTests {
    private func size(_ data: Data) -> (Int, Int) {
        let p = TestJPEG.properties(of: data)
        return (p[kCGImagePropertyPixelWidth] as! Int, p[kCGImagePropertyPixelHeight] as! Int)
    }

    @Test func landscapeBecomesSquareOfShorterSide() throws {
        let out = try SquareCrop.centered(in: TestJPEG.make(width: 4032, height: 3024))
        #expect(size(out) == (3024, 3024))
    }

    @Test func portraitBecomesSquareOfShorterSide() throws {
        let out = try SquareCrop.centered(in: TestJPEG.make(width: 3024, height: 4032))
        #expect(size(out) == (3024, 3024))
    }

    @Test func squareStaysItsSize() throws {
        let out = try SquareCrop.centered(in: TestJPEG.make(width: 3000, height: 3000))
        #expect(size(out) == (3000, 3000))
    }

    @Test func garbageThrowsDecodeFailed() {
        #expect(throws: SnapError.decodeFailed) {
            try SquareCrop.centered(in: Data([0, 1, 2, 3, 4, 5, 6, 7]))
        }
    }
}
