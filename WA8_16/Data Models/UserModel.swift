import FirebaseFirestore

struct UserModel: Codable {
    var id: String
    var name: String
    var email: String

    init(id: String, name: String, email: String) {
        self.id = id
        self.name = name
        self.email = email
    }

    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let name = data["name"] as? String,
              let email = data["email"] as? String else {
            return nil
        }
        self.id = document.documentID
        self.name = name
        self.email = email
    }

    var dictionary: [String: Any] {
        return [
            "name": name,
            "email": email
        ]
    }
}
