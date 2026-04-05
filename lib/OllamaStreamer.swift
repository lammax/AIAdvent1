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
    
    var onToken: ((String) -> Void)?
    var onComplete: ((OllamaChunk) -> Void)?
    
    override init() {}
    
    func send(_ message: Message, options: [String : Any]) async throws -> String {
        
        let finalOptions = options.isEmpty ? Constants.defaultOllamaOptions : options
            
        var body: [String: Any] = finalOptions
        body["messages"] = [["role": message.role.text, "content": message.content]]
        
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
    
    func start(messages: [Message], options: [String : Encodable]) {
        do {
            let url = URL(string: LLMURL.ollama.text)!
            
            let finalOptions = options.isEmpty ? Constants.defaultOllamaOptions : options
            
            var body: [String: Encodable] = finalOptions
            body["messages"] = messages.map {
                ["role": $0.role.text, "content": $0.content]
            }
            
            print("body", "\(body)")
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.withoutEscapingSlashes])
            
            let config = URLSessionConfiguration.default
            config.waitsForConnectivity = true
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            
            let session = URLSession(configuration: config,
                                     delegate: self,
                                     delegateQueue: nil)
            
            session.dataTask(with: request).resume()
        } catch {
            print(error)
            print(error.localizedDescription)
        }
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
                    onComplete?(token)
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
