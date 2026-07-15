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
    /// When true, the Edit/Done toggle is hidden and links are
    /// pure-tap-to-open. The popover uses this to keep the surface
    /// strictly consult-and-launch — actual link management lives in
    /// the dashboard.
    var isReadOnly: Bool = false
    /// When true, hides the redundant "QUICK LINKS" title inside the
    /// panel header. The Edit/Done button stays visible so link
    /// management still works. Used when the panel lives inside a
    /// parent that already labels it (e.g. the dashboard's tab bar).
    var hideTitle: Bool = false

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
            if !hideTitle {
                Text("QUICK LINKS")
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    .tracking(0.5)
                if let count = currentProject?.quickLinks.count, count > 0 {
                    Text("\(count)")
                        .font(DevtailTokens.Typography.captionSmall)
                        .foregroundStyle(DevtailTokens.Colors.textMuted)
                }
            }
            Spacer()
            if currentProject != nil && !isReadOnly {
                Button(isEditingLinks ? "Done" : "Edit") {
                    if isEditingLinks {
                        isAddingLink = false
                        editingLinkID = nil
                    }
                    isEditingLinks.toggle()
                }
                .buttonStyle(.plain)
                .font(DevtailTokens.Typography.bodySmall)
                .foregroundStyle(DevtailTokens.Colors.accentPrimary)
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
            Text(isReadOnly
                 ? "Open Manage… to add links."
                 : "Enter edit mode to add your first link.")
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    /// Two-column grid; each chip fills the full width of its cell so
    /// rows line up even when labels differ in length.
    private var chipGridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: DevtailTokens.Spacing.gapMedium),
            GridItem(.flexible(), spacing: DevtailTokens.Spacing.gapMedium)
        ]
    }

    /// Groups the project's links by their classified category and
    /// returns the categories that actually have at least one link,
    /// preserving `QuickLinkCategory.displayOrder`.
    private var groupedLinks: [(category: QuickLinkCategory, links: [QuickLink])] {
        let grouped = Dictionary(grouping: sortedLinks) { link in
            QuickLinkCategory.classify(urlString: link.url)
        }
        return QuickLinkCategory.displayOrder.compactMap { category in
            guard let links = grouped[category], !links.isEmpty else { return nil }
            return (category, links)
        }
    }

    private var linkList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapLarge) {
                // One section per non-empty category. Each section has a
                // small uppercase header followed by the 2-column chip grid.
                ForEach(groupedLinks, id: \.category) { group in
                    categorySection(category: group.category, links: group.links)
                }

                // Edit-mode affordances span the full width, outside the
                // grid so they never share a row with a chip cell.
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
                            .foregroundStyle(DevtailTokens.Colors.accentPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// Threshold above which a category's chips are split across two
    /// columns. At or below this count we render a single full-width
    /// column — a list of 2-3 repos reads much better stacked vertically
    /// than as one row of half-width chips with empty air on each side.
    private static let singleColumnThreshold = 5

    /// Splits a link list into two columns filled top-to-bottom:
    /// left column takes ceil(n/2), right column takes the rest. This
    /// matches the user's mental model of "first fill down, then across"
    /// instead of LazyVGrid's default row-major fill.
    private func columnSplit(_ links: [QuickLink]) -> (left: [QuickLink], right: [QuickLink]) {
        let midpoint = (links.count + 1) / 2
        let left = Array(links.prefix(midpoint))
        let right = Array(links.dropFirst(midpoint))
        return (left, right)
    }

    @ViewBuilder
    private func categorySection(
        category: QuickLinkCategory,
        links: [QuickLink]
    ) -> some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
            Text(category.header)
                .font(DevtailTokens.Typography.captionSmall)
                .tracking(0.5)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)

            if links.count <= Self.singleColumnThreshold {
                // Small groups render as a single full-width column so
                // each chip gets real estate proportional to its role.
                columnView(links: links)
            } else {
                let (leftColumn, rightColumn) = columnSplit(links)
                HStack(
                    alignment: .top,
                    spacing: DevtailTokens.Spacing.gapMedium
                ) {
                    columnView(links: leftColumn)
                    columnView(links: rightColumn)
                }
            }
        }
    }

    @ViewBuilder
    private func columnView(links: [QuickLink]) -> some View {
        VStack(
            alignment: .leading,
            spacing: DevtailTokens.Spacing.gapMedium
        ) {
            ForEach(links, id: \.id) { link in
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
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            vscodeLauncher: VSCodeLauncher(),
            browserLauncher: BrowserLauncher()
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
            vscodeLauncher: VSCodeLauncher(),
            browserLauncher: BrowserLauncher()
        )
        store.createProject(name: "Devtail", color: .green)
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
