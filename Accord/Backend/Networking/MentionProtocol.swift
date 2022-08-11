//
//  MentionProtocol.swift
//  MentionProtocol
//
//  Created by evelyn on 2021-09-01.
//

import Foundation

protocol MentionSenderDelegate {
    func addMention(guild: String, channel: String)
    func deselect()
    func removeMentions(server: String)
    func select(channel: Channel)
    func newMessage(in: String, message: Message)
}

class MentionSender {
    static let shared = MentionSender()
    public var delegate: MentionSenderDelegate?
    func addMention(guild: String, channel: String) {
        delegate?.addMention(guild: guild, channel: channel)
    }

    func deselect() {
        delegate?.deselect()
    }

    func removeMentions(server: String) {
        delegate?.removeMentions(server: server)
    }

    func select(channel: Channel) {
        delegate?.select(channel: channel)
    }

    func newMessage(in channel: String, message: Message) {
        delegate?.newMessage(in: channel, message: message)
    }
}
