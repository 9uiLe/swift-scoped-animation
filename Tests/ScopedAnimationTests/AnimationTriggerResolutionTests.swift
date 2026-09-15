import SwiftUI
import Testing

@testable import ScopedAnimation

@Suite("Trigger selection")
@MainActor
struct AnimationTriggerResolutionTests {
    @Test("Repeated snapshots preserve the pending selection until a structural change")
    func pendingSelection() throws {
        let initial = AnimationTriggerSnapshot(triggers: [.animation(.linear, value: 0)])
        let changed = AnimationTriggerSnapshot(triggers: [.animation(.spring, value: 1)])
        let history = AnimationTriggerHistory(initialSnapshot: initial)
        let selection = try #require(history.resolve(changed))

        #expect(history.resolve(changed) == selection)
        let resized = AnimationTriggerSnapshot(triggers: [
            .animation(.linear, value: 1), .animation(.spring, value: false),
        ])
        #expect(history.resolve(resized) == nil)
        #expect(history.resolve(resized) == nil)
        let next = AnimationTriggerSnapshot(triggers: [
            .animation(.linear, value: 1), .animation(.spring, value: true),
        ])
        #expect(history.resolve(next)?.winner.index == 1)
    }

    @Test("The first changed position wins regardless of the animation", arguments: 1..<8)
    func priority(changedMask: Int) throws {
        let animations: [Animation] = [.linear, .easeIn, .spring]
        let previous = AnimationTriggerSnapshot(
            triggers: animations.map { .animation($0, value: false) }
        )
        let current = AnimationTriggerSnapshot(
            triggers: animations.enumerated().map { index, animation in
                .animation(animation, value: changedMask & (1 << index) != 0)
            }
        )

        let history = AnimationTriggerHistory(initialSnapshot: previous)
        let resolution = try #require(history.resolve(current))
        let expectedWinner = changedMask.trailingZeroBitCount
        #expect(resolution.winner.index == expectedWinner)
        #expect(resolution.winner.animation == animations[expectedWinner])
        #if DEBUG
            let expectedRejected = (0..<3).filter {
                $0 != expectedWinner && changedMask & (1 << $0) != 0
            }
            #expect(resolution.rejected.map(\.index) == expectedRejected)
            #expect(resolution.rejected.map(\.animation) == expectedRejected.map { animations[$0] })
        #endif
    }

    @Test("Changing an animation alone does not trigger an update")
    func animationIsConfiguration() {
        let previous = AnimationTriggerSnapshot(triggers: [.animation(.linear, value: 1)])
        let current = AnimationTriggerSnapshot(triggers: [.animation(.spring, value: 1)])

        #expect(previous == current)
        let history = AnimationTriggerHistory(initialSnapshot: previous)
        #expect(history.resolve(current) == nil)
    }

    @Test("Equal values of different concrete types remain different triggers")
    func erasedValueTypes() {
        let integer = AnimationTriggerSnapshot(triggers: [.animation(.linear, value: 1)])
        let optional = AnimationTriggerSnapshot(triggers: [.animation(.linear, value: Int?.some(1))]
        )

        #expect(integer != optional)
        #expect(optional != integer)
        let history = AnimationTriggerHistory(initialSnapshot: integer)
        #expect(history.resolve(optional)?.winner.index == 0)
    }

    @Test("Optional nil and collection values compare by value")
    func heterogeneousValues() throws {
        let previous = AnimationTriggerSnapshot(triggers: [
            .animation(.linear, value: Int?.none),
            .animation(.spring, value: Set([1, 2])),
        ])
        let current = AnimationTriggerSnapshot(triggers: [
            .animation(.easeOut, value: Int?.none),
            .animation(.spring, value: Set([2, 3])),
        ])

        let history = AnimationTriggerHistory(initialSnapshot: previous)
        let resolution = try #require(history.resolve(current))
        #expect(resolution.winner.index == 1)
        #expect(resolution.winner.animation == .spring)
    }
}
