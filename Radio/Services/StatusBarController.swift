import AppKit
import SwiftUI

final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let hostingController: NSViewController

    init(radioPlayer: RadioPlayer) {
        hostingController = NSHostingController(
            rootView: ContentView().environmentObject(radioPlayer)
        )
        super.init()

        popover.contentViewController = hostingController
        popover.behavior = .transient
        _ = hostingController.view

        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "dot.radiowaves.left.and.right", accessibilityDescription: "Radio")
        button.action = #selector(handleStatusItemClick(_:))
        button.target = self
        button.sendAction(on: [.leftMouseDown, .rightMouseUp])
    }

    @objc
    private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePopover(sender)
            return
        }

        switch event.type {
        case .rightMouseUp:
            showContextMenu()
        default:
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let quitItem = NSMenuItem(
            title: String(localized: "menu.quit_application"),
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc
    private func quitApplication() {
        NSApp.terminate(nil)
    }
}
