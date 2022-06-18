//
//  ChannelView.swift
//  Accord
//
//  Created by evelyn on 2020-11-27.
//

import AppKit
import AVKit
import Combine
import SwiftUI

struct ChannelView: View, Equatable {
    static func == (lhs: ChannelView, rhs: ChannelView) -> Bool {
        lhs.viewModel == rhs.viewModel
    }

    @StateObject var viewModel: ChannelViewViewModel

    var guildID: String
    var channelID: String
    var channelName: String
    var guildName: String

    // Whether or not there is a message send in progress
    @State var sending: Bool = false

    // WebSocket error
    @State var error: String?

    // Mention users in replies
    @State var mention: Bool = true
    @State var replyingTo: Message?
    @State var mentionUser: Bool = true

    @State var pins: Bool = false
    @State var mentions: Bool = false
    
    @State var searchText: String = ""
    @State var showSearch: Bool = false
    @State var searchMessages: [Message] = []
    @State var searchForPinnedMessages: Bool = false
    
    @AppStorage("memberListShown")
    var memberListShown: Bool = false

    @State var fileUploads: [(Data?, URL?)] = .init()

    @AppStorage("MetalRenderer")
    var metalRenderer: Bool = false

    @State private var cancellable = Set<AnyCancellable>()

    @Environment(\.user)
    var user: User

    @Environment(\.colorScheme)
    var colorScheme: ColorScheme

    static var scrollTo = PassthroughSubject<(String, String), Never>()
    
    @State var scrolledOutOfBounds: Bool = false

    // MARK: - init

    init(_ channel: Channel, _ guildName: String? = nil, model: StateObject<ChannelViewViewModel>? = nil) {
        guildID = channel.guild_id ?? "@me"
        channelID = channel.id
        channelName = channel.name ?? channel.recipients?.first?.username ?? "Unknown channel"
        self.guildName = guildName ?? "Direct Messages"
        if let model {
            self._viewModel = model
        } else {
            _viewModel = StateObject(wrappedValue: ChannelViewViewModel(channel: channel))
        }
        viewModel.memberList = channel.recipients?.map(OPSItems.init) ?? []
        if wss.connection?.state == .cancelled {
            concurrentQueue.async {
                wss?.reset()
            }
        }
    }

    var messagesView: some View {
        ForEach(viewModel.messages, id: \.identifier) { message in
            MessageCellView(
                message: message,
                nick: viewModel.nicks[message.author?.id ?? ""],
                replyNick: viewModel.nicks[message.referenced_message?.author?.id ?? ""],
                pronouns: viewModel.pronouns[message.author?.id ?? ""],
                avatar: viewModel.avatars[message.author?.id ?? ""],
                guildID: viewModel.guildID,
                permissions: $viewModel.permissions,
                role: $viewModel.roles[message.author?.id ?? ""],
                replyRole: $viewModel.roles[message.referenced_message?.author?.id ?? ""],
                replyingTo: $replyingTo
            )
            .equatable()
            .id(message.id)
            .listRowInsets(EdgeInsets(
                top: 3.5,
                leading: 0,
                bottom: message.bottomInset,
                trailing: 0
            ))
            .padding(.horizontal, 5.0)
            .padding(.vertical, message.userMentioned ? 3.0 : 0.0)
            .background(message.userMentioned ? Color.yellow.opacity(0.1).cornerRadius(7) : nil)
            .onAppear { [unowned viewModel] in
                if viewModel.messages.count >= 50,
                   message == viewModel.messages[viewModel.messages.count - 2]
                {
                    messageFetchQueue.async {
                        viewModel.loadMoreMessages()
                    }
                }
            }
        }
        .rotationEffect(.degrees(180))
        .scaleEffect(x: -1.0, y: 1.0, anchor: .center)
        .fixedSize(horizontal: false, vertical: true)
    }
    
    var messagePlaceholderView : some View {
        ForEach(1..<20) { _ in
            VStack {
                HStack(alignment: .bottom) {
                    Circle()
                        .foregroundColor(.gray)
                        .frame(width: 35, height: 35)
                        .padding(.trailing, 1.5)
                        .fixedSize()
                    
                    VStack(alignment: .leading) {
                        Rectangle()
                            .frame(width: 30 * CGFloat(Int.random(in: 3...20)), height: 13 * CGFloat(Int.random(in: 1...5)))
                            .cornerRadius(6)
                        Rectangle()
                            .frame(width: 20 * CGFloat(Int.random(in: 3...10)), height: 13)
                            .cornerRadius(6)
                        Spacer().frame(height: 1.3)
                    }
                }
                .foregroundColor(.gray)
                .opacity(0.5)
                Spacer()
            }
        }
    }

