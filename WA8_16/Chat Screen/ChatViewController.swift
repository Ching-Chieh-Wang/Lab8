//
//  ChatViewController.swift
//  App12
//
//  One-on-one chat with relative timestamps (“x minutes ago”, “yesterday”),
//  falling back to date+time for older messages. Larger multiline input above Send.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore   // for Timestamp.dateValue()

final class ChatViewController: UIViewController {

    // MARK: - Inputs
    private let friend: UserModel
    private let currentUser: FirebaseAuth.User

    // MARK: - Data
    private let api = MessageAPI()
    private var messages: [MessageModel] = []

    // MARK: - UI
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let inputContainer = UIView()
    private let inputTextView = UITextView()
    private let sendButton = UIButton(type: .system)

    // Constraints we’ll adjust
    private var inputBottomConstraint: NSLayoutConstraint!
    private var inputTextViewHeight: NSLayoutConstraint!

    // MARK: - Time formatters
    private lazy var relativeFmt: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full   // .short -> "5 min ago"; .full -> "5 minutes ago"
        return f
    }()

    private lazy var absoluteFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    /// Popular UX: relative for recent (“5 minutes ago”), “yesterday” for 1 day,
    /// then absolute date+time after 7 days.
    private func prettyTimestamp(for date: Date, now: Date = Date()) -> String {
        if Calendar.current.isDateInYesterday(date) { return "yesterday" }
        let days = Calendar.current.dateComponents([.day], from: date, to: now).day ?? 0
        if days >= 7 { return absoluteFmt.string(from: date) }
        return relativeFmt.localizedString(for: date, relativeTo: now)
    }

    // MARK: - Init
    init(friend: UserModel, currentUser: FirebaseAuth.User) {
        self.friend = friend
        self.currentUser = currentUser
        super.init(nibName: nil, bundle: nil)
        self.title = friend.name
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupTable()
        setupInputArea()
        registerKeyboardObservers()
        startListening()
        updateSendState()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - UI Setup
    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        tableView.alwaysBounceVertical = true
        tableView.keyboardDismissMode = .interactive
        tableView.contentInset.bottom = 6
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MessageCell.self, forCellReuseIdentifier: MessageCell.reuseID)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
        ])
    }

    private func setupInputArea() {
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.backgroundColor = .secondarySystemBackground
        view.addSubview(inputContainer)

        // Larger multi-line chat box above the Send button
        inputTextView.translatesAutoresizingMaskIntoConstraints = false
        inputTextView.font = .systemFont(ofSize: 16)
        inputTextView.isScrollEnabled = false
        inputTextView.backgroundColor = .white
        inputTextView.layer.cornerRadius = 10
        inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        inputTextView.delegate = self
        inputContainer.addSubview(inputTextView)

        // Send button below the box
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle("Send", for: .normal)
        sendButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        sendButton.addTarget(self, action: #selector(onSendTapped), for: .touchUpInside)
        inputContainer.addSubview(sendButton)

        // Bottom attachment
        inputBottomConstraint = inputContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)

        // Height of the text view (auto-growing 56...120)
        inputTextViewHeight = inputTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 56)

        NSLayoutConstraint.activate([
            inputContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            inputBottomConstraint,

            inputTextView.topAnchor.constraint(equalTo: inputContainer.topAnchor, constant: 8),
            inputTextView.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 12),
            inputTextView.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -12),
            inputTextViewHeight,

            sendButton.topAnchor.constraint(equalTo: inputTextView.bottomAnchor, constant: 8),
            sendButton.trailingAnchor.constraint(equalTo: inputTextView.trailingAnchor),
            sendButton.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -8),

            tableView.bottomAnchor.constraint(equalTo: inputContainer.topAnchor),
        ])
    }

    // MARK: - Keyboard handling
    private func registerKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboard(notification:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboard(notification:)),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func onKeyboard(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
              let curveRaw = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }

        let isHiding = notification.name == UIResponder.keyboardWillHideNotification
        let kbHeight = isHiding ? 0 : max(0, view.convert(endFrame, from: nil).intersection(view.bounds).height)

        inputBottomConstraint.constant = -kbHeight

        UIView.animate(withDuration: duration,
                       delay: 0,
                       options: UIView.AnimationOptions(rawValue: curveRaw << 16),
                       animations: {
                           self.view.layoutIfNeeded()
                           if !self.messages.isEmpty { self.scrollToBottom(animated: false) }
                       },
                       completion: nil)
    }

    // MARK: - Messaging
    private func startListening() {
        api.listenForMessages(between: currentUser.uid, and: friend.id) { [weak self] newMessages, error in
            guard let self = self else { return }
            if let error = error {
                print("listen error:", error)
                return
            }
            let msgs = newMessages ?? []
            self.messages = msgs.sorted { $0.timestamp.dateValue() < $1.timestamp.dateValue() }
            self.tableView.reloadData()
            self.scrollToBottom(animated: false)
        }
    }

    @objc private func onSendTapped() { sendCurrentText() }

    private func sendCurrentText() {
        let text = inputTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let senderName = currentUser.displayName ?? "Me"
        api.sendMessage(from: currentUser.uid, to: friend.id, text: text, senderName: senderName) { [weak self] error in
            if let error = error { print("send error:", error) }
            self?.inputTextView.text = ""
            self?.resizeTextViewIfNeeded()
            self?.updateSendState()
        }
    }

    private func scrollToBottom(animated: Bool) {
        let count = messages.count
        guard count > 0 else { return }
        let index = IndexPath(row: count - 1, section: 0)
        tableView.scrollToRow(at: index, at: .bottom, animated: animated)
    }

    // MARK: - Input helpers
    private func updateSendState() {
        let trimmed = inputTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let enabled = !trimmed.isEmpty
        sendButton.isEnabled = enabled
        sendButton.alpha = enabled ? 1.0 : 0.5
    }

    private func resizeTextViewIfNeeded() {
        let fitting = CGSize(width: inputTextView.bounds.width, height: .greatestFiniteMagnitude)
        let target = inputTextView.sizeThatFits(fitting).height
        let clamped = min(max(target, 56), 120) // grow between 56…120pt
        inputTextViewHeight.constant = clamped
        view.layoutIfNeeded()
    }
}

