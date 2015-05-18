//
//  CourseOutlineViewController.swift
//  edX
//
//  Created by Akiva Leffert on 4/30/15.
//  Copyright (c) 2015 edX. All rights reserved.
//

import Foundation
import UIKit

public class CourseOutlineViewController : UIViewController, CourseOutlineTableControllerDelegate, CourseBlockViewController {

    public class Environment : NSObject {
        weak var router : OEXRouter?
        let dataManager : DataManager
        let styles : OEXStyles?
        
        init(dataManager : DataManager, router : OEXRouter, styles : OEXStyles?) {
            self.router = router
            self.dataManager = dataManager
            self.styles = styles
        }
    }

    
    private var rootID : CourseBlockID
    private var environment : Environment
    
    private var currentMode : CourseOutlineMode = .Full  // TODO
    
    private let courseQuerier : CourseOutlineQuerier
    private let tableController : CourseOutlineTableController = CourseOutlineTableController()
    
    private var loader : Promise<[CourseBlock]>?
    
    private let loadController : LoadStateViewController
    
    public var blockID : CourseBlockID {
        return rootID
    }
    
    public var courseID : String {
        return courseQuerier.courseID
    }
    
    public init(environment: Environment, courseID : String, rootID : CourseBlockID) {
        self.rootID = rootID
        self.environment = environment
        courseQuerier = environment.dataManager.courseDataManager.querierForCourseWithID(courseID)
        loadController = LoadStateViewController(styles: environment.styles)
        
        super.init(nibName: nil, bundle: nil)
        
        addChildViewController(tableController)
        tableController.didMoveToParentViewController(self)
        tableController.delegate = self
    }

    public required init(coder aDecoder: NSCoder) {
        // required by the compiler because UIViewController implements NSCoding,
        // but we don't actually want to serialize these things
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = self.environment.styles?.standardBackgroundColor()
        view.addSubview(tableController.view)
        
        loadController.setupInController(self, contentView:tableController.view)
        
        self.view.setNeedsUpdateConstraints()
    }
    
    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        loadContentIfNecessary()
    }
    
    override public func updateViewConstraints() {
        loadController.insets = UIEdgeInsets(top: self.topLayoutGuide.length, left: 0, bottom: self.bottomLayoutGuide.length, right : 0)
        
        tableController.view.snp_updateConstraints {make in
            make.edges.equalTo(self.view)
        }
        super.updateViewConstraints()
    }
    
    private func loadContentIfNecessary() {
        if loader == nil {
            let action = courseQuerier.childrenOfBlockWithID(self.rootID, mode: currentMode)
            loader = action
            
            action.then {[weak self] nodes -> Promise<Void> in
                if let owner = self {
                    owner.tableController.nodes = nodes
                    var children : [CourseBlockID : Promise<[CourseBlock]>] = [:]
                    let promises = nodes.map {(node : CourseBlock) -> Promise<[CourseBlock]> in
                        let promise = owner.courseQuerier.childrenOfBlockWithID(node.blockID, mode: owner.currentMode)
                        children[node.blockID] = promise
                        return promise
                    }
                    owner.tableController.children = children
                    
                    return when(promises).then {_ -> Void in
                        self?.tableController.tableView.reloadData()
                        self?.loadController.state = .Loaded
                    }
                }
                // If owner is nil, then the owning controller is dealloced, so just fail quietly
                return Promise {fullfil, reject in
                    reject(NSError.oex_courseContentLoadError())
                }
            }.catch {[weak self] error in
                if let state = self?.loadController.state where state.isInitial {
                    self?.loadController.state = .Failed(error : error, icon : nil, message : nil)
                }
                // Otherwise, we already have content so stifle error
            } as Void
        }
    }
    
    func outlineTableController(controller: CourseOutlineTableController, choseBlock block: CourseBlock, withParentID parent : CourseBlockID) {
        self.environment.router?.showContainerForBlockWithID(block.blockID, type:block.type.displayType, parentID: parent, courseID: courseQuerier.courseID, fromController:self)
    }
}
