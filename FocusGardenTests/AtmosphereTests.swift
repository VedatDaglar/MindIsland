//
//  AtmosphereTests.swift
//  FocusGardenTests
//
//  Created by Vedat Daglar on 31.03.2026.
//

import XCTest
@testable import FocusGarden

final class AtmosphereTests: XCTestCase {

    // MARK: - Atmosphere Data Integrity

    func testAtmosphereCountIsFive() {
        XCTAssertEqual(atmospheres.count, 5)
    }

    func testAllAtmospheresHaveUniqueIds() {
        let ids = atmospheres.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count, "Atmosphere IDs must be unique")
    }

    func testAllAtmospheresHaveUniqueSounds() {
        let sounds = atmospheres.map { $0.soundName }
        XCTAssertEqual(Set(sounds).count, sounds.count, "Each atmosphere should have a unique sound")
    }

    func testAllAtmospheresHaveUniqueThemes() {
        let themes = atmospheres.map { $0.themeId }
        XCTAssertEqual(Set(themes).count, themes.count, "Each atmosphere should have a unique theme")
    }

    func testAtmospheresAreSortedByRequiredMinutes() {
        let minutes = atmospheres.map { $0.requiredMinutes }
        XCTAssertEqual(minutes, minutes.sorted(), "Atmospheres should be sorted by required minutes")
    }

    // MARK: - Unlock Requirements

    func testFirstAtmosphereIsFree() {
        XCTAssertEqual(atmospheres.first?.requiredMinutes, 0, "First atmosphere should be free")
        XCTAssertEqual(atmospheres.first?.id, "atmosphere.zen")
    }

    func testUnlockThresholds() {
        let expected: [(String, Int)] = [
            ("atmosphere.zen", 0),
            ("atmosphere.neon", 250),
            ("atmosphere.campfire", 500),
            ("atmosphere.deepfocus", 1000),
            ("atmosphere.cafe", 1500),
        ]

        for (index, (id, minutes)) in expected.enumerated() {
            XCTAssertEqual(atmospheres[index].id, id)
            XCTAssertEqual(atmospheres[index].requiredMinutes, minutes,
                           "\(id) should require \(minutes) minutes")
        }
    }

    // MARK: - Unlock Logic Simulation

    func testAtmosphereUnlockWithZeroMinutes() {
        let unlocked = atmospheres.filter { $0.requiredMinutes <= 0 }
        XCTAssertEqual(unlocked.count, 1)
        XCTAssertEqual(unlocked.first?.id, "atmosphere.zen")
    }

    func testAtmosphereUnlockWith300Minutes() {
        let unlocked = atmospheres.filter { $0.requiredMinutes <= 300 }
        XCTAssertEqual(unlocked.count, 2)
        XCTAssertTrue(unlocked.contains { $0.id == "atmosphere.zen" })
        XCTAssertTrue(unlocked.contains { $0.id == "atmosphere.neon" })
    }

    func testAtmosphereUnlockWith1000Minutes() {
        let unlocked = atmospheres.filter { $0.requiredMinutes <= 1000 }
        XCTAssertEqual(unlocked.count, 4)
    }

    func testAllAtmospheresUnlockWith1500Minutes() {
        let unlocked = atmospheres.filter { $0.requiredMinutes <= 1500 }
        XCTAssertEqual(unlocked.count, 5, "All atmospheres should be unlocked at 1500 minutes")
    }

    // MARK: - Atmosphere Properties

    func testAllAtmospheresHaveIcons() {
        for atmosphere in atmospheres {
            XCTAssertFalse(atmosphere.icon.isEmpty, "\(atmosphere.id) should have an icon")
        }
    }

    func testAllAtmospheresHaveSoundNames() {
        for atmosphere in atmospheres {
            XCTAssertFalse(atmosphere.soundName.isEmpty, "\(atmosphere.id) should have a sound name")
        }
    }

    func testAllAtmospheresHaveThemeIds() {
        for atmosphere in atmospheres {
            XCTAssertFalse(atmosphere.themeId.isEmpty, "\(atmosphere.id) should have a theme ID")
        }
    }
}
