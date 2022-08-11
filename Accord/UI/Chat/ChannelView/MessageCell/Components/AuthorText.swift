//
//  AuthorText.swift
//  Accord
//
//  Created by evelyn on 2022-05-30.
//

import SwiftUI

struct AuthorTextView: View, Equatable {
    static func == (lhs: AuthorTextView, rhs: AuthorTextView) -> Bool {
        lhs.nick == rhs.nick && lhs.role == rhs.role
    }
    
    var message: Message
    var pronouns: String?
    var nick: String?
    
    @Environment(\.guildID)
    var guildID: String
    
    @MainActor
    var nickname: String? {
        if self.guildID == "@me" {
            return _nickname
        }
        return nil
    }
    
    @MainActor
    var _nickname: String? {
        Storage.users[self.message.author?.id ?? ""]?.relationship?.nickname
    }
    
    @Binding var role: String?
    
    @EnvironmentObject
    var appModel: AppGlobals
    
    var body: some View {
        HStack(spacing: 1) {
            Text(self.nickname ?? nick ?? _nickname ?? message.author?.username ?? "Unknown User")
                .foregroundColor({ () -> Color in
                    if let role = role, let color = Storage.roleColors[role]?.0, !message.isSameAuthor {
                        return Color(int: color)
                    }
                    return Color.primary
                }())
                .font(.chatTextFont)
                .fontWeight(.semibold)
                +
            Text("  \(message.processedTimestamp ?? "")")
                .foregroundColor(Color.secondary)
                .font(.subheadline)
                +
            Text(message.editedTimestamp != nil ? " (edited at \(message.editedTimestamp?.makeProperHour() ?? "unknown time"))" : "")
                .foregroundColor(Color.secondary)
                .font(.subheadline)
                +
            Text((pronouns != nil) ? " • \(pronouns ?? "Use my name")" : "")
                .foregroundColor(Color.secondary)
                .font(.subheadline)
            if message.author?.bot == true {
                Text("Bot")
                    .padding(.horizontal, 4)
                    .foregroundColor(Color.white)
                    .font(.subheadline)
                    .background(Capsule().fill().foregroundColor(Color.red))
                    .padding(.horizontal, 4)
            }
            if message.author?.system == true {
                Text("System")
                    .padding(.horizontal, 4)
                    .foregroundColor(Color.white)
                    .font(.subheadline)
                    .background(Capsule().fill().foregroundColor(Color.purple))
                    .padding(.horizontal, 4)
            }
        }
    }
}
