//
//  Containers.swift
//  MaynardUI
//

import SwiftUI
import UIKit

/// A white card on a soft shadow, with no border (DS-CN-01, DS-SH-04). Rows inside separate themselves
/// with `DSDivider`.
public struct CardContainer<Content: View>: View {
    private let radius: CGFloat
    private let content: Content

    public init(radius: CGFloat = DSRadius.listCard, @ViewBuilder content: () -> Content) {
        self.radius = radius
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(.horizontal, DSSpacing.ml)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color.ds.surfaceCard))
            .dsCardElevation(cornerRadius: radius)
    }
}

/// A white card on a soft shadow with even padding on every side (DS-CN-16): the Player card's profile,
/// histogram and handicap cards (PC-HDR-01, PC-HI-01, PC-HC-01). `CardContainer` is for rows that run to
/// the card's top and bottom edges; this one is for content that sits inside a margin.
public struct ContentCard<Content: View>: View {
    private let padding: CGFloat
    private let spacing: CGFloat
    private let content: Content

    public init(padding: CGFloat = DSSpacing.l, spacing: CGFloat = DSSpacing.m, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.summaryCard, style: .continuous)
        VStack(alignment: .leading, spacing: spacing) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(shape.fill(Color.ds.surfaceCard))
            .dsCardElevation(cornerRadius: DSRadius.summaryCard)
    }
}

/// The Hairline between rows in a card (DS-CN-01).
public struct DSDivider: View {
    public init() {}

    public var body: some View {
        Rectangle().fill(Color.ds.divider).frame(height: 1).accessibilityHidden(true)
    }
}

/// A caps section title with an optional "· N OF M" count and a trailing action (DS-CN-02).
public struct SectionHeader<Trailing: View>: View {
    private let title: Text
    private let count: (Int, Int)?
    private let trailing: Trailing

    public init(_ title: Text, count: (Int, Int)? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.count = count
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DSSpacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: DSSpacing.xs) {
                title.dsFont(.section).foregroundStyle(Color.ds.textPrimary)
                if let count {
                    Text(verbatim: DisplayFormatting.countSubtitle(count.0, of: count.1))
                        .dsFont(.label).foregroundStyle(Color.ds.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: DSSpacing.s)
            trailing
        }
        .padding(.horizontal, DSSpacing.xxs)
    }
}

public extension SectionHeader where Trailing == EmptyView {
    init(_ title: Text, count: (Int, Int)? = nil) {
        self.init(title, count: count) { EmptyView() }
    }
}

/// A player's row: avatar, name, optional subtitle, trailing HCP and an optional chevron or checkbox
/// (DS-CN-03). Height 62–64.
public struct PlayerRow: View {
    public enum Accessory: Sendable, Equatable {
        case none, chevron
        case checkbox(isOn: Bool)
    }

    private let name: String
    private let color: PlayerPalette
    private let photo: UIImage?
    private let subtitle: String?
    private let handicapIndex: Double?
    private let showsHandicap: Bool
    private let accessory: Accessory
    @ScaledMetric(relativeTo: .body) private var chevronSize: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var checkboxSize: CGFloat = 26

    public init(name: String, color: PlayerPalette, photo: UIImage? = nil, subtitle: String? = nil,
                handicapIndex: Double? = nil, showsHandicap: Bool = true, accessory: Accessory = .none) {
        self.name = name
        self.color = color
        self.photo = photo
        self.subtitle = subtitle
        self.handicapIndex = handicapIndex
        self.showsHandicap = showsHandicap
        self.accessory = accessory
    }

