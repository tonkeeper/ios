import UIKit

final class TooltipDatePickerViewController: UIViewController {
    private let completion: (Date) -> Void
    private let selectedDate: Date

    private lazy var datePicker: UIDatePicker = {
        let view = UIDatePicker()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.datePickerMode = .date
        view.preferredDatePickerStyle = .inline
        view.maximumDate = Date()
        view.date = selectedDate
        return view
    }()

    init(
        selectedDate: Date,
        completion: @escaping (Date) -> Void
    ) {
        self.selectedDate = selectedDate
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "First launch date"
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(didTapCancel)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(didTapSave)
        )

        view.addSubview(datePicker)
        NSLayoutConstraint.activate([
            datePicker.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            datePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            datePicker.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    @objc
    private func didTapCancel() {
        dismiss(animated: true)
    }

    @objc
    private func didTapSave() {
        completion(datePicker.date)
        dismiss(animated: true)
    }
}
