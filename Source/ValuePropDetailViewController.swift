//
//  ValuePropDetailViewController.swift
//  edX
//
//  Created by Salman on 19/11/2020.
//  Copyright © 2020 edX. All rights reserved.
//

import UIKit

enum ValuePropModalType {
    case courseEnrollment
    case courseUnit
}

class ValuePropDetailViewController: UIViewController, InterfaceOrientationOverriding {
    
    typealias Environment = OEXAnalyticsProvider & OEXStylesProvider & ReachabilityProvider & NetworkManagerProvider & OEXConfigProvider & OEXInterfaceProvider
    
    private lazy var valuePropTableView: ValuePropMessagesView = {
        let tableView = ValuePropMessagesView()
        tableView.accessibilityIdentifier = "ValuePropDetailViewController:table-view"
        return tableView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.attributedText = titleStyle.attributedString(withText: Strings.ValueProp.upgrade(courseName: course.name ?? "")).setLineSpacing(4)
        label.accessibilityIdentifier = "ValuePropDetailViewController:title-label"
        return label
    }()
    
    private lazy var upgradeButton: CourseUpgradeButtonView = {
        let upgradeButton = CourseUpgradeButtonView()
        upgradeButton.tapAction = { [weak self] in
            self?.upgradeCourse()
        }
        upgradeButton.accessibilityIdentifier = "ValuePropDetailViewController:upgrade-button"
        return upgradeButton
    }()
    
    private var titleStyle: OEXMutableTextStyle = {
        let style = OEXMutableTextStyle(weight: .bold, size: .xxLarge, color: OEXStyles.shared().primaryDarkColor())
        style.alignment = .left
        return style
    }()
    
    private let crossButtonSize: CGFloat = 20
    
    private var type: ValuePropModalType
    private let course: OEXCourse
    private let environment: Environment
    
    init(type: ValuePropModalType, course: OEXCourse, environment: Environment) {
        self.type = type
        self.course = course
        self.environment = environment
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = environment.styles.neutralWhiteT()
                
        navigationController?.navigationBar.apply(barTintColor: environment.styles.neutralWhiteT(), tintColor: environment.styles.primaryBaseColor(), clearShadow: true)
        
        configureView()
        
        PaymentManager.shared.productPrice(TestInAppPurchaseID) { [weak self] price in
            if let price = price {
                self?.upgradeButton.setPrice(price)
            }
        }
    }
    
    private func configureView() {
        addSubviews()
        setConstraints()
    }
    
    private func addSubviews() {
        view.addSubview(titleLabel)
        view.addSubview(valuePropTableView)
        view.addSubview(upgradeButton)
        addCloseButton()
    }
    
    private func addCloseButton() {
        let closeButton = UIBarButtonItem(image: Icon.Close.imageWithFontSize(size: crossButtonSize), style: .plain, target: nil, action: nil)
        closeButton.accessibilityLabel = Strings.Accessibility.closeLabel
        closeButton.accessibilityHint = Strings.Accessibility.closeHint
        closeButton.accessibilityIdentifier = "ValuePropDetailView:close-button"
        navigationItem.rightBarButtonItem = closeButton
        
        closeButton.oex_setAction { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }
    }
    
    private func setConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(view).offset(StandardHorizontalMargin)
            make.trailing.equalTo(view).inset(StandardHorizontalMargin)
            make.top.equalTo(view).offset(StandardVerticalMargin * 5)
        }
        
        valuePropTableView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel).inset(-StandardHorizontalMargin / 2)
            make.trailing.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(StandardVerticalMargin)
            make.bottom.equalTo(upgradeButton.snp.top).offset(-StandardVerticalMargin)
        }
        
        upgradeButton.snp.makeConstraints { make in
            make.leading.equalTo(valuePropTableView)
            make.trailing.equalTo(valuePropTableView)
            make.bottom.equalTo(safeBottom).inset(StandardVerticalMargin)
            make.height.equalTo(CourseUpgradeButtonView.height)
        }
    }
    
    private func upgradeCourse() {
        disableAppTouchs()
        
        let pacing = course.isSelfPaced ? "self" : "instructor"
        environment.analytics.trackUpgradeNow(with: course.course_id ?? "", blockID: TestInAppPurchaseID, pacing: pacing)
        
        CourseUpgradeHandler.shared.upgradeCourse(course, environment: environment) { [weak self] status in
            guard let topController = UIApplication.shared.topMostController() else {
                self?.enableAppTouches()
                return
            }
            
            switch status {
            case .payment:
                self?.upgradeButton.stopAnimating()
                break
            case .complete:
                self?.enableAppTouches()
                self?.upgradeButton.isHidden = true
                let alertController = UIAlertController().showAlert(withTitle: Strings.CourseUpgrade.successAlertTitle, message: Strings.CourseUpgrade.successAlertMessage, cancelButtonTitle: nil, onViewController: topController) { _, _, _ in }
                alertController.addButton(withTitle: Strings.CourseUpgrade.successAlertContinue, style: .cancel) { action in
                    // TODO: continue button handling
                }
                break
            case .error:
                self?.enableAppTouches()
                self?.upgradeButton.stopAnimating()
                let alertController = UIAlertController().showAlert(withTitle: Strings.CourseUpgrade.failureAlertTitle, message: Strings.CourseUpgrade.failureAlertMessage, cancelButtonTitle: nil, onViewController: topController) { _, _, _ in }
                alertController.addButton(withTitle: Strings.CourseUpgrade.failureAlertGetHelp) { action in
                    // TODO: Add option to send email
                }
                alertController.addButton(withTitle: Strings.close, style: .default) { action in
                    // TODO: Close button handling
                }
                break
            default:
                break
            }
        }
    }
    
    private func disableAppTouchs() {
        DispatchQueue.main.async {
            if !UIApplication.shared.isIgnoringInteractionEvents {
                UIApplication.shared.beginIgnoringInteractionEvents()
            }
        }
    }
    
    private func enableAppTouches() {
        DispatchQueue.main.async {
            if UIApplication.shared.isIgnoringInteractionEvents {
                UIApplication.shared.endIgnoringInteractionEvents()
            }
        }
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .allButUpsideDown
    }
}
