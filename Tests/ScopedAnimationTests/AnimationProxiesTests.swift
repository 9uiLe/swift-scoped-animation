import SwiftUI
import Testing

@testable import ScopedAnimation

extension AnimationScopeBehaviorTests {
    @Suite("プロキシ")
    @MainActor
    struct Proxies {
        @Test
        func testProxyDrivenScopeStampsWithTransaction() throws {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let proxyBox = ProxyBox()
            let hosted = host(
                ProxyScopeProbeView(model: model, recorder: recorder, proxyBox: proxyBox))
            defer { hosted.close() }
            pumpRunLoop()

            let proxy = try #require(proxyBox.proxy)

            recorder.clear()
            proxy.animate {
                model.inner.toggle()
            }
            pumpRunLoop()

            #expect(recorder.hasAnimation("proxy-root"))
            #expect(recorder.hasStamp("proxy-root"))
            #expect(recorder.hasAnimation("proxy-child"))
            #expect(recorder.hasStamp("proxy-child"))
        }

        @Test
        func testNestedScopeBoundaryLetsInnerScopeWin() throws {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let proxyBox = NestedProxyBox()
            let hosted = host(
                NestedScopeProbeView(model: model, recorder: recorder, proxyBox: proxyBox))
            defer { hosted.close() }
            pumpRunLoop()

            let outerProxy = try #require(proxyBox.outerProxy)
            let innerProxy = try #require(proxyBox.innerProxy)

            recorder.clear()
            outerProxy.animate {
                model.outer.toggle()
            }
            pumpRunLoop()
            #expect(!recorder.hasAnimation("nested-inner-child"))

            recorder.clear()
            innerProxy.animate {
                model.inner.toggle()
            }
            pumpRunLoop()
            #expect(recorder.hasAnimation("nested-inner-child"))
            #expect(recorder.hasStamp("nested-inner-child"))
        }

        @Test
        func testInnerProxyDoesNotAnimateOuterScopeRegion() throws {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let proxyBox = NestedProxyBox()
            let hosted = host(
                OuterRegionProbeView(model: model, recorder: recorder, proxyBox: proxyBox))
            defer { hosted.close() }
            pumpRunLoop()

            let innerProxy = try #require(proxyBox.innerProxy)

            recorder.clear()
            innerProxy.animate {
                model.inner.toggle()
            }
            pumpRunLoop()

            #expect(!recorder.hasAnimation("outer-region"))
            #expect(recorder.hasAnimation("inner-region"))
        }

        @Test
        func testProxyDrivenScopeWorksBelowAnimationBarrier() throws {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let proxyBox = ProxyBox()
            let hosted = host(
                BarrierBelowProxyProbeView(model: model, recorder: recorder, proxyBox: proxyBox))
            defer { hosted.close() }
            pumpRunLoop()

            let proxy = try #require(proxyBox.proxy)

            recorder.clear()
            proxy.animate {
                model.inner.toggle()
            }
            pumpRunLoop()

            #expect(recorder.hasAnimation("barrier-proxy-child"))
            #expect(recorder.hasStamp("barrier-proxy-child"))
        }

        @Test
        func testProxyAnimationOverrideIsUsedWhenBoundaryRestores() throws {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let proxyBox = ProxyBox()
            let overrideAnimation = Animation.easeInOut(duration: 0.73)
            let hosted = host(
                OverrideProxyProbeView(model: model, recorder: recorder, proxyBox: proxyBox))
            defer { hosted.close() }
            pumpRunLoop()

            let proxy = try #require(proxyBox.proxy)

            recorder.clear()
            proxy.animate(overrideAnimation) {
                model.inner.toggle()
            }
            pumpRunLoop()

            #expect(recorder.hasAnimation("override-child"))
            #expect(recorder.hasAnimation("override-child", overrideAnimation))
        }

        @Test
        func testProxyDrivenScopeHonorsDisabledAnimations() throws {
            let model = ProbeModel()
            let recorder = TransactionRecorder()
            let proxyBox = ProxyBox()
            let hosted = host(
                DisabledProxyScopeProbeView(model: model, recorder: recorder, proxyBox: proxyBox)
            )
            defer { hosted.close() }
            pumpRunLoop()

            let proxy = try #require(proxyBox.proxy)

            recorder.clear()
            proxy.animate {
                model.inner.toggle()
            }
            pumpRunLoop()

            #expect(!recorder.hasAnimation("disabled-proxy-child"))
            #expect(recorder.matching("disabled-proxy-child").contains { $0.disablesAnimations })
        }
    }
}
