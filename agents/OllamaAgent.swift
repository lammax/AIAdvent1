//
//  OllamaService.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 22.03.26.
//

import Foundation
import MCP

final class OllamaAgent: LLMAgentProtocol, @unchecked Sendable {
    
    // MARK: - Constants
    
    private static let systemPrompt = "You are a helpful assistant. Answer concisely."
    private let developerReviewDiffCharacterLimit = 60_000
    
    // MARK: - Identity
    
    internal let agentId: String
    private var userId: String
    private var userProfile: UserProfile = .defaultProfile
    
    // MARK: - Dependencies
    
    private let memoryService: MemoryServiceProtocol
    private let userProfileService: UserProfileServiceProtocol
    private let taskContextService: TaskContextServiceProtocol
    private let indexingService: DocumentIndexingServiceProtocol
    private let ragRetrievalService: RAGRetrievalServiceProtocol
    private let ragQueryRewriteService: RAGQueryRewriteServiceProtocol
    private let ragAnswerValidationService: RAGAnswerValidationServiceProtocol
    private let ragEvaluationQuestionRepository: RAGEvaluationQuestionRepositoryProtocol
    private let ragEvaluationService: RAGEvaluationServiceProtocol
    private let ragTaskMemoryService: RAGTaskMemoryServiceProtocol
    private let ragMiniChatScenarioRepository: RAGMiniChatScenarioRepositoryProtocol
    private let ragMiniChatScenarioEvaluationService: RAGMiniChatScenarioEvaluationServiceProtocol
    private let ragMCPClient: RAGMCPClient
    private let promptBuilder = TaskPromptBuilder()
    private let streamer: OllamaStreamer
    
    private let mcpOrchestrator: MCPOrchestratorProtocol?
    
    private let invariantService: InvariantServiceProtocol
    private let invariantFileName: String = "invariants"
    
    // MARK: - Callbacks
    
    var onToken: ((String) -> Void)?
    var onComplete: ((OllamaChunk) -> Void)?
    
    // MARK: - State
    
    private var messages: [Message] = []
    private var summary: String = ""
    private var options: [String: Any] = Constants.defaultOllamaOptions
    
    private let maxMessages: Int
    private let summaryTrigger: Int
    
    private var strategy: ContextStrategyProtocol
    private var isTaskPlanningEnabled: Bool = false
    private var ragSourceType: RAGSourceType = .mcpServer
    private var ragAnswerMode: RAGAnswerMode = .disabled
    private var ragChunkingStrategy: RAGChunkingStrategy = .fixedTokens
    private var ragRetrievalMode: RAGRetrievalMode = .basic
    private var ragEvaluationMode: RAGEvaluationMode = .disabled
    private var ragRetrievalSettings: RAGRetrievalSettings = .default
    private var ragMiniChatTaskState: RAGTaskState = .empty
    private var isPrepared = false
    private var isSending = false
    
    // MARK: - Task context
    private var currentTaskContext: TaskContext?
    private var cachedMCPTools: [MCPToolDescriptor] = []
    private var hasLoadedMCPTools = false
    
    // MARK: - Init
    
    init(
        agentId: String = "ollama_agent",
        userId: String = "default_user",
        memoryService: MemoryServiceProtocol = MemoryService(),
        userProfileService: UserProfileServiceProtocol = UserProfileService(),
        taskContextService: TaskContextServiceProtocol = TaskContextService(),
        indexingService: DocumentIndexingServiceProtocol = DocumentIndexingService(),
        ragRetrievalService: RAGRetrievalServiceProtocol = RAGRetrievalService(),
        ragQueryRewriteService: RAGQueryRewriteServiceProtocol = OllamaRAGQueryRewriteService(),
        ragAnswerValidationService: RAGAnswerValidationServiceProtocol = RAGAnswerValidationService(),
        ragEvaluationQuestionRepository: RAGEvaluationQuestionRepositoryProtocol = MarkdownRAGEvaluationQuestionRepository(),
        ragEvaluationService: RAGEvaluationServiceProtocol = RAGEvaluationService(),
        ragTaskMemoryService: RAGTaskMemoryServiceProtocol = RAGTaskMemoryService(),
        ragMiniChatScenarioRepository: RAGMiniChatScenarioRepositoryProtocol = DefaultRAGMiniChatScenarioRepository(),
        ragMiniChatScenarioEvaluationService: RAGMiniChatScenarioEvaluationServiceProtocol = RAGMiniChatScenarioEvaluationService(),
        ragMCPClient: RAGMCPClient = RAGMCPClient(),
        invariantService: InvariantServiceProtocol = InvariantService(),
        streamer: OllamaStreamer = OllamaStreamer(),
        maxMessages: Int = 12,
        summaryTrigger: Int = 16,
        strategy: ContextStrategyProtocol? = nil
    ) {
        self.agentId = agentId
        self.userId = userId
        self.memoryService = memoryService
        self.userProfileService = userProfileService
        self.taskContextService = taskContextService
        self.indexingService = indexingService
        self.ragRetrievalService = ragRetrievalService
        self.ragQueryRewriteService = ragQueryRewriteService
        self.ragAnswerValidationService = ragAnswerValidationService
        self.ragEvaluationQuestionRepository = ragEvaluationQuestionRepository
        self.ragEvaluationService = ragEvaluationService
        self.ragTaskMemoryService = ragTaskMemoryService
        self.ragMiniChatScenarioRepository = ragMiniChatScenarioRepository
        self.ragMiniChatScenarioEvaluationService = ragMiniChatScenarioEvaluationService
        self.ragMCPClient = ragMCPClient
        self.invariantService = invariantService
        self.streamer = streamer
        self.mcpOrchestrator = MCPOrchestrator(
            streamer: streamer,
            maxSteps: 5
        )
        self.maxMessages = maxMessages
        self.summaryTrigger = summaryTrigger
        self.strategy = strategy ?? SlidingWindowStrategy(maxMessages: maxMessages)
        
        Task {
            await prepareIfNeeded()
        }
    }
    
    // MARK: - Public
    
    func send(
            _ prompt: PromptTemplate,
            options: [String: Any]
        ) {
            
        if isTaskPlanningEnabled, let task = self.currentTaskContext, task.status == .paused {
            let pausedText = """
            The current task is paused.

            Current phase: \(task.phase.rawValue)
            Current step: \(task.step)/\(task.total)
            Current item: \(task.current)

            Resume the task before continuing.
            """
            
            DispatchQueue.main.async { [weak self] in
                self?.onToken?(pausedText)
            }
            return
        }
            
        Task { [weak self] in
            guard let self else { return }
            guard !isSending else { return }
            
            isSending = true
            defer { isSending = false }
            
            await prepareIfNeeded()
            await refreshMCPToolsIfNeeded()
            
            let normalizedOptions = normalizeOptions(options)
            self.options = normalizedOptions

            if let developerSupportRequest = developerSupportRequest(from: prompt.text) {
                let userMessage = Message(
                    agentId: agentId,
                    role: .user,
                    content: prompt.text
                )

                messages.append(userMessage)
                strategy.onUserMessage(userMessage)
                await memoryService.appendMessage(userMessage)

                updateMemoryLayers(with: userMessage)

                await answerDeveloperSupport(
                    request: developerSupportRequest,
                    userQuery: prompt.text
                )
                return
            }

            if let developerCodeReviewFocus = developerCodeReviewFocus(from: prompt.text) {
                let userMessage = Message(
                    agentId: agentId,
                    role: .user,
                    content: prompt.text
                )

                messages.append(userMessage)
                strategy.onUserMessage(userMessage)
                await memoryService.appendMessage(userMessage)

                updateMemoryLayers(with: userMessage)

                await answerDeveloperCodeReview(
                    focus: developerCodeReviewFocus,
                    userQuery: prompt.text
                )
                return
            }

            if let developerHelpQuestion = developerHelpQuestion(from: prompt.text) {
                let userMessage = Message(
                    agentId: agentId,
                    role: .user,
                    content: prompt.text
                )

                messages.append(userMessage)
                strategy.onUserMessage(userMessage)
                await memoryService.appendMessage(userMessage)

                updateMemoryLayers(with: userMessage)

                await answerDeveloperHelp(
                    question: developerHelpQuestion,
                    userQuery: prompt.text
                )
                return
            }
            
            if ragEvaluationMode == .builtInQuestions {
                await runRAGEvaluation()
                return
            }
            
            if ragEvaluationMode == .miniChatScenarios {
                await runRAGMiniChatScenarioEvaluation()
                return
            }
            
            let finalPromptText = await makeUserPromptText(from: prompt.text)
            
            let userMessage = Message(
                agentId: agentId,
                role: .user,
                content: finalPromptText
            )
            
            messages.append(userMessage)
            strategy.onUserMessage(userMessage)
            await memoryService.appendMessage(userMessage)
            
            updateMemoryLayers(with: userMessage)
            
            let baseContext = await buildContext()

            if ragAnswerMode == .disabled, let orchestration = try? await mcpOrchestrator?.run(
                agentId: agentId,
                userText: prompt.text,
                baseContext: baseContext,
                options: normalizedOptions
            ) {
                for toolMessage in orchestration.toolMessages {
                    messages.append(toolMessage)
                    strategy.onAssistantMessage(toolMessage)
                    await memoryService.appendMessage(toolMessage)
                }

                let finalText = orchestration.finalAnswer.trimmingCharacters(in: .whitespacesAndNewlines)

                if !finalText.isEmpty {
                    let validation = await invariantService.validateResponse(
                        finalText,
                        fileName: invariantFileName
                    )

                    let safeContent: String

                    if validation.isValid {
                        safeContent = LocalPathPrivacy.redact(finalText)
                    } else {
                        let violations = validation.violations.joined(separator: "\n")
                        safeContent = """
                        I can’t recommend that option because it violates the project invariants.

                        Violations:
                        \(LocalPathPrivacy.redact(violations))

                        Please choose an option that stays within the defined architecture, stack, and business rules.
                        """
                    }

                    let assistantMessage = Message(
                        agentId: agentId,
                        role: .assistant,
                        content: safeContent
                    )

                    messages.append(assistantMessage)
                    strategy.onAssistantMessage(assistantMessage)
                    await memoryService.appendMessage(assistantMessage)

                    await advanceTaskStateIfNeeded(
                        userQuery: prompt.text,
                        assistantResponse: safeContent
                    )
                    
                    let item = DispatchWorkItem(flags: [], block: { [weak self] in
                        guard let self else { return }
                        
                        self.onToken?(safeContent)
                        self.onComplete?(OllamaChunk(
                            model: "",
                            createdAt: Date(),
                            message: .init(role: .assistant, content: safeContent),
                            done: true
                            ))
                    })

                    DispatchQueue.main.async(execute: item)

                    return
                }
            } else {
                
                if shouldSummarize {
                    try? await summarizeHistoryIfNeeded()
                }
                
                switch ragAnswerMode {
                case .disabled:
                    let context = await buildContext()
                    streamAnswer(context: context, userQuery: prompt.text)
                case .enabled:
                    if ragRetrievalMode == .compareEnhanced {
                        await compareEnhancedRAGAnswers(question: prompt.text)
                    } else {
                        await answerWithRAG(question: prompt.text)
                    }
                case .miniChat:
                    await answerWithRAGMiniChat(question: prompt.text)
                case .compare:
                    await compareRAGAnswers(question: prompt.text)
                }
            }
        }
    }

