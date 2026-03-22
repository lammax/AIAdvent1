//
//  OllamaStreamer.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 16.03.26.
//

import Foundation

class OllamaStreamer: NSObject, URLSessionDataDelegate, LLMProtocol {
    
    var onToken: ((String) -> Void)?
    
    let decoder = JSONDecoder()
    
    override init() {
//        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    func start(with prompt: Prompt) {
        
        let url = URL(string: LLMURL.ollama.text)!
        
        let body: [String: Any] = [
            "model": "phi3",
            "prompt": prompt.text,
            "stream": true
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try! JSONSerialization.data(withJSONObject: body)
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        session.dataTask(with: request).resume()
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        
        guard let text = String(data: data, encoding: .utf8) else { return }
        print("text:", text)
        
        let lines = text.split(separator: "\n")
        
        for line in lines {
            
            guard let jsonData = line.data(using: .utf8) else { return }
            
            if let token = parseToken(from: jsonData) {
                DispatchQueue.main.async {
                    self.onToken?(token)
                }
            }
        }
    }
    
    private func parseToken(from data: Data) -> String? {
        
        struct Chunk: Decodable {
            enum CodingKeys: String, CodingKey {
                case model, created_at, response, done, done_reason, context, total_duration
                case load_duration, prompt_eval_count, prompt_eval_duration, eval_count, eval_duration
            }
            
            let model: String
            let created_at: String
            let response: String
            let done: Bool
            let done_reason: String?
            let context: [Int]?
            let total_duration: Int?
            let load_duration: Int?
            let prompt_eval_count: Int?
            let prompt_eval_duration: Int?
            let eval_count: Int?
            let eval_duration: Int?
        }
        
        do {
            print("data:", String(data: data, encoding: .utf8)!)
            let response = try decoder
                .decode(Chunk.self, from: data)
                .response
            return response
        } catch {
            print(error)
            return nil
        }
        
    }
}
