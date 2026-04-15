# RAG Evaluation Questions

Use these questions after indexing the `AIChallenge` project sources. For each question, compare the plain model answer with the RAG answer, then mark the result as `miss`, `partial`, or `good`.

## 1. Ollama embedding endpoint

Question: Which endpoint and model does the app use to create embeddings?

Expected: The answer should mention `http://127.0.0.1:11434/api/embed` and `nomic-embed-text`.

Expected sources: `OllamaEmbeddingService.swift`.

## 2. Embedding normalization

Question: How are embedding vectors normalized before they are saved?

Expected: The answer should say each vector element is divided by the maximum element of the vector, and should not describe this as L2 normalization.

Expected sources: `OllamaEmbeddingService.swift`.

## 3. Supported document types

Question: Which file types can be indexed directly, and how are zip files handled?

Expected: The answer should list `.swift`, `.md`, `.txt`, `.json`, and explain that `.zip` files are extracted before loading supported files from the extracted directory.

Expected sources: `DocumentIndexingService.swift`, `ZipDocumentExtractor.swift`.

## 4. Zip cleanup rules

Question: Which files or directories are skipped when indexing extracted zip contents?

Expected: The answer should mention `__MACOSX`, `.DS_Store`, and AppleDouble files prefixed with `._`.

Expected sources: `DocumentIndexingService.swift`.

## 5. Fixed token chunking

Question: How does the fixed-token RAG chunking strategy split text?

Expected: The answer should mention `FixedTokenChunker`, a default chunk size of 500 tokens, overlap of 50 tokens, character limiting, and tokenization by whitespace with long-token splitting.

Expected sources: `RAGChunker.swift`.

## 6. Structure chunking

Question: How does structure-based chunking split Markdown and Swift files?

Expected: The answer should explain Markdown headers for `.md`, Swift declarations such as `struct`, `class`, `enum`, `extension`, and `func`, plus fallback to fixed-token chunking.

Expected sources: `RAGChunker.swift`.

## 7. SQLite RAG storage

Question: What metadata is stored for each RAG chunk in SQLite?

Expected: The answer should include strategy, source, title, section, chunk id, content, token count, offsets, embedding blob, embedding dimension, embedding model, and creation time.

Expected sources: `SQLiteDB.swift`, `RAGIndexRepository.swift`.

## 8. Indexing progress

Question: How does the indexing flow report progress back to the UI?

Expected: The answer should mention the typed async progress callback with `RAGIndexingProgress` events, not NotificationCenter.

Expected sources: `DocumentIndexingServiceProtocol.swift`, `DocumentIndexingService.swift`, `MainViewModel.swift`.

## 9. RAG settings path

Question: How does the selected RAG chunking strategy travel from settings to indexing?

Expected: The answer should describe `SettingsView` picker, `SettingsViewModel.apply()`, `SettingsObserver`, and `MainViewModel.ragChunkingStrategy`.

Expected sources: `SettingsView.swift`, `SettingsViewModel.swift`, `SettingsObserver.swift`, `MainViewModel.swift`.

## 10. Clearing agent data

Question: What happens when all Ollama agent data is deleted?

Expected: The answer should say messages are cleared separately from RAG data, and `deleteAllAgentData()` calls `deleteAllMessages()` plus `indexingService.deleteAll()`.

Expected sources: `OllamaAgent.swift`, `RAGIndexRepository.swift`.
