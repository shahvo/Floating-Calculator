import AppKit

enum AppInfo {
    // Single source of truth for the menu bar, About panel, window title, and app bundle.
    static let name = "Floating Calculator"
    static let version = "1.0"
    static let copyright = "Copyright © 2026 SamEarth.net"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: CalculatorWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.mainMenu = makeMainMenu()

        if let icon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = icon
        }

        // AppKit command-line apps do not get a storyboard/window scene, so startup
        // creates the single calculator window manually and makes it key immediately.
        let calculatorWindow = CalculatorWindow()
        calculatorWindow.placeInVisibleCorner()
        calculatorWindow.makeKeyAndOrderFront(nil)
        calculatorWindow.orderFrontRegardless()
        calculatorWindow.makeFirstResponder(calculatorWindow)
        window = calculatorWindow

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func makeMainMenu() -> NSMenu {
        // A minimal macOS application menu keeps standard About and Quit behavior
        // available even though this app is created without an Xcode storyboard.
        let mainMenu = NSMenu(title: "Main Menu")
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: AppInfo.name)

        appMenu.addItem(
            withTitle: "About \(AppInfo.name)",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit \(AppInfo.name)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        return mainMenu
    }

    @MainActor @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: AppInfo.name,
            .applicationVersion: AppInfo.version,
            .version: AppInfo.version,
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): AppInfo.copyright
        ])
    }
}

final class CalculatorWindow: NSWindow {
    private let controller = CalculatorViewController()
    private static let defaultSize = NSSize(width: 236, height: 340)

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        title = AppInfo.name
        minSize = Self.defaultSize
        maxSize = Self.defaultSize
        contentViewController = controller
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        setFloating(true)

        // The view controller owns the checkbox; the window owns the macOS window level.
        controller.onFloatChanged = { [weak self] shouldFloat in
            self?.setFloating(shouldFloat)
        }
    }

    func placeInVisibleCorner() {
        // Use the visible frame, not the full frame, so the window avoids the menu bar
        // and Dock while still landing where it is easy to find.
        let screenFrame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
        let margin: CGFloat = 18
        let origin = NSPoint(
            x: screenFrame.maxX - Self.defaultSize.width - margin,
            y: screenFrame.maxY - Self.defaultSize.height - margin
        )
        setFrame(NSRect(origin: origin, size: Self.defaultSize), display: true)
    }

    private func setFloating(_ shouldFloat: Bool) {
        // A high window level plus these collection behaviors let the calculator
        // remain visible across Spaces, including typical fullscreen app Spaces.
        level = shouldFloat ? .screenSaver : .normal
        collectionBehavior = shouldFloat
            ? [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            : []
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        // Keyboard and number pad input arrive here because the window is first responder.
        if let calculatorInput = KeyInputMapper.calculatorInput(from: event) {
            controller.press(calculatorInput)
        } else {
            super.keyDown(with: event)
        }
    }
}

final class CalculatorViewController: NSViewController {
    var onFloatChanged: ((Bool) -> Void)?

