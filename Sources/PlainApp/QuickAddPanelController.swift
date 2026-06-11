import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class QuickAddPanelController: ObservableObject {
    @Published var inputText = ""
    @Published private(set) var previewText: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var destinationDescription = "No writable todo.txt selected"
    @Published private(set) var canRevealMainWindow = false
    @Published private(set) var detectedPriority: String?

    let autocomplete: AutocompleteEngine

    private let model: PlainShellModel
    private var panel: QuickAddPanel?
    private var isHiding = false
    nonisolated(unsafe) private var hotKeyRef: EventHotKeyRef?
    nonisolated(unsafe) private var eventHandlerRef: EventHandlerRef?
    private let hotKeyID: UInt32 = 1

    var revealMainWindow: () -> Void = {
        NSApp.activate(ignoringOtherApps: true)
    }

    init(model: PlainShellModel) {
        self.model = model
        self.autocomplete = AutocompleteEngine(tagProvider: { [weak model] in
            guard let model else { return ([], []) }
            return (projects: model.projectCounts.map(\.name), contexts: model.contextCounts.map(\.name))
        })
        registerHotKey()
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    func inputTextDidChange() {
        refreshPreview()
        updateDetectedPriority()
        autocomplete.update(for: inputText)
        if errorMessage != nil {
            errorMessage = nil
            canRevealMainWindow = false
        }
    }

    func showPanel() {
        isHiding = false
        model.loadInitialSnapshotIfNeeded()
        inputText = ""
        errorMessage = nil
        previewText = nil
        canRevealMainWindow = false
        detectedPriority = nil
        autocomplete.dismiss()
        autocomplete.isDueDatePickerPresented = false
        ensurePanel()
        refreshPreview()
        destinationDescription = model.quickAddDestinationDescription
        positionPanelAtTop()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hidePanel() {
        guard let panel, !isHiding else { return }
        isHiding = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            panel.alphaValue = 1
            self?.inputText = ""
            self?.errorMessage = nil
            self?.previewText = nil
            self?.canRevealMainWindow = false
            self?.detectedPriority = nil
            self?.autocomplete.dismiss()
            self?.autocomplete.isDueDatePickerPresented = false
        })
    }

    func submit() {
        autocomplete.trackRecentTags(in: inputText)
        do {
            _ = try model.addTaskFromQuickAdd(rawText: inputText)
            hidePanel()
        } catch let error as PlainShellModel.QuickAddError {
            handle(error: error)
        } catch {
            errorMessage = error.localizedDescription
            canRevealMainWindow = false
        }
    }

    func revealMainApp() {
        hidePanel()
        revealMainWindow()
    }

    private func updateDetectedPriority() {
        guard inputText.count >= 4,
              inputText.hasPrefix("("),
              let letter = inputText.dropFirst().first,
              "ABC".contains(letter),
              inputText.dropFirst(2).hasPrefix(") ")
        else {
            detectedPriority = nil
            return
        }
        detectedPriority = String(letter)
    }

    private func handle(error: PlainShellModel.QuickAddError) {
        switch error {
        case .conflict:
            hidePanel()
            revealMainWindow()
        case .noWritableFile:
            errorMessage = error.localizedDescription
            canRevealMainWindow = true
            destinationDescription = model.quickAddDestinationDescription
        case .emptyTask:
            errorMessage = error.localizedDescription
            canRevealMainWindow = false
        }
    }

    private func refreshPreview() {
        previewText = model.previewTextForNewTask(inputText)
        destinationDescription = model.quickAddDestinationDescription
    }

    private func positionPanelAtTop() {
        guard let panel else { return }

        let mouseScreen = NSScreen.screens.first(where: {
            NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
        }) ?? NSScreen.main ?? NSScreen.screens[0]

        let screenFrame = mouseScreen.visibleFrame
        let panelWidth: CGFloat = 520
        let panelX = screenFrame.midX - panelWidth / 2

        let hostingView = panel.contentView as? NSHostingView<QuickAddPanelView>
        let fittingHeight = hostingView?.fittingSize.height ?? 280
        let panelHeight = min(fittingHeight, 500)
        let topPadding: CGFloat = 8
        let finalY = screenFrame.maxY - panelHeight - topPadding

        panel.setFrame(NSRect(x: panelX, y: finalY, width: panelWidth, height: panelHeight), display: true)
    }

    private func ensurePanel() {
        guard panel == nil else {
            updatePanelContent()
            return
        }

        let panel = QuickAddPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 280),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.animationBehavior = .utilityWindow
        panel.onResignKey = { [weak self] in
            self?.hidePanel()
        }
        self.panel = panel
        updatePanelContent()
    }

    private func updatePanelContent() {
        guard let panel else { return }
        let hostingView = NSHostingView(rootView: QuickAddPanelView(controller: self))
        hostingView.sizingOptions = [.minSize, .intrinsicContentSize]
        panel.contentView = hostingView
    }

    private func registerHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData, let event else {
                    return noErr
                }

                let controller = Unmanaged<QuickAddPanelController>.fromOpaque(userData).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr, hotKeyID.id == controller.hotKeyID else {
                    return noErr
                }

                Task { @MainActor in
                    controller.showPanel()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        let carbonHotKeyID = EventHotKeyID(signature: OSType(0x504C4149), id: hotKeyID)
        RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(cmdKey | shiftKey),
            carbonHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
}

private final class QuickAddPanel: NSPanel {
    var onResignKey: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onResignKey?()
    }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}

