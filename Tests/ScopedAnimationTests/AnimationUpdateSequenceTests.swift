import SwiftUI
import Testing

@testable import ScopedAnimation

extension AnimationScopeBehaviorTests {
    @Suite("連続更新")
    @MainActor
    struct UpdateSequences {
        @Test("値の変更だけが現在のアニメーションと名前を使って動く")
        func configurationChanges() {
            let model = UpdateModel()
            let recorder = TransactionRecorder()
            let hosted = host(UpdateProbe(model: model, recorder: recorder))
            defer { hosted.close() }
            pumpRunLoop()

            recorder.clear()
            model.value = 1
            pumpRunLoop()
            #expect(recorder.hasAnimation("child", .linear(duration: 0.05)))
            let originalIDs = Set(recorder.matching("child").compactMap { $0.stamp?.id })
            #expect(originalIDs.count == 1)
            #expect(!recorder.hasStamp("root"))

            recorder.clear()
            model.animation = .easeOut(duration: 0.05)
            model.name = "Renamed"
            model.unrelated.toggle()
            pumpRunLoop()
            #expect(!recorder.hasAnimation("child"))
            #expect(!recorder.hasStamp("child"))

            recorder.clear()
            model.value = 2
            pumpRunLoop()
            #expect(recorder.hasAnimation("child", model.animation))
            #expect(recorder.hasScopedAnimation("child", model.animation))
            #expect(recorder.hasStampName("child", "Renamed"))
            #expect(Set(recorder.matching("child").compactMap { $0.stamp?.id }) == originalIDs)
        }

        @Test("無効な更新は比較基準を進め、後からアニメーションを再生しない")
        func disabledUpdate() {
            let model = UpdateModel()
            let recorder = TransactionRecorder()
            let hosted = host(UpdateProbe(model: model, recorder: recorder))
            defer { hosted.close() }
            pumpRunLoop()

            recorder.clear()
            var transaction = Transaction(animation: .spring)
            transaction.disablesAnimations = true
            withTransaction(transaction) { model.value = 1 }
            pumpRunLoop()
            #expect(!recorder.hasAnimation("child"))
            #expect(!recorder.hasStamp("child"))
            #expect(recorder.matching("child").contains { $0.disablesAnimations })

            recorder.clear()
            model.unrelated.toggle()
            pumpRunLoop()
            #expect(!recorder.hasAnimation("child"))
            #expect(!recorder.hasStamp("child"))

            recorder.clear()
            model.value = 0
            pumpRunLoop()
            #expect(recorder.hasAnimation("child", model.animation))
        }

        @Test("入れ子の同時変更には内側の値スコープのスタンプを使う")
        func simultaneousNestedValues() {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let hosted = host(NestedValueScopeProbeView(model: model, recorder: recorder))
            defer { hosted.close() }
            pumpRunLoop()

            recorder.clear()
            model.outer.toggle()
            model.inner.toggle()
            pumpRunLoop()
            let innerAnimation = Animation.spring(response: 0.35, dampingFraction: 0.7)
            #expect(recorder.hasAnimation("nested-value-child", innerAnimation))
            #expect(recorder.hasScopedAnimation("nested-value-child", innerAnimation))
            #expect(recorder.hasStampName("nested-value-child", "Inner"))
        }
    }
}

@MainActor
private final class UpdateModel: ObservableObject {
    @Published var value = 0
    @Published var unrelated = false
    @Published var animation = Animation.linear(duration: 0.05)
    @Published var name = "Original"
}

private struct UpdateProbe: View {
    @ObservedObject var model: UpdateModel
    let recorder: TransactionRecorder

    var body: some View {
        AnimationScope(model.animation, value: model.value, name: model.name) {
            Text(verbatim: "\(model.value)-\(model.unrelated)")
                .opacity(model.value == 0 ? 1 : 0.5)
                .transaction { recorder.record("child", $0) }
        }
        .transaction { recorder.record("root", $0) }
    }
}
