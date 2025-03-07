//
//  AppDelegate.swift
//  StatusSyn
//
//  Created by Enkidu ㅤ on 2025/3/7.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, WorkspaceObserverDelegate {

    private var statusItem: NSStatusItem?
    private var currentAppName: String = "未知应用"
    private var currentAppIcon: NSImage?
    private var workspaceObserver: WorkspaceObserver?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusBar()
        setupWorkspaceObserver()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "StatusSyn")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving and Undo support

    func save() {
        // Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
        let context = persistentContainer.viewContext

        if !context.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing before saving")
        }
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Customize this code block to include application-specific recovery steps.
                let nserror = error as NSError
                NSApplication.shared.presentError(nserror)
            }
        }
    }

    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager? {
        // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
        return persistentContainer.viewContext.undoManager
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Save changes in the application's managed object context before the application terminates.
        let context = persistentContainer.viewContext
        
        if !context.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing to terminate")
            return .terminateCancel
        }
        
        if !context.hasChanges {
            return .terminateNow
        }
        
        do {
            try context.save()
        } catch {
            let nserror = error as NSError

            // Customize this code block to include application-specific recovery steps.
            let result = sender.presentError(nserror)
            if (result) {
                return .terminateCancel
            }
            
            let question = NSLocalizedString("Could not save changes while quitting. Quit anyway?", comment: "Quit without saves error question message")
            let info = NSLocalizedString("Quitting now will lose any changes you have made since the last successful save", comment: "Quit without saves error question info");
            let quitButton = NSLocalizedString("Quit anyway", comment: "Quit anyway button title")
            let cancelButton = NSLocalizedString("Cancel", comment: "Cancel button title")
            let alert = NSAlert()
            alert.messageText = question
            alert.informativeText = info
            alert.addButton(withTitle: quitButton)
            alert.addButton(withTitle: cancelButton)
            
            let answer = alert.runModal()
            if answer == .alertSecondButtonReturn {
                return .terminateCancel
            }
        }
        // If we got here, it is time to quit.
        return .terminateNow
    }

    // MARK: - Status Bar Setup
    
    private func setupStatusBar() {
        // 创建状态栏项
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // 设置状态栏图标
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "StatusSyn")
        }
        
        // 创建菜单
        let menu = NSMenu()
        
        // 添加当前应用信息项
        let currentAppItem = NSMenuItem(title: "当前应用：\(currentAppName)", action: nil, keyEquivalent: "")
        currentAppItem.isEnabled = false
        menu.addItem(currentAppItem)
        
        // 添加分割线
        menu.addItem(NSMenuItem.separator())
        
        // 添加退出按钮
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        // 设置菜单
        statusItem?.menu = menu
        
        // 设置初始图标大小
        updateStatusBarIcon(currentAppIcon)
    }
    
    // MARK: - Workspace Observer Setup
    
    private func setupWorkspaceObserver() {
        workspaceObserver = WorkspaceObserver()
        workspaceObserver?.delegate = self
    }
    
    // MARK: - WorkspaceObserverDelegate
    
    func workspaceObserver(_ observer: WorkspaceObserver, didChangeFrontmostApplication name: String, icon: NSImage?) {
        updateCurrentAppName(name)
        updateStatusBarIcon(icon)
    }
    
    // MARK: - Update Methods
    
    func updateCurrentAppName(_ name: String) {
        currentAppName = name
        updateMenuItems()
    }
    
    private func updateStatusBarIcon(_ icon: NSImage?) {
        currentAppIcon = icon
        
        if let button = statusItem?.button, let icon = icon {
            // 调整图标大小为16x16
            let resizedIcon = NSImage(size: NSSize(width: 16, height: 16))
            resizedIcon.lockFocus()
            icon.draw(in: NSRect(x: 0, y: 0, width: 16, height: 16),
                     from: NSRect(x: 0, y: 0, width: icon.size.width, height: icon.size.height),
                     operation: .sourceOver,
                     fraction: 1.0)
            resizedIcon.unlockFocus()
            
            button.image = resizedIcon
        } else if let button = statusItem?.button {
            // 如果没有图标，使用默认图标
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "StatusSyn")
        }
        
        updateMenuItems()
    }
    
    private func updateMenuItems() {
        if let menu = statusItem?.menu {
            let menuItem = menu.item(at: 0)
            menuItem?.title = "当前应用：\(currentAppName)"
            
            // 为菜单项创建一个新的图标副本
            if let icon = currentAppIcon {
                let menuIconSize = NSSize(width: 16, height: 16)
                let menuIcon = NSImage(size: menuIconSize)
                menuIcon.lockFocus()
                icon.draw(in: NSRect(x: 0, y: 0, width: menuIconSize.width, height: menuIconSize.height),
                         from: NSRect(x: 0, y: 0, width: icon.size.width, height: icon.size.height),
                         operation: .sourceOver,
                         fraction: 1.0)
                menuIcon.unlockFocus()
                menuItem?.image = menuIcon
            } else {
                menuItem?.image = nil
            }
        }
    }

}

