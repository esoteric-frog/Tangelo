import Foundation
import Testing
@testable import TangeloCore

let t0 = Date(timeIntervalSince1970: 0)
func at(_ s: Double) -> Date { t0.addingTimeInterval(s) }

@Test func holdOpensAfterDelayOnce() {
    var d = HoldDetector()
    #expect(d.update([.control], at: at(0)) == nil)
    #expect(d.update([.control], at: at(0.1)) == nil)       // too short yet
    #expect(d.update([.control], at: at(0.2)) == .open(.control))
    #expect(d.update([.control], at: at(0.5)) == nil)       // already open
}

@Test func releaseCloses() {
    var d = HoldDetector()
    _ = d.update([.option], at: at(0)); _ = d.update([.option], at: at(0.3))
    #expect(d.update([], at: at(0.4)) == .close)
    #expect(d.update([], at: at(0.5)) == nil)
}

@Test func quickTapDoesNothing() {
    var d = HoldDetector()
    _ = d.update([.control], at: at(0))
    #expect(d.update([], at: at(0.05)) == nil)
}

@Test func twoKeysNeverOpenAndCloseAnOpenWheel() {
    var d = HoldDetector()
    _ = d.update([.control, .command], at: at(0))
    #expect(d.update([.control, .command], at: at(1)) == nil)
    _ = d.update([.command], at: at(1.1)); _ = d.update([.command], at: at(1.4))  // opens tools
    #expect(d.update([.command, .option], at: at(1.5)) == .close)
}

@Test func switchingKeysSwapsWheel() {
    var d = HoldDetector()
    _ = d.update([.control], at: at(0)); _ = d.update([.control], at: at(0.3))
    #expect(d.update([.option], at: at(0.4)) == .close)
    #expect(d.update([.option], at: at(0.6)) == .open(.option))
}

@Test func keysMapToWheels() {
    #expect(WheelKind.opened(by: .control) == .conversion)
    #expect(WheelKind.opened(by: .command) == .tools)
    #expect(WheelKind.opened(by: .option) == .actions)
}
