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
        // SwiftUI はトランザクションを届ける前に修飾子を複数回評価することがあります。
        // 最初の評価で変更を消費すると、次の評価でアニメーションを失うため結果を保持します。
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
