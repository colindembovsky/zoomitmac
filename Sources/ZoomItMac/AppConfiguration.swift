import AppKit
import Carbon.HIToolbox
import Foundation

enum ToggleHotkeyModifierOption: String, CaseIterable {
    case control
    case option
    case command
    case shift
    case controlCommand
    case controlOption
    case controlShift
    case optionShift
    case commandOption
    case commandShift

    var displayName: String {
        switch self {
        case .control:
            return "Control"
        case .option:
            return "Option"
        case .command:
            return "Command"
        case .shift:
            return "Shift"
        case .controlCommand:
            return "Control + Command"
        case .controlOption:
            return "Control + Option"
        case .controlShift:
            return "Control + Shift"
        case .optionShift:
            return "Option + Shift"
        case .commandOption:
            return "Command + Option"
        case .commandShift:
            return "Command + Shift"
        }
    }

    var carbonFlags: UInt32 {
        switch self {
        case .control:
            return UInt32(controlKey)
        case .option:
            return UInt32(optionKey)
        case .command:
            return UInt32(cmdKey)
        case .shift:
            return UInt32(shiftKey)
        case .controlCommand:
            return UInt32(controlKey | cmdKey)
        case .controlOption:
            return UInt32(controlKey | optionKey)
        case .controlShift:
            return UInt32(controlKey | shiftKey)
        case .optionShift:
            return UInt32(optionKey | shiftKey)
        case .commandOption:
            return UInt32(cmdKey | optionKey)
        case .commandShift:
            return UInt32(cmdKey | shiftKey)
        }
    }

    var displayPrefix: String {
        switch self {
        case .control:
            return "Ctrl"
        case .option:
            return "Opt"
        case .command:
            return "Cmd"
        case .shift:
            return "Shift"
        case .controlCommand:
            return "Ctrl+Cmd"
        case .controlOption:
            return "Ctrl+Opt"
        case .controlShift:
            return "Ctrl+Shift"
        case .optionShift:
            return "Opt+Shift"
        case .commandOption:
            return "Cmd+Opt"
        case .commandShift:
            return "Cmd+Shift"
        }
    }

    static func from(modifiers: NSEvent.ModifierFlags) -> ToggleHotkeyModifierOption? {
        let significantModifiers = modifiers.intersection([.control, .option, .command, .shift])

        switch significantModifiers {
        case [.control]:
            return .control
        case [.option]:
            return .option
        case [.command]:
            return .command
        case [.shift]:
            return .shift
        case [.control, .command]:
            return .controlCommand
        case [.control, .option]:
            return .controlOption
        case [.control, .shift]:
            return .controlShift
        case [.option, .shift]:
            return .optionShift
        case [.command, .option]:
            return .commandOption
        case [.command, .shift]:
            return .commandShift
        default:
            return nil
        }
    }
}

enum PenThicknessOption: String, CaseIterable {
    case standard
    case thick
    case extraThick

    var displayName: String {
        switch self {
        case .standard:
            return "Standard"
        case .thick:
            return "Thick"
        case .extraThick:
            return "Extra Thick"
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .standard:
            return 4.0
        case .thick:
            return 8.0
        case .extraThick:
            return 12.0
        }
    }
}

enum AppShortcutAction: String, CaseIterable {
    case red
    case blue
    case green
    case yellow
    case clear
    case save

    var displayName: String {
        switch self {
        case .red:
            return "Red Pen"
        case .blue:
            return "Blue Pen"
        case .green:
            return "Green Pen"
        case .yellow:
            return "Yellow Pen"
        case .clear:
            return "Clear Annotations"
        case .save:
            return "Save Image (Ctrl+Key)"
        }
    }

    var defaultKey: String {
        switch self {
        case .red:
            return "R"
        case .blue:
            return "B"
        case .green:
            return "G"
        case .yellow:
            return "Y"
        case .clear:
            return "C"
        case .save:
            return "S"
        }
    }

    var requiresControlModifier: Bool {
        self == .save
    }
}

enum ShortcutKeyMapper {
    static func normalizedKeyInput(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.count == 1, let scalar = trimmed.unicodeScalars.first else {
            return nil
        }

        guard CharacterSet.alphanumerics.contains(scalar) else {
            return nil
        }

        return trimmed
    }

