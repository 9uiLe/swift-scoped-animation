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
    private let value: AnyEquatable

    func hasSameValue(as other: Self) -> Bool {
        value == other.value
    }

    /// Creates a trigger that animates when `value` changes.
    public static func animation(_ animation: Animation, value: some Equatable) -> AnimationTrigger
    {
        AnimationTrigger(animation: animation, value: AnyEquatable(value))
    }
}

private struct AnyEquatable: Equatable {
    private let type: ObjectIdentifier
    private let value: Any
    private let equals: (Any) -> Bool

    init<Value: Equatable>(_ value: Value) {
        self.type = ObjectIdentifier(Value.self)
        self.value = value
        self.equals = { other in
            guard let otherValue = other as? Value else {
                return false
            }
            return value == otherValue
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.type == rhs.type && lhs.equals(rhs.value)
    }
}
