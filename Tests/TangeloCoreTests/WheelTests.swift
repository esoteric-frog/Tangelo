import Foundation
import Testing
@testable import TangeloCore

let c = CGPoint(x: 100, y: 100)  // AppKit coords: y up

@Test func fourSlicesClockwiseFromTop() {
    #expect(WheelGeometry.slice(at: CGPoint(x: 100, y: 180), center: c, count: 4, deadZone: 50) == 0)  // up
    #expect(WheelGeometry.slice(at: CGPoint(x: 180, y: 100), center: c, count: 4, deadZone: 50) == 1)  // right
    #expect(WheelGeometry.slice(at: CGPoint(x: 100, y: 20), center: c, count: 4, deadZone: 50) == 2)   // down
    #expect(WheelGeometry.slice(at: CGPoint(x: 20, y: 100), center: c, count: 4, deadZone: 50) == 3)   // left
    #expect(WheelGeometry.slice(at: CGPoint(x: 160, y: 175), center: c, count: 4, deadZone: 50) == 0)  // up-right, nearer up
}

@Test func deadZoneAndEmptyWheel() {
    #expect(WheelGeometry.slice(at: CGPoint(x: 110, y: 110), center: c, count: 4, deadZone: 50) == nil)
    #expect(WheelGeometry.slice(at: CGPoint(x: 100, y: 180), center: c, count: 0, deadZone: 50) == nil)
    #expect(WheelGeometry.slice(at: CGPoint(x: 20, y: 30), center: c, count: 1, deadZone: 50) == 0)
}

let menus = WheelMenus(conversion: Registry([ImageConverter(binDir: binDir), PDFShrinkConverter()]),
                       tools: Registry([ImageToolConverter(), PDFShrinkConverter()]))

@Test func conversionWheelListsFormats() {
    let ch = menus.choices(.conversion, for: [URL(fileURLWithPath: "/a.png")])
    #expect(ch.contains(.format(.webp)) && !ch.contains(.format(.png)))
}

@Test func actionsForAnyFiles() {
    #expect(menus.choices(.actions, for: [URL(fileURLWithPath: "/a.txt")]).count == FileAction.allCases.count)
    #expect(menus.choices(.actions, for: []).isEmpty)
}

@Test func nothingForUnsupportedFiles() {
    #expect(menus.choices(.conversion, for: [URL(fileURLWithPath: "/a.txt")]).isEmpty)
    #expect(menus.choices(.tools, for: [URL(fileURLWithPath: "/a.txt")]).isEmpty)
}

@Test func pathsAreOnePerLine() {
    #expect(FileAction.paths([URL(fileURLWithPath: "/x/a b.png"), URL(fileURLWithPath: "/y/c.pdf")]) == "/x/a b.png\n/y/c.pdf")
}

@Test func terminalOpensFolderOfFileOrFolderItself() throws {
    let dir = tmpDir(), file = dir.appendingPathComponent("f.txt")
    write("x", to: file)
    #expect(FileAction.terminalFolder(for: [file])?.standardizedFileURL == dir.standardizedFileURL)
    #expect(FileAction.terminalFolder(for: [dir])?.standardizedFileURL == dir.standardizedFileURL)
    #expect(FileAction.terminalFolder(for: []) == nil)
}

@Test func toolsWheelForPhotoAndPDF() {
    #expect(menus.choices(.tools, for: [URL(fileURLWithPath: "/a.jpg")]) == [.format(.compress), .format(.halfSize)])
    #expect(menus.choices(.tools, for: [URL(fileURLWithPath: "/a.pdf")]) == [.format(.smallPDF)])
}

@Test func sliceIsRoundedAndSeparated() {
    let o = CGPoint.zero
    let p = WheelGeometry.slicePath(index: 0, count: 4, center: o, inner: 50, outer: 160, gap: 6, corner: 10)
    #expect(p.contains(CGPoint(x: 0, y: 100)))                      // middle of the top slice (y up)
    #expect(!p.contains(CGPoint(x: 0, y: 30)))                      // dead zone stays empty
    #expect(!p.contains(CGPoint(x: 100 * sin(.pi / 4), y: 100 * cos(.pi / 4))))  // on the seam: gap
    let sharp = CGPoint(x: 158 * sin(.pi / 4 - 0.03), y: 158 * cos(.pi / 4 - 0.03))
    #expect(!p.contains(sharp))                                     // outer corner is rounded off
    #expect(WheelGeometry.slicePath(index: 0, count: 1, center: o, inner: 50, outer: 160, gap: 6, corner: 10)
        .contains(CGPoint(x: 0, y: -100)))                          // one choice = full ring
}
