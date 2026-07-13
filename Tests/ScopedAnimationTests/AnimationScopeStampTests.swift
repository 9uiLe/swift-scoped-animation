import Foundation
import SwiftUI
import Testing

@testable import ScopedAnimation

@Suite("Animation scope stamp identity")
struct AnimationScopeStampTests {
    @Test("Name and animation changes preserve scope identity")
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

    @Test("Different scope identifiers remain distinct with equal payloads")
    func differentIdentifiersRemainDistinct() {
        let first = AnimationScopeStamp(name: "Card", animation: .smooth)
        let second = AnimationScopeStamp(name: "Card", animation: .smooth)

        #expect(first != second)
        #expect(Set([first, second]).count == 2)
    }
}
