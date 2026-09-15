import SwiftUI

struct AnimationTriggerSnapshot: Equatable {
    private let triggers: [AnimationTrigger]

    init(triggers: [AnimationTrigger]) {
        self.triggers = triggers
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.triggers.elementsEqual(rhs.triggers) { $0.hasSameValue(as: $1) }
    }

    enum Change {
        case unchanged
        case structure
        case values(AnimationTriggerResolution)
    }

    func change(since previous: Self) -> Change {
        guard triggers.count == previous.triggers.count else {
            return .structure
        }

        var resolution: AnimationTriggerResolution?
        for (index, trigger) in triggers.enumerated()
        where !trigger.hasSameValue(as: previous.triggers[index]) {
            let selection = AnimationTriggerResolution.Selection(
                index: index, animation: trigger.animation
            )
            if resolution == nil {
                resolution = AnimationTriggerResolution(winner: selection)
                #if !DEBUG
                    return .values(AnimationTriggerResolution(winner: selection))
                #endif
            } else {
                #if DEBUG
                    resolution?.rejected.append(selection)
                #endif
            }
        }
        return resolution.map(Change.values) ?? .unchanged
    }
}

struct AnimationTriggerResolution: Equatable, Sendable {
    struct Selection: Equatable, Sendable {
        let index: Int
        let animation: Animation
    }

    let winner: Selection
    #if DEBUG
        var rejected: [Selection] = []
    #endif
}

@MainActor
final class AnimationTriggerHistory {
    private var latestSnapshot: AnimationTriggerSnapshot
    private var latestResolution: AnimationTriggerResolution?

    init(initialSnapshot: AnimationTriggerSnapshot) {
        latestSnapshot = initialSnapshot
    }

    func resolve(_ snapshot: AnimationTriggerSnapshot) -> AnimationTriggerResolution? {
        // SwiftUI can evaluate the modifier more than once before delivering its transaction.
        // Consuming a change on the first evaluation would lose its animation on the next one.
        switch snapshot.change(since: latestSnapshot) {
        case .unchanged:
            return latestResolution
        case .structure:
            latestResolution = nil
        case .values(let resolution):
            latestResolution = resolution
        }
        latestSnapshot = snapshot
        return latestResolution
    }
}