    static func carbonKeyCode(for key: String) -> UInt32? {
        switch key.uppercased() {
        case "A": return UInt32(kVK_ANSI_A)
        case "B": return UInt32(kVK_ANSI_B)
        case "C": return UInt32(kVK_ANSI_C)
        case "D": return UInt32(kVK_ANSI_D)
        case "E": return UInt32(kVK_ANSI_E)
        case "F": return UInt32(kVK_ANSI_F)
        case "G": return UInt32(kVK_ANSI_G)
        case "H": return UInt32(kVK_ANSI_H)
        case "I": return UInt32(kVK_ANSI_I)
        case "J": return UInt32(kVK_ANSI_J)
        case "K": return UInt32(kVK_ANSI_K)
        case "L": return UInt32(kVK_ANSI_L)
        case "M": return UInt32(kVK_ANSI_M)
        case "N": return UInt32(kVK_ANSI_N)
        case "O": return UInt32(kVK_ANSI_O)
        case "P": return UInt32(kVK_ANSI_P)
        case "Q": return UInt32(kVK_ANSI_Q)
        case "R": return UInt32(kVK_ANSI_R)
        case "S": return UInt32(kVK_ANSI_S)
        case "T": return UInt32(kVK_ANSI_T)
        case "U": return UInt32(kVK_ANSI_U)
        case "V": return UInt32(kVK_ANSI_V)
        case "W": return UInt32(kVK_ANSI_W)
        case "X": return UInt32(kVK_ANSI_X)
        case "Y": return UInt32(kVK_ANSI_Y)
        case "Z": return UInt32(kVK_ANSI_Z)
        case "0": return UInt32(kVK_ANSI_0)
        case "1": return UInt32(kVK_ANSI_1)
        case "2": return UInt32(kVK_ANSI_2)
        case "3": return UInt32(kVK_ANSI_3)
        case "4": return UInt32(kVK_ANSI_4)
        case "5": return UInt32(kVK_ANSI_5)
        case "6": return UInt32(kVK_ANSI_6)
        case "7": return UInt32(kVK_ANSI_7)
        case "8": return UInt32(kVK_ANSI_8)
        case "9": return UInt32(kVK_ANSI_9)
        default: return nil
        }
    }
}

enum AppConfiguration {
    private static let saveFolderKey = "saveFolderURL"
    private static let toggleHotkeyKeyKey = "toggleHotkeyKey"
    private static let toggleHotkeyModifierKey = "toggleHotkeyModifier"
    private static let penThicknessKey = "penThickness"

    static var defaultSaveFolderURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
    }

    static var saveFolderURL: URL {
        get {
            UserDefaults.standard.url(forKey: saveFolderKey) ?? defaultSaveFolderURL
        }
        set {
            UserDefaults.standard.set(newValue, forKey: saveFolderKey)
        }
    }

    static var toggleHotkeyKey: String {
        get {
            if let stored = UserDefaults.standard.string(forKey: toggleHotkeyKeyKey),
               let normalized = ShortcutKeyMapper.normalizedKeyInput(stored) {
                return normalized
            }
            return "1"
        }
        set {
            if let normalized = ShortcutKeyMapper.normalizedKeyInput(newValue) {
                UserDefaults.standard.set(normalized, forKey: toggleHotkeyKeyKey)
            }
        }
    }

    static var toggleHotkeyModifier: ToggleHotkeyModifierOption {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: toggleHotkeyModifierKey),
                  let modifier = ToggleHotkeyModifierOption(rawValue: rawValue) else {
                return .control
            }
            return modifier
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: toggleHotkeyModifierKey)
        }
    }

    static var toggleHotkeyDisplayString: String {
        "\(toggleHotkeyModifier.displayPrefix)+\(toggleHotkeyKey)"
    }

    static var penThickness: PenThicknessOption {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: penThicknessKey),
                  let thickness = PenThicknessOption(rawValue: rawValue) else {
                return .thick
            }
            return thickness
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: penThicknessKey)
        }
    }

    static func key(for action: AppShortcutAction) -> String {
        if let stored = UserDefaults.standard.string(forKey: shortcutStorageKey(for: action)),
           let normalized = ShortcutKeyMapper.normalizedKeyInput(stored) {
            return normalized
        }
        return action.defaultKey
    }

    static func setKey(_ key: String, for action: AppShortcutAction) {
        if let normalized = ShortcutKeyMapper.normalizedKeyInput(key) {
            UserDefaults.standard.set(normalized, forKey: shortcutStorageKey(for: action))
        }
    }

    static func matchesShortcut(
        characters: String,
        modifiers: NSEvent.ModifierFlags,
        action: AppShortcutAction
    ) -> Bool {
        let normalizedCharacters = characters.uppercased()
        let expectedKey = key(for: action)
        let significantModifiers = modifiers.intersection(.deviceIndependentFlagsMask)

        if action.requiresControlModifier {
            return significantModifiers.contains(.control) && normalizedCharacters == expectedKey
        }

        let disallowedModifiers: NSEvent.ModifierFlags = [.control, .option, .command]
        return significantModifiers.intersection(disallowedModifiers).isEmpty && normalizedCharacters == expectedKey
    }

    private static func shortcutStorageKey(for action: AppShortcutAction) -> String {
        "shortcut.\(action.rawValue)"
    }

    static func resetShortcutsToDefaults() {
        UserDefaults.standard.removeObject(forKey: toggleHotkeyKeyKey)
        UserDefaults.standard.removeObject(forKey: toggleHotkeyModifierKey)
        AppShortcutAction.allCases.forEach { action in
            UserDefaults.standard.removeObject(forKey: shortcutStorageKey(for: action))
        }
    }
}
