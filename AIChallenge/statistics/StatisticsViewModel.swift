//
//  StatisticsViewModel.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 26.03.26.
//

import Combine

final class StatisticsViewModel: ObservableObject {
    
    @Published var chunk: OllamaChunk?
    
    init(chunk: OllamaChunk?) {
        self.chunk = chunk
    }
    
    var tokensPerSecond: Double {
        guard let c = chunk,
                let evalDuration = c.evalDuration,
                evalDuration > 0,
              let evalCount = c.evalCount
        else { return 0 }
        return Double(evalCount) / evalDuration
    }
}
