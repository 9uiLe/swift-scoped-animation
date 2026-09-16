import SwiftUI
import Testing

@testable import ScopedAnimation

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

struct TransactionSnapshot: CustomStringConvertible {
    let label: String
    let animation: Animation?
    let stamp: AnimationScopeStamp?
    let disablesAnimations: Bool

    var hasAnimation: Bool { animation != nil }
    var stampName: String? { stamp?.name }

    var description: String {
        "\(label): animation=\(String(describing: animation)), "
            + "stamp=\(String(describing: stamp)), disablesAnimations=\(disablesAnimations)"
    }
}

@MainActor
final class TransactionRecorder {
    private(set) var snapshots: [TransactionSnapshot] = []

    func record(_ label: String, _ transaction: Transaction) {
        snapshots.append(
            TransactionSnapshot(
                label: label,
                animation: transaction.animation,
                stamp: transaction.animationScopeStamp,
                disablesAnimations: transaction.disablesAnimations
            )
        )
    }

    func clear() {
        snapshots.removeAll()
    }

    func matching(
        _ label: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> [TransactionSnapshot] {
        let matches = snapshots.filter { $0.label == label }
        #expect(
            !matches.isEmpty,
            "\(label) にトランザクションが届きませんでした。観測結果: \(snapshots)",
            sourceLocation: sourceLocation
        )
        return matches
    }

    func hasAnimation(
        _ label: String, sourceLocation: SourceLocation = #_sourceLocation
    ) -> Bool {
        matching(label, sourceLocation: sourceLocation).contains { $0.hasAnimation }
    }

    func hasAnimation(
        _ label: String, _ animation: Animation,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> Bool {
        matching(label, sourceLocation: sourceLocation).contains { $0.animation == animation }
    }

    func hasStamp(
        _ label: String, sourceLocation: SourceLocation = #_sourceLocation
    ) -> Bool {
        matching(label, sourceLocation: sourceLocation).contains { $0.stamp != nil }
    }

    func hasStampName(
        _ label: String, _ name: String, sourceLocation: SourceLocation = #_sourceLocation
    ) -> Bool {
        matching(label, sourceLocation: sourceLocation).contains { $0.stampName == name }
    }

    func hasScopedAnimation(
        _ label: String, _ animation: Animation,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> Bool {
        matching(label, sourceLocation: sourceLocation).contains {
            $0.stamp?.animation == animation
        }
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

        func close() {
            window.isHidden = true
            window.rootViewController = nil
        }
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

        func close() {
            window.contentView = nil
            window.close()
        }
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
        window.isReleasedWhenClosed = false
        let view = NSHostingView(rootView: content)
        view.frame = CGRect(origin: .zero, size: size)
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        return Hosted(view: view, window: window)
    }
#endif
