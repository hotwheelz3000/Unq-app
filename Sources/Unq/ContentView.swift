import SwiftUI

struct ContentView: View {
    var body: some View {
        // Fill the whole screen (under the clock and home bar) in the site's
        // charcoal, so no black strips show above or below the page.
        WebView()
            .ignoresSafeArea()
            .background(Color(red: 0x1E / 255.0, green: 0x1D / 255.0, blue: 0x19 / 255.0))
    }
}

/// Hosts the UIKit web view controller in SwiftUI.
struct WebView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> WebViewController {
        WebViewController()
    }

    func updateUIViewController(_ controller: WebViewController, context: Context) {}
}
