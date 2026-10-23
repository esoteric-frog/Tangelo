import Foundation
import Testing
@testable import TangeloCore

let t0 = Date(timeIntervalSince1970: 0)
func at(_ s: Double) -> Date { t0.addingTimeInterval(s) }

@Test func quickTapFires() {
    var d = TapDetector()
    #expect(d.update([], at: at(0)) == nil)
    #expect(d.update([.control], at: at(0.1)) == nil)
    #expect(d.update([], at: at(0.3)) == .control)
}

@Test func longHoldDoesNotFire() {
    var d = TapDetector()
    _ = d.update([.command], at: at(0))
    #expect(d.update([], at: at(0.8)) == nil)
}

@Test func twoKeysTogetherDoNotFire() {
    var d = TapDetector()
    _ = d.update([.control], at: at(0))
    _ = d.update([.control, .option], at: at(0.1))
    _ = d.update([.control], at: at(0.2))
    #expect(d.update([], at: at(0.3)) == nil)
}

@Test func keyAddedOnTopOfHeldKeyDoesNotFire() {
    var d = TapDetector()
    _ = d.update([.command], at: at(0))
    _ = d.update([.command, .control], at: at(0.1))
    _ = d.update([.command], at: at(0.2))
    #expect(d.update([], at: at(1.5)) == nil)
}

@Test func secondTapFiresAgain() {
    var d = TapDetector()
    _ = d.update([.control], at: at(0)); _ = d.update([], at: at(0.1))
    _ = d.update([.option], at: at(0.5))
    #expect(d.update([], at: at(0.6)) == .option)
}

@Test func keysMapToWheels() {
    #expect(WheelKind.opened(by: .control) == .conversion)
    #expect(WheelKind.opened(by: .command) == .tools)
    #expect(WheelKind.opened(by: .option) == .actions)
}
