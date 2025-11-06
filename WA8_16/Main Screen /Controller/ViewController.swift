//
//  ViewController.swift
//  App12
//
//  Created by Sakib Miazi on 6/1/23.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    let mainScreen = MainScreenView()
    
    var usersList = [UserModel]()
    
    var handleAuth: AuthStateDidChangeListenerHandle?
    
    var currentUser:FirebaseAuth.User?
    
    let database = Firestore.firestore()
    
    override func loadView() {
        view = mainScreen
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        //MARK: handling if the Authentication state is changed (sign in, sign out, register)...
        handleAuth = Auth.auth().addStateDidChangeListener { auth, user in
            if user == nil {
                //MARK: not signed in...
                self.currentUser = nil
                self.mainScreen.labelText.text = "Please sign in to start chatting with your friends!"
                //self.mainScreen.buttonNewChat.isEnabled = false
                //self.mainScreen.buttonNewChat.isHidden = true

                //MARK: Reset tableView...
                self.usersList.removeAll()
                self.mainScreen.tableViewChats.reloadData()

                //MARK: Sign in bar button...
                self.setupRightBarButton(isLoggedin: false)

            } else {
                //MARK: the user is signed in...
                self.currentUser = user
                self.mainScreen.labelText.text = "Welcome \(user?.displayName ?? "Anonymous")!"
                //self.mainScreen.buttonNewChat.isEnabled = true
                //self.mainScreen.buttonNewChat.isHidden = false

                //MARK: Logout bar button...
                self.setupRightBarButton(isLoggedin: true)

                //MARK: Fetch all users except current user to display as chat friends
                self.database.collection("users")
                    .addSnapshotListener(includeMetadataChanges: false, listener: { querySnapshot, error in
                        if let documents = querySnapshot?.documents {
                            self.usersList.removeAll()
                            for document in documents {
                                // Exclude current user
                                if let currentUserEmail = self.currentUser?.email,
                                   let currentUserName = self.currentUser?.displayName,
                                   let userEmail = document.data()["email"] as? String,
                                   let userName = document.data()["name"] as? String,
                                   userEmail == currentUserEmail || userName == currentUserName {
                                    continue
                                }
                                let userModel = UserModel(document: document)
                                if let userModel = UserModel(document: document) {
                                    self.usersList.append(userModel)
                                }
                            }
                            self.usersList.sort(by: { $0.name < $1.name })
                            self.mainScreen.tableViewChats.reloadData()
                        }
                    })
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "My Chats"
        
        //MARK: patching table view delegate and data source...
        mainScreen.tableViewChats.delegate = self
        mainScreen.tableViewChats.dataSource = self
        
        //MARK: removing the separator line...
        mainScreen.tableViewChats.separatorStyle = .none
        
        //MARK: Make the titles look large...
        navigationController?.navigationBar.prefersLargeTitles = true
        
        //MARK: Put the floating button above all the views...
        //view.bringSubviewToFront(mainScreen.buttonNewChat)
        
        //mainScreen.buttonNewChat.isHidden = true
        
        //MARK: tapping the floating add contact button...
        //mainScreen.buttonNewChat.addTarget(self, action: #selector(newChatButtonTapped), for: .touchUpInside)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        Auth.auth().removeStateDidChangeListener(handleAuth!)
    }

    func signIn(email: String, password: String){
        Auth.auth().signIn(withEmail: email, password: password)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let friend = usersList[indexPath.row]

        // Unwrap the signed-in user your VC tracks
        guard let cu = self.currentUser else {
            // Optional: show an alert that sign-in is required
            return
        }

        // Push chat screen
        let chatVC = ChatViewController(friend: friend, currentUser: cu)
        navigationController?.pushViewController(chatVC, animated: true)
    }
}