    public var body: some View {
        HStack(spacing: DSSpacing.m) {
            PlayerAvatar(name: name, color: color, photo: photo, size: .s).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name).dsFont(.bodyEmphasized).foregroundStyle(Color.ds.textPrimary)
                if let subtitle {
                    Text(verbatim: subtitle).dsFont(.caption).foregroundStyle(Color.ds.textSecondary)
                }
            }
            Spacer(minLength: DSSpacing.s)
            if showsHandicap {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: Self.handicapLabel).dsFont(.labelSmall).foregroundStyle(Color.ds.textSecondary)
                    Text(verbatim: DisplayFormatting.handicapIndex(handicapIndex)).dsFont(.bodyEmphasized).dsNumeric()
                        .foregroundStyle(Color.ds.textPrimary)
                }
            }
            switch accessory {
            case .none: EmptyView()
            case .chevron:
                Image(systemName: "chevron.right").font(.system(size: chevronSize, weight: .semibold))
                    .foregroundStyle(Color.ds.textTertiary).accessibilityHidden(true)
            case .checkbox(let isOn):
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: checkboxSize))
                    .foregroundStyle(isOn ? Color.ds.primaryAction : Color.ds.toggleOff)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 62)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(Self.isSelected(accessory) ? .isSelected : [])
    }

    /// "HCP" over the index.
    public nonisolated static var handicapLabel: String {
        String(localized: "HCP", bundle: Bundle.maynardUI, comment: "Short label over a player's handicap index, shown in caps.")
    }

    nonisolated static func isSelected(_ accessory: Accessory) -> Bool {
        if case .checkbox(isOn: true) = accessory { return true }
        return false
    }
}

/// A round's row: date block, course name with meta, a wrapping row of score chips, chevron (DS-CN-04).
/// No winner, weather or to-par. Hide its disclosure for read-only Trash rows (#224).
public struct RoundRow: View {
    /// One player's chip on the row.
    public struct Score: Identifiable, Sendable {
        public let id: UUID
        public let name: String
        public let color: PlayerPalette
        public let score: Int

        /// `id` must be stable across renders (the player's id), so the chips keep their identity.
        public init(id: UUID, name: String, color: PlayerPalette, score: Int) {
            self.id = id
            self.name = name
            self.color = color
            self.score = score
        }
    }

    private let date: Date
    private let dateStyle: DisplayFormatting.DateBlockStyle
    private let courseName: String
    private let meta: String
    private let scores: [Score]
    private let isInProgress: Bool
    private let showsChevron: Bool
    private let photos: [UUID: UIImage]
    @ScaledMetric(relativeTo: .body) private var chevronSize: CGFloat = 14

    public init(date: Date, dateStyle: DisplayFormatting.DateBlockStyle, courseName: String, meta: String, scores: [Score],
                isInProgress: Bool = false, photos: [UUID: UIImage] = [:], showsChevron: Bool = true) {
        self.date = date
        self.dateStyle = dateStyle
        self.courseName = courseName
        self.meta = meta
        self.scores = scores
        self.isInProgress = isInProgress
        self.showsChevron = showsChevron
        self.photos = photos
    }

    public var body: some View {
        let block = DisplayFormatting.dateBlock(date, style: dateStyle)
        HStack(alignment: .top, spacing: DSSpacing.m) {
            VStack(spacing: 0) {
                Text(verbatim: block.label).dsFont(.labelSmall).foregroundStyle(Color.ds.textSecondary)
                Text(verbatim: block.day).dsFont(.dateDay).foregroundStyle(Color.ds.textPrimary)
            }
            .frame(minWidth: 40)
            VStack(alignment: .leading, spacing: DSSpacing.s) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) { titleText; Spacer(minLength: DSSpacing.s); metaText }
                    VStack(alignment: .leading, spacing: 2) { titleText; metaText }
                }
                FlowLayout(spacing: DSSpacing.xs) {
                    ForEach(scores) { PlayerScoreChip(name: $0.name, color: $0.color, photo: photos[$0.id], score: $0.score) }
                }
            }
            if showsChevron {
                Image(systemName: "chevron.right").font(.system(size: chevronSize, weight: .semibold))
                    .foregroundStyle(Color.ds.textTertiary).accessibilityHidden(true)
                    .padding(.top, DSSpacing.xxs)
            }
        }
        .padding(.vertical, DSSpacing.ml)
        .frame(minHeight: 66, alignment: .top)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var titleText: some View {
        Text(verbatim: courseName).dsFont(.bodyEmphasized).foregroundStyle(Color.ds.textPrimary)
    }

    @ViewBuilder private var metaText: some View {
        if isInProgress { StatusPill(.inProgress) }
        else { Text(verbatim: meta).dsFont(.caption).foregroundStyle(Color.ds.textSecondary) }
    }
}

