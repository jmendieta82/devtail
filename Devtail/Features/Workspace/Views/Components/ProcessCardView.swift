//
//  ProcessCardView.swift
//  Devtail
//
//  Sidebar card for one managed process: state dot, name, lifecycle actions.
//

import SwiftUI

struct ProcessCardView: View {
    let process: ManagedProcess
    let isSelected: Bool
    let onSelect: () -> Void
    let onStart: () -> Void
    let onStop: () -> Void
    let onRestart: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 2) {
                    Text(process.name)
                        .font(DevtailTokens.Typography.body)
                        .lineLimit(1)
                    Text(stateLabel)
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                actions
            }
            .padding(DevtailTokens.Spacing.gapMedium)
            .background(
                RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                    .fill(isSelected ? Color.primary.opacity(0.08) : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var actions: some View {
        switch process.state {
        case .running, .starting:
            Button("Restart", systemImage: "arrow.clockwise", action: onRestart)
                .labelStyle(.iconOnly).buttonStyle(.plain).help("Restart")
            Button("Stop", systemImage: "stop.fill", action: onStop)
                .labelStyle(.iconOnly).buttonStyle(.plain).help("Stop")
        case .stopped, .exited:
            Button("Start", systemImage: "play.fill", action: onStart)
                .labelStyle(.iconOnly).buttonStyle(.plain).help("Start")
        }
    }

    private var stateColor: Color {
        switch process.state {
        case .running: .green
        case .starting: .yellow
        case .stopped: .gray
        case .exited: .red
        }
    }

    private var stateLabel: String {
        switch process.state {
        case .running: "running"
        case .starting: "starting…"
        case .stopped: "stopped"
        case .exited(let code): code.map { "exited (\($0))" } ?? "exited"
        }
    }
}