    var body: some View {
        HStack(content: {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomTrailing) {
                    ScrollViewReader { proxy in
                        List {
                            Spacer().frame(height: 15)
                            if metalRenderer {
                                messagesView
                                    .drawingGroup()
                            } else {
                                messagesView
                            }
                            if viewModel.noMoreMessages {
                                Divider()
                                Text("This is the start of the channel")
                                    .rotationEffect(.degrees(180))
                                    .scaleEffect(x: -1.0, y: 1.0, anchor: .center)
                                Text("Welcome to #\(channelName)!")
                                    .bold()
                                    .dynamicTypeSize(.xxxLarge)
                                    .font(.largeTitle)
                                    .rotationEffect(.degrees(180))
                                    .scaleEffect(x: -1.0, y: 1.0, anchor: .center)
                            } else {
                                messagePlaceholderView
                            }
                        }
                        .listRowBackground(colorScheme == .dark ? Color.darkListBackground : Color(NSColor.controlBackgroundColor))
                        .rotationEffect(.radians(.pi))
                        .scaleEffect(x: -1.0, y: 1.0, anchor: .center)
                        .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.didWakeNotification), perform: { [weak viewModel] _ in
                            viewModel?.cancellable.forEach { $0.cancel() }
                            viewModel?.cancellable.removeAll()
                            viewModel?.connect()
                            if viewModel?.guildID == "@me" {
                                try? wss.subscribeToDM(self.channelID)
                            } else {
                                try? wss.subscribe(to: self.guildID)
                            }
                            viewModel?.getMessages(channelID: self.channelID, guildID: self.guildID)
                        })
                        .onReceive(Self.scrollTo, perform: { channelID, id in
                            guard channelID == self.channelID else { return }
                            if viewModel.messages.map(\.id).contains(id) {
                                withAnimation(.easeInOut(duration: 0.5), {
                                    proxy.scrollTo(id, anchor: .center)
                                })
                            } else {
                                self.scrolledOutOfBounds = true
                                messageFetchQueue.async {
                                    viewModel.loadAroundMessage(id: id)
                                }
                            }
                        })
                    }
                    if self.scrolledOutOfBounds {
                        Button(action: { [weak viewModel] in
                            self.scrolledOutOfBounds = false
                            messageFetchQueue.async {
                                viewModel?.getMessages(channelID: self.channelID, guildID: self.guildID, scrollAfter: true)
                            }
                        }) {
                            Image(systemName: "arrowtriangle.down.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 33, height: 33)
                                .opacity(0.9)
                        }
                        .buttonStyle(.borderless)
                        .padding(15)
                    }
                }
                blurredTextField
            }
            if memberListShown {
                MemberListView(guildID: viewModel.guildID, list: $viewModel.memberList)
                    .frame(width: 250)
                    .onAppear { [unowned viewModel] in
                        if viewModel.memberList.isEmpty, viewModel.guildID != "@me" {
                            try? wss.memberList(for: viewModel.guildID, in: viewModel.channelID)
                        }
                    }
            }
            