// MARK: - UITableViewDataSource/Delegate
extension ChatViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { messages.count }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let msg = messages[indexPath.row]
        let isMe = msg.senderId == currentUser.uid

        // Hide time if previous message is same sender within 2 minutes
        var showTime = true
        if indexPath.row > 0 {
            let prev = messages[indexPath.row - 1]
            let sameSender = prev.senderId == msg.senderId
            let delta = msg.timestamp.dateValue().timeIntervalSince(prev.timestamp.dateValue())
            showTime = !(sameSender && delta <= 120)
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: MessageCell.reuseID,
                                                 for: indexPath) as! MessageCell
        let timeText = prettyTimestamp(for: msg.timestamp.dateValue())
        cell.configure(with: msg, isMe: isMe, showTime: showTime, timeText: timeText)
        return cell
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat { 66 }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { UITableView.automaticDimension }
}

// MARK: - UITextViewDelegate
extension ChatViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        resizeTextViewIfNeeded()
        updateSendState()
    }

    // Cmd+Return sends; Return inserts newline
    override var keyCommands: [UIKeyCommand]? {
        [UIKeyCommand(input: "\r", modifierFlags: [.command], action: #selector(onSendTapped), discoverabilityTitle: "Send")]
    }
}

// MARK: - Bubble cell with timestamp
fileprivate final class MessageCell: UITableViewCell {
    static let reuseID = "MessageCell"

    private let bubble = UIView()
    private let label = UILabel()
    private let timeLabel = UILabel()

    private var leading: NSLayoutConstraint!
    private var trailing: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        bubble.translatesAutoresizingMaskIntoConstraints = false
        bubble.layer.cornerRadius = 16
        bubble.layer.masksToBounds = true

        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16)

        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = .systemFont(ofSize: 12)
        timeLabel.textColor = .secondaryLabel
        timeLabel.numberOfLines = 1
        timeLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        contentView.addSubview(bubble)
        bubble.addSubview(label)
        contentView.addSubview(timeLabel)

        leading  = bubble.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        trailing = bubble.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)

        NSLayoutConstraint.activate([
            bubble.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            leading, trailing,
            bubble.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75),

            label.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -10),
            label.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -12),

            timeLabel.topAnchor.constraint(equalTo: bubble.bottomAnchor, constant: 4),
            timeLabel.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 4),
            timeLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),
            timeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with message: MessageModel, isMe: Bool, showTime: Bool, timeText: String) {
        label.text = message.text
        timeLabel.text = timeText
        timeLabel.isHidden = !showTime

        if isMe {
            // my bubble on the right
            leading.isActive = false
            trailing.isActive = true
            bubble.backgroundColor = UIColor.systemBlue
            label.textColor = .white
            timeLabel.textAlignment = .right
        } else {
            // friend bubble on the left
            trailing.isActive = false
            leading.isActive = true
            bubble.backgroundColor = UIColor.secondarySystemBackground
            label.textColor = .label
            timeLabel.textAlignment = .left
        }
        contentView.layoutIfNeeded()
    }
}
