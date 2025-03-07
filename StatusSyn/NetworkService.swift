import Foundation

class NetworkService {
    static let shared = NetworkService()
    
    private var baseURL: String? {
        return UserDefaults.standard.string(forKey: "baseURL")
    }
    
    private var characterKey: String? {
        return UserDefaults.standard.string(forKey: "characterKey")
    }
    
    var isConfigured: Bool {
        let baseURL = UserDefaults.standard.string(forKey: "baseURL")
        let characterKey = UserDefaults.standard.string(forKey: "characterKey")
        return !(baseURL?.isEmpty ?? true) && !(characterKey?.isEmpty ?? true)
    }
    
    private var debounceTimer: Timer?
    private var pendingTabInfo: TabInfo?
    private var pendingAppName: String?
    
    private init() {
        // 监听配置变化
        NotificationCenter.default.addObserver(self, selector: #selector(configDidChange), name: .configDidChange, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        debounceTimer?.invalidate()
    }
    
    @objc private func configDidChange() {
        print("配置已更新")
    }
    
    func sendTabInfo(_ tabInfo: TabInfo?) {
        // 取消现有的定时器
        debounceTimer?.invalidate()
        
        // 保存待发送的状态
        pendingTabInfo = tabInfo
        pendingAppName = nil
        
        // 创建新的定时器，3秒后执行
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            if let tabInfo = self?.pendingTabInfo {
                // 浏览器状态：发送浏览器名称和标签页标题
                self?.sendStatusRequest("\(tabInfo.browserType.rawValue)\n\(tabInfo.title)")
            }
        }
    }
    
    func updateStatus(appName: String) {
        // 取消现有的定时器
        debounceTimer?.invalidate()
        
        // 保存待发送的状态
        pendingTabInfo = nil
        pendingAppName = appName
        
        // 创建新的定时器，3秒后执行
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            if let appName = self?.pendingAppName {
                self?.sendStatusRequest(appName)
            }
        }
    }
    
    private func sendStatusRequest(_ appName: String) {
        guard let baseURLString = baseURL, let url = URL(string: baseURLString),
              let key = characterKey, !key.isEmpty else {
            print("配置无效，请先完成配置")
            return
        }
        
        print("发送状态更新: \(appName)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "X-Character-Key")
        
        let payload: [String: Any] = [
            "type": "mac",
            "data": [
                "mac": appName
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("网络请求错误: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("状态更新响应码: \(httpResponse.statusCode)")
                }
            }
            task.resume()
        } catch {
            print("创建请求数据失败: \(error.localizedDescription)")
        }
    }
} 