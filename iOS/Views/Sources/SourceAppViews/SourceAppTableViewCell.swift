//
//  SourceAppTableViewCell.swift
//  feather
//
//  Created by samara on 5/22/24.
//

import Foundation
import UIKit

class SourceAppTableViewCell: UITableViewCell {

	public var appDownload: AppDownload?
	private var progressObserver: NSObjectProtocol?

	private let progressLayer = CAShapeLayer()
	private var getButtonWidthConstraint: NSLayoutConstraint?
	private var buttonImage: UIImage?
	
	let nameLabel: UILabel = {
		let label = UILabel()
		label.font = UIFont.boldSystemFont(ofSize: 17)
		label.numberOfLines = 0
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()

	let versionLabel: UILabel = {
		let label = UILabel()
		label.font = UIFont.systemFont(ofSize: 13)
		label.textColor = .secondaryLabel
		label.numberOfLines = 0
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()

	let detailLabel: UILabel = {
		let label = UILabel()
		label.font = UIFont.systemFont(ofSize: 11)
		label.textColor = .secondaryLabel
		label.numberOfLines = 0
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()

	let getButton: UIButton = {
		let button = UIButton(type: .system)
		button.layer.cornerRadius = 15
		button.layer.backgroundColor = UIColor(named: "Cells")?.cgColor
		button.translatesAutoresizingMaskIntoConstraints = false
		return button
	}()

	private func setupViews() {
		contentView.addSubview(nameLabel)
		contentView.addSubview(versionLabel)
		contentView.addSubview(detailLabel)
		contentView.addSubview(getButton)

		imageView?.translatesAutoresizingMaskIntoConstraints = true
		getButtonWidthConstraint = getButton.widthAnchor.constraint(equalToConstant: 60)

		NSLayoutConstraint.activate([
			nameLabel.leadingAnchor.constraint(equalTo: imageView!.trailingAnchor, constant: 15),
			nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
			nameLabel.trailingAnchor.constraint(equalTo: getButton.leadingAnchor, constant: -10),

			versionLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
			versionLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
			versionLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),

			detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
			detailLabel.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 4),
			detailLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
			detailLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

			getButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
			getButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
			getButtonWidthConstraint!,
			getButton.heightAnchor.constraint(equalToConstant: 30)
		])
	}

	private func configureGetButtonArrow() {
		let symbolConfig = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
		buttonImage = UIImage(systemName: "arrow.down", withConfiguration: symbolConfig)
		getButton.setImage(buttonImage, for: .normal)
		getButton.tintColor = Preferences.appTintColor.uiColor
	}

	private func configureGetButtonSquare() {
		let symbolConfig = UIImage.SymbolConfiguration(pointSize: 9, weight: .bold)
		buttonImage = UIImage(systemName: "square.fill", withConfiguration: symbolConfig)
		getButton.setImage(buttonImage, for: .normal)
		getButton.tintColor = Preferences.appTintColor.uiColor
	}

	private func configureProgressLayer() {
		progressLayer.strokeColor = Preferences.appTintColor.uiColor.cgColor
		progressLayer.lineWidth = 3.0
		progressLayer.fillColor = nil
		progressLayer.lineCap = .round
		progressLayer.strokeEnd = 0.0

		let circularPath = UIBezierPath(roundedRect: getButton.bounds, cornerRadius: 15)
		progressLayer.path = circularPath.cgPath
		getButton.layer.addSublayer(progressLayer)
	}
	
	private func addObservers() {
		progressObserver = NotificationCenter.default.addObserver(forName: .downloadProgressUpdated, object: nil, queue: .main) { [weak self] notification in
			guard let self = self,
				  let userInfo = notification.userInfo,
				  let uuid = userInfo["uuid"] as? String,
				  self.appDownload?.AppUUID == uuid else { return }
		}
	}
	
	//MARK: - Configure
	
	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		setupViews()
		configureGetButtonArrow()
		configureProgressLayer()
		addObservers()
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		updateProgressLayerPath()
	}

	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)
		getButton.layer.backgroundColor = UIColor(named: "Cells")?.cgColor
		updateProgressLayerPath()
	}

	deinit {
		if let observer = progressObserver {
			NotificationCenter.default.removeObserver(observer)
		}
	}

	func configure(with app: StoreApps) {

		var name = app.name
		if app.bundleIdentifier!.hasSuffix("Beta") {
			name! += " (Beta)"
		}
		nameLabel.text = name
		var desc = app.developerName ?? "Unknown"
		desc += " • "

		if let firstApp = app.versions?.firstObject as? StoreVersions,
		   let firstAppIconURL = firstApp.version {
			desc += firstAppIconURL
		} else {
			desc += app.version ?? ""
		}

		versionLabel.text = desc
		detailLabel.text = app.subtitle ?? "An awesome application!"

		updateDownloadState(uuid: app.uuid!)
	}
	
//MARK: - Changing states

	private func updateDownloadState(uuid: String?) {
		guard let appUUID = uuid else {
			return
		}
		
		DownloadTaskManager.shared.restoreTaskState(for: appUUID, cell: self)
				
		if let task = DownloadTaskManager.shared.task(for: appUUID) {
			switch task.state {
			case .inProgress(_):
				DispatchQueue.main.async {
					self.startDownload()
				}
			default:
				break
			}
		}
	}

	func updateProgress(to value: CGFloat) {
		DispatchQueue.main.async {
			self.progressLayer.strokeEnd = value
		}
	}

	func startDownload() {
		DispatchQueue.main.async {
			UIView.animate(withDuration: 0.3, animations: {
				self.getButtonWidthConstraint?.constant = 30
				self.layoutIfNeeded()
				self.configureGetButtonSquare()
				self.updateProgressLayerPath()
			})
		}
	}

	func stopDownload() {
		DispatchQueue.main.async {
			UIView.animate(withDuration: 0.3, animations: {
				self.getButtonWidthConstraint?.constant = 60
				self.progressLayer.strokeEnd = 0.0
				self.configureGetButtonArrow()
				self.layoutIfNeeded()
			})
		}
	}
	
	func cancelDownload() {
		DispatchQueue.main.async {
			self.appDownload?.cancelDownload()
			self.stopDownload()
		}
	}

	private func updateProgressLayerPath() {
		let circularPath = UIBezierPath(roundedRect: getButton.bounds, cornerRadius: 15)
		progressLayer.path = circularPath.cgPath
	}
}