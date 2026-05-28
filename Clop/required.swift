// Ziben custom: stub replacing upstream's private (gitignored) license-verification file.
// Fully unlocked fork: every requirement check passes and license enforcement is a no-op.
import Cocoa

// Always Pro in this unlocked fork.
@inline(__always) var proactive: Bool {
    true
}

func validReq() -> Bool {
    true
}

@discardableResult
func invalidReq(_: [Any], _: NSWindow?) -> Bool {
    false
}

@discardableResult
func invalidReq2(_: [Any], _: NSWindow?) -> Bool {
    false
}

@discardableResult
func invalidReq3(_: [Any], _: NSWindow?) -> Bool {
    false
}

func hasShortcutsDB() -> Bool {
    true
}
