import SwiftUI

extension View {
  /// Draws debug outlines around animation scope boundaries.
  ///
  /// Use the overlay while tuning scope placement in a sample app or during manual QA.
  ///
  /// ```swift
  /// RootView()
  ///   .animationScopeDebugOverlay()
  /// ```
  public func animationScopeDebugOverlay() -> some View {
    #if DEBUG
      modifier(AnimationScopeDebugOverlayModifier())
    #else
      self
    #endif
  }

  @ViewBuilder
  func animationScopeDebugBoundary(stamp: AnimationScopeStamp) -> some View {
    #if DEBUG
      anchorPreference(key: AnimationScopeBoundaryPreferenceKey.self, value: .bounds) { anchor in
        [AnimationScopeBoundary(id: stamp.id, name: stamp.name, anchor: anchor)]
      }
    #else
      self
    #endif
  }
}

#if DEBUG
  private struct AnimationScopeBoundary: Identifiable {
    let id: UUID
    let name: String?
    let anchor: Anchor<CGRect>

    var label: String {
      name ?? "AnimationScope"
    }

    var color: Color {
      let hash = abs(id.uuidString.hashValue % 360)
      return Color(hue: Double(hash) / 360, saturation: 0.82, brightness: 0.94)
    }
  }

  private struct AnimationScopeBoundaryPreferenceKey: PreferenceKey {
    static let defaultValue: [AnimationScopeBoundary] = []

    static func reduce(
      value: inout [AnimationScopeBoundary],
      nextValue: () -> [AnimationScopeBoundary]
    ) {
      value.append(contentsOf: nextValue())
    }
  }

  private struct AnimationScopeDebugOverlayModifier: ViewModifier {
    func body(content: Content) -> some View {
      content.overlayPreferenceValue(AnimationScopeBoundaryPreferenceKey.self) { boundaries in
        GeometryReader { proxy in
          ForEach(boundaries) { boundary in
            let rect = proxy[boundary.anchor]
            let color = boundary.color

            Rectangle()
              .stroke(color, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
              .overlay(alignment: .topLeading) {
                Text(boundary.label)
                  .font(.caption2)
                  .fontWeight(.semibold)
                  .foregroundStyle(.white)
                  .lineLimit(1)
                  .padding(.horizontal, 5)
                  .padding(.vertical, 2)
                  .background(color)
              }
              .frame(width: max(rect.width, 0), height: max(rect.height, 0))
              .position(x: rect.midX, y: rect.midY)
          }
        }
        .allowsHitTesting(false)
      }
    }
  }
#endif
