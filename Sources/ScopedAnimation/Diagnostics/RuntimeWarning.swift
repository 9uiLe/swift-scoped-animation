#if DEBUG
  import Foundation
  import OSLog

  struct AnimationScopeWarning: Equatable, Sendable {
    let siteID: String
    let title: String
    let message: String
  }

  enum AnimationScopeRuntimeWarning {
    struct Site: Hashable, Sendable {
      let id: String
      let name: String

      init(_ name: String, id: String = UUID().uuidString) {
        self.id = id
        self.name = name
      }
    }

    private struct State {
      var lastReportDates: [String: Date] = [:]
      var sink: @Sendable (AnimationScopeWarning) -> Void = defaultSink
      var debounceInterval: TimeInterval = 1
    }

    private static let lock = OSAllocatedUnfairLock(initialState: State())

    static func report(_ warning: AnimationScopeWarning, now: Date = Date()) {
      let sink: (@Sendable (AnimationScopeWarning) -> Void)? = lock.withLock { state in
        if let lastReportDate = state.lastReportDates[warning.siteID],
          now.timeIntervalSince(lastReportDate) < state.debounceInterval
        {
          return nil
        }

        state.lastReportDates[warning.siteID] = now
        return state.sink
      }

      sink?(warning)
    }

    static func withTestSink<R>(
      debounceInterval: TimeInterval = 1,
      _ sink: @escaping @Sendable (AnimationScopeWarning) -> Void,
      operation: () throws -> R
    ) rethrows -> R {
      let previous = lock.withLock { state in
        let previous = state
        state = State(sink: sink, debounceInterval: debounceInterval)
        return previous
      }

      defer {
        lock.withLock { state in
          state = previous
        }
      }

      return try operation()
    }

    static func resetForTesting() {
      lock.withLock { state in
        state = State()
      }
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

  extension AnimationScopeWarning {
    static func unscopedAnimation(site: AnimationScopeRuntimeWarning.Site) -> Self {
      AnimationScopeWarning(
        siteID: site.id,
        title: "Unscoped animation transaction",
        message:
          "ScopedAnimation detected an animation transaction without an AnimationScope stamp at "
          + "\(site.name). Move the animation into AnimationScope or add animationBarrier() "
          + "near the leaking subtree."
      )
    }

    static func barrierLeak(site: AnimationScopeRuntimeWarning.Site) -> Self {
      AnimationScopeWarning(
        siteID: site.id,
        title: "Animation barrier stripped an unscoped transaction",
        message:
          "animationBarrier() stripped an animation transaction without an AnimationScope stamp. "
          + "Move the animation into AnimationScope or pass warnsOnLeaks: false when this "
          + "barrier intentionally silences legacy animation."
      )
    }

    static func crossScopeAnimationStrip(
      site: AnimationScopeRuntimeWarning.Site,
      strippingScopeName: String?,
      strippedScopeName: String?
    ) -> Self {
      let strippingScope = scopeDisplayName(strippingScopeName)
      let strippedScope = scopeDisplayName(strippedScopeName)

      return AnimationScopeWarning(
        siteID: site.id,
        title: "AnimationScope boundary stripped another scope's animation",
        message: "AnimationScope \(strippingScope) stripped a stamped animation from "
          + "AnimationScope \(strippedScope). Nested AnimationScope boundaries block ancestor "
          + "scope animations. Use sibling scopes for separate subtrees; one subtree with "
          + "multiple triggers cannot be represented by nesting."
      )
    }

    private static func scopeDisplayName(_ name: String?) -> String {
      guard let name, !name.isEmpty else {
        return "unnamed scope"
      }
      return "\"\(name)\""
    }
  }
#endif
