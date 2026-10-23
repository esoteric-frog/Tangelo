import Foundation
import PDFKit
import Testing
@testable import TangeloCore

let shrink = PDFShrinkConverter()

@Test func photoPDFGetsSmaller() async throws {
    let dir = tmpDir(), input = dir.appendingPathComponent("scan.pdf"), out = dir.appendingPathComponent("o.pdf")
    makePDF(input, withPhoto: true)
    try await shrink.convert(input: input, to: .smallPDF, output: out)
    #expect(fileSize(out) < fileSize(input))
    #expect(PDFDocument(url: out)?.pageCount == 1)
}

@Test func textPDFThatGrowsIsRefused() async {
    let dir = tmpDir(), input = dir.appendingPathComponent("t.pdf")
    makePDF(input, withPhoto: false)
    do {
        try await shrink.convert(input: input, to: .smallPDF, output: dir.appendingPathComponent("o.pdf"))
        Issue.record("no throw")
    } catch { #expect(error.localizedDescription.contains("already as small")) }
}

@Test func nameHasSmallSuffix() {
    #expect(shrink.suggestedName(input: URL(fileURLWithPath: "/x/Report.pdf"), format: .smallPDF) == "Report (small).pdf")
}

@Test func onlyPDFsOffered() {
    #expect(shrink.outputs(for: .pdf) == [.smallPDF])
    #expect(shrink.outputs(for: .png).isEmpty)
}
