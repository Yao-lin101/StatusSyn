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
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontmostApp.bundleIdentifier else {
            if lastTabInfo != nil {
                lastTabInfo = nil
                delegate?.browserTabMonitor(self, didUpdateTabInfo: nil)
            }
            return
        }
        
        print("当前应用 Bundle ID: \(bundleId)")
        
        let browserType: BrowserType?
        switch bundleId {
        case BrowserType.safari.bundleIdentifier:
            browserType = .safari
        case BrowserType.chrome.bundleIdentifier:
            browserType = .chrome
        case BrowserType.edge.bundleIdentifier:
            browserType = .edge
        default:
            print("未识别的浏览器 Bundle ID: \(bundleId)")
            browserType = nil
        }
        
        guard let browser = browserType else {
            if lastTabInfo != nil {
                lastTabInfo = nil
                delegate?.browserTabMonitor(self, didUpdateTabInfo: nil)
            }
            return
        }
        
        // 如果浏览器类型发生变化，更新当前浏览器类型
        if browser != currentBrowserType {
            print("浏览器切换到: \(browser.rawValue)")
            currentBrowserType = browser
            lastTabInfo = nil
            // 浏览器切换时立即更新
            executeAppleScript(for: browser)
        } else {
            // 使用 DispatchQueue 在后台执行 AppleScript
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.executeAppleScript(for: browser)
            }
        }
        
        lastCheckTime = currentTime
    }
    
    private func executeAppleScript(for browserType: BrowserType) {
        print("开始执行 AppleScript: \(browserType.rawValue)")
        print("脚本内容:\n\(browserType.appleScript)")
        
        guard let script = NSAppleScript(source: browserType.appleScript) else {
            print("创建 AppleScript 失败: \(browserType.rawValue)")
            return
        }
        
        var error: NSDictionary?
        let resultDescriptor = script.executeAndReturnError(&error)
        
        if let error = error {
            print("AppleScript 执行错误 [\(browserType.rawValue)]: \(error)")
            print("错误详情: \(error.description)")
            if lastTabInfo != nil {
                lastTabInfo = nil
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.browserTabMonitor(self, didUpdateTabInfo: nil)
                }
            }
            return
        }
        
        print("AppleScript 执行结果: 项目数量 = \(resultDescriptor.numberOfItems)")
        
        if resultDescriptor.numberOfItems > 0,
           let title = resultDescriptor.atIndex(1)?.stringValue,
           let url = resultDescriptor.atIndex(2)?.stringValue,
           let indexStr = resultDescriptor.atIndex(3)?.stringValue,
           let tabIndex = Int(indexStr) {
            
            print("解析结果: title=\(title), url=\(url), index=\(tabIndex)")
            
            let newTabInfo = TabInfo(
                title: title,
                url: url,
                browserType: browserType,
                tabIndex: tabIndex
            )
            
            // 只有当标签页信息发生变化时才通知代理
            if newTabInfo.isValid && (lastTabInfo == nil ||
                lastTabInfo?.title != newTabInfo.title ||
                lastTabInfo?.url != newTabInfo.url ||
                lastTabInfo?.tabIndex != newTabInfo.tabIndex ||
                lastTabInfo?.browserType != newTabInfo.browserType) {
                
                print("标签页更新 [\(browserType.rawValue)]: \(title)")
                lastTabInfo = newTabInfo
                // 在主线程更新 UI
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.browserTabMonitor(self, didUpdateTabInfo: newTabInfo)
                }
            }
        } else {
            print("无效的 AppleScript 返回结果 [\(browserType.rawValue)]")
            print("返回值类型: \(resultDescriptor.descriptorType)")
            if let stringValue = resultDescriptor.stringValue {
                print("返回值字符串: \(stringValue)")
            }
        }
    }
    
    deinit {
        stopMonitoring()
    }
} 