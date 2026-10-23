import Foundation
import Testing
@testable import TangeloCore

let registry = Registry([ImageConverter(binDir: binDir), PDFShrinkConverter()])

@Test func choicesAreCommonToAllFiles() {
    let pngAndHeic = [URL(fileURLWithPath: "/a.png"), URL(fileURLWithPath: "/b.heic")]
    let c = registry.choices(for: pngAndHeic)
    #expect(c.contains(.jpeg) && c.contains(.webp))
    #expect(!c.contains(.png) && !c.contains(.heic))   // each excluded by one file
}

@Test func mixedImageAndPDFHasNoChoices() {
    #expect(registry.choices(for: [URL(fileURLWithPath: "/a.png"), URL(fileURLWithPath: "/b.pdf")]).isEmpty)
}

@Test func unknownTypeHasNoChoices() {
    #expect(registry.choices(for: [URL(fileURLWithPath: "/a.xyz")]).isEmpty)
    #expect(registry.converter(for: URL(fileURLWithPath: "/a.xyz"), format: .jpeg) == nil)
}

@Test func uppercaseExtensionsWork() {
    #expect(registry.choices(for: [URL(fileURLWithPath: "/IMG_1.HEIC")]).contains(.jpeg))
}

@Test func pdfAloneOffersSmallerPDF() {
    #expect(registry.choices(for: [URL(fileURLWithPath: "/a.pdf")]) == [.smallPDF])
}
