//
//  ChatViewController.swift
//  App12
//
//  One-on-one chat with relative timestamps (“x minutes ago”, “yesterday”),
//  falling back to date+time for older messages. Larger multiline input above Send.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

final class ChatViewController: UIViewController {

    // MARK: - Inputs
    private let friend: UserModel
    private let currentUser: FirebaseAuth.User

    // MARK: - Data / API
    private let api = MessageAPI()
    private var messages: [MessageModel] = []
    private var liveListener: ListenerRegistration?

    // Pagination
    private var isLoadingMore = false
    private var hasMore = true
    private var oldestLoadedTimestamp: Timestamp?

    // User interaction flags
    private var userIsInteracting = false
    private var didDoInitialScroll = false

    // MARK: - UI
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let refresh = UIRefreshControl()

    private let inputContainer = UIView()
    private let inputTextView = UITextView()
    private let sendButton = UIButton(type: .system)

    private var inputBottomConstraint: NSLayoutConstraint!
    private var inputTextViewHeight: NSLayoutConstraint!

    // MARK: - Time formatters
    private lazy var relativeFmt: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()
    private lazy var absoluteFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
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
        startLiveTail()
        updateSendState()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateTableInsets()
        // Do an initial bottom scroll exactly once if content exists
        if !didDoInitialScroll, messages.count > 0 {
            didDoInitialScroll = true
            DispatchQueue.main.async { [weak self] in self?.scrollToBottom(animated: false) }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        liveListener?.remove()
        liveListener = nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        liveListener?.remove()
    }

