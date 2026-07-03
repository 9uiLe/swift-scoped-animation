import ScopedAnimation
import SwiftUI

struct BeforeAfterView: View {
  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        ComparisonPanel(mode: .before)
        ComparisonPanel(mode: .after)
      }
      .padding()
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Before / After")
  }
}

private enum ComparisonMode {
  case before
  case after

  var title: String {
    switch self {
    case .before:
      "Before"
    case .after:
      "After"
    }
  }

  var actionTitle: String {
    switch self {
    case .before:
      "Raw update"
    case .after:
      "Scoped update"
    }
  }
}

private struct ComparisonPanel: View {
  let mode: ComparisonMode
  @State private var expanded = false
  @State private var scopeProxy: AnimationScopeProxy?
  @State private var didStartAutomaticRun = false

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text(mode.title)
          .font(.headline)
        Spacer()
        Button(mode.actionTitle) {
          toggle()
        }
        .buttonStyle(.borderedProminent)
      }

      HStack(alignment: .top, spacing: 14) {
        if mode == .before {
          AnimatedCard(expanded: expanded)
        } else {
          AnimationScope(.easeInOut(duration: 0.55), name: "Card") { scope in
            AnimatedCard(expanded: expanded)
              .onAppear {
                scopeProxy = scope
              }
              .onTapGesture {
                scope.animate {
                  expanded.toggle()
                }
              }
          }
        }

        AmbientStatus(expanded: expanded)
          .animationBarrier(warnsOnLeaks: false)
      }
    }
    .padding()
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    .detectAnimationLeaks()
    .task {
      await runAutomaticDemoIfNeeded()
    }
  }

  @MainActor
  private func runAutomaticDemoIfNeeded() async {
    guard ProcessInfo.processInfo.arguments.contains("--auto-compare-demo"),
      !didStartAutomaticRun
    else {
      return
    }

    didStartAutomaticRun = true
    let delay: Duration = mode == .before ? .milliseconds(1_000) : .milliseconds(2_400)
    try? await Task.sleep(for: delay)
    toggle()
  }

  private func toggle() {
    switch mode {
    case .before:
      withAnimation(.easeInOut(duration: 0.55)) {
        expanded.toggle()
      }
    case .after:
      if let scopeProxy {
        scopeProxy.animate {
          expanded.toggle()
        }
      } else {
        expanded.toggle()
      }
    }
  }
}

private struct AnimatedCard: View {
  let expanded: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Image(systemName: expanded ? "bolt.fill" : "bolt")
          .font(.title2)
          .foregroundStyle(.yellow, .orange)
        Text("Pipeline")
          .font(.headline)
      }

      RoundedRectangle(cornerRadius: 4)
        .fill(expanded ? Color.green : Color.blue)
        .frame(width: expanded ? 180 : 116, height: 16)

      RoundedRectangle(cornerRadius: 4)
        .fill(.secondary.opacity(0.24))
        .frame(width: expanded ? 142 : 86, height: 12)
    }
    .padding()
    .frame(width: expanded ? 230 : 170, height: expanded ? 150 : 112, alignment: .topLeading)
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct AmbientStatus: View {
  let expanded: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Status")
        .font(.headline)
      HStack(spacing: 6) {
        ForEach(0..<4) { index in
          Capsule()
            .fill(index < (expanded ? 4 : 2) ? Color.mint : Color.gray.opacity(0.28))
            .frame(width: 12, height: expanded ? 42 : 24)
        }
      }
      Text(expanded ? "Active" : "Idle")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding()
    .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
    .background(Color(.tertiarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