/// A `surfaceRaised` (Gray 100) tile with a big number and a caption (DS-CN-06); `content` replaces the number in the
/// variant that hosts a compact segmented control.
public struct StatTile<Content: View>: View {
    private let caption: Text
    private let content: Content
    private let readsAsOne: Bool

    /// A tile hosting a control: its parts stay separate, so VoiceOver can operate the control.
    public init(caption: Text, @ViewBuilder content: () -> Content) {
        self.caption = caption
        self.content = content()
        self.readsAsOne = false
    }

    init(caption: Text, readsAsOne: Bool, content: Content) {
        self.caption = caption
        self.content = content
        self.readsAsOne = readsAsOne
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
            content
            caption.dsFont(.caption).foregroundStyle(Color.ds.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.m)
        .background(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous).fill(Color.ds.surfaceRaised))
        .accessibilityElement(children: readsAsOne ? .combine : .contain)
    }
}

/// The big number on a `StatTile` (SF Pro 700 28, tabular).
public struct StatValue: View {
    let value: String

    public var body: some View {
        Text(verbatim: value).dsFont(.title).dsNumeric().foregroundStyle(Color.ds.textPrimary)
    }
}

public extension StatTile where Content == StatValue {
    /// A tile with a big number and a caption, read as one element ("84.2, Avg score").
    init(value: String, caption: Text) {
        self.init(caption: caption, readsAsOne: true, content: StatValue(value: value))
    }
}

/// The empty state, on the system's `ContentUnavailableView` (DS-CN-07).
public struct EmptyStateView<Actions: View>: View {
    private let title: Text
    private let systemImage: String
    private let message: Text
    private let actions: Actions

    public init(_ title: Text, systemImage: String, message: Text, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
        self.actions = actions()
    }

    public var body: some View {
        ContentUnavailableView {
            Label { title.foregroundStyle(Color.ds.textPrimary) } icon: {
                Image(systemName: systemImage).foregroundStyle(Color.ds.textSecondary)
            }
        } description: {
            message.foregroundStyle(Color.ds.textSecondary)
        } actions: {
            actions
        }
    }
}

public extension EmptyStateView where Actions == EmptyView {
    init(_ title: Text, systemImage: String, message: Text) {
        self.init(title, systemImage: systemImage, message: message) { EmptyView() }
    }
}

/// Lays children out in rows that wrap (the score chips on `RoundRow`).
public struct FlowLayout: Layout {
    public var spacing: CGFloat

    public init(spacing: CGFloat = DSSpacing.xs) { self.spacing = spacing }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = Self.rows(for: subviews.map { $0.sizeThatFits(.unspecified) }, width: proposal.width ?? .infinity, spacing: spacing)
        return rows.size
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = Self.rows(for: subviews.map { $0.sizeThatFits(.unspecified) }, width: bounds.width, spacing: spacing)
        for (index, origin) in rows.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    /// Where each item goes, wrapping when the next one wouldn't fit, and the total size. Pure, so it's tested.
    public nonisolated static func rows(for sizes: [CGSize], width: CGFloat, spacing: CGFloat) -> (origins: [CGPoint], size: CGSize) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for size in sizes {
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (origins, CGSize(width: widest, height: sizes.isEmpty ? 0 : y + rowHeight))
    }
}
