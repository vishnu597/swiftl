import AppKit
import Cocoa

class AreaSelectionWindow: NSWindow {
    private var initialPoint: NSPoint?
    private var currentRect: NSRect?
    private let overlayView: OverlayView
    private weak var viewModel: TranslatorViewModel?
    
    init(viewModel: TranslatorViewModel) {
        self.viewModel = viewModel
        
        // Create a window that covers the entire screen
        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        overlayView = OverlayView()
        
        super.init(
            contentRect: screenRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Configure the window
        self.contentView = overlayView
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Set cursor to crosshair
        NSCursor.crosshair.push()
    }
    
    override func mouseDown(with event: NSEvent) {
        initialPoint = event.locationInWindow
        currentRect = nil
        overlayView.selectionRect = nil
        overlayView.needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let initialPoint = initialPoint else { return }
        
        let currentPoint = event.locationInWindow
        
        // Calculate the rectangle between the initial point and current point
        let minX = min(initialPoint.x, currentPoint.x)
        let minY = min(initialPoint.y, currentPoint.y)
        let width = abs(initialPoint.x - currentPoint.x)
        let height = abs(initialPoint.y - currentPoint.y)
        
        currentRect = NSRect(x: minX, y: minY, width: width, height: height)
        overlayView.selectionRect = currentRect
        overlayView.needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        // Reset cursor
        NSCursor.pop()
        
        // Unhide the app
        NSApp.unhide(nil)
        
        // Check if we have a valid rectangle
        if let rect = currentRect, rect.width > 10, rect.height > 10,
           let mainScreen = NSScreen.main,
           let vm = viewModel {
            
            // Convert the selection rect to base coordinates (flipped)
            let flippedRect = NSRect(
                x: rect.minX,
                y: mainScreen.frame.height - rect.maxY,
                width: rect.width,
                height: rect.height
            )
            
            // Convert to screen coordinates
            let screenRect = self.convertToScreen(flippedRect)
            
            // Create the final capture rect
            let captureRect = NSRect(
                x: screenRect.minX,
                y: screenRect.minY,
                width: screenRect.width,
                height: screenRect.height
            )
            
            // This is important: create a local copy of the capture rectangle
            // so it's not tied to this window's lifecycle
            let finalRect = NSRect(x: captureRect.minX, 
                                  y: captureRect.minY, 
                                  width: captureRect.width, 
                                  height: captureRect.height)
            
            // Make sure the window is closed before processing
            self.orderOut(nil)
            
            // Use a separate async call to process the area after window is closed
            DispatchQueue.main.async {
                vm.processSelectedArea(rect: finalRect)
            }
        } else {
            // Close without processing
            self.orderOut(nil)
        }
    }
}

class OverlayView: NSView {
    var selectionRect: NSRect?
    
    override func draw(_ dirtyRect: NSRect) {
        // Fill the entire view with a semi-transparent black
        NSColor.black.withAlphaComponent(0.3).setFill()
        dirtyRect.fill()
        
        // If we have a selection rectangle, clear it and draw a border
        if let selectionRect = selectionRect {
            // Clear the selection rectangle
            NSColor.clear.setFill()
            selectionRect.fill()
            
            // Draw a border around the selection rectangle
            NSColor.white.setStroke()
            let path = NSBezierPath(rect: selectionRect)
            path.lineWidth = 2.0
            path.stroke()
        }
    }
}