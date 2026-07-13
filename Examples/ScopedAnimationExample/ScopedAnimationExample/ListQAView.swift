import Observation
import ScopedAnimation
import SwiftUI
import os

struct ListQAView: View {
  @State private var status = ListQAStatus()
  @State private var selectedCheck = ListQACheck.scope
  @State private var scopePulse = false
  @State private var barrierPulse = false
  @State private var reusePulse = false
  @State private var didStartAutomaticRun = false

  private let rows = 0..<80

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

        ListQARows(
          check: selectedCheck,
          active: selectedPulse,
          rows: rows,
          counters: status.counters
        )
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

  private var selectedPulse: Bool {
    switch selectedCheck {
    case .scope:
      scopePulse
    case .barrier:
      barrierPulse
    case .reuse:
      reusePulse
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
    try? await Task.sleep(for: .milliseconds(250))
    status.begin(check)

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

private enum ListQACheck: String, CaseIterable, Identifiable, Sendable {
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

private struct ListQARows: View {
  let check: ListQACheck
  let active: Bool
  let rows: Range<Int>
  let counters: ListQATransactionCounters

  @ViewBuilder
  var body: some View {
    switch check {
    case .scope:
      AnimationScope(.easeInOut(duration: 0.7), value: active, name: "List wrapper") {
        List(rows.prefix(18), id: \.self) { row in
          QAListRow(
            row: row,
            active: active,
            check: .scope,
            counters: counters,
            tint: .blue
          )
        }
      }
    case .barrier:
      List(rows.prefix(18), id: \.self) { row in
        QAListRow(
          row: row,
          active: active,
          check: .barrier,
          counters: counters,
          tint: .red
        )
        .animationBarrier()
      }
    case .reuse:
      AnimationScope(.easeInOut(duration: 0.7), value: active, name: "Reuse list") {
        List(rows, id: \.self) { row in
          QAListRow(
            row: row,
            active: active,
            check: .reuse,
            counters: counters,
            tint: .green
          )
          .id(row)
        }
      }
    }
  }
}

@MainActor @Observable
private final class ListQAStatus {
  private(set) var scope = ListQAResult()
  private(set) var barrier = ListQAResult()
  private(set) var reuse = ListQAResult()

  @ObservationIgnored let counters = ListQATransactionCounters()

  func begin(_ check: ListQACheck) {
    counters.begin(check)
    set(ListQAResult(isRunning: true), for: check)
  }

  func finish(_ check: ListQACheck) {
    let counts = counters.finish(check)
    var result = result(for: check)
    result.observedTransactions = counts.observedTransactions
    result.animatedTransactions = counts.animatedTransactions
    result.isRunning = false
    result.didRun = true
    switch check {
    case .scope, .reuse:
      result.passed = result.animatedTransactions > 0
    case .barrier:
      result.passed = result.observedTransactions > 0 && result.animatedTransactions == 0
    }
    set(result, for: check)
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

private final class ListQATransactionCounters: Sendable {
  private struct State: Sendable {
    var activeCheck: ListQACheck?
    var observedTransactions = 0
    var animatedTransactions = 0
  }

  private let state = OSAllocatedUnfairLock(initialState: State())

  func begin(_ check: ListQACheck) {
    state.withLock { state in
      state = State(activeCheck: check)
    }
  }

  func record(_ check: ListQACheck, hasAnimation: Bool) {
    state.withLock { state in
      guard state.activeCheck == check else {
        return
      }

      state.observedTransactions += 1
      if hasAnimation {
        state.animatedTransactions += 1
      }
    }
  }

  func finish(_ check: ListQACheck) -> (
    observedTransactions: Int,
    animatedTransactions: Int
  ) {
    state.withLock { state in
      guard state.activeCheck == check else {
        return (0, 0)
      }

      state.activeCheck = nil
      return (state.observedTransactions, state.animatedTransactions)
    }
  }
}

private struct ListQAResult: Equatable {
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
  let status: ListQAStatus

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
  let counters: ListQATransactionCounters
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
      counters.record(check, hasAnimation: transaction.animation != nil)
    }
  }
}
