//
//  UIViewController+Overlay.swift
//  edX
//
//  Created by Akiva Leffert on 12/23/15.
//  Copyright © 2015 edX. All rights reserved.
//

import Foundation

private var StatusMessageHideActionKey = "StatusMessageHideActionKey"
private var SnackBarHideActionKey = "SnackBarHideActionKey"

private typealias StatusMessageRemovalInfo = (action : () -> Void, container : UIView)
private typealias TemporaryViewRemovalInfo = (action : () -> Void, container : UIView)

private class StatusMessageView : UIView {
    
    private let messageLabel = UILabel()
    private let margin = 20
    
    init(message: String) {
        super.init(frame: CGRect.zero)
        accessibilityIdentifier = "StatusMessageView:overlay-view"
        messageLabel.numberOfLines = 0
        messageLabel.accessibilityIdentifier = "StatusMessageView:message-label"
        addSubview(messageLabel)
        
        backgroundColor = OEXStyles.shared().infoXXLight()
        messageLabel.attributedText = statusMessageStyle.attributedString(withText: message)
        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(self).offset(margin)
            make.leading.equalTo(self).offset(margin)
            make.trailing.equalTo(self).offset(-margin)
            make.bottom.equalTo(self).offset(-margin)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var statusMessageStyle: OEXMutableTextStyle {
        let style = OEXMutableTextStyle(weight: .normal, size: .base, color: OEXStyles.shared().neutralBlackT())
        style.alignment = .center;
        style.lineBreakMode = NSLineBreakMode.byWordWrapping;
        return style;
        
    }
}

private let visibleDuration: TimeInterval = 5.0
private let animationDuration: TimeInterval = 1.0

extension UIViewController {
    
