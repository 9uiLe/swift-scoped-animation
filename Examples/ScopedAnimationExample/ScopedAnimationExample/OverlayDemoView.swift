import ScopedAnimation
import SwiftUI

struct OverlayDemoView: View {
  @State private var selected = false
  @State private var rawPulse = false
  @State private var didStartAutomaticRun = false

  var body: some View {
    VStack(spacing: 18) {
      AnimationScope(.spring(duration: 0.45), name: "Outer") { scope in
        VStack(spacing: 16) {
          HStack(spacing: 12) {
            OverlayNode(title: "Queue", active: selected, color: .blue)
            OverlayNode(title: "Worker", active: !selected, color: .green)
          }

          AnimationScope(.easeInOut(duration: 0.35), value: selected, name: "Value") {
            HStack(spacing: 8) {
              ForEach(0..<5) { index in
                Circle()
                  .fill(index < (selected ? 5 : 2) ? Color.orange : Color.gray.opacity(0.25))
                  .frame(width: selected ? 24 : 16, height: selected ? 24 : 16)
              }
            }
            .frame(height: 34)
          }

          HStack {
            Button("Scoped") {
              scope.animate {
                selected.toggle()
              }
            }
            .buttonStyle(.borderedProminent)

            Button("Raw") {
              withAnimation(.easeInOut(duration: 0.4)) {
                rawPulse.toggle()
              }
            }
            .buttonStyle(.bordered)
          }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task {
          guard ProcessInfo.processInfo.arguments.contains("--auto-overlay-qa"),
            !didStartAutomaticRun
          else {
            return
          }
          didStartAutomaticRun = true
          try? await Task.sleep(for: .milliseconds(300))
          scope.animate {
            selected.toggle()
          }
          try? await Task.sleep(for: .milliseconds(700))
          withAnimation(.easeInOut(duration: 0.4)) {
            rawPulse.toggle()
          }
        }
      }

      RoundedRectangle(cornerRadius: 8)
        .fill(rawPulse ? Color.red.opacity(0.7) : Color.gray.opacity(0.24))
        .frame(height: rawPulse ? 86 : 46)
        .overlay {
          Text("Raw probe")
            .font(.headline)
            .foregroundStyle(.white)
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Overlay")
    .detectAnimationLeaks()
    .animationScopeDebugOverlay()
  }
}

private struct OverlayNode: View {
  let title: String
  let active: Bool
  let color: Color

  var body: some View {
    VStack(spacing: 10) {
      Image(systemName: active ? "record.circle.fill" : "circle")
        .font(.largeTitle)
        .foregroundStyle(color)
        .scaleEffect(active ? 1.12 : 0.9)

      Text(title)
        .font(.headline)
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
