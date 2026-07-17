# Devtail — Project Context for Claude Code

## Engram Identity

- **Project name in engram**: `devtail`
- When calling `mem_save`, `mem_search`, `mem_session_summary` or any engram tool, ALWAYS pass `project: "devtail"` explicitly.
- Open Claude Code from THIS directory (`DEVTAIL/Devtail/`), not from subdirectories.

## What is this project

Devtail is a native macOS menu bar app for freelance developers managing multiple projects. Three modules: Context Switcher, Credential Vault, AWS Cost Watcher.

Full product spec lives in Notion: page id `33b51204-0274-810d-a954-cd13a46e23c5` (parent: Freelance → Mi mundo). Always cross-reference Notion for product/business decisions.

## Stack

- **Language:** Swift 5 language mode (`SWIFT_VERSION = 5.0`, Xcode 26.4 toolchain) with approachable concurrency (`SWIFT_APPROACHABLE_CONCURRENCY = YES`) and MainActor default isolation (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`) — NOT the Swift 6 language mode
- **UI:** SwiftUI declarative
- **App shell:** `MenuBarExtra` (primary; the menu bar popover absorbed the old dashboard window) + per-project workspace `WindowGroup` + a small "New Project" `Window`
- **Persistence:** SwiftData (local SQLite via Apple ORM)
- **Secrets:** macOS Keychain Services (Secure Enclave-backed)
- **Subscriptions:** StoreKit 2
- **Cloud SDKs:** `aws-sdk-swift` (Phase 3), `gcp` and `azure` later
- **Min macOS:** 26.0 Tahoe (`MACOSX_DEPLOYMENT_TARGET = 26.0`)
- **Bundle ID:** `com.jamodev.Devtail`
- **Development Team:** UCSM3T74LQ

## Critical decisions (do not violate without explicit user confirmation)

1. **App Sandbox is OFF (decided 2026-07-14).** Devtail is a personal tool distributed directly — not via Mac App Store. Hardened Runtime stays ON. This means:
   - PTY sessions and managed processes are allowed (the reason sandbox was dropped)
   - `ENABLE_APP_SANDBOX = NO` in the pbxproj — the build setting injects the entitlement at signing regardless of the entitlements file; never set it back to YES (incident 2026-07-15: it silently re-sandboxed every build)
   - Security-scoped bookmarks are legacy (kept dormant, cleanup deferred)
   - macOS TCC still applies (external volumes, Documents, etc.) — expect one-time permission prompts
2. **macOS 26.0 Tahoe minimum** (`MACOSX_DEPLOYMENT_TARGET = 26.0`). Do not use APIs newer than Tahoe without confirming.
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
│   ├── Workspace/        # per-project workspace windows (adds Services/)
│   ├── CredentialVault/
│   └── CloudCosts/
├── Core/
│   ├── Persistence/      # SwiftData ModelContainer setup
│   ├── Keychain/         # Keychain wrapper
│   ├── Shell/            # NSWorkspace + security-scoped bookmarks
│   ├── Claude/           # Claude Code project introspection
│   ├── GitDetection/     # git status reader
│   ├── StackDetection/   # project stack detectors
│   └── Settings/         # AppSettings
├── DesignSystem/         # Colors, typography, reusable components
└── Resources/            # Fonts (Assets.xcassets lives at Devtail/ root)
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
- Disable Hardened Runtime, or re-enable App Sandbox (it is deliberately OFF — see critical decision 1).
- Add telemetry, analytics, or any kind of phone-home code.
- Use `Process` for shell commands when sandboxed alternatives exist.
- Generate "improvements" or refactors not requested by the user.
- Add comments explaining obvious Swift syntax — the user is senior.
