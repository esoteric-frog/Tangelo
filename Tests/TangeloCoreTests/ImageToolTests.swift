import Foundation
import Testing
import UniformTypeIdentifiers
@testable import TangeloCore

let tools = ImageToolConverter()

@Test func compressShrinksJPEGAndKeepsFormat() async throws {
    let dir = tmpDir(), input = dir.appendingPathComponent("p.jpg"), out = dir.appendingPathComponent("o.jpg")
    makeNoise(input, type: .jpeg, width: 300, height: 200)
    try await tools.convert(input: input, to: .compress, output: out)
    #expect(fileSize(out) < fileSize(input))
    #expect(imageInfo(out)?.type == UTType.jpeg.identifier)
}

@Test func compressThatGrowsIsRefused() async {
    let dir = tmpDir(), input = dir.appendingPathComponent("s.png")
    makeImage(input, type: .png, width: 8, height: 8)
    do { try await tools.convert(input: input, to: .compress, output: dir.appendingPathComponent("o.png")); Issue.record("no throw") }
    catch { #expect(error.localizedDescription.contains("already as small")) }
}

@Test func resizeHalvesAndStaysUpright() async throws {
    let dir = tmpDir(), input = dir.appendingPathComponent("r.jpg"), out = dir.appendingPathComponent("o.jpg")
    makeImage(input, type: .jpeg, width: 40, height: 20, orientation: 6)  // shown as 20×40
    try await tools.convert(input: input, to: .halfSize, output: out)
    let info = try #require(imageInfo(out))
    #expect(info.width == 10 && info.height == 20)
}

@Test func namesKeepExtension() {
    let u = URL(fileURLWithPath: "/x/IMG_1.HEIC")
    #expect(tools.suggestedName(input: u, format: .compress) == "IMG_1 (compressed).HEIC")
    #expect(tools.suggestedName(input: u, format: .halfSize) == "IMG_1 (50%).HEIC")
}

@Test func onlyWritableImageTypes() {
    #expect(tools.outputs(for: .jpeg) == [.compress, .halfSize])
    #expect(tools.outputs(for: .webP).isEmpty)
    #expect(tools.outputs(for: .pdf).isEmpty)
}
