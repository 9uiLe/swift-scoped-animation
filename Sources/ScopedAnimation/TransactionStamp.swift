import Foundation
import SwiftUI

struct AnimationScopeStamp: Hashable, Sendable {
  let id: UUID
  let name: String?
  let animation: Animation?

  init(id: UUID = UUID(), name: String? = nil, animation: Animation? = nil) {
    self.id = id
    self.name = name
    self.animation = animation
  }

  func named(_ name: String?) -> AnimationScopeStamp {
    AnimationScopeStamp(id: id, name: name, animation: animation)
  }

  func withAnimation(_ animation: Animation?) -> AnimationScopeStamp {
    AnimationScopeStamp(id: id, name: name, animation: animation)
  }

  // Do not compare name or animation: either payload can change without replacing the scope.
  static func == (lhs: AnimationScopeStamp, rhs: AnimationScopeStamp) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

private enum AnimationScopeStampKey: TransactionKey {
  static let defaultValue: AnimationScopeStamp? = nil
}

extension Transaction {
  var animationScopeStamp: AnimationScopeStamp? {
    get { self[AnimationScopeStampKey.self] }
    set { self[AnimationScopeStampKey.self] = newValue }
  }
}
