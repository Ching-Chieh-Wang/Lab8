//
//  MainScreenView.swift
//  App12
//
//  Created by Sakib Miazi on 6/2/23.
//

import UIKit

class MainScreenView: UIView {
    var profilePic: UIImageView!
    var labelText: UILabel!
    var buttonNewChat: UIButton!
    var tableViewChats: UITableView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .white
        
        setupProfilePic()
        setupLabelText()
        setupButtonNewChat()
        setupTableViewChats()
        initConstraints()
    }
    
    //MARK: initializing the UI elements...
    func setupProfilePic(){
        profilePic = UIImageView()
        profilePic.image = UIImage(systemName: "person.circle")?.withRenderingMode(.alwaysOriginal)
        profilePic.contentMode = .scaleToFill
        profilePic.clipsToBounds = true
        profilePic.layer.masksToBounds = true
        profilePic.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(profilePic)
    }
    
    func setupLabelText(){
        labelText = UILabel()
        labelText.font = .boldSystemFont(ofSize: 14)
        labelText.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(labelText)
    }
    
    func setupTableViewChats(){
        tableViewChats = UITableView(frame: .zero, style: .plain)
        tableViewChats.backgroundColor = UIColor.systemGray6
        tableViewChats.separatorStyle = .none
        tableViewChats.rowHeight = 72
        tableViewChats.showsVerticalScrollIndicator = false
        tableViewChats.layer.cornerRadius = 8
        tableViewChats.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        tableViewChats.register(ChatListCell.self, forCellReuseIdentifier: Configs.tableViewChatListID)
        tableViewChats.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(tableViewChats)
    }
    
    func setupButtonNewChat(){
        buttonNewChat = UIButton(type: .system)
        buttonNewChat.setTitle("", for: .normal)
        buttonNewChat.setImage(UIImage(systemName: "plus.bubble.fill")?.withRenderingMode(.alwaysOriginal), for: .normal)
        buttonNewChat.contentHorizontalAlignment = .fill
        buttonNewChat.contentVerticalAlignment = .fill
        buttonNewChat.imageView?.contentMode = .scaleAspectFit
        buttonNewChat.layer.cornerRadius = 16
        buttonNewChat.imageView?.layer.shadowOffset = .zero
        buttonNewChat.imageView?.layer.shadowRadius = 0.8
        buttonNewChat.imageView?.layer.shadowOpacity = 0.7
        buttonNewChat.imageView?.clipsToBounds = true
        buttonNewChat.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(buttonNewChat)
    }
    
    
    //MARK: setting up constraints...
    func initConstraints(){
        NSLayoutConstraint.activate([
            profilePic.widthAnchor.constraint(equalToConstant: 32),
            profilePic.heightAnchor.constraint(equalToConstant: 32),
            profilePic.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor, constant: 8),
            profilePic.leadingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            
            labelText.topAnchor.constraint(equalTo: profilePic.topAnchor),
            labelText.bottomAnchor.constraint(equalTo: profilePic.bottomAnchor),
            labelText.leadingAnchor.constraint(equalTo: profilePic.trailingAnchor, constant: 8),
            
            tableViewChats.topAnchor.constraint(equalTo: profilePic.bottomAnchor, constant: 8),
            tableViewChats.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            tableViewChats.leadingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            tableViewChats.trailingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            
            buttonNewChat.widthAnchor.constraint(equalToConstant: 48),
            buttonNewChat.heightAnchor.constraint(equalToConstant: 48),
            buttonNewChat.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            buttonNewChat.trailingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
