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

struct AnimationTriggerSnapshot: Equatable {
  let values: [AnyEquatable]

  init(triggers: [AnimationTrigger]) {
    self.values = triggers.map(\.value)
  }
}

struct AnimationTriggerResolution: Sendable {
  let adoptedTriggerIndex: Int
  let adoptedAnimation: Animation
  let rejectedTriggerIndices: [Int]
  let rejectedAnimations: [Animation]
}

final class AnimationTriggerHistory {
  private var latestSnapshot: AnimationTriggerSnapshot
  private var latestResolution: AnimationTriggerResolution?

  init(initialSnapshot: AnimationTriggerSnapshot) {
    self.latestSnapshot = initialSnapshot
  }

  func resolve(
    current snapshot: AnimationTriggerSnapshot,
    triggers: [AnimationTrigger]
  ) -> AnimationTriggerResolution? {
    guard snapshot != latestSnapshot else {
      return latestResolution
    }

    let previousSnapshot = latestSnapshot
    latestSnapshot = snapshot

    guard previousSnapshot.values.count == snapshot.values.count else {
      latestResolution = nil
      return nil
    }

    let changedIndices = snapshot.values.indices.filter { index in
      previousSnapshot.values[index] != snapshot.values[index]
    }

    guard let adoptedTriggerIndex = changedIndices.first else {
      latestResolution = nil
      return nil
    }

    let rejectedTriggerIndices = Array(changedIndices.dropFirst())
    let resolution = AnimationTriggerResolution(
      adoptedTriggerIndex: adoptedTriggerIndex,
      adoptedAnimation: triggers[adoptedTriggerIndex].animation,
      rejectedTriggerIndices: rejectedTriggerIndices,
      rejectedAnimations: rejectedTriggerIndices.map { triggers[$0].animation }
    )
    latestResolution = resolution
    return resolution
  }
}

struct AnyEquatable: Equatable {
  private let value: Any
  private let equals: (Any) -> Bool

  init<Value: Equatable>(_ value: Value) {
    self.value = value
    self.equals = { other in
      guard let otherValue = other as? Value else {
        return false
      }
      return value == otherValue
    }
  }

  static func == (lhs: AnyEquatable, rhs: AnyEquatable) -> Bool {
    lhs.equals(rhs.value)
  }
}
