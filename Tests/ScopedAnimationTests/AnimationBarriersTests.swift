import SwiftUI
import Testing

@testable import ScopedAnimation

extension AnimationScopeBehaviorTests {
    @Suite("Barriers")
    @MainActor
    struct Barriers {
        @Test
        func testBarrierStripsExplicitAndImplicitIncomingAnimations() {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let hosted = host(BarrierProbeView(model: model, recorder: recorder))
            defer { hosted.close() }
            pumpRunLoop()

            recorder.clear()
            withAnimation(.linear(duration: 0.2)) {
                model.outer.toggle()
            }
            pumpRunLoop()
            #expect(recorder.hasAnimation("explicit-control"))
            #expect(!recorder.hasAnimation("explicit-barrier"))

            recorder.clear()
            model.inner.toggle()
            pumpRunLoop()
            #expect(recorder.hasAnimation("implicit-control"))
            #expect(!recorder.hasAnimation("implicit-barrier"))
        }

        @Test
        func testLazyVStackRowsRespectBarrier() {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let hosted = host(LazyBarrierProbeView(model: model, recorder: recorder))
            defer { hosted.close() }
            pumpRunLoop()

            recorder.clear()
            withAnimation(.linear(duration: 0.2)) {
                model.items.insert(-1, at: 0)
                _ = model.items.popLast()
            }
            pumpRunLoop()

            #expect(recorder.matching("lazy-row").count > 0)
            #expect(!recorder.hasAnimation("lazy-row"))
        }
    }
}
