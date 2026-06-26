import Foundation

struct NoopSignProvider: SignProvider {
    func makeSign() -> String { "" }
}
