import SwiftUI
import Testing

@testable import ScopedAnimation

extension AnimationScopeBehaviorTests {
    @Suite("Assumptions")
    @MainActor
    struct Assumptions {
        @Test
        func transactionHooksCanRestoreAStrippedAnimation() {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let hosted = host(RestoredTransactionProbe(model: model, recorder: recorder))
            defer { hosted.close() }
            pumpRunLoop()

            recorder.clear()
            withAnimation(.linear(duration: 0.2)) {
                model.inner.toggle()
            }
            pumpRunLoop()

            #expect(recorder.hasAnimation("s7-child"))
        }

        @Test
        func valueTransactionHooksAnimateOnlyTheirTrackedValue() {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let hosted = host(ValueTransactionProbe(model: model, recorder: recorder))
            defer { hosted.close() }
            pumpRunLoop()

            recorder.clear()
            model.outer.toggle()
            pumpRunLoop()

            #expect(!recorder.hasAnimation("s8-child"))

            recorder.clear()
            model.inner.toggle()
            pumpRunLoop()

            #expect(recorder.hasAnimation("s8-child"))
        }
    }
}
