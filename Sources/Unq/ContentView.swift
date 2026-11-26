import SwiftUI

struct ContentView: View {
    var body: some View {
        WebView()
            .background(Color.black)
    }
}

/// Hosts the UIKit web view controller in SwiftUI.
struct WebView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> WebViewController {
        WebViewController()
    }

    func updateUIViewController(_ controller: WebViewController, context: Context) {}
}
