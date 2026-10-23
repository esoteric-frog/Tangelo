import Foundation
import Testing
import UniformTypeIdentifiers
@testable import TangeloCore

let images = ImageConverter(binDir: binDir)

@Test(arguments: [Format.jpeg, .png, .tiff, .heic, .avif, .webp])
func pngConvertsToEveryFormat(_ format: Format) async throws {
    let dir = tmpDir(), input = dir.appendingPathComponent("in.png"), out = dir.appendingPathComponent("out.\(format.ext)")
    makeImage(input, type: .png, width: 40, height: 30)
    try await images.convert(input: input, to: format, output: out)
    let info = try #require(imageInfo(out))
    #expect(UTType(info.type)!.conforms(to: format.type))
    #expect(info.width == 40 && info.height == 30)
}

@Test func heicInputWorks() async throws {
    let dir = tmpDir(), input = dir.appendingPathComponent("in.heic"), out = dir.appendingPathComponent("out.jpg")
    makeImage(input, type: .heic, width: 64, height: 48)
    try await images.convert(input: input, to: .jpeg, output: out)
    #expect(imageInfo(out)?.width == 64)
}

@Test func rotatedPhotoStaysUprightInWebP() async throws {
    // Orientation 6 = stored landscape, shown portrait (typical iPhone photo).
    let dir = tmpDir(), input = dir.appendingPathComponent("in.jpg"), out = dir.appendingPathComponent("out.webp")
    makeImage(input, type: .jpeg, width: 40, height: 20, orientation: 6)
    try await images.convert(input: input, to: .webp, output: out)
    let info = try #require(imageInfo(out))
    #expect(info.width == 20 && info.height == 40)
}

@Test func transparentPNGToJPGIsWhiteNotBlack() async throws {
    let dir = tmpDir(), input = dir.appendingPathComponent("in.png"), out = dir.appendingPathComponent("out.jpg")
    makeImage(input, type: .png, width: 10, height: 10, alpha: true)
    try await images.convert(input: input, to: .jpeg, output: out)
    let p = pixel(out, x: 5, y: 5)
    #expect(p.r > 240 && p.g > 240 && p.b > 240)
}

@Test func outputsExcludeOwnFormatAndNonImages() {
    #expect(!images.outputs(for: .png).contains(.png))
    #expect(images.outputs(for: .png).contains(.webp))
    #expect(images.outputs(for: .pdf).isEmpty)
    #expect(images.outputs(for: .plainText).isEmpty)
}

@Test func garbageFileThrowsReadableError() async {
    let dir = tmpDir(), input = dir.appendingPathComponent("fake.png")
    write("not an image", to: input)
    await #expect(throws: TangeloError.self) {
        try await images.convert(input: input, to: .jpeg, output: dir.appendingPathComponent("o.jpg"))
    }
}
