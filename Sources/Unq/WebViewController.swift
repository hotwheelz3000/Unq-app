@preconcurrency import WebKit
import UIKit

/// Full-screen web view of unqx.site/sclib with a native Paste button. Signed
/// .shortcut downloads are saved and handed to the share sheet so they open
/// straight in Shortcuts.
final class WebViewController: UIViewController {
    static let homeURL = URL(string: "https://unqx.site/sclib/") ?? URL(filePath: "/")

    // unqforge palette (from the site's wordmark).
    static let charcoal = UIColor(red: 0x1E / 255.0, green: 0x1D / 255.0, blue: 0x19 / 255.0, alpha: 1)
    static let cream = UIColor(red: 0xE9 / 255.0, green: 0xE3 / 255.0, blue: 0xD5 / 255.0, alpha: 1)

    private var webView: WKWebView!
    private let pasteButton = UIButton(type: .system)
    private let toast = UILabel()
    private var downloadFiles: [ObjectIdentifier: URL] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        // Charcoal, not black, so no dark strip shows below or above the page.
        view.backgroundColor = Self.charcoal

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.userContentController.addUserScript(
            WKUserScript(source: PasteScript.source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = Self.charcoal
        webView.scrollView.backgroundColor = Self.charcoal
        webView.underPageBackgroundColor = Self.charcoal
        webView.translatesAutoresizingMaskIntoConstraints = false

        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(reloadPage(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        view.addSubview(webView)
        setUpPasteButton()
        setUpToast()

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        webView.load(URLRequest(url: Self.homeURL))
    }

    // MARK: Paste button

    private func setUpPasteButton() {
        var config = UIButton.Configuration.filled()
        config.title = L10n.pasteButton
        config.image = UIImage(systemName: "doc.on.clipboard")
        config.imagePadding = 4
        config.buttonSize = .small
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        config.cornerStyle = .capsule
        // unqforge logo palette: charcoal button, cream text and outline.
        config.baseBackgroundColor = Self.charcoal
        config.baseForegroundColor = Self.cream
        config.background.strokeColor = Self.cream
        config.background.strokeWidth = 1
        pasteButton.configuration = config
        pasteButton.accessibilityHint = L10n.pasteHint
        pasteButton.layer.shadowColor = UIColor.black.cgColor
        pasteButton.layer.shadowOpacity = 0.4
        pasteButton.layer.shadowRadius = 6
        pasteButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        pasteButton.addTarget(self, action: #selector(pasteTapped), for: .touchUpInside)
        pasteButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pasteButton)

        NSLayoutConstraint.activate([
            pasteButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            pasteButton.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -16),
        ])
    }

    @objc private func pasteTapped() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            showToast(L10n.clipboardEmpty)
            return
        }
        Task { @MainActor in
            do {
                let result = try await webView.callAsyncJavaScript(
                    "return window.__unqPaste ? window.__unqPaste(text) : 'none';",
                    arguments: ["text": text],
                    in: nil,
                    contentWorld: .page
                )
                let kind = result as? String ?? "none"
                showToast(kind == "none" ? L10n.editorNotFound : L10n.pasted)
            } catch {
                showToast(L10n.editorNotFound)
            }
        }
    }

    // MARK: Toast

    private func setUpToast() {
        toast.font = .preferredFont(forTextStyle: .subheadline)
        toast.textColor = .white
        toast.backgroundColor = UIColor(white: 0.15, alpha: 0.95)
        toast.textAlignment = .center
        toast.layer.cornerRadius = 14
        toast.layer.masksToBounds = true
        toast.alpha = 0
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)

        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: pasteButton.topAnchor, constant: -12),
            toast.heightAnchor.constraint(equalToConstant: 32),
            toast.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
        ])
    }

    private func showToast(_ message: String) {
        toast.text = "  \(message)  "
        UIAccessibility.post(notification: .announcement, argument: message)
        UIView.animate(withDuration: 0.2) { self.toast.alpha = 1 }
        UIView.animate(withDuration: 0.3, delay: 1.6, options: []) { self.toast.alpha = 0 }
    }

    // MARK: Reload

    @objc private func reloadPage(_ sender: UIRefreshControl) {
        if webView.url == nil {
            webView.load(URLRequest(url: Self.homeURL))
        } else {
            webView.reload()
        }
        sender.endRefreshing()
    }

    // MARK: Opening downloaded files

    private func presentShareSheet(for fileURL: URL) {
        let sheet = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = pasteButton
        let presenter = presentedViewController ?? self
        presenter.present(sheet, animated: true)
    }

    private func isOwnSite(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return true }
        return host == "unqx.site" || host.hasSuffix(".unqx.site")
    }
}

// MARK: - Navigation

extension WebViewController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
            return
        }
        let url = navigationAction.request.url
        let scheme = url?.scheme?.lowercased() ?? ""
        // A .shortcut file stays in the app (it's downloaded below), whatever host serves it.
        if url?.pathExtension.lowercased() == "shortcut" {
            decisionHandler(.allow)
            return
        }
        // Links that leave the site in the main frame open in Safari (or their app).
        if navigationAction.targetFrame?.isMainFrame ?? true,
           navigationAction.navigationType == .linkActivated,
           ["http", "https"].contains(scheme),
           !isOwnSite(url),
           let url {
            decisionHandler(.cancel)
            Task { @MainActor in _ = await UIApplication.shared.open(url) }
            return
        }
        if !["http", "https", "blob", "data", "about"].contains(scheme), let url {
            decisionHandler(.cancel)
            Task { @MainActor in _ = await UIApplication.shared.open(url) }
            return
        }
        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void
    ) {
        let response = navigationResponse.response
        let isAttachment = (response as? HTTPURLResponse)
            .flatMap { $0.value(forHTTPHeaderField: "Content-Disposition") }?
            .lowercased()
            .contains("attachment") ?? false
        let isShortcut = response.url?.pathExtension.lowercased() == "shortcut"
            || response.suggestedFilename?.lowercased().hasSuffix(".shortcut") == true
        if isAttachment || isShortcut || !navigationResponse.canShowMIMEType {
            decisionHandler(.download)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}

// MARK: - Downloads

extension WebViewController: WKDownloadDelegate {
    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping @MainActor @Sendable (URL?) -> Void
    ) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            completionHandler(nil)
            return
        }
        let name = suggestedFilename.isEmpty ? "download.shortcut" : suggestedFilename
        let file = folder.appendingPathComponent(name)
        downloadFiles[ObjectIdentifier(download)] = file
        completionHandler(file)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let file = downloadFiles.removeValue(forKey: ObjectIdentifier(download)) else { return }
        presentShareSheet(for: file)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloadFiles.removeValue(forKey: ObjectIdentifier(download))
        showToast(L10n.downloadFailed)
    }
}

// MARK: - Pop-ups and dialogs

extension WebViewController: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // target="_blank" / window.open: stay in the app for the site, Safari otherwise.
        if let url = navigationAction.request.url {
            if isOwnSite(url) || ["blob", "data"].contains(url.scheme?.lowercased() ?? "") {
                webView.load(navigationAction.request)
            } else {
                Task { @MainActor in _ = await UIApplication.shared.open(url) }
            }
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor @Sendable () -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.ok, style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor @Sendable (Bool) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.cancel, style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: L10n.ok, style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }
}
