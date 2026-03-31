//
//  FocusSession.swift
//  FocusGarden
//
//  Created by Vedat Dağlar on 15.03.2026.
//

import Foundation
import SwiftData

@Model
final class FocusSession {
    var date: Date
    var durationMinutes: Int
    var completed: Bool
    var category: String

    init(date: Date, durationMinutes: Int, completed: Bool = false, category: String = "general") {
        self.date = date
        self.durationMinutes = durationMinutes
        self.completed = completed
        self.category = category
    }
}