private struct QuickAddPanelView: View {
    @ObservedObject var controller: QuickAddPanelController
    @FocusState private var isInputFocused: Bool
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var springAnimation: Animation {
        reduceMotion ? .linear(duration: 0) : .spring(response: 0.35, dampingFraction: 0.72)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            header
            inputSection
            autocompleteOverlays
            previewSection
            errorSection
            actionBar
        }
        .padding(Spacing.xl)
        .frame(width: 480)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(PlainTokens.Border.input, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.15), radius: 24, x: 0, y: 12)
        .padding(Spacing.lg)
        .offset(y: appeared ? 0 : -40)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            isInputFocused = true
            withAnimation(springAnimation) {
                appeared = true
            }
        }
        .onChange(of: controller.inputText) { _, _ in
            controller.inputTextDidChange()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .lastTextBaseline) {
                Text("Quick Add")
                    .font(PlainType.panelTitle)
                    .foregroundStyle(PlainTokens.TextToken.primary)

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Text("⌘ · ⇧ · SPACE")
                        .font(PlainType.mastheadDate)
                        .tracking(Tracking.mastheadDate)
                        .foregroundStyle(PlainTokens.TextToken.muted)
                    Text(controller.destinationDescription)
                        .font(PlainType.mastheadMeta)
                        .foregroundStyle(PlainTokens.TextToken.secondary)
                }
            }

            VStack(spacing: 2) {
                Rectangle()
                    .fill(PlainTokens.Border.section)
                    .frame(height: 1.5)
                Rectangle()
                    .fill(PlainTokens.Border.section)
                    .frame(height: 0.5)
            }
        }
    }

    private var inputSection: some View {
        HStack(spacing: Spacing.md) {
            if let priority = controller.detectedPriority {
                Text(priority)
                    .font(PlainType.priorityMarginal)
                    .foregroundStyle(priorityColor(priority))
                    .frame(width: 28, height: 28)
                    .background(priorityColor(priority).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                    .accessibilityLabel("Priority \(priority)")
            }

            TextField("Capture a task...", text: $controller.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(PlainType.taskBody)
                .lineLimit(1...6)
                .focused($isInputFocused)
                .onSubmit {
                    if controller.autocomplete.hasSuggestions {
                        controller.autocomplete.acceptSuggestion(in: &controller.inputText)
                    } else {
                        controller.submit()
                    }
                }
                .onKeyPress(.upArrow) {
                    guard controller.autocomplete.hasSuggestions else { return .ignored }
                    controller.autocomplete.moveUp()
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    guard controller.autocomplete.hasSuggestions else { return .ignored }
                    controller.autocomplete.moveDown()
                    return .handled
                }
                .onKeyPress(.tab) {
                    guard controller.autocomplete.hasSuggestions else { return .ignored }
                    controller.autocomplete.acceptSuggestion(in: &controller.inputText)
                    return .handled
                }
                .onKeyPress(.escape) {
                    if controller.autocomplete.isDueDatePickerPresented {
                        controller.autocomplete.isDueDatePickerPresented = false
                        return .handled
                    }
                    guard controller.autocomplete.hasSuggestions else { return .ignored }
                    controller.autocomplete.dismiss()
                    return .handled
                }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: controller.detectedPriority)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.lg)
        .background(PlainTokens.Surface.input, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(isInputFocused ? PlainTokens.Border.inputFocused : PlainTokens.Border.input, lineWidth: isInputFocused ? 1.5 : 1)
        )
        .shadow(
            color: isInputFocused ? PlainTokens.accent.opacity(0.18) : .clear,
            radius: 8,
            x: 0,
            y: 2
        )
    }

    @ViewBuilder
    private var autocompleteOverlays: some View {
        if controller.autocomplete.hasSuggestions {
            AutocompleteSuggestionPopup(engine: controller.autocomplete) { _ in
                controller.autocomplete.acceptSuggestion(in: &controller.inputText)
            }
        }

        if controller.autocomplete.isDueDatePickerPresented {
            DueDatePickerPopup(engine: controller.autocomplete) { date in
                controller.autocomplete.insertDueDate(date, into: &controller.inputText)
            }
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        if let previewText = controller.previewText {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("PREVIEW")
                    .font(PlainType.sidebarSection)
                    .tracking(Tracking.sidebarSection)
                    .foregroundStyle(PlainTokens.TextToken.muted)
                Text(previewText)
                    .font(PlainType.scratchPad)
                    .foregroundStyle(PlainTokens.TextToken.secondary)
                    .textSelection(.enabled)
            }
            .padding(Spacing.lg)
            .background(PlainTokens.Surface.input, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = controller.errorMessage {
            HStack(spacing: Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(PlainTokens.Status.conflict)
                Text(errorMessage)
                    .font(PlainType.taskMeta)
                    .foregroundStyle(PlainTokens.TextToken.secondary)
                Spacer()
            }
        }
    }

    private var actionBar: some View {
        HStack {
            Button("Cancel") {
                controller.hidePanel()
            }
            .keyboardShortcut(.cancelAction)

            if controller.canRevealMainWindow {
                Button("Open Main Window") {
                    controller.revealMainApp()
                }
            }

            Spacer()

            Button("Add Task") {
                controller.submit()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(controller.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "A": return PlainTokens.Priority.a
        case "B": return PlainTokens.Priority.b
        case "C": return PlainTokens.Priority.c
        default: return PlainTokens.Priority.low
        }
    }
}

struct MainWindowRegistrationView: View {
    @ObservedObject var controller: QuickAddPanelController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        WindowAccessor { window in
            window.setFrameAutosaveName("PlainMainWindow")
            window.titleVisibility = .hidden
        }
        .frame(width: 0, height: 0)
        .onAppear {
            controller.revealMainWindow = {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
        }
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onWindow(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
