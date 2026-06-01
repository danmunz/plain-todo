import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class QuickAddPanelController: ObservableObject {
    @Published var inputText = "" {
        didSet {
            refreshPreview()
            if errorMessage != nil {
                errorMessage = nil
                canRevealMainWindow = false
            }
        }
    }
    @Published private(set) var previewText: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var destinationDescription = "No writable todo.txt selected"
    @Published private(set) var canRevealMainWindow = false

    private let model: PlainShellModel
    private var panel: QuickAddPanel?
    nonisolated(unsafe) private var hotKeyRef: EventHotKeyRef?
    nonisolated(unsafe) private var eventHandlerRef: EventHandlerRef?
    private let hotKeyID: UInt32 = 1

    var revealMainWindow: () -> Void = {
        NSApp.activate(ignoringOtherApps: true)
    }

    init(model: PlainShellModel) {
        self.model = model
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

    func showPanel() {
        model.loadInitialSnapshotIfNeeded()
        inputText = ""
        errorMessage = nil
        previewText = nil
        canRevealMainWindow = false
        ensurePanel()
        refreshPreview()
        destinationDescription = model.quickAddDestinationDescription
        panel?.center()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hidePanel() {
        panel?.orderOut(nil)
        inputText = ""
        errorMessage = nil
        previewText = nil
        canRevealMainWindow = false
    }

    func submit() {
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

    private func ensurePanel() {
        guard panel == nil else {
            updatePanelContent()
            return
        }

        let panel = QuickAddPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 240),
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
        self.panel = panel
        updatePanelContent()
    }

    private func updatePanelContent() {
        guard let panel else {
            return
        }

        panel.contentView = NSHostingView(rootView: QuickAddPanelView(controller: self))
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
            UInt32(kVK_ANSI_T),
            UInt32(controlKey | optionKey),
            carbonHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
}

private final class QuickAddPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) {
        orderOut(sender)
    }
}

private struct QuickAddPanelView: View {
    @ObservedObject var controller: QuickAddPanelController
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("QUICK ADD")
                        .font(PlainType.groupHeader)
                        .tracking(Tracking.sidebarSection)
                        .foregroundStyle(PlainTokens.Syntax.project)
                    Text(controller.destinationDescription)
                        .font(PlainType.taskMeta)
                        .foregroundStyle(PlainTokens.TextToken.muted)
                }
                .padding(.leading, Spacing.md)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(PlainTokens.Syntax.project)
                        .frame(width: 2)
                }

                Spacer()

                Text("Ctrl+Opt+T")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(PlainTokens.TextToken.muted)
                    .padding(.horizontal, Spacing.sm + 1)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(PlainTokens.Surface.hover)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(PlainTokens.Border.row, lineWidth: 0.5)
                    )
            }

            TextField("Capture a task...", text: $controller.inputText)
                .textFieldStyle(.plain)
                .font(PlainType.taskBody)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(PlainTokens.Surface.input, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .stroke(PlainTokens.Border.input, lineWidth: 1)
                )
                .focused($isInputFocused)
                .onSubmit {
                    controller.submit()
                }

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
        .padding(Spacing.xl)
        .frame(width: 480)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(PlainTokens.Border.input, lineWidth: 1)
        }
        .padding(Spacing.lg)
        .onAppear {
            isInputFocused = true
        }
    }
}

struct MainWindowRegistrationView: View {
    @ObservedObject var controller: QuickAddPanelController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        WindowAccessor { window in
            window.setFrameAutosaveName("PlainMainWindow")
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