    private let display = NSTextField(labelWithString: "0")
    private let expressionLabel = NSTextField(labelWithString: "")
    private let floatToggle = NSButton(checkboxWithTitle: "Float", target: nil, action: nil)
    private var engine = CalculatorEngine()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
        updateDisplay()
    }

    private func buildInterface() {
        expressionLabel.font = .systemFont(ofSize: 13, weight: .medium)
        expressionLabel.textColor = .secondaryLabelColor
        expressionLabel.alignment = .right
        expressionLabel.lineBreakMode = .byTruncatingHead
        expressionLabel.translatesAutoresizingMaskIntoConstraints = false

        display.font = .monospacedDigitSystemFont(ofSize: 30, weight: .regular)
        display.textColor = .labelColor
        display.alignment = .right
        display.lineBreakMode = .byTruncatingHead
        display.maximumNumberOfLines = 1
        display.translatesAutoresizingMaskIntoConstraints = false

        floatToggle.state = .on
        floatToggle.target = self
        floatToggle.action = #selector(floatChanged)
        floatToggle.translatesAutoresizingMaskIntoConstraints = false

        let header = NSStackView(views: [expressionLabel, display])
        header.orientation = .vertical
        header.alignment = .trailing
        header.spacing = 4
        header.translatesAutoresizingMaskIntoConstraints = false

        // The keypad uses explicit constraints so all columns and rows stay aligned,
        // independent of label length such as "C", "⌫", or operation symbols.
        let buttons = [
            ["C", "⌫", "%", "÷"],
            ["7", "8", "9", "×"],
            ["4", "5", "6", "-"],
            ["1", "2", "3", "+"],
            ["±", "0", ".", "="]
        ]

        let keypad = makeKeypad(rows: buttons)

        let root = NSStackView(views: [floatToggle, header, keypad])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 10
        root.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        root.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            root.topAnchor.constraint(equalTo: view.topAnchor),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            expressionLabel.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -24),
            display.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -24),
            keypad.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -24)
        ])
    }

    private func makeKeypad(rows: [[String]]) -> NSView {
        let keypad = NSView()
        keypad.translatesAutoresizingMaskIntoConstraints = false

        let buttons = rows.map { row in
            row.map { title -> CalculatorButton in
                let button = makeButton(title)
                keypad.addSubview(button)
                return button
            }
        }

        let spacing: CGFloat = 6
        var constraints = [NSLayoutConstraint]()

        for rowIndex in buttons.indices {
            for columnIndex in buttons[rowIndex].indices {
                let button = buttons[rowIndex][columnIndex]

                if rowIndex == buttons.startIndex {
                    constraints.append(button.topAnchor.constraint(equalTo: keypad.topAnchor))
                } else {
                    constraints.append(button.topAnchor.constraint(equalTo: buttons[rowIndex - 1][columnIndex].bottomAnchor, constant: spacing))
                    constraints.append(button.heightAnchor.constraint(equalTo: buttons[rowIndex - 1][columnIndex].heightAnchor))
                }

                if columnIndex == buttons[rowIndex].startIndex {
                    constraints.append(button.leadingAnchor.constraint(equalTo: keypad.leadingAnchor))
                } else {
                    constraints.append(button.leadingAnchor.constraint(equalTo: buttons[rowIndex][columnIndex - 1].trailingAnchor, constant: spacing))
                    constraints.append(button.widthAnchor.constraint(equalTo: buttons[rowIndex][columnIndex - 1].widthAnchor))
                }

                if rowIndex == buttons.index(before: buttons.endIndex) {
                    constraints.append(button.bottomAnchor.constraint(equalTo: keypad.bottomAnchor))
                }

                if columnIndex == buttons[rowIndex].index(before: buttons[rowIndex].endIndex) {
                    constraints.append(button.trailingAnchor.constraint(equalTo: keypad.trailingAnchor))
                }
            }
        }

        constraints.append(keypad.heightAnchor.constraint(equalToConstant: 224))
        NSLayoutConstraint.activate(constraints)
        return keypad
    }

    private func makeButton(_ title: String) -> CalculatorButton {
        let button = CalculatorButton(title: title, target: self, action: #selector(buttonPressed(_:)))
        button.keyStyle = buttonStyle(for: title)
        button.font = .systemFont(ofSize: 17, weight: buttonWeight(for: title))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return button
    }

    private func buttonStyle(for title: String) -> CalculatorButton.KeyStyle {
        if ["C", "⌫", "%"].contains(title) {
            return .function
        }

        if ["÷", "×", "-", "+", "="].contains(title) {
            return .operation
        }

        return .number
    }

    private func buttonWeight(for title: String) -> NSFont.Weight {
        ["÷", "×", "-", "+", "="].contains(title) ? .semibold : .regular
    }

    @objc private func buttonPressed(_ sender: NSButton) {
        press(sender.title)

        // AppKit can leave a custom layer-backed button visually highlighted after
        // mouse tracking; reset after the action so Clear and other keys repaint.
        (sender as? CalculatorButton)?.resetHighlight()
    }

    @objc private func floatChanged() {
        onFloatChanged?(floatToggle.state == .on)
    }

    func press(_ input: String) {
        engine.press(input)
        updateDisplay()
    }

    private func updateDisplay() {
        display.stringValue = engine.display
        expressionLabel.stringValue = engine.expression
    }
}

