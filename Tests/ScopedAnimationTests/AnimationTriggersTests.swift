import SwiftUI
import Testing

@testable import ScopedAnimation

extension AnimationScopeBehaviorTests {
    @Suite("Triggers")
    @MainActor
    struct Triggers {
        @Test
        func testEmptyTriggerScopeBehavesAsNamedBoundary() {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let hosted = host(EmptyTriggerScopeProbeView(model: model, recorder: recorder))
            defer { hosted.close() }
            pumpRunLoop()

            recorder.clear()
            withAnimation(.linear(duration: 0.2)) {
                model.outer.toggle()
            }
            pumpRunLoop()

            #expect(!recorder.hasAnimation("empty-trigger-child"))
            #expect(!recorder.hasStamp("empty-trigger-child"))
        }

        @Test
        func testEmptyTriggerScopePreservesAncestorStampWithoutRestoringAnimation() throws {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let proxyBox = ProxyBox()
            let hosted = host(
                StampedEmptyTriggerScopeProbeView(
                    model: model,
                    recorder: recorder,
                    proxyBox: proxyBox
                )
            )
            defer { hosted.close() }
            pumpRunLoop()

            let proxy = try #require(proxyBox.proxy)

            recorder.clear()
            proxy.animate {
                model.outer.toggle()
            }
            pumpRunLoop()

            #expect(!recorder.hasAnimation("stamped-empty-trigger-child"))
            #expect(recorder.hasStampName("stamped-empty-trigger-child", "Outer"))
        }

        @Test
        func testMultiTriggerScopeAnimatesFirstTriggerIndependently() {
            let model = MultiTriggerProbeModel()
            let recorder = TransactionRecorder()
            let selectionAnimation = Animation.easeOut(duration: 0.12)
            let hosted = host(
                MultiTriggerProbeView(
                    model: model,
                    recorder: recorder,
                    selectionAnimation: selectionAnimation,
                    hintAnimation: Animation.spring(response: 0.35, dampingFraction: 0.7)
                )
            )
            defer { hosted.close() }
            pumpRunLoop()

            recorder.clear()
            model.selectedPoints = 1
            pumpRunLoop()

            #expect(recorder.hasAnimation("multi-trigger-child"))
            #expect(recorder.hasStamp("multi-trigger-child"))
            #expect(recorder.hasAnimation("multi-trigger-child", selectionAnimation))
        }

        @Test
        func testMultiTriggerScopeAnimatesSecondTriggerIndependently() {
            let model = MultiTriggerProbeModel()
            let recorder = TransactionRecorder()
            let hintAnimation = Animation.spring(response: 0.35, dampingFraction: 0.7)
            let hosted = host(
                MultiTriggerProbeView(
                    model: model,
                    recorder: recorder,
                    selectionAnimation: Animation.easeOut(duration: 0.12),
                    hintAnimation: hintAnimation
                )
            )
            defer { hosted.close() }
            pumpRunLoop()

            recorder.clear()
            model.hintPoints = 1
            pumpRunLoop()

            #expect(recorder.hasAnimation("multi-trigger-child"))
            #expect(recorder.hasStamp("multi-trigger-child"))
            #expect(recorder.hasAnimation("multi-trigger-child", hintAnimation))
        }

        @Test
        func testMultiTriggerScopePrefersFirstTriggerOnSimultaneousChange() {
            let model = MultiTriggerProbeModel()
            let recorder = TransactionRecorder()
            let selectionAnimation = Animation.easeOut(duration: 0.12)
            let hintAnimation = Animation.spring(response: 0.35, dampingFraction: 0.7)
            let hosted = host(
                MultiTriggerProbeView(
                    model: model,
                    recorder: recorder,
                    selectionAnimation: selectionAnimation,
                    hintAnimation: hintAnimation
                )
            )
            defer { hosted.close() }
            pumpRunLoop()

            recorder.clear()
            model.selectedPoints = 1
            model.hintPoints = 1
            pumpRunLoop()

            #expect(recorder.hasAnimation("multi-trigger-child", selectionAnimation))
            #expect(!recorder.hasAnimation("multi-trigger-child", hintAnimation))
        }

        @Test
        func testMultiTriggerScopeDoesNotAnimateUnrelatedStateChanges() {
            let model = MultiTriggerProbeModel()
            let recorder = TransactionRecorder()
            let hosted = host(
                MultiTriggerProbeView(
                    model: model,
                    recorder: recorder,
                    selectionAnimation: Animation.easeOut(duration: 0.12),
                    hintAnimation: Animation.spring(response: 0.35, dampingFraction: 0.7)
                )
            )
            defer { hosted.close() }
            pumpRunLoop()

            recorder.clear()
            model.unrelated.toggle()
            pumpRunLoop()

            #expect(!recorder.hasAnimation("multi-trigger-child"))
            #expect(!recorder.hasStamp("multi-trigger-child"))
        }

