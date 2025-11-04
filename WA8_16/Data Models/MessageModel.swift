import FirebaseFirestore

struct MessageModel {
    let id: String
    let senderId: String
    let senderName: String
    let text: String
    let timestamp: Timestamp

    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let senderId = data["senderId"] as? String,
              let senderName = data["senderName"] as? String,
              let text = data["text"] as? String,
              let timestamp = data["timestamp"] as? Timestamp else { return nil }
        self.id = document.documentID
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.timestamp = timestamp
    }
}
