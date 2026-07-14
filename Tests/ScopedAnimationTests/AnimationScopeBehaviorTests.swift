#if canImport(SwiftUI)
    @testable import ScopedAnimation
    import SwiftUI
    import XCTest

    // XCTest is used because these behavioral tests need a platform hosting view/controller
    // lifetime while SwiftUI transactions are pumped on the main actor.
    @MainActor
    final class AnimationScopeBehaviorTests: XCTestCase {
        func testS7TransactionHookCanRestoreAnimationAfterStrip() {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            _ = host(S7RestoreProbeView(model: model, recorder: recorder))
            pumpRunLoop()

            recorder.clear()
            withAnimation(.linear(duration: 0.2)) {
                model.inner.toggle()
            }
            pumpRunLoop()
            recorder.dump("R1_S7_RESTORE")

            XCTAssertTrue(recorder.hasAnimation("s7-child"))
        }

        func testS8ValueTransactionHookOnlyAnimatesItsTrackedValue() {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            _ = host(S8ValueTransactionProbeView(model: model, recorder: recorder))
            pumpRunLoop()

            recorder.clear()
            model.outer.toggle()
            pumpRunLoop()
            recorder.dump("S8_VALUE_TRANSACTION_UNRELATED")

            XCTAssertFalse(recorder.hasAnimation("s8-child"))

            recorder.clear()
            model.inner.toggle()
            pumpRunLoop()
            recorder.dump("S8_VALUE_TRANSACTION_TRACKED")

            XCTAssertTrue(recorder.hasAnimation("s8-child"))
        }

        func testValueDrivenScopeSuppliesAnimationAndStampToTransitionInsertion() {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            _ = host(TransitionProbeView(model: model, recorder: recorder))
            pumpRunLoop()

            recorder.clear()
            model.inner.toggle()
            pumpRunLoop()
            recorder.dump("M1_TRANSITION_INSERTION")

            XCTAssertTrue(recorder.hasAnimation("transition-container"))
            XCTAssertTrue(recorder.hasStampName("transition-container", "Transition"))
        }

        func testValueDrivenScopeHonorsDisabledAnimations() {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            _ = host(DisabledValueScopeProbeView(model: model, recorder: recorder))
            pumpRunLoop()

            recorder.clear()
            model.inner.toggle()
            pumpRunLoop()
            recorder.dump("M1_VALUE_DISABLED")

            XCTAssertFalse(recorder.hasAnimation("disabled-value-child"))
            XCTAssertFalse(recorder.hasStamp("disabled-value-child"))
            XCTAssertTrue(
                recorder.matching("disabled-value-child").contains { $0.disablesAnimations }
            )
        }

        func testEmptyTriggerScopeBehavesAsNamedBoundary() {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            _ = host(EmptyTriggerScopeProbeView(model: model, recorder: recorder))
            pumpRunLoop()

            recorder.clear()
            withAnimation(.linear(duration: 0.2)) {
                model.outer.toggle()
            }
            pumpRunLoop()
            recorder.dump("M2_EMPTY_TRIGGER_BOUNDARY")

            XCTAssertFalse(recorder.hasAnimation("empty-trigger-child"))
            XCTAssertFalse(recorder.hasStamp("empty-trigger-child"))
        }

        func testEmptyTriggerScopePreservesAncestorStampWithoutRestoringAnimation() throws {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let proxyBox = ProxyBox()
            _ = host(
                StampedEmptyTriggerScopeProbeView(
                    model: model,
                    recorder: recorder,
                    proxyBox: proxyBox
                )
            )
            pumpRunLoop()

            guard let proxy = proxyBox.proxy else {
                XCTFail("Expected proxy to be captured")
                return
            }

            recorder.clear()
            proxy.animate {
                model.outer.toggle()
            }
            pumpRunLoop()

            XCTAssertFalse(recorder.hasAnimation("stamped-empty-trigger-child"))
            XCTAssertTrue(recorder.hasStampName("stamped-empty-trigger-child", "Outer"))
        }

        func testBarrierStripsExplicitAndImplicitIncomingAnimations() {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            _ = host(BarrierProbeView(model: model, recorder: recorder))
            pumpRunLoop()

            recorder.clear()
            withAnimation(.linear(duration: 0.2)) {
                model.outer.toggle()
            }
            pumpRunLoop()
            recorder.dump("M1_BARRIER_EXPLICIT")
            XCTAssertTrue(recorder.hasAnimation("explicit-control"))
            XCTAssertFalse(recorder.hasAnimation("explicit-barrier"))

            recorder.clear()
            model.inner.toggle()
            pumpRunLoop()
            recorder.dump("M1_BARRIER_IMPLICIT")
            XCTAssertTrue(recorder.hasAnimation("implicit-control"))
            XCTAssertFalse(recorder.hasAnimation("implicit-barrier"))
        }

        func testValueDrivenScopeBlocksAncestorsAndAnimatesItsValueWithStamp() {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            _ = host(ValueScopeProbeView(model: model, recorder: recorder))
            pumpRunLoop()

            recorder.clear()
            withAnimation(.linear(duration: 0.2)) {
                model.outer.toggle()
            }
            pumpRunLoop()
            recorder.dump("M1_VALUE_OUTER")
            XCTAssertFalse(recorder.hasAnimation("value-child"))
            XCTAssertFalse(recorder.hasStamp("value-child"))

            recorder.clear()
            model.inner.toggle()
            pumpRunLoop()
            recorder.dump("M1_VALUE_INNER")
            XCTAssertTrue(recorder.hasAnimation("value-child"))
            XCTAssertTrue(recorder.hasStamp("value-child"))
        }

        func testProxyDrivenScopeStampsWithTransaction() throws {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let proxyBox = ProxyBox()
            _ = host(ProxyScopeProbeView(model: model, recorder: recorder, proxyBox: proxyBox))
            pumpRunLoop()

            guard let proxy = proxyBox.proxy else {
                XCTFail("Expected proxy to be captured")
                return
            }

            recorder.clear()
            proxy.animate {
                model.inner.toggle()
            }
            pumpRunLoop()
            recorder.dump("M1_PROXY")

            XCTAssertTrue(recorder.hasAnimation("proxy-root"))
            XCTAssertTrue(recorder.hasStamp("proxy-root"))
            XCTAssertTrue(recorder.hasAnimation("proxy-child"))
            XCTAssertTrue(recorder.hasStamp("proxy-child"))
        }

        func testNestedScopeBoundaryLetsInnerScopeWin() throws {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let proxyBox = NestedProxyBox()
            _ = host(NestedScopeProbeView(model: model, recorder: recorder, proxyBox: proxyBox))
            pumpRunLoop()

            guard let outerProxy = proxyBox.outerProxy, let innerProxy = proxyBox.innerProxy else {
                XCTFail("Expected both proxies to be captured")
                return
            }

            recorder.clear()
            outerProxy.animate {
                model.outer.toggle()
            }
            pumpRunLoop()
            recorder.dump("M1_NESTED_OUTER")
            XCTAssertFalse(recorder.hasAnimation("nested-inner-child"))

            recorder.clear()
            innerProxy.animate {
                model.inner.toggle()
            }
            pumpRunLoop()
            recorder.dump("M1_NESTED_INNER")
            XCTAssertTrue(recorder.hasAnimation("nested-inner-child"))
            XCTAssertTrue(recorder.hasStamp("nested-inner-child"))
        }

        func testNonNestedValueDrivenScopeKeepsItsValueAnimation() {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            _ = host(NonNestedValueScopeProbeView(model: model, recorder: recorder))
            pumpRunLoop()

            recorder.clear()
            model.outer.toggle()
            pumpRunLoop()
            recorder.dump("M1_NON_NESTED_VALUE_OUTER")

            XCTAssertTrue(recorder.hasAnimation("control-value-child"))
            XCTAssertTrue(recorder.hasStampName("control-value-child", "Control"))
        }

        func testNestedValueDrivenScopeStripsAncestorValueAnimationAtDescendantBoundary() {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            _ = host(NestedValueScopeProbeView(model: model, recorder: recorder))
            pumpRunLoop()

            recorder.clear()
            model.outer.toggle()
            pumpRunLoop()
            recorder.dump("M1_NESTED_VALUE_OUTER")

            XCTAssertFalse(recorder.hasAnimation("nested-value-child"))
            XCTAssertTrue(recorder.hasStampName("nested-value-child", "Outer"))
            XCTAssertTrue(
                recorder.matching("nested-value-child").contains {
                    !$0.hasAnimation && $0.stampName == "Outer"
                        && $0.stampAnimationDescription != nil
                }
            )
        }

        func testInnerProxyDoesNotAnimateOuterScopeRegion() throws {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let proxyBox = NestedProxyBox()
            _ = host(OuterRegionProbeView(model: model, recorder: recorder, proxyBox: proxyBox))
            pumpRunLoop()

            guard let innerProxy = proxyBox.innerProxy else {
                XCTFail("Expected inner proxy to be captured")
                return
            }

            recorder.clear()
            innerProxy.animate {
                model.inner.toggle()
            }
            pumpRunLoop()
            recorder.dump("R1_INNER_PROXY_OUTER_REGION")

            XCTAssertFalse(recorder.hasAnimation("outer-region"))
            XCTAssertTrue(recorder.hasAnimation("inner-region"))
        }

        func testProxyDrivenScopeWorksBelowAnimationBarrier() throws {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let proxyBox = ProxyBox()
            _ = host(
                BarrierBelowProxyProbeView(model: model, recorder: recorder, proxyBox: proxyBox))
            pumpRunLoop()

            guard let proxy = proxyBox.proxy else {
                XCTFail("Expected proxy to be captured")
                return
            }

            recorder.clear()
            proxy.animate {
                model.inner.toggle()
            }
            pumpRunLoop()
            recorder.dump("R1_BARRIER_BELOW_PROXY")

            XCTAssertTrue(recorder.hasAnimation("barrier-proxy-child"))
            XCTAssertTrue(recorder.hasStamp("barrier-proxy-child"))
        }

        func testProxyAnimationOverrideIsUsedWhenBoundaryRestores() throws {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let proxyBox = ProxyBox()
            let overrideAnimation = Animation.easeInOut(duration: 0.73)
            _ = host(OverrideProxyProbeView(model: model, recorder: recorder, proxyBox: proxyBox))
            pumpRunLoop()

            guard let proxy = proxyBox.proxy else {
                XCTFail("Expected proxy to be captured")
                return
            }

            recorder.clear()
            proxy.animate(overrideAnimation) {
                model.inner.toggle()
            }
            pumpRunLoop()
            recorder.dump("R1_PROXY_OVERRIDE")

            XCTAssertTrue(recorder.hasAnimation("override-child"))
            XCTAssertTrue(
                recorder.hasAnimationDescription(
                    "override-child", String(describing: overrideAnimation))
            )
        }

        func testProxyDrivenScopeHonorsDisabledAnimations() throws {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let proxyBox = ProxyBox()
            _ = host(
                DisabledProxyScopeProbeView(model: model, recorder: recorder, proxyBox: proxyBox)
            )
            pumpRunLoop()

            guard let proxy = proxyBox.proxy else {
                XCTFail("Expected proxy to be captured")
                return
            }

            recorder.clear()
            proxy.animate {
                model.inner.toggle()
            }
            pumpRunLoop()
            recorder.dump("M1_PROXY_DISABLED")

            XCTAssertFalse(recorder.hasAnimation("disabled-proxy-child"))
            XCTAssertTrue(
                recorder.matching("disabled-proxy-child").contains { $0.disablesAnimations }
            )
        }

        func testLazyVStackRowsRespectBarrier() {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            _ = host(LazyBarrierProbeView(model: model, recorder: recorder))
            pumpRunLoop()

            recorder.clear()
            withAnimation(.linear(duration: 0.2)) {
                model.items.insert(-1, at: 0)
                _ = model.items.popLast()
            }
            pumpRunLoop()
            recorder.dump("M1_LAZY_BARRIER")

            XCTAssertGreaterThan(recorder.matching("lazy-row").count, 0)
            XCTAssertFalse(recorder.hasAnimation("lazy-row"))
        }

        #if DEBUG
            func testNestedValueDrivenScopeWarnsWhenDescendantBoundaryStripsAncestorAnimation() {
                let model = ProbeModel()
                let recorder = TransactionRecorder()
                let warningRecorder = WarningRecorder()
                defer { AnimationScopeRuntimeWarning.resetForTesting() }

                AnimationScopeRuntimeWarning.resetForTesting()
                AnimationScopeRuntimeWarning.withTestSink(
                    { warningRecorder.record($0) },
                    operation: {
                        _ = host(NestedValueScopeProbeView(model: model, recorder: recorder))
                        pumpRunLoop()

                        recorder.clear()
                        model.outer.toggle()
                        pumpRunLoop()
                        recorder.dump("M1_NESTED_VALUE_WARNING")
                    }
                )

                XCTAssertFalse(recorder.hasAnimation("nested-value-child"))
                XCTAssertEqual(warningRecorder.warnings.count, 1)
                XCTAssertEqual(
                    warningRecorder.warnings.first?.title,
                    "AnimationScope boundary stripped another scope's animation"
                )
                XCTAssertTrue(warningRecorder.warnings.first?.message.contains("Inner") == true)
                XCTAssertTrue(warningRecorder.warnings.first?.message.contains("Outer") == true)
            }

            func testNonNestedValueDrivenScopeDoesNotWarn() {
                let model = ProbeModel()
                let recorder = TransactionRecorder()
                let warningRecorder = WarningRecorder()
                defer { AnimationScopeRuntimeWarning.resetForTesting() }

                AnimationScopeRuntimeWarning.resetForTesting()
                AnimationScopeRuntimeWarning.withTestSink(
                    { warningRecorder.record($0) },
                    operation: {
                        _ = host(NonNestedValueScopeProbeView(model: model, recorder: recorder))
                        pumpRunLoop()

                        recorder.clear()
                        model.outer.toggle()
                        pumpRunLoop()
                        recorder.dump("M1_NON_NESTED_VALUE_NO_WARNING")
                    }
                )

                XCTAssertTrue(recorder.hasAnimation("control-value-child"))
                XCTAssertEqual(warningRecorder.warnings.count, 0)
            }

            func testNestedValueDrivenScopeDoesNotWarnForInnerScopeTrigger() {
                let model = ProbeModel()
                let recorder = TransactionRecorder()
                let warningRecorder = WarningRecorder()
                defer { AnimationScopeRuntimeWarning.resetForTesting() }

                AnimationScopeRuntimeWarning.resetForTesting()
                AnimationScopeRuntimeWarning.withTestSink(
                    { warningRecorder.record($0) },
                    operation: {
                        _ = host(NestedValueScopeProbeView(model: model, recorder: recorder))
                        pumpRunLoop()

                        recorder.clear()
                        model.inner.toggle()
                        pumpRunLoop()
                        recorder.dump("M1_NESTED_VALUE_INNER_NO_WARNING")
                    }
                )

                XCTAssertTrue(recorder.hasAnimation("nested-value-child"))
                XCTAssertTrue(recorder.hasStampName("nested-value-child", "Inner"))
                XCTAssertEqual(warningRecorder.warnings.count, 0)
            }

            func testDetectAnimationLeaksReportsUnscopedAnimationTransactions() {
                let model = ProbeModel()
                let warningRecorder = WarningRecorder()
                defer { AnimationScopeRuntimeWarning.resetForTesting() }

                AnimationScopeRuntimeWarning.resetForTesting()
                AnimationScopeRuntimeWarning.withTestSink(
                    { warningRecorder.record($0) },
                    operation: {
                        _ = host(LeakDetectorProbeView(model: model))
                        pumpRunLoop()

                        withAnimation(.linear(duration: 0.2)) {
                            model.outer.toggle()
                        }
                        pumpRunLoop()
                    }
                )

                XCTAssertEqual(warningRecorder.warnings.count, 1)
                XCTAssertEqual(
                    warningRecorder.warnings.first?.title, "Unscoped animation transaction")
            }

            func testDetectAnimationLeaksIgnoresStampedAnimationTransactions() {
                let model = ProbeModel()
                let proxyBox = ProxyBox()
                let warningRecorder = WarningRecorder()
                defer { AnimationScopeRuntimeWarning.resetForTesting() }

                AnimationScopeRuntimeWarning.resetForTesting()
                AnimationScopeRuntimeWarning.withTestSink(
                    { warningRecorder.record($0) },
                    operation: {
                        _ = host(StampedLeakDetectorProbeView(model: model, proxyBox: proxyBox))
                        pumpRunLoop()

                        guard let proxy = proxyBox.proxy else {
                            XCTFail("Expected proxy to be captured")
                            return
                        }

                        proxy.animate {
                            model.inner.toggle()
                        }
                        pumpRunLoop()
                    }
                )

                XCTAssertTrue(warningRecorder.warnings.isEmpty)
            }

            func testDetectAnimationLeaksDebouncesSameSiteWarnings() {
                let model = ProbeModel()
                let warningRecorder = WarningRecorder()
                defer { AnimationScopeRuntimeWarning.resetForTesting() }

                AnimationScopeRuntimeWarning.resetForTesting()
                AnimationScopeRuntimeWarning.withTestSink(
                    debounceInterval: 10,
                    { warningRecorder.record($0) },
                    operation: {
                        _ = host(LeakDetectorProbeView(model: model))
                        pumpRunLoop()

                        withAnimation(.linear(duration: 0.2)) {
                            model.outer.toggle()
                        }
                        pumpRunLoop()

                        withAnimation(.linear(duration: 0.2)) {
                            model.outer.toggle()
                        }
                        pumpRunLoop()
                    }
                )

                XCTAssertEqual(warningRecorder.warnings.count, 1)
            }

            func testDetectAnimationLeaksDebouncesAcrossSeparateViewInstances() {
                let firstModel = ProbeModel()
                let remountedModel = ProbeModel()
                let warningRecorder = WarningRecorder()
                defer { AnimationScopeRuntimeWarning.resetForTesting() }

                AnimationScopeRuntimeWarning.resetForTesting()
                AnimationScopeRuntimeWarning.withTestSink(
                    debounceInterval: 10,
                    { warningRecorder.record($0) },
                    operation: {
                        _ = host(LeakDetectorProbeView(model: firstModel))
                        pumpRunLoop()

                        withAnimation(.linear(duration: 0.2)) {
                            firstModel.outer.toggle()
                        }
                        pumpRunLoop()

                        _ = host(LeakDetectorProbeView(model: remountedModel))
                        pumpRunLoop()

                        withAnimation(.linear(duration: 0.2)) {
                            remountedModel.outer.toggle()
                        }
                        pumpRunLoop()
                    }
                )

                XCTAssertEqual(warningRecorder.warnings.count, 1)
            }

            func testAnimationBarrierSensorReportsOnlyUnstampedAnimationTransactions() {
                let model = ProbeModel()
                let recorder = TransactionRecorder()
                let proxyBox = ProxyBox()
                let warningRecorder = WarningRecorder()
                defer { AnimationScopeRuntimeWarning.resetForTesting() }

                AnimationScopeRuntimeWarning.resetForTesting()
                AnimationScopeRuntimeWarning.withTestSink(
                    { warningRecorder.record($0) },
                    operation: {
                        _ = host(BarrierSensorProbeView(model: model, warnsOnLeaks: true))
                        pumpRunLoop()

                        withAnimation(.linear(duration: 0.2)) {
                            model.outer.toggle()
                        }
                        pumpRunLoop()

                        _ = host(
                            BarrierBelowProxyProbeView(
                                model: model, recorder: recorder, proxyBox: proxyBox))
                        pumpRunLoop()

                        guard let proxy = proxyBox.proxy else {
                            XCTFail("Expected proxy to be captured")
                            return
                        }

                        proxy.animate {
                            model.inner.toggle()
                        }
                        pumpRunLoop()
                    }
                )

                XCTAssertEqual(warningRecorder.warnings.count, 1)
                XCTAssertEqual(
                    warningRecorder.warnings.first?.title,
                    "Animation barrier stripped an unscoped transaction"
                )
            }

            func testAnimationBarrierSensorCanBeDisabled() {
                let model = ProbeModel()
                let warningRecorder = WarningRecorder()
                defer { AnimationScopeRuntimeWarning.resetForTesting() }

                AnimationScopeRuntimeWarning.resetForTesting()
                AnimationScopeRuntimeWarning.withTestSink(
                    { warningRecorder.record($0) },
                    operation: {
                        _ = host(BarrierSensorProbeView(model: model, warnsOnLeaks: false))
                        pumpRunLoop()

                        withAnimation(.linear(duration: 0.2)) {
                            model.outer.toggle()
                        }
                        pumpRunLoop()
                    }
                )

                XCTAssertTrue(warningRecorder.warnings.isEmpty)
            }
        #endif

        func testMultiTriggerScopeAnimatesFirstTriggerIndependently() {
            let model = MultiTriggerProbeModel()
            let recorder = TransactionRecorder()
            let selectionAnimation = Animation.easeOut(duration: 0.12)
            _ = host(
                MultiTriggerProbeView(
                    model: model,
                    recorder: recorder,
                    selectionAnimation: selectionAnimation,
                    hintAnimation: Animation.spring(response: 0.35, dampingFraction: 0.7)
                )
            )
            pumpRunLoop()

            recorder.clear()
            model.selectedPoints = 1
            pumpRunLoop()
            recorder.dump("M2_MULTI_TRIGGER_SELECTION")

            XCTAssertTrue(recorder.hasAnimation("multi-trigger-child"))
            XCTAssertTrue(recorder.hasStamp("multi-trigger-child"))
            XCTAssertTrue(
                recorder.hasAnimationDescription(
                    "multi-trigger-child",
                    String(describing: selectionAnimation)
                )
            )
        }

        func testMultiTriggerScopeAnimatesSecondTriggerIndependently() {
            let model = MultiTriggerProbeModel()
            let recorder = TransactionRecorder()
            let hintAnimation = Animation.spring(response: 0.35, dampingFraction: 0.7)
            _ = host(
                MultiTriggerProbeView(
                    model: model,
                    recorder: recorder,
                    selectionAnimation: Animation.easeOut(duration: 0.12),
                    hintAnimation: hintAnimation
                )
            )
            pumpRunLoop()

            recorder.clear()
            model.hintPoints = 1
            pumpRunLoop()
            recorder.dump("M2_MULTI_TRIGGER_HINT")

            XCTAssertTrue(recorder.hasAnimation("multi-trigger-child"))
            XCTAssertTrue(recorder.hasStamp("multi-trigger-child"))
            XCTAssertTrue(
                recorder.hasAnimationDescription(
                    "multi-trigger-child",
                    String(describing: hintAnimation)
                )
            )
        }

        func testMultiTriggerScopePrefersFirstTriggerOnSimultaneousChange() {
            let model = MultiTriggerProbeModel()
            let recorder = TransactionRecorder()
            let selectionAnimation = Animation.easeOut(duration: 0.12)
            let hintAnimation = Animation.spring(response: 0.35, dampingFraction: 0.7)
            _ = host(
                MultiTriggerProbeView(
                    model: model,
                    recorder: recorder,
                    selectionAnimation: selectionAnimation,
                    hintAnimation: hintAnimation
                )
            )
            pumpRunLoop()

            recorder.clear()
            model.selectedPoints = 1
            model.hintPoints = 1
            pumpRunLoop()
            recorder.dump("M2_MULTI_TRIGGER_SIMULTANEOUS")

            XCTAssertTrue(
                recorder.hasAnimationDescription(
                    "multi-trigger-child",
                    String(describing: selectionAnimation)
                )
            )
            XCTAssertFalse(
                recorder.hasAnimationDescription(
                    "multi-trigger-child",
                    String(describing: hintAnimation)
                )
            )
        }

        func testMultiTriggerScopeDoesNotAnimateUnrelatedStateChanges() {
            let model = MultiTriggerProbeModel()
            let recorder = TransactionRecorder()
            _ = host(
                MultiTriggerProbeView(
                    model: model,
                    recorder: recorder,
                    selectionAnimation: Animation.easeOut(duration: 0.12),
                    hintAnimation: Animation.spring(response: 0.35, dampingFraction: 0.7)
                )
            )
            pumpRunLoop()

            recorder.clear()
            model.unrelated.toggle()
            pumpRunLoop()
            recorder.dump("M2_MULTI_TRIGGER_UNRELATED")

            XCTAssertFalse(recorder.hasAnimation("multi-trigger-child"))
            XCTAssertFalse(recorder.hasStamp("multi-trigger-child"))
        }

        func testThreeTriggerScopePrefersFirstChangedTrigger() {
            let model = MultiTriggerProbeModel()
            let recorder = TransactionRecorder()
            let selectionAnimation = Animation.easeOut(duration: 0.12)
            let hintAnimation = Animation.spring(response: 0.35, dampingFraction: 0.7)
            let tertiaryAnimation = Animation.linear(duration: 0.91)
            _ = host(
                ThreeTriggerProbeView(
                    model: model,
                    recorder: recorder,
                    selectionAnimation: selectionAnimation,
                    hintAnimation: hintAnimation,
                    tertiaryAnimation: tertiaryAnimation
                )
            )
            pumpRunLoop()

            recorder.clear()
            model.hintPoints = 1
            model.tertiaryPoints = 1
            pumpRunLoop()
            recorder.dump("M2_THREE_TRIGGER_PRIORITY")

            XCTAssertTrue(
                recorder.hasAnimationDescription(
                    "three-trigger-child",
                    String(describing: hintAnimation)
                )
            )
            XCTAssertFalse(
                recorder.hasAnimationDescription(
                    "three-trigger-child",
                    String(describing: tertiaryAnimation)
                )
            )
        }

        func testDynamicTriggerCountPreservesIdentityFromOneToTwo() {
            assertDynamicTriggerIdentity(initialCount: 1, updatedCount: 2)
        }

        func testDynamicTriggerCountPreservesIdentityFromZeroToOne() {
            assertDynamicTriggerIdentity(initialCount: 0, updatedCount: 1)
        }

        func testDynamicTriggerCountPreservesIdentityFromOneToZero() {
            assertDynamicTriggerIdentity(initialCount: 1, updatedCount: 0)
        }

        func testDynamicTriggerCountPreservesIdentityFromTwoToThree() {
            assertDynamicTriggerIdentity(initialCount: 2, updatedCount: 3)
        }

        func testDynamicTriggerCountPreservesIdentityFromThreeToTwo() {
            assertDynamicTriggerIdentity(initialCount: 3, updatedCount: 2)
        }

        func testDynamicTriggerReorderingPreservesIdentityAndUsesNewArrayPriority() {
            let model = DynamicTriggerProbeModel(triggerCount: 3)
            model.first = 1
            model.second = 2
            model.third = 3
            let identityRecorder = ViewIdentityRecorder()
            let transactionRecorder = TransactionRecorder()
            let expectedAnimation = Animation.linear(duration: 0.33)
            _ = host(
                DynamicTriggerProbeView(
                    model: model,
                    identityRecorder: identityRecorder,
                    transactionRecorder: transactionRecorder
                )
            )
            pumpRunLoop()

            transactionRecorder.clear()
            #if DEBUG
                AnimationScopeRuntimeWarning.resetForTesting()
                defer { AnimationScopeRuntimeWarning.resetForTesting() }
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
            transactionRecorder.dump("M2_DYNAMIC_TRIGGER_REORDER")

            XCTAssertEqual(identityRecorder.distinctIdentities.count, 1)
            XCTAssertTrue(
                transactionRecorder.hasAnimationDescription(
                    "dynamic-trigger-child",
                    String(describing: expectedAnimation)
                )
            )
        }

        func testIssue1BoardCaseUsesMultiTriggerScopeForSelectionAndHint() {
            let model = MultiTriggerProbeModel()
            let recorder = TransactionRecorder()
            let selectionAnimation = Animation.easeOut(duration: 0.12)
            let hintAnimation = Animation.spring(response: 0.35, dampingFraction: 0.7)
            _ = host(
                MultiTriggerProbeView(
                    model: model,
                    recorder: recorder,
                    selectionAnimation: selectionAnimation,
                    hintAnimation: hintAnimation
                )
            )
            pumpRunLoop()

            recorder.clear()
            model.selectedPoints = 2
            pumpRunLoop()
            recorder.dump("M2_ISSUE1_SELECTION")
            XCTAssertTrue(
                recorder.hasAnimationDescription(
                    "multi-trigger-child",
                    String(describing: selectionAnimation)
                )
            )

            recorder.clear()
            model.hintPoints = 2
            pumpRunLoop()
            recorder.dump("M2_ISSUE1_HINT")
            XCTAssertTrue(
                recorder.hasAnimationDescription(
                    "multi-trigger-child",
                    String(describing: hintAnimation)
                )
            )
        }

        #if DEBUG
            func testMultiTriggerScopeReportsConflictWarningOnSimultaneousChange() {
                let model = MultiTriggerProbeModel()
                let recorder = TransactionRecorder()
                let warningRecorder = WarningRecorder()
                let selectionAnimation = Animation.easeOut(duration: 0.12)
                let hintAnimation = Animation.spring(response: 0.35, dampingFraction: 0.7)
                defer { AnimationScopeRuntimeWarning.resetForTesting() }

                AnimationScopeRuntimeWarning.resetForTesting()
                AnimationScopeRuntimeWarning.withTestSink(
                    { warningRecorder.record($0) },
                    operation: {
                        _ = host(
                            MultiTriggerProbeView(
                                model: model,
                                recorder: recorder,
                                selectionAnimation: selectionAnimation,
                                hintAnimation: hintAnimation
                            )
                        )
                        pumpRunLoop()

                        recorder.clear()
                        model.selectedPoints = 3
                        model.hintPoints = 3
                        pumpRunLoop()
                        recorder.dump("M2_MULTI_TRIGGER_CONFLICT_WARNING")
                    }
                )

                XCTAssertEqual(warningRecorder.warnings.count, 1)
                XCTAssertEqual(
                    warningRecorder.warnings.first?.title,
                    "AnimationScope multi-trigger conflict"
                )
                XCTAssertTrue(
                    warningRecorder.warnings.first?.message.contains("trigger[0]") == true)
                XCTAssertTrue(
                    warningRecorder.warnings.first?.message.contains("trigger[1]") == true)
                XCTAssertTrue(
                    recorder.hasAnimationDescription(
                        "multi-trigger-child",
                        String(describing: selectionAnimation)
                    )
                )
                XCTAssertTrue(
                    warningRecorder.warnings.first?.message.contains(
                        String(describing: selectionAnimation))
                        == true
                )
                XCTAssertFalse(
                    recorder.hasAnimationDescription(
                        "multi-trigger-child",
                        String(describing: hintAnimation)
                    )
                )
            }
        #endif

        func testValueDrivenScopeRestampsWhenAnimationChangesInsideStampedTransaction() throws {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let proxyBox = ProxyBox()
            let innerAnimation = Animation.easeInOut(duration: 0.45)
            _ = host(
                ValueAttributionProbeView(
                    model: model,
                    recorder: recorder,
                    proxyBox: proxyBox,
                    innerAnimation: innerAnimation
                )
            )
            pumpRunLoop()

            guard let proxy = proxyBox.proxy else {
                XCTFail("Expected proxy to be captured")
                return
            }

            recorder.clear()
            proxy.animate(.linear(duration: 0.2)) {
                model.inner.toggle()
            }
            pumpRunLoop()
            recorder.dump("M2_VALUE_ATTRIBUTION")

            XCTAssertTrue(recorder.hasAnimation("attribution-child"))
            XCTAssertTrue(recorder.hasStampName("attribution-child", "inner-value"))
            XCTAssertTrue(
                recorder.hasStampAnimationDescription(
                    "attribution-child",
                    String(describing: innerAnimation)
                )
            )
        }

        func testValueDrivenScopeRestampsEqualAnimationForInnerScopeOwnership() throws {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let proxyBox = ProxyBox()
            let sharedAnimation = Animation.linear(duration: 0.2)
            _ = host(
                ValueAttributionProbeView(
                    model: model,
                    recorder: recorder,
                    proxyBox: proxyBox,
                    innerAnimation: sharedAnimation
                )
            )
            pumpRunLoop()

            guard let proxy = proxyBox.proxy else {
                XCTFail("Expected proxy to be captured")
                return
            }

            recorder.clear()
            proxy.animate(sharedAnimation) {
                model.inner.toggle()
            }
            pumpRunLoop()
            recorder.dump("M2_EQUAL_ANIMATION_ATTRIBUTION")

            XCTAssertTrue(recorder.hasAnimation("attribution-child"))
            XCTAssertTrue(recorder.hasStampName("attribution-child", "inner-value"))
            XCTAssertTrue(
                recorder.hasStampAnimationDescription(
                    "attribution-child",
                    String(describing: sharedAnimation)
                )
            )
        }

        private func assertDynamicTriggerIdentity(initialCount: Int, updatedCount: Int) {
            let model = DynamicTriggerProbeModel(triggerCount: initialCount)
            let identityRecorder = ViewIdentityRecorder()
            let transactionRecorder = TransactionRecorder()
            _ = host(
                DynamicTriggerProbeView(
                    model: model,
                    identityRecorder: identityRecorder,
                    transactionRecorder: transactionRecorder
                )
            )
            pumpRunLoop()

            transactionRecorder.clear()
            model.triggerCount = updatedCount
            pumpRunLoop()

            XCTAssertEqual(identityRecorder.distinctIdentities.count, 1)
            XCTAssertFalse(transactionRecorder.hasAnimation("dynamic-trigger-child"))
        }
    }

    @MainActor
    private final class ProbeModel: ObservableObject {
        @Published var outer = false
        @Published var inner = false
        @Published var items = Array(0..<12)
    }

    @MainActor
    private final class ProxyBox {
        var proxy: AnimationScopeProxy?
    }

    @MainActor
    private final class NestedProxyBox {
        var outerProxy: AnimationScopeProxy?
        var innerProxy: AnimationScopeProxy?
    }

    #if DEBUG
        private final class WarningRecorder: @unchecked Sendable {
            private let lock = NSLock()
            private var storage: [AnimationScopeWarning] = []

            var warnings: [AnimationScopeWarning] {
                lock.lock()
                defer { lock.unlock() }
                return storage
            }

            func record(_ warning: AnimationScopeWarning) {
                lock.lock()
                defer { lock.unlock() }
                storage.append(warning)
            }
        }
    #endif

    @MainActor
    private struct S7RestoreProbeView: View {
        @ObservedObject var model: ProbeModel
        let recorder: TransactionRecorder

        var body: some View {
            Text("s7")
                .opacity(model.inner ? 0.2 : 1)
                .transaction { recorder.record("s7-child", $0) }
                .transaction { transaction in
                    transaction.animation = .linear(duration: 0.2)
                }
                .transaction { transaction in
                    transaction.animation = nil
                }
        }
    }

    @MainActor
    private struct S8ValueTransactionProbeView: View {
        @ObservedObject var model: ProbeModel
        let recorder: TransactionRecorder

        var body: some View {
            Text("s8")
                .opacity(model.inner ? 0.2 : 1)
                .scaleEffect(model.outer ? 1.2 : 1)
                .transaction { recorder.record("s8-child", $0) }
                .transaction(value: model.inner) { transaction in
                    guard !transaction.disablesAnimations else {
                        return
                    }
                    transaction.animation = .linear(duration: 0.2)
                }
        }
    }

    @MainActor
    private struct TransitionProbeView: View {
        @ObservedObject var model: ProbeModel
        let recorder: TransactionRecorder

        var body: some View {
            AnimationScope(.easeInOut(duration: 0.2), value: model.inner, name: "Transition") {
                VStack {
                    if model.inner {
                        Text("transition")
                            .transition(.opacity)
                    }
                }
                .transaction { recorder.record("transition-container", $0) }
            }
        }
    }

    @MainActor
    private struct DisabledValueScopeProbeView: View {
        @ObservedObject var model: ProbeModel
        let recorder: TransactionRecorder

        var body: some View {
            AnimationScope(.linear(duration: 0.2), value: model.inner, name: "Disabled") {
                Text("disabled-value")
                    .opacity(model.inner ? 0.2 : 1)
                    .transaction { recorder.record("disabled-value-child", $0) }
            }
            .transaction { transaction in
                transaction.disablesAnimations = true
            }
        }
    }

    @MainActor
    private struct EmptyTriggerScopeProbeView: View {
        @ObservedObject var model: ProbeModel
        let recorder: TransactionRecorder

        var body: some View {
            AnimationScope(name: "Empty", triggers: []) {
                Text("empty-trigger")
                    .opacity(model.outer ? 0.2 : 1)
                    .transaction { recorder.record("empty-trigger-child", $0) }
            }
        }
    }

    @MainActor
    private struct StampedEmptyTriggerScopeProbeView: View {
        @ObservedObject var model: ProbeModel
        let recorder: TransactionRecorder
        let proxyBox: ProxyBox

        var body: some View {
            AnimationScope(.linear(duration: 0.2), name: "Outer") { scope in
                AnimationScope(name: "Empty", triggers: []) {
                    Text("stamped-empty-trigger")
                        .opacity(model.outer ? 0.2 : 1)
                        .transaction { recorder.record("stamped-empty-trigger-child", $0) }
                }
                .onAppear { proxyBox.proxy = scope }
            }
        }
    }

    @MainActor
    private struct BarrierProbeView: View {
        @ObservedObject var model: ProbeModel
        let recorder: TransactionRecorder

        var body: some View {
            VStack {
                Text("explicit-control")
                    .opacity(model.outer ? 0.2 : 1)
                    .transaction { recorder.record("explicit-control", $0) }

                Text("explicit-barrier")
                    .opacity(model.outer ? 0.2 : 1)
                    .transaction { recorder.record("explicit-barrier", $0) }
                    .animationBarrier(warnsOnLeaks: false)

                Text("implicit-control")
                    .opacity(model.inner ? 0.2 : 1)
                    .transaction { recorder.record("implicit-control", $0) }
                    .animation(.linear(duration: 0.2), value: model.inner)

                Text("implicit-barrier")
                    .opacity(model.inner ? 0.2 : 1)
                    .transaction { recorder.record("implicit-barrier", $0) }
                    .animationBarrier(warnsOnLeaks: false)
                    .animation(.linear(duration: 0.2), value: model.inner)
            }
        }
    }

    @MainActor
    private struct ValueScopeProbeView: View {
        @ObservedObject var model: ProbeModel
        let recorder: TransactionRecorder

        var body: some View {
            AnimationScope(.snappy(duration: 0.2), value: model.inner) {
                Text("value")
                    .opacity(model.inner ? 0.2 : 1)
                    .scaleEffect(model.outer ? 1.2 : 1)
                    .transaction { recorder.record("value-child", $0) }
            }
        }
    }

    @MainActor
    private struct ProxyScopeProbeView: View {
        @ObservedObject var model: ProbeModel
        let recorder: TransactionRecorder
        let proxyBox: ProxyBox

        var body: some View {
            AnimationScope(.linear(duration: 0.2)) { scope in
                Text("proxy")
                    .opacity(model.inner ? 0.2 : 1)
                    .transaction { recorder.record("proxy-child", $0) }
                    .onAppear { proxyBox.proxy = scope }
            }
            .transaction { recorder.record("proxy-root", $0) }
        }
    }

    @MainActor
    private struct NestedScopeProbeView: View {
        @ObservedObject var model: ProbeModel
        let recorder: TransactionRecorder
        let proxyBox: NestedProxyBox

        var body: some View {
            AnimationScope(.linear(duration: 0.2)) { outerScope in
                AnimationScope(.linear(duration: 0.2)) { innerScope in
                    Text("nested")
                        .opacity(model.inner ? 0.2 : 1)
                        .scaleEffect(model.outer ? 1.2 : 1)
                        .transaction { recorder.record("nested-inner-child", $0) }
                        .onAppear {
                            proxyBox.outerProxy = outerScope
                            proxyBox.innerProxy = innerScope
                        }
                }
            }
        }
    }

    @MainActor
    private struct NonNestedValueScopeProbeView: View {
        @ObservedObject var model: ProbeModel
        let recorder: TransactionRecorder

        var body: some View {
            AnimationScope(.easeOut(duration: 0.12), value: model.outer, name: "Control") {
                Text("control")
                    .opacity(model.outer ? 0.2 : 1)
                    .transaction { recorder.record("control-value-child", $0) }
            }
        }
    }

    @MainActor
    private struct NestedValueScopeProbeView: View {
        @ObservedObject var model: ProbeModel
        let recorder: TransactionRecorder

        var body: some View {
            AnimationScope(.easeOut(duration: 0.12), value: model.outer, name: "Outer") {
                AnimationScope(
                    .spring(response: 0.35, dampingFraction: 0.7), value: model.inner, name: "Inner"
                ) {
                    Text("nested-value")
                        .opacity(model.outer ? 0.2 : (model.inner ? 0.6 : 1))
                        .transaction { recorder.record("nested-value-child", $0) }
                }
            }
        }
    }

    @MainActor
    private struct OuterRegionProbeView: View {
        @ObservedObject var model: ProbeModel
        let recorder: TransactionRecorder
        let proxyBox: NestedProxyBox

        var body: some View {
            AnimationScope(.linear(duration: 0.2)) { outerScope in
                VStack {
                    Text("outer-region")
                        .opacity(model.inner ? 0.2 : 1)
                        .transaction { recorder.record("outer-region", $0) }

                    AnimationScope(.linear(duration: 0.2)) { innerScope in
                        Text("inner-region")
                            .opacity(model.inner ? 0.2 : 1)
                            .transaction { recorder.record("inner-region", $0) }
                            .onAppear {
                                proxyBox.outerProxy = outerScope
                                proxyBox.innerProxy = innerScope
                            }
                    }
                }
            }
        }
    }

    @MainActor
    private struct BarrierBelowProxyProbeView: View {
        @ObservedObject var model: ProbeModel
        let recorder: TransactionRecorder
        let proxyBox: ProxyBox

        var body: some View {
            AnimationScope(.linear(duration: 0.2)) { scope in
                Text("barrier-proxy")
                    .opacity(model.inner ? 0.2 : 1)
                    .transaction { recorder.record("barrier-proxy-child", $0) }
                    .onAppear { proxyBox.proxy = scope }
            }
            .animationBarrier()
        }
    }

    @MainActor
    private struct OverrideProxyProbeView: View {
        @ObservedObject var model: ProbeModel
        let recorder: TransactionRecorder
        let proxyBox: ProxyBox

        var body: some View {
            AnimationScope(.linear(duration: 0.2)) { scope in
                Text("override")
                    .opacity(model.inner ? 0.2 : 1)
                    .transaction { recorder.record("override-child", $0) }
                    .onAppear { proxyBox.proxy = scope }
            }
        }
    }

    @MainActor
    private struct DisabledProxyScopeProbeView: View {
        @ObservedObject var model: ProbeModel
        let recorder: TransactionRecorder
        let proxyBox: ProxyBox

        var body: some View {
            AnimationScope(.linear(duration: 0.2), name: "Disabled proxy") { scope in
                Text("disabled-proxy")
                    .opacity(model.inner ? 0.2 : 1)
                    .transaction { recorder.record("disabled-proxy-child", $0) }
                    .onAppear { proxyBox.proxy = scope }
            }
            .transaction { transaction in
                transaction.disablesAnimations = true
            }
        }
    }

    @MainActor
    private struct LazyBarrierProbeView: View {
        @ObservedObject var model: ProbeModel
        let recorder: TransactionRecorder

        var body: some View {
            ScrollView {
                LazyVStack {
                    ForEach(model.items, id: \.self) { item in
                        Text("row-\(item)")
                            .frame(maxWidth: .infinity)
                            .transaction { recorder.record("lazy-row", $0) }
                    }
                }
            }
            .frame(height: 300)
            .animationBarrier(warnsOnLeaks: false)
        }
    }

    @MainActor
    private struct LeakDetectorProbeView: View {
        @ObservedObject var model: ProbeModel

        var body: some View {
            Text("leak-detector")
                .opacity(model.outer ? 0.2 : 1)
                .detectAnimationLeaks()
        }
    }

    @MainActor
    private struct StampedLeakDetectorProbeView: View {
        @ObservedObject var model: ProbeModel
        let proxyBox: ProxyBox

        var body: some View {
            AnimationScope(.linear(duration: 0.2), name: "leak-scope") { scope in
                Text("stamped-leak-detector")
                    .opacity(model.inner ? 0.2 : 1)
                    .detectAnimationLeaks()
                    .onAppear { proxyBox.proxy = scope }
            }
        }
    }

    @MainActor
    private struct BarrierSensorProbeView: View {
        @ObservedObject var model: ProbeModel
        let warnsOnLeaks: Bool

        var body: some View {
            Text("barrier-sensor")
                .opacity(model.outer ? 0.2 : 1)
                .animationBarrier(warnsOnLeaks: warnsOnLeaks)
        }
    }

    @MainActor
    private final class MultiTriggerProbeModel: ObservableObject {
        @Published var selectedPoints = 0
        @Published var hintPoints = 0
        @Published var tertiaryPoints = 0
        @Published var unrelated = false
    }

    @MainActor
    private final class DynamicTriggerProbeModel: ObservableObject {
        @Published var triggerCount: Int
        @Published var first = 0
        @Published var second = 0
        @Published var third = 0
        @Published var isReversed = false

        init(triggerCount: Int) {
            self.triggerCount = triggerCount
        }
    }

    @MainActor
    private final class ViewIdentityRecorder {
        private(set) var identities: [UUID] = []

        var distinctIdentities: Set<UUID> {
            Set(identities)
        }

        func record(_ identity: UUID) {
            identities.append(identity)
        }
    }

    @MainActor
    private struct MultiTriggerProbeView: View {
        @ObservedObject var model: MultiTriggerProbeModel
        let recorder: TransactionRecorder
        let selectionAnimation: Animation
        let hintAnimation: Animation

        var body: some View {
            AnimationScope(
                name: "Board",
                triggers: [
                    .animation(selectionAnimation, value: model.selectedPoints),
                    .animation(hintAnimation, value: model.hintPoints),
                ]
            ) {
                Text("multi-trigger")
                    .scaleEffect(model.selectedPoints > 0 ? 1.1 : 1)
                    .opacity(model.hintPoints > 0 ? 0.6 : (model.unrelated ? 0.8 : 1))
                    .transaction { recorder.record("multi-trigger-child", $0) }
            }
        }
    }

    @MainActor
    private struct ThreeTriggerProbeView: View {
        @ObservedObject var model: MultiTriggerProbeModel
        let recorder: TransactionRecorder
        let selectionAnimation: Animation
        let hintAnimation: Animation
        let tertiaryAnimation: Animation

        var body: some View {
            AnimationScope(
                name: "Three triggers",
                triggers: [
                    .animation(selectionAnimation, value: model.selectedPoints),
                    .animation(hintAnimation, value: model.hintPoints),
                    .animation(tertiaryAnimation, value: model.tertiaryPoints),
                ]
            ) {
                Text("three-trigger")
                    .scaleEffect(model.selectedPoints > 0 ? 1.1 : 1)
                    .opacity(model.hintPoints > 0 ? 0.6 : 1)
                    .offset(x: model.tertiaryPoints > 0 ? 8 : 0)
                    .transaction { recorder.record("three-trigger-child", $0) }
            }
        }
    }

    @MainActor
    private struct DynamicTriggerProbeView: View {
        @ObservedObject var model: DynamicTriggerProbeModel
        let identityRecorder: ViewIdentityRecorder
        let transactionRecorder: TransactionRecorder

        var body: some View {
            let availableTriggers: [AnimationTrigger] = [
                .animation(.easeOut(duration: 0.11), value: model.first),
                .animation(.easeInOut(duration: 0.22), value: model.second),
                .animation(.linear(duration: 0.33), value: model.third),
            ]
            let orderedTriggers =
                model.isReversed ? Array(availableTriggers.reversed()) : availableTriggers

            AnimationScope(
                name: "Dynamic triggers",
                triggers: Array(orderedTriggers.prefix(model.triggerCount))
            ) {
                StatefulIdentityProbeView(
                    topologyDescription: "\(model.triggerCount)-\(model.isReversed)",
                    identityRecorder: identityRecorder,
                    transactionRecorder: transactionRecorder
                )
            }
        }
    }

    @MainActor
    private struct StatefulIdentityProbeView: View {
        let topologyDescription: String
        let identityRecorder: ViewIdentityRecorder
        let transactionRecorder: TransactionRecorder
        @State private var identity = UUID()

        var body: some View {
            Text("identity-\(topologyDescription)")
                .transaction { transactionRecorder.record("dynamic-trigger-child", $0) }
                .onAppear {
                    identityRecorder.record(identity)
                }
        }
    }

    @MainActor
    private struct ValueAttributionProbeView: View {
        @ObservedObject var model: ProbeModel
        let recorder: TransactionRecorder
        let proxyBox: ProxyBox
        let innerAnimation: Animation

        var body: some View {
            AnimationScope(.linear(duration: 0.2), name: "outer-proxy") { outerScope in
                AnimationScope(innerAnimation, value: model.inner, name: "inner-value") {
                    Text("attribution")
                        .opacity(model.inner ? 0.2 : 1)
                        .transaction { recorder.record("attribution-child", $0) }
                        .onAppear { proxyBox.proxy = outerScope }
                }
            }
        }
    }
#endif
