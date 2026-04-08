//
//  QuickLinkError.swift
//  Devtail
//
//  Domain errors for the QuickLink entity.
//

import Foundation

enum QuickLinkError: Error, Equatable {
    case invalidLabel
    case invalidURL
}
