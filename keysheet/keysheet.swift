// KeySheet: floating keyboard cheat sheet. Shows the Keymap page (keys.html) centered at ~70% of the screen, floating over
// every space, opened to the shortcuts of one app (argv[1] -> #app=<name>). Esc, clicking away or running it again closes it.
import Cocoa
import WebKit

final class Panel: NSWindow {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { NSApp.terminate(nil) }
}

final class Delegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var win: Panel!
    func applicationDidFinishLaunching(_ n: Notification) {
        let app = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ""
        let path = ProcessInfo.processInfo.environment["KEYSHEET_PAGE"]
            ?? NSHomeDirectory() + "/Vaults/Tyler's Vault/03_Projects/Keymap/keys.html"
        let frame = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        let w = frame.width * 0.7, h = frame.height * 0.7
        win = Panel(contentRect: NSRect(x: frame.midX - w / 2, y: frame.midY - h / 2, width: w, height: h),
                    styleMask: [.borderless], backing: .buffered, defer: false)
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        win.isOpaque = false
        win.backgroundColor = NSColor(white: 0.07, alpha: 1)
        win.hasShadow = true
        win.contentView?.wantsLayer = true
        win.contentView?.layer?.cornerRadius = 18
        win.contentView?.layer?.masksToBounds = true
        win.delegate = self
        let web = WKWebView(frame: win.contentView!.bounds, configuration: WKWebViewConfiguration())
        web.autoresizingMask = [.width, .height]
        web.setValue(false, forKey: "drawsBackground")
        win.contentView?.addSubview(web)
        let frag = app.isEmpty ? "" : "#app=" + (app.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? app)
        let url = URL(string: "file://" + path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)! + frag)!
        web.loadFileURL(url, allowingReadAccessTo: URL(fileURLWithPath: path).deletingLastPathComponent())
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }
    func windowDidResignKey(_ n: Notification) { NSApp.terminate(nil) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let d = Delegate()
app.delegate = d
app.run()
