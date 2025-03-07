import Cocoa

enum BrowserType: String {
    case safari = "Safari"
    case chrome = "Google Chrome"
    case edge = "Microsoft Edge"
    
    var bundleIdentifier: String {
        switch self {
        case .safari: return "com.apple.Safari"
        case .chrome: return "com.google.Chrome"
        case .edge: return "com.microsoft.edgemac"
        }
    }
    
    var appleScript: String {
        switch self {
        case .safari:
            return """
            tell application "Safari"
                if frontmost then
                    tell front window
                        try
                            set tabTitle to name of current tab
                            set tabURL to URL of current tab
                            set tabIndex to index of current tab
                            return {tabTitle, tabURL, tabIndex as string}
                        on error
                            return {"", "", "0"}
                        end try
                    end tell
                else
                    return {"", "", "0"}
                end if
            end tell
            """
        case .chrome:
            return """
            tell application "Google Chrome"
                if frontmost then
                    tell front window
                        try
                            set tabTitle to title of active tab
                            set tabURL to URL of active tab
                            set tabIndex to active tab index
                            return {tabTitle, tabURL, tabIndex as string}
                        on error
                            return {"", "", "0"}
                        end try
                    end tell
                else
                    return {"", "", "0"}
                end if
            end tell
            """
        case .edge:
            return """
            tell application "Microsoft Edge"
                if frontmost then
                    try
                        set allWindows to windows
                        if (count of allWindows) > 0 then
                            tell first window
                                try
                                    set allTabs to tabs
                                    if (count of allTabs) > 0 then
                                        set activeTab to active tab
                                        set tabTitle to title of activeTab
                                        set tabURL to URL of activeTab
                                        return {tabTitle, tabURL, "1"}
                                    end if
                                on error errorMessage
                                    log "Edge tab error: " & errorMessage
                                    return {"", "", "0"}
                                end try
                            end tell
                        end if
                    on error errorMessage
                        log "Edge window error: " & errorMessage
                        return {"", "", "0"}
                    end try
                end if
                return {"", "", "0"}
            end tell
            """
        }
    }
}

struct TabInfo {
    let title: String
    let url: String
    let browserType: BrowserType
    let tabIndex: Int
    
    var isValid: Bool {
        return !title.isEmpty && !url.isEmpty && tabIndex > 0
    }
}

protocol BrowserTabMonitorDelegate: AnyObject {
    func browserTabMonitor(_ monitor: BrowserTabMonitor, didUpdateTabInfo tabInfo: TabInfo?)
}

class BrowserTabMonitor {
    weak var delegate: BrowserTabMonitorDelegate?
    private var currentBrowserType: BrowserType?
    private var timer: Timer?
    private var lastTabInfo: TabInfo?
    private var lastCheckTime: TimeInterval = 0
    private let minimumCheckInterval: TimeInterval = 1.0  // 最小检查间隔为1秒
    private var lastAppBundleId: String?
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        // 降低检查频率到1秒
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkCurrentTab()
        }
        timer?.tolerance = 0.2 // 添加容差以优化性能
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkCurrentTab() {
        let currentTime = Date().timeIntervalSince1970
        
        // 检查是否达到最小检查间隔
        if currentTime - lastCheckTime < minimumCheckInterval {
            return
        }
        
        // 检查当前前台应用是否是受支持的浏览器
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            if lastAppBundleId != nil {
                print("切换到: 无前台应用")
                lastAppBundleId = nil
                clearCurrentState()
            }
            return
        }
        
        guard let bundleId = frontmostApp.bundleIdentifier else {
            if lastAppBundleId != nil {
                print("切换到: 未知应用")
                lastAppBundleId = nil
                clearCurrentState()
            }
            return
        }
        
        // 如果应用没有变化，不打印日志
        if bundleId == lastAppBundleId {
            // 继续检查标签页更新
        } else {
            lastAppBundleId = bundleId
            if let localizedName = frontmostApp.localizedName {
                print("切换到: \(localizedName)")
            }
        }
        
        let browserType: BrowserType?
        switch bundleId {
        case BrowserType.safari.bundleIdentifier:
            browserType = .safari
        case BrowserType.chrome.bundleIdentifier:
            browserType = .chrome
        case BrowserType.edge.bundleIdentifier:
            browserType = .edge
        default:
            browserType = nil
            if lastAppBundleId != nil {
                clearCurrentState()
            }
            return
        }
        
        guard let browser = browserType else {
            return
        }
        
        // 如果浏览器类型发生变化，更新当前浏览器类型
        if browser != currentBrowserType {
            currentBrowserType = browser
            lastTabInfo = nil
            // 浏览器切换时立即更新
            executeAppleScript(for: browser)
        } else {
            // 使用 DispatchQueue 在后台执行 AppleScript
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.executeAppleScript(for: browser, shouldLog: false)
            }
        }
        
        lastCheckTime = currentTime
    }
    
    private func clearCurrentState() {
        currentBrowserType = nil
        lastTabInfo = nil
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.browserTabMonitor(self, didUpdateTabInfo: nil)
        }
    }
    
    private func executeAppleScript(for browserType: BrowserType, shouldLog: Bool = true) {
        guard let script = NSAppleScript(source: browserType.appleScript) else {
            if shouldLog {
                print("创建 AppleScript 失败: \(browserType.rawValue)")
            }
            clearCurrentState()
            return
        }
        
        var error: NSDictionary?
        let resultDescriptor = script.executeAndReturnError(&error)
        
        if let error = error {
            print("AppleScript 执行错误 [\(browserType.rawValue)]: \(error)")
            clearCurrentState()
            return
        }
        
        if resultDescriptor.numberOfItems > 0,
           let title = resultDescriptor.atIndex(1)?.stringValue,
           let url = resultDescriptor.atIndex(2)?.stringValue,
           let indexStr = resultDescriptor.atIndex(3)?.stringValue,
           let tabIndex = Int(indexStr) {
            
            // 如果返回的是空值，说明浏览器不在前台或没有活动标签页
            if title.isEmpty || url.isEmpty || tabIndex <= 0 {
                clearCurrentState()
                return
            }
            
            let newTabInfo = TabInfo(
                title: title,
                url: url,
                browserType: browserType,
                tabIndex: tabIndex
            )
            
            // 只有当标签页信息有效且发生变化时才通知代理
            if lastTabInfo == nil ||
                lastTabInfo?.title != newTabInfo.title ||
                lastTabInfo?.url != newTabInfo.url ||
                lastTabInfo?.tabIndex != newTabInfo.tabIndex ||
                lastTabInfo?.browserType != newTabInfo.browserType {
                
                print("[\(browserType.rawValue)] 切换到: \(title)")
                lastTabInfo = newTabInfo
                // 在主线程更新 UI
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.browserTabMonitor(self, didUpdateTabInfo: newTabInfo)
                }
            }
        } else {
            clearCurrentState()
        }
    }
    
    deinit {
        stopMonitoring()
    }
} 