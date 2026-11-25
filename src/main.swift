// Copyright 2026 FreeDial contributors. Licensed under the Apache License, Version 2.0.
import Cocoa

// Picker for RDP targets. Saved entries live in ~/.config/freedial/hosts.tsv as
// "machine<TAB>address" lines, most recently used first. The password is kept in the
// Keychain under rdp-<machine>, so one machine can have several addresses.
// Optional ~/.config/freedial/config: a line "user=name" overrides the RDP username
// (default: your macOS login name).

let home = NSHomeDirectory()
let configDir = home + "/.config/freedial"
let hostsPath = configDir + "/hosts.tsv"
let logPath = home + "/Library/Logs/freedial.log"

let rdpUser: String = {
    let text = (try? String(contentsOfFile: configDir + "/config", encoding: .utf8)) ?? ""
    for line in text.split(separator: "\n") where line.hasPrefix("user=") {
        let v = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        if !v.isEmpty { return v }
    }
    return NSUserName()
}()

struct Entry: Equatable { var machine: String; var address: String }

func loadEntries() -> [Entry] {
    guard let text = try? String(contentsOfFile: hostsPath, encoding: .utf8) else { return [] }
    return text.split(separator: "\n").compactMap { line in
        let f = line.split(separator: "\t", maxSplits: 1).map(String.init)
        return f.count == 2 ? Entry(machine: f[0], address: f[1]) : nil
    }
}

func saveEntries(_ entries: [Entry]) {
    try? FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)
    let text = entries.map { "\($0.machine)\t\($0.address)" }.joined(separator: "\n") + "\n"
    try? text.write(toFile: hostsPath, atomically: true, encoding: .utf8)
}

func valid(_ s: String) -> Bool {
    !s.isEmpty && s.range(of: "^[A-Za-z0-9._:\\-\\[\\]]+$", options: .regularExpression) != nil
}

@discardableResult
func runSecurity(_ args: [String]) -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    p.arguments = args
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    try? p.run(); p.waitUntilExit()
    return p.terminationStatus
}

// Stored in-process so the password never appears in another process's arguments.
func savePassword(service: String, password: String) -> Bool {
    let item: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: rdpUser,
        kSecValueData as String: Data(password.utf8),
    ]
    return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
}

func message(_ title: String, _ info: String) {
    let a = NSAlert()
    a.messageText = title
    a.informativeText = info
    a.addButton(withTitle: "OK")
    a.runModal()
}

final class Picker: NSObject, NSComboBoxDelegate {
    var entries: [Entry]
    let machine = NSComboBox(frame: NSRect(x: 80, y: 34, width: 280, height: 26))
    let address = NSComboBox(frame: NSRect(x: 80, y: 0, width: 280, height: 26))
    let view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 64))

    init(entries: [Entry]) {
        self.entries = entries
        super.init()
        for (text, y) in [("Machine", 38), ("Address", 4)] {
            let l = NSTextField(labelWithString: text)
            l.frame = NSRect(x: 0, y: y, width: 76, height: 20)
            view.addSubview(l)
        }
        for box in [machine, address] {
            box.isEditable = true
            box.completes = true
            box.numberOfVisibleItems = 10
            box.delegate = self
            view.addSubview(box)
        }
        var seen = Set<String>()
        machine.addItems(withObjectValues: entries.map(\.machine).filter { seen.insert($0).inserted })
        if let first = entries.first {
            machine.stringValue = first.machine
            fillAddresses(for: first.machine, select: first.address)
        }
    }

    func fillAddresses(for m: String, select: String? = nil) {
        address.removeAllItems()
        let list = entries.filter { $0.machine == m }.map(\.address)
        address.addItems(withObjectValues: list)
        address.stringValue = select ?? list.first ?? ""
    }

    func comboBoxSelectionDidChange(_ n: Notification) {
        guard let box = n.object as? NSComboBox, box === machine,
              let m = machine.objectValueOfSelectedItem as? String else { return }
        fillAddresses(for: m)
    }
}

guard let connectPath = Bundle.main.path(forResource: "freedial-connect", ofType: nil) else {
    fatalError("freedial-connect is missing from the app bundle")
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)

let initial = loadEntries()
let picker = Picker(entries: initial)
let dialog = NSAlert()
dialog.messageText = "Connect with RDP"
dialog.informativeText = initial.isEmpty
    ? "Type a machine name and its address (host name or IP, optionally :port). They're saved for next time."
    : "Pick a saved address from the list, or type a new one."
dialog.accessoryView = picker.view
dialog.addButton(withTitle: "Connect")
dialog.addButton(withTitle: "Cancel")
dialog.window.initialFirstResponder = initial.isEmpty ? picker.machine : picker.address
guard dialog.runModal() == .alertFirstButtonReturn else { exit(0) }

let m = picker.machine.stringValue.trimmingCharacters(in: .whitespaces)
let a = picker.address.stringValue.trimmingCharacters(in: .whitespaces)
guard valid(m), valid(a) else {
    message("Invalid entry", "Machine and address may only contain letters, digits and . : - _")
    exit(1)
}

let service = "rdp-\(m)"
if runSecurity(["find-generic-password", "-s", service, "-a", rdpUser]) != 0 {
    let prompt = NSAlert()
    prompt.messageText = "Password for \(m)"
    prompt.informativeText = "The RDP password isn't saved yet. It will be stored in your Keychain."
    let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
    prompt.accessoryView = field
    prompt.addButton(withTitle: "Save and Connect")
    prompt.addButton(withTitle: "Cancel")
    prompt.window.initialFirstResponder = field
    guard prompt.runModal() == .alertFirstButtonReturn, !field.stringValue.isEmpty else { exit(0) }
    if !savePassword(service: service, password: field.stringValue) {
        message("Couldn't save the password", "The Keychain refused the new item.")
        exit(1)
    }
}

var entries = loadEntries()
entries.removeAll { $0 == Entry(machine: m, address: a) }
entries.insert(Entry(machine: m, address: a), at: 0)
saveEntries(entries)

try? FileManager.default.createDirectory(atPath: (logPath as NSString).deletingLastPathComponent,
                                         withIntermediateDirectories: true)
FileManager.default.createFile(atPath: logPath, contents: nil)
let log = FileHandle(forWritingAtPath: logPath)

let rdp = Process()
rdp.executableURL = URL(fileURLWithPath: connectPath)
rdp.arguments = [m]
var env = ProcessInfo.processInfo.environment
env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
env["FREEDIAL_ADDRESS"] = a
env["FREEDIAL_USER"] = rdpUser
rdp.environment = env
rdp.standardOutput = log
rdp.standardError = log
do { try rdp.run() } catch {
    message("Couldn't start", "\(connectPath) failed to launch: \(error.localizedDescription)")
    exit(1)
}

// Only an early exit counts as a failed connection; closing the RDP window later stays silent.
let deadline = Date().addingTimeInterval(6)
while rdp.isRunning && Date() < deadline {
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
}
if !rdp.isRunning && rdp.terminationStatus != 0 {
    let tail = ((try? String(contentsOfFile: logPath, encoding: .utf8)) ?? "")
        .split(separator: "\n").filter { $0.contains("ERROR") || $0.hasPrefix("No ") || $0.hasPrefix("sdl-") }
        .suffix(3).joined(separator: "\n")
    message("Couldn't connect to \(a)", tail.isEmpty ? "The connection ended right away. See \(logPath)." : tail)
}
exit(0)
