//
//  Navigation.swift
//  MaynardUI
//

import SwiftUI
import UIKit

/// The custom bar (DS-NV-01): translucent Chalk @ 92 % with a blur, a leading pill button, a caps title and
/// an optional trailing action. Screens add it with `.dsNavigationBar(...)`, which hides the system bar and
/// pins this one to the top safe area. The title is centered by default, or leading next to the button
/// (the Player card, PC-TOP-02); the background is always there, or only once content scrolls under the bar
/// (`.scrollEdge`, with a hairline, PC-TOP-04).
public struct DSNavigationBar<Leading: View, Trailing: View>: View {
    private let title: Text
    private let titleAlignment: DSBarTitleAlignment
    private let background: DSBarBackground
    private let showsTitle: Bool
    private let leading: Leading
    private let trailing: Trailing

    public init(_ title: Text, titleAlignment: DSBarTitleAlignment = .center, background: DSBarBackground = .always,
                showsTitle: Bool = true,
                @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.titleAlignment = titleAlignment
        self.background = background
        self.showsTitle = showsTitle
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        Group {
            switch titleAlignment {
            case .center:
                ZStack {
                    titleText.padding(.horizontal, 96) // keeps the centered title clear of the buttons
                    HStack {
                        leading
                        Spacer()
                        trailing
                    }
                }
            case .leading:
                HStack(spacing: DSSpacing.m) {
                    leading
                    titleText
                    Spacer(minLength: DSSpacing.s)
                    trailing
                }
            }
        }
        .padding(.horizontal, DSSpacing.m)
        .frame(minHeight: 50)
        .padding(.bottom, DSSpacing.s)
        .background {
            if background.showsBackground {
                Rectangle().fill(.ultraThinMaterial)
                    .overlay(Color.ds.background.opacity(background.tintOpacity))
                    .overlay(alignment: .bottom) { if background.showsHairline { DSDivider() } }
                    .ignoresSafeArea(edges: .top)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: background)
    }

    @ViewBuilder private var titleText: some View {
        if showsTitle {
            Group {
                if background.isOverPhoto { title.dsGlassText() }
                else { title }
            }
            .dsFont(.section)
            .foregroundStyle(background.isOverPhoto ? Color.ds.chalk50 : Color.ds.textPrimary)
            .lineLimit(1).minimumScaleFactor(0.8)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("navigation.title")
        }
    }
}

/// Where `DSNavigationBar`'s title sits (DS-NV-01).
public enum DSBarTitleAlignment: Sendable, Equatable {
    case center
    /// Next to the leading button (the Player card, PC-TOP-02).
    case leading
}

/// When `DSNavigationBar` draws its background (DS-NV-01, PC-TOP-04).
public enum DSBarBackground: Sendable, Equatable {
    /// Always (the default).
    case always
    /// Transparent at the top of the scroll; the blur and a bottom hairline once content is under the bar.
    case scrollEdge(isScrolled: Bool)
    /// Home's pinned photo bar: clear at the top, then material over the photo without the opaque Chalk tint.
    case photo(isScrolled: Bool)

    /// Photo bars use white, shadowed title text on their supplied photo background (HOME-HDR-05).
    var isOverPhoto: Bool {
        if case .photo = self { return true }
        return false
    }

    /// The standard Chalk wash must not obscure the photo behind Home's translucent bar.
    var tintOpacity: Double { isOverPhoto ? 0 : 0.92 }

    /// Whether the blur shows: always, or once scrolled for the scroll-edge and photo styles.
    public var showsBackground: Bool {
        switch self {
        case .always: true
        case .scrollEdge(let isScrolled), .photo(let isScrolled): isScrolled
        }
    }

    /// The bottom hairline shows on scrolled photo and scroll-edge bars (HOME-HDR-02, PC-TOP-04).
    public var showsHairline: Bool { self == .scrollEdge(isScrolled: true) || self == .photo(isScrolled: true) }

    /// Whether content has scrolled under the bar: the offset past the top inset (the bar itself), with
    /// half a point of slack for rounding. Feed it from `onScrollGeometryChange`.
    public static func isScrolled(offsetY: CGFloat, topInset: CGFloat) -> Bool {
        offsetY + topInset > 0.5
    }
}

public extension View {
    /// Replaces the system bar with `DSNavigationBar` (DS-NV-01).
    func dsNavigationBar<Leading: View, Trailing: View>(_ title: Text,
                                                        titleAlignment: DSBarTitleAlignment = .center,
                                                        background: DSBarBackground = .always,
                                                        showsTitle: Bool = true,
                                                        @ViewBuilder leading: () -> Leading,
                                                        @ViewBuilder trailing: () -> Trailing = { EmptyView() }) -> some View {
        let bar = DSNavigationBar(title, titleAlignment: titleAlignment, background: background, showsTitle: showsTitle, leading: leading, trailing: trailing)
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
        /// UIKit's own delegate, put back once this screen has gone. The gesture's delegate is weak, so
        /// without this it would become nil and nothing would stop a swipe on the root screen or during
        /// a transition, which freezes the navigation stack. It's restored in `viewDidDisappear`, not
        /// `viewWillDisappear`: an interactive pop calls the latter when the swipe begins, and a cancelled
        /// swipe would then leave this screen without its swipe back.
        private weak var previousDelegate: UIGestureRecognizerDelegate?
        private weak var gesture: UIGestureRecognizer?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let recognizer = navigationController?.interactivePopGestureRecognizer else { return }
            if recognizer.delegate !== self { previousDelegate = recognizer.delegate }
            recognizer.isEnabled = true
            recognizer.delegate = self
            gesture = recognizer
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            if let gesture, gesture.delegate === self { gesture.delegate = previousDelegate }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            Self.shouldBegin(stackCount: navigationController?.viewControllers.count ?? 0,
                             isTransitioning: navigationController?.transitionCoordinator != nil)
        }

        /// The swipe starts only when there's a screen underneath to go back to and no push or pop is
        /// animating.
        nonisolated static func shouldBegin(stackCount: Int, isTransitioning: Bool) -> Bool {
            stackCount > 1 && !isTransitioning
        }
    }
}
