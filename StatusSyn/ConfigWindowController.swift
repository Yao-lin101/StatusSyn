import Cocoa

class ConfigWindowController: NSWindowController {
    
    private var baseURLField: NSTextView!
    private var characterKeyField: NSTextView!
    private var saveButton: NSButton!
    
    static let shared = ConfigWindowController()
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "配置"
        window.center()
        
        super.init(window: window)
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        guard let window = self.window else { return }
        
        // 添加编辑菜单
        let mainMenu = NSApp.mainMenu ?? NSMenu()
        let editMenu = NSMenu(title: "编辑")
        let editMenuItem = NSMenuItem(title: "编辑", action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu
        
        // 添加编辑菜单项
        editMenu.addItem(withTitle: "撤销", action: Selector("undo:"), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector("redo:"), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        
        if NSApp.mainMenu == nil {
            NSApp.mainMenu = mainMenu
        }
        if mainMenu.item(withTitle: "编辑") == nil {
            mainMenu.addItem(editMenuItem)
        }
        
        let contentView = window.contentView!
        
        // Base URL Label
        let baseURLLabel = NSTextField(labelWithString: "Base URL:")
        baseURLLabel.frame = NSRect(x: 20, y: 160, width: 100, height: 20)
        contentView.addSubview(baseURLLabel)
        
        // Base URL Field Container
        let baseURLContainer = NSScrollView(frame: NSRect(x: 120, y: 160, width: 260, height: 20))
        baseURLContainer.hasVerticalScroller = false
        baseURLContainer.hasHorizontalScroller = false
        baseURLContainer.borderType = .bezelBorder
        
        // Base URL Field
        baseURLField = CustomTextView(frame: NSRect(x: 0, y: 0, width: 260, height: 20))
        baseURLField.isHorizontallyResizable = false
        baseURLField.isVerticallyResizable = false
        baseURLField.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: 20)
        baseURLField.minSize = NSSize(width: 0, height: 20)
        baseURLField.textContainer?.widthTracksTextView = true
        baseURLField.textContainer?.heightTracksTextView = true
        baseURLField.delegate = self
        baseURLField.isRichText = false
        baseURLField.isEditable = true
        baseURLField.isSelectable = true
        baseURLContainer.documentView = baseURLField
        contentView.addSubview(baseURLContainer)
        
        // Character Key Label
        let characterKeyLabel = NSTextField(labelWithString: "Character Key:")
        characterKeyLabel.frame = NSRect(x: 20, y: 120, width: 100, height: 20)
        contentView.addSubview(characterKeyLabel)
        
        // Character Key Field Container
        let characterKeyContainer = NSScrollView(frame: NSRect(x: 120, y: 120, width: 260, height: 20))
        characterKeyContainer.hasVerticalScroller = false
        characterKeyContainer.hasHorizontalScroller = false
        characterKeyContainer.borderType = .bezelBorder
        
        // Character Key Field
        characterKeyField = CustomTextView(frame: NSRect(x: 0, y: 0, width: 260, height: 20))
        characterKeyField.isHorizontallyResizable = false
        characterKeyField.isVerticallyResizable = false
        characterKeyField.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: 20)
        characterKeyField.minSize = NSSize(width: 0, height: 20)
        characterKeyField.textContainer?.widthTracksTextView = true
        characterKeyField.textContainer?.heightTracksTextView = true
        characterKeyField.delegate = self
        characterKeyField.isRichText = false
        characterKeyField.isEditable = true
        characterKeyField.isSelectable = true
        characterKeyContainer.documentView = characterKeyField
        contentView.addSubview(characterKeyContainer)
        
