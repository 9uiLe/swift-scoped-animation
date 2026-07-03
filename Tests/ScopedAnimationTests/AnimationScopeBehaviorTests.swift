#if canImport(SwiftUI)
  @testable import ScopedAnimation
  import SwiftUI
  import XCTest

  // XCTest is used because these behavioral tests need a platform hosting view/controller
  // lifetime while SwiftUI transactions are pumped on the main actor.
  @MainActor
  final class AnimationScopeBehaviorTests: XCTestCase {
    func testS7TransactionHookCanRestoreAnimationAfterStrip() {
      let model = ProbeModel()
      let recorder = TransactionRecorder()
      _ = host(S7RestoreProbeView(model: model, recorder: recorder))
      pumpRunLoop()

      recorder.clear()
      withAnimation(.linear(duration: 0.2)) {
        model.inner.toggle()
      }
      pumpRunLoop()
      recorder.dump("R1_S7_RESTORE")

      XCTAssertTrue(recorder.hasAnimation("s7-child"))
    }

    func testBarrierStripsExplicitAndImplicitIncomingAnimations() {
      let model = ProbeModel()
      let recorder = TransactionRecorder()
      _ = host(BarrierProbeView(model: model, recorder: recorder))
      pumpRunLoop()

      recorder.clear()
      withAnimation(.linear(duration: 0.2)) {
        model.outer.toggle()
      }
      pumpRunLoop()
      recorder.dump("M1_BARRIER_EXPLICIT")
      XCTAssertTrue(recorder.hasAnimation("explicit-control"))
      XCTAssertFalse(recorder.hasAnimation("explicit-barrier"))

      recorder.clear()
      model.inner.toggle()
      pumpRunLoop()
      recorder.dump("M1_BARRIER_IMPLICIT")
      XCTAssertTrue(recorder.hasAnimation("implicit-control"))
      XCTAssertFalse(recorder.hasAnimation("implicit-barrier"))
    }

    func testValueDrivenScopeBlocksAncestorsAndAnimatesItsValueWithStamp() {
      let model = ProbeModel()
      let recorder = TransactionRecorder()
      _ = host(ValueScopeProbeView(model: model, recorder: recorder))
      pumpRunLoop()

      recorder.clear()
      withAnimation(.linear(duration: 0.2)) {
        model.outer.toggle()
      }
      pumpRunLoop()
      recorder.dump("M1_VALUE_OUTER")
      XCTAssertFalse(recorder.hasAnimation("value-child"))
      XCTAssertFalse(recorder.hasStamp("value-child"))

      recorder.clear()
      model.inner.toggle()
      pumpRunLoop()
      recorder.dump("M1_VALUE_INNER")
      XCTAssertTrue(recorder.hasAnimation("value-child"))
      XCTAssertTrue(recorder.hasStamp("value-child"))
    }

    func testProxyDrivenScopeStampsWithTransaction() throws {
      let model = ProbeModel()
      let recorder = TransactionRecorder()
      let proxyBox = ProxyBox()
      _ = host(ProxyScopeProbeView(model: model, recorder: recorder, proxyBox: proxyBox))
      pumpRunLoop()

      guard let proxy = proxyBox.proxy else {
        XCTFail("Expected proxy to be captured")
        return
      }

      recorder.clear()
      proxy.animate {
        model.inner.toggle()
      }
      pumpRunLoop()
      recorder.dump("M1_PROXY")

      XCTAssertTrue(recorder.hasAnimation("proxy-root"))
      XCTAssertTrue(recorder.hasStamp("proxy-root"))
      XCTAssertTrue(recorder.hasAnimation("proxy-child"))
      XCTAssertTrue(recorder.hasStamp("proxy-child"))
    }

    func testNestedScopeBoundaryLetsInnerScopeWin() throws {
      let model = ProbeModel()
      let recorder = TransactionRecorder()
      let proxyBox = NestedProxyBox()
      _ = host(NestedScopeProbeView(model: model, recorder: recorder, proxyBox: proxyBox))
      pumpRunLoop()

      guard let outerProxy = proxyBox.outerProxy, let innerProxy = proxyBox.innerProxy else {
        XCTFail("Expected both proxies to be captured")
        return
      }

      recorder.clear()
      outerProxy.animate {
        model.outer.toggle()
      }
      pumpRunLoop()
      recorder.dump("M1_NESTED_OUTER")
      XCTAssertFalse(recorder.hasAnimation("nested-inner-child"))

      recorder.clear()
      innerProxy.animate {
        model.inner.toggle()
      }
      pumpRunLoop()
      recorder.dump("M1_NESTED_INNER")
      XCTAssertTrue(recorder.hasAnimation("nested-inner-child"))
      XCTAssertTrue(recorder.hasStamp("nested-inner-child"))
    }

    func testInnerProxyDoesNotAnimateOuterScopeRegion() throws {
      let model = ProbeModel()
      let recorder = TransactionRecorder()
      let proxyBox = NestedProxyBox()
      _ = host(OuterRegionProbeView(model: model, recorder: recorder, proxyBox: proxyBox))
      pumpRunLoop()

      guard let innerProxy = proxyBox.innerProxy else {
        XCTFail("Expected inner proxy to be captured")
        return
      }

      recorder.clear()
      innerProxy.animate {
        model.inner.toggle()
      }
      pumpRunLoop()
      recorder.dump("R1_INNER_PROXY_OUTER_REGION")

      XCTAssertFalse(recorder.hasAnimation("outer-region"))
      XCTAssertTrue(recorder.hasAnimation("inner-region"))
    }

    func testProxyDrivenScopeWorksBelowAnimationBarrier() throws {
      let model = ProbeModel()
      let recorder = TransactionRecorder()
      let proxyBox = ProxyBox()
      _ = host(BarrierBelowProxyProbeView(model: model, recorder: recorder, proxyBox: proxyBox))
      pumpRunLoop()

      guard let proxy = proxyBox.proxy else {
        XCTFail("Expected proxy to be captured")
        return
      }

      recorder.clear()
      proxy.animate {
        model.inner.toggle()
      }
      pumpRunLoop()
      recorder.dump("R1_BARRIER_BELOW_PROXY")

      XCTAssertTrue(recorder.hasAnimation("barrier-proxy-child"))
      XCTAssertTrue(recorder.hasStamp("barrier-proxy-child"))
    }

    func testProxyAnimationOverrideIsUsedWhenBoundaryRestores() throws {
      let model = ProbeModel()
      let recorder = TransactionRecorder()
      let proxyBox = ProxyBox()
      let overrideAnimation = Animation.easeInOut(duration: 0.73)
      _ = host(OverrideProxyProbeView(model: model, recorder: recorder, proxyBox: proxyBox))
      pumpRunLoop()

      guard let proxy = proxyBox.proxy else {
        XCTFail("Expected proxy to be captured")
        return
      }

      recorder.clear()
      proxy.animate(overrideAnimation) {
        model.inner.toggle()
      }
      pumpRunLoop()
      recorder.dump("R1_PROXY_OVERRIDE")

      XCTAssertTrue(recorder.hasAnimation("override-child"))
      XCTAssertTrue(
        recorder.hasAnimationDescription("override-child", String(describing: overrideAnimation))
      )
    }

    func testLazyVStackRowsRespectBarrier() {
      let model = ProbeModel()
      let recorder = TransactionRecorder()
      _ = host(LazyBarrierProbeView(model: model, recorder: recorder))
      pumpRunLoop()

      recorder.clear()
      withAnimation(.linear(duration: 0.2)) {
        model.items.insert(-1, at: 0)
        _ = model.items.popLast()
      }
      pumpRunLoop()
      recorder.dump("M1_LAZY_BARRIER")

      XCTAssertGreaterThan(recorder.matching("lazy-row").count, 0)
      XCTAssertFalse(recorder.hasAnimation("lazy-row"))
    }

    #if DEBUG
      func testDetectAnimationLeaksReportsUnscopedAnimationTransactions() {
        let model = ProbeModel()
        let warningRecorder = WarningRecorder()
        defer { AnimationScopeRuntimeWarning.resetForTesting() }

        AnimationScopeRuntimeWarning.resetForTesting()
        AnimationScopeRuntimeWarning.withTestSink(
          { warningRecorder.record($0) },
          operation: {
            _ = host(LeakDetectorProbeView(model: model))
            pumpRunLoop()

            withAnimation(.linear(duration: 0.2)) {
              model.outer.toggle()
            }
            pumpRunLoop()
          }
        )

        XCTAssertEqual(warningRecorder.warnings.count, 1)
        XCTAssertEqual(warningRecorder.warnings.first?.title, "Unscoped animation transaction")
      }

      func testDetectAnimationLeaksIgnoresStampedAnimationTransactions() {
        let model = ProbeModel()
        let proxyBox = ProxyBox()
        let warningRecorder = WarningRecorder()
        defer { AnimationScopeRuntimeWarning.resetForTesting() }

        AnimationScopeRuntimeWarning.resetForTesting()
        AnimationScopeRuntimeWarning.withTestSink(
          { warningRecorder.record($0) },
          operation: {
            _ = host(StampedLeakDetectorProbeView(model: model, proxyBox: proxyBox))
            pumpRunLoop()

            guard let proxy = proxyBox.proxy else {
              XCTFail("Expected proxy to be captured")
              return
            }

            proxy.animate {
              model.inner.toggle()
            }
            pumpRunLoop()
          }
        )

        XCTAssertTrue(warningRecorder.warnings.isEmpty)
      }

      func testDetectAnimationLeaksDebouncesSameSiteWarnings() {
        let model = ProbeModel()
        let warningRecorder = WarningRecorder()
        defer { AnimationScopeRuntimeWarning.resetForTesting() }

        AnimationScopeRuntimeWarning.resetForTesting()
        AnimationScopeRuntimeWarning.withTestSink(
          debounceInterval: 10,
          { warningRecorder.record($0) },
          operation: {
            _ = host(LeakDetectorProbeView(model: model))
            pumpRunLoop()

            withAnimation(.linear(duration: 0.2)) {
              model.outer.toggle()
            }
            pumpRunLoop()

            withAnimation(.linear(duration: 0.2)) {
              model.outer.toggle()
            }
            pumpRunLoop()
          }
        )

        XCTAssertEqual(warningRecorder.warnings.count, 1)
      }

      func testAnimationBarrierSensorReportsOnlyUnstampedAnimationTransactions() {
        let model = ProbeModel()
        let recorder = TransactionRecorder()
        let proxyBox = ProxyBox()
        let warningRecorder = WarningRecorder()
        defer { AnimationScopeRuntimeWarning.resetForTesting() }

        AnimationScopeRuntimeWarning.resetForTesting()
        AnimationScopeRuntimeWarning.withTestSink(
          { warningRecorder.record($0) },
          operation: {
            _ = host(BarrierSensorProbeView(model: model, warnsOnLeaks: true))
            pumpRunLoop()

            withAnimation(.linear(duration: 0.2)) {
              model.outer.toggle()
            }
            pumpRunLoop()

            _ = host(
              BarrierBelowProxyProbeView(model: model, recorder: recorder, proxyBox: proxyBox))
            pumpRunLoop()

            guard let proxy = proxyBox.proxy else {
              XCTFail("Expected proxy to be captured")
              return
            }

            proxy.animate {
              model.inner.toggle()
            }
            pumpRunLoop()
          }
        )

        XCTAssertEqual(warningRecorder.warnings.count, 1)
        XCTAssertEqual(
          warningRecorder.warnings.first?.title,
          "Animation barrier stripped an unscoped transaction"
        )
      }

      func testAnimationBarrierSensorCanBeDisabled() {
        let model = ProbeModel()
        let warningRecorder = WarningRecorder()
        defer { AnimationScopeRuntimeWarning.resetForTesting() }

        AnimationScopeRuntimeWarning.resetForTesting()
        AnimationScopeRuntimeWarning.withTestSink(
          { warningRecorder.record($0) },
          operation: {
            _ = host(BarrierSensorProbeView(model: model, warnsOnLeaks: false))
            pumpRunLoop()

            withAnimation(.linear(duration: 0.2)) {
              model.outer.toggle()
            }
            pumpRunLoop()
          }
        )

        XCTAssertTrue(warningRecorder.warnings.isEmpty)
      }
    #endif

    func testValueDrivenScopeRestampsWhenAnimationChangesInsideStampedTransaction() throws {
      let model = ProbeModel()
      let recorder = TransactionRecorder()
      let proxyBox = ProxyBox()
      let innerAnimation = Animation.easeInOut(duration: 0.45)
      _ = host(
        ValueAttributionProbeView(
          model: model,
          recorder: recorder,
          proxyBox: proxyBox,
          innerAnimation: innerAnimation
        )
      )
      pumpRunLoop()

      guard let proxy = proxyBox.proxy else {
        XCTFail("Expected proxy to be captured")
        return
      }

      recorder.clear()
      proxy.animate(.linear(duration: 0.2)) {
        model.inner.toggle()
      }
      pumpRunLoop()
      recorder.dump("M2_VALUE_ATTRIBUTION")

      XCTAssertTrue(recorder.hasAnimation("attribution-child"))
      XCTAssertTrue(recorder.hasStampName("attribution-child", "inner-value"))
      XCTAssertTrue(
        recorder.hasStampAnimationDescription(
          "attribution-child",
          String(describing: innerAnimation)
        )
      )
    }
  }

  @MainActor
  private final class ProbeModel: ObservableObject {
    @Published var outer = false
    @Published var inner = false
    @Published var items = Array(0..<12)
  }

  @MainActor
  private final class ProxyBox {
    var proxy: AnimationScopeProxy?
  }

  @MainActor
  private final class NestedProxyBox {
    var outerProxy: AnimationScopeProxy?
    var innerProxy: AnimationScopeProxy?
  }

  #if DEBUG
    private final class WarningRecorder: @unchecked Sendable {
      private let lock = NSLock()
      private var storage: [AnimationScopeWarning] = []

      var warnings: [AnimationScopeWarning] {
        lock.lock()
        defer { lock.unlock() }
        return storage
      }

      func record(_ warning: AnimationScopeWarning) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(warning)
      }
    }
  #endif

  @MainActor
  private struct S7RestoreProbeView: View {
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
  private struct BarrierProbeView: View {
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
  private struct ValueScopeProbeView: View {
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
  private struct ProxyScopeProbeView: View {
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
  private struct NestedScopeProbeView: View {
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
  private struct OuterRegionProbeView: View {
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
  private struct BarrierBelowProxyProbeView: View {
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
  private struct OverrideProxyProbeView: View {
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
  private struct LazyBarrierProbeView: View {
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
  private struct LeakDetectorProbeView: View {
    @ObservedObject var model: ProbeModel

    var body: some View {
      Text("leak-detector")
        .opacity(model.outer ? 0.2 : 1)
        .detectAnimationLeaks()
    }
  }

  @MainActor
  private struct StampedLeakDetectorProbeView: View {
    @ObservedObject var model: ProbeModel
    let proxyBox: ProxyBox

    var body: some View {
      AnimationScope(.linear(duration: 0.2), name: "leak-scope") { scope in
        Text("stamped-leak-detector")
          .opacity(model.inner ? 0.2 : 1)
          .detectAnimationLeaks()
          .onAppear { proxyBox.proxy = scope }
      }
    }
  }

  @MainActor
  private struct BarrierSensorProbeView: View {
    @ObservedObject var model: ProbeModel
    let warnsOnLeaks: Bool

    var body: some View {
      Text("barrier-sensor")
        .opacity(model.outer ? 0.2 : 1)
        .animationBarrier(warnsOnLeaks: warnsOnLeaks)
    }
  }

  @MainActor
  private struct ValueAttributionProbeView: View {
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
#endif
