//
//  OpenFile.swift
//  Devtail
//
//  A file open in the workspace center column (read-only viewer tab).
//

import Foundation

/// A file open in the workspace center column (read-only viewer tab).
struct OpenFile: Identifiable, Hashable {
    let path: String
    var id: String { path }
    var name: String { (path as NSString).lastPathComponent }
}
