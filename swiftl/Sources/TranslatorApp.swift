import SwiftUI
import AppKit

@main
struct TranslatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    private var mouseEventMonitor: Any?
    var isAreaSelectionActive: (() -> Bool)?
    
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect,
                  styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
                  backing: backing,
                  defer: flag)
        
        self.isFloatingPanel = true
        self.level = .floating
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Set background color to a light color with some transparency
        let visualEffect = NSVisualEffectView(frame: contentRect)
        visualEffect.material = .popover
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        self.contentView = visualEffect
        
        self.isOpaque = false
        self.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.98)
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.isReleasedWhenClosed = false
        
        // Set up mouse event monitoring
        setupMouseEventMonitoring()
    }
    
    private func setupMouseEventMonitoring() {
        mouseEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isVisible else { return }
            
            // Get the mouse location in screen coordinates
            let mouseLocation = event.locationInWindow
            
            // Convert mouse location to window coordinates
            let windowFrame = self.frame
            
            // Check if click is outside the window
            if !windowFrame.contains(mouseLocation) {
                // Check if we're not in area selection mode
                if !(self.isAreaSelectionActive?() ?? false) {
                    DispatchQueue.main.async {
                        self.orderOut(nil)
                    }
                }
            }
        }
    }
    
    deinit {
        if let monitor = mouseEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var panel: FloatingPanel?
    private let viewModel = TranslatorViewModel()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        // Create the SwiftUI view that provides the window contents
        let contentView = ContentView().environmentObject(viewModel)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 400)
        
        // Create the floating panel
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            backing: .buffered,
            defer: false
        )
        
        // Add the hosting view to the visual effect view
        if let visualEffect = panel.contentView as? NSVisualEffectView {
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            visualEffect.addSubview(hostingView)
            
            // Add constraints to make the hosting view fill the visual effect view
            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
                hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
                hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor)
            ])
        }
        
        // Set up the area selection check using the shared viewModel
        panel.isAreaSelectionActive = { [weak self] in
            self?.viewModel.isSelectingArea ?? false
        }
        
        self.panel = panel

        // Create the status item
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "character.book.closed", accessibilityDescription: nil) ?? NSImage(named: "NSBookmarks")
            button.target = self
            button.action = #selector(togglePanel)
            
            // Enable right-click menu
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        self.statusItem = statusItem
    }
    
    @objc func togglePanel(_ sender: NSStatusBarButton) {
        if let event = NSApp.currentEvent {
            if event.type == .rightMouseUp {
                showContextMenu()
            } else {
                if let panel = self.panel {
                    if panel.isVisible {
                        panel.orderOut(nil)
                    } else {
                        showPanel(sender)
                    }
                }
            }
        }
    }
    
    func showContextMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        if let button = statusItem?.button {
            let position = NSPoint(x: 0, y: button.bounds.height)
            menu.popUp(positioning: nil, at: position, in: button)
        }
    }
    
    func showPanel(_ sender: Any?) {
        guard let panel = self.panel else { return }
        
        if let statusButton = statusItem?.button {
            // Position panel above the status item
            let buttonRect = statusButton.window?.convertToScreen(statusButton.convert(statusButton.bounds, to: nil)) ?? .zero
            panel.setFrameTopLeftPoint(NSPoint(
                x: buttonRect.midX - panel.frame.width/2,
                y: buttonRect.minY - 5
            ))
        } else {
            // If called from elsewhere, position near the center of the screen
            if let screen = NSScreen.main {
                let screenRect = screen.visibleFrame
                panel.setFrameOrigin(NSPoint(
                    x: screenRect.midX - panel.frame.width/2,
                    y: screenRect.midY - panel.frame.height/2
                ))
            }
        }
        
        panel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}