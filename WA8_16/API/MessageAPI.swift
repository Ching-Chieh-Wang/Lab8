//
//  MessageAPI.swift
//  WA8_16
//
//  Created by 王敬捷 on 11/3/25.
//



import FirebaseFirestore

class MessageAPI {
    private let db = Firestore.firestore()

    func sendMessage(from senderId: String, to receiverId: String, text: String, senderName: String, completion: @escaping (Error?) -> Void) {
        let chatId = [senderId, receiverId].sorted().joined(separator: "_")
        let message: [String: Any] = [
            "senderId": senderId,
            "senderName": senderName,
            "text": text,
            "timestamp": Timestamp()
        ]
        db.collection("chats").document(chatId).collection("messages").addDocument(data: message) { error in
            completion(error)
        }
    }

    func listenForMessages(between user1: String, and user2: String, completion: @escaping ([MessageModel]?, Error?) -> Void) {
        let chatId = [user1, user2].sorted().joined(separator: "_")
        db.collection("chats").document(chatId).collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    completion(nil, error)
                } else {
                    let messages = snapshot?.documents.compactMap { MessageModel(document: $0) } ?? []
                    completion(messages, nil)
                }
            }
    }
}
