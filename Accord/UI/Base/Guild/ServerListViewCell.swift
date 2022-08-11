//
//  ServerListViewCell.swift
//  Accord
//
//  Created by evelyn on 2022-04-17.
//

import Foundation
import SwiftUI

struct ServerListViewCell: View {
    @Binding var channel: Channel
    var guildID: String { channel.guild_id ?? "@me" }
    @State var status: String? = nil

    @MainActor private var dmLabelView: some View {
        HStack {
            ZStack(alignment: .bottomTrailing) {
                Attachment(pfpURL(
                    channel.recipients?.first?.id,
                    channel.recipients?.first?.avatar,
                    discriminator: channel.recipients?.first?.discriminator ?? "0005"
                ))
                .equatable()
                .frame(width: 35, height: 35)
                .clipShape(Circle())
                statusDot
            }
            VStack(alignment: .leading) {
                Text(channel.computedName)
                    .animation(nil, value: UUID())
                if let messageID = channel.last_message_id {
                    if messageID != channel.read_state?.last_message_id {
                        Text("New messages at " + Date(timeIntervalSince1970: Double(parseSnowflake(messageID) / 1000)).makeProperHour())
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    @MainActor @ViewBuilder
    private var labelView: some View {
        switch channel.type {
        case .normal:
            HStack {
                Image(systemName: "number")
                Text(channel.computedName)
            }
        case .voice:
            HStack {
                Image(systemName: "speaker.wave.2.fill")
                Text(channel.computedName)
            }
        case .guild_news:
            HStack {
                Image(systemName: "megaphone.fill")
                Text(channel.computedName)
            }
        case .stage:
            HStack {
                Image(systemName: "person.wave.2.fill")
                Text(channel.computedName)
            }
        case .dm:
            dmLabelView
        case .group_dm:
            HStack {
                if let channelIcon = channel.icon {
                    Attachment(cdnURL + "/channel-icons/\(channel.id)/\(channelIcon).png?size=48").equatable()
                        .frame(width: 35, height: 35)
                        .clipShape(Circle())
                } else {
                    Attachment(pfpURL(nil, nil, discriminator: channel.id.suffix(4).stringLiteral))
                        .frame(width: 35, height: 35)
                        .clipShape(Circle())
                }
                VStack(alignment: .leading) {
                    Text(channel.computedName)
                    Text(String((channel.recipients?.count ?? 0) + 1) + " members")
                        .foregroundColor(.secondary)
                }
            }
        case .guild_public_thread:
            HStack {
                Image(systemName: "tray.full")
                Text(channel.computedName)
            }
        case .guild_private_thread:
            HStack {
                Image(systemName: "tray.full")
                Text(channel.computedName)
            }
        default:
            HStack {
                Image(systemName: "number")
                Text(channel.computedName)
            }
        }
    }

    private var statusDot: some View {
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
            .frame(width: 8, height: 8)
            .opacity(0.8)
            .shadow(radius: 0.25)
    }

    private var readStateDot: some View {
        ZStack {
            Circle()
                .foregroundColor(.red)
                .opacity(0.8)
                .shadow(radius: 0.2)
            Text(String(channel.read_state?.mention_count ?? 0))
                .foregroundColor(.white)
                .font(.caption)
        }
        .frame(width: 15, height: 15)
    }

    var body: some View {
        HStack {
            labelView
            Spacer()
            if let readState = channel.read_state, readState.mention_count != 0 {
                readStateDot
            }
        }
    }
}
