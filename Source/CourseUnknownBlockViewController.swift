//
//  CourseUnknownBlockViewController.swift
//  edX
//
//  Created by Ehmad Zubair Chughtai on 20/05/2015.
//  Copyright (c) 2015 edX. All rights reserved.
//

import UIKit

class CourseUnknownBlockViewController: UIViewController, CourseBlockViewController {
    
    typealias Environment = DataManagerProvider & OEXInterfaceProvider & OEXAnalyticsProvider & OEXConfigProvider & OEXStylesProvider & OEXRouterProvider & DataManagerProvider & RemoteConfigProvider & ReachabilityProvider & NetworkManagerProvider
    
    private let environment: Environment
    
    let blockID: CourseBlockID?
    let courseID: String
    
    var block: CourseBlock? {
        didSet {
            navigationItem.title = block?.displayName
        }
    }
    
    private var messageView: IconMessageView?
    private lazy var valuePropView: ValuePropComponentView = {
        let view = ValuePropComponentView(environment: environment, courseID: courseID, blockID: blockID)
        view.delegate = self
        return view
    }()
    
    private var loader: OEXStream<URL?>?
    
    init(blockID: CourseBlockID?, courseID: String, environment: Environment) {
        self.blockID = blockID
        self.courseID = courseID
        self.environment = environment
        
        super.init(nibName: nil, bundle: nil)
        
        let courseQuerier = environment.dataManager.courseDataManager.querierForCourseWithID(courseID: self.courseID, environment: environment)
        courseQuerier.blockWithID(id: blockID).extendLifetimeUntilFirstResult (
            success: { [weak self] block in
                self?.block = block
                if let video = block.type.asVideo, video.isYoutubeVideo {
                    self?.showYoutubeMessage(buttonTitle: Strings.Video.viewOnYoutube, message: Strings.Video.onlyOnYoutube, icon: Icon.CourseVideos, videoUrl: video.videoURL)
                } else {
                    self?.showError()
                }
            },
            failure: { [weak self] _ in
                self?.showError()
            }
        )
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = environment.styles.standardBackgroundColor()
    }
    
    override func updateViewConstraints() {
        if isVerticallyCompact() {
            applyLandscapeConstraints()
        } else {
            applyPortraitConstraints()
        }
        
        super.updateViewConstraints()
    }
    
