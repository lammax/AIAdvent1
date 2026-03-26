//
//  OllamaStreamer.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 16.03.26.
//

import Foundation

class OpenRouterStreamer: NSObject {
    let decoder = JSONDecoder()
    
    private var buffer = Data()
    
    var onToken: ((String) -> Void)?
    var onComplete: (() -> Void)?
    
    override init() {}
    
    func send(_ message: Message, options: [String : Any]) async throws -> String {
        
        let finalOptions = options.isEmpty ? Constants.defaultOllamaOptions : options
            
        var body: [String: Any] = finalOptions
        body["messages"] = [["role": message.role, "content": message.content]]
        
        let url = URL(string: LLMURL.openRouter.text)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        request.addValue("Bearer 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", forHTTPHeaderField: "Authorization")
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
        
        var body: [String: Any] = finalOptions
        body["messages"] = messages.map {
            ["role": $0.role.text, "content": $0.content]
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        request.addValue("Bearer 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", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try! JSONSerialization.data(withJSONObject: body)
        
        let session = URLSession(configuration: URLSessionConfiguration.default,
                                 delegate: self,
                                 delegateQueue: nil)
        
        session.dataTask(with: request).resume()
    }
    
}

extension OpenRouterStreamer: URLSessionDataDelegate {
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
