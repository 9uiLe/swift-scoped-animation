import SwiftUI

@testable import ScopedAnimation

@MainActor
struct RestoredTransactionProbe: View {
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
struct ValueTransactionProbe: View {
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
struct TransitionProbeView: View {
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
struct DisabledValueScopeProbeView: View {
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
struct EmptyTriggerScopeProbeView: View {
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
struct StampedEmptyTriggerScopeProbeView: View {
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
struct BarrierProbeView: View {
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
struct ValueScopeProbeView: View {
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
struct ProxyScopeProbeView: View {
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
struct NestedScopeProbeView: View {
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
struct NonNestedValueScopeProbeView: View {
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
struct NestedValueScopeProbeView: View {
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
struct OuterRegionProbeView: View {
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
struct BarrierBelowProxyProbeView: View {
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
struct OverrideProxyProbeView: View {
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
struct DisabledProxyScopeProbeView: View {
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
struct LazyBarrierProbeView: View {
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
struct LeakDetectorProbeView: View {
    @ObservedObject var model: ProbeModel

    var body: some View {
        Text("leak-detector")
            .opacity(model.outer ? 0.2 : 1)
            .detectAnimationLeaks()
    }
}

@MainActor
struct StampedLeakDetectorProbeView: View {
    @ObservedObject var model: ProbeModel
    let proxyBox: ProxyBox
    let recorder: TransactionRecorder

    var body: some View {
        AnimationScope(.linear(duration: 0.2), name: "leak-scope") { scope in
            Text("stamped-leak-detector")
                .opacity(model.inner ? 0.2 : 1)
                .transaction { recorder.record("stamped-detector", $0) }
                .detectAnimationLeaks()
                .onAppear { proxyBox.proxy = scope }
        }
    }
}

@MainActor
struct BarrierSensorProbeView: View {
    @ObservedObject var model: ProbeModel
    let warnsOnLeaks: Bool
    let recorder: TransactionRecorder

    var body: some View {
        Text("barrier-sensor")
            .opacity(model.outer ? 0.2 : 1)
            .transaction { recorder.record("barrier-sensor", $0) }
            .animationBarrier(warnsOnLeaks: warnsOnLeaks)
    }
}

@MainActor
struct ValueAttributionProbeView: View {
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
