//
//  OllamaStreamer.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 16.03.26.
//

import Foundation

class OllamaStreamer: NSObject, LLMProtocol {
    let decoder = JSONDecoder()
    
    private var buffer = Data()

    var onToken: ((String) -> Void)?
    var onComplete: (() -> Void)?
    
    override init() {}
    
    func start(messages: [Message], options: [String : Any]) {
            
        let url = URL(string: LLMURL.ollama.text)!
        
        let finalOptions = options.isEmpty ? Constants.defaultOllamaOptions : options
        
        let body: [String: Any] = [
            "model": "phi3",
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
        
//        request.setValue("close", forHTTPHeaderField: "Connection")
        
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        let session = URLSession(configuration: config,
                                 delegate: self,
                                 delegateQueue: nil)
        
        session.dataTask(with: request).resume()
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