            if showSearch {
                List(searchMessages, id: \.id) { message in
                    MessageCellView(
                        message: message,
                        nick: nil,
                        replyNick: nil,
                        pronouns: nil,
                        avatar: nil,
                        guildID: self.guildID,
                        permissions: .constant(.init()),
                        role: Binding.constant(nil),
                        replyRole: Binding.constant(nil),
                        replyingTo: $replyingTo
                    )
                }
            }
        })
        .navigationTitle(Text("\(viewModel.guildID == "@me" ? "" : "#")\(channelName)".replacingOccurrences(of: "#", with: "")))
        .presentedWindowToolbarStyle(.unifiedCompact)
        .onDrop(of: ["public.file-url"], isTargeted: Binding.constant(false)) { providers -> Bool in
            providers.first?.loadDataRepresentation(forTypeIdentifier: "public.file-url", completionHandler: { data, _ in
                if let data = data, let path = NSString(data: data, encoding: 4), let url = URL(string: path as String) {
                    self.fileUploads.append((try? Data(contentsOf: url), url))
                }
            })
            return true
        }
        .searchable(text: $searchText) {
            Toggle("Filter by pinned", isOn: $searchForPinnedMessages)
        }
        .onSubmit(of: .search) {
            showSearch = !searchText.isEmpty || self.searchForPinnedMessages
            if showSearch {
                search()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack {
                    Button(action: {
                        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                    }, label: {
                        Image(systemName: "sidebar.leading")
                    })
                    Image(systemName: "number")
                        .resizable()
                        .frame(width: 13, height: 13)
                        .foregroundColor(.secondary)
                        .padding(.trailing, -2)
                }
            }
            ToolbarItemGroup {
                Toggle(isOn: $pins) {
                    Image(systemName: "pin.fill")
                        .rotationEffect(.degrees(45))
                }
                .popover(isPresented: $pins) { [unowned viewModel] in
                    PinsView(guildID: viewModel.guildID, channelID: viewModel.channelID, replyingTo: Binding.constant(nil))
                        .frame(width: 500, height: 600)
                }
                Toggle(isOn: $mentions) {
                    Image(systemName: "bell.badge.fill")
                }
                .popover(isPresented: $mentions) {
                    MentionsView(replyingTo: Binding.constant(nil))
                        .frame(width: 500, height: 600)
                }
                Toggle(isOn: $memberListShown.animation()) {
                    Image(systemName: "person.2.fill")
                }
            }
        }
    }
    
    func search() {
        var queryParams: [String: String] = [:]
        if !searchText.isEmpty {
            queryParams["content"] = searchText
        }
        
        queryParams["pinned"] = searchForPinnedMessages.description
        
        let url = URL(string: rootURL)!
            .appendingPathComponent("guilds")
            .appendingPathComponent(self.guildID)
            .appendingPathComponent("messages")
            .appendingPathComponent("search")
            .appendingQueryParameters(queryParams)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601withFractionalSeconds
        Request.fetch(SearchResult.self, request: nil, url: url, headers: Headers(
            userAgent: discordUserAgent,
            token: Globals.token,
            type: .GET
        ), decoder: decoder) { result in
            switch result {
            case .success(let messages):
                DispatchQueue.main.async {
                    self.searchMessages = messages.messages.flatMap { $0 }
                }
            case .failure(let error):
                print("Error: \(error)")
            }
        }
    }
}

struct MemberListView: View {
    var guildID: String
    @Binding var list: [OPSItems]
    var body: some View {
        List(self.$list, id: \.id) { $ops in
            if let group = ops.group {
                Text(
                    "\(group.id == "offline" ? "OFFLINE" : group.id == "online" ? "OFFLINE" : roleNames[group.id ?? ""]?.uppercased() ?? "") - \(group.count ?? 0)"
                )
                .fontWeight(.semibold)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding([.top])
            } else {
                MemberListViewCell(guildID: self.guildID, ops: $ops)
            }
        }
    }
}

struct MemberListViewCell: View {
    var guildID: String
    @Binding var ops: OPSItems
    @State var popup: Bool = false
    var body: some View {
        Button(action: {
            self.popup.toggle()
        }) { [unowned ops] in
            HStack {
                Attachment(pfpURL(ops.member?.user.id ?? "", ops.member?.user.avatar ?? "", discriminator: ops.member?.user.discriminator ?? "", "64"))
                    .equatable()
                    .frame(width: 33, height: 33)
                    .clipShape(Circle())
                VStack(alignment: .leading) {
                    Text(ops.member?.nick ?? ops.member?.user.username ?? "")
                        .fontWeight(.medium)
                        .foregroundColor({ () -> Color in
                            if let role = ops.member?.roles?.first, let color = roleColors[role]?.0 {
                                return Color(int: color)
                            }
                            return Color.primary
                        }())
                        .lineLimit(0)
                    if let presence = ops.member?.presence?.activities.first?.state {
                        Text(presence).foregroundColor(.secondary)
                            .lineLimit(0)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.borderless)
        .popover(isPresented: self.$popup, content: {
            PopoverProfileView(user: ops.member?.user, guildID: guildID)
        })
    }
}
