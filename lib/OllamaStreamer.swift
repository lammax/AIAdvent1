//
//  OllamaStreamer.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 16.03.26.
//

import Foundation

class OllamaStreamer: NSObject {
    let decoder = JSONDecoder()
    
    private var buffer = Data()
    
    private var model: OllamaModel = .phi3

    var onToken: ((String) -> Void)?
    var onComplete: (() -> Void)?
    
    override init() {}
    
    func send(_ message: Message, options: [String : Any]) async throws -> String {
            
        let body: [String: Any] = [
            "model": model.text,
            "messages": [["role": message.role, "content": message.content]],
            "options": options
        ]
        
        let url = URL(string: LLMURL.ollama.text)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let message = (json["message"] as! [String: Any])["content"] as! String
        
        return message
    }
    
    func start(messages: [Message], options: [String : Any]) {
            
        let url = URL(string: LLMURL.ollama.text)!
        
        let finalOptions = options.isEmpty ? Constants.defaultOllamaOptions : options
        
        let body: [String: Any] = [
            "model": model.text,
            "messages": messages.map {
                ["role": $0.role.text, "content": $0.content]
            },
            "stream": true,
            "options": finalOptions
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try! JSONSerialization.data(withJSONObject: body)
        
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        let session = URLSession(configuration: config,
                                 delegate: self,
                                 delegateQueue: nil)
        
        session.dataTask(with: request).resume()
    }
    
    func set(model: OllamaModel) {
        self.model = model
    }
}

extension OllamaStreamer: URLSessionDataDelegate {
    func urlSession(_ session: URLSession,
                        dataTask: URLSessionDataTask,
                        didReceive data: Data) {
            
        buffer.append(data)
        
        guard let text = String(data: buffer, encoding: .utf8) else { return }
        
        let lines = text.split(separator: "\n")
        
        for line in lines {
            
            let jsonString = line //.dropFirst(5)
            
            guard let jsonData = jsonString.data(using: .utf8) else { continue }
            
            print(String(data: jsonData, encoding: .utf8)!)
            
            if let token = parseToken(from: jsonData) {
                if token.done {
                    onComplete?()
                } else {
                    onToken?(token.message.content)
                }
                
            }
        }
        
        buffer.removeAll()
    }
    
    private func parseToken(from data: Data) -> OllamaChunk? {
        
        do {
            let response = try decoder
                .decode(OllamaChunk.self, from: data)
            return response
        } catch {
            print(error)
            return nil
        }
        
    }
}
