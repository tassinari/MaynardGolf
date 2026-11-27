//
//  Forms.swift
//  MaynardUI
//

import SwiftUI
import UIKit

/// A settings row: label, optional hint and a trailing accessory (DS-CN-08). The parts stay separate
/// accessibility elements, so VoiceOver reads the label and can operate the toggle or picker.
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
        .accessibilityElement(children: .contain)
    }
}

/// A search field: magnifier and placeholder in `textSecondary`, a clear button while there's text (DS-CN-15). Used
/// in screens with `dsNavigationBar`, which hides the system bar `.searchable` would draw into.
public struct DSSearchField: View {
    private let prompt: Text
    @Binding private var text: String
    private let identifier: String?

    public init(_ prompt: Text, text: Binding<String>, identifier: String? = nil) {
        self.prompt = prompt
        _text = text
        self.identifier = identifier
    }

    public var body: some View {
        HStack(spacing: DSSpacing.s) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.ds.textSecondary).accessibilityHidden(true)
            TextField(text: $text, prompt: prompt.foregroundStyle(Color.ds.textSecondary)) { prompt }
                .dsFont(.body)
                .foregroundStyle(Color.ds.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier(identifier ?? "")
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.ds.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: String(localized: "Clear search", bundle: Bundle.maynardUI, comment: "Clears the search field.")))
            }
        }
        .padding(.horizontal, DSSpacing.m)
        .frame(minHeight: DSTouchTarget.minimum)
        .background(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous).fill(Color.ds.surfaceRaised))
    }
}

/// The standard `Toggle` with the design's Green 400 on-track (DS-CN-09). The off track stays the system
/// grey: SwiftUI can't color it, and a custom switch isn't worth losing the system control's behavior.
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

/// A segmented control in the design's colors (DS-CN-10): a Field Fill track and a white selected
/// segment. Drawn custom because the system segmented picker can't take these colors; VoiceOver still
/// gets a standard picker through `accessibilityRepresentation`.
public struct DSSegmented<Value: Hashable>: View {
    private let label: Text
    private let options: [(value: Value, title: Text)]
    @Binding private var selection: Value
    private let compact: Bool
    private let identifier: String?

    /// `identifier` tags the control and each segment (`"\(identifier).\(index)"`) for UI tests.
    public init(_ label: Text, selection: Binding<Value>, options: [(value: Value, title: Text)], compact: Bool = false,
                identifier: String? = nil) {
        self.label = label
        _selection = selection
        self.options = options
        self.compact = compact
        self.identifier = identifier
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
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
                                Capsule().fill(Color.ds.segmentSelected).shadow(color: Color.ds.controlShadow, radius: 2, y: 1)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(identifier.map { "\($0).\(index)" } ?? "")
            }
        }
        .padding(2)
        .background(Capsule().fill(compact ? Color.ds.segmentTrack : Color.ds.segmentTrack))
        .accessibilityRepresentation {
            Picker(selection: $selection) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    option.title.tag(option.value).accessibilityIdentifier(identifier.map { "\($0).\(index)" } ?? "")
                }
            } label: { label }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(identifier ?? "")
        }
    }
}

/// Grouped text fields with caps labels above each input and `textSecondary` placeholders (DS-CN-11). Return moves
/// to the next field; the last field's Return ends editing.
public struct FormFieldCard: View {
    /// One field. `id` is also its accessibility identifier.
    public struct Field: Identifiable {
        public let id: String
        public let label: Text
        public let placeholder: String
        public let text: Binding<String>
        /// The keyboard: `.default`, or `.decimalPad` for numbers.
        public var keyboard: UIKeyboardType
        public var contentType: UITextContentType?
        public var capitalization: TextInputAutocapitalization
        /// An inline error under the input (`underPar`), or nil.
        public var error: Text?

        public init(id: String, label: Text, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default,
                    contentType: UITextContentType? = nil, capitalization: TextInputAutocapitalization = .sentences,
                    error: Text? = nil) {
            self.id = id
            self.label = label
            self.placeholder = placeholder
            self.text = text
            self.keyboard = keyboard
            self.contentType = contentType
            self.capitalization = capitalization
            self.error = error
        }
    }

    private let fields: [Field]
    @FocusState private var focused: String?

    public init(fields: [Field]) { self.fields = fields }

    public var body: some View {
        CardContainer(radius: DSRadius.card) {
            ForEach(Array(fields.enumerated()), id: \.element.id) { index, field in
                if index > 0 { DSDivider() }
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    field.label.dsFont(.labelSmall).foregroundStyle(Color.ds.textSecondary)
                    TextField(text: field.text) { Text(verbatim: field.placeholder).foregroundStyle(Color.ds.textSecondary) }
                        .dsFont(.body)
                        .foregroundStyle(Color.ds.textPrimary)
                        .keyboardType(field.keyboard)
                        .textContentType(field.contentType)
                        .textInputAutocapitalization(field.capitalization)
                        .autocorrectionDisabled()
                        .focused($focused, equals: field.id)
                        .submitLabel(index < fields.count - 1 ? .next : .done)
                        .onSubmit { focused = Self.nextField(after: field.id, in: fields.map(\.id)) }
                        .accessibilityIdentifier(field.id)
                    if let error = field.error {
                        error.dsFont(.caption).foregroundStyle(Color.ds.underPar)
                            .accessibilityIdentifier("\(field.id).error")
                    }
                }
                .padding(.vertical, DSSpacing.m)
            }
        }
    }

    /// The field Return moves to: the next one, or none after the last.
    nonisolated static func nextField(after id: String, in ids: [String]) -> String? {
        guard let index = ids.firstIndex(of: id), index + 1 < ids.count else { return nil }
        return ids[index + 1]
    }
}

/// The five player colors as 44 pt swatches, one selected (AP-CL-01, 02): the selected swatch has a 3 pt
/// white ring inside a 2 pt `textPrimary` ring. Each swatch is labeled with the color's name, and identified
/// `"\(identifierPrefix).\(color)"`.
public struct ColorSwatchPicker: View {
    @Binding private var selection: PlayerPalette
    private let identifierPrefix: String

    public init(selection: Binding<PlayerPalette>, identifierPrefix: String = "color") {
        _selection = selection
        self.identifierPrefix = identifierPrefix
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(PlayerPalette.allCases, id: \.self) { color in
                Button { selection = color } label: {
                    Circle().fill(color.background)
                        .frame(width: DSTouchTarget.minimum, height: DSTouchTarget.minimum)
                        .overlay {
                            if color == selection {
                                Circle().strokeBorder(Color.ds.textPrimary, lineWidth: 2)
                                    .overlay(Circle().inset(by: 2).strokeBorder(Color.ds.swatchRing, lineWidth: 3))
                            }
                        }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(Text(verbatim: color.title))
                .accessibilityAddTraits(color == selection ? .isSelected : [])
                .accessibilityIdentifier("\(identifierPrefix).\(color.rawValue)")
            }
        }
    }
}

/// A card that can be selected, with a 2 pt Blue inner stroke when it is (DS-CN-12); used by `TeeCard`.
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
            .dsCardElevation(cornerRadius: DSRadius.card)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous).strokeBorder(Color.ds.emphasis, lineWidth: 2)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
