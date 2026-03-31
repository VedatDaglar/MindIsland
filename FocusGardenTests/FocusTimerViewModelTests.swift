//
//  FocusTimerViewModelTests.swift
//  FocusGardenTests
//
//  Created by Vedat Daglar on 31.03.2026.
//

import XCTest
@testable import FocusGarden

final class FocusTimerViewModelTests: XCTestCase {

    private var defaults: UserDefaults!
    private var sut: FocusTimerViewModel!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "com.focusgarden.tests")!
        defaults.removePersistentDomain(forName: "com.focusgarden.tests")
        sut = FocusTimerViewModel(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "com.focusgarden.tests")
        defaults = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testDefaultInitialValues() {
        XCTAssertEqual(sut.focusDuration, 25 * 60, "Default focus duration should be 25 minutes")
        XCTAssertEqual(sut.timeRemaining, 25 * 60)
        XCTAssertFalse(sut.timerIsRunning)
        XCTAssertFalse(sut.sessionCompleted)
        XCTAssertFalse(sut.showCelebration)
        XCTAssertFalse(sut.sessionFailed)
        XCTAssertFalse(sut.breakIsRunning)
        XCTAssertEqual(sut.totalFocusMinutes, 0)
        XCTAssertEqual(sut.completedSessions, 0)
        XCTAssertEqual(sut.focusStreak, 0)
        XCTAssertEqual(sut.focusCoins, 0)
        XCTAssertEqual(sut.selectedCategory, "general")
        XCTAssertTrue(sut.ambientSoundsEnabled)
        XCTAssertFalse(sut.notificationsEnabled)
    }

    func testInitRestoresPersistedValues() {
        defaults.set(120, forKey: "totalFocusMinutes")
        defaults.set(5, forKey: "completedSessions")
        defaults.set(3, forKey: "focusStreak")
        defaults.set(50, forKey: "focusCoins")
        defaults.set("work", forKey: "lastSelectedCategory")

        let vm = FocusTimerViewModel(defaults: defaults)

        XCTAssertEqual(vm.totalFocusMinutes, 120)
        XCTAssertEqual(vm.completedSessions, 5)
        XCTAssertEqual(vm.focusStreak, 3)
        XCTAssertEqual(vm.focusCoins, 50)
        XCTAssertEqual(vm.selectedCategory, "work")
    }

    // MARK: - Duration Selection Tests

    func testSelectDuration15Minutes() {
        sut.selectDuration(15)

        XCTAssertEqual(sut.focusDuration, 15 * 60)
        XCTAssertEqual(sut.timeRemaining, 15 * 60)
        XCTAssertEqual(sut.selectedMinutes, 15)
    }

    func testSelectDuration45Minutes() {
        sut.selectDuration(45)

        XCTAssertEqual(sut.focusDuration, 45 * 60)
        XCTAssertEqual(sut.timeRemaining, 45 * 60)
        XCTAssertEqual(sut.selectedMinutes, 45)
    }

    func testSelectDurationIgnoredWhenTimerRunning() {
        sut.startSession()
        let originalDuration = sut.focusDuration

        sut.selectDuration(60)

        XCTAssertEqual(sut.focusDuration, originalDuration, "Duration should not change while timer is running")
    }

    func testIsCustomSelectedForStandardDurations() {
        sut.selectDuration(15)
        XCTAssertFalse(sut.isCustomSelected)

        sut.selectDuration(25)
        XCTAssertFalse(sut.isCustomSelected)

        sut.selectDuration(45)
        XCTAssertFalse(sut.isCustomSelected)

        sut.selectDuration(60)
        XCTAssertFalse(sut.isCustomSelected)
    }

    func testIsCustomSelectedForNonStandardDurations() {
        sut.selectDuration(30)
        XCTAssertTrue(sut.isCustomSelected)

        sut.selectDuration(90)
        XCTAssertTrue(sut.isCustomSelected)
    }

    // MARK: - Break Duration Calculation Tests

    func testBreakDurationForShortSession() {
        sut.selectDuration(15)
        XCTAssertEqual(sut.breakDuration, 3 * 60, "15-min session should have 3-min break")
    }

    func testBreakDurationForMediumSession() {
        sut.selectDuration(25)
        XCTAssertEqual(sut.breakDuration, 5 * 60, "25-min session should have 5-min break")
    }

    func testBreakDurationForLongSession() {
        sut.selectDuration(45)
        XCTAssertEqual(sut.breakDuration, 10 * 60, "45-min session should have 10-min break")
    }

    func testBreakDurationForVeryLongSession() {
        sut.selectDuration(90)
        XCTAssertEqual(sut.breakDuration, 15 * 60, "90-min session should have 15-min break")
    }

    // MARK: - Timer State Tests

    func testStartSession() {
        sut.startSession()

        XCTAssertTrue(sut.timerIsRunning)
        XCTAssertFalse(sut.sessionCompleted)
        XCTAssertFalse(sut.sessionFailed)
        XCTAssertFalse(sut.showCelebration)
        XCTAssertNotNil(sut.sessionEndDate)
    }

    func testStartSessionSetsCorrectEndDate() {
        let beforeStart = Date()
        sut.startSession()
        let afterStart = Date()

        guard let endDate = sut.sessionEndDate else {
            XCTFail("sessionEndDate should not be nil after starting")
            return
        }

        let expectedEndMin = beforeStart.addingTimeInterval(TimeInterval(sut.focusDuration))
        let expectedEndMax = afterStart.addingTimeInterval(TimeInterval(sut.focusDuration))

        XCTAssertGreaterThanOrEqual(endDate, expectedEndMin)
        XCTAssertLessThanOrEqual(endDate, expectedEndMax)
    }

    func testDoubleStartIsIgnored() {
        sut.startSession()
        let firstEndDate = sut.sessionEndDate

        sut.startSession()

        XCTAssertEqual(sut.sessionEndDate, firstEndDate, "Second start should be ignored")
    }

    func testStopSession() {
        sut.startSession()
        sut.stopSession()

        XCTAssertFalse(sut.timerIsRunning)
        XCTAssertNil(sut.sessionEndDate)
        XCTAssertEqual(sut.timeRemaining, sut.focusDuration)
    }

    func testFailSession() {
        sut.startSession()
        sut.failSession()

        XCTAssertFalse(sut.timerIsRunning)
        XCTAssertTrue(sut.sessionFailed)
        XCTAssertFalse(sut.sessionCompleted)
        XCTAssertFalse(sut.showCelebration)
        XCTAssertNil(sut.sessionEndDate)
    }

    func testDismissFailure() {
        sut.startSession()
        sut.failSession()
        sut.dismissFailure()

        XCTAssertFalse(sut.sessionFailed)
    }

    // MARK: - Break Tests

    func testSkipBreak() {
        // Simulate a break state
        sut.startSession()
        // We can't easily trigger completeSession without mocking time,
        // but we can test skipBreak resets state correctly
        sut.skipBreak()

        XCTAssertFalse(sut.breakIsRunning)
        XCTAssertNil(sut.breakEndDate)
        XCTAssertEqual(sut.timeRemaining, sut.focusDuration)
        XCTAssertFalse(sut.sessionCompleted)
    }

    // MARK: - Category Tests

    func testSelectCategory() {
        sut.selectCategory("work")
        XCTAssertEqual(sut.selectedCategory, "work")
        XCTAssertEqual(defaults.string(forKey: "lastSelectedCategory"), "work")
    }

    func testSelectCategoryPersists() {
        sut.selectCategory("study")

        let vm2 = FocusTimerViewModel(defaults: defaults)
        XCTAssertEqual(vm2.selectedCategory, "study")
    }

    // MARK: - Time String Tests

    func testTimeStringFormat() {
        sut.selectDuration(25)
        XCTAssertEqual(sut.timeString, "25:00")
    }

    func testTimeStringFormatSingleDigits() {
        sut.selectDuration(5)
        XCTAssertEqual(sut.timeString, "05:00")
    }

    // MARK: - Progress Value Tests

    func testProgressValueAtStart() {
        XCTAssertEqual(sut.progressValue, 0.0, accuracy: 0.01)
    }

    func testProgressValueBounds() {
        XCTAssertGreaterThanOrEqual(sut.progressValue, 0.0)
        XCTAssertLessThanOrEqual(sut.progressValue, 1.0)
    }

    // MARK: - Custom Duration Sheet Tests

    func testPresentCustomSheet() {
        sut.presentCustomSheet()
        XCTAssertTrue(sut.showCustomSheet)
    }

    func testPresentCustomSheetIgnoredWhenRunning() {
        sut.startSession()
        sut.presentCustomSheet()
        XCTAssertFalse(sut.showCustomSheet)
    }

    func testDismissCustomSheet() {
        sut.presentCustomSheet()
        sut.dismissCustomSheet()
        XCTAssertFalse(sut.showCustomSheet)
    }

    func testConfirmCustomDuration() {
        sut.customMinutes = 42
        sut.presentCustomSheet()
        sut.confirmCustomDurationSelection()

        XCTAssertEqual(sut.selectedMinutes, 42)
        XCTAssertFalse(sut.showCustomSheet)
    }

    // MARK: - Persistence Tests

    func testTimerStatePersistsAfterStart() {
        sut.startSession()

        XCTAssertTrue(defaults.bool(forKey: "timerIsRunning"))
        XCTAssertNotNil(defaults.object(forKey: "sessionEndDate"))
    }

    func testTimerStatePersistsAfterStop() {
        sut.startSession()
        sut.stopSession()

        XCTAssertFalse(defaults.bool(forKey: "timerIsRunning"))
        XCTAssertNil(defaults.object(forKey: "sessionEndDate"))
    }

    func testDurationPersistsAcrossInstances() {
        sut.selectDuration(45)

        let vm2 = FocusTimerViewModel(defaults: defaults)
        XCTAssertEqual(vm2.focusDuration, 45 * 60)
    }

    // MARK: - Today Preview Minutes Tests

    func testTodayPreviewMinutesWhenIdle() {
        defaults.set(100, forKey: "totalFocusMinutes")
        let vm = FocusTimerViewModel(defaults: defaults)

        XCTAssertEqual(vm.todayPreviewMinutes, 100)
    }
}