    // MARK: - UI setup
    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        tableView.alwaysBounceVertical = true
        tableView.keyboardDismissMode = .interactive
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MessageCell.self, forCellReuseIdentifier: MessageCell.reuseID)
        view.addSubview(tableView)

        // Pull to load older messages
        refresh.addTarget(self, action: #selector(loadOlderPage), for: .valueChanged)
        tableView.refreshControl = refresh

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

        inputTextView.translatesAutoresizingMaskIntoConstraints = false
        inputTextView.font = .systemFont(ofSize: 16)
        inputTextView.isScrollEnabled = false
        inputTextView.backgroundColor = .white
        inputTextView.layer.cornerRadius = 10
        inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        inputTextView.delegate = self
        inputContainer.addSubview(inputTextView)

        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle("Send", for: .normal)
        sendButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        sendButton.addTarget(self, action: #selector(onSendTapped), for: .touchUpInside)
        inputContainer.addSubview(sendButton)

        inputBottomConstraint = inputContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
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

    // MARK: - Insets to keep last message visible
    private func updateTableInsets() {
        inputContainer.layoutIfNeeded()
        let barHeight = inputContainer.bounds.height
        let bottomInset = barHeight + 12
        tableView.contentInset.bottom = bottomInset
        tableView.scrollIndicatorInsets.bottom = bottomInset
    }

    // Are we close enough to the bottom to auto-stick?
    private func isNearBottom(threshold: CGFloat = 60) -> Bool {
        tableView.layoutIfNeeded()
        let contentH = tableView.contentSize.height
        if contentH <= 0 { return true }
        let visibleH = tableView.bounds.height
        let bottomY = contentH + tableView.contentInset.bottom - visibleH
        return tableView.contentOffset.y >= bottomY - threshold
    }

    // MARK: - Keyboard
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

        let shouldStick = isNearBottom() // capture BEFORE layout change
        inputBottomConstraint.constant = -kbHeight

        UIView.animate(withDuration: duration,
                       delay: 0,
                       options: UIView.AnimationOptions(rawValue: curveRaw << 16),
                       animations: {
                           self.view.layoutIfNeeded()
                           self.updateTableInsets()
                           // only autoscroll if user was near bottom
                           if shouldStick, !self.messages.isEmpty {
                               self.scrollToBottom(animated: false)
                           }
                       },
                       completion: nil)
    }

    // MARK: - Live tail
    private func startLiveTail(limit: Int = 30) {
        liveListener?.remove()
        liveListener = api.listenForLatestMessages(between: currentUser.uid, and: friend.id, limit: limit) { [weak self] latest, error in
            guard let self = self else { return }
            if let error = error {
                print("listen error:", error)
                return
            }
            let tail = latest ?? []

            // Capture stickiness BEFORE we mutate data
            let shouldStick = self.isNearBottom()

            // Merge: keep already-loaded older pages (< first tail timestamp),
            // then append the latest tail; de-dupe by id.
            let olderPart: [MessageModel]
            if let firstTail = tail.first?.timestamp.dateValue() {
                olderPart = self.messages.filter { $0.timestamp.dateValue() < firstTail }
            } else {
                olderPart = []
            }
            let tailIds = Set(tail.map { $0.id })
            let keptOlder = olderPart.filter { !tailIds.contains($0.id) }

            var merged = keptOlder + tail
            var seen = Set<String>()
            merged = merged.filter { seen.insert($0.id).inserted }

            self.messages = merged
            self.oldestLoadedTimestamp = self.messages.first?.timestamp
            self.hasMore = (self.oldestLoadedTimestamp != nil)

            self.tableView.reloadData()
            self.updateTableInsets()

            // Only snap to bottom if user was already near bottom (or we haven't scrolled yet)
            if (shouldStick || !self.didDoInitialScroll), !self.messages.isEmpty {
                self.scrollToBottom(animated: false)
                self.didDoInitialScroll = true
            }
        }
    }

    // MARK: - Pagination (pull to refresh)
    @objc private func loadOlderPage() {
        guard !isLoadingMore, hasMore, let cursor = oldestLoadedTimestamp else {
            refresh.endRefreshing()
            return
        }
        isLoadingMore = true

        let beforeHeight = tableView.contentSize.height

        api.fetchOlderMessages(between: currentUser.uid, and: friend.id, before: cursor, limit: 30) { [weak self] chunk, error in
            guard let self = self else { return }
            self.refresh.endRefreshing()
            self.isLoadingMore = false

            if let error = error {
                print("older fetch error:", error)
                return
            }
            let older = chunk ?? []
            if older.isEmpty {
                self.hasMore = false
                return
            }

            // Prepend, de-dupe by id
            var seen = Set(self.messages.map { $0.id })
            let uniques = older.filter { seen.insert($0.id).inserted }
            self.messages.insert(contentsOf: uniques, at: 0)
            self.oldestLoadedTimestamp = self.messages.first?.timestamp

            self.tableView.reloadData()
            self.tableView.layoutIfNeeded()

            // Preserve current viewport (no jump to bottom during pagination)
            let afterHeight = self.tableView.contentSize.height
            let delta = afterHeight - beforeHeight
            self.tableView.contentOffset.y += delta

            self.updateTableInsets()
        }
    }

    // MARK: - Send
    @objc private func onSendTapped() { sendCurrentText() }

    private func sendCurrentText() {
        let text = inputTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let senderName = currentUser.displayName ?? "Me"
        sendButton.isEnabled = false
        api.sendMessage(from: currentUser.uid, to: friend.id, text: text, senderName: senderName) { [weak self] error in
            guard let self = self else { return }
            self.sendButton.isEnabled = true
            if let error = error {
                print("send error:", error)
                return
            }
            // Don't append locally; listener will deliver it.
            self.inputTextView.text = ""
            self.resizeTextViewIfNeeded()
            self.updateSendState()

            // After sending, we WANT to stick to bottom
            self.scrollToBottom(animated: true)
            self.didDoInitialScroll = true
        }
    }

    // MARK: - Helpers
    private func scrollToBottom(animated: Bool) {
        let count = messages.count
        guard count > 0 else { return }
        let index = IndexPath(row: count - 1, section: 0)
        tableView.scrollToRow(at: index, at: .bottom, animated: animated)
    }

    private func updateSendState() {
        let trimmed = inputTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let enabled = !trimmed.isEmpty
        sendButton.isEnabled = enabled
        sendButton.alpha = enabled ? 1.0 : 0.5
    }

    private func resizeTextViewIfNeeded() {
        let fitting = CGSize(width: inputTextView.bounds.width, height: .greatestFiniteMagnitude)
        let target = inputTextView.sizeThatFits(fitting).height
        let clamped = min(max(target, 56), 120)
        let shouldStick = isNearBottom()
        inputTextViewHeight.constant = clamped
        view.layoutIfNeeded()
        updateTableInsets()
        if shouldStick, !messages.isEmpty {
            scrollToBottom(animated: false)
        }
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

    // Track user interaction so we don’t fight their scroll
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { userIsInteracting = true }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { userIsInteracting = false }
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { userIsInteracting = false }
}

// MARK: - UITextViewDelegate
extension ChatViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        resizeTextViewIfNeeded()
        updateSendState()
    }

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
            leading.isActive = false
            trailing.isActive = true
            bubble.backgroundColor = UIColor.systemBlue
            label.textColor = .white
            timeLabel.textAlignment = .right
        } else {
            trailing.isActive = false
            leading.isActive = true
            bubble.backgroundColor = UIColor.secondarySystemBackground
            label.textColor = .label
            timeLabel.textAlignment = .left
        }
        contentView.layoutIfNeeded()
    }
}
