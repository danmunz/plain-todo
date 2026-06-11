import SwiftUI

struct AutocompleteSuggestionPopup: View {
    @ObservedObject var engine: AutocompleteEngine
    let onAccept: (String) -> Void

    var body: some View {
        if engine.hasSuggestions {
            let prefix = engine.activePrefix.map(String.init) ?? ""
            let syntaxColor = engine.activePrefix == "+" ? PlainTokens.Syntax.project : PlainTokens.Syntax.context
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(engine.suggestions.enumerated()), id: \.offset) { index, suggestion in
                    Button {
                        onAccept(suggestion)
                    } label: {
                        HStack {
                            Text("\(prefix)\(suggestion)")
                                .font(PlainType.taskBody)
                                .foregroundStyle(syntaxColor)
                            Spacer()
                            if index < 3 && engine.isRecentTag(suggestion) {
                                Text("recent")
                                    .font(PlainType.taskMeta)
                                    .foregroundStyle(PlainTokens.TextToken.muted)
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .background(index == engine.selectedIndex ? PlainTokens.Surface.hover : Color.clear)
                    }
                    .buttonStyle(.plain)
                    if index < engine.suggestions.count - 1 {
                        Divider()
                    }
                }
            }
            .background(PlainTokens.Surface.input)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(PlainTokens.Border.input, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
            .frame(maxWidth: 260)
        }
    }
}

struct DueDatePickerPopup: View {
    @ObservedObject var engine: AutocompleteEngine
    let onInsert: (Date) -> Void

    var body: some View {
        if engine.isDueDatePickerPresented {
            VStack(spacing: 0) {
                HStack {
                    Text("Due Date")
                        .font(PlainType.sidebarLabel)
                        .foregroundStyle(PlainTokens.TextToken.primary)
                    Spacer()
                    Button {
                        engine.isDueDatePickerPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(PlainTokens.TextToken.muted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.sm)

                DatePicker(
                    "Due date",
                    selection: $engine.dueDatePickerValue,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal, Spacing.sm)

                Divider()
                    .padding(.horizontal, Spacing.lg)

                HStack(spacing: Spacing.md) {
                    Button("Today") {
                        onInsert(Date())
                    }
                    .buttonStyle(.plain)
                    .font(PlainType.taskMeta)
                    .foregroundStyle(PlainTokens.Syntax.context)

                    Button("Tomorrow") {
                        onInsert(Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
                    }
                    .buttonStyle(.plain)
                    .font(PlainType.taskMeta)
                    .foregroundStyle(PlainTokens.Syntax.context)

                    Spacer()

                    Button("Set Date") {
                        onInsert(engine.dueDatePickerValue)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(PlainTokens.Border.input, lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
            .frame(width: 280)
        }
    }
}
