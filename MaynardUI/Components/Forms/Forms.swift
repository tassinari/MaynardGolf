//
//  Forms.swift
//  MaynardUI
//

import SwiftUI

/// A settings row: label, optional hint and a trailing accessory (DS-CN-08).
public struct SettingsRow<Accessory: View>: View {
    private let label: Text
    private let hint: Text?
    private let accessory: Accessory

    public init(_ label: Text, hint: Text? = nil, @ViewBuilder accessory: () -> Accessory) {
        self.label = label
        self.hint = hint
        self.accessory = accessory()
    }

    public var body: some View {
        HStack(spacing: DSSpacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                label.dsFont(.body).foregroundStyle(Color.ds.textPrimary)
                if let hint { hint.dsFont(.caption).foregroundStyle(Color.ds.textSecondary) }
            }
            Spacer(minLength: DSSpacing.s)
            accessory
        }
        .frame(minHeight: DSTouchTarget.minimum)
        .padding(.vertical, DSSpacing.s)
        .accessibilityElement(children: .combine)
    }
}

/// The standard `Toggle` with the design's tracks: Rough 600 on, Chalk 300 off (DS-CN-09).
public struct DSToggleStyle: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Toggle(configuration).toggleStyle(.switch).tint(Color.ds.toggleOn)
    }
}

public extension ToggleStyle where Self == DSToggleStyle {
    /// The design's switch (DS-CN-09).
    static var ds: Self { DSToggleStyle() }
}

/// A segmented control in the design's colors (DS-CN-10): a Chalk 200 track and a white selected
/// segment. Drawn custom because the system segmented picker can't take these colors; VoiceOver still
/// gets a standard picker through `accessibilityRepresentation`.
public struct DSSegmented<Value: Hashable>: View {
    private let label: Text
    private let options: [(value: Value, title: Text)]
    @Binding private var selection: Value
    private let compact: Bool

    public init(_ label: Text, selection: Binding<Value>, options: [(value: Value, title: Text)], compact: Bool = false) {
        self.label = label
        _selection = selection
        self.options = options
        self.compact = compact
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let isSelected = option.value == selection
                Button { selection = option.value } label: {
                    option.title
                        .dsFont(compact ? .caption : .bodyEmphasized)
                        .foregroundStyle(isSelected ? Color.ds.textPrimary : Color.ds.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: compact ? 32 : 40)
                        .background {
                            if isSelected {
                                Capsule().fill(Color.ds.segmentSelected).shadow(color: Color.ds.canopy950.opacity(0.12), radius: 2, y: 1)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().fill(compact ? Color.ds.teeGreen100 : Color.ds.segmentTrack))
        .accessibilityRepresentation {
            Picker(selection: $selection) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in option.title.tag(option.value) }
            } label: { label }
            .pickerStyle(.segmented)
        }
    }
}

/// Grouped text fields with caps labels above each input and Moss 400 placeholders (DS-CN-11).
public struct FormFieldCard: View {
    /// One field.
    public struct Field: Identifiable {
        public let id: String
        public let label: Text
        public let placeholder: String
        public let text: Binding<String>

        public init(id: String, label: Text, placeholder: String, text: Binding<String>) {
            self.id = id
            self.label = label
            self.placeholder = placeholder
            self.text = text
        }
    }

    private let fields: [Field]

    public init(fields: [Field]) { self.fields = fields }

    public var body: some View {
        CardContainer(radius: DSRadius.card) {
            ForEach(Array(fields.enumerated()), id: \.element.id) { index, field in
                if index > 0 { DSDivider() }
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    field.label.dsFont(.labelSmall).foregroundStyle(Color.ds.textSecondary)
                    TextField(text: field.text) { Text(verbatim: field.placeholder).foregroundStyle(Color.ds.textTertiary) }
                        .dsFont(.body)
                        .foregroundStyle(Color.ds.textPrimary)
                        .accessibilityIdentifier("field.\(field.id)")
                }
                .padding(.vertical, DSSpacing.m)
            }
        }
    }
}

/// A card that can be selected, with a 2 pt Lake inner stroke when it is (DS-CN-12); used by `TeeCard`.
public struct SelectableCard<Content: View>: View {
    private let isSelected: Bool
    private let content: Content

    public init(isSelected: Bool, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.content = content()
    }

    public var body: some View {
        content
            .padding(DSSpacing.ml)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous).fill(Color.ds.surfaceCard))
            .overlay(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
                .strokeBorder(isSelected ? Color.ds.primaryAction : Color.ds.cardBorder, lineWidth: isSelected ? 2 : 1))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