    private func showYoutubeMessage(buttonTitle: String, message: String, icon: Icon, videoUrl: String?) {
        messageView = IconMessageView(icon: icon, message: message)
        messageView?.buttonInfo = MessageButtonInfo(title : buttonTitle) {
            guard let videoURL = videoUrl, let url = URL(string: videoURL), UIApplication.shared.canOpenURL(url) else { return }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        
        if let messageView = messageView {
            view.addSubview(messageView)
        }
    }
    
    private func showError() {
        guard let block = block else {
            showCourseContentUnknownView()
            return
        }
        
        if block.specialExamInfo != nil {
            showSpecialExamMessageView(blockID: block.blockID)
        } else if (block.type == .Section && block.children.isEmpty) {
            showEmptySubsectionMessageView(blockID: block.blockID)
        } else if block.isGated {
            if environment.remoteConfig.valuePropEnabled {
                environment.analytics.trackLockedContentClicked(courseID: courseID, screenName: .CourseUnit, assignmentID: block.blockID)
                showValuePropMessageView()
            } else {
                showGatedContentMessageView()
            }
        }
        else {
            showCourseContentUnknownView()
        }
    }
    
    private func showSpecialExamMessageView(blockID: CourseBlockID) {
        let info = [ AnalyticsEventDataKey.SubsectionID.rawValue: blockID ]
        environment.analytics.trackScreen(withName: AnalyticsScreenName.SpecialExamBlockedScreen.rawValue, courseID: courseID, value: nil, additionalInfo: info)
        
        configureIconMessage(with: IconMessageView(icon: Icon.CourseUnknownContent, message: Strings.courseContentNotAvailable))
    }
    
    private func showEmptySubsectionMessageView(blockID: CourseBlockID) {
        let info = [ AnalyticsEventDataKey.SubsectionID.rawValue: blockID ]
        environment.analytics.trackScreen(withName: AnalyticsScreenName.EmptySectionOutline.rawValue, courseID: courseID, value: nil, additionalInfo: info)
        
        configureIconMessage(with: IconMessageView(icon: Icon.CourseUnknownContent, message: Strings.courseContentNotAvailable))
    }
    
    private func showGatedContentMessageView() {
        configureIconMessage(with: IconMessageView(icon: Icon.Closed, message: Strings.courseContentGated))
    }
    
    private func showCourseContentUnknownView() {
        configureIconMessage(with: IconMessageView(icon: Icon.CourseUnknownContent, message: Strings.courseContentUnknown))
    }
    
    private func configureIconMessage(with iconView: IconMessageView) {
        messageView = iconView
        
        messageView?.buttonInfo = MessageButtonInfo(title : Strings.openInBrowser) { [weak self] in
            guard let weakSelf = self else { return }
            weakSelf.loader?.listen(weakSelf, success : { url in
                guard let url = url, UIApplication.shared.canOpenURL(url) else { return }
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                weakSelf.trackBroswerEvent()
            }, failure : { _ in })
        }
        if let messageView = messageView {
            view.addSubview(messageView)
        }
    }
    
    private func showValuePropMessageView() {
        view.addSubview(valuePropView)
        view.backgroundColor = OEXStyles.shared().neutralWhiteT()
        
        valuePropView.snp.makeConstraints { make in
            make.top.equalTo(view).offset(StandardVerticalMargin * 2)
            make.leading.equalTo(view)
            make.trailing.equalTo(view)
            make.bottom.equalTo(view)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func applyPortraitConstraints() {
        messageView?.snp.remakeConstraints { make in
            make.edges.equalTo(safeEdges)
        }
    }
    
    private func applyLandscapeConstraints() {
        messageView?.snp.remakeConstraints { make in
            make.edges.equalTo(safeEdges)
            let barHeight = navigationController?.toolbar.frame.size.height ?? 0.0
            make.bottom.equalTo(safeBottom).offset(-barHeight)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        loader = environment.dataManager.courseDataManager.querierForCourseWithID(courseID: courseID, environment: environment).blockWithID(id: blockID).map { $0.webURL as URL? }.firstSuccess()
    }
    
    private func trackBroswerEvent() {
        guard let block = block else { return }
        
        if block.specialExamInfo != nil {
            environment.analytics.trackSubsectionViewOnWebTapped(isSpecialExam: true, courseID: courseID, subsectionID: block.blockID)
        } else if (block.type == .Section && block.children.isEmpty) {
            environment.analytics.trackSubsectionViewOnWebTapped(isSpecialExam: false, courseID: courseID, subsectionID: block.blockID)
        } else {
            environment.analytics.trackOpenInBrowser(withURL: block.blockURL?.absoluteString ?? "", courseID: courseID, blockID: block.blockID, minifiedBlockID: block.minifiedBlockID ?? "", supported: block.multiDevice)
        }
    }
}

extension CourseUnknownBlockViewController: ValuePropMessageViewDelegate {
    func didTapUpgradeCourse(upgradeView: ValuePropComponentView) {
        guard let course = environment.interface?.enrollmentForCourse(withID: courseID)?.course else { return }
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
                upgradeView.stopAnimating()
                break
            case .complete:
                self?.enableAppTouches()
                upgradeView.updateUpgradeButtonVisibility(visible: false)
                let alertController = UIAlertController().showAlert(withTitle: Strings.CourseUpgrade.successAlertTitle, message: Strings.CourseUpgrade.successAlertMessage, cancelButtonTitle: nil, onViewController: topController) { _, _, _ in }
                alertController.addButton(withTitle: Strings.CourseUpgrade.successAlertContinue, style: .cancel) { action in
                    // TODO: continue button handling
                }
                break
            case .error:
                self?.enableAppTouches()
                upgradeView.stopAnimating()
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
    
    func showValuePropDetailView() {
        guard let course = environment.dataManager.enrollmentManager.enrolledCourseWithID(courseID: courseID)?.course else { return }
        environment.analytics.trackValuePropLearnMore(courseID: courseID, screenName: .CourseUnit, assignmentID: blockID)
        environment.router?.showValuePropDetailView(from: self, type: .courseUnit, course: course) { [weak self] in
            if let weakSelf = self {
                weakSelf.environment.analytics.trackValuePropModal(with: .CourseUnit, courseId: weakSelf.courseID, assignmentID: weakSelf.blockID)
            }
        }
    }
}
