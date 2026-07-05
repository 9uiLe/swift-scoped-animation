import SwiftUI

/// A value-driven animation trigger for ``AnimationScope``.
///
/// Create triggers with ``animation(_:value:)`` and pass them to
/// ``AnimationScope/init(name:triggers:content:)``.
///
/// ```swift
/// AnimationScope(
///   name: "Board",
///   triggers: [
///     .animation(.easeOut(duration: 0.12), value: selectedPoints),
///     .animation(.spring(response: 0.35, dampingFraction: 0.7), value: hintPoints),
///   ]
/// ) {
///   BoardView()
/// }
/// ```
public struct AnimationTrigger {
  let animation: Animation
  let value: AnyEquatable

  /// Creates a trigger that animates when `value` changes.
  public static func animation(_ animation: Animation, value: some Equatable) -> AnimationTrigger {
    AnimationTrigger(animation: animation, value: AnyEquatable(value))
  }
}
