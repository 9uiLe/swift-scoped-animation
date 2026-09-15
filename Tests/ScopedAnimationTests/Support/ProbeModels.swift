import SwiftUI

@testable import ScopedAnimation

@MainActor
final class ProbeModel: ObservableObject {
    @Published var outer = false
    @Published var inner = false
    @Published var items = Array(0..<12)
}

@MainActor
final class ProxyBox {
    var proxy: AnimationScopeProxy?
}

@MainActor
final class NestedProxyBox {
    var outerProxy: AnimationScopeProxy?
    var innerProxy: AnimationScopeProxy?
}

@MainActor
final class MultiTriggerProbeModel: ObservableObject {
    @Published var selectedPoints = 0
    @Published var hintPoints = 0
    @Published var tertiaryPoints = 0
    @Published var unrelated = false
}

@MainActor
final class DynamicTriggerProbeModel: ObservableObject {
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
final class ViewIdentityRecorder {
    private(set) var identities: [UUID] = []

    var distinctIdentities: Set<UUID> {
        Set(identities)
    }

    func record(_ identity: UUID) {
        identities.append(identity)
    }
}
