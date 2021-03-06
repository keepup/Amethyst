//
//  AppDelegate.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/8/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import CCNLaunchAtLoginItem
import CCNPreferencesWindowController
import CoreServices
import Crashlytics
import Fabric
import Foundation
import RxCocoa
import RxSwift
import Sparkle

public class AppDelegate: NSObject, NSApplicationDelegate {
    private var loginItem: CCNLaunchAtLoginItem?
    private var preferencesWindowController: CCNPreferencesWindowController?

    private var windowManager: WindowManager?
    private var hotKeyManager: HotKeyManager?

    private var statusItem: NSStatusItem?
    @IBOutlet public var statusItemMenu: NSMenu?
    @IBOutlet public var versionMenuItem: NSMenuItem?
    @IBOutlet public var startAtLoginMenuItem: NSMenuItem?

    public func applicationDidFinishLaunching(notification: NSNotification) {
        if NSProcessInfo.processInfo().arguments.indexOf("--log") == nil {
            LogManager.log?.minLevel = .Warning
        } else {
            LogManager.log?.minLevel = .Trace
        }

        #if DEBUG
            LogManager.log?.minLevel = .Trace
        #endif

        LogManager.log?.info("Logging is enabled")

        UserConfiguration.sharedConfiguration.load()

        #if RELEASE
            let appcastURLString = { () -> String? in
                if UserConfiguration.sharedConfiguration.useCanaryBuild() {
                    return NSBundle.mainBundle().infoDictionary?["SUCanaryFeedURL"] as? String
                } else {
                    return NSBundle.mainBundle().infoDictionary?["SUFeedURL"] as? String
                }
            }()!

            SUUpdater.sharedUpdater().feedURL = NSURL(string: appcastURLString)
        #endif

        _ = UserConfiguration.sharedConfiguration
            .rx_observe(Bool.self, "tilingEnabled")
            .subscribeNext() { [weak self] tilingEnabled in
                var statusItemImage: NSImage?
                if tilingEnabled == true {
                    statusItemImage = NSImage(named: "icon-statusitem")
                } else {
                    statusItemImage = NSImage(named: "icon-statusitem-disabled")
                }
                statusItemImage?.template = true
                self?.statusItem?.image = statusItemImage
            }

        if let fabricData = NSBundle.mainBundle().infoDictionary?["Fabric"] as? [String: AnyObject] where fabricData["APIKey"] != nil {
            if UserConfiguration.sharedConfiguration.shouldSendCrashReports() {
                LogManager.log?.info("Crash reporting enabled")
                Fabric.with([Crashlytics.self])
                #if DEBUG
                    Crashlytics.sharedInstance().debugMode = true
                #endif
            }
        }

        preferencesWindowController = CCNPreferencesWindowController()
        preferencesWindowController?.centerToolbarItems = false
        preferencesWindowController?.allowsVibrancy = true
        let preferencesViewControllers = [
            GeneralPreferencesViewController(),
            ShortcutsPreferencesViewController()
        ]
        preferencesWindowController?.setPreferencesViewControllers(preferencesViewControllers)

        windowManager = WindowManager(userConfiguration: UserConfiguration.sharedConfiguration)
        hotKeyManager = HotKeyManager(userConfiguration: UserConfiguration.sharedConfiguration)

        hotKeyManager?.setUpWithHotKeyManager(windowManager!, configuration: UserConfiguration.sharedConfiguration)
    }

    public override func awakeFromNib() {
        super.awakeFromNib()

        let version = NSBundle.mainBundle().infoDictionary?["CFBundleVersion"] as! String
        let shortVersion = NSBundle.mainBundle().infoDictionary?["CFBundleShortVersionString"] as! String

        statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength)
        statusItem?.image = NSImage(named: "icon-statusitem")
        statusItem?.menu = statusItemMenu
        statusItem?.highlightMode = true

        versionMenuItem?.title = "Version \(shortVersion) (\(version))"

        loginItem = CCNLaunchAtLoginItem(forBundle: NSBundle.mainBundle())
        startAtLoginMenuItem?.state = (loginItem!.isActive() ? NSOnState : NSOffState)
    }

    @IBAction public func toggleStartAtLogin(sender: AnyObject) {
        if startAtLoginMenuItem?.state == NSOffState {
            loginItem?.activate()
        } else {
            loginItem?.deActivate()
        }
        startAtLoginMenuItem?.state = (loginItem!.isActive() ? NSOnState : NSOffState)
    }

    @IBAction public func relaunch(sender: AnyObject) {
        let executablePath = NSBundle.mainBundle().executablePath! as NSString
        let fileSystemRepresentedPath = executablePath.fileSystemRepresentation
        let fileSystemPath = NSFileManager.defaultManager().stringWithFileSystemRepresentation(fileSystemRepresentedPath, length: Int(strlen(fileSystemRepresentedPath)))
        NSTask.launchedTaskWithLaunchPath(fileSystemPath, arguments: [])
        NSApp.terminate(self)
    }

    @IBAction public func showPreferencesWindow(sender: AnyObject) {
        if UserConfiguration.sharedConfiguration.hasCustomConfiguration() {
            let alert = NSAlert()
            alert.alertStyle = .WarningAlertStyle
            alert.messageText = "Warning"
            alert.informativeText = "You have a .amethyst file, which can override in-app preferences. You may encounter unexpected behavior."
            alert.runModal()
        }

        preferencesWindowController?.showPreferencesWindow()
    }

    @IBAction public func checkForUpdates(sender: AnyObject) {
        #if RELEASE
            SUUpdater.sharedUpdater().checkForUpdates(sender)
        #endif
    }
}
