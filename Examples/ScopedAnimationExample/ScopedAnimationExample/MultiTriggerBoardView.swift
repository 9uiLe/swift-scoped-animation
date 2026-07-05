import ScopedAnimation
import SwiftUI

struct MultiTriggerBoardView: View {
  @State private var selectedCells: Set<Int> = []
  @State private var hintCells: Set<Int> = []

  private static let presetHints: Set<Int> = [2, 4, 6]
  private static let conflictSelection: Set<Int> = [1, 3, 5]

  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        AnimationScope(
          name: "Board",
          triggers: [
            .animation(.easeOut(duration: 0.12), value: selectedCells),
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: hintCells),
          ]
        ) {
          LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
            spacing: 10
          ) {
            ForEach(0..<9, id: \.self) { index in
              BoardCell(
                index: index,
                isSelected: selectedCells.contains(index),
                isHint: hintCells.contains(index)
              )
              .onTapGesture {
                toggleSelection(for: index)
              }
            }
          }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))

        HStack(spacing: 10) {
          Button("Show hints") {
            toggleHints()
          }
          .buttonStyle(.borderedProminent)

          Button("Select + hint together") {
            applyConflictDemo()
          }
          .buttonStyle(.bordered)
        }

        Button("Reset") {
          selectedCells = []
          hintCells = []
        }
        .buttonStyle(.bordered)

        Text(
          "One AnimationScope drives both selection (easeOut) and hints (spring). "
            + "When both values change in the same transaction, the first trigger in the "
            + "array wins. In DEBUG builds, Xcode logs a multiTriggerConflict warning."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding()
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Multi-Trigger")
  }

  private func toggleSelection(for index: Int) {
    if selectedCells.contains(index) {
      selectedCells.remove(index)
    } else {
      selectedCells.insert(index)
    }
  }

  private func toggleHints() {
    if hintCells == Self.presetHints {
      hintCells = []
    } else {
      hintCells = Self.presetHints
    }
  }

  private func applyConflictDemo() {
    if selectedCells == Self.conflictSelection && hintCells == Self.presetHints {
      selectedCells = [0]
      hintCells = []
    } else {
      selectedCells = Self.conflictSelection
      hintCells = Self.presetHints
    }
  }
}

private struct BoardCell: View {
  let index: Int
  let isSelected: Bool
  let isHint: Bool

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8)
        .fill(isSelected ? Color.blue.opacity(0.85) : Color(.tertiarySystemGroupedBackground))
        .scaleEffect(isSelected ? 1.08 : 1.0)

      RoundedRectangle(cornerRadius: 8)
        .strokeBorder(isHint ? Color.orange : Color.clear, lineWidth: 3)
        .scaleEffect(isHint ? 1.06 : 1.0)
        .offset(y: isHint ? -4 : 0)

      if isHint {
        Image(systemName: "lightbulb.fill")
          .font(.caption)
          .foregroundStyle(.orange)
          .offset(y: isHint ? -10 : 0)
          .scaleEffect(isHint ? 1.15 : 1.0)
      }

      Text("\(index + 1)")
        .font(.headline)
        .foregroundStyle(isSelected ? .white : .primary)
    }
    .frame(height: 72)
  }
}
