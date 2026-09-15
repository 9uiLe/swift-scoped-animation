import SwiftUI

@testable import ScopedAnimation

@MainActor
struct MultiTriggerProbeView: View {
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
                .opacity(model.hintPoints > 0 ? 0.6 : 1)
                .offset(x: model.unrelated ? 2 : 0)
                .transaction { recorder.record("multi-trigger-child", $0) }
        }
    }
}

@MainActor
struct ThreeTriggerProbeView: View {
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
struct DynamicTriggerProbeView: View {
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
                topologyDescription: "\(model.triggerCount)-\(model.isReversed)-\(model.first)",
                identityRecorder: identityRecorder,
                transactionRecorder: transactionRecorder
            )
        }
    }
}

@MainActor
struct StatefulIdentityProbeView: View {
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
