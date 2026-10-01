import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let resources = Bundle.main.resourceURL!
    private var runDirectory: URL { resources.appendingPathComponent("run", isDirectory: true) }
    private var commandFile: URL { runDirectory.appendingPathComponent("menu.command") }
    private var webStatusFile: URL { runDirectory.appendingPathComponent("web.status") }
    private var dnsStatusFile: URL { runDirectory.appendingPathComponent("dns.status") }
    private var assetsStatusFile: URL { runDirectory.appendingPathComponent("assets.status") }
    private var helperURL: URL { resources.appendingPathComponent("bin/server.sh") }
    private var window: NSWindow!
    private var statusLabel: NSTextField!
    private var addressLabel: NSTextField!
    private var assetsLabel: NSTextField!
    private var webStatusLabel: NSTextField!
    private var dnsStatusLabel: NSTextField!
    private var webButton: NSButton!
    private var dnsButton: NSButton!
    private var webMenuItem: NSMenuItem!
    private var dnsMenuItem: NSMenuItem!
    private var helper: Process?
    private var statusTimer: Timer?
    private var scraper: Process?
    private var scraperProgressTimer: Timer?
    private var scraperProgressFile: URL { runDirectory.appendingPathComponent("scraper.progress") }
    private var scraperLogHandle: FileHandle?
    private var progressWindow: NSWindow?
    private var progressBar: NSProgressIndicator?
    private var progressMessage: NSTextField?
    private var progressCount: NSTextField?
    private var progressCancelButton: NSButton?
    private var progressRetryButton: NSButton?
    private var retryTimer: Timer?
    private var retrySecondsLeft = 0
    private var downloadCancelled = false
    private var pendingQuit = false
    private var isStarting = false
    private var isStopping = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildMenu()
        buildWindow()

        if resources.path.contains("/AppTranslocation/") || !FileManager.default.isWritableFile(atPath: resources.path) {
            showError("Liberated needs a writable location. Move Liberated.app out of the quarantine location and open it again.")
            NSApp.terminate(nil)
            return
        }

        do {
            try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: resources.appendingPathComponent("web/logs", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: resources.appendingPathComponent("web/temp", isDirectory: true), withIntermediateDirectories: true)
        } catch {
            showError("Cannot prepare the app's runtime folders: \(error.localizedDescription)")
            NSApp.terminate(nil)
            return
        }

        fixVenvConfig()
        let ip = localIPv4Address() ?? "unknown"
        addressLabel.stringValue = "Set your device DNS to: \(ip)"
        assetsLabel.stringValue = assetsAreDownloaded() ? "Game assets are ready." : "Game assets are missing."
        fixVenvConfig()
        showControlWindow(nil)
        startServer()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showControlWindow(nil)
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        pendingQuit = true
        stopRetryTimer()
        if scraper?.isRunning == true { scraper?.interrupt() }
        sendCommand("quit")
        return scraper?.isRunning == true ? .terminateCancel : .terminateNow
    }

    private func buildMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appItem.title = "Liberated"
        appMenu.addItem(NSMenuItem(title: "Show Control Window", action: #selector(showControlWindow(_:)), keyEquivalent: ""))
        webMenuItem = NSMenuItem(title: "Start Web Server", action: #selector(toggleWeb(_:)), keyEquivalent: "")
        appMenu.addItem(webMenuItem)
        dnsMenuItem = NSMenuItem(title: "Start DNS Server", action: #selector(toggleDNS(_:)), keyEquivalent: "")
        appMenu.addItem(dnsMenuItem)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Update Assets", action: #selector(updateAssets(_:)), keyEquivalent: "u"))
        appMenu.addItem(NSMenuItem(title: "Edit Scraper Config", action: #selector(editScraperConfig(_:)), keyEquivalent: "e"))
        appMenu.addItem(NSMenuItem(title: "Open Logs", action: #selector(openLogs(_:)), keyEquivalent: "l"))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Stop All Servers", action: #selector(stopAll(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Liberated", action: #selector(quitApp(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        NSApp.mainMenu = mainMenu
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 290),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Liberated"
        // We hold our own strong reference; letting AppKit also release on close crashes the app
        window.isReleasedWhenClosed = false
        window.center()

        let heading = NSTextField(labelWithString: "Liberated is starting")
        heading.font = .boldSystemFont(ofSize: 16)
        heading.frame = NSRect(x: 24, y: 254, width: 472, height: 24)
        statusLabel = heading

        addressLabel = NSTextField(labelWithString: "")
        addressLabel.frame = NSRect(x: 24, y: 226, width: 472, height: 20)

        webStatusLabel = NSTextField(labelWithString: "Web server: Starting")
        webStatusLabel.frame = NSRect(x: 24, y: 186, width: 300, height: 20)
        webButton = NSButton(title: "Stop Web", target: self, action: #selector(toggleWeb(_:)))
        webButton.frame = NSRect(x: 366, y: 180, width: 130, height: 32)

        dnsStatusLabel = NSTextField(labelWithString: "DNS server: Stopped")
        dnsStatusLabel.frame = NSRect(x: 24, y: 148, width: 300, height: 20)
        dnsButton = NSButton(title: "Start DNS", target: self, action: #selector(toggleDNS(_:)))
        dnsButton.frame = NSRect(x: 366, y: 142, width: 130, height: 32)

        assetsLabel = NSTextField(labelWithString: "")
        assetsLabel.frame = NSRect(x: 24, y: 104, width: 472, height: 20)
        assetsLabel.lineBreakMode = .byTruncatingTail

        let update = NSButton(title: "Update Assets", target: self, action: #selector(updateAssets(_:)))
        update.frame = NSRect(x: 24, y: 42, width: 112, height: 32)

        let editConfig = NSButton(title: "Edit Scraper Config", target: self, action: #selector(editScraperConfig(_:)))
        editConfig.frame = NSRect(x: 144, y: 42, width: 142, height: 32)

        let logs = NSButton(title: "Open Logs", target: self, action: #selector(openLogs(_:)))
        logs.frame = NSRect(x: 294, y: 42, width: 92, height: 32)

        let stopAll = NSButton(title: "Stop All", target: self, action: #selector(stopAll(_:)))
        stopAll.frame = NSRect(x: 394, y: 42, width: 102, height: 32)

        [heading, addressLabel, webStatusLabel, webButton, dnsStatusLabel, dnsButton,
         assetsLabel, update, editConfig, logs, stopAll].forEach { window.contentView?.addSubview($0) }
    }

    private func startServer() {
        guard helper?.isRunning != true else { return }
        isStarting = true
        statusLabel.stringValue = "Liberated is starting"
        sendCommand("idle")
        try? FileManager.default.removeItem(at: webStatusFile)
        try? FileManager.default.removeItem(at: dnsStatusFile)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [helperURL.path]
        process.currentDirectoryURL = resources
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                guard let self else { return }
                self.statusTimer?.invalidate()
                self.helper = nil
                self.isStarting = false
                self.statusLabel.stringValue = process.terminationStatus == 0 ? "Liberated is stopped" : "Liberated could not start"
                if process.terminationStatus != 0 {
                    self.showError("The server stopped unexpectedly. See Resources/run and Resources/web/logs for details.")
                }
            }
        }

        do {
            try process.run()
            helper = process
            statusTimer?.invalidate()
            statusTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                DispatchQueue.main.async { self?.refreshStatus() }
            }
        } catch {
            isStarting = false
            statusLabel.stringValue = "Liberated could not start"
            showError("Could not start the server helper: \(error.localizedDescription)")
        }
    }

    private func refreshStatus() {
        let web = readStatus(webStatusFile)
        let dns = readStatus(dnsStatusFile)
        webStatusLabel.stringValue = "Web server: \(web.capitalized)"
        dnsStatusLabel.stringValue = "DNS server: \(dns.capitalized)"
        webButton.title = web == "running" ? "Stop Web" : "Start Web"
        dnsButton.title = dns == "running" ? "Stop DNS" : "Start DNS"
        webMenuItem.title = web == "running" ? "Stop Web Server" : "Start Web Server"
        dnsMenuItem.title = dns == "running" ? "Stop DNS Server" : "Start DNS Server"

        let assetState = readStatus(assetsStatusFile)
        if !assetState.isEmpty { assetsLabel.stringValue = assetState }
        if web == "running" || dns == "running" {
            statusLabel.stringValue = "Liberated is running"
            isStarting = false
        } else if isStarting && web.hasPrefix("failed:") {
            isStarting = false
            statusLabel.stringValue = "Web server failed to start"
            showError(String(web.dropFirst("failed:".count)))
        } else if !isStarting {
            statusLabel.stringValue = "Servers are stopped"
        }
    }

    private func readStatus(_ url: URL) -> String {
        (try? String(contentsOf: url, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "stopped"
    }

    private func sendCommand(_ command: String) {
        try? FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        try? (command + "\n").write(to: commandFile, atomically: true, encoding: .utf8)
    }

    private func fixVenvConfig() {
        let config = resources.appendingPathComponent("venv/pyvenv.cfg")
        guard let contents = try? String(contentsOf: config, encoding: .utf8) else { return }
        let lines = contents.split(separator: "\n")
            .filter { !$0.hasPrefix("home =") && !$0.hasPrefix("executable =") && !$0.hasPrefix("command =") }
            .map(String.init)
        let fixed = (["home = \(resources.appendingPathComponent("python/bin").path)"] + lines).joined(separator: "\n") + "\n"
        try? fixed.write(to: config, atomically: true, encoding: .utf8)
    }

    private func assetsAreDownloaded() -> Bool {
        let configURL = resources.appendingPathComponent("scraper/scraper-config.json")
        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let platform = config["platform"] as? String,
              let language = config["lang_code"] as? String else { return false }
        let path = resources.appendingPathComponent("web/html/contents/\(platform)/custom/\(language)/ab_list.txt").path
        return FileManager.default.fileExists(atPath: path)
    }

    private func localIPv4Address() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/route")
        process.arguments = ["-n", "get", "default"]
        let pipe = Pipe()
        process.standardOutput = pipe
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let text = String(data: data, encoding: .utf8),
              let line = text.split(separator: "\n").first(where: { $0.contains("interface:") }),
              let interface = line.split(separator: ":").last?.trimmingCharacters(in: .whitespaces) else { return nil }

        let address = Process()
        address.executableURL = URL(fileURLWithPath: "/usr/sbin/ipconfig")
        address.arguments = ["getifaddr", interface]
        let addressPipe = Pipe()
        address.standardOutput = addressPipe
        guard (try? address.run()) != nil else { return nil }
        let addressData = addressPipe.fileHandleForReading.readDataToEndOfFile()
        address.waitUntilExit()
        return String(data: addressData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @objc private func showControlWindow(_ sender: Any?) {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func updateAssets(_ sender: Any?) {
        startAssetDownload()
    }

    private func startAssetDownload() {
        if progressWindow == nil {
            buildProgressWindow()
        }
        progressWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        guard scraper == nil, retryTimer == nil else { return }
        launchScraper()
    }

    private func buildProgressWindow() {
        let progress = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 170),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        progress.title = "Liberated"
        progress.isReleasedWhenClosed = false
        progress.center()

        let message = NSTextField(labelWithString: "")
        message.frame = NSRect(x: 20, y: 122, width: 460, height: 20)
        message.lineBreakMode = .byTruncatingMiddle

        let bar = NSProgressIndicator(frame: NSRect(x: 20, y: 84, width: 460, height: 20))
        bar.minValue = 0
        bar.maxValue = 100

        let count = NSTextField(labelWithString: "")
        count.frame = NSRect(x: 20, y: 50, width: 330, height: 20)

        let retry = NSButton(title: "Retry Now", target: self, action: #selector(retryAssetDownload(_:)))
        retry.frame = NSRect(x: 280, y: 16, width: 100, height: 30)

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelAssetDownload(_:)))
        cancel.frame = NSRect(x: 390, y: 16, width: 90, height: 30)

        [message, bar, count, retry, cancel].forEach { progress.contentView?.addSubview($0) }
        progressWindow = progress
        progressMessage = message
        progressBar = bar
        progressCount = count
        progressRetryButton = retry
        progressCancelButton = cancel
    }

    private func launchScraper() {
        downloadCancelled = false
        progressMessage?.stringValue = "Preparing asset download…"
        progressCount?.stringValue = "Connecting…"
        progressBar?.isIndeterminate = true
        progressBar?.startAnimation(nil)
        progressRetryButton?.isHidden = true
        progressCancelButton?.title = "Cancel"
        progressCancelButton?.isEnabled = true

        try? FileManager.default.removeItem(at: scraperProgressFile)
        let logURL = runDirectory.appendingPathComponent("scraper.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)

        let process = Process()
        process.executableURL = resources.appendingPathComponent("venv/bin/python3")
        process.arguments = ["-u", resources.appendingPathComponent("scraper/scraper.py").path,
                             "--progress", scraperProgressFile.path]
        process.currentDirectoryURL = resources
        do {
            let log = try FileHandle(forWritingTo: logURL)
            scraperLogHandle = log
            process.standardOutput = log
            process.standardError = log
            process.terminationHandler = { [weak self] process in
                DispatchQueue.main.async { self?.finishAssetDownload(exitCode: process.terminationStatus) }
            }
            try process.run()
            scraper = process
            assetsLabel.stringValue = "Downloading game assets…"
            scraperProgressTimer?.invalidate()
            scraperProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                DispatchQueue.main.async { self?.refreshAssetProgress() }
            }
        } catch {
            scraperLogHandle = nil
            progressMessage?.stringValue = "Could not start the scraper: \(error.localizedDescription)"
            progressCount?.stringValue = ""
            progressCancelButton?.title = "Close"
        }
    }

    private func refreshAssetProgress() {
        guard let value = try? String(contentsOf: scraperProgressFile, encoding: .utf8) else { return }
        let fields = value.components(separatedBy: "\t")
        guard fields.count >= 3, fields[0] != "EXIT" else { return }
        progressMessage?.stringValue = fields.dropFirst(2).joined(separator: "\t")
        if let done = Double(fields[0]), let total = Double(fields[1]), total > 0 {
            progressBar?.isIndeterminate = false
            progressBar?.doubleValue = min(100, done * 100 / total)
            progressCount?.stringValue = "\(Int(done)) / \(Int(total)) files (\(Int(done * 100 / total))%)"
        }
    }

    private func finishAssetDownload(exitCode: Int32) {
        scraperProgressTimer?.invalidate()
        scraperProgressTimer = nil
        scraperLogHandle?.closeFile()
        scraperLogHandle = nil
        scraper = nil
        try? FileManager.default.removeItem(at: scraperProgressFile)
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: scraperProgressFile.path + ".tmp"))

        progressCancelButton?.isEnabled = true
        progressBar?.stopAnimation(nil)
        if pendingQuit {
            NSApp.terminate(nil)
            return
        }
        if exitCode == 0 {
            assetsLabel.stringValue = "Game assets are ready."
            progressMessage?.stringValue = "Game assets downloaded."
            progressBar?.isIndeterminate = false
            progressBar?.doubleValue = 100
            progressCount?.stringValue = "Done"
            progressCancelButton?.title = "Close"
        } else if downloadCancelled {
            showDownloadStopped("Download cancelled; downloaded files were kept.")
        } else {
            assetsLabel.stringValue = "Download failed; retrying…"
            progressMessage?.stringValue = "Download failed: \(lastScraperLogLine() ?? "see run/scraper.log")"
            progressRetryButton?.isHidden = false
            progressCancelButton?.title = "Cancel"
            retrySecondsLeft = 10
            progressCount?.stringValue = "Retrying in \(retrySecondsLeft) seconds…"
            retryTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                DispatchQueue.main.async { self?.tickRetryCountdown() }
            }
        }
    }

    private func tickRetryCountdown() {
        retrySecondsLeft -= 1
        if retrySecondsLeft > 0 {
            progressCount?.stringValue = "Retrying in \(retrySecondsLeft) seconds…"
        } else {
            stopRetryTimer()
            launchScraper()
        }
    }

    private func stopRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = nil
    }

    private func showDownloadStopped(_ text: String) {
        assetsLabel.stringValue = text
        progressMessage?.stringValue = text
        progressCount?.stringValue = "Cancelled"
        progressRetryButton?.isHidden = false
        progressCancelButton?.title = "Close"
    }

    private func lastScraperLogLine() -> String? {
        let log = runDirectory.appendingPathComponent("scraper.log")
        guard let text = try? String(contentsOf: log, encoding: .utf8) else { return nil }
        return text.split(separator: "\n").last.map(String.init)
    }

    @objc private func retryAssetDownload(_ sender: NSButton) {
        stopRetryTimer()
        guard scraper == nil else { return }
        launchScraper()
    }

    @objc private func cancelAssetDownload(_ sender: NSButton) {
        if scraper?.isRunning == true {
            downloadCancelled = true
            progressMessage?.stringValue = "Cancelling download…"
            sender.isEnabled = false
            scraper?.interrupt()
        } else if retryTimer != nil {
            stopRetryTimer()
            showDownloadStopped("Download failed; automatic retry cancelled.")
        } else {
            progressWindow?.orderOut(nil)
            progressWindow = nil
            progressMessage = nil
            progressBar = nil
            progressCount = nil
            progressRetryButton = nil
            progressCancelButton = nil
        }
    }

    @objc private func editScraperConfig(_ sender: Any?) {
        NSWorkspace.shared.open(resources.appendingPathComponent("scraper/scraper-config.json"))
    }

    @objc private func openLogs(_ sender: Any?) {
        NSWorkspace.shared.open(runDirectory)
        NSWorkspace.shared.open(resources.appendingPathComponent("web/logs", isDirectory: true))
    }

    @objc private func toggleWeb(_ sender: Any?) {
        sendCommand(readStatus(webStatusFile) == "running" ? "stop-web" : "start-web")
    }

    @objc private func toggleDNS(_ sender: Any?) {
        sendCommand(readStatus(dnsStatusFile) == "running" ? "stop-dns" : "start-dns")
    }

    @objc private func stopAll(_ sender: Any?) {
        sendCommand("stop-all")
    }

    @objc private func quitApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func showError(_ text: String) {
        let alert = NSAlert()
        alert.messageText = "Liberated"
        alert.informativeText = text
        alert.alertStyle = .warning
        alert.runModal()
    }
}

@main
struct LiberatedMain {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}
