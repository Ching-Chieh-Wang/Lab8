import UIKit
import FirebaseFirestore
import FirebaseAuth

class ChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let userAPI = UserAPI()
    private var users: [UserModel] = []
    var currentUser: User?
    var friend: UserModel

    init(friend: UserModel) {
        self.friend = friend
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Start New Chat"
        view.backgroundColor = .systemBackground

        setupTableView()
        fetchUsers()
    }

    private func setupTableView() {
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "UserCell")
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
        ])
    }

    private func fetchUsers() {
        userAPI.getAllUsers { [weak self] users, error in
            guard let self = self else { return }
            if let error = error {
                print("Error fetching users: \(error)")
                return
            }
            if let currentId = Auth.auth().currentUser?.uid {
                self.users = users?.filter { $0.id != currentId } ?? []
            }
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        users.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath)
        cell.textLabel?.text = users[indexPath.row].name
        cell.detailTextLabel?.text = users[indexPath.row].email
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let friend = users[indexPath.row]
        let chatVC = ChatViewController(friend: friend)
        navigationController?.pushViewController(chatVC, animated: true)
    }
}
