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
    let stamp: AnimationScopeStamp?
    let disablesAnimations: Bool

    var description: String {
      let stampDescription = stamp == nil ? "nil" : "set"
      return "seq=\(sequence) label=\(label) animation=\(hasAnimation) "
        + "stamp=\(stampDescription) disables=\(disablesAnimations)"
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
          stamp: transaction.animationScopeStamp,
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
