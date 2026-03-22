//
//  LLMStreamer.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 16.03.26.
//

import Foundation

import Foundation

class OpenAIStreamer: NSObject, URLSessionDataDelegate, LLMProtocol {
    
    private var buffer = Data()
    var onToken: ((String) -> Void)?
    
    func start(messages: [Message], options: [String : Any]) {
        
        let url = URL(string: LLMURL.openAI.text)!
        
        let body: [String: Any] = [
            "model": "gpt-5",
            "input": messages.first?.content ?? "",
            "max_output_tokens": 200,
            "stream": true,
            "options": options
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(Constants.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try! JSONSerialization.data(withJSONObject: body)
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
        buffer.append(data)
        
        guard let text = String(data: buffer, encoding: .utf8) else { return }
        
        let lines = text.split(separator: "\n")
        
        for line in lines {
            
            guard line.starts(with: "data:") else { continue }
            
            let jsonString = line.dropFirst(5)
            
            if jsonString == "[DONE]" {
                return
            }
            
            guard let jsonData = jsonString.data(using: .utf8) else { continue }
            
            if let token = parseToken(from: jsonData) {
                DispatchQueue.main.async {
                    self.onToken?(token)
                }
            }
        }
        
        buffer.removeAll()
    }
    
    private func parseToken(from data: Data) -> String? {
        
        struct Chunk: Decodable {
            struct Delta: Decodable {
                let text: String?
            }
            let delta: Delta?
        }
        
        return try? JSONDecoder()
            .decode(Chunk.self, from: data)
            .delta?
            .text
    }
}
