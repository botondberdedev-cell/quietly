import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var editing = false

    var body: some View {
        List {
            Section {
                ForEach(store.settings.friendUsernames, id: \.self) { name in
                    Button {
                        store.start(.home, friend: name)
                    } label: {
                        Label("@\(name)", systemImage: "person.crop.circle")
                            .padding(.vertical, 8)
                    }
                }
                if store.settings.friendUsernames.isEmpty {
                    Text("Keep your people close. Add their Instagram usernames to start here.")
                        .foregroundStyle(Palette.secondaryText)
                }
            } footer: {
                Text("Visit a profile for its posts, stories and Reels. Each visit uses your usual timer. Instagram decides which private content your account can access.")
            }
            Button("Edit Friends list") { editing = true }
        }
        .navigationTitle("Your people")
        .sheet(isPresented: $editing) { SettingsView() }
    }
}
