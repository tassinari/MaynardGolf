//
//  ComponentTests.swift
//  MaynardUITests
//

import SwiftUI
import Testing
import UIKit
@testable import MaynardUI

/// §7.1 buttons: the color table behind every style.
struct ButtonKindTests {
    @Test(arguments: [
        (DSButtonKind.primary, DSColorToken?.some(.primaryAction), DSColorToken.onAccent),
        (.scrim, .scrim, .onImagery), (.tertiary, .tintedFill, .tintedText), (.tinted, .tintedFill, .tintedText),
        (.neutralPill, .surfaceRaised, .textPrimary), (.textLink, nil, .link),
    ])
    func enabledColors(kind: DSButtonKind, fill: DSColorToken?, text: DSColorToken) {
        let colors = kind.colors(isEnabled: true)
        #expect(colors.fill == fill && colors.text == text)
        #expect(kind.textStyle == .bodyEmphasized)
    }

    /// DS-BT-01: disabled is `surfaceRaised` + `textSecondary`; a text link just greys out.
    @Test(arguments: DSButtonKind.allCases)
    func disabledColors(kind: DSButtonKind) {
        let colors = kind.colors(isEnabled: false)
        if kind == .textLink {
            #expect(colors.fill == nil && colors.text == .textTertiary)
        } else {
            #expect(colors.fill == .surfaceRaised && colors.text == .textSecondary)
        }
    }

    @Test func sizes() {
        #expect(DSButtonHeight.allCases.map(\.rawValue) == [44, 48, 56])
        #expect(DSIconButtonSize.allCases.map(\.rawValue) == [44, 52])
    }

    /// DS-BT-07, HP-OO-03: the warning badge is 30 × 28 pt, 10 pt outside the button's top-trailing corner.
    @Test func warningBadgeGeometry() {
        #expect(WarningBadge.size == CGSize(width: 30, height: 28))
        #expect(WarningBadge.outset == 10)
    }
}

/// Distances in yards or meters (DS-CH-01).
struct DistanceUnitTests {
    @Test(arguments: [(DistanceUnit.yards, 148, 148), (.meters, 148, 135), (.meters, 0, 0), (.meters, 500, 457)])
    func conversion(unit: DistanceUnit, yards: Int, value: Int) {
        #expect(unit.value(fromYards: yards) == value)
    }

    @Test func abbreviationsAndSpokenForms() {
        #expect(DistanceUnit.yards.abbreviation == "yds")
        #expect(DistanceUnit.meters.abbreviation == "m")
        #expect(DistanceUnit.yards.spoken(1) == "1 yard")
        #expect(DistanceUnit.yards.spoken(148) == "148 yards")
        #expect(DistanceUnit.meters.spoken(1) == "1 meter")
        #expect(DistanceUnit.meters.spoken(135) == "135 meters")
    }
}

/// §7.2 identity and §7.3 chips: initials and VoiceOver text.
struct IdentityAndChipTextTests {
    @Test(arguments: [("Mark", "M"), ("  josé", "J"), ("émile", "É"), ("", "?"), ("   ", "?")])
    func initials(name: String, initial: String) {
        #expect(PlayerAvatar.initial(of: name) == initial)
    }

    @Test func labels() {
        #expect(PlayerAvatar.accessibilityLabel(for: "Mark") == "Photo of Mark")
        #expect(HoleNumberBadge.accessibilityLabel(for: 7) == "Hole 7")
        #expect(AvatarPicker.accessibilityLabel(hasPhoto: false) == "Add photo")
        #expect(AvatarPicker.accessibilityLabel(hasPhoto: true) == "Change photo")
        #expect(PinChip.text(148) == "Pin 148")
        #expect(PinChip.spoken(148, unit: .yards) == "Pin, 148 yards")
        #expect(StatusPill.Status.inProgress.text == "In progress")
        #expect(PlayerScoreChip.accessibilityLabel(name: "Mark", score: 41) == "Mark, 41")
        #expect(DSCapsuleButtonStyle.loadingValue == "Loading")
    }

    @Test func avatarSizes() {
        #expect(AvatarSize.allCases.map(\.rawValue) == [24, 28, 40, 44, 48, 52, 60, 64, 104, 112])
        #expect(AvatarSize.s.initialSize == 17)
        #expect(AvatarSize.profile.initialSize == 52) // PC-HDR-02
        // X-06: every initial is WCAG large text (14 pt bold), so white on Flag / Fairway (4.3 : 1) passes at 3 : 1.
        #expect(AvatarSize.allCases.allSatisfy { $0.initialSize >= AvatarSize.minimumInitialSize })
        #expect(AvatarSize.xxs.initialSize == 14 && AvatarSize.xs.initialSize == 14)
        #expect(HoleNumberBadge.Size.allCases.map(\.rawValue) == [36, 60])
    }
}

struct CatalogHelperTests {
    @Test func cycledRepeatsToTheCount() {
        #expect([1, 2].cycled(5) == [1, 2, 1, 2, 1])
        #expect([Int]().cycled(3).isEmpty)
    }

    /// The catalog's groups, in 00-design-system §7 order. Their raw values are the names UI tests pass to
    /// `-uiTestCatalogSection` (`CatalogUITests.Group`), and each gets a section (`catalog.group.<name>`).
    @Test func catalogGroups() {
        #expect(ComponentCatalogView.Group.allCases.map(\.rawValue) == [
            "Buttons", "Identity", "Chips & badges", "Containers & rows", "Form controls",
            "Navigation & sheets", "Golf display", "Course overlay",
        ])
    }
}

/// Smoke tests: every component sample renders in both appearances and at AX3.
@MainActor
struct ComponentRenderSmokeTests {
    @Test(arguments: [ColorScheme.light, .dark])
    func samplesRender(scheme: ColorScheme) {
        let view = VStack { ButtonSamples(); IdentitySamples(); ChipSamples() }
            .frame(width: 400)
            .environment(\.colorScheme, scheme)
            .dynamicTypeSize(.accessibility3)
        #expect(ImageRenderer(content: view).uiImage != nil)
        #expect(SamplePhoto.image.size == CGSize(width: 120, height: 120))
    }
}
