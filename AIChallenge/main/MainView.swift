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
    
    @StateObject private var viewModel = MainViewModel()
    @StateObject private var settingsVM = SettingsViewModel()
    
    @State var promptAIText: String = ""
    @State var currentOption: Prompt?
    
    @State private var showSettings: Bool = false
    @State private var showStatistics: Bool = false
    @State private var showUserProfile: Bool = false
    @State private var showDocumentImporter: Bool = false
    @State private var isTaskPaused: Bool = false
//    @State private var isMCPtest: Bool = false
//    @State private var scheduledJob: ScheduledJob?
//    @State private var isPipelineTest: Bool = false
    
    private var ragImportTypes: [UTType] {
        [
            .plainText,
            .sourceCode,
            .json,
            UTType(filenameExtension: "zip") ?? .data
        ]
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
                        showDocumentImporter.toggle()
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
                        options: Prompt.allCases,
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
            
            SettingsView(vm: settingsVM, isOpen: $showSettings)
            
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
            isPresented: $showDocumentImporter,
            allowedContentTypes: ragImportTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                viewModel.indexDocuments(urls: urls)
            case .failure(let error):
                viewModel.ragStatus = "Document selection failed: \(error.localizedDescription)"
            }
        }
        .padding()
        .navigationBarTitle("AI Challenge")

    }
}
