import Foundation
import SwiftUI
import Testing

@testable import ScopedAnimation

@Suite("スタンプの同一性")
struct AnimationScopeStampTests {
    @Test("名前とアニメーションの変更はスコープの同一性を保つ")
    func payloadChangesPreserveIdentity() {
        let id = UUID()
        let original = AnimationScopeStamp(
            id: id,
            name: "Original",
            animation: .linear(duration: 0.1)
        )
        let updated = AnimationScopeStamp(
            id: id,
            name: "Updated",
            animation: .spring(duration: 0.4)
        )

        #expect(original == updated)
        #expect(Set([original, updated]).count == 1)
    }

    @Test("内容が等しくても異なるスコープ ID は区別する")
    func differentIdentifiersRemainDistinct() {
        let first = AnimationScopeStamp(name: "Card", animation: .smooth)
        let second = AnimationScopeStamp(name: "Card", animation: .smooth)

        #expect(first != second)
        #expect(Set([first, second]).count == 2)
    }
}
