import SwiftUI

protocol OverviewNavigating {
    func select(_ tab: DashboardView.DashboardTab)
    func reviewSmartGroup(named name: String)
}

struct OverviewNavigator: OverviewNavigating {
    let selectedTab: Binding<DashboardView.DashboardTab?>
    let targetSmartGroupName: Binding<String?>

    func select(_ tab: DashboardView.DashboardTab) {
        selectedTab.wrappedValue = tab
    }

    func reviewSmartGroup(named name: String) {
        targetSmartGroupName.wrappedValue = name
        selectedTab.wrappedValue = .smartGroups
    }
}
