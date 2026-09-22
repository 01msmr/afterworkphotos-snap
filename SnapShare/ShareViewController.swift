import UIKit
import SnapCore

/// "Share with Snap": takes the first photo shared (any more are ignored),
/// puts its original file — EXIF and GPS intact — on the handoff pasteboard
/// and opens Snap, which picks it up like the Upload button's pick. No UI of
/// its own beyond a dark sheet for the moment it takes.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task {
            if let data = await firstPhoto() {
                UIPasteboard(name: UIPasteboard.Name(Handoff.pasteboard), create: true)?
                    .setData(data, forPasteboardType: Handoff.pasteboardType)
                openSnap()
            }
            extensionContext?.completeRequest(returningItems: nil)
        }
    }

    /// The original file of the first image attachment, read while the
    /// provider's temporary URL is still valid.
    private func firstPhoto() async -> Data? {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        for provider in items.flatMap({ $0.attachments ?? [] }) {
            guard let type = Handoff.imageType(in: provider.registeredTypeIdentifiers) else { continue }
            return await withCheckedContinuation { done in
                _ = provider.loadFileRepresentation(forTypeIdentifier: type) { url, _ in
                    done.resume(returning: url.flatMap { try? Data(contentsOf: $0) })
                }
            }
        }
        return nil
    }

    /// Extensions may not open their app — `UIApplication.open` is off
    /// limits here — so the call goes up the responder chain by selector.
    /// Fine for an app that never meets App Review; if iOS refuses, the
    /// photo waits on the pasteboard until Snap is opened by hand.
    private func openSnap() {
        let selector = sel_registerName("openURL:options:completionHandler:")
        var responder: UIResponder? = self
        while let r = responder {
            if let app = r as? UIApplication, app.responds(to: selector) {
                // Typed call, nil completion — `perform(_:with:with:)` would
                // leave the third argument as whatever sat in the register.
                typealias Open = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, AnyObject?) -> Void
                let open = unsafeBitCast(app.method(for: selector), to: Open.self)
                open(app, selector, Handoff.url as NSURL, [:] as NSDictionary, nil)
                return
            }
            responder = r.next
        }
    }
}