final class CalculatorButton: NSButton {
    enum KeyStyle {
        case number
        case function
        case operation
    }

    var keyStyle = KeyStyle.number {
        didSet {
            updateStyle()
        }
    }

    override var isHighlighted: Bool {
        didSet {
            updateStyle()
        }
    }

    override var font: NSFont? {
        didSet {
            updateStyle()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    convenience init(title: String, target: AnyObject?, action: Selector?) {
        self.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        updateStyle()
    }

    private func configure() {
        isBordered = false
        setButtonType(.momentaryChange)
        bezelStyle = .regularSquare
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.masksToBounds = true
        focusRingType = .none
        updateStyle()
    }

    override func mouseDown(with event: NSEvent) {
        isHighlighted = true
        super.mouseDown(with: event)
        resetHighlight()
    }

    func resetHighlight() {
        isHighlighted = false
        updateStyle()
    }

    private func updateStyle() {
        let palette = palette(for: keyStyle)

        layer?.backgroundColor = (isHighlighted ? palette.highlightedBackground : palette.background).cgColor
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: palette.foreground,
                .font: font ?? NSFont.systemFont(ofSize: 17)
            ]
        )
    }

    private func palette(for style: KeyStyle) -> (background: NSColor, highlightedBackground: NSColor, foreground: NSColor) {
        switch style {
        case .number:
            return (
                background: NSColor(calibratedWhite: 0.86, alpha: 1.0),
                highlightedBackground: NSColor(calibratedWhite: 0.76, alpha: 1.0),
                foreground: .labelColor
            )
        case .function:
            return (
                background: NSColor(calibratedWhite: 0.74, alpha: 1.0),
                highlightedBackground: NSColor(calibratedWhite: 0.64, alpha: 1.0),
                foreground: .labelColor
            )
        case .operation:
            return (
                background: NSColor(calibratedRed: 0.97, green: 0.61, blue: 0.18, alpha: 1.0),
                highlightedBackground: NSColor(calibratedRed: 0.86, green: 0.47, blue: 0.09, alpha: 1.0),
                foreground: .white
            )
        }
    }
}

enum KeyInputMapper {
    static func calculatorInput(from event: NSEvent) -> String? {
        // Delete/backspace is more reliable by keyCode than by character across keyboards.
        if event.keyCode == 51 {
            return "⌫"
        }

        // Numeric keypad Enter uses a distinct key code from the main Return key.
        if event.keyCode == 76 {
            return "="
        }

        guard let rawInput = event.charactersIgnoringModifiers else {
            return nil
        }

        switch rawInput {
        // Number row and number pad both produce these characters, so one mapping covers both.
        case "0"..."9":
            return rawInput
        case ".":
            return "."
        case "+", "-":
            return rawInput
        case "*":
            return "×"
        case "/":
            return "÷"
        case "=", "\r", "\n":
            return "="
        case "%":
            return "%"
        case "\u{1b}", "c", "C":
            return "C"
        default:
            return nil
        }
    }
}

struct CalculatorEngine {
    private(set) var display = "0"
    private(set) var expression = ""

    // The engine keeps one stored left-hand value plus one pending operation, which is
    // enough for standard four-function calculator behavior.
    private var pendingOperation: String?
    private var storedValue: Decimal?
    private var repeatedOperation: (operation: String, operand: Decimal)?
    private var shouldStartNewNumber = true
    private var justEvaluated = false

