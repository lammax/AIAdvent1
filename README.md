# AIChallenge

AIChallenge is a local AI assistant playground focused on model orchestration, RAG, MCP tools, and project-aware developer workflows.

## Current MCP Architecture

The app separates MCP responsibilities by server:

- `GitHubMCPServer` provides repository and git context such as branch, changed files, and diff.
- `RAGMCPServer` provides documentation and knowledge retrieval.
- `SupportMCPServer` provides support-domain data such as tickets and users.
- `FileOperationsMCPServer` provides project file operations for the `/files` assistant.

`OllamaAgent` is the orchestration layer used by commands such as `/help`, `/review`, `/support`, and `/files`. The agent does not call file tools directly. It calls `MCPOrchestrator`, which uses `MCPToolRouter` to route each tool call to the server that registered that tool.

## File Assistant

The `/files` command can inspect and change files through `FileOperationsMCPServer`.

Supported file tools:

- `project_list_files`
- `project_search_files`
- `project_read_file`
- `project_write_file`
- `project_delete_file`

Typical commands:

```text
/files обнови README на основе текущей MCP архитектуры
/files --dry-run обнови README на основе текущей MCP архитектуры
/files undo
```

`--dry-run` analyzes and plans changes without writing files. Without `--dry-run`, the assistant may write files and records the latest file changes in memory so `/files undo` can restore or delete the affected files during the current app session.

## Project Root

The file assistant can use the project folder selected in Settings -> Files. The app passes that folder to `FileOperationsMCPServer` as `project_root` for each file operation.

`FileOperationsMCPServer` can also be started with a default root:

```bash
cd ../MCP_server
swift run FileOperationsMCPServer --project-root ../AIChallenge
```

## Important App Files

- agents/OllamaAgent.swift
- services/mcporchestrator/MCPOrchestrator.swift
- services/mcp/MCPToolRouter.swift
- lib/Constants.swift

Files read for the last README update: README.md, AIChallenge/main/MainView.swift, AIChallenge/main/MainViewModel.swift, AIChallenge/mcp/MCPTools/MCPToolsScreen.swift, AIChallenge/mcp/MCPTools/MCPToolsViewModel.swift.

## Verification

Useful local checks:

```bash
swift build --product FileOperationsMCPServer
xcodebuild build -quiet -project AIChallenge.xcodeproj -scheme AIChallenge -destination 'generic/platform=iOS Simulator'
git diff --check
```