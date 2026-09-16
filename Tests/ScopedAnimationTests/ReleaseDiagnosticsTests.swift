#if !DEBUG
    import ScopedAnimation
    import SwiftUI
    import Testing

    @MainActor
    @Test("RELEASE の診断修飾子は元のビュー型を保つ")
    func diagnosticModifiersAreStructuralNoOps() {
        let leakDetectorType = String(reflecting: type(of: EmptyView().detectAnimationLeaks()))
        let overlayType = String(reflecting: type(of: EmptyView().animationScopeDebugOverlay()))
        let emptyViewType = String(reflecting: EmptyView.self)

        #expect(leakDetectorType == emptyViewType)
        #expect(overlayType == emptyViewType)
    }
#endif