        @Test
        func testThreeTriggerScopePrefersFirstChangedTrigger() {
            let model = MultiTriggerProbeModel()
            let recorder = TransactionRecorder()
            let selectionAnimation = Animation.easeOut(duration: 0.12)
            let hintAnimation = Animation.spring(response: 0.35, dampingFraction: 0.7)
            let tertiaryAnimation = Animation.linear(duration: 0.91)
            let hosted = host(
                ThreeTriggerProbeView(
                    model: model,
                    recorder: recorder,
                    selectionAnimation: selectionAnimation,
                    hintAnimation: hintAnimation,
                    tertiaryAnimation: tertiaryAnimation
                )
            )
            defer { hosted.close() }
            pumpRunLoop()

            recorder.clear()
            model.hintPoints = 1
            model.tertiaryPoints = 1
            pumpRunLoop()

            #expect(recorder.hasAnimation("three-trigger-child", hintAnimation))
            #expect(!recorder.hasAnimation("three-trigger-child", tertiaryAnimation))
        }

        @Test
        func testDynamicTriggerReorderingPreservesIdentityAndUsesNewArrayPriority() {
            let model = DynamicTriggerProbeModel(triggerCount: 3)
            model.first = 1
            model.second = 2
            model.third = 3
            let identityRecorder = ViewIdentityRecorder()
            let transactionRecorder = TransactionRecorder()
            let expectedAnimation = Animation.linear(duration: 0.33)
            let hosted = host(
                DynamicTriggerProbeView(
                    model: model,
                    identityRecorder: identityRecorder,
                    transactionRecorder: transactionRecorder
                )
            )
            defer { hosted.close() }
            pumpRunLoop()

            transactionRecorder.clear()
            #if DEBUG
                AnimationScopeRuntimeWarning.withTestSink(
                    { _ in },
                    operation: {
                        model.isReversed = true
                        pumpRunLoop()
                    }
                )
            #else
                model.isReversed = true
                pumpRunLoop()
            #endif

            #expect(identityRecorder.distinctIdentities.count == 1)
            #expect(transactionRecorder.hasAnimation("dynamic-trigger-child", expectedAnimation))
        }

        @Test
        func sequentialTriggersDoNotAnimateLaterUnrelatedUpdates() {
            let model = MultiTriggerProbeModel()
            let recorder = TransactionRecorder()
            let selectionAnimation = Animation.easeOut(duration: 0.12)
            let hintAnimation = Animation.spring(response: 0.35, dampingFraction: 0.7)
            let hosted = host(
                MultiTriggerProbeView(
                    model: model,
                    recorder: recorder,
                    selectionAnimation: selectionAnimation,
                    hintAnimation: hintAnimation
                )
            )
            defer { hosted.close() }
            pumpRunLoop()

            recorder.clear()
            model.selectedPoints = 2
            pumpRunLoop()
            #expect(recorder.hasAnimation("multi-trigger-child", selectionAnimation))

            recorder.clear()
            model.hintPoints = 2
            pumpRunLoop()
            #expect(recorder.hasAnimation("multi-trigger-child", hintAnimation))

            recorder.clear()
            model.unrelated.toggle()
            pumpRunLoop()
            #expect(!recorder.hasAnimation("multi-trigger-child"))
            #expect(!recorder.hasStamp("multi-trigger-child"))
        }

        @Test(
            "Resizing preserves state, suppresses animation, and establishes the next baseline",
            arguments: [(0, 1), (1, 0), (1, 2), (2, 1), (2, 3), (3, 2), (0, 3), (3, 0)])
        func dynamicTriggerCount(initialCount: Int, updatedCount: Int) {
            let model = DynamicTriggerProbeModel(triggerCount: initialCount)
            let identityRecorder = ViewIdentityRecorder()
            let transactionRecorder = TransactionRecorder()
            let hosted = host(
                DynamicTriggerProbeView(
                    model: model,
                    identityRecorder: identityRecorder,
                    transactionRecorder: transactionRecorder
                )
            )
            defer { hosted.close() }
            pumpRunLoop()

            transactionRecorder.clear()
            model.triggerCount = updatedCount
            pumpRunLoop()

            #expect(identityRecorder.distinctIdentities.count == 1)
            #expect(!transactionRecorder.hasAnimation("dynamic-trigger-child"))

            transactionRecorder.clear()
            model.first += 1
            pumpRunLoop()
            if updatedCount == 0 {
                #expect(!transactionRecorder.hasAnimation("dynamic-trigger-child"))
            } else {
                #expect(
                    transactionRecorder.hasAnimation(
                        "dynamic-trigger-child", .easeOut(duration: 0.11)))
                #expect(
                    transactionRecorder.hasScopedAnimation(
                        "dynamic-trigger-child", .easeOut(duration: 0.11)))
            }
            #expect(identityRecorder.distinctIdentities.count == 1)
        }
    }
}
