//
//  MessageAPI.swift
//  WA8_16
//
//  Created by 王敬捷 on 11/3/25.
//

import Foundation
import FirebaseFirestore

final class MessageAPI {
    private let db = Firestore.firestore()

    // MARK: - Helpers
    private func chatId(for a: String, and b: String) -> String {
        return [a, b].sorted().joined(separator: "_")
    }

    // MARK: - Send
    func sendMessage(from senderId: String,
                     to receiverId: String,
                     text: String,
                     senderName: String,
                     completion: @escaping (Error?) -> Void) {
        let cid = chatId(for: senderId, and: receiverId)
        let data: [String: Any] = [
            "senderId": senderId,
            "senderName": senderName,
            "text": text,
            "timestamp": Timestamp()
        ]
        db.collection("chats").document(cid)
            .collection("messages")
            .addDocument(data: data, completion: completion)
    }

    // MARK: - Live tail listener (latest N, ordered ascending)
    // Keeps the newest messages in sync for smooth real-time UI.
    func listenForLatestMessages(between user1: String,
                                 and user2: String,
                                 limit: Int = 30,
                                 completion: @escaping ([MessageModel]?, Error?) -> Void) -> ListenerRegistration {
        let cid = chatId(for: user1, and: user2)
        return db.collection("chats").document(cid)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .limit(toLast: limit)
            .addSnapshotListener { snap, err in
                if let err = err {
                    completion(nil, err)
                    return
                }
                let list = snap?.documents.compactMap { MessageModel(document: $0) } ?? []
                completion(list, nil)
            }
    }

    // MARK: - One-shot pagination (older than a cursor)
    // Returns up to `limit` messages strictly older than `olderThan`, in ascending order.
    func fetchOlderMessages(between user1: String,
                            and user2: String,
                            before olderThan: Timestamp,
                            limit: Int = 30,
                            completion: @escaping ([MessageModel]?, Error?) -> Void) {
        let cid = chatId(for: user1, and: user2)
        db.collection("chats").document(cid)
            .collection("messages")
            .whereField("timestamp", isLessThan: olderThan)
            .order(by: "timestamp", descending: true) // efficient page
            .limit(to: limit)
            .getDocuments { snap, err in
                if let err = err {
                    completion(nil, err)
                    return
                }
                // flip to ascending for UI
                let desc = snap?.documents.compactMap { MessageModel(document: $0) } ?? []
                completion(Array(desc.reversed()), nil)
            }
    }
}
