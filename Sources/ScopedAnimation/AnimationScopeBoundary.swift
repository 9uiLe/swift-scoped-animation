import SwiftUI

struct AnimationScopeBoundaryModifier: ViewModifier {
    let stamp: AnimationScopeStamp

    func body(content: Content) -> some View {
        content.transaction { transaction in
            #if DEBUG
                let incomingAnimation = transaction.animation
            #endif
            let incomingStamp = transaction.animationScopeStamp

            #if DEBUG
                if !transaction.disablesAnimations,
                    incomingAnimation != nil,
                    let incomingStamp,
                    incomingStamp.id != stamp.id,
                    incomingStamp.animation != nil
                {
                    AnimationScopeRuntimeWarning.report(
                        .crossScopeAnimationStrip(
                            site: AnimationScopeRuntimeWarning.Site(
                                "AnimationScopeBoundary",
                                scopeName: stamp.name
                            ),
                            strippingScopeName: stamp.name,
                            strippedScopeName: incomingStamp.name
                        )
                    )
                }
            #endif

            transaction.animation = nil

            guard !transaction.disablesAnimations,
                incomingStamp?.id == stamp.id,
                let restoredAnimation = incomingStamp?.animation
            else {
                return
            }

            transaction.animation = restoredAnimation
        }
    }
}
