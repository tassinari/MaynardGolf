//
//  Navigation.swift
//  MaynardUI
//

import SwiftUI
import UIKit

/// The custom bar (DS-NV-01): translucent Chalk @ 92 % with a blur, a leading pill button, a centered
/// caps title and an optional trailing action. Screens add it with `.dsNavigationBar(...)`, which hides
/// the system bar and pins this one to the top safe area.
public struct DSNavigationBar<Leading: View, Trailing: View>: View {
    private let title: Text
    private let leading: Leading
    private let trailing: Trailing

    public init(_ title: Text, @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        ZStack {
            title.dsFont(.section).foregroundStyle(Color.ds.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.8)
                .padding(.horizontal, 96) // keeps the centered title clear of the buttons
                .accessibilityAddTraits(.isHeader)
            HStack {
                leading
                Spacer()
                trailing
            }
        }
        .padding(.horizontal, DSSpacing.m)
        .frame(minHeight: 50)
        .padding(.bottom, DSSpacing.s)
        .background {
            Rectangle().fill(.ultraThinMaterial)
                .overlay(Color.ds.background.opacity(0.92))
                .ignoresSafeArea(edges: .top)
        }
    }
}

public extension View {
    /// Replaces the system bar with `DSNavigationBar` (DS-NV-01).
    func dsNavigationBar<Leading: View, Trailing: View>(_ title: Text, @ViewBuilder leading: () -> Leading,
                                                        @ViewBuilder trailing: () -> Trailing = { EmptyView() }) -> some View {
        let bar = DSNavigationBar(title, leading: leading, trailing: trailing)
        return toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) { bar }
            // Hiding the system bar turns off the edge swipe back; this turns it on again.
            .background(InteractivePopEnabler().frame(width: 0, height: 0).accessibilityHidden(true))
    }

    /// A bottom sheet with a glass background, 44 pt radius and a grabber (DS-NV-02).
    func dsGlassSheet<Content: View>(isPresented: Binding<Bool>, detents: Set<PresentationDetent> = [.medium, .large],
                                     @ViewBuilder content: @escaping () -> Content) -> some View {
        sheet(isPresented: isPresented) {
            content()
                .presentationDetents(detents)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(DSRadius.glassSheet)
                .presentationBackground { Rectangle().fill(.clear).dsGlass(cornerRadius: DSRadius.glassSheet) }
        }
    }

    /// Pins a primary button to the bottom with a Chalk fade behind it, so content scrolls under it
    /// (DS-NV-04).
    func dsStickyBottomCTA<CTA: View>(@ViewBuilder _ cta: () -> CTA) -> some View {
        let button = cta()
        return safeAreaInset(edge: .bottom, spacing: 0) {
            button
                .padding(.horizontal, DSSpacing.gutter)
                .padding(.top, DSSpacing.xxxl)
                .padding(.bottom, DSSpacing.s)
                .background {
                    LinearGradient(stops: [.init(color: Color.ds.background.opacity(0), location: 0),
                                           .init(color: Color.ds.background, location: 0.35)],
                                   startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea(edges: .bottom)
                }
        }
    }
}

/// The content of a full-height Chalk sheet (DS-NV-03): grabber, title and subtitle with a close button,
/// a hairline, then the content. Present it with `.sheet` and `.dsLightSheet()`.
public struct LightSheet<Content: View>: View {
    private let title: Text
    private let subtitle: Text?
    private let closeLabel: Text
    private let onClose: () -> Void
    private let content: Content

    public init(_ title: Text, subtitle: Text? = nil, closeLabel: Text, onClose: @escaping () -> Void,
                @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.closeLabel = closeLabel
        self.onClose = onClose
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: DSSpacing.m) {
                VStack(alignment: .leading, spacing: 2) {
                    title.dsFont(.title).foregroundStyle(Color.ds.textPrimary).accessibilityAddTraits(.isHeader)
                    if let subtitle { subtitle.dsFont(.caption).foregroundStyle(Color.ds.textSecondary) }
                }
                Spacer(minLength: DSSpacing.s)
                CircleIconButton(closeLabel, action: onClose)
                    .accessibilityIdentifier("lightSheet.close")
            }
            .padding(.horizontal, DSSpacing.gutter)
            .padding(.top, DSSpacing.xl)
            .padding(.bottom, DSSpacing.m)
            DSDivider()
            content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Color.ds.background)
    }
}

public extension View {
    /// The presentation of a `LightSheet` (DS-NV-03): full height, 36 pt radius, grabber.
    func dsLightSheet() -> some View {
        presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(DSRadius.lightSheet)
            .presentationBackground(Color.ds.background)
    }
}

/// Keeps the edge swipe back working on screens that hide the system navigation bar (DS-NV-01): UIKit
/// disables `interactivePopGestureRecognizer` when the bar is hidden, so this finds the navigation
/// controller and lets the gesture begin whenever there's a screen to go back to.
struct InteractivePopEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let navigation = navigationController else { return }
            navigation.interactivePopGestureRecognizer?.isEnabled = true
            navigation.interactivePopGestureRecognizer?.delegate = self
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            Self.shouldBegin(stackCount: navigationController?.viewControllers.count ?? 0)
        }

        /// The swipe starts only when there's a screen underneath to go back to.
        nonisolated static func shouldBegin(stackCount: Int) -> Bool { stackCount > 1 }
    }
}
