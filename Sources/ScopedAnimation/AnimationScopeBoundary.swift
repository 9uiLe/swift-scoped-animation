import SwiftUI

struct AnimationScopeBoundaryModifier: ViewModifier {
    private let stamp: AnimationScopeStamp?
    #if DEBUG
        private let warnsOnLeaks: Bool
    #endif

    init(stamp: AnimationScopeStamp) {
        self.stamp = stamp
        #if DEBUG
            warnsOnLeaks = false
        #endif
    }

    init(warnsOnLeaks: Bool) {
        stamp = nil
        #if DEBUG
            self.warnsOnLeaks = warnsOnLeaks
        #endif
    }

    func body(content: Content) -> some View {
        content.transaction { transaction in
            #if DEBUG
                let incomingAnimation = transaction.animation
            #endif
            let incomingStamp = transaction.animationScopeStamp

            #if DEBUG
                if warnsOnLeaks, incomingAnimation != nil, incomingStamp == nil {
                    AnimationScopeRuntimeWarning.report(.barrierLeak)
                }
                if let stamp, !transaction.disablesAnimations,
                    incomingAnimation != nil,
                    let incomingStamp,
                    incomingStamp.id != stamp.id,
                    incomingStamp.animation != nil
                {
                    AnimationScopeRuntimeWarning.report(
                        .crossScopeAnimationStrip(
                            strippingScopeName: stamp.name,
                            strippedScopeName: incomingStamp.name
                        )
                    )
                }
            #endif

            transaction.animation = nil

            guard let stamp, !transaction.disablesAnimations,
                incomingStamp?.id == stamp.id,
                let restoredAnimation = incomingStamp?.animation
            else {
                return
            }

            transaction.animation = restoredAnimation
        }
    }
}
