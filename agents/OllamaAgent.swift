//
//  OllamaService.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 22.03.26.
//

import Foundation

final class OllamaAgent: LLMAgentProtocol {
    
    // MARK: - Constants
    
    private static let systemPrompt = "You are a helpful assistant. Answer concisely."
    
    // MARK: - Identity
    
    internal let agentId: String
    private var userId: String
    private var userProfile: UserProfile = .defaultProfile
    
    // MARK: - Dependencies
    
    private let memoryService: MemoryServiceProtocol
    private let userProfileService: UserProfileServiceProtocol
    private let taskContextService: TaskContextServiceProtocol
    private let promptBuilder = TaskPromptBuilder()
    private let streamer: OllamaStreamer
    private let invariantService: InvariantServiceProtocol
    private let invariantFileName: String = "invariants"
    
    // MARK: - Callbacks
    
    var onToken: ((String) -> Void)?
    var onComplete: ((OllamaChunk) -> Void)?
    
    // MARK: - State
    
    private var messages: [Message] = []
    private var summary: String = ""
    private var options: [String: Encodable] = Constants.defaultOllamaOptions
    
    private let maxMessages: Int
    private let summaryTrigger: Int
    
    private var strategy: ContextStrategyProtocol
    private var isPrepared = false
    private var isSending = false
    
    // MARK: - Task context
    private var currentTaskContext: TaskContext?
    
    // MARK: - Init
    
    init(
        agentId: String = "ollama_agent",
        userId: String = "default_user",
        memoryService: MemoryServiceProtocol = MemoryService(),
        userProfileService: UserProfileServiceProtocol = UserProfileService(),
        taskContextService: TaskContextServiceProtocol = TaskContextService(),
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
        self.invariantService = invariantService
        self.streamer = streamer
        self.maxMessages = maxMessages
        self.summaryTrigger = summaryTrigger
        self.strategy = strategy ?? SlidingWindowStrategy(maxMessages: maxMessages)
        
        Task {
            await prepareIfNeeded()
        }
    }
    
    // MARK: - Public
    
    func send(
            _ prompt: Prompt,
            options: [String: Encodable]
        ) {
        Task { [weak self] in
            guard let self else { return }
            guard !isSending else { return }
            
            isSending = true
            defer { isSending = false }
            
            await prepareIfNeeded()
            
            let normalizedOptions = normalizeOptions(options)
            self.options = normalizedOptions
            
            // 1. Убедимся, что есть TaskContext
            if self.currentTaskContext == nil {
                let plan = await generateInitialPlan(for: prompt.text)
                self.currentTaskContext = await taskContextService.startTask(
                    agentId: agentId,
                    task: prompt.text,
                    plan: plan
                )
            }
            
            guard let taskContext = self.currentTaskContext else { return }
            
            // 2. Формируем task-aware prompt
            let profilePrompt = await userProfileService.makeProfilePrompt(userId: userId)
            let finalPromptText = promptBuilder.buildPrompt(
                query: prompt.text,
                context: taskContext,
                profilePrompt: profilePrompt
            )
            
            let userMessage = Message(
                agentId: agentId,
                role: .user,
                content: finalPromptText
            )
            
            messages.append(userMessage)
            strategy.onUserMessage(userMessage)
            await memoryService.appendMessage(userMessage)
            
            updateMemoryLayers(with: userMessage)
            
            if shouldSummarize {
                try? await summarizeHistoryIfNeeded()
            }
            
            let context = await buildContext()
            
            var fullResponse = ""
            
            streamer.onToken = { [weak self] token in
                fullResponse += token
                DispatchQueue.main.async {
                    self?.onToken?(token)
                }
            }
            
            streamer.onComplete = { [weak self] ollamaChunk in
                guard let self else { return }
                
                let finalText = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                let content = finalText.isEmpty ? ollamaChunk.message.content : finalText
                
                Task {
                    let validation = await self.invariantService.validateResponse(
                        content,
                        fileName: self.invariantFileName
                    )
                    
                    let safeContent: String
                    
                    if validation.isValid {
                        safeContent = content
                    } else {
                        let violations = validation.violations.joined(separator: "\n")
                        safeContent = """
                        I can’t recommend that option because it violates the project invariants.

                        Violations:
                        \(violations)

                        Please choose an option that stays within the defined architecture, stack, and business rules.
                        """
                    }
                    
                    let assistantMessage = Message(
                        agentId: self.agentId,
                        role: .assistant,
                        content: safeContent
                    )
                    
                    self.messages.append(assistantMessage)
                    self.strategy.onAssistantMessage(assistantMessage)
                    await self.memoryService.appendMessage(assistantMessage)
                    
                    // 3. Авто-обновление TaskContext после ответа модели
                    await self.advanceTaskStateIfNeeded(
                        userQuery: prompt.text,
                        assistantResponse: content
                    )
                }
                
                DispatchQueue.main.async {
                    self.onComplete?(ollamaChunk)
                }
            }
            
            streamer.start(messages: context, options: self.options)
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
            self.strategy = self.strategy.makeCleanCopy()
            
            await self.memoryService.deleteMessages(agentId: self.agentId)
            await self.memoryService.appendMessage(system)
        }
    }
    
