#if canImport(SwiftUI)
  @testable import ScopedAnimation
  import SwiftUI
  import XCTest

  #if canImport(UIKit)
    import UIKit
  #elseif canImport(AppKit)
    import AppKit
  #endif

  struct TransactionSnapshot: CustomStringConvertible {
    let sequence: Int
    let label: String
    let hasAnimation: Bool
    let animationDescription: String?
    let stamp: AnimationScopeStamp?
    let stampAnimationDescription: String?
    let disablesAnimations: Bool

    var description: String {
      let stampDescription = stamp == nil ? "nil" : "set"
      let animationDescription = animationDescription ?? "nil"
      let stampAnimationDescription = stampAnimationDescription ?? "nil"
      return "seq=\(sequence) label=\(label) animation=\(hasAnimation) "
        + "animationDescription=\(animationDescription) stamp=\(stampDescription) "
        + "stampAnimationDescription=\(stampAnimationDescription) disables=\(disablesAnimations)"
    }
  }

  @MainActor
  final class TransactionRecorder {
    private(set) var snapshots: [TransactionSnapshot] = []
    private var sequence = 0

    func record(_ label: String, _ transaction: Transaction) {
      sequence += 1
      snapshots.append(
        TransactionSnapshot(
          sequence: sequence,
          label: label,
          hasAnimation: transaction.animation != nil,
          animationDescription: transaction.animation.map { String(describing: $0) },
          stamp: transaction.animationScopeStamp,
          stampAnimationDescription: transaction.animationScopeStamp?.animation.map {
            String(describing: $0)
          },
          disablesAnimations: transaction.disablesAnimations
        )
      )
    }

    func clear() {
      snapshots.removeAll()
    }

    func matching(_ label: String) -> [TransactionSnapshot] {
      snapshots.filter { $0.label == label }
    }

    func hasAnimation(_ label: String) -> Bool {
      matching(label).contains { $0.hasAnimation }
    }

    func hasStamp(_ label: String) -> Bool {
      matching(label).contains { $0.stamp != nil }
    }

    func hasAnimationDescription(_ label: String, _ description: String) -> Bool {
      matching(label).contains { $0.animationDescription == description }
    }

    func distinctStamps(_ label: String) -> Set<AnimationScopeStamp> {
      Set(matching(label).compactMap(\.stamp))
    }

    func dump(_ title: String) {
      print("\(title): \(snapshots.map(\.description).joined(separator: " | "))")
    }
  }

  @MainActor
  func pumpRunLoop(cycles: Int = 6, interval: TimeInterval = 0.03) {
    for _ in 0..<cycles {
      RunLoop.main.run(until: Date().addingTimeInterval(interval))
    }
  }

  #if canImport(UIKit) && !os(watchOS)
    @MainActor
    struct Hosted<Content: View> {
      let window: UIWindow
      let controller: UIHostingController<Content>
    }

    @MainActor
    func host<Content: View>(
      _ content: Content,
      size: CGSize = CGSize(width: 390, height: 844)
    ) -> Hosted<Content> {
      let window = UIWindow(frame: CGRect(origin: .zero, size: size))
      let controller = UIHostingController(rootView: content)
      window.rootViewController = controller
      window.makeKeyAndVisible()
      controller.view.frame = window.bounds
      controller.view.setNeedsLayout()
      controller.view.layoutIfNeeded()
      return Hosted(window: window, controller: controller)
    }
  #elseif canImport(AppKit)
    @MainActor
    struct Hosted<Content: View> {
      let view: NSHostingView<Content>
      let window: NSWindow
    }

    @MainActor
    func host<Content: View>(
      _ content: Content,
      size: CGSize = CGSize(width: 390, height: 844)
    ) -> Hosted<Content> {
      let window = NSWindow(
        contentRect: CGRect(origin: .zero, size: size),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
      )
      let view = NSHostingView(rootView: content)
      view.frame = CGRect(origin: .zero, size: size)
      window.contentView = view
      window.makeKeyAndOrderFront(nil)
      view.needsLayout = true
      view.layoutSubtreeIfNeeded()
      return Hosted(view: view, window: window)
    }
  #endif
#endif
