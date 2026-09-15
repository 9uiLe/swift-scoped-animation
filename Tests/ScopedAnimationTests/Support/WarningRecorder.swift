#if DEBUG
    import os

    @testable import ScopedAnimation

    final class WarningRecorder: Sendable {
        private let storage = OSAllocatedUnfairLock(initialState: [AnimationScopeWarning]())

        var warnings: [AnimationScopeWarning] {
            storage.withLock { $0 }
        }

        func record(_ warning: AnimationScopeWarning) {
            storage.withLock { $0.append(warning) }
        }
    }
#endif
