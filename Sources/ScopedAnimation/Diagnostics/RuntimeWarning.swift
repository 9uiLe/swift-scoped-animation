#if DEBUG
    import Foundation
    import OSLog
    import SwiftUI

    enum AnimationScopeRuntimeWarning {
        struct Site: Hashable, Sendable {
            let kind: String
            let scopeName: String?

            init(_ kind: String, scopeName: String? = nil) {
                self.kind = kind
                self.scopeName = scopeName.flatMap { $0.isEmpty ? nil : $0 }
            }

            var id: String {
                guard let scopeName else {
                    return kind
                }
                return "\(kind)|\(scopeName)"
            }
        }

        private struct State {
            var debouncer = RuntimeWarningDebouncer()
            var sink: @Sendable (AnimationScopeWarning) -> Void = defaultSink
        }

        private static let lock = OSAllocatedUnfairLock(initialState: State())

        static func report(_ warning: AnimationScopeWarning, now: Date = Date()) {
            let sink: (@Sendable (AnimationScopeWarning) -> Void)? = lock.withLock { state in
                guard state.debouncer.shouldReport(siteID: warning.siteID, now: now) else {
                    return nil
                }

                return state.sink
            }

            sink?(warning)
        }

        static func withTestSink<R>(
            debounceInterval: TimeInterval = 1,
            maximumSiteCount: Int = 64,
            _ sink: @escaping @Sendable (AnimationScopeWarning) -> Void,
            operation: () throws -> R
        ) rethrows -> R {
            let previous = lock.withLock { state in
                let previous = state
                state = State(
                    debouncer: RuntimeWarningDebouncer(
                        interval: debounceInterval,
                        maximumEntryCount: maximumSiteCount
                    ),
                    sink: sink
                )
                return previous
            }

            defer {
                lock.withLock { state in
                    state = previous
                }
            }

            return try operation()
        }

        private static func defaultSink(_ warning: AnimationScopeWarning) {
            os_log(
                .fault,
                dso: #dsohandle,
                log: OSLog(subsystem: "com.apple.runtime-issues", category: "ScopedAnimation"),
                "%{public}@",
                warning.message
            )
        }
    }

    struct RuntimeWarningDebouncer {
        let interval: TimeInterval
        let maximumEntryCount: Int
        private(set) var lastReportDates: [String: Date] = [:]

        init(interval: TimeInterval = 1, maximumEntryCount: Int = 64) {
            self.interval = max(interval, 0)
            self.maximumEntryCount = max(maximumEntryCount, 1)
        }

        var entryCount: Int {
            lastReportDates.count
        }

        mutating func shouldReport(siteID: String, now: Date) -> Bool {
            lastReportDates = lastReportDates.filter { _, lastReportDate in
                let age = now.timeIntervalSince(lastReportDate)
                return age >= 0 && age < interval
            }

            if lastReportDates[siteID] != nil {
                return false
            }

            if lastReportDates.count >= maximumEntryCount,
                let oldest = lastReportDates.min(by: { lhs, rhs in
                    if lhs.value == rhs.value {
                        return lhs.key < rhs.key
                    }
                    return lhs.value < rhs.value
                })
            {
                lastReportDates.removeValue(forKey: oldest.key)
            }

            lastReportDates[siteID] = now
            return true
        }
    }

    enum AnimationScopeWarning: Equatable, Sendable {
        case unscopedAnimation
        case barrierLeak
        case crossScopeAnimationStrip(strippingScopeName: String?, strippedScopeName: String?)
        case multiTriggerConflict(scopeName: String?, resolution: AnimationTriggerResolution)

        private var site: AnimationScopeRuntimeWarning.Site {
            switch self {
            case .unscopedAnimation:
                .init("detectAnimationLeaks")
            case .barrierLeak:
                .init("animationBarrier")
            case .crossScopeAnimationStrip(let strippingScopeName, _):
                .init("AnimationScopeBoundary", scopeName: strippingScopeName)
            case .multiTriggerConflict(let scopeName, _):
                .init("MultiTriggerConflict", scopeName: scopeName)
            }
        }

        var siteID: String { site.id }

        var title: String {
            switch self {
            case .unscopedAnimation:
                "Unscoped animation transaction"
            case .barrierLeak:
                "Animation barrier stripped an unscoped transaction"
            case .crossScopeAnimationStrip:
                "AnimationScope boundary stripped another scope's animation"
            case .multiTriggerConflict:
                "AnimationScope multi-trigger conflict"
            }
        }

        // A transaction hook can run for every descendant. Formatting before debounce
        // would repeat reflection and string allocation even when the warning is suppressed.
        var message: String {
            switch self {
            case .unscopedAnimation:
                return
                    "ScopedAnimation detected an animation transaction without an AnimationScope stamp at "
                    + "detectAnimationLeaks. Move the animation into AnimationScope or add animationBarrier() "
                    + "near the leaking subtree."
            case .barrierLeak:
                return
                    "animationBarrier() stripped an animation transaction without an AnimationScope stamp. "
                    + "Move the animation into AnimationScope or pass warnsOnLeaks: false when this "
                    + "barrier intentionally silences legacy animation."
            case .crossScopeAnimationStrip(let strippingScopeName, let strippedScopeName):
                let strippingScope = Self.scopeDisplayName(strippingScopeName)
                let strippedScope = Self.scopeDisplayName(strippedScopeName)
                return "AnimationScope \(strippingScope) stripped a stamped animation from "
                    + "AnimationScope \(strippedScope). Nested AnimationScope boundaries block ancestor "
                    + "scope animations. Use sibling scopes for separate subtrees, or "
                    + "`AnimationScope(name:triggers:)` when multiple `(animation, value)` pairs affect "
                    + "the same subtree."
            case .multiTriggerConflict(let scopeName, let resolution):
                let scope = Self.scopeDisplayName(scopeName)
                let adoptedDescription = Self.triggerDescription(resolution.winner)
                let rejectedDescriptions = resolution.rejected
                    .map(Self.triggerDescription)
                    .joined(separator: ", ")
                return "AnimationScope \(scope) resolved a simultaneous trigger change in favor of "
                    + "\(adoptedDescription). Ignored trigger(s): \(rejectedDescriptions). Put the "
                    + "primary motion first in the `triggers` array."
            }
        }

        private static func triggerDescription(_ selection: AnimationTriggerResolution.Selection)
            -> String
        {
            "trigger[\(selection.index)] (\(String(describing: selection.animation)))"
        }

        private static func scopeDisplayName(_ name: String?) -> String {
            guard let name, !name.isEmpty else {
                return "unnamed scope"
            }
            return "\"\(name)\""
        }
    }
#endif
