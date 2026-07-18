//
//  SidePanelView.swift
//  Devtail
//
//  Views the activity-bar rail can show in the workspace side panel.
//

import Foundation

enum SidePanelView: CaseIterable {
    case files
    case processes
    case tasks

    var icon: String {
        switch self {
        case .files: "folder"
        case .processes: "play.square.stack"
        case .tasks: "checklist"
        }
    }

    var help: String {
        switch self {
        case .files: "Files"
        case .processes: "Processes"
        case .tasks: "Tasks"
        }
    }
}
