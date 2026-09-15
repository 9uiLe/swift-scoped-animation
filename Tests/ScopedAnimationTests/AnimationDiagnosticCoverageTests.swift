#if DEBUG
    import SwiftUI
    import Testing
    import os

    @testable import ScopedAnimation

    extension AnimationScopeBehaviorTests {
        @Suite("Diagnostic coverage")
        @MainActor
        struct DiagnosticCoverage {
            @Test("Debounced conflicts do not format their animation descriptions")
            func suppressedConflictFormatting() {
                let counter = AnimationDescriptionCounter()
                let animation = Animation(DescriptionProbeAnimation(counter: counter))
                let resolution = AnimationTriggerResolution(
                    winner: .init(index: 0, animation: animation),
                    rejected: [.init(index: 1, animation: animation)]
                )
                let now = Date(timeIntervalSinceReferenceDate: 100)
                AnimationScopeRuntimeWarning.withTestSink(
                    { _ = $0.message },
                    operation: {
                        AnimationScopeRuntimeWarning.report(
                            .multiTriggerConflict(scopeName: "Probe", resolution: resolution),
                            now: now
                        )
                        let initialCount = counter.count
                        #expect(initialCount > 0)
                        for _ in 0..<10 {
                            AnimationScopeRuntimeWarning.report(
                                .multiTriggerConflict(scopeName: "Probe", resolution: resolution),
                                now: now
                            )
                        }
                        #expect(counter.count == initialCount)
                        AnimationScopeRuntimeWarning.report(
                            .multiTriggerConflict(scopeName: "Probe", resolution: resolution),
                            now: now.addingTimeInterval(2)
                        )
                        #expect(counter.count > initialCount)
                    }
                )
            }

            @Test(
                "Implicit animation is visible only downstream of its source",
                arguments: [false, true])
            func implicitAnimation(downstream: Bool) {
                let model = ProbeModel()
                let transactions = TransactionRecorder()
                let warnings = WarningRecorder()

                AnimationScopeRuntimeWarning.withTestSink(
                    { warnings.record($0) },
                    operation: {
                        let hosted = host(
                            ImplicitLeakProbe(
                                model: model, recorder: transactions, downstream: downstream)
                        )
                        defer { hosted.close() }
                        pumpRunLoop()

                        transactions.clear()
                        model.inner.toggle()
                        pumpRunLoop()

                        #expect(transactions.hasAnimation("child", .linear(duration: 0.1)))
                        #expect(!transactions.hasStamp("child"))
                        #expect(!transactions.hasAnimation("root"))
                    })

                #expect(warnings.warnings.count == (downstream ? 1 : 0))
            }

            @Test("Resizing triggers never reports a conflict, even when all values change")
            func resizedTriggers() {
                let model = DynamicTriggerProbeModel(triggerCount: 2)
                let identities = ViewIdentityRecorder()
                let transactions = TransactionRecorder()
                let warnings = WarningRecorder()

                AnimationScopeRuntimeWarning.withTestSink(
                    { warnings.record($0) },
                    operation: {
                        let hosted = host(
                            DynamicTriggerProbeView(
                                model: model, identityRecorder: identities,
                                transactionRecorder: transactions
                            ))
                        defer { hosted.close() }
                        pumpRunLoop()

                        transactions.clear()
                        model.triggerCount = 3
                        model.first = 1
                        model.second = 1
                        model.third = 1
                        pumpRunLoop()
                        #expect(!transactions.hasAnimation("dynamic-trigger-child"))
                    })

                #expect(warnings.warnings.isEmpty)
            }

            @Test("Warning capture restores the previous sink and debounce state after a throw")
            func warningCaptureRestoresState() {
                enum Failure: Error { case expected }
                let outer = WarningRecorder()
                let inner = WarningRecorder()
                let warning = AnimationScopeWarning.unscopedAnimation
                let now = Date(timeIntervalSinceReferenceDate: 100)

                AnimationScopeRuntimeWarning.withTestSink(
                    { outer.record($0) },
                    operation: {
                        AnimationScopeRuntimeWarning.report(warning, now: now)
                        #expect(throws: Failure.expected) {
                            try AnimationScopeRuntimeWarning.withTestSink(
                                { inner.record($0) },
                                operation: {
                                    AnimationScopeRuntimeWarning.report(warning, now: now)
                                    throw Failure.expected
                                })
                        }
                        AnimationScopeRuntimeWarning.report(warning, now: now)
                        AnimationScopeRuntimeWarning.report(.barrierLeak, now: now)
                    })

                #expect(outer.warnings == [warning, .barrierLeak])
                #expect(inner.warnings == [warning])
            }
        }
    }

    private final class AnimationDescriptionCounter: Sendable {
        private let storage = OSAllocatedUnfairLock(initialState: 0)
        var count: Int { storage.withLock { $0 } }
        func record() { storage.withLock { $0 += 1 } }
    }

    private struct DescriptionProbeAnimation: CustomAnimation, CustomStringConvertible {
        let counter: AnimationDescriptionCounter

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.counter === rhs.counter
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(ObjectIdentifier(counter))
        }

        var description: String {
            counter.record()
            return "DescriptionProbeAnimation"
        }

        func animate<V: VectorArithmetic>(
            value: V, time: TimeInterval, context: inout AnimationContext<V>
        ) -> V? {
            nil
        }
    }

    private struct ImplicitLeakProbe: View {
        @ObservedObject var model: ProbeModel
        let recorder: TransactionRecorder
        let downstream: Bool

        var body: some View {
            Group {
                if downstream {
                    content
                        .detectAnimationLeaks()
                        .animation(.linear(duration: 0.1), value: model.inner)
                } else {
                    content
                        .animation(.linear(duration: 0.1), value: model.inner)
                        .detectAnimationLeaks()
                }
            }
            .transaction { recorder.record("root", $0) }
        }

        private var content: some View {
            Text(verbatim: "\(model.inner)")
                .opacity(model.inner ? 0.5 : 1)
                .transaction { recorder.record("child", $0) }
        }
    }
#endif
