//
//  DefaultRAGMiniChatScenarioRepository.swift
//  AIChallenge
//
//  Created by Codex on 17.04.26.
//

import Foundation

final class DefaultRAGMiniChatScenarioRepository: RAGMiniChatScenarioRepositoryProtocol {
    func loadScenarios() -> [RAGMiniChatScenario] {
        [
            RAGMiniChatScenario(
                id: 1,
                title: "RAG answer contract implementation",
                expectedGoalKeywords: ["rag", "answer", "contract"],
                turns: [
                    turn(1, "Цель: спроектировать мини-чат для проверки RAG answer contract в этом проекте."),
                    turn(2, "Уточнение: меня интересует именно история диалога, а не один независимый вопрос."),
                    turn(3, "Найди в базе, какие модели уже описывают RAG answer."),
                    turn(4, "Важно: источники должны выводиться всегда."),
                    turn(5, "Какие поля источника уже зафиксированы?"),
                    turn(6, "Термин chunk_id считаем обязательным и не переименовываем."),
                    turn(7, "Как сейчас проверяется, что цитата взята из retrieved chunk?"),
                    turn(8, "Ограничение: semantic support пока можно считать эвристикой."),
                    turn(9, "С учётом этих ограничений, какой контракт ответа нужен мини-чату?"),
                    turn(10, "Не теряй цель: мне нужен именно мини-чат с памятью задачи и источниками."),
                    turn(11, "Как это должно вести себя при слабом контексте?"),
                    turn(12, "Собери итоговые правила для mini-chat RAG ответа.")
                ]
            ),
            RAGMiniChatScenario(
                id: 2,
                title: "RAG evaluation and settings flow",
                expectedGoalKeywords: ["rag", "evaluation", "settings"],
                turns: [
                    turn(1, "Цель: проверить длинный сценарий RAG evaluation через настройки приложения."),
                    turn(2, "Уточнение: сценарий должен идти 10-15 сообщений и помнить цель."),
                    turn(3, "Какие режимы RAG evaluation уже есть?"),
                    turn(4, "Важно: обычная история сообщений не должна засоряться eval report."),
                    turn(5, "Где в Settings UI выбирается RAG Evaluation?"),
                    turn(6, "Ограничение: не скрывать side effects от пользователя."),
                    turn(7, "Как выбранный режим доходит до OllamaAgent?"),
                    turn(8, "Термин task state означает цель, уточнения и ограничения."),
                    turn(9, "Как проверять, что ассистент не потерял цель?"),
                    turn(10, "Как проверять, что источники продолжают выводиться?"),
                    turn(11, "Нужно ли запускать сценарии одним блоком или по одному сообщению?"),
                    turn(12, "Сделай итог по требованиям к проверке mini-chat сценариев.")
                ]
            )
        ]
    }
    
    private func turn(_ id: Int, _ userMessage: String) -> RAGMiniChatScenarioTurn {
        RAGMiniChatScenarioTurn(id: id, userMessage: userMessage)
    }
}
