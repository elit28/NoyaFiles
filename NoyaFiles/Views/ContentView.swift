import SwiftUI

/// One window: the sidebar and whatever the main area shows.
struct ContentView: View {
    @State private var window = WindowModel()
    @State private var sidebar = SidebarModel()
    @AppStorage(PreferenceKey.appearance) private var appearance = AppearancePreference.system
    @AppStorage(PreferenceKey.accent) private var accent = AccentPreference.teal
    private let workspaces = WorkspaceStore.shared
    private let notices = NoticeCenter.shared
    @MainActor private static var hasCheckedWeeklyTidy = false

    var body: some View {
        NavigationSplitView {
            SidebarView(sidebar: sidebar, selection: $window.sidebarSelection) {
                window.isTidyPresented = true
            }
                .navigationSplitViewColumnWidth(min: 190, ideal: 230, max: 320)
        } detail: {
            switch window.destination {
            case .browser:
                if window.isDualPane {
                    DualPaneScreen(window: window)
                } else {
                    BrowserScreen(model: window.browser, window: window)
                }
            case .workspace(let id):
                WorkspaceScreen(workspaceID: id)
            case .search:
                if let search = window.search {
                    SearchScreen(search: search, window: window)
                }
            case .tool(.freeUpSpace):
                FreeUpSpaceScreen()
            case .tool(.developer):
                DeveloperScreen()
            case .tool(.assistant):
                AssistantScreen(window: window)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            VStack(alignment: .trailing, spacing: 0) {
                if let notice = notices.current {
                    NoticeToast(notice: notice, perform: notices.perform, dismiss: notices.dismiss)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if let operation = window.operations.current {
                    OperationToast(operation: operation) {
                        window.operations.cancel()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: window.operations.current?.id)
        .animation(.easeOut(duration: 0.2), value: notices.current?.id)
        .sheet(isPresented: $window.isTidyPresented) {
            TidySheet()
        }
        .task {
            await Self.runWeeklyTidyIfDue(window: window)
        }
        .alert("Something went wrong", isPresented: errorBinding, presenting: currentError) { _ in
            Button("OK") {
                window.operations.lastError = nil
                workspaces.lastError = nil
            }
        } message: { message in
            Text(message)
        }
        .environment(workspaces)
        .environment(\.tidyUp) { window.isTidyPresented = true }
        .environment(SavedSearchStore.shared)
        .focusedSceneValue(\.browserModel, window.activeBrowser)
        .focusedSceneValue(\.windowModel, window)
        .tint(accent.color)
        .frame(minWidth: 900, minHeight: 540)
        .onChange(of: appearance, initial: true) {
            appearance.apply()
        }
    }

    /// Once per launch, tidies up Downloads if the weekly tidy-up is due.
    private static func runWeeklyTidyIfDue(window: WindowModel) async {
        guard !hasCheckedWeeklyTidy else { return }
        hasCheckedWeeklyTidy = true
        let tidy = TidyController.shared
        guard tidy.isWeeklyTidyDue else { return }
        if tidy.showsPreview {
            window.isTidyPresented = true
        } else {
            let outcome = await tidy.apply(await tidy.makePlan())
            TidySheet.announce(outcome)
        }
    }

    private var currentError: String? {
        window.operations.lastError ?? workspaces.lastError
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { currentError != nil },
            set: { isPresented in
                if !isPresented {
                    window.operations.lastError = nil
                    workspaces.lastError = nil
                }
            }
        )
    }
}

#Preview {
    ContentView()
        .frame(width: 1180, height: 740)
}
