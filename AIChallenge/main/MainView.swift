//
//  ContentView.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 16.03.26.
//

import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    private static let outputBottomID = "main-output-bottom"
    
    private enum ImportTarget {
        case documents
        case localModel
        case projectFolder
    }
    
    @StateObject private var viewModel = MainViewModel()
    @StateObject private var settingsVM = SettingsViewModel()
    
    @State var promptAIText: String = ""
    @State var currentOption: PromptTemplate?
    
    @State private var showSettings: Bool = false
    @State private var showStatistics: Bool = false
    @State private var showUserProfile: Bool = false
    @State private var isImporterPresented: Bool = false
    @State private var activeImporter: ImportTarget?
    @State private var isTaskPaused: Bool = false
//    @State private var isMCPtest: Bool = false
//    @State private var scheduledJob: ScheduledJob?
//    @State private var isPipelineTest: Bool = false
    
    private var ragImportTypes: [UTType] {
        switch settingsVM.ragSourceType {
        case .mcpServer:
            return [UTType(filenameExtension: "zip") ?? .data]
        case .builtIn:
            return [
                .plainText,
                .sourceCode,
                .json,
                UTType(filenameExtension: "zip") ?? .data
            ]
        }
    }
    
    private var localModelImportTypes: [UTType] {
        [UTType(filenameExtension: "gguf") ?? .data]
    }
    
    private var allowedImportTypes: [UTType] {
        switch activeImporter {
        case .documents:
            return ragImportTypes
        case .localModel:
            return localModelImportTypes
        case .projectFolder:
            return [.folder]
        case nil:
            return [.data]
        }
    }
    
    private var allowsMultipleImportSelection: Bool {
        switch activeImporter {
        case .documents:
            return true
        case .localModel, .projectFolder, .none:
            return false
        }
    }
    
    let formatterInt: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.allowsFloats = false
        return formatter
    }()
    
    var body: some View {
        ZStack {
            VStack {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(viewModel.answer)
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)
                            
                            if !viewModel.ragStatus.isEmpty {
                                Text(viewModel.ragStatus)
                                    .font(.footnote)
                                    .foregroundStyle(Color.secondary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(nil)
                            }
                            
                            Color.clear
                                .frame(height: 1)
                                .id(Self.outputBottomID)
                        }
                    }
                    .onChange(of: viewModel.answer) { _, _ in
                        proxy.scrollTo(Self.outputBottomID, anchor: .bottom)
                    }
                    .onChange(of: viewModel.ragStatus) { _, _ in
                        proxy.scrollTo(Self.outputBottomID, anchor: .bottom)
                    }
                }
                .padding(.top, 80)
                
                HStack {
                    Button {
                        viewModel.deleteAll()
                        promptAIText = ""
                    } label: {
                        Image(systemName: "xmark.bin")
                            .foregroundStyle(Color.red)
                            .frame(width: 20, height: 20)
                    }
                    
                    TextField(
                        "",
                        text: $promptAIText,
                        prompt: Text("Enter prompt here")
                    )
                    
                    Button {
                        viewModel.start(
                            prompt: (currentOption?.isSomeText ?? false) ? .someText(text: promptAIText) : currentOption
                        )
                        promptAIText = ""
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.black)
                            .frame(width: 20, height: 20)
                    }
                    
                    Button {
                        isTaskPaused.toggle()
                        viewModel.setTaskRunState(isPause: isTaskPaused)
                    } label: {
                        Image(systemName: isTaskPaused ? "play.fill" : "pause.fill")
                            .foregroundStyle(Color.black)
                            .frame(width: 20, height: 20)
                    }
                }
            }

            VStack {
                
                HStack {
                    Button {
                        showUserProfile.toggle()
                    } label: {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(Color.black)
                            .frame(width: 40, height: 40)
                    }
                    
                    Button {
                        activeImporter = .documents
                        isImporterPresented = true
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundStyle(Color.black)
                            .frame(width: 40, height: 40)
                    }
                    
//                    Button {
//                        viewModel.createSummaryJobAndOpen(
//                            owner: "apple",
//                            repo: "swift"
//                        ) { jobId in
//                            scheduledJob = ScheduledJob(id: jobId)
//                        }
//                    } label: {
//                        Text("Schedule summary")
//                    }
//                    
//                    Button {
//                        isPipelineTest.toggle()
//                    } label: {
//                        Text("Pipeline")
//                    }
                }
                
                HStack(alignment: .top) {
                    Button {
                        showStatistics.toggle()
                    } label: {
                        Image(systemName: "chart.bar.xaxis.descending")
                            .foregroundStyle(Color.black)
                            .frame(width: 40, height: 40)
                            .padding(.top, 20)
                    }
                    .disabled(viewModel.isStatisticsBtnDisabled)
                    
                    AnimatedDropdownMenu(
                        options: PromptTemplate.allCases,
                        selectedOption: $currentOption
                    )
                    .onChange(of: currentOption) { _, newValue in
                        if let newValue, !newValue.text.isEmpty {
                            promptAIText = newValue.text
                        }
                    }
                    
                    Button {
                        showSettings.toggle()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Color.black)
                            .frame(width: 40, height: 40)
                            .padding(.top, 20)
                    }
                }
                
                Spacer()
            }
            
            SettingsView(
                vm: settingsVM,
                isOpen: $showSettings,
                onSelectLocalModel: {
                    activeImporter = .localModel
                    isImporterPresented = true
                },
                onSelectProjectFolder: {
                    activeImporter = .projectFolder
                    isImporterPresented = true
                }
            )
            
            StatisticsView(vm: StatisticsViewModel(chunk: viewModel.ollamaChunk), isOpen: $showStatistics)
            
            UserProfileView(vm: UserProfileViewModel(), isOpen: $showUserProfile)
            
        }
//        .sheet(isPresented: $isMCPtest, content: {
//            MCPToolsScreen()
//        })
//        .sheet(isPresented: $isPipelineTest, content: {
//            PipelineScreen(executor: viewModel.mcpToolExecutor)
//        })
//        .sheet(item: $scheduledJob) { job in
//            SummaryScreen(jobId: job.id, executor: viewModel.mcpToolExecutor)
//        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: allowedImportTypes,
            allowsMultipleSelection: allowsMultipleImportSelection
        ) { result in
            let target = activeImporter
            isImporterPresented = false
            activeImporter = nil
            
            switch (target, result) {
            case (.documents, .success(let urls)):
                viewModel.indexDocuments(urls: urls)
            case (.localModel, .success(let urls)):
                guard let url = urls.first else { return }
                Task {
                    await settingsVM.importLocalModel(from: url)
                }
            case (.projectFolder, .success(let urls)):
                guard let url = urls.first else { return }
                Task {
                    await settingsVM.importProjectFolder(from: url)
                }
            case (.documents, .failure(let error)):
                viewModel.ragStatus = "Document selection failed: \(error.localizedDescription)"
            case (.localModel, .failure(let error)):
                settingsVM.localModelStatus = "Local model selection failed: \(error.localizedDescription)"
            case (.projectFolder, .failure(let error)):
                settingsVM.fileOperationsProjectRootStatus = "Project folder selection failed: \(error.localizedDescription)"
            case (.none, _):
                break
            }
        }
        .padding()
        .navigationBarTitle("AI Challenge")

    }
}
