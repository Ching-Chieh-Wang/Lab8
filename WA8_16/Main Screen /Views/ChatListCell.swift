import UIKit

class ChatListCell: UITableViewCell {

    var wrapperCellView: UIView!
    var labelName: UILabel!
    var labelLastMessage: UILabel!
    var labelTime: UILabel!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setupWrapperCellView()
        setupLabelName()
        setupLabelLastMessage()
        setupLabelTime()
        initConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupWrapperCellView() {
        wrapperCellView = UIView()
        wrapperCellView.backgroundColor = .white
        wrapperCellView.layer.cornerRadius = 6.0
        wrapperCellView.layer.shadowColor = UIColor.gray.cgColor
        wrapperCellView.layer.shadowOffset = .zero
        wrapperCellView.layer.shadowRadius = 4.0
        wrapperCellView.layer.shadowOpacity = 0.4
        wrapperCellView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(wrapperCellView)
    }

    func setupLabelName() {
        labelName = UILabel()
        labelName.font = UIFont.boldSystemFont(ofSize: 18)
        labelName.translatesAutoresizingMaskIntoConstraints = false
        wrapperCellView.addSubview(labelName)
    }

    func setupLabelLastMessage() {
        labelLastMessage = UILabel()
        labelLastMessage.font = UIFont.systemFont(ofSize: 14)
        labelLastMessage.textColor = .gray
        labelLastMessage.translatesAutoresizingMaskIntoConstraints = false
        wrapperCellView.addSubview(labelLastMessage)
    }

    func setupLabelTime() {
        labelTime = UILabel()
        labelTime.font = UIFont.systemFont(ofSize: 12)
        labelTime.textColor = .lightGray
        labelTime.translatesAutoresizingMaskIntoConstraints = false
        wrapperCellView.addSubview(labelTime)
    }

    func initConstraints() {
        NSLayoutConstraint.activate([
            wrapperCellView.topAnchor.constraint(equalTo: self.topAnchor, constant: 8),
            wrapperCellView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 8),
            wrapperCellView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -8),
            wrapperCellView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -8),

            labelName.topAnchor.constraint(equalTo: wrapperCellView.topAnchor, constant: 8),
            labelName.leadingAnchor.constraint(equalTo: wrapperCellView.leadingAnchor, constant: 12),

            labelLastMessage.topAnchor.constraint(equalTo: labelName.bottomAnchor, constant: 4),
            labelLastMessage.leadingAnchor.constraint(equalTo: labelName.leadingAnchor),
            labelLastMessage.trailingAnchor.constraint(equalTo: wrapperCellView.trailingAnchor, constant: -12),

            labelTime.topAnchor.constraint(equalTo: wrapperCellView.topAnchor, constant: 8),
            labelTime.trailingAnchor.constraint(equalTo: wrapperCellView.trailingAnchor, constant: -12)
        ])
    }
}
