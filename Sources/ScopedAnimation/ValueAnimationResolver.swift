import SwiftUI

struct ValueAnimationResolverModifier: ViewModifier {
    let snapshot: AnimationTriggerSnapshot
    let stamp: AnimationScopeStamp

    @State private var history: AnimationTriggerHistory

    init(triggers: [AnimationTrigger], stamp: AnimationScopeStamp) {
        let snapshot = AnimationTriggerSnapshot(triggers: triggers)
        self.snapshot = snapshot
        self.stamp = stamp
        _history = State(initialValue: AnimationTriggerHistory(initialSnapshot: snapshot))
    }

    func body(content: Content) -> some View {
        let resolution = history.resolve(snapshot)

        content.transaction(value: snapshot) { transaction in
            guard !transaction.disablesAnimations, let resolution else {
                return
            }

            transaction.animation = resolution.winner.animation
            transaction.animationScopeStamp = stamp.withAnimation(resolution.winner.animation)

            #if DEBUG
                if !resolution.rejected.isEmpty {
                    AnimationScopeRuntimeWarning.report(
                        .multiTriggerConflict(scopeName: stamp.name, resolution: resolution)
                    )
                }
            #endif
        }
    }
}