    func set(strategy: ContextStrategyProtocol) {
        self.strategy = strategy.makeCleanCopy()
        self.strategy.rebuild(from: messages)
    }
    
    // MARK: - Prepare
    
    private func prepareIfNeeded() async {
        guard !isPrepared else { return }
        
        await loadHistory()
        self.currentTaskContext = await taskContextService.loadCurrent(agentId: agentId)
        self.userProfile = await userProfileService.fetchProfile(userId: userId) ??  self.userProfile
        
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
        
        let system = messages.first(where: { $0.role == .system }) ?? makeSystemMessage()
        context.append(system)
        
        if let profileText = await userProfileService.makeProfilePrompt(userId: userId),
           !profileText.isEmpty {
            context.append(
                Message(
                    agentId: agentId,
                    role: .system,
                    content: profileText
                )
            )
        }
        
        if let invariantPrompt = await invariantService.makePrompt(fileName: invariantFileName),
           !invariantPrompt.isEmpty {
            context.append(
                Message(
                    agentId: agentId,
                    role: .system,
                    content: invariantPrompt
                )
            )
        }
        
        let working = await memoryService.fetchWorking(agentId: agentId)
        if !working.isEmpty {
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
        if !longTerm.isEmpty {
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
        
        if let taskContext = currentTaskContext {
            context.append(
                Message(
                    agentId: agentId,
                    role: .system,
                    content: """
                    Current task state:
                    - state: \(taskContext.state.rawValue)
                    - step: \(taskContext.step)/\(taskContext.total)
                    - current: \(taskContext.current)
                    - expected action: \(taskContext.expectedAction)
                    """
                )
            )
        }
        
        let strategyMessages = strategy
            .buildContext(messages: messages, summary: summary)
            .filter { candidate in
                !(candidate.role == .system && candidate.content == system.content)
            }
        
        context.append(contentsOf: strategyMessages)
        return context
    }
    
    // MARK: - Summary
    
    private func summarizeHistoryIfNeeded() async throws {
        let dialogMessages = messages.filter { $0.role != .system }
        guard dialogMessages.count > summaryTrigger else { return }
        
        let oldMessages = dialogMessages.dropLast(maxMessages)
        guard !oldMessages.isEmpty else { return }
        
        let text = oldMessages
            .map { "\($0.role): \($0.content)" }
            .joined(separator: "\n")
        
        let prompt = """
        Summarize the following conversation briefly.
        Keep important facts, user preferences, and context.

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
    
    // MARK: - Task Planning
    
    private func generateInitialPlan(for task: String) async -> [String] {
        let profilePrompt = await userProfileService.makeProfilePrompt(userId: userId) ?? ""
        
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
            
            await applyTaskProgressUpdate(update, currentContext: context)
            
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
        - state: \(context.state.rawValue)
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
    ) async {
        guard let targetState = TaskState(rawValue: update.nextState.lowercased()) else {
            return
        }
        
        var context = currentContext
        
        if context.state != targetState {
            do {
                context = try await taskContextService.transition(context, to: targetState)
            } catch {
                print("Task transition error:", error)
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
        } catch {
            print("Task step update error:", error)
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
    
    private func normalizeOptions(_ options: [String: Encodable]) -> [String: Encodable] {
        var result = options
        
        if let model = result["model"] as? OllamaModel {
            result["model"] = model.rawValue
        }
        
        return result
    }
    
    private func makeAnyOptions(from options: [String: Encodable]) -> [String: Any] {
        var result: [String: Any] = [:]
        
        for (key, value) in options {
            switch value {
            case let value as String:
                result[key] = value
            case let value as Int:
                result[key] = value
            case let value as Double:
                result[key] = value
            case let value as Bool:
                result[key] = value
            case let value as OllamaModel:
                result[key] = value.rawValue
            case let value as [String: Any]:
                result[key] = value
            case let value as [String: Encodable]:
                result[key] = makeAnyOptions(from: value)
            default:
                break
            }
        }
        
        return result
    }
    
    func setUser(_ profile: UserProfile) {
        self.userId = profile.userId
        self.userProfile = profile
    }
    
}