    mutating func press(_ input: String) {
        switch input {
        case "0"..."9":
            appendDigit(input)
        case ".":
            appendDecimalPoint()
        case "+", "-", "×", "÷":
            setOperation(input)
        case "=":
            evaluate()
        case "C":
            clear()
        case "⌫":
            backspace()
        case "±":
            toggleSign()
        case "%":
            percent()
        default:
            break
        }
    }

    private mutating func appendDigit(_ digit: String) {
        if shouldStartNewNumber || display == "0" || justEvaluated {
            display = digit
            shouldStartNewNumber = false
            repeatedOperation = nil
            justEvaluated = false
            return
        }

        if display.count < 16 {
            display += digit
        }
    }

    private mutating func appendDecimalPoint() {
        if shouldStartNewNumber || justEvaluated {
            display = "0."
            shouldStartNewNumber = false
            repeatedOperation = nil
            justEvaluated = false
        } else if !display.contains(".") {
            display += "."
        }
    }

    private mutating func setOperation(_ operation: String) {
        let current = decimalValue

        // Chained operations evaluate left-to-right as desktop calculators usually do:
        // pressing 2 + 3 + shows 5 and keeps + pending for the next number.
        if let pendingOperation, let storedValue, !shouldStartNewNumber {
            let result = calculate(storedValue, current, pendingOperation)
            self.storedValue = result
            display = format(result)
        } else {
            storedValue = current
        }

        pendingOperation = operation
        repeatedOperation = nil
        shouldStartNewNumber = true
        justEvaluated = false
        expression = "\(display) \(operation)"
    }

    private mutating func evaluate() {
        if let operation = pendingOperation, let storedValue {
            let rightValue = decimalValue
            let result = calculate(storedValue, rightValue, operation)
            expression = "\(format(storedValue)) \(operation) \(format(rightValue)) ="
            display = format(result)
            pendingOperation = nil
            self.storedValue = nil
            repeatedOperation = (operation, rightValue)
            shouldStartNewNumber = true
            justEvaluated = true
            return
        }

        if justEvaluated, let repeatedOperation {
            let leftValue = decimalValue
            let result = calculate(leftValue, repeatedOperation.operand, repeatedOperation.operation)
            expression = "\(format(leftValue)) \(repeatedOperation.operation) \(format(repeatedOperation.operand)) ="
            display = format(result)
            shouldStartNewNumber = true
            justEvaluated = true
            return
        }

        shouldStartNewNumber = true
        justEvaluated = true
    }

    private mutating func clear() {
        display = "0"
        expression = ""
        pendingOperation = nil
        storedValue = nil
        repeatedOperation = nil
        shouldStartNewNumber = true
        justEvaluated = false
    }

    private mutating func backspace() {
        guard !shouldStartNewNumber, !justEvaluated else {
            display = "0"
            return
        }

        if display.count <= 1 || (display.count == 2 && display.hasPrefix("-")) {
            display = "0"
            shouldStartNewNumber = true
        } else {
            display.removeLast()
        }
    }

    private mutating func toggleSign() {
        guard display != "0" else { return }

        if display.hasPrefix("-") {
            display.removeFirst()
        } else {
            display = "-\(display)"
        }
    }

    private mutating func percent() {
        display = format(decimalValue / 100)
    }

    private var decimalValue: Decimal {
        Decimal(string: display) ?? 0
    }

    private func calculate(_ left: Decimal, _ right: Decimal, _ operation: String) -> Decimal {
        switch operation {
        case "+":
            left + right
        case "-":
            left - right
        case "×":
            left * right
        case "÷":
            right == 0 ? 0 : left / right
        default:
            right
        }
    }

    private func format(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        if number == .notANumber {
            return "Error"
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 10
        formatter.minimumFractionDigits = 0

        let text = formatter.string(from: number) ?? "0"
        return text == "-0" ? "0" : text
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
