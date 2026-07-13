#if !DEBUG
  import ScopedAnimation
  import SwiftUI
  import Testing

  @MainActor
  @Test("Diagnostic modifiers preserve the original view type in RELEASE")
  func diagnosticModifiersAreStructuralNoOps() {
    let leakDetectorType = String(reflecting: type(of: EmptyView().detectAnimationLeaks()))
    let overlayType = String(reflecting: type(of: EmptyView().animationScopeDebugOverlay()))
    let emptyViewType = String(reflecting: EmptyView.self)

    #expect(leakDetectorType == emptyViewType)
    #expect(overlayType == emptyViewType)
  }
#endif
