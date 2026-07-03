import Foundation
import SwiftUI

struct AnimationScopeStamp: Hashable, Sendable {
  let id: UUID
  let name: String?
  private let allowedBoundaryIDs: Set<UUID>

  init(id: UUID = UUID(), name: String? = nil, allowedBoundaryIDs: Set<UUID> = []) {
    self.id = id
    self.name = name
    self.allowedBoundaryIDs = allowedBoundaryIDs
  }

  func named(_ name: String?) -> AnimationScopeStamp {
    AnimationScopeStamp(id: id, name: name, allowedBoundaryIDs: allowedBoundaryIDs)
  }

  func allowingBoundaries(_ boundaryIDs: some Sequence<UUID>) -> AnimationScopeStamp {
    AnimationScopeStamp(id: id, name: name, allowedBoundaryIDs: Set(boundaryIDs))
  }

  func isAllowed(through boundary: AnimationScopeStamp) -> Bool {
    allowedBoundaryIDs.contains(boundary.id)
  }

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
