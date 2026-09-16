import Foundation
import SwiftUI
import os

@main
@MainActor
struct ScopedAnimationBenchmarks {
    static func main() {
        #if DEBUG
            let configuration = "DEBUG (-Onone)"
        #else
            let configuration = "RELEASE (-O)"
        #endif
        print(
            "configuration,case,iterations,min_ns_per_operation,median_ns_per_operation,max_ns_per_operation,checksum"
        )

        for count in [1, 2, 8, 64] {
            for changedIndex in [-1, 0, count - 1].uniqued() {
                let first = snapshot(count: count, changedIndex: -1)
                let second = snapshot(count: count, changedIndex: changedIndex)
                let history = AnimationTriggerHistory(initialSnapshot: first)
                measure(
                    configuration, "history/count=\(count)/changed=\(changedIndex)",
                    iterations: 20_000
                ) {
                    resolve(history, first: first, second: second, iterations: $0)
                }
            }
        }

        let collectionsA = collectionSnapshot(revision: 0)
        let collectionsB = collectionSnapshot(revision: 1)
        let collections = AnimationTriggerHistory(initialSnapshot: collectionsA)
        measure(configuration, "history/8x1024-element-arrays/changed=7", iterations: 2_000) {
            resolve(collections, first: collectionsA, second: collectionsB, iterations: $0)
        }

        measure(configuration, "construct-and-compare/two-8-trigger-snapshots", iterations: 20_000)
        { iterations in
            var checksum = 0
            for index in 0..<iterations {
                let first = snapshot(count: 8, changedIndex: index % 8)
                let second = snapshot(count: 8, changedIndex: -1)
                checksum += first == second ? 0 : 1
            }
            return checksum
        }

        #if DEBUG
            let first = snapshot(count: 8, changedIndex: -1)
            let second = AnimationTriggerSnapshot(
                triggers: (0..<8).map {
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: $0 + 100)
                })
            let history = AnimationTriggerHistory(initialSnapshot: first)
            guard let conflict = history.resolve(second) else {
                preconditionFailure("複数トリガーが競合する計測データが必要です")
            }
            for siteCount in [1, 64] {
                let sink = WarningSinkCounter()
                AnimationScopeRuntimeWarning.withTestSink(
                    debounceInterval: 10,
                    { sink.record($0) },
                    operation: {
                        measure(
                            configuration, "suppressed-conflict/sites=\(siteCount)",
                            iterations: 2_000
                        ) {
                            reportConflicts(conflict, siteCount: siteCount, iterations: $0)
                        }
                    }
                )
                precondition(
                    sink.count == siteCount, "各箇所で警告がちょうど 1 回出力される必要があります")
            }
        #endif
    }

    @inline(never)
    private static func snapshot(count: Int, changedIndex: Int) -> AnimationTriggerSnapshot {
        AnimationTriggerSnapshot(
            triggers: (0..<count).map { index in
                .animation(.linear(duration: 0.2), value: index == changedIndex ? 1 : 0)
            })
    }

    @inline(never)
    private static func collectionSnapshot(revision: Int) -> AnimationTriggerSnapshot {
        AnimationTriggerSnapshot(
            triggers: (0..<8).map { index in
                var values = Array(0..<1_024)
                if index == 7 { values[1_023] += revision }
                return .animation(.linear(duration: 0.2), value: values)
            })
    }

    @inline(never)
    private static func resolve(
        _ history: AnimationTriggerHistory,
        first: AnimationTriggerSnapshot,
        second: AnimationTriggerSnapshot,
        iterations: Int
    ) -> Int {
        var checksum = 0
        for index in 0..<iterations {
            let resolution = history.resolve(index.isMultiple(of: 2) ? second : first)
            checksum &+= resolution.map { $0.winner.index + 1 } ?? 0
        }
        return checksum
    }

    private static func measure(
        _ configuration: String, _ name: String, iterations: Int,
        operation: (Int) -> Int
    ) {
        var checksum = operation(100)
        var samples: [Double] = []
        let clock = ContinuousClock()
        for _ in 0..<7 {
            let start = clock.now
            checksum &+= operation(iterations)
            let elapsed = start.duration(to: clock.now).components
            let nanoseconds =
                Double(elapsed.seconds) * 1_000_000_000
                + Double(elapsed.attoseconds) / 1_000_000_000
            samples.append(nanoseconds / Double(iterations))
        }
        let sorted = samples.sorted()
        let statistics = [sorted[0], sorted[3], sorted[6]]
            .map { String(format: "%.1f", $0) }
            .joined(separator: ",")
        print("\(configuration),\(name),\(iterations),\(statistics),\(checksum)")
    }

    #if DEBUG
        @inline(never)
        private static func reportConflicts(
            _ resolution: AnimationTriggerResolution, siteCount: Int, iterations: Int
        ) -> Int {
            for index in 0..<iterations {
                AnimationScopeRuntimeWarning.report(
                    .multiTriggerConflict(
                        scopeName: "Scope \(index % siteCount)", resolution: resolution),
                    now: Date(timeIntervalSinceReferenceDate: 100)
                )
            }
            return iterations
        }
    #endif
}

extension Array where Element: Equatable {
    fileprivate func uniqued() -> [Element] {
        reduce(into: []) { result, element in
            if !result.contains(element) { result.append(element) }
        }
    }
}

#if DEBUG
    private final class WarningSinkCounter: Sendable {
        private let storage = OSAllocatedUnfairLock(initialState: 0)
        var count: Int { storage.withLock { $0 } }
        func record(_ warning: AnimationScopeWarning) {
            precondition(!warning.message.isEmpty)
            storage.withLock { $0 += 1 }
        }
    }
#endif
