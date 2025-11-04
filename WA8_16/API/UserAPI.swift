import FirebaseFirestore

class UserAPI {
    private let db = Firestore.firestore()
    
    func getAllUsers(completion: @escaping ([UserModel]?, Error?) -> Void) {
        db.collection("users").getDocuments { snapshot, error in
            if let error = error {
                completion(nil, error)
            } else if let documents = snapshot?.documents {
                let users = documents.compactMap { UserModel(document: $0) }
                completion(users, nil)
            } else {
                completion([], nil)
            }
        }
    }

    func saveUser(_ user: UserModel, completion: @escaping (Error?) -> Void) {
        db.collection("users").document(user.id).setData(user.dictionary) { error in
            completion(error)
        }
    }
}
