import Foundation

class NetworkService {
    private var baseURL: String? {
        return UserDefaults.standard.string(forKey: "baseURL")
    }
    
    private var characterKey: String? {
        return UserDefaults.standard.string(forKey: "characterKey")
    }
    
    static var isConfigured: Bool {
        let baseURL = UserDefaults.standard.string(forKey: "baseURL")
        let characterKey = UserDefaults.standard.string(forKey: "characterKey")
        return !(baseURL?.isEmpty ?? true) && !(characterKey?.isEmpty ?? true)
    }
    
    init() {
        // 监听配置变化
        NotificationCenter.default.addObserver(self, selector: #selector(configDidChange), name: .configDidChange, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func configDidChange() {
        print("配置已更新")
    }
    
    func updateStatus(appName: String) {
        guard let baseURLString = baseURL, let url = URL(string: baseURLString),
              let key = characterKey, !key.isEmpty else {
            print("配置无效，请先完成配置")
            return
        }
        
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