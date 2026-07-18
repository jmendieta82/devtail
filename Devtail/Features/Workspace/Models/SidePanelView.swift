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

    var icon: String {
        switch self {
        case .files: "folder"
        case .processes: "play.square.stack"
        }
    }

    var help: String {
        switch self {
        case .files: "Files"
        case .processes: "Processes"
        }
    }
}
