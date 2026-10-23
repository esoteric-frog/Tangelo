import Foundation
import PDFKit
import UniformTypeIdentifiers

public struct PDFShrinkConverter: Converter {
    public init() {}

    public func outputs(for input: UTType) -> [Format] { input.conforms(to: .pdf) ? [.smallPDF] : [] }

    public func suggestedName(input: URL, format: Format) -> String {
        input.deletingPathExtension().lastPathComponent + " (small).pdf"
    }

    public func convert(input: URL, to format: Format, output: URL) async throws {
        guard let doc = PDFDocument(url: input) else { throw TangeloError("Can't open \(input.lastPathComponent) as a PDF") }
        guard !doc.isLocked else { throw TangeloError("\(input.lastPathComponent) is password-protected") }
        guard doc.write(to: output, withOptions: [.saveImagesAsJPEGOption: true, .optimizeImagesForScreenOption: true])
        else { throw TangeloError("Couldn't write the smaller PDF") }
        let size = { (u: URL) in (try? FileManager.default.attributesOfItem(atPath: u.path)[.size] as? Int) ?? 0 }
        guard size(output) < size(input) else {
            throw TangeloError("\(input.lastPathComponent) is already as small as it gets — nothing saved")
        }
    }
}
