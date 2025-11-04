//
//  ContactsTableViewManager.swift
//  App12
//
//  Created by Sakib Miazi on 6/2/23.
//

import Foundation
import UIKit

extension ViewController {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return usersList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Configs.tableViewChatListID, for: indexPath) as! ChatListCell
        cell.labelName.text = usersList[indexPath.row].name
        cell.labelLastMessage.text = usersList[indexPath.row].email
        cell.labelTime.text = ""
        return cell
    }
}
