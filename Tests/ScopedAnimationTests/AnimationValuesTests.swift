import SwiftUI
import Testing

@testable import ScopedAnimation

extension AnimationScopeBehaviorTests {
    @Suite("値")
    @MainActor
    struct Values {
        @Test
        func transitionsReceiveScopedTransactionsForInsertionAndRemoval() {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let hosted = host(TransitionProbeView(model: model, recorder: recorder))
            defer { hosted.close() }
            pumpRunLoop()

            recorder.clear()
            model.inner.toggle()
            pumpRunLoop()

            #expect(recorder.hasAnimation("transition-container"))
            #expect(recorder.hasStampName("transition-container", "Transition"))

            recorder.clear()
            model.inner.toggle()
            pumpRunLoop()
            #expect(recorder.hasAnimation("transition-container", .easeInOut(duration: 0.2)))
            #expect(recorder.hasScopedAnimation("transition-container", .easeInOut(duration: 0.2)))
        }

        @Test
        func testValueDrivenScopeHonorsDisabledAnimations() {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let hosted = host(DisabledValueScopeProbeView(model: model, recorder: recorder))
            defer { hosted.close() }
            pumpRunLoop()

            recorder.clear()
            model.inner.toggle()
            pumpRunLoop()

            #expect(!recorder.hasAnimation("disabled-value-child"))
            #expect(!recorder.hasStamp("disabled-value-child"))
            #expect(recorder.matching("disabled-value-child").contains { $0.disablesAnimations })
        }

        @Test
        func testValueDrivenScopeBlocksAncestorsAndAnimatesItsValueWithStamp() {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let hosted = host(ValueScopeProbeView(model: model, recorder: recorder))
            defer { hosted.close() }
            pumpRunLoop()

            recorder.clear()
            withAnimation(.linear(duration: 0.2)) {
                model.outer.toggle()
            }
            pumpRunLoop()
            #expect(!recorder.hasAnimation("value-child"))
            #expect(!recorder.hasStamp("value-child"))

            recorder.clear()
            model.inner.toggle()
            pumpRunLoop()
            #expect(recorder.hasAnimation("value-child"))
            #expect(recorder.hasStamp("value-child"))
        }

        @Test
        func testNonNestedValueDrivenScopeKeepsItsValueAnimation() {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let hosted = host(NonNestedValueScopeProbeView(model: model, recorder: recorder))
            defer { hosted.close() }
            pumpRunLoop()

            recorder.clear()
            model.outer.toggle()
            pumpRunLoop()

            #expect(recorder.hasAnimation("control-value-child"))
            #expect(recorder.hasStampName("control-value-child", "Control"))
        }

        @Test
        func testNestedValueDrivenScopeStripsAncestorValueAnimationAtDescendantBoundary() {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let hosted = host(NestedValueScopeProbeView(model: model, recorder: recorder))
            defer { hosted.close() }
            pumpRunLoop()

            recorder.clear()
            model.outer.toggle()
            pumpRunLoop()

            #expect(!recorder.hasAnimation("nested-value-child"))
            #expect(recorder.hasStampName("nested-value-child", "Outer"))
            #expect(
                recorder.matching("nested-value-child").contains {
                    !$0.hasAnimation && $0.stampName == "Outer"
                        && $0.stamp?.animation != nil
                })
        }

        @Test
        func testValueDrivenScopeRestampsWhenAnimationChangesInsideStampedTransaction() throws {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let proxyBox = ProxyBox()
            let innerAnimation = Animation.easeInOut(duration: 0.45)
            let hosted = host(
                ValueAttributionProbeView(
                    model: model,
                    recorder: recorder,
                    proxyBox: proxyBox,
                    innerAnimation: innerAnimation
                )
            )
            defer { hosted.close() }
            pumpRunLoop()

            let proxy = try #require(proxyBox.proxy)

            recorder.clear()
            proxy.animate(.linear(duration: 0.2)) {
                model.inner.toggle()
            }
            pumpRunLoop()

            #expect(recorder.hasAnimation("attribution-child"))
            #expect(recorder.hasStampName("attribution-child", "inner-value"))
            #expect(recorder.hasScopedAnimation("attribution-child", innerAnimation))
        }

        @Test
        func testValueDrivenScopeRestampsEqualAnimationForInnerScopeOwnership() throws {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let proxyBox = ProxyBox()
            let sharedAnimation = Animation.linear(duration: 0.2)
            let hosted = host(
                ValueAttributionProbeView(
                    model: model,
                    recorder: recorder,
                    proxyBox: proxyBox,
                    innerAnimation: sharedAnimation
                )
            )
            defer { hosted.close() }
            pumpRunLoop()

            let proxy = try #require(proxyBox.proxy)

            recorder.clear()
            proxy.animate(sharedAnimation) {
                model.inner.toggle()
            }
            pumpRunLoop()

            #expect(recorder.hasAnimation("attribution-child"))
            #expect(recorder.hasStampName("attribution-child", "inner-value"))
            #expect(recorder.hasScopedAnimation("attribution-child", sharedAnimation))
        }
    }
}
