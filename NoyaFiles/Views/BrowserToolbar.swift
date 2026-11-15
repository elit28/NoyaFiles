import SwiftUI

struct BrowserToolbar: ToolbarContent {
    @Bindable var model: BrowserModel
    let window: WindowModel

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            ControlGroup {
                Button {
                    model.goBack()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .disabled(!model.canGoBack)
                .help("Back")

                Button {
                    model.goForward()
                } label: {
                    Label("Forward", systemImage: "chevron.right")
                }
                .disabled(!model.canGoForward)
                .help("Forward")
            }
            .controlGroupStyle(.navigation)
        }

        ToolbarItem {
            Picker("Group By", selection: $model.grouping) {
                ForEach(GroupingMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .help("Group items")
        }

        ToolbarItem {
            Menu {
                Picker("Sort By", selection: $model.sortField) {
                    ForEach(SortField.allCases) { field in
                        Text(field.title).tag(field)
                    }
                }
                .pickerStyle(.inline)

                Picker("Order", selection: $model.sortDirection) {
                    Text("Ascending").tag(SortOrder.forward)
                    Text("Descending").tag(SortOrder.reverse)
                }
                .pickerStyle(.inline)
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            .help("Sort items")
        }

        ToolbarItem {
            Picker("View", selection: $model.viewMode) {
                Label("List", systemImage: "list.bullet").tag(ViewMode.list)
                Label("Grid", systemImage: "square.grid.2x2").tag(ViewMode.grid)
                Label("Columns", systemImage: "rectangle.split.3x1").tag(ViewMode.columns)
            }
            .pickerStyle(.segmented)
            .labelStyle(.iconOnly)
            .help("Change how items are shown")
        }

        ToolbarItem {
            Button {
                window.isDualPane = true
            } label: {
                Label("Dual Pane", systemImage: "rectangle.split.2x1")
            }
            .help("Show two folders side by side")
        }

        ToolbarItem {
            Toggle(isOn: $model.isInsightsVisible) {
                Label("Insights", systemImage: "chart.bar.xaxis")
            }
            .help("Show or hide insights")
        }
    }
}
