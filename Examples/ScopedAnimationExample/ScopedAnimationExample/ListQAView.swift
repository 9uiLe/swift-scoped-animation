import ScopedAnimation
import SwiftUI

struct ListQAView: View {
  @StateObject private var status = ListQAStatus()
  @State private var selectedCheck = ListQACheck.scope
  @State private var scopePulse = false
  @State private var barrierPulse = false
  @State private var reusePulse = false
  @State private var didStartAutomaticRun = false

  private let rows = Array(0..<80)

  var body: some View {
    ScrollViewReader { proxy in
      VStack(spacing: 12) {
        ListQAStatusPanel(status: status)

        Picker("Check", selection: $selectedCheck) {
          ForEach(ListQACheck.allCases) { check in
            Text(check.title).tag(check)
          }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)

        HStack {
          Button("Run selected") {
            Task {
              await run(selectedCheck, proxy: proxy)
            }
          }
          .buttonStyle(.borderedProminent)

          Button("Run all") {
            Task {
              await runAll(proxy: proxy)
            }
          }
          .buttonStyle(.bordered)
        }

        currentList
      }
      .navigationTitle("List QA")
      .task {
        guard ProcessInfo.processInfo.arguments.contains("--auto-list-qa"),
          !didStartAutomaticRun
        else {
          return
        }
        didStartAutomaticRun = true
        await runAll(proxy: proxy)
      }
    }
  }

  @ViewBuilder
  private var currentList: some View {
    switch selectedCheck {
    case .scope:
      AnimationScope(.easeInOut(duration: 0.7), value: scopePulse, name: "List wrapper") {
        List(rows.prefix(18), id: \.self) { row in
          QAListRow(row: row, active: scopePulse, check: .scope, status: status, tint: .blue)
        }
      }
    case .barrier:
      List(rows.prefix(18), id: \.self) { row in
        QAListRow(row: row, active: barrierPulse, check: .barrier, status: status, tint: .red)
          .animationBarrier()
      }
    case .reuse:
      AnimationScope(.easeInOut(duration: 0.7), value: reusePulse, name: "Reuse list") {
        List(rows, id: \.self) { row in
          QAListRow(row: row, active: reusePulse, check: .reuse, status: status, tint: .green)
            .id(row)
        }
      }
    }
  }

  @MainActor
  private func runAll(proxy: ScrollViewProxy) async {
    await run(.scope, proxy: proxy)
    await run(.barrier, proxy: proxy)
    await run(.reuse, proxy: proxy)
  }

  @MainActor
  private func run(_ check: ListQACheck, proxy: ScrollViewProxy) async {
    selectedCheck = check
    status.begin(check)
    try? await Task.sleep(for: .milliseconds(250))

    switch check {
    case .scope:
      scopePulse.toggle()
      try? await Task.sleep(for: .milliseconds(850))
      status.finish(check)
    case .barrier:
      withAnimation(.easeInOut(duration: 0.7)) {
        barrierPulse.toggle()
      }
      try? await Task.sleep(for: .milliseconds(850))
      status.finish(check)
    case .reuse:
      reusePulse.toggle()
      try? await Task.sleep(for: .milliseconds(850))
      withAnimation(.easeInOut(duration: 0.45)) {
        proxy.scrollTo(79, anchor: .bottom)
      }
      try? await Task.sleep(for: .milliseconds(700))
      withAnimation(.easeInOut(duration: 0.45)) {
        proxy.scrollTo(0, anchor: .top)
      }
      try? await Task.sleep(for: .milliseconds(700))
      status.begin(.reuse)
      reusePulse.toggle()
      try? await Task.sleep(for: .milliseconds(850))
      status.finish(check)
    }
  }
}

private enum ListQACheck: String, CaseIterable, Identifiable {
  case scope
  case barrier
  case reuse

  var id: String {
    rawValue
  }

  var title: String {
    switch self {
    case .scope:
      "Scope"
    case .barrier:
      "Barrier"
    case .reuse:
      "Reuse"
    }
  }
}

@MainActor
private final class ListQAStatus: ObservableObject {
  @Published private(set) var scope = ListQAResult()
  @Published private(set) var barrier = ListQAResult()
  @Published private(set) var reuse = ListQAResult()

  private var activeCheck: ListQACheck?

  func begin(_ check: ListQACheck) {
    activeCheck = check
    set(ListQAResult(isRunning: true), for: check)
  }

  func record(_ check: ListQACheck, hasAnimation: Bool) {
    guard activeCheck == check else {
      return
    }

    var result = result(for: check)
    result.observedTransactions += 1
    if hasAnimation {
      result.animatedTransactions += 1
    }
    set(result, for: check)
  }

  func finish(_ check: ListQACheck) {
    var result = result(for: check)
    result.isRunning = false
    result.didRun = true
    switch check {
    case .scope, .reuse:
      result.passed = result.animatedTransactions > 0
    case .barrier:
      result.passed = result.observedTransactions > 0 && result.animatedTransactions == 0
    }
    set(result, for: check)
    activeCheck = nil
  }

  private func result(for check: ListQACheck) -> ListQAResult {
    switch check {
    case .scope:
      scope
    case .barrier:
      barrier
    case .reuse:
      reuse
    }
  }

  private func set(_ result: ListQAResult, for check: ListQACheck) {
    switch check {
    case .scope:
      scope = result
    case .barrier:
      barrier = result
    case .reuse:
      reuse = result
    }
  }
}

private struct ListQAResult {
  var observedTransactions = 0
  var animatedTransactions = 0
  var didRun = false
  var isRunning = false
  var passed = false

  var stateText: String {
    if isRunning {
      "Running"
    } else if !didRun {
      "Ready"
    } else if passed {
      "Pass"
    } else {
      "Check"
    }
  }

  var color: Color {
    if isRunning {
      .orange
    } else if !didRun {
      .secondary
    } else if passed {
      .green
    } else {
      .red
    }
  }
}

private struct ListQAStatusPanel: View {
  @ObservedObject var status: ListQAStatus

  var body: some View {
    HStack(spacing: 8) {
      StatusChip(title: "Scope", result: status.scope)
      StatusChip(title: "Barrier", result: status.barrier)
      StatusChip(title: "Reuse", result: status.reuse)
    }
    .padding(.horizontal)
    .padding(.top, 8)
  }
}

private struct StatusChip: View {
  let title: String
  let result: ListQAResult

  var body: some View {
    VStack(spacing: 6) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(result.stateText)
        .font(.headline)
        .foregroundStyle(result.color)
      Text("\(result.animatedTransactions)/\(result.observedTransactions)")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct QAListRow: View {
  let row: Int
  let active: Bool
  let check: ListQACheck
  @ObservedObject var status: ListQAStatus
  let tint: Color

  var body: some View {
    HStack(spacing: 12) {
      Circle()
        .fill(active ? tint : Color.gray.opacity(0.28))
        .frame(width: active ? 28 : 18, height: active ? 28 : 18)
        .offset(x: active ? 18 : 0)

      VStack(alignment: .leading, spacing: 4) {
        Text("Row \(row)")
          .font(.headline)
        RoundedRectangle(cornerRadius: 3)
          .fill(active ? tint.opacity(0.8) : Color.gray.opacity(0.24))
          .frame(width: active ? 190 : 94, height: 8)
      }

      Spacer()
    }
    .frame(height: 54)
    .transaction { transaction in
      let hasAnimation = transaction.animation != nil
      Task { @MainActor in
        status.record(check, hasAnimation: hasAnimation)
      }
    }
  }
}
