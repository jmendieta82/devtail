//
//  FileTreePlaceholderColumn.swift
//  Devtail
//
//  Right column placeholder. Cycle 2 (file tree + viewer) mounts here.
//

import SwiftUI

/// Right column placeholder. Cycle 2 (file tree + viewer) mounts here.
struct FileTreePlaceholderColumn: View {
    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "folder")
                .font(.title2)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
            Text("Files")
                .font(.headline)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
            Text("Coming soon")
                .font(.caption)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