        // Save Button
        saveButton = NSButton(frame: NSRect(x: 280, y: 20, width: 100, height: 32))
        saveButton.title = "保存"
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveConfig)
        saveButton.keyEquivalent = "\r"  // Enter 键
        contentView.addSubview(saveButton)
        
        // Cancel Button
        let cancelButton = NSButton(frame: NSRect(x: 180, y: 20, width: 100, height: 32))
        cancelButton.title = "取消"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelConfig)
        contentView.addSubview(cancelButton)
        
        // 加载保存的配置
        baseURLField.string = UserDefaults.standard.string(forKey: "baseURL") ?? ""
        characterKeyField.string = UserDefaults.standard.string(forKey: "characterKey") ?? ""
        
        // 初始化保存按钮状态
        updateSaveButtonState()
        
        // 设置窗口为第一响应者
        window.makeFirstResponder(baseURLField)
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        window?.delegate = self
    }
    
    private func updateSaveButtonState() {
        saveButton.isEnabled = !(baseURLField.string.isEmpty) && !(characterKeyField.string.isEmpty)
    }
    
    @objc private func saveConfig() {
        guard !(baseURLField.string.isEmpty) && !(characterKeyField.string.isEmpty) else {
            let alert = NSAlert()
            alert.messageText = "配置无效"
            alert.informativeText = "请填写所有必要的配置信息"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.beginSheetModal(for: window!) { _ in }
            return
        }
        
        // 保存配置
        UserDefaults.standard.set(baseURLField.string, forKey: "baseURL")
        UserDefaults.standard.set(characterKeyField.string, forKey: "characterKey")
        
        // 发送配置更新通知
        NotificationCenter.default.post(name: .configDidChange, object: nil)
        
        window?.close()
    }
    
    @objc private func cancelConfig() {
        window?.close()
    }
}

// MARK: - NSTextViewDelegate
extension ConfigWindowController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        updateSaveButtonState()
    }
    
    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        return false
    }
    
    func textViewDidChangeSelection(_ notification: Notification) {
    }
}

// MARK: - NSWindowDelegate
extension ConfigWindowController: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        window?.makeFirstResponder(baseURLField)
    }
    
    func windowDidResignKey(_ notification: Notification) {
    }
}

extension Notification.Name {
    static let configDidChange = Notification.Name("configDidChange")
}

// 自定义 NSTextView 子类来处理编辑命令
class CustomTextView: NSTextView {
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        self.allowsUndo = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.allowsUndo = true
    }
    
    convenience override init(frame frameRect: NSRect) {
        let container = NSTextContainer(containerSize: frameRect.size)
        let layoutManager = NSLayoutManager()
        let storage = NSTextStorage()
        
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        
        self.init(frame: frameRect, textContainer: container)
    }
    
    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(NSText.copy(_:)) {
            return self.selectedRange().length > 0
        }
        if item.action == #selector(NSText.paste(_:)) {
            return NSPasteboard.general.string(forType: .string) != nil
        }
        if item.action == #selector(NSText.cut(_:)) {
            return self.selectedRange().length > 0 && self.isEditable
        }
        if item.action == #selector(NSText.selectAll(_:)) {
            return true
        }
        if item.action == #selector(NSText.delete(_:)) {
            return self.selectedRange().length > 0 && self.isEditable
        }
        if item.action == Selector("undo:") {
            return self.undoManager?.canUndo ?? false
        }
        if item.action == Selector("redo:") {
            return self.undoManager?.canRedo ?? false
        }
        return super.validateUserInterfaceItem(item)
    }
    
    override func copy(_ sender: Any?) {
        super.copy(sender)
    }
    
    override func paste(_ sender: Any?) {
        super.paste(sender)
    }
    
    override func cut(_ sender: Any?) {
        super.cut(sender)
    }
    
    override func selectAll(_ sender: Any?) {
        super.selectAll(sender)
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func becomeFirstResponder() -> Bool {
        return super.becomeFirstResponder()
    }
    
    override func resignFirstResponder() -> Bool {
        return super.resignFirstResponder()
    }
    
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            switch event.characters?.lowercased() {
            case "a":
                self.selectAll(nil)
                return
            case "c":
                self.copy(nil)
                return
            case "v":
                self.paste(nil)
                return
            case "x":
                self.cut(nil)
                return
            case "z":
                if event.modifierFlags.contains(.shift) {
                    self.undoManager?.redo()
                } else {
                    self.undoManager?.undo()
                }
                return
            default:
                break
            }
        }
        
        super.keyDown(with: event)
    }
} 