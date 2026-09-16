#if DEBUG
    @testable import ScopedAnimation
    import Foundation
    import Testing

    @Suite("実行時警告のデバウンス")
    struct RuntimeWarningDebouncerTests {
        @Test("独立した警告箇所は互いを抑制しない")
        func independentSites() {
            var debouncer = RuntimeWarningDebouncer(interval: 10)
            let now = Date(timeIntervalSinceReferenceDate: 100)
            let firstCardReport = debouncer.shouldReport(siteID: "boundary|Card", now: now)
            let menuReport = debouncer.shouldReport(siteID: "boundary|Menu", now: now)
            let repeatedCardReport = debouncer.shouldReport(siteID: "boundary|Card", now: now)

            #expect(firstCardReport)
            #expect(menuReport)
            #expect(!repeatedCardReport)
        }

        @Test("期限切れの項目は除去され、再び報告できる")
        func expiry() {
            var debouncer = RuntimeWarningDebouncer(interval: 1)
            let first = Date(timeIntervalSinceReferenceDate: 100)
            let initialReport = debouncer.shouldReport(siteID: "detector", now: first)
            let debouncedReport = debouncer.shouldReport(
                siteID: "detector",
                now: first.addingTimeInterval(0.5)
            )
            let expiredReport = debouncer.shouldReport(
                siteID: "detector",
                now: first.addingTimeInterval(1.1)
            )

            #expect(initialReport)
            #expect(!debouncedReport)
            #expect(expiredReport)
            #expect(debouncer.entryCount == 1)
        }

        @Test("設定した上限で最も古い箇所を除去する")
        func boundedEviction() {
            var debouncer = RuntimeWarningDebouncer(interval: 10, maximumEntryCount: 2)
            let first = Date(timeIntervalSinceReferenceDate: 100)
            let reportA = debouncer.shouldReport(siteID: "A", now: first)
            let reportB = debouncer.shouldReport(siteID: "B", now: first.addingTimeInterval(1))
            let reportC = debouncer.shouldReport(siteID: "C", now: first.addingTimeInterval(2))

            #expect(reportA)
            #expect(reportB)
            #expect(reportC)
            #expect(debouncer.entryCount == 2)
            let reportEvictedA = debouncer.shouldReport(
                siteID: "A",
                now: first.addingTimeInterval(3)
            )
            #expect(reportEvictedA)
            #expect(debouncer.entryCount == 2)
        }

        @Test("ビューを再マウントしても箇所キーを維持する")
        func stableSiteKey() {
            let first = AnimationScopeRuntimeWarning.Site(
                "AnimationScopeBoundary",
                scopeName: "Card"
            )
            let remounted = AnimationScopeRuntimeWarning.Site(
                "AnimationScopeBoundary",
                scopeName: "Card"
            )

            #expect(first.id == remounted.id)
        }
    }
#endif
