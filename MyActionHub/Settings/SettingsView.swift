import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }

            IMESwitcherTab()
                .tabItem { Label("IME Switcher", systemImage: "keyboard") }

            BindingsTab()
                .tabItem { Label("Bindings", systemImage: "list.bullet.rectangle") }

            PermissionsTab()
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .padding(20)
        .frame(width: 720, height: 540)
    }
}
