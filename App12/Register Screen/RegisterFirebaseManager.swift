//
//  RegisterFirebaseManager.swift
//  App12
//
//  Created by Sakib Miazi on 6/2/23.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

extension RegisterViewController{
    
    func registerNewAccount(){
        //MARK: display the progress indicator...
        showActivityIndicator()
        //MARK: create a Firebase user with email and password...
        if let name = registerView.textFieldName.text,
           let email = registerView.textFieldEmail.text,
           let password = registerView.textFieldPassword.text,
           let reenterPassword = registerView.textFieldReenterPassword.text {

            guard password == reenterPassword else {
                print("Passwords do not match.")
                self.hideActivityIndicator()
                return
            }

            Auth.auth().createUser(withEmail: email, password: password, completion: {result, error in
                if error == nil {
                    //MARK: the user creation is successful...
                    self.setNameOfTheUserInFirebaseAuth(name: name)
                    
                    if let uid = result?.user.uid {
                        let user = UserModel(id: uid, name: name, email: email)
                        let userAPI = UserAPI()
                        userAPI.saveUser(user) { err in
                            if let err = err {
                                print("Failed to save user to Firestore:", err)
                            } else {
                                print("User saved successfully to Firestore.")
                            }
                        }
                    }
                } else {
                    //MARK: there is a error creating the user...
                    print(error)
                }
            })
        }
    }
    
    //MARK: We set the name of the user after we create the account...
    func setNameOfTheUserInFirebaseAuth(name: String){
        let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
        changeRequest?.displayName = name
        changeRequest?.commitChanges(completion: {(error) in
            if error == nil{
                //MARK: the profile update is successful...
                
                //MARK: hide the progress indicator...
                self.hideActivityIndicator()
                
                //MARK: pop the current controller...
                self.navigationController?.popViewController(animated: true)
            }else{
                //MARK: there was an error updating the profile...
                print("Error occured: \(String(describing: error))")
            }
        })
    }
}
