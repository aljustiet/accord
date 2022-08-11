//
//  SetNicknameView.swift
//  Accord
//
//  Created by Serena on 21/05/2022
//

import SwiftUI

struct SetNicknameView: View {
    /// The user to set the nickname for
    var user: User?

    /// The guild ID to set the nickname in
    @Environment(\.guildID)
    var guildID: String

    @Binding var isPresented: Bool

    @State var newNicknameText: String = ""
    @State var errorText: String? = nil
    var body: some View {
        Text("Setting nickname for \(user?.username ?? "Unknown User")")
        TextField("new nickname..", text: $newNicknameText)
            .textFieldStyle(.roundedBorder)
        if let errorText = errorText {
            Text(errorText)
                .foregroundColor(.red)
                .fixedSize(horizontal: true, vertical: false)
        }

        Button("Set") {
            setNickname()
        }
        .disabled(newNicknameText.isEmpty)
        .keyboardShortcut(.defaultAction)
    }

    func setNickname() {
        errorText = nil // reset error, if one was encountered

        guard let userID = user?.id else {
            errorText = "Unable to get user ID"
            return
        }

        // The API URL to contact
        var url = URL(string: rootURL)!
            .appendingPathComponent("guilds")
            .appendingPathComponent(guildID)
            .appendingPathComponent("members")

        // if we're changing the nickname of the current user,
        // we must append @me instead
        // otherwise, you'll encounter an error
        if user == Globals.user {
            url.appendPathComponent("@me")
        } else {
            url.appendPathComponent(userID)
        }

        let body = ["nick": newNicknameText]

        Request.fetch(url: url, headers: Headers(
            token: Globals.token,
            bodyObject: body,
            type: .PATCH,
            discordHeaders: true,
            json: true
        )) { result in
            switch result {
            case let .success(data):
                // make sure it is not a DiscordError
                if let discordErr = try? JSONDecoder().decode(DiscordError.self, from: data) {
                    errorText = "Discord Error: \(discordErr.message ?? "Unknown Error")"
                    return
                }

                isPresented.toggle() // dismiss the view once we're done
            case let .failure(err):
                errorText = "Failed to set nickname with error \(err)"
            }
        }
    }
}