    func showOverlayMessageView(messageView : UIView) {
        let container = PassthroughView()
        container.clipsToBounds = true
        view.addSubview(container)
        container.addSubview(messageView)
        
        container.snp.makeConstraints { make in
            make.top.equalTo(safeTop)
            make.leading.equalTo(safeLeading)
            make.trailing.equalTo(safeTrailing)
        }
        messageView.snp.makeConstraints { make in
            make.edges.equalTo(container)
        }
        
        let size = messageView.systemLayoutSizeFitting(CGSize(width: view.bounds.width, height: CGFloat.greatestFiniteMagnitude))
        messageView.transform = CGAffineTransform(translationX: 0, y: -size.height)
        container.layoutIfNeeded()
        
        let hideAction = {[weak self] in
            if let owner = self {
                let hideInfo = objc_getAssociatedObject(owner, &StatusMessageHideActionKey) as? Box<StatusMessageRemovalInfo>
                if hideInfo?.value.container == container {
                    objc_setAssociatedObject(owner, &StatusMessageHideActionKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                }
            }
            UIView.animate(withDuration: animationDuration, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0.1, options: .curveEaseOut, animations: {
                messageView.transform = CGAffineTransform(translationX: 0, y: -size.height)
                }, completion: { _ in
                    container.removeFromSuperview()
            })
        }
        
        // show
        UIView.animate(withDuration: animationDuration, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0.1, options: .curveEaseIn, animations: { () -> Void in
            messageView.transform = .identity
            }, completion: {_ in
                
                let delay = DispatchTime.now() + Double(Int64(visibleDuration * TimeInterval(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                DispatchQueue.main.asyncAfter(deadline: delay) {
                    hideAction()
                }
        })
        
        let info : StatusMessageRemovalInfo = (action: hideAction, container: container)
        objc_setAssociatedObject(self, &StatusMessageHideActionKey, Box(info), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    func showOverlay(withMessage message : String) {
        let hideInfo = objc_getAssociatedObject(self, &StatusMessageHideActionKey) as? Box<StatusMessageRemovalInfo>
        hideInfo?.value.action()
        let view = StatusMessageView(message: message)
        showOverlayMessageView(messageView: view)
    }
    
    func showSnackBarView(snackBarView : UIView, addOffset: Bool = false) {
        let container = PassthroughView()
        container.clipsToBounds = true
        view.addSubview(container)
        container.addSubview(snackBarView)

        let verticalOffset:CGFloat = addOffset ? 2 * StandardVerticalMargin : 0.0
        let horizontalOffset:CGFloat = addOffset ? StandardHorizontalMargin : 0.0
        
        container.snp.makeConstraints { make in
            make.bottom.equalTo(safeBottom).inset(verticalOffset)
            make.leading.equalTo(safeLeading).offset(horizontalOffset)
            make.trailing.equalTo(safeTrailing).inset(horizontalOffset)
        }
        snackBarView.snp.makeConstraints { make in
            make.edges.equalTo(container)
        }
        
        let hideAction = {[weak self] in
            if let owner = self {
                let hideInfo = objc_getAssociatedObject(owner, &SnackBarHideActionKey) as? Box<TemporaryViewRemovalInfo>
                if hideInfo?.value.container == container {
                    objc_setAssociatedObject(owner, &SnackBarHideActionKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                }
            }
            UIView.animate(withDuration: animationDuration, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0.1, options: .curveEaseOut, animations: {
                snackBarView.transform = .identity
                }, completion: { _ in
                    container.removeFromSuperview()
            })
        }
        
        // show
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0.1, options: .curveEaseIn, animations: { () -> Void in
            snackBarView.transform = .identity
            }, completion: nil)
        
        let info : TemporaryViewRemovalInfo = (action: hideAction, container: container)
        objc_setAssociatedObject(self, &SnackBarHideActionKey, Box(info), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    func showVersionUpgradeSnackBar(string: String) {
        let hideInfo = objc_getAssociatedObject(self, &SnackBarHideActionKey) as? Box<TemporaryViewRemovalInfo>
        hideInfo?.value.action()
        let view = VersionUpgradeView(message: string)
        showSnackBarView(snackBarView: view)
    }
    
    
    func showOfflineSnackBar(message: String, selector: Selector?) {
        let hideInfo = objc_getAssociatedObject(self, &SnackBarHideActionKey) as? Box<TemporaryViewRemovalInfo>
        hideInfo?.value.action()
        let view = OfflineView(message: message, selector: selector)
        showSnackBarView(snackBarView: view)
    }
    
    @objc func hideSnackBar() {
        let hideInfo = objc_getAssociatedObject(self, &SnackBarHideActionKey) as? Box<TemporaryViewRemovalInfo>
        hideInfo?.value.action()
    }
    
    func showDateResetSnackBar(message: String, buttonText: String? = nil, showButton: Bool = false, autoDismiss: Bool = true, buttonAction: (()->())? = nil) {
        let hideInfo = objc_getAssociatedObject(self, &SnackBarHideActionKey) as? Box<TemporaryViewRemovalInfo>
        hideInfo?.value.action()
        let view = DateResetToastView(message: message, buttonText: buttonText, showButton: showButton, buttonAction: buttonAction)
        view.layer.cornerRadius = 4
        showSnackBarView(snackBarView: view, addOffset: true)
        if autoDismiss {
            perform(#selector(hideSnackBar), with: nil, afterDelay: 5)
        }
    }
    
    func showCalendarActionSnackBar(message: String, autoDismiss: Bool = true, duration: TimeInterval = 5) {
        let hideInfo = objc_getAssociatedObject(self, &SnackBarHideActionKey) as? Box<TemporaryViewRemovalInfo>
        hideInfo?.value.action()
        let view = CalendarActionToastView(message: message)
        view.layer.cornerRadius = 4
        showSnackBarView(snackBarView: view, addOffset: true)
        if autoDismiss {
            perform(#selector(hideSnackBar), with: nil, afterDelay: duration)
        }
    }
}

// For use in testing only
extension UIViewController {
    
    var t_isShowingOverlayMessage : Bool {
        return objc_getAssociatedObject(self, &StatusMessageHideActionKey) as? Box<StatusMessageRemovalInfo> != nil
    }
    
    var t_isShowingSnackBar : Bool {
        return objc_getAssociatedObject(self, &SnackBarHideActionKey) as? Box<TemporaryViewRemovalInfo> != nil
    }
    
}
