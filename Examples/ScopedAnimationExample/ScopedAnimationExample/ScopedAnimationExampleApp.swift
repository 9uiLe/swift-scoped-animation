import SwiftUI

@main
struct ScopedAnimationExampleApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView(initialTab: ExampleTab.launchDefault)
    }
  }
}

enum ExampleTab: Hashable {
  case comparison
  case overlay
  case listQA

  static var launchDefault: ExampleTab {
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("--screen=list-qa") {
      return .listQA
    }
    if arguments.contains("--screen=overlay") {
      return .overlay
    }
    return .comparison
  }
}

struct ContentView: View {
  @State private var selectedTab: ExampleTab

  init(initialTab: ExampleTab = .comparison) {
    _selectedTab = State(initialValue: initialTab)
  }

  var body: some View {
    TabView(selection: $selectedTab) {
      NavigationStack {
        BeforeAfterView()
      }
      .tabItem {
        Label("Compare", systemImage: "rectangle.2.swap")
      }
      .tag(ExampleTab.comparison)

      NavigationStack {
        OverlayDemoView()
      }
      .tabItem {
        Label("Overlay", systemImage: "scope")
      }
      .tag(ExampleTab.overlay)

      NavigationStack {
        ListQAView()
      }
      .tabItem {
        Label("List QA", systemImage: "checklist")
      }
      .tag(ExampleTab.listQA)
    }
  }
}
