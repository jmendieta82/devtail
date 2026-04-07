# Devtail

Native macOS menu bar app for freelance developers managing multiple projects.

Combines three modules in one tool:

- **Context Switcher** — switch between dev projects with one click
- **Credential Vault** — manage development secrets per project, encrypted in macOS Keychain
- **AWS Cost Watcher** — real-time AWS infrastructure cost monitoring

## Stack

- Swift 5+ / SwiftUI
- macOS 15 Sequoia minimum
- SwiftData (local persistence)
- macOS Keychain Services (secrets storage)
- StoreKit 2 (Free + Pro subscriptions)
- AWS SDK for Swift (Cost Explorer integration)

## Distribution

Mac App Store only (App Sandbox enabled).

## Build

Open `Devtail.xcodeproj` in Xcode 26+ and press `Cmd+R`.

From terminal:

```bash
xcodebuild -project Devtail.xcodeproj -scheme Devtail -configuration Debug build
xcodebuild -list                                          # list schemes
xcodebuild clean -project Devtail.xcodeproj -scheme Devtail
```

## Project structure

```
Devtail/
├── App/                  # App entry point, root scenes
├── Features/
│   ├── ContextSwitcher/  # Project switching
│   ├── CredentialVault/  # Secret management
│   └── CloudCosts/       # AWS / GCP / Azure cost tracking
├── Core/
│   ├── Persistence/      # SwiftData model container
│   ├── Keychain/         # Keychain wrapper
│   ├── Shell/            # NSWorkspace launcher
│   └── Extensions/
├── DesignSystem/         # Reusable UI components, colors, fonts
└── Resources/            # Assets.xcassets
```

## Bundle Identifier

`com.jamodev.Devtail`

## License

Proprietary — All rights reserved.