    private func developerHelpQuestion(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/help") else {
            return nil
        }

        let remainder = trimmed.dropFirst("/help".count)
        guard remainder.isEmpty || remainder.first?.isWhitespace == true else {
            return nil
        }

        let question = remainder
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if question.isEmpty {
            return "Какая структура проекта и где находятся основные модули?"
        }

        return String(question)
    }

    private func answerDeveloperHelp(question: String, userQuery: String) async {
        do {
            async let gitContext = developerGitContext()
            let ragQuestion = """
            Вопрос разработчика о проекте:
            \(question)

            Ответь на основе README, project/docs, схем данных и API-описаний из RAG-индекса. Если вопрос про структуру проекта, опиши основные модули и их ответственность. Если информации в документации не хватает, прямо скажи, чего не хватает.
            """

            let run = try await makeRAGAnswerRun(
                question: ragQuestion,
                keepSourcesForUnknown: true
            )
            let formatted = formatDeveloperHelpAnswer(
                question: question,
                ragAnswer: run.formattedAnswer,
                gitContext: await gitContext
            )
            let safeContent = await validatedContent(formatted)

            let assistantMessage = Message(
                agentId: agentId,
                role: .assistant,
                content: safeContent
            )

            messages.append(assistantMessage)
            strategy.onAssistantMessage(assistantMessage)
            await memoryService.appendMessage(assistantMessage)

            await advanceTaskStateIfNeeded(
                userQuery: userQuery,
                assistantResponse: safeContent
            )

            DispatchQueue.main.async { [weak self] in
                self?.onToken?(safeContent)
                self?.onComplete?(self?.makeCompletionChunk(
                    content: safeContent,
                    sourceChunk: run.responseChunk
                ) ?? OllamaChunk(
                    model: "",
                    createdAt: Date(),
                    message: .init(role: .assistant, content: safeContent),
                    done: true
                ))
            }
        } catch {
            let message = LocalPathPrivacy.redact("Developer help failed: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.onToken?(message)
            }
        }
    }

    private func developerGitContext() async -> String {
        guard let mcpOrchestrator else {
            return "Git context: unavailable."
        }

        await refreshMCPTools(force: true)

        do {
            let result = try await mcpOrchestrator.callTool(name: "git_current_branch")
            let content = LocalPathPrivacy.redact(result.content)

            if let info = decodeDeveloperGitBranchInfo(from: content) {
                let repository = info.repository?.isEmpty == false ? info.repository! : "unknown"
                return "Git context: repository \(repository), branch \(info.branch)."
            }

            return "Git context: \(content)"
        } catch {
            return LocalPathPrivacy.redact("Git context: unavailable (\(error.localizedDescription)).")
        }
    }

    private func decodeDeveloperGitBranchInfo(from text: String) -> DeveloperGitBranchInfo? {
        guard let data = text.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(DeveloperGitBranchInfo.self, from: data)
    }

    private func formatDeveloperHelpAnswer(
        question: String,
        ragAnswer: String,
        gitContext: String
    ) -> String {
        LocalPathPrivacy.redact("""
        Ассистент разработчика

        Вопрос:
        \(question)

        \(gitContext)

        \(ragAnswer)
        """)
    }

    private func developerSupportRequest(from text: String) -> DeveloperSupportRequest? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/support") else {
            return nil
        }

        let remainder = trimmed.dropFirst("/support".count)
        guard remainder.isEmpty || remainder.first?.isWhitespace == true else {
            return nil
        }

        let requestText = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestText.isEmpty else {
            return DeveloperSupportRequest(ticketId: nil, question: "")
        }

        let parts = requestText.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
        guard let ticketId = parts.first.map(String.init) else {
            return DeveloperSupportRequest(ticketId: nil, question: "")
        }

        guard isDeveloperSupportTicketId(ticketId) else {
            return DeveloperSupportRequest(ticketId: nil, question: requestText)
        }

        let question = parts.count > 1
            ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        return DeveloperSupportRequest(
            ticketId: ticketId,
            question: question.isEmpty ? "Сформируй ответ поддержки по этому тикету." : question
        )
    }

    private func isDeveloperSupportTicketId(_ value: String) -> Bool {
        let pattern = #"^[A-Za-z]+-\d+$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    private func answerDeveloperSupport(request: DeveloperSupportRequest, userQuery: String) async {
        do {
            let ticketId = try await resolveDeveloperSupportTicketId(for: request)
            let supportContext = try await developerSupportContext(ticketId: ticketId)
            async let ragContext = developerSupportRAGContext(
                question: request.question,
                ticket: supportContext.ticket,
                user: supportContext.user
            )

            let prompt = makeDeveloperSupportPrompt(
                request: request,
                context: supportContext,
                ragContext: await ragContext
            )
            let rawAnswer = try await streamer.send(
                messages: [
                    Message(
                        agentId: agentId,
                        role: .system,
                        content: """
                        You are a careful customer support assistant. Use product documentation context and ticket/user context to draft a helpful support response. Do not expose unnecessary personal data, internal identifiers, secrets, or absolute local paths. If context is insufficient, say what should be checked next.
                        """
                    ),
                    Message(
                        agentId: agentId,
                        role: .user,
                        content: prompt
                    )
                ],
                options: options
            )

            let formatted = formatDeveloperSupportAnswer(
                ticket: supportContext.ticket,
                answer: rawAnswer
            )
            let safeContent = await validatedContent(formatted)
            await completeDeveloperAssistantResponse(
                content: safeContent,
                userQuery: userQuery,
                sourceChunk: streamer.latestChunk
            )
        } catch {
            let message = LocalPathPrivacy.redact("Support assistant failed: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.onToken?(message)
            }
        }
    }

    private func resolveDeveloperSupportTicketId(for request: DeveloperSupportRequest) async throws -> String {
        if let ticketId = request.ticketId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !ticketId.isEmpty {
            return ticketId
        }

        let searchQuery = request.question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else {
            throw NSError(
                domain: "DeveloperSupport",
                code: 4,
                userInfo: [
                    NSLocalizedDescriptionKey: "Укажите вопрос или ticketId: /support T-1001 Почему не работает авторизация?"
                ]
            )
        }

        let matches = try await developerSupportSearchTickets(query: searchQuery)
        if matches.count == 1, let ticketId = matches.first?.ticketId {
            return ticketId
        }

        if matches.isEmpty {
            throw NSError(
                domain: "DeveloperSupport",
                code: 5,
                userInfo: [
                    NSLocalizedDescriptionKey: "Не нашел подходящий тикет по вопросу. Укажите ticketId явно: /support T-1001 \(searchQuery)"
                ]
            )
        }

        let options = matches
            .prefix(5)
            .map { "- \($0.ticketId): \($0.subject) (\($0.status))" }
            .joined(separator: "\n")
        throw NSError(
            domain: "DeveloperSupport",
            code: 6,
            userInfo: [
                NSLocalizedDescriptionKey: """
                Нашел несколько подходящих тикетов. Уточните ticketId:
                \(options)
                """
            ]
        )
    }

    private func developerSupportSearchTickets(query: String) async throws -> [DeveloperSupportTicket] {
        guard let mcpOrchestrator else {
            throw NSError(
                domain: "DeveloperSupport",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "MCP orchestrator is unavailable."]
            )
        }

        await refreshMCPTools(force: true)

        let result = try await mcpOrchestrator.callTool(
            name: "support_search_tickets",
            arguments: ["query": .string(query)]
        )
        let text = LocalPathPrivacy.redact(result.content)
        guard let data = text.data(using: .utf8) else {
            return []
        }

        return (try? JSONDecoder().decode([DeveloperSupportTicket].self, from: data)) ?? []
    }

    private func developerSupportContext(ticketId: String) async throws -> DeveloperSupportContext {
        guard let mcpOrchestrator else {
            throw NSError(
                domain: "DeveloperSupport",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "MCP orchestrator is unavailable."]
            )
        }

        await refreshMCPTools(force: true)

        let ticketResult = try await mcpOrchestrator.callTool(
            name: "support_get_ticket",
            arguments: ["ticketId": .string(ticketId)]
        )
        let ticketText = LocalPathPrivacy.redact(ticketResult.content)
        guard let ticket = decodeDeveloperSupportTicket(from: ticketText) else {
            throw NSError(
                domain: "DeveloperSupport",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Unable to decode support ticket context."]
            )
        }

        let userResult = try await mcpOrchestrator.callTool(
            name: "support_get_user",
            arguments: ["userId": .string(ticket.userId)]
        )
        let userText = LocalPathPrivacy.redact(userResult.content)
        guard let user = decodeDeveloperSupportUser(from: userText) else {
            throw NSError(
                domain: "DeveloperSupport",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Unable to decode support user context."]
            )
        }

        return DeveloperSupportContext(ticket: ticket, user: user)
    }

    private func developerSupportRAGContext(
        question: String,
        ticket: DeveloperSupportTicket,
        user: DeveloperSupportUser
    ) async -> String {
        let metadata = ticket.metadata
            .map { "\($0.key): \($0.value)" }
            .sorted()
            .joined(separator: "\n")
        let ragQuestion = LocalPathPrivacy.redact("""
        Нужно ответить на вопрос поддержки пользователя по продукту.

        Вопрос:
        \(question)

        Тема тикета:
        \(ticket.subject)

        Сигналы из тикета:
        \(metadata.isEmpty ? "Нет metadata." : metadata)

        Тариф: \(user.plan)
        Email подтвержден: \(user.emailVerified ? "yes" : "no")

        Найди в FAQ, документации и troubleshooting знания по этой проблеме. Не включай персональные данные, только продуктовые причины, проверки и рекомендации.
        """)

        do {
            let run = try await makeRAGAnswerRun(
                question: ragQuestion,
                keepSourcesForUnknown: true
            )
            return run.formattedAnswer
        } catch {
            return LocalPathPrivacy.redact("RAG context unavailable: \(error.localizedDescription)")
        }
    }

    private func makeDeveloperSupportPrompt(
        request: DeveloperSupportRequest,
        context: DeveloperSupportContext,
        ragContext: String
    ) -> String {
        let ticket = context.ticket
        let user = context.user
        let messages = ticket.messages.isEmpty
            ? "No ticket messages."
            : ticket.messages.map { "- \($0)" }.joined(separator: "\n")
        let metadata = ticket.metadata.isEmpty
            ? "No ticket metadata."
            : ticket.metadata.map { "- \($0.key): \($0.value)" }.sorted().joined(separator: "\n")

        return LocalPathPrivacy.redact("""
        Сформируй ответ ассистента поддержки.

        Ticket:
        id: \(ticket.ticketId)
        subject: \(ticket.subject)
        status: \(ticket.status)

        User context:
        plan: \(user.plan)
        emailVerified: \(user.emailVerified)
        lastLoginAt: \(user.lastLoginAt)

        Ticket messages:
        \(messages)

        Ticket metadata:
        \(metadata)

        Support question:
        \(request.question)

        Product knowledge from RAG:
        \(ragContext)

        Верни ответ строго в структуре:
        Проблема:
        ...

        Контекст пользователя:
        ...

        Вероятная причина:
        ...

        Ответ пользователю:
        ...

        Что проверить внутри:
        - ...

        Следующий шаг:
        ...

        Не раскрывай лишние персональные данные. Если данных недостаточно, явно укажи, что нужно проверить.
        """)
    }

    private func formatDeveloperSupportAnswer(
        ticket: DeveloperSupportTicket,
        answer: String
    ) -> String {
        LocalPathPrivacy.redact("""
        Ассистент поддержки

        Ticket: \(ticket.ticketId)
        Status: \(ticket.status)

        \(answer.trimmingCharacters(in: .whitespacesAndNewlines))
        """)
    }

    private func developerCodeReviewFocus(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/review") else {
            return nil
        }

        let remainder = trimmed.dropFirst("/review".count)
        guard remainder.isEmpty || remainder.first?.isWhitespace == true else {
            return nil
        }

        let focus = remainder
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return focus.isEmpty ? "" : String(focus)
    }

    private func answerDeveloperCodeReview(focus: String, userQuery: String) async {
        do {
            let gitContext = try await developerReviewGitContext()
            guard !gitContext.diff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                let noDiffMessage = formatDeveloperCodeReviewNoDiffAnswer(gitContext: gitContext)
                let safeContent = await validatedContent(noDiffMessage)
                await completeDeveloperAssistantResponse(
                    content: safeContent,
                    userQuery: userQuery,
                    sourceChunk: nil
                )
                return
            }

            async let ragContext = developerReviewRAGContext(
                files: gitContext.files,
                focus: focus
            )

            let reviewPrompt = makeDeveloperCodeReviewPrompt(
                gitContext: gitContext,
                ragContext: await ragContext,
                focus: focus
            )
            let rawReview = try await streamer.send(
                messages: [
                    Message(
                        agentId: agentId,
                        role: .system,
                        content: """
                        You are a senior code reviewer for a local developer assistant. Prioritize concrete bugs, architecture risks, and practical recommendations. Do not reveal absolute local user paths. Do not invent files or behavior that are not supported by the diff or context.
                        """
                    ),
                    Message(
                        agentId: agentId,
                        role: .user,
                        content: reviewPrompt
                    )
                ],
                options: options
            )

            let formatted = formatDeveloperCodeReviewAnswer(
                gitContext: gitContext,
                review: rawReview
            )
            let safeContent = await validatedContent(formatted)
            await completeDeveloperAssistantResponse(
                content: safeContent,
                userQuery: userQuery,
                sourceChunk: streamer.latestChunk
            )
        } catch {
            let message = LocalPathPrivacy.redact("Developer code review failed: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.onToken?(message)
            }
        }
    }

    private func developerReviewGitContext() async throws -> DeveloperReviewGitContext {
        guard let mcpOrchestrator else {
            throw NSError(
                domain: "DeveloperCodeReview",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "MCP orchestrator is unavailable."]
            )
        }

        await refreshMCPToolsIfNeeded()

        async let changedFilesResult = mcpOrchestrator.callTool(name: "git_changed_files")
        async let diffResult = mcpOrchestrator.callTool(name: "git_diff")

        let changedFilesToolResult = try await changedFilesResult
        let diffToolResult = try await diffResult
        let changedFilesContent = LocalPathPrivacy.redact(changedFilesToolResult.content)
        let diffContent = LocalPathPrivacy.redact(diffToolResult.content)

        let changedFiles = decodeDeveloperChangedFiles(from: changedFilesContent)
        let diff = decodeDeveloperGitDiff(from: diffContent)

        return DeveloperReviewGitContext(
            repository: changedFiles?.repository ?? diff?.repository ?? "unknown",
            branch: changedFiles?.branch ?? diff?.branch ?? "unknown",
            files: changedFiles?.files ?? [],
            diff: diff?.diff ?? diffContent
        )
    }

    private func developerReviewRAGContext(files: [DeveloperChangedFile], focus: String) async -> String {
        let fileList = files.isEmpty
            ? "No changed files were reported."
            : files.map { "- \($0.path) (\($0.status))" }.joined(separator: "\n")
        let focusText = focus.isEmpty ? "Общий code review текущих изменений." : focus
        let ragQuestion = """
        Для code review изменений в проекте AIChallenge нужен архитектурный контекст.

        Измененные файлы:
        \(fileList)

        Фокус ревью:
        \(focusText)

        Опиши ответственность затронутых модулей, важные ограничения архитектуры, риски вокруг MCP/RAG/LLM flow и проверки, которые стоит выполнить. Если документации недостаточно, скажи об этом явно.
        """

        do {
            let run = try await makeRAGAnswerRun(
                question: ragQuestion,
                keepSourcesForUnknown: true
            )
            return run.formattedAnswer
        } catch {
            return LocalPathPrivacy.redact("RAG context unavailable: \(error.localizedDescription)")
        }
    }

    private func makeDeveloperCodeReviewPrompt(
        gitContext: DeveloperReviewGitContext,
        ragContext: String,
        focus: String
    ) -> String {
        let fileList = gitContext.files.isEmpty
            ? "No changed files were reported."
            : gitContext.files.map { "- \($0.path) (\($0.status))" }.joined(separator: "\n")
        let truncatedDiff = truncatedDeveloperReviewDiff(gitContext.diff)
        let truncationNote = truncatedDiff.wasTruncated
            ? "\nDiff note: diff was truncated to \(developerReviewDiffCharacterLimit) characters."
            : ""
        let focusText = focus.isEmpty ? "General review of the current repository changes." : focus

        return LocalPathPrivacy.redact("""
        Review the current local changes for AIChallenge.

        Repository: \(gitContext.repository)
        Branch: \(gitContext.branch)
        Focus: \(focusText)

        Changed files:
        \(fileList)

        RAG context:
        \(ragContext)

        Diff:
        \(truncatedDiff.text)
        \(truncationNote)

        Return the review in this exact structure:
        Potential Bugs
        - ...

        Architecture Concerns
        - ...

        Recommendations
        - ...

        Tests To Add Or Check
        - ...

        If there are no findings in a section, say "No clear issues found."
        """)
    }

    private func truncatedDeveloperReviewDiff(_ diff: String) -> (text: String, wasTruncated: Bool) {
        guard diff.count > developerReviewDiffCharacterLimit else {
            return (diff, false)
        }

        let endIndex = diff.index(diff.startIndex, offsetBy: developerReviewDiffCharacterLimit)
        return (String(diff[..<endIndex]), true)
    }

    private func formatDeveloperCodeReviewAnswer(
        gitContext: DeveloperReviewGitContext,
        review: String
    ) -> String {
        let fileList = gitContext.files.isEmpty
            ? "No changed files reported."
            : gitContext.files.map { "- \($0.path) (\($0.status))" }.joined(separator: "\n")

        return LocalPathPrivacy.redact("""
        Ассистент разработчика

        Code Review

        Repository: \(gitContext.repository)
        Branch: \(gitContext.branch)

        Changed files:
        \(fileList)

        \(review.trimmingCharacters(in: .whitespacesAndNewlines))
        """)
    }

    private func formatDeveloperCodeReviewNoDiffAnswer(gitContext: DeveloperReviewGitContext) -> String {
        let fileList = gitContext.files.isEmpty
            ? "No changed files reported."
            : gitContext.files.map { "- \($0.path) (\($0.status))" }.joined(separator: "\n")

        return LocalPathPrivacy.redact("""
        Ассистент разработчика

        Code Review

        Repository: \(gitContext.repository)
        Branch: \(gitContext.branch)

        Changed files:
        \(fileList)

        No staged or unstaged diff was returned by GitHubMCPServer, so there is nothing concrete to review yet.
        """)
    }

    private func completeDeveloperAssistantResponse(
        content: String,
        userQuery: String,
        sourceChunk: OllamaChunk?
    ) async {
        let safeContent = LocalPathPrivacy.redact(content)
        let assistantMessage = Message(
            agentId: agentId,
            role: .assistant,
            content: safeContent
        )

        messages.append(assistantMessage)
        strategy.onAssistantMessage(assistantMessage)
        await memoryService.appendMessage(assistantMessage)

        await advanceTaskStateIfNeeded(
            userQuery: userQuery,
            assistantResponse: safeContent
        )

        DispatchQueue.main.async { [weak self] in
            self?.onToken?(safeContent)
            self?.onComplete?(self?.makeCompletionChunk(
                content: safeContent,
                sourceChunk: sourceChunk
            ) ?? OllamaChunk(
                model: "",
                createdAt: Date(),
                message: .init(role: .assistant, content: safeContent),
                done: true
            ))
        }
    }
    
    func startTask(title: String, plan: [String]) {
        Task {
            self.currentTaskContext = await taskContextService.startTask(
                agentId: agentId,
                task: title,
                plan: plan
            )
        }
    }
    
    func deleteAllMessages() {
        Task { [weak self] in
            guard let self else { return }
            
            let system = makeSystemMessage()
            
            self.summary = ""
            self.messages = [system]
            self.currentTaskContext = nil
            self.ragMiniChatTaskState = .empty
            self.strategy = self.strategy.makeCleanCopy()
            
            await self.memoryService.deleteMessages(agentId: self.agentId)
            await self.memoryService.appendMessage(system)
        }
    }
    
    func deleteAllAgentData() {
        deleteAllMessages()
        
        Task { [weak self] in
            guard let self else { return }
            
            try? await self.indexingService.deleteAll()
            _ = try? await self.ragMCPClient.clearIndex()
            await self.ragRetrievalService.invalidateCache()
        }
    }
    
    func set(strategy: ContextStrategyProtocol) {
        self.strategy = strategy.makeCleanCopy()
        self.strategy.rebuild(from: messages)
    }
    
    func setTaskPlanningEnabled(_ isEnabled: Bool) {
        self.isTaskPlanningEnabled = isEnabled
    }
    
    func setRAGAnswerMode(_ mode: RAGAnswerMode) {
        self.ragAnswerMode = mode
    }

    func setRAGSourceType(_ sourceType: RAGSourceType) {
        self.ragSourceType = sourceType
    }
    
    func setRAGChunkingStrategy(_ strategy: RAGChunkingStrategy) {
        self.ragChunkingStrategy = strategy
    }
    
    func setRAGRetrievalMode(_ mode: RAGRetrievalMode) {
        self.ragRetrievalMode = mode
    }
    
    func setRAGEvaluationMode(_ mode: RAGEvaluationMode) {
        self.ragEvaluationMode = mode
    }
    
    func setRAGRetrievalSettings(_ settings: RAGRetrievalSettings) {
        self.ragRetrievalSettings = settings
    }
    
    func invalidateRAGRetrievalCache() {
        Task { [weak self] in
            await self?.ragRetrievalService.invalidateCache()
        }
    }
    
    // MARK: - Prepare
    
    private func prepareIfNeeded() async {
        guard !isPrepared else { return }
        
        await loadHistory()
        self.currentTaskContext = await taskContextService.loadCurrent(agentId: agentId)
        self.userProfile = await userProfileService.fetchProfile(userId: userId) ??  self.userProfile
        await refreshMCPToolsIfNeeded()
        
        isPrepared = true
    }
    
    private func loadHistory() async {
        let stored = (try? await memoryService.loadMessages(agentId: agentId)) ?? []
        
        if stored.isEmpty {
            let system = makeSystemMessage()
            messages = [system]
            await memoryService.appendMessage(system)
        } else {
            messages = stored
            
            if messages.first(where: { $0.role == .system }) == nil {
                let system = makeSystemMessage()
                messages.insert(system, at: 0)
                await memoryService.appendMessage(system)
            }
        }
        
        strategy.rebuild(from: messages)
    }
    
    // MARK: - Context
    
    private var shouldSummarize: Bool {
        !(strategy is BranchingStrategy)
    }
    
    private func buildContext() async -> [Message] {
        var context: [Message] = []
        let promptContextSettings = currentPromptContextSettings()
        
        let system = messages.first(where: { $0.role == .system }) ?? makeSystemMessage()
        context.append(system)
        
        if promptContextSettings.includeUserProfile,
           let profileText = await userProfileService.makeProfilePrompt(userId: userId),
           !profileText.isEmpty {
            context.append(
                Message(
                    agentId: agentId,
                    role: .system,
                    content: profileText
                )
            )
        }
        
        if promptContextSettings.includeInvariants,
           let invariantPrompt = await invariantService.makePrompt(fileName: invariantFileName),
           !invariantPrompt.isEmpty {
            context.append(
                Message(
                    agentId: agentId,
                    role: .system,
                    content: invariantPrompt
                )
            )
        }
        
        if promptContextSettings.includeMCPTools, !cachedMCPTools.isEmpty {
            let text = cachedMCPTools
                .map { tool in
                    if let description = tool.description, !description.isEmpty {
                        return "- \(tool.name): \(description)"
                    } else {
                        return "- \(tool.name)"
                    }
                }
                .joined(separator: "\n")

            context.append(
                Message(
                    agentId: agentId,
                    role: .system,
                    content: """
                    Available MCP tools:
                    \(text)

                    Use tool results when they are present in the conversation context.
                    """
                )
            )
        }
        
        let working = await memoryService.fetchWorking(agentId: agentId)
        if promptContextSettings.includeWorkingMemory, !working.isEmpty {
            let text = working
                .map { "\($0.key): \($0.value)" }
                .joined(separator: "\n")
            
            context.append(
                Message(
                    agentId: agentId,
                    role: .system,
                    content: "Working memory:\n\(text)"
                )
            )
        }
        
        let longTerm = await memoryService.fetchLongTerm(userId: userId)
        if promptContextSettings.includeLongTermMemory, !longTerm.isEmpty {
            let text = longTerm
                .map(\.content)
                .joined(separator: "\n")
            
            context.append(
                Message(
                    agentId: agentId,
                    role: .system,
                    content: "Long-term memory:\n\(text)"
                )
            )
        }
        
        if promptContextSettings.includeTaskState,
           isTaskPlanningEnabled,
           let taskContext = currentTaskContext {
            context.append(
                Message(
                    agentId: agentId,
                    role: .system,
                    content: """
                    Current task state:
                    - phase: \(taskContext.phase.title)
                    - step: \(taskContext.step)/\(taskContext.total)
                    - current: \(taskContext.current)
                    - expected action: \(taskContext.expectedAction)
                    """
                )
            )
        }
        
        let strategyMessages = strategy
            .buildContext(
                messages: messages,
                summary: promptContextSettings.includeConversationSummary ? summary : ""
            )
            .filter { candidate in
                !(candidate.role == .system && candidate.content == system.content)
            }
        
        context.append(contentsOf: strategyMessages)
        return context
    }
    
    private func makeRAGContext(
        question: String,
        baseContext: [Message]
    ) async -> (messages: [Message], sources: [RAGRetrievedChunk], retrievalResult: RAGRetrievalResult?) {
        do {
            let result: RAGRetrievalResult?
            let sources: [RAGRetrievedChunk]
            
            switch ragRetrievalMode {
            case .basic, .compareEnhanced:
                sources = try await ragRetrievalService.retrieve(
                    question: question,
                    strategy: ragChunkingStrategy,
                    limit: ragRetrievalSettings.topKAfterFiltering
                )
                result = nil
            case .enhanced:
                let searchQuery = await makeRAGSearchQuery(from: question)
                let retrievalResult = try await ragRetrievalService.retrieve(
                    originalQuestion: question,
                    searchQuery: searchQuery,
                    strategy: ragChunkingStrategy,
                    settings: ragRetrievalSettings
                )
                sources = retrievalResult.chunksAfterFiltering
                result = retrievalResult
            }
            
            let ragMessage = Message(
                agentId: agentId,
                role: .system,
                content: makeRAGPrompt(from: sources, retrievalResult: result)
            )
            
            return (insert(ragMessage, beforeLastUserMessageIn: baseContext), sources, result)
        } catch {
            let ragMessage = Message(
                agentId: agentId,
                role: .system,
                content: """
                RAG retrieval failed: \(error.localizedDescription)

                Answer the user without local indexed context and say that RAG retrieval was unavailable if local project knowledge is required.
                """
            )
            
            return (insert(ragMessage, beforeLastUserMessageIn: baseContext), [], nil)
        }
    }
    
    private func makeRAGSearchQuery(from question: String) async -> String {
        guard ragRetrievalSettings.isQueryRewriteEnabled else {
            return question
        }
        
        do {
            return try await ragQueryRewriteService.rewrite(
                question: question,
                options: makeAnyOptions(from: options)
            )
        } catch {
            print("RAG query rewrite failed:", error)
            return question
        }
    }
    
    private func makeUserPromptText(from text: String) async -> String {
        guard isTaskPlanningEnabled else {
            return text
        }
        
        if currentTaskContext == nil {
            let plan = await generateInitialPlan(for: text)
            currentTaskContext = await taskContextService.startTask(
                agentId: agentId,
                task: text,
                plan: plan
            )
        }
        
        guard let taskContext = currentTaskContext else {
            return text
        }
        
        let profilePrompt = currentPromptContextSettings().includeUserProfile
            ? await userProfileService.makeProfilePrompt(userId: userId)
            : nil
        return promptBuilder.buildPrompt(
            query: text,
            context: taskContext,
            profilePrompt: profilePrompt
        )
    }
    
    private func makeRAGPrompt(
        from sources: [RAGRetrievedChunk],
        retrievalResult: RAGRetrievalResult? = nil,
        taskState: RAGTaskState? = nil
    ) -> String {
        let taskMemoryPrompt: String
        if currentPromptContextSettings().includeRAGTaskMemory {
            taskMemoryPrompt = taskState
                .map { "\n\n\(ragTaskMemoryService.makePrompt(from: $0))" }
                ?? ""
        } else {
            taskMemoryPrompt = ""
        }
        
        guard !sources.isEmpty else {
            if let retrievalResult, !retrievalResult.candidatesBeforeFiltering.isEmpty {
                return """
                RAG mode is enabled, but relevance filtering removed all retrieved chunks.

                If the user's question depends on indexed documents, say that the local RAG index does not contain enough relevant information.
                \(taskMemoryPrompt)
                """
            }
            
            return """
            RAG mode is enabled, but no indexed chunks were found.

            If the user's question depends on indexed documents, say that the local RAG index does not contain enough information.
            \(taskMemoryPrompt)
            """
        }
        
        let context = sources.enumerated()
            .map { index, item in
                """
                [\(index + 1)] source: \(item.chunk.title)
                section: \(item.chunk.section)
                chunk_id: \(item.chunk.chunkId)
                score: \(String(format: "%.4f", item.score))
                relevance: \(String(format: "%.4f", item.relevanceScore))
                reason: \(item.relevanceReason)
                content:
                \(item.chunk.content)
                """
            }
            .joined(separator: "\n\n")
        
        let retrievalNotes: String
        
        if let retrievalResult {
            let rewriteText = retrievalResult.rewrittenQuestion ?? "not used"
            retrievalNotes = """
            
            Retrieval:
            original question: \(retrievalResult.originalQuestion)
            rewritten query: \(rewriteText)
            candidates before filtering: \(retrievalResult.candidatesBeforeFiltering.count)
            chunks after filtering: \(retrievalResult.chunksAfterFiltering.count)
            """
        } else {
            retrievalNotes = ""
        }
        
        return """
        Use the local RAG context below to answer the user's question.
        Prefer the context over general knowledge.
        Answer only from the provided chunks.
        If task memory is present, preserve the user's goal, clarifications, constraints, and fixed terms across turns.
        Every non-unknown answer must include sources and verbatim quotes from the chunks.
        Use the source, section, and chunk_id values exactly as shown in the context.
        Quotes must be exact fragments copied from chunk content.
        If the context does not contain enough information, set is_unknown to true, answer "Не знаю", and ask for clarification.
        Return only valid JSON with this shape:
        {
          "answer": "short answer",
          "sources": [
            {"source": "File.swift", "section": "section name", "chunk_id": 1}
          ],
          "quotes": [
            {"source": "File.swift", "section": "section name", "chunk_id": 1, "text": "verbatim quote"}
          ],
          "is_unknown": false,
          "clarification_request": null
        }
        \(retrievalNotes)
        \(taskMemoryPrompt)

        RAG context:
        \(context)
        """
    }
    
    private func insert(_ message: Message, beforeLastUserMessageIn context: [Message]) -> [Message] {
        var result = context
        
        if let lastUserIndex = result.lastIndex(where: { $0.role == .user }) {
            result.insert(message, at: lastUserIndex)
        } else {
            result.append(message)
        }
        
        return result
    }
    
    private func streamAnswer(context: [Message], userQuery: String) {
        var fullResponse = ""
        
        streamer.onToken = { [weak self] token in
            fullResponse += token
            DispatchQueue.main.async { [weak self] in
                self?.onToken?(token)
            }
        }
        
        streamer.onComplete = { [weak self] ollamaChunk in
            guard let self else { return }
            
            let finalText = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            let content = finalText.isEmpty ? ollamaChunk.message.content : finalText
            
            Task {
                let safeContent = await self.validatedContent(content)
                
                let assistantMessage = Message(
                    agentId: self.agentId,
                    role: .assistant,
                    content: safeContent
                )
                
                self.messages.append(assistantMessage)
                self.strategy.onAssistantMessage(assistantMessage)
                await self.memoryService.appendMessage(assistantMessage)
                
                await self.advanceTaskStateIfNeeded(
                    userQuery: userQuery,
                    assistantResponse: safeContent
                )
            }
            
            DispatchQueue.main.async {
                self.onComplete?(ollamaChunk)
            }
        }
        
        streamer.start(messages: context, options: self.options)
    }
    
    private func answerWithRAG(question: String) async {
        do {
            let run = try await makeRAGAnswerRun(question: question)
            let safeContent = await validatedContent(run.formattedAnswer)
            
            let assistantMessage = Message(
                agentId: agentId,
                role: .assistant,
                content: safeContent
            )
            
            messages.append(assistantMessage)
            strategy.onAssistantMessage(assistantMessage)
            await memoryService.appendMessage(assistantMessage)
            
            await advanceTaskStateIfNeeded(
                userQuery: question,
                assistantResponse: safeContent
            )
            
            DispatchQueue.main.async { [weak self] in
                self?.onToken?(safeContent)
                self?.onComplete?(self?.makeCompletionChunk(
                    content: safeContent,
                    sourceChunk: run.responseChunk
                ) ?? OllamaChunk(
                    model: "",
                    createdAt: Date(),
                    message: .init(role: .assistant, content: safeContent),
                    done: true
                ))
            }
        } catch {
            let message = "RAG answer failed: \(error.localizedDescription)"
            DispatchQueue.main.async { [weak self] in
                self?.onToken?(message)
            }
        }
    }
    
    private func answerWithRAGMiniChat(question: String) async {
        do {
            ragMiniChatTaskState = ragTaskMemoryService.update(
                state: ragMiniChatTaskState,
                userMessage: question,
                assistantAnswer: nil
            )
            
            let searchQuestion = makeRAGMiniChatSearchQuestion(
                question: question,
                taskState: ragMiniChatTaskState
            )
            let run = try await makeRAGAnswerRun(
                question: question,
                taskState: ragMiniChatTaskState,
                searchQuestion: searchQuestion,
                keepSourcesForUnknown: true
            )
            ragMiniChatTaskState = ragTaskMemoryService.update(
                state: ragMiniChatTaskState,
                userMessage: question,
                assistantAnswer: run.contract.answer
            )
            
            let formatted = formatRAGMiniChatAnswer(
                run: run,
                taskState: ragMiniChatTaskState
            )
            let safeContent = await validatedContent(formatted)
            
            let assistantMessage = Message(
                agentId: agentId,
                role: .assistant,
                content: safeContent
            )
            
            messages.append(assistantMessage)
            strategy.onAssistantMessage(assistantMessage)
            await memoryService.appendMessage(assistantMessage)
            
            await advanceTaskStateIfNeeded(
                userQuery: question,
                assistantResponse: safeContent
            )
            
            DispatchQueue.main.async { [weak self] in
                self?.onToken?(safeContent)
                self?.onComplete?(self?.makeCompletionChunk(
                    content: safeContent,
                    sourceChunk: run.responseChunk
                ) ?? OllamaChunk(
                    model: "",
                    createdAt: Date(),
                    message: .init(role: .assistant, content: safeContent),
                    done: true
                ))
            }
        } catch {
            let message = "RAG mini-chat answer failed: \(error.localizedDescription)"
            DispatchQueue.main.async { [weak self] in
                self?.onToken?(message)
            }
        }
    }
    
    private func makeRAGAnswerRun(
        question: String,
        appendingQuestionToContext: Bool = false,
        taskState: RAGTaskState? = nil,
        searchQuestion: String? = nil,
        keepSourcesForUnknown: Bool = false
    ) async throws -> RAGEvaluationAnswerRun {
        switch ragSourceType {
        case .mcpServer:
            return try await makeMCPRAGAnswerRun(
                question: question,
                searchQuestion: searchQuestion,
                keepSourcesForUnknown: keepSourcesForUnknown
            )
        case .builtIn:
            return try await makeBuiltInRAGAnswerRun(
                question: question,
                appendingQuestionToContext: appendingQuestionToContext,
                taskState: taskState,
                searchQuestion: searchQuestion,
                keepSourcesForUnknown: keepSourcesForUnknown
            )
        }
    }

    private func makeMCPRAGAnswerRun(
        question: String,
        searchQuestion: String?,
        keepSourcesForUnknown: Bool
    ) async throws -> RAGEvaluationAnswerRun {
        let mcpSearchQuery: String?
        if let searchQuestion {
            mcpSearchQuery = searchQuestion
        } else {
            mcpSearchQuery = await searchQueryForRAGMCP(question: question)
        }
        let mcpRun = try await ragMCPClient.answer(
            question: question,
            searchQuery: mcpSearchQuery,
            retrievalMode: ragRetrievalMode,
            strategy: ragChunkingStrategy,
            settings: ragRetrievalSettings,
            includeChunks: true
        )
        let retrievedChunks = mcpRun.chunks?.map {
            $0.makeRetrievedChunk(strategy: ragChunkingStrategy)
        } ?? []
        let retrievalResult = RAGRetrievalResult(
            originalQuestion: mcpRun.retrieval.originalQuestion,
            rewrittenQuestion: mcpRun.retrieval.searchQuery == mcpRun.retrieval.originalQuestion ? nil : mcpRun.retrieval.searchQuery,
            candidatesBeforeFiltering: [],
            chunksAfterFiltering: retrievedChunks
        )
        let finalContract: RAGAnswerContract
        let finalValidation: RAGAnswerValidationResult

        if mcpRun.contract.isUnknown, keepSourcesForUnknown, !retrievedChunks.isEmpty {
            finalContract = makeUnknownRAGContract(sources: retrievedChunks)
            finalValidation = ragAnswerValidationService.validate(
                answer: finalContract,
                retrievedChunks: retrievedChunks
            )
        } else {
            finalContract = mcpRun.contract
            finalValidation = mcpRun.validation
        }

        return RAGEvaluationAnswerRun(
            contract: finalContract,
            formattedAnswer: formatRAGAnswer(finalContract, validation: finalValidation),
            retrievedChunks: retrievedChunks,
            retrievalResult: retrievalResult,
            validation: finalValidation,
            responseChunk: nil
        )
    }

    private func makeBuiltInRAGAnswerRun(
        question: String,
        appendingQuestionToContext: Bool,
        taskState: RAGTaskState?,
        searchQuestion: String?,
        keepSourcesForUnknown: Bool
    ) async throws -> RAGEvaluationAnswerRun {
        let evidence = try await retrieveRAGEvidence(question: searchQuestion ?? question)

        if isWeakRAGContext(evidence.sources) {
            let contract = keepSourcesForUnknown
                ? makeUnknownRAGContract(sources: evidence.sources)
                : makeUnknownRAGContract()
            let validation = ragAnswerValidationService.validate(
                answer: contract,
                retrievedChunks: evidence.sources
            )

            return RAGEvaluationAnswerRun(
                contract: contract,
                formattedAnswer: formatRAGAnswer(contract, validation: validation),
                retrievedChunks: evidence.sources,
                retrievalResult: evidence.retrievalResult,
                validation: validation,
                responseChunk: nil
            )
        }

        let baseContext = await buildContext()
        let ragMessage = Message(
            agentId: agentId,
            role: .system,
            content: makeRAGPrompt(
                from: evidence.sources,
                retrievalResult: evidence.retrievalResult,
                taskState: taskState
            )
        )
        var context = insert(ragMessage, beforeLastUserMessageIn: baseContext)

        if appendingQuestionToContext {
            context.append(
                Message(
                    agentId: agentId,
                    role: .user,
                    content: question
                )
            )
        }

        let rawAnswer = try await streamer.send(
            messages: context,
            options: makeAnyOptions(from: options)
        )
        let responseChunk = streamer.latestChunk
        let contract = parseRAGAnswerContract(from: rawAnswer)
            ?? makeFallbackRAGContract(
                answer: rawAnswer,
                sources: evidence.sources
            )
        let validation = ragAnswerValidationService.validate(
            answer: contract,
            retrievedChunks: evidence.sources
        )
        let finalContract = validation.isValid
            ? contract
            : makeFallbackRAGContract(answer: contract.answer, sources: evidence.sources)
        let finalValidation = ragAnswerValidationService.validate(
            answer: finalContract,
            retrievedChunks: evidence.sources
        )

        return RAGEvaluationAnswerRun(
            contract: finalContract,
            formattedAnswer: formatRAGAnswer(finalContract, validation: finalValidation),
            retrievedChunks: evidence.sources,
            retrievalResult: evidence.retrievalResult,
            validation: finalValidation,
            responseChunk: responseChunk
        )
    }

    private func searchQueryForRAGMCP(question: String) async -> String? {
        guard ragRetrievalMode != .basic,
              ragRetrievalSettings.isQueryRewriteEnabled else {
            return nil
        }

        return await makeRAGSearchQuery(from: question)
    }
    
    private func retrieveRAGEvidence(
        question: String
    ) async throws -> (sources: [RAGRetrievedChunk], retrievalResult: RAGRetrievalResult?) {
        switch ragRetrievalMode {
        case .basic, .compareEnhanced:
            let sources = try await ragRetrievalService.retrieve(
                question: question,
                strategy: ragChunkingStrategy,
                limit: ragRetrievalSettings.topKAfterFiltering
            )
            return (sources, nil)
        case .enhanced:
            let searchQuery = await makeRAGSearchQuery(from: question)
            let retrievalResult = try await ragRetrievalService.retrieve(
                originalQuestion: question,
                searchQuery: searchQuery,
                strategy: ragChunkingStrategy,
                settings: ragRetrievalSettings
            )
            return (retrievalResult.chunksAfterFiltering, retrievalResult)
        }
    }
    
    private func isWeakRAGContext(_ sources: [RAGRetrievedChunk]) -> Bool {
        guard let best = sources.map(\.relevanceScore).max() else {
            return true
        }
        
        return best < ragRetrievalSettings.similarityThreshold
    }
    
    private func makeUnknownRAGContract() -> RAGAnswerContract {
        RAGAnswerContract(
            answer: "Не знаю. В найденном контексте недостаточно релевантной информации, чтобы ответить уверенно.",
            sources: [],
            quotes: [],
            isUnknown: true,
            clarificationRequest: "Уточните вопрос или добавьте больше контекста."
        )
    }
    
    private func makeUnknownRAGContract(sources: [RAGRetrievedChunk]) -> RAGAnswerContract {
        guard !sources.isEmpty else {
            return makeUnknownRAGContract()
        }
        
        return RAGAnswerContract(
            answer: "Не знаю. В найденном контексте недостаточно релевантной информации, чтобы ответить уверенно.",
            sources: sources.map {
                RAGAnswerSource(
                    source: $0.chunk.title,
                    section: $0.chunk.section,
                    chunkID: $0.chunk.chunkId
                )
            },
            quotes: sources.prefix(3).map {
                RAGAnswerQuote(
                    source: $0.chunk.title,
                    section: $0.chunk.section,
                    chunkID: $0.chunk.chunkId,
                    text: makeQuoteSnippet(from: $0.chunk.content)
                )
            },
            isUnknown: true,
            clarificationRequest: "Уточните вопрос или добавьте более релевантные документы в RAG индекс."
        )
    }
    
    private func makeFallbackRAGContract(
        answer: String,
        sources: [RAGRetrievedChunk]
    ) -> RAGAnswerContract {
        let answerText = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceItems = sources.map {
            RAGAnswerSource(
                source: $0.chunk.title,
                section: $0.chunk.section,
                chunkID: $0.chunk.chunkId
            )
        }
        let quoteItems = sources.prefix(3).map {
            RAGAnswerQuote(
                source: $0.chunk.title,
                section: $0.chunk.section,
                chunkID: $0.chunk.chunkId,
                text: makeQuoteSnippet(from: $0.chunk.content)
            )
        }
        
        return RAGAnswerContract(
            answer: answerText.isEmpty ? "Ответ сформирован по найденному RAG-контексту." : answerText,
            sources: sourceItems,
            quotes: quoteItems,
            isUnknown: false,
            clarificationRequest: nil
        )
    }
    
    private func makeQuoteSnippet(from text: String) -> String {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        guard normalized.count > 240 else {
            return normalized
        }
        
        let endIndex = normalized.index(normalized.startIndex, offsetBy: 240)
        return String(normalized[..<endIndex])
    }
    
    private func parseRAGAnswerContract(from text: String) -> RAGAnswerContract? {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard
            let start = cleaned.firstIndex(of: "{"),
            let end = cleaned.lastIndex(of: "}")
        else {
            return nil
        }
        
        let json = String(cleaned[start...end])
        guard let data = json.data(using: .utf8) else {
            return nil
        }
        
        return try? JSONDecoder().decode(RAGAnswerContract.self, from: data)
    }
    
    private func formatRAGAnswer(
        _ contract: RAGAnswerContract,
        validation: RAGAnswerValidationResult
    ) -> String {
        let sourcesText = contract.sources.isEmpty
            ? "-"
            : contract.sources.enumerated()
                .map { index, source in
                    "\(index + 1). \(source.source), section: \(source.section ?? "-"), chunk_id: \(source.chunkID)"
                }
                .joined(separator: "\n")
        
        let quotesText = contract.quotes.isEmpty
            ? "-"
            : contract.quotes.enumerated()
                .map { index, quote in
                    "\(index + 1). \(quote.source), section: \(quote.section ?? "-"), chunk_id: \(quote.chunkID)\n\"\(quote.text)\""
                }
                .joined(separator: "\n\n")
        
        let clarification = contract.clarificationRequest
            .map { "\n\nУточнение:\n\($0)" }
            ?? ""
        let validationNotes = validation.notes.isEmpty || contract.isUnknown
            ? ""
            : "\n\nValidation notes:\n\(validation.notes.map { "- \($0)" }.joined(separator: "\n"))"
        
        return """
        Ответ:
        \(contract.answer)\(clarification)

        Источники:
        \(sourcesText)

        Цитаты:
        \(quotesText)\(validationNotes)
        """
    }
    
    private func formatRAGMiniChatAnswer(
        run: RAGEvaluationAnswerRun,
        taskState: RAGTaskState
    ) -> String {
        """
        \(run.formattedAnswer)
        
        Память задачи:
        \(formatRAGTaskState(taskState))
        """
    }
    
    private func formatRAGTaskState(_ state: RAGTaskState) -> String {
        let goal = state.goal ?? "-"
        let clarifications = state.clarifications.isEmpty
            ? "-"
            : state.clarifications.map { "- \($0)" }.joined(separator: "\n")
        let constraints = state.constraintsAndTerms.isEmpty
            ? "-"
            : state.constraintsAndTerms.map { "- \($0)" }.joined(separator: "\n")
        
        return """
        Цель: \(goal)
        Уточнения:
        \(clarifications)
        Ограничения и термины:
        \(constraints)
        """
    }
    
    private func makeRAGMiniChatSearchQuestion(
        question: String,
        taskState: RAGTaskState
    ) -> String {
        let goal = taskState.goal ?? ""
        let clarifications = taskState.clarifications.joined(separator: " ")
        let constraints = taskState.constraintsAndTerms.joined(separator: " ")
        
        return [goal, clarifications, constraints, question]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
    
    private func runRAGEvaluation() async {
        do {
            let questions = try ragEvaluationQuestionRepository.loadQuestions()
            var fullContent = """
            RAG Evaluation: \(questions.count) Questions
            
            """
            
            DispatchQueue.main.async { [weak self] in
                self?.onToken?(fullContent)
            }
            
            let report = await ragEvaluationService.evaluate(
                questions: questions,
                onQuestionStarted: { [weak self] question, index, total in
                    let progress = """
                    
                    Processing question \(index)/\(total): \(question.title)
                    Question: \(question.question)
                    
                    """
                    fullContent += progress
                    
                    DispatchQueue.main.async {
                        self?.onToken?(progress)
                    }
                },
                onItemCompleted: { [weak self] item, _, _ in
                    let itemText = "\n\(self?.makeRAGEvaluationItemReport(item) ?? "")\n\n---\n"
                    fullContent += itemText
                    
                    DispatchQueue.main.async {
                        self?.onToken?(itemText)
                    }
                }
            ) { [weak self] question in
                guard let self else {
                    throw CancellationError()
                }
                
                return try await self.makeRAGAnswerRun(
                    question: question.question,
                    appendingQuestionToContext: true
                )
            }
            let summary = "\n\(makeRAGEvaluationSummary(report))"
            fullContent += summary
            
            DispatchQueue.main.async { [weak self] in
                self?.onToken?(summary)
                self?.onComplete?(OllamaChunk(
                    model: "",
                    createdAt: Date(),
                    message: .init(role: .assistant, content: fullContent),
                    done: true
                ))
            }
        } catch {
            let message = "RAG evaluation failed: \(error.localizedDescription)"
            DispatchQueue.main.async { [weak self] in
                self?.onToken?(message)
            }
        }
    }
    
    private func runRAGMiniChatScenarioEvaluation() async {
        let scenarios = ragMiniChatScenarioRepository.loadScenarios()
        let savedMessages = messages
        let savedSummary = summary
        let savedTaskState = ragMiniChatTaskState
        let system = messages.first(where: { $0.role == .system }) ?? makeSystemMessage()
        
        messages = [system]
        summary = ""
        ragMiniChatTaskState = .empty
        strategy.rebuild(from: messages)
        
        var fullContent = """
        RAG Mini-Chat Evaluation: \(scenarios.count) Scenarios
        
        """
        
        DispatchQueue.main.async { [weak self] in
            self?.onToken?(fullContent)
        }
        
        let report = await ragMiniChatScenarioEvaluationService.evaluate(
            scenarios: scenarios,
            onScenarioStarted: { [weak self] scenario, index, total in
                let text = """
                
                Scenario \(index)/\(total): \(scenario.title)
                
                """
                fullContent += text
                
                DispatchQueue.main.async {
                    self?.onToken?(text)
                }
            },
            onTurnStarted: { [weak self] turn, index, total in
                let text = """
                Processing message \(index)/\(total): \(turn.userMessage)
                
                """
                fullContent += text
                
                DispatchQueue.main.async {
                    self?.onToken?(text)
                }
            },
            onTurnCompleted: { [weak self] result, _, _ in
                guard let self else { return }
                let text = "\(self.makeRAGMiniChatScenarioTurnReport(result))\n\n---\n"
                fullContent += text
                
                DispatchQueue.main.async {
                    self.onToken?(text)
                }
            }
        ) { [weak self] scenario, turn, state in
            guard let self else {
                throw CancellationError()
            }
            
            return try await self.makeRAGMiniChatScenarioTurnResult(
                scenario: scenario,
                turn: turn,
                state: state
            )
        }
        
        let summary = "\n\(makeRAGMiniChatScenarioSummary(report))"
        fullContent += summary
        messages = savedMessages
        self.summary = savedSummary
        ragMiniChatTaskState = savedTaskState
        strategy.rebuild(from: messages)
        
        DispatchQueue.main.async { [weak self] in
            self?.onToken?(summary)
            self?.onComplete?(OllamaChunk(
                model: "",
                createdAt: Date(),
                message: .init(role: .assistant, content: fullContent),
                done: true
            ))
        }
    }
    
    private func makeRAGMiniChatScenarioTurnResult(
        scenario: RAGMiniChatScenario,
        turn: RAGMiniChatScenarioTurn,
        state: RAGTaskState
    ) async throws -> RAGMiniChatScenarioTurnResult {
        let nextState = ragTaskMemoryService.update(
            state: state,
            userMessage: turn.userMessage,
            assistantAnswer: nil
        )
        let userMessage = Message(
            agentId: agentId,
            role: .user,
            content: turn.userMessage
        )
        messages.append(userMessage)
        strategy.onUserMessage(userMessage)
        
        let searchQuestion = makeRAGMiniChatSearchQuestion(
            question: turn.userMessage,
            taskState: nextState
        )
        let run = try await makeRAGAnswerRun(
            question: turn.userMessage,
            taskState: nextState,
            searchQuestion: searchQuestion,
            keepSourcesForUnknown: true
        )
        let finalState = ragTaskMemoryService.update(
            state: nextState,
            userMessage: turn.userMessage,
            assistantAnswer: run.contract.answer
        )
        let retainedGoal = retainedScenarioGoal(
            state: finalState,
            scenario: scenario
        )
        let hasSources = !run.contract.sources.isEmpty
        var notes = run.validation.notes
        
        if !retainedGoal {
            notes.append("Task goal was not retained in mini-chat state.")
        }
        
        if !hasSources {
            notes.append("Mini-chat answer did not include sources.")
        }
        
        let assistantMessage = Message(
            agentId: agentId,
            role: .assistant,
            content: formatRAGMiniChatAnswer(
                run: run,
                taskState: finalState
            )
        )
        messages.append(assistantMessage)
        strategy.onAssistantMessage(assistantMessage)
        
        return RAGMiniChatScenarioTurnResult(
            turn: turn,
            taskState: finalState,
            run: run,
            retainedGoal: retainedGoal,
            hasSources: hasSources,
            notes: notes
        )
    }
    
    private func retainedScenarioGoal(
        state: RAGTaskState,
        scenario: RAGMiniChatScenario
    ) -> Bool {
        guard let goal = state.goal?.lowercased(), !goal.isEmpty else {
            return false
        }
        
        return scenario.expectedGoalKeywords.allSatisfy {
            goal.contains($0.lowercased())
        }
    }
    
    private func makeRAGMiniChatScenarioTurnReport(
        _ result: RAGMiniChatScenarioTurnResult
    ) -> String {
        let notes = result.notes.isEmpty
            ? "none"
            : result.notes.map { "- \($0)" }.joined(separator: "\n")
        
        return """
        Message \(result.turn.id)
        Goal retained: \(passFail(result.retainedGoal))
        Sources present: \(passFail(result.hasSources))
        Quotes present: \(passFail(result.run.validation.hasQuotes))
        Quotes from chunks: \(passFail(result.run.validation.quotesMatchChunks))
        
        Task memory:
        \(formatRAGTaskState(result.taskState))
        
        \(result.run.formattedAnswer)
        
        Scenario notes:
        \(notes)
        """
    }
    
    private func makeRAGMiniChatScenarioSummary(
        _ report: RAGMiniChatScenarioReport
    ) -> String {
        let total = report.turnCount
        
        return """
        Summary:
        scenarios: \(report.results.count)
        messages: \(total)
        goal retained: \(report.retainedGoalCount)/\(total)
        sources present: \(report.sourceCount)/\(total)
        """
    }
    
    private func makeRAGEvaluationReport(_ report: RAGEvaluationReport) -> String {
        let total = report.items.count
        let itemText = report.items.map(makeRAGEvaluationItemReport)
        .joined(separator: "\n\n---\n\n")
        
        return """
        RAG Evaluation: \(total) Questions
        
        Summary:
        sources: \(report.sourcePassCount)/\(total)
        quotes: \(report.quotePassCount)/\(total)
        quotes from chunks: \(report.quoteGroundingPassCount)/\(total)
        supported by quotes: \(report.supportedPassCount)/\(total)
        unknown responses: \(report.unknownCount)
        
        \(itemText)
        """
    }
    
    private func makeRAGEvaluationItemReport(_ item: RAGEvaluationItem) -> String {
        let validation = item.run.validation
        let notes = item.notes.isEmpty
            ? "none"
            : item.notes.map { "- \($0)" }.joined(separator: "\n")
        let rewritten = item.run.retrievalResult?.rewrittenQuestion ?? "not used"
        
        return """
        \(item.question.id). \(item.question.title)
        Question: \(item.question.question)
        Grade: \(item.grade.rawValue)
        Sources: \(passFail(validation.hasSources))
        Quotes: \(passFail(validation.hasQuotes))
        Quotes from chunks: \(passFail(validation.quotesMatchChunks))
        Answer supported by quotes: \(passFail(validation.answerSupportedByQuotes))
        Rewritten query: \(rewritten)
        
        \(item.run.formattedAnswer)
        
        Eval notes:
        \(notes)
        """
    }
    
    private func makeRAGEvaluationSummary(_ report: RAGEvaluationReport) -> String {
        let total = report.items.count
        
        return """
        Summary:
        sources: \(report.sourcePassCount)/\(total)
        quotes: \(report.quotePassCount)/\(total)
        quotes from chunks: \(report.quoteGroundingPassCount)/\(total)
        supported by quotes: \(report.supportedPassCount)/\(total)
        unknown responses: \(report.unknownCount)
        """
    }
    
    private func passFail(_ value: Bool) -> String {
        value ? "pass" : "fail"
    }
    
    private func compareRAGAnswers(question: String) async {
        let baseContext = await buildContext()
        let options = makeAnyOptions(from: self.options)
        
        do {
            let withoutRAG = try await streamer.send(messages: baseContext, options: options)
            let ragRun = try await makeRAGAnswerRun(question: question)
            let comparison = await validatedContent(
                makeComparisonAnswer(
                    withoutRAG: withoutRAG,
                    withRAG: ragRun.formattedAnswer,
                    sources: ragRun.retrievedChunks
                )
            )
            
            let assistantMessage = Message(
                agentId: agentId,
                role: .assistant,
                content: comparison
            )
            
            messages.append(assistantMessage)
            strategy.onAssistantMessage(assistantMessage)
            await memoryService.appendMessage(assistantMessage)
            
            await advanceTaskStateIfNeeded(
                userQuery: question,
                assistantResponse: comparison
            )
            
            DispatchQueue.main.async { [weak self] in
                self?.onToken?(comparison)
                self?.onComplete?(OllamaChunk(
                    model: "",
                    createdAt: Date(),
                    message: .init(role: .assistant, content: comparison),
                    done: true
                ))
            }
        } catch {
            let message = "RAG comparison failed: \(error.localizedDescription)"
            DispatchQueue.main.async { [weak self] in
                self?.onToken?(message)
            }
        }
    }
    
    private func compareEnhancedRAGAnswers(question: String) async {
        do {
            let basicRAG: String
            let enhancedRAG: String
            let basicSources: [RAGRetrievedChunk]
            let enhancedResult: RAGRetrievalResult

            switch ragSourceType {
            case .mcpServer:
                let basicRun = try await ragMCPClient.answer(
                    question: question,
                    retrievalMode: .basic,
                    strategy: ragChunkingStrategy,
                    settings: ragRetrievalSettings,
                    includeChunks: true
                )
                let searchQuery = await searchQueryForRAGMCP(question: question)
                let enhancedRun = try await ragMCPClient.answer(
                    question: question,
                    searchQuery: searchQuery,
                    retrievalMode: .enhanced,
                    strategy: ragChunkingStrategy,
                    settings: ragRetrievalSettings,
                    includeChunks: true
                )
                basicSources = basicRun.chunks?.map {
                    $0.makeRetrievedChunk(strategy: ragChunkingStrategy)
                } ?? []
                let enhancedSources = enhancedRun.chunks?.map {
                    $0.makeRetrievedChunk(strategy: ragChunkingStrategy)
                } ?? []
                enhancedResult = RAGRetrievalResult(
                    originalQuestion: enhancedRun.retrieval.originalQuestion,
                    rewrittenQuestion: enhancedRun.retrieval.searchQuery == enhancedRun.retrieval.originalQuestion ? nil : enhancedRun.retrieval.searchQuery,
                    candidatesBeforeFiltering: [],
                    chunksAfterFiltering: enhancedSources
                )
                basicRAG = formatRAGAnswer(
                    basicRun.contract,
                    validation: basicRun.validation
                )
                enhancedRAG = formatRAGAnswer(
                    enhancedRun.contract,
                    validation: enhancedRun.validation
                )
            case .builtIn:
                let baseContext = await buildContext()
                let options = makeAnyOptions(from: self.options)
                basicSources = try await ragRetrievalService.retrieve(
                    question: question,
                    strategy: ragChunkingStrategy,
                    limit: ragRetrievalSettings.topKAfterFiltering
                )
                let basicMessage = Message(
                    agentId: agentId,
                    role: .system,
                    content: makeRAGPrompt(from: basicSources)
                )
                let basicContext = insert(basicMessage, beforeLastUserMessageIn: baseContext)
                let searchQuery = await makeRAGSearchQuery(from: question)
                enhancedResult = try await ragRetrievalService.retrieve(
                    originalQuestion: question,
                    searchQuery: searchQuery,
                    strategy: ragChunkingStrategy,
                    settings: ragRetrievalSettings
                )
                let enhancedMessage = Message(
                    agentId: agentId,
                    role: .system,
                    content: makeRAGPrompt(
                        from: enhancedResult.chunksAfterFiltering,
                        retrievalResult: enhancedResult
                    )
                )
                let enhancedContext = insert(enhancedMessage, beforeLastUserMessageIn: baseContext)

                basicRAG = try await streamer.send(messages: basicContext, options: options)
                enhancedRAG = try await streamer.send(messages: enhancedContext, options: options)
            }
            let comparison = await validatedContent(
                makeEnhancedComparisonAnswer(
                    basicRAG: basicRAG,
                    enhancedRAG: enhancedRAG,
                    basicSources: basicSources,
                    enhancedResult: enhancedResult
                )
            )
            
            let assistantMessage = Message(
                agentId: agentId,
                role: .assistant,
                content: comparison
            )
            
            messages.append(assistantMessage)
            strategy.onAssistantMessage(assistantMessage)
            await memoryService.appendMessage(assistantMessage)
            
            await advanceTaskStateIfNeeded(
                userQuery: question,
                assistantResponse: comparison
            )
            
            DispatchQueue.main.async { [weak self] in
                self?.onToken?(comparison)
                self?.onComplete?(OllamaChunk(
                    model: "",
                    createdAt: Date(),
                    message: .init(role: .assistant, content: comparison),
                    done: true
                ))
            }
        } catch {
            let message = "Enhanced RAG comparison failed: \(error.localizedDescription)"
            DispatchQueue.main.async { [weak self] in
                self?.onToken?(message)
            }
        }
    }
    
    private func makeComparisonAnswer(
        withoutRAG: String,
        withRAG: String,
        sources: [RAGRetrievedChunk]
    ) -> String {
        let sourceText: String
        
        if sources.isEmpty {
            sourceText = "No RAG sources were retrieved."
        } else {
            sourceText = sources.enumerated()
                .map { index, source in
                    "\(index + 1). \(source.chunk.title), section: \(source.chunk.section), chunk: \(source.chunk.chunkId), score: \(String(format: "%.4f", source.score))"
                }
                .joined(separator: "\n")
        }
        
        return """
        Without RAG

        \(withoutRAG.trimmingCharacters(in: .whitespacesAndNewlines))

        With RAG

        \(withRAG.trimmingCharacters(in: .whitespacesAndNewlines))

        RAG sources

        \(sourceText)
        """
    }
    
    private func makeEnhancedComparisonAnswer(
        basicRAG: String,
        enhancedRAG: String,
        basicSources: [RAGRetrievedChunk],
        enhancedResult: RAGRetrievalResult
    ) -> String {
        let rewritten = enhancedResult.rewrittenQuestion ?? "not used"
        
        return """
        Basic RAG

        \(basicRAG.trimmingCharacters(in: .whitespacesAndNewlines))

        Enhanced RAG

        \(enhancedRAG.trimmingCharacters(in: .whitespacesAndNewlines))

        Retrieval comparison

        Original question:
        \(enhancedResult.originalQuestion)

        Rewritten query:
        \(rewritten)

        Basic sources

        \(makeSourceList(from: basicSources))

        Enhanced candidates before filtering: \(enhancedResult.candidatesBeforeFiltering.count)
        Enhanced sources after filtering: \(enhancedResult.chunksAfterFiltering.count)

        Enhanced sources

        \(makeSourceList(from: enhancedResult.chunksAfterFiltering))
        """
    }
    
    private func makeSourceList(from sources: [RAGRetrievedChunk]) -> String {
        guard !sources.isEmpty else {
            return "No RAG sources were retrieved."
        }
        
        return sources.enumerated()
            .map { index, source in
                "\(index + 1). \(source.chunk.title), section: \(source.chunk.section), chunk: \(source.chunk.chunkId), score: \(String(format: "%.4f", source.score)), relevance: \(String(format: "%.4f", source.relevanceScore)), reason: \(source.relevanceReason)"
            }
            .joined(separator: "\n")
    }
    
    private func validatedContent(_ content: String) async -> String {
        let validation = await invariantService.validateResponse(
            content,
            fileName: invariantFileName
        )
        
        if validation.isValid {
            return LocalPathPrivacy.redact(content)
        }
        
        let violations = validation.violations.joined(separator: "\n")
        return """
        I can’t recommend that option because it violates the project invariants.

        Violations:
        \(LocalPathPrivacy.redact(violations))

        Please choose an option that stays within the defined architecture, stack, and business rules.
        """
    }
    
    // MARK: - Summary
    
    private func summarizeHistoryIfNeeded() async throws {
        let dialogMessages = messages.filter { $0.role != .system }
        guard dialogMessages.count > summaryTrigger else { return }
        
        let oldMessages = dialogMessages.dropLast(maxMessages)
        guard !oldMessages.isEmpty else { return }
        
        let text = oldMessages
            .compactMap(makeSummarizableLine)
            .joined(separator: "\n")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let prompt = """
        Summarize the following conversation briefly.
        Keep only stable conversation facts, user preferences, decisions, and useful context.
        Do not include citations, raw tool outputs, RAG context, eval reports, source lists, chunk ids, JSON, logs, validation notes, or formatting artifacts.
        If a message is diagnostic or evaluation output, ignore it.

        Conversation:
        \(text)
        """
        
        let summaryMessage = Message(
            agentId: agentId,
            role: .user,
            content: prompt
        )
        
        let result = try await streamer.send(
            summaryMessage,
            options: makeAnyOptions(from: options)
        )
        
        summary = result
        
        let system = messages.first(where: { $0.role == .system }) ?? makeSystemMessage()
        let tail = Array(dialogMessages.suffix(maxMessages))
        
        messages = [system] + tail
        
        await memoryService.deleteMessages(agentId: agentId)
        await memoryService.appendMessages(messages)
        
        strategy.rebuild(from: messages)
    }
    
    private func makeSummarizableLine(from message: Message) -> String? {
        guard message.role != .system else {
            return nil
        }
        
        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            return nil
        }
        
        if isDiagnosticHistoryContent(content) {
            return nil
        }
        
        if message.role == .assistant, let answer = extractAnswerSection(from: content) {
            return "\(message.role): \(answer)"
        }
        
        return "\(message.role): \(content)"
    }
    
    private func isDiagnosticHistoryContent(_ content: String) -> Bool {
        content.hasPrefix("RAG Evaluation:") ||
        content.hasPrefix("RAG comparison failed:") ||
        content.hasPrefix("Enhanced RAG comparison failed:") ||
        content.hasPrefix("Basic RAG\n") ||
        content.contains("Enhanced candidates before filtering:") ||
        content.contains("Retrieval comparison") ||
        content.contains("Validation notes:")
    }
    
    private func extractAnswerSection(from content: String) -> String? {
        guard content.contains("Источники:"), content.contains("Цитаты:") else {
            return nil
        }
        
        let marker = "Ответ:"
        guard let start = content.range(of: marker) else {
            return nil
        }
        
        let tail = String(content[start.upperBound...])
        if let end = tail.range(of: "Источники:") {
            return "RAG answer: \(tail[..<end.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines))"
        }
        
        return "RAG answer: \(tail.trimmingCharacters(in: .whitespacesAndNewlines))"
    }
    
    // MARK: - Task Planning
    
    private func generateInitialPlan(for task: String) async -> [String] {
        let profilePrompt = currentPromptContextSettings().includeUserProfile
            ? await userProfileService.makeProfilePrompt(userId: userId) ?? ""
            : ""
        
        let planningPrompt = """
        Break down the following task into a short sequential implementation plan.

        Task:
        \(task)

        User profile:
        \(profilePrompt)

        Requirements:
        - 3 to 7 steps
        - each step must be concise
        - steps must be sequential
        - adapt to user profile, tech stack, architecture, and constraints
        - return ONLY a JSON array of strings
        - no markdown
        - no explanations

        Example:
        ["Collect requirements", "Design the solution", "Implement core functionality", "Validate result"]
        """
        
        let message = Message(
            agentId: agentId,
            role: .user,
            content: planningPrompt
        )
        
        do {
            let response = try await streamer.send(
                message,
                options: makeAnyOptions(from: options)
            )
            
            let cleaned = response
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
            
            if let data = cleaned.data(using: .utf8),
               let plan = try? JSONDecoder().decode([String].self, from: data),
               !plan.isEmpty {
                return plan
            }
        } catch {
            print("generateInitialPlan error:", error)
        }
        
        return fallbackPlan(for: task)
    }
    
    private func fallbackPlan(for task: String) -> [String] {
        [
            "Collect and confirm requirements",
            "Design the solution and implementation steps",
            "Implement the core functionality",
            "Validate and test the result",
            "Finalize and document the outcome"
        ]
    }
    
    // MARK: - Task Auto-Progression
    
    private struct TaskProgressUpdate: Decodable {
        let nextState: String
        let step: Int
        let current: String
        let done: [String]
        let expectedAction: String
    }
    
    private func advanceTaskStateIfNeeded(
        userQuery: String,
        assistantResponse: String
    ) async {
        guard isTaskPlanningEnabled else { return }
        guard let context = currentTaskContext else { return }
        
        let analysisPrompt = buildTaskAnalysisPrompt(
            context: context,
            userQuery: userQuery,
            assistantResponse: assistantResponse
        )
        
        let message = Message(
            agentId: agentId,
            role: .user,
            content: analysisPrompt
        )
        
        do {
            let raw = try await streamer.send(
                message,
                options: makeAnyOptions(from: options)
            )
            
            let cleaned = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
            
            guard let data = cleaned.data(using: .utf8),
                  let update = try? JSONDecoder().decode(TaskProgressUpdate.self, from: data) else {
                return
            }
            
            let res = await applyTaskProgressUpdate(update, currentContext: context)
            print(res ?? "")
        } catch {
            print("advanceTaskStateIfNeeded error:", error)
        }
    }
    
    private func buildTaskAnalysisPrompt(
        context: TaskContext,
        userQuery: String,
        assistantResponse: String
    ) -> String {
        let planText = context.plan.isEmpty ? "-" : context.plan.joined(separator: ", ")
        let doneText = context.done.isEmpty ? "-" : context.done.joined(separator: ", ")
        
        return """
        Analyze the task progress and update the task state machine.

        Current task context:
        - task: \(context.task)
        - phase: \(context.phase.title)
        - step: \(context.step)
        - total: \(context.total)
        - current: \(context.current)
        - plan: \(planText)
        - done: \(doneText)
        - expected_action: \(context.expectedAction)

        Latest user query:
        \(userQuery)

        Latest assistant response:
        \(assistantResponse)

        Allowed transitions:
        - planning -> execution
        - execution -> validation or planning
        - validation -> done or execution
        - done -> done

        Rules:
        - If planning is finished and a concrete plan exists, move to execution.
        - If the current execution step is completed, advance to the next step.
        - If all execution steps are completed, move to validation.
        - If validation confirms success, move to done.
        - If validation finds problems, move back to execution.
        - Never skip directly from planning to validation.
        - Never skip directly from execution to done.
        - step must stay in range 1...total
        - done must contain already completed items only
        - current must describe the active item
        - expectedAction must describe the next expected action

        Return ONLY valid JSON:
        {
          "nextState": "planning|execution|validation|done",
          "step": 1,
          "current": "string",
          "done": ["string"],
          "expectedAction": "string"
        }
        """
    }
    
    private func applyTaskProgressUpdate(
        _ update: TaskProgressUpdate,
        currentContext: TaskContext
    ) async -> String? {
        guard let targetPhase = TaskPhase(rawValue: update.nextState.lowercased()) else {
            return "Invalid next phase proposed by the analyzer."
        }
        
        var context = currentContext
        
        if context.phase != targetPhase {
            do {
                context = try await taskContextService.transition(context, to: targetPhase)
            } catch let error as TaskTransitionError {
                self.currentTaskContext = context
                return taskTransitionRefusal(for: error)
            } catch {
                self.currentTaskContext = context
                return "Task transition failed."
            }
        }
        
        let safeStep = max(1, min(update.step, max(context.total, 1)))
        
        do {
            context = try await taskContextService.updateStep(
                context,
                step: safeStep,
                current: update.current,
                done: update.done,
                expectedAction: update.expectedAction
            )
            self.currentTaskContext = context
            return nil
        } catch {
            self.currentTaskContext = context
            return "Task step update failed."
        }
    }
    
    func pauseTask() {
        Task {
            guard let context = currentTaskContext else { return }
            currentTaskContext = await taskContextService.pause(context)
        }
    }

    func resumeTask() {
        Task {
            guard let context = currentTaskContext else { return }
            currentTaskContext = await taskContextService.resume(context)
        }
    }
    
    // MARK: - Memory extraction
    
    private func updateMemoryLayers(with message: Message) {
        guard message.role == .user else { return }
        
        let text = message.content.lowercased()
        
        if text.contains("my goal is") || text.contains("goal:") {
            Task {
                await memoryService.upsertWorking(
                    WorkingMemoryItem(
                        agentId: agentId,
                        key: "goal",
                        value: message.content
                    )
                )
            }
        }
        
        if text.contains("i prefer") || text.contains("preference:") {
            Task {
                await memoryService.saveLongTerm(
                    LongTermMemoryItem(
                        userId: userId,
                        category: "preference",
                        content: message.content
                    )
                )
            }
        }
    }
    
    // MARK: - Helpers
    
    private func makeSystemMessage() -> Message {
        Message(
            agentId: agentId,
            role: .system,
            content: Self.systemPrompt
        )
    }
    
    private func normalizeOptions(_ options: [String: Any]) -> [String: Any] {
        var result = options
        
        if let model = result["model"] as? OllamaModel {
            result["model"] = model.rawValue
        }
        
        return result
    }

    private func makeAnyOptions(from options: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        
        for (key, value) in options {
            switch value {
            case let value as OllamaModel:
                result[key] = value.rawValue
            case let value as [String: Any]:
                result[key] = makeAnyOptions(from: value)
            default:
                result[key] = value
            }
        }
        
        return result
    }

    private func currentPromptContextSettings() -> PromptContextInclusionSettings {
        let rawSettings = options["prompt_context"] as? [String: Any] ?? [:]
        return PromptContextInclusionSettings(dictionary: rawSettings)
    }

    private func makeCompletionChunk(
        content: String,
        sourceChunk: OllamaChunk?
    ) -> OllamaChunk {
        OllamaChunk(
            model: sourceChunk?.model ?? "",
            createdAt: Date(),
            message: .init(role: .assistant, content: content),
            done: true,
            doneReason: sourceChunk?.doneReason,
            totalDuration: sourceChunk?.totalDuration,
            loadDuration: sourceChunk?.loadDuration,
            promptEvalCount: sourceChunk?.promptEvalCount,
            promptEvalDuration: sourceChunk?.promptEvalDuration,
            evalCount: sourceChunk?.evalCount,
            evalDuration: sourceChunk?.evalDuration,
            localStats: sourceChunk?.localStats
        )
    }
    
    private func taskTransitionRefusal(for error: TaskTransitionError) -> String {
        switch error {
        case .cannotExecuteWithoutApprovedPlan:
            return """
            I can’t start implementation yet because the plan is not approved.

            Next valid step:
            - review and confirm the plan
            """
            
        case .cannotFinishWithoutValidation:
            return """
            I can’t finalize the task yet because validation has not been completed.

            Next valid step:
            - run validation
            - confirm that acceptance criteria are met
            """
            
        case let .invalidPhaseTransition(from, to):
            return """
            I can’t move the task from \(from.rawValue) to \(to.rawValue).

            Allowed next transitions are enforced by the task state machine.
            """
            
        case .taskIsPaused:
            return """
            The task is currently paused.

            Resume it first, then continue from:
            \(currentTaskContext?.phase.rawValue ?? "unknown") / step \(currentTaskContext?.step ?? 0)
            """
            
        case .invalidStep:
            return "The task step is inconsistent. Please reload the task state."
        }
    }
    
    // MARK: - MCP

    private struct DeveloperGitBranchInfo: Decodable {
        let branch: String
        let repository: String?
    }

    private struct DeveloperSupportRequest {
        let ticketId: String?
        let question: String
    }

    private struct DeveloperSupportTicket: Decodable {
        let ticketId: String
        let userId: String
        let subject: String
        let status: String
        let messages: [String]
        let metadata: [String: String]
    }

    private struct DeveloperSupportUser: Decodable {
        let userId: String
        let name: String
        let plan: String
        let emailVerified: Bool
        let lastLoginAt: String
    }

    private struct DeveloperSupportContext {
        let ticket: DeveloperSupportTicket
        let user: DeveloperSupportUser
    }

    private func decodeDeveloperSupportTicket(from text: String) -> DeveloperSupportTicket? {
        guard let data = text.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(DeveloperSupportTicket.self, from: data)
    }

    private func decodeDeveloperSupportUser(from text: String) -> DeveloperSupportUser? {
        guard let data = text.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(DeveloperSupportUser.self, from: data)
    }

    private struct DeveloperChangedFilesInfo: Decodable {
        let branch: String
        let repository: String?
        let files: [DeveloperChangedFile]
    }

    private struct DeveloperChangedFile: Decodable {
        let path: String
        let status: String
    }

    private struct DeveloperGitDiffInfo: Decodable {
        let branch: String
        let repository: String?
        let diff: String
    }

    private struct DeveloperReviewGitContext {
        let repository: String
        let branch: String
        let files: [DeveloperChangedFile]
        let diff: String
    }

    private func decodeDeveloperChangedFiles(from text: String) -> DeveloperChangedFilesInfo? {
        guard let data = text.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(DeveloperChangedFilesInfo.self, from: data)
    }

    private func decodeDeveloperGitDiff(from text: String) -> DeveloperGitDiffInfo? {
        guard let data = text.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(DeveloperGitDiffInfo.self, from: data)
    }
    
    private func refreshMCPToolsIfNeeded() async {
        await refreshMCPTools(force: false)
    }

    private func refreshMCPTools(force: Bool) async {
        guard let mcpOrchestrator else { return }
        guard force || !hasLoadedMCPTools else { return }

        await mcpOrchestrator.refreshTools()
        cachedMCPTools = await mcpOrchestrator.availableTools()
        hasLoadedMCPTools = true
    }
    
    func setUser(_ profile: UserProfile) {
        self.userId = profile.userId
        self.userProfile = profile
    }
    
}
