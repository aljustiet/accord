//
//  ServerListView.swift
//  Accord
//
//  Created by evelyn on 2021-06-18.
//

import Combine
import SwiftUI
import UserNotifications

struct NavigationLazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }

    var body: Content {
        build()
    }
}

extension Reachability {
    var connected: Bool {
        connection == .wifi || connection == .cellular
    }
}

struct GuildHoverAnimation: ViewModifier {
    var color: Color = Color.accentColor.opacity(0.5)
    var hasIcon: Bool
    var frame: Double = 45
    var selected: Bool
    @State var hovered: Bool = false

    func body(content: Content) -> some View {
        content
            .frame(width: frame, height: frame)
            .background(!hasIcon && hovered ? color : Color.clear)
            .onHover(perform: { res in
                withAnimation(Animation.easeInOut(duration: 0.1)) {
                    hovered = res
                }
            })
            .cornerRadius(hovered || selected ? 15 : frame / 2)
    }
}

func pingCount(guild: Guild) -> Int {
    let intArray = guild.channels.compactMap { $0.read_state?.mention_count }
    return intArray.reduce(0, +)
}

func unreadMessages(guild: Guild) -> Bool {
    let array = guild.channels
        .filter { $0.read_state != nil }
        .compactMap { $0.last_message_id == $0.read_state?.last_message_id }
        .contains(false)
    return array
}

struct ServerListView: View {
    
    @MainActor @State
    var selection: Int? = nil
    @MainActor @State
    var selectedGuild: Guild? = nil
    
    @MainActor @AppStorage("SelectedServer")
    var selectedServer: String?
    
    @MainActor @ObservedObject
    public var appModel: AppGlobals = .init()
    
    internal static var readStates: [ReadStateEntry] = .init()
    var statusText: String? = nil
    @State var status: String? = nil
    @State var iconHovered: Bool = false
    @State var isShowingJoinServerSheet: Bool = false
    
    @State var popup: Bool = false
    
    @ObservedObject var viewModel: ServerListViewModel = ServerListViewModel(guild: nil, readyPacket: nil)

    var onlineButton: some View {
        Button(action: {
            AccordApp.error(text: "Offline", additionalDescription: "Check your network connection")
        }, label: {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.title)
        })
        .buttonStyle(.borderless)
    }
    
    var performInView = PassthroughSubject<() -> Void, Never>()

    var statusIndicator: some View {
        Circle()
            .foregroundColor({ () -> Color in
                switch self.status {
                case "online":
                    return Color.green
                case "idle":
                    return Color.orange
                case "dnd":
                    return Color.red
                case "offline":
                    return Color.gray
                default:
                    return Color.clear
                }
            }())
            .frame(width: 7, height: 7)
    }

    var settingsLink: some View {
        NavigationLink(destination: SettingsView(), tag: 0, selection: self.$selection) {
            HStack {
                ZStack(alignment: .bottomTrailing) {
                    Image(nsImage: NSImage(data: avatar) ?? NSImage()).resizable()
                        .scaledToFit()
                        .clipShape(Circle())
                        .frame(width: 24, height: 24)
                    statusIndicator
                }
                VStack(alignment: .leading) {
                    if let user = Globals.user {
                        Text(user.username) + Text("#" + user.discriminator).foregroundColor(.secondary)
                        if let statusText = statusText {
                            Text(statusText)
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .buttonStyle(.borderless)
    }

    var body: some View {
        NavigationView {
            HStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    // MARK: - Messages button
                    
                    LazyVStack {
                        if reachability?.connected == false {
                            onlineButton.buttonStyle(BorderlessButtonStyle())
                            Color.gray
                                .frame(width: 30, height: 1)
                                .opacity(0.75)
                        }
                        DMButton(
                            selection: self.$selection,
                            selectedServer: self.$selectedServer,
                            selectedGuild: self.$selectedGuild
                        )
                        .fixedSize()
                        Color.gray
                            .frame(width: 30, height: 1)
                            .opacity(0.75)
                        FolderListView(selectedServer: self.$selectedServer, selection: self.$selection, selectedGuild: self.$selectedGuild)
                            .padding(.trailing, 3.5)
                        Color.gray
                            .frame(width: 30, height: 1)
                            .opacity(0.75)
                        JoinServerButton()
                    }
                }
                .frame(width: 80)
                .padding(.top, 5)
                .onReceive(self.performInView, perform: { action in
                    action()
                })
                Divider()
                
                // MARK: - Loading UI
                
                if selectedServer == "@me" {
                    List {
                        settingsLink
                        Divider()
                        PrivateChannelsView(selection: self.$selection)
                            .animation(nil, value: UUID())
                    }
                    .padding(.top, 5)
                    .listStyle(.sidebar)
                    .animation(nil, value: UUID())
                } else if let selectedGuild = selectedGuild {
                    GuildView(guild: Binding($selectedGuild) ?? .constant(selectedGuild), selection: self.$selection)
                        .animation(nil, value: UUID())
                }
            }
            .frame(minWidth: 300, maxWidth: 500, maxHeight: .infinity)
        }
        .environmentObject(self.appModel)
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
        // .navigationViewStyle(DoubleColumnNavigationViewStyle())
        .sheet(isPresented: $popup, onDismiss: {}) {
            SearchView()
                .focusable()
                .environmentObject(self.appModel)
                .touchBar {
                    Button(action: {
                        popup.toggle()
                    }) {
                        Image(systemName: "magnifyingglass")
                    }
                }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("Refresh")), perform: { pub in
            guard let uInfo = pub.userInfo as? [String: Int],
                  let firstKey = uInfo.first else { return }
            print(firstKey)
            self.selectedServer = firstKey.key
            self.selection = firstKey.value
            self.selectedGuild = Array(appModel.folders.map(\.guilds).joined())[keyed: firstKey.key]
        })
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DMSelect")), perform: { pub in
            guard let uInfo = pub.userInfo as? [String: String],
                  let index = uInfo["index"], let number = Int(index) else { return }
            self.selectedServer = "@me"
            self.selection = number
        })
        .onReceive(NotificationCenter.default.publisher(for: .init("red.evelyn.accord.Search")), perform: { _ in
            self.popup.toggle()
        })
        .onAppear {
            if let upcomingGuild = self.viewModel.upcomingGuild {
                self.selectedGuild = upcomingGuild
                self.selection = self.viewModel.upcomingSelection
            }
            DispatchQueue.global().async {
                try? wss?.updatePresence(status: MediaRemoteWrapper.status ?? "offline", since: 0) {
                    Activity.current!
                }
                if UserDefaults.standard.bool(forKey: "XcodeRPC") {
                    guard let workspace = XcodeRPC.getActiveWorkspace() else { return }
                    XcodeRPC.updatePresence(workspace: workspace, filename: XcodeRPC.getActiveFilename())
                } else if UserDefaults.standard.bool(forKey: "AppleMusicRPC") {
                    MediaRemoteWrapper.updatePresence()
                } else if UserDefaults.standard.bool(forKey: "VSCodeRPCEnabled") {
                    VisualStudioCodeRPC.updatePresence()
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                if selection == nil {
                    Toggle(isOn: Binding.constant(false)) {
                        Image(systemName: "bell.badge.fill")
                    }
                }
            }
        }
    }
}
