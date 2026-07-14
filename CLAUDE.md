# Devtail — Project Context for Claude Code

## Engram Identity

- **Project name in engram**: `devtail`
- When calling `mem_save`, `mem_search`, `mem_session_summary` or any engram tool, ALWAYS pass `project: "devtail"` explicitly.
- Open Claude Code from THIS directory (`DEVTAIL/Devtail/`), not from subdirectories.

## What is this project

Devtail is a native macOS menu bar app for freelance developers managing multiple projects. Three modules: Context Switcher, Credential Vault, AWS Cost Watcher.

Full product spec lives in Notion: page id `33b51204-0274-810d-a954-cd13a46e23c5` (parent: Freelance → Mi mundo). Always cross-reference Notion for product/business decisions.

## Stack

- **Language:** Swift 5+ (Xcode 26.4 toolchain, Swift 6 concurrency model active via `SWIFT_APPROACHABLE_CONCURRENCY = YES` and `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`)
- **UI:** SwiftUI declarative
- **App shell:** `MenuBarExtra` (primary) + `Window` for full dashboard
- **Persistence:** SwiftData (local SQLite via Apple ORM)
- **Secrets:** macOS Keychain Services (Secure Enclave-backed)
- **Subscriptions:** StoreKit 2
- **Cloud SDKs:** `aws-sdk-swift` (Phase 3), `gcp` and `azure` later
- **Min macOS:** 15.0 Sequoia
- **Bundle ID:** `com.jamodev.Devtail`
- **Development Team:** UCSM3T74LQ

## Critical decisions (do not violate without explicit user confirmation)

1. **Mac App Store only.** App Sandbox is ON. Hardened Runtime is ON. This means:
   - No direct `Process` calls for launching external apps
   - Use `NSWorkspace.open(_:configuration:)` instead
   - Filesystem access requires `NSOpenPanel` + security-scoped bookmarks
   - No Sparkle (App Store handles updates)
   - All entitlements must be App Store compatible
2. **macOS 15 Sequoia minimum.** Do not use APIs newer than Sequoia without confirming.
3. **No backend.** Everything is local. SwiftData + Keychain. Cloud calls go directly client → provider API.
4. **Zero telemetry.** No analytics SDKs, no logging to remote servers.
5. **MenuBarExtra over NSStatusItem.** Use the SwiftUI native API. Drop to AppKit only if absolutely necessary.

## Architecture

Layered, lightweight Clean Architecture adapted for app size:

```
Devtail/
├── App/                  # DevtailApp.swift, AppDelegate, root scenes
├── Features/
│   ├── ContextSwitcher/
│   │   ├── Models/
│   │   ├── Views/
│   │   └── Stores/       # @Observable state holders
│   ├── CredentialVault/
│   └── CloudCosts/
├── Core/
│   ├── Persistence/      # SwiftData ModelContainer setup
│   ├── Keychain/         # Keychain wrapper
│   ├── Shell/            # NSWorkspace + security-scoped bookmarks
│   └── Extensions/
├── DesignSystem/         # Colors, typography, reusable components
└── Resources/            # Assets.xcassets
```

State management: prefer `@Observable` macro (Swift 5.9+ / iOS 17+ / macOS 14+) over `ObservableObject`/`@Published`. The new approach is the canonical one — do not use the old pattern.

## Modules — implementation order

1. **Context Switcher** (Phase 1, MVP) — highest priority. Project CRUD, quick links, menu bar UI, terminal launcher via NSWorkspace.
2. **Credential Vault** (Phase 2) — Keychain wrapper, copy with auto-clean clipboard, .env import/export.
3. **AWS Cost Watcher** (Phase 3) — Cost Explorer integration, daily/monthly costs, alerts.

## Build commands

```bash
xcodebuild -project Devtail.xcodeproj -scheme Devtail -configuration Debug build
xcodebuild -list
xcodebuild clean -project Devtail.xcodeproj -scheme Devtail
```

**Important:** never run builds proactively. Only build when the user explicitly asks.

## User profile

Senior developer, 15+ years. Experienced in:

- Native Android with Kotlin (lifecycle, threading, ViewModels, native architecture)
- Full stack TypeScript (NestJS, Angular)
- AWS infrastructure (IAM, Cost Explorer, services)
- Django

**First time** working with: Swift, SwiftUI, the entire Apple ecosystem (Xcode, App Store, StoreKit, Keychain, SwiftData).

When explaining Swift/Apple-specific concepts:

- Use Kotlin/TypeScript analogies (`protocol` ≈ `interface`, `struct` is value type unlike Kotlin `data class`, `Task { }` ≈ `viewModelScope.launch`, `@Observable` ≈ `StateFlow`/`BehaviorSubject`, SwiftUI ≈ Compose/Angular declarative)
- Skip programming fundamentals — he knows them
- Focus on Apple ecosystem quirks (signing, sandboxing, Xcode gotchas, App Store flow)
- Be direct, opinionated, technical

## Conventions

- **Commit style:** Conventional Commits. NEVER add "Co-Authored-By" or AI attribution.
- **CLI tools:** Use `bat`, `rg`, `fd`, `sd`, `eza` instead of `cat`, `grep`, `find`, `sed`, `ls`.
- **Naming:** Swift conventions — `PascalCase` for types, `camelCase` for properties/methods, no Hungarian notation, no `_` prefixes.
- **File organization:** one type per file unless they are tightly coupled (e.g., a small helper enum used only by one type).
- **No premature abstractions.** Only build interfaces/protocols when there is a real second implementation or a real testing need.

## Things to NEVER do

- Add SPM dependencies before they are needed (Sparkle, KeychainAccess, aws-sdk-swift come when their feature is being implemented, not before).
- Build the project without explicit user request.
- Disable App Sandbox or Hardened Runtime.
- Add telemetry, analytics, or any kind of phone-home code.
- Use `Process` for shell commands when sandboxed alternatives exist.
- Generate "improvements" or refactors not requested by the user.
- Add comments explaining obvious Swift syntax — the user is senior.
