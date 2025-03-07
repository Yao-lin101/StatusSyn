import Foundation

class NetworkService {
    private let baseURL = "https://alive.ineed.asia/api/v1/status/update/"
    private let characterKey = "82d896e0-8173-4e13-a852-43e5698c7142"
    
    func updateStatus(appName: String) {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(characterKey, forHTTPHeaderField: "X-Character-Key")
        
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