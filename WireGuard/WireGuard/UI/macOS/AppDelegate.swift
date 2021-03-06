// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Cocoa
import ServiceManagement

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var tunnelsManager: TunnelsManager?
    var tunnelsTracker: TunnelsTracker?
    var statusItemController: StatusItemController?

    var manageTunnelsRootVC: ManageTunnelsRootViewController?
    var manageTunnelsWindowObject: NSWindow?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Logger.configureGlobal(tagged: "APP", withFilePath: FileManager.logFileURL?.path)
        registerLoginItem(shouldLaunchAtLogin: true)

        TunnelsManager.create { [weak self] result in
            guard let self = self else { return }
            if let error = result.error {
                ErrorPresenter.showErrorAlert(error: error, from: nil)
                return
            }

            let tunnelsManager: TunnelsManager = result.value!

            let statusMenu = StatusMenu(tunnelsManager: tunnelsManager)
            statusMenu.windowDelegate = self

            let statusItemController = StatusItemController()
            statusItemController.statusItem.menu = statusMenu

            let tunnelsTracker = TunnelsTracker(tunnelsManager: tunnelsManager)
            tunnelsTracker.statusMenu = statusMenu
            tunnelsTracker.statusItemController = statusItemController

            self.tunnelsManager = tunnelsManager
            self.tunnelsTracker = tunnelsTracker
            self.statusItemController = statusItemController
        }
    }

    @objc func quit() {
        if let manageWindow = manageTunnelsWindowObject, manageWindow.attachedSheet != nil {
            NSApp.activate(ignoringOtherApps: true)
            manageWindow.orderFront(self)
            return
        }
        registerLoginItem(shouldLaunchAtLogin: false)
        guard let currentTunnel = tunnelsTracker?.currentTunnel, currentTunnel.status == .active || currentTunnel.status == .activating else {
            NSApp.terminate(nil)
            return
        }
        let alert = NSAlert()
        alert.messageText = tr("macAppExitingWithActiveTunnelMessage")
        alert.informativeText = tr("macAppExitingWithActiveTunnelInfo")
        NSApp.activate(ignoringOtherApps: true)
        if let manageWindow = manageTunnelsWindowObject {
            manageWindow.orderFront(self)
            alert.beginSheetModal(for: manageWindow) { _ in
                NSApp.terminate(nil)
            }
        } else {
            alert.runModal()
            NSApp.terminate(nil)
        }
    }
}

extension AppDelegate: StatusMenuWindowDelegate {
    func manageTunnelsWindow() -> NSWindow {
        if manageTunnelsWindowObject == nil {
            manageTunnelsRootVC = ManageTunnelsRootViewController(tunnelsManager: tunnelsManager!)
            let window = NSWindow(contentViewController: manageTunnelsRootVC!)
            window.title = tr("macWindowTitleManageTunnels")
            window.setContentSize(NSSize(width: 800, height: 480))
            window.setFrameAutosaveName(NSWindow.FrameAutosaveName("ManageTunnelsWindow")) // Auto-save window position and size
            manageTunnelsWindowObject = window
            tunnelsTracker?.manageTunnelsRootVC = manageTunnelsRootVC
        }
        return manageTunnelsWindowObject!
    }
}

@discardableResult
func registerLoginItem(shouldLaunchAtLogin: Bool) -> Bool {
    let appId = Bundle.main.bundleIdentifier!
    let helperBundleId = "\(appId).login-item-helper"
    return SMLoginItemSetEnabled(helperBundleId as CFString, shouldLaunchAtLogin)
}
