//
//  QuickLinksPanel.swift
//  Devtail
//
//  Detail panel rendered below the project list. Receives the selected
//  projectID, reads the store from the environment, and owns all edit state
//  for quick links (isEditingLinks, isAddingLink, editingLinkID).
//

import SwiftUI
import SwiftData

struct QuickLinksPanel: View {
    let projectID: UUID?

    @Environment(ProjectStore.self) private var store

    @State private var isEditingLinks: Bool = false
    @State private var isAddingLink: Bool = false
    @State private var editingLinkID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
        }
        .padding(.horizontal, DevtailTokens.Spacing.popoverPadding)
        .padding(.vertical, DevtailTokens.Spacing.gapMedium)
        .onChange(of: projectID) { _, _ in
            resetEditState()
        }
    }

    private var currentProject: Project? {
        guard let projectID else { return nil }
        return store.projects.first { $0.id == projectID }
    }

    private var sortedLinks: [QuickLink] {
        currentProject?.quickLinks.sorted { $0.order < $1.order } ?? []
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: DevtailTokens.Spacing.gapSmall) {
            Text("QUICK LINKS")
                .font(DevtailTokens.Typography.captionSmall)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
                .tracking(0.5)
            if let count = currentProject?.quickLinks.count, count > 0 {
                Text("\(count)")
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textMuted)
            }
            Spacer()
            if currentProject != nil {
                Button(isEditingLinks ? "Done" : "Edit") {
                    if isEditingLinks {
                        isAddingLink = false
                        editingLinkID = nil
                    }
                    isEditingLinks.toggle()
                }
                .buttonStyle(.plain)
                .font(DevtailTokens.Typography.bodySmall)
                .foregroundStyle(DevtailTokens.Colors.accentGreen)
            }
        }
        .padding(.bottom, DevtailTokens.Spacing.gapMedium)
    }

    @ViewBuilder
    private var content: some View {
        if currentProject == nil {
            emptyNoSelection
        } else if sortedLinks.isEmpty && !isEditingLinks {
            emptyNoLinks
        } else {
            linkList
        }
    }

    private var emptyNoSelection: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
            Text("Select a project")
                .font(DevtailTokens.Typography.bodyDefault)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
            Text("Tap a project to see its quick links.")
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var emptyNoLinks: some View {
        VStack(alignment: .center, spacing: DevtailTokens.Spacing.gapSmall) {
            Text("No quick links yet")
                .font(DevtailTokens.Typography.bodyDefault)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
            Text("Enter edit mode to add your first link.")
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var linkList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
                ForEach(sortedLinks, id: \.id) { link in
                    if editingLinkID == link.id {
                        QuickLinkEditRow(
                            initialLabel: link.label,
                            initialURL: link.url,
                            onSave: { newLabel, newURL in
                                store.updateQuickLink(link, label: newLabel, url: newURL)
                                editingLinkID = nil
                            },
                            onCancel: {
                                editingLinkID = nil
                            }
                        )
                    } else {
                        QuickLinkChip(
                            quickLink: link,
                            isEditing: isEditingLinks,
                            onEditTap: {
                                editingLinkID = link.id
                            },
                            onDelete: {
                                store.deleteQuickLink(link)
                            }
                        )
                    }
                }

                if isEditingLinks {
                    if isAddingLink {
                        QuickLinkEditRow(
                            onSave: { newLabel, newURL in
                                if let project = currentProject {
                                    store.addQuickLink(label: newLabel, url: newURL, to: project)
                                }
                                isAddingLink = false
                            },
                            onCancel: {
                                isAddingLink = false
                            }
                        )
                    } else {
                        Button {
                            isAddingLink = true
                        } label: {
                            HStack(spacing: DevtailTokens.Spacing.gapSmall) {
                                Image(systemName: "plus")
                                Text("Add link")
                            }
                            .font(DevtailTokens.Typography.bodySmall)
                            .foregroundStyle(DevtailTokens.Colors.accentGreen)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func resetEditState() {
        isEditingLinks = false
        isAddingLink = false
        editingLinkID = nil
    }
}

#Preview("Empty - no selection") {
    let store: ProjectStore = {
        let container = PersistenceController.makeContainer(inMemory: true)
        let projectRepo = ProjectRepository(context: container.mainContext)
        let linkRepo = QuickLinkRepository(context: container.mainContext)
        let paneRepo = WorkspacePaneRepository(context: container.mainContext)
        return ProjectStore(
            repository: projectRepo,
            quickLinkRepository: linkRepo,
            workspacePaneRepository: paneRepo,
            launcher: WorkspaceLauncher()
        )
    }()
    QuickLinksPanel(projectID: nil)
        .environment(store)
        .frame(width: 320)
        .background(DevtailTokens.Colors.popoverBackground)
}

#Preview("Project with links") {
    let (store, projectID): (ProjectStore, UUID) = {
        let container = PersistenceController.makeContainer(inMemory: true)
        let projectRepo = ProjectRepository(context: container.mainContext)
        let linkRepo = QuickLinkRepository(context: container.mainContext)
        let paneRepo = WorkspacePaneRepository(context: container.mainContext)
        let store = ProjectStore(
            repository: projectRepo,
            quickLinkRepository: linkRepo,
            workspacePaneRepository: paneRepo,
            launcher: WorkspaceLauncher()
        )
        store.createProject(name: "Devtail", color: .green, environment: .dev)
        if let project = store.projects.first {
            store.addQuickLink(label: "GitHub", url: "https://github.com", to: project)
            store.addQuickLink(label: "Notion", url: "https://notion.so", to: project)
        }
        return (store, store.projects[0].id)
    }()
    QuickLinksPanel(projectID: projectID)
        .environment(store)
        .frame(width: 320)
        .background(DevtailTokens.Colors.popoverBackground)
}
