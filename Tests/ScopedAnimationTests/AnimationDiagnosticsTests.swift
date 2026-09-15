#if DEBUG
    import SwiftUI
    import Testing

    @testable import ScopedAnimation

    extension AnimationScopeBehaviorTests {
        @Suite("Diagnostics")
        @MainActor
        struct Diagnostics {
            @Test
            func testNestedValueDrivenScopeWarnsWhenDescendantBoundaryStripsAncestorAnimation() {
                let model = ProbeModel()
                let recorder = TransactionRecorder()
                let warningRecorder = WarningRecorder()

                AnimationScopeRuntimeWarning.withTestSink(
                    { warningRecorder.record($0) },
                    operation: {
                        let hosted = host(
                            NestedValueScopeProbeView(model: model, recorder: recorder))
                        defer { hosted.close() }
                        pumpRunLoop()

                        recorder.clear()
                        model.outer.toggle()
                        pumpRunLoop()
                    }
                )

                #expect(!recorder.hasAnimation("nested-value-child"))
                #expect(warningRecorder.warnings.count == 1)
                #expect(
                    warningRecorder.warnings.first?.title
                        == "AnimationScope boundary stripped another scope's animation")
                #expect(warningRecorder.warnings.first?.message.contains("Inner") == true)
                #expect(warningRecorder.warnings.first?.message.contains("Outer") == true)
            }

            @Test
            func testNonNestedValueDrivenScopeDoesNotWarn() {
                let model = ProbeModel()
                let recorder = TransactionRecorder()
                let warningRecorder = WarningRecorder()

                AnimationScopeRuntimeWarning.withTestSink(
                    { warningRecorder.record($0) },
                    operation: {
                        let hosted = host(
                            NonNestedValueScopeProbeView(model: model, recorder: recorder))
                        defer { hosted.close() }
                        pumpRunLoop()

                        recorder.clear()
                        model.outer.toggle()
                        pumpRunLoop()
                    }
                )

                #expect(recorder.hasAnimation("control-value-child"))
                #expect(warningRecorder.warnings.count == 0)
            }

            @Test
            func testNestedValueDrivenScopeDoesNotWarnForInnerScopeTrigger() {
                let model = ProbeModel()
                let recorder = TransactionRecorder()
                let warningRecorder = WarningRecorder()

                AnimationScopeRuntimeWarning.withTestSink(
                    { warningRecorder.record($0) },
                    operation: {
                        let hosted = host(
                            NestedValueScopeProbeView(model: model, recorder: recorder))
                        defer { hosted.close() }
                        pumpRunLoop()

                        recorder.clear()
                        model.inner.toggle()
                        pumpRunLoop()
                    }
                )

                #expect(recorder.hasAnimation("nested-value-child"))
                #expect(recorder.hasStampName("nested-value-child", "Inner"))
                #expect(warningRecorder.warnings.count == 0)
            }

            @Test
            func testDetectAnimationLeaksReportsUnscopedAnimationTransactions() {
                let model = ProbeModel()
                let warningRecorder = WarningRecorder()

                AnimationScopeRuntimeWarning.withTestSink(
                    { warningRecorder.record($0) },
                    operation: {
                        let hosted = host(LeakDetectorProbeView(model: model))
                        defer { hosted.close() }
                        pumpRunLoop()

                        withAnimation(.linear(duration: 0.2)) {
                            model.outer.toggle()
                        }
                        pumpRunLoop()
                    }
                )

                #expect(warningRecorder.warnings.count == 1)
                #expect(warningRecorder.warnings.first?.title == "Unscoped animation transaction")
            }

            @Test
            func testDetectAnimationLeaksIgnoresStampedAnimationTransactions() throws {
                let model = ProbeModel()
                let recorder = TransactionRecorder()
                let proxyBox = ProxyBox()
                let warningRecorder = WarningRecorder()

                try AnimationScopeRuntimeWarning.withTestSink(
                    { warningRecorder.record($0) },
                    operation: {
                        let hosted = host(
                            StampedLeakDetectorProbeView(
                                model: model, proxyBox: proxyBox, recorder: recorder))
                        defer { hosted.close() }
                        pumpRunLoop()

                        let proxy = try #require(proxyBox.proxy)

                        proxy.animate {
                            model.inner.toggle()
                        }
                        pumpRunLoop()
                    }
                )

                #expect(recorder.hasAnimation("stamped-detector"))
                #expect(recorder.hasStamp("stamped-detector"))
                #expect(warningRecorder.warnings.isEmpty)
            }

            @Test
            func testDetectAnimationLeaksDebouncesSameSiteWarnings() {
                let model = ProbeModel()
                let warningRecorder = WarningRecorder()

                AnimationScopeRuntimeWarning.withTestSink(
                    debounceInterval: 10,
                    { warningRecorder.record($0) },
                    operation: {
                        let hosted = host(LeakDetectorProbeView(model: model))
                        defer { hosted.close() }
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

                #expect(warningRecorder.warnings.count == 1)
            }

            @Test
            func testDetectAnimationLeaksDebouncesAcrossSeparateViewInstances() {
                let firstModel = ProbeModel()
                let remountedModel = ProbeModel()
                let warningRecorder = WarningRecorder()

                AnimationScopeRuntimeWarning.withTestSink(
                    debounceInterval: 10,
                    { warningRecorder.record($0) },
                    operation: {
                        let hosted = host(LeakDetectorProbeView(model: firstModel))
                        defer { hosted.close() }
                        pumpRunLoop()

                        withAnimation(.linear(duration: 0.2)) {
                            firstModel.outer.toggle()
                        }
                        pumpRunLoop()

                        let remounted = host(LeakDetectorProbeView(model: remountedModel))
                        defer { remounted.close() }
                        pumpRunLoop()

                        withAnimation(.linear(duration: 0.2)) {
                            remountedModel.outer.toggle()
                        }
                        pumpRunLoop()
                    }
                )

                #expect(warningRecorder.warnings.count == 1)
            }

            @Test
            func testAnimationBarrierSensorReportsOnlyUnstampedAnimationTransactions() throws {
                let model = ProbeModel()
                let recorder = TransactionRecorder()
                let proxyBox = ProxyBox()
                let warningRecorder = WarningRecorder()

                try AnimationScopeRuntimeWarning.withTestSink(
                    { warningRecorder.record($0) },
                    operation: {
                        let hosted = host(
                            BarrierSensorProbeView(
                                model: model, warnsOnLeaks: true, recorder: recorder))
                        defer { hosted.close() }
                        pumpRunLoop()

                        withAnimation(.linear(duration: 0.2)) {
                            model.outer.toggle()
                        }
                        pumpRunLoop()

                        let remounted = host(
                            BarrierBelowProxyProbeView(
                                model: model, recorder: recorder, proxyBox: proxyBox))
                        defer { remounted.close() }
                        pumpRunLoop()

                        let proxy = try #require(proxyBox.proxy)

                        proxy.animate {
                            model.inner.toggle()
                        }
                        pumpRunLoop()
                    }
                )

                #expect(warningRecorder.warnings.count == 1)
                #expect(
                    warningRecorder.warnings.first?.title
                        == "Animation barrier stripped an unscoped transaction")
            }

            @Test
            func testAnimationBarrierSensorCanBeDisabled() {
                let model = ProbeModel()
                let recorder = TransactionRecorder()
                let warningRecorder = WarningRecorder()

                AnimationScopeRuntimeWarning.withTestSink(
                    { warningRecorder.record($0) },
                    operation: {
                        let hosted = host(
                            BarrierSensorProbeView(
                                model: model, warnsOnLeaks: false, recorder: recorder))
                        defer { hosted.close() }
                        pumpRunLoop()
                        recorder.clear()

                        withAnimation(.linear(duration: 0.2)) {
                            model.outer.toggle()
                        }
                        pumpRunLoop()
                    }
                )

                #expect(!recorder.hasAnimation("barrier-sensor"))
                #expect(warningRecorder.warnings.isEmpty)
            }

            @Test
            func testMultiTriggerScopeReportsConflictWarningOnSimultaneousChange() {
                let model = MultiTriggerProbeModel()
                let recorder = TransactionRecorder()
                let warningRecorder = WarningRecorder()
                let selectionAnimation = Animation.easeOut(duration: 0.12)
                let hintAnimation = Animation.spring(response: 0.35, dampingFraction: 0.7)

                AnimationScopeRuntimeWarning.withTestSink(
                    { warningRecorder.record($0) },
                    operation: {
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
                        model.selectedPoints = 3
                        model.hintPoints = 3
                        pumpRunLoop()
                    }
                )

                #expect(warningRecorder.warnings.count == 1)
                #expect(
                    warningRecorder.warnings.first?.title == "AnimationScope multi-trigger conflict"
                )
                #expect(warningRecorder.warnings.first?.message.contains("trigger[0]") == true)
                #expect(warningRecorder.warnings.first?.message.contains("trigger[1]") == true)
                #expect(recorder.hasAnimation("multi-trigger-child", selectionAnimation))
                #expect(
                    warningRecorder.warnings.first?.message.contains(
                        String(describing: selectionAnimation))
                        == true)
                #expect(!recorder.hasAnimation("multi-trigger-child", hintAnimation))
            }
        }
    }
#endif
