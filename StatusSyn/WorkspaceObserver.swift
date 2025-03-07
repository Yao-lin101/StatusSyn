import Cocoa

protocol WorkspaceObserverDelegate: AnyObject {
    func workspaceObserver(_ observer: WorkspaceObserver, didChangeFrontmostApplication name: String, icon: NSImage?)
}

class WorkspaceObserver {
    weak var delegate: WorkspaceObserverDelegate?
    private var workspace: NSWorkspace
    private var notificationCenter: NotificationCenter
    
    init() {
        workspace = NSWorkspace.shared
        notificationCenter = workspace.notificationCenter
        setupObservers()
    }
    
    private func setupObservers() {
        // 监听应用切换事件
        notificationCenter.addObserver(
            self,
            selector: #selector(frontmostApplicationDidChange(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        // 立即获取当前前台应用
        if let frontmostApp = workspace.frontmostApplication {
            notifyDelegate(for: frontmostApp)
        }
    }
    
    @objc private func frontmostApplicationDidChange(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        notifyDelegate(for: app)
    }
    
    private func notifyDelegate(for app: NSRunningApplication) {
        let appName = app.localizedName ?? "未知应用"
        let appIcon = workspace.icon(forFile: app.bundleURL?.path ?? "")
        delegate?.workspaceObserver(self, didChangeFrontmostApplication: appName, icon: appIcon)
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
} 