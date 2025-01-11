//
//  DefaultWebView.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/01.
//

import SwiftUI
import WebKit

enum HTMLContent {
    case string(String)
    case url(URL)
    
    var content: String {
        get async {
            switch self {
            case .string(let string):
                return string
            case .url(let url):
                // Launch a task to load on background thread.
                let loadingTask = Task {
                    try Data(contentsOf: url)
                }
                guard let data = try? await loadingTask.value else {
                    return ""
                }
                return String(data: data, encoding: .utf8) ?? ""
            }
        }
    }
    
    var url: URL? {
        switch self {
        case .url(let url):
            return url
        default:
            return nil
        }
    }
}

#if canImport(UIKit)
import UIKit

struct DefaultWebView: UIViewRepresentable {
    typealias UIViewType = WKWebView

    let htmlContent: HTMLContent
    let onNavigate: (URL) -> Void
    let onMaskedWordTap: (Int) -> Void

    func makeUIView(context: Context) -> UIViewType {
        let config = WKWebViewConfiguration()
        let userScript = WKUserScript(
            source: """
            document.addEventListener('click', function(e) {
                console.log('Click event detected:', e.target);
                if (e.target.classList.contains('masked-word')) {
                    console.log('Masked word clicked:', e.target.dataset.maskIndex);
                    window.webkit.messageHandlers.maskedWordTapped.postMessage({
                        maskIndex: parseInt(e.target.dataset.maskIndex)
                    });
                }
            });
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(userScript)
        config.userContentController.add(context.coordinator, name: "maskedWordTapped")
        
        let view = UIViewType(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        
        // デバッグ用のコンソールメッセージを有効化
        view.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        Task {
            await view.loadHtmlContent(htmlContent)
        }
        return view
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        Task {
            await uiView.loadHtmlContent(htmlContent)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        .init(
            onNavigate: onNavigate,
            onMaskedWordTap: onMaskedWordTap
        )
    }
    
    final class Coordinator: NSObject {
        let onNavigate: (URL) -> Void
        let onMaskedWordTap: (Int) -> Void
        
        init(
            onNavigate: @escaping (URL) -> Void,
            onMaskedWordTap: @escaping (Int) -> Void
        ) {
            self.onNavigate = onNavigate
            self.onMaskedWordTap = onMaskedWordTap
        }
    }
}
#endif

#if canImport(AppKit)
import AppKit

struct DefaultWebView: NSViewRepresentable {
    typealias NSViewType = WKWebView
    
    let htmlContent: HTMLContent
    let onNavigate: (URL) -> Void
    let onMaskedWordTap: (Int) -> Void

    func makeNSView(context: Context) -> NSViewType {
        let config = WKWebViewConfiguration()
        let userScript = WKUserScript(
            source: """
            document.addEventListener('click', function(e) {
                console.log('Click event detected:', e.target);
                if (e.target.classList.contains('masked-word')) {
                    console.log('Masked word clicked:', e.target.dataset.maskIndex);
                    window.webkit.messageHandlers.maskedWordTapped.postMessage({
                        maskIndex: parseInt(e.target.dataset.maskIndex)
                    });
                }
            });
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(userScript)
        config.userContentController.add(context.coordinator, name: "maskedWordTapped")
        
        let view = NSViewType(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        Task {
            await view.loadHtmlContent(htmlContent)
        }
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        Task {
            await nsView.loadHtmlContent(htmlContent)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onNavigate: onNavigate, onMaskedWordTap: onMaskedWordTap)
    }
    
    final class Coordinator: NSObject {
        let onNavigate: (URL) -> Void
        let onMaskedWordTap: (Int) -> Void
        
        init(onNavigate: @escaping (URL) -> Void, onMaskedWordTap: @escaping (Int) -> Void) {
            self.onNavigate = onNavigate
            self.onMaskedWordTap = onMaskedWordTap
        }
    }
}
#endif

fileprivate extension WKWebView {
    func loadHtmlContent(_ htmlContent: HTMLContent) async {
        if let url = htmlContent.url {
            load(URLRequest(url: url))
        } else {
            loadHTMLString(await parse(html: htmlContent), baseURL: nil)
        }
    }
}

// ref: https://designcode.io/swiftui-advanced-handbook-code-highlighting-in-a-webview
fileprivate func parse(html: HTMLContent) async -> String {
    let htmlContent = await html.content
    if case .url = html {
        // if the content is from URL, we don't need to add any styling.
        return htmlContent
    }
    
    // HTMLエスケープを解除
    let unescapedContent = htmlContent
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&#39;", with: "'")
        .replacingOccurrences(of: "&amp;", with: "&")
    
    let htmlStart = """
        <HTML>
        <HEAD>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/10.7.2/styles/atom-one-dark.min.css">
            <style>
                * {
                    font-family: -apple-system, BlinkMacSystemFont, SF Mono, Menlo, monospace;
                }
                body {
                    font-size: 20px;
                    line-height: 1.6;
                    padding: 16px;
                    color: #333;
                }
                pre {
                    margin: 16px 0;
                    border-radius: 8px;
                    background: #282c34;
                }
                pre code {
                    display: block;
                    overflow-x: auto;
                    padding: 16px;
                    font-size: 15px;
                    line-height: 1.4;
                    font-weight: 500;
                    white-space: pre;
                }
                code:not(pre code) {
                    font-size: 0.9em;
                    background: #f0f0f0;
                    padding: 2px 6px;
                    border-radius: 4px;
                    color: #e06c75;
                }
                .masked-word {
                    background-color: #000;
                    color: #fff;
                    padding: 2px 6px;
                    border-radius: 4px;
                    cursor: pointer;
                    user-select: none;
                    display: inline-block;  /* インライン要素をブロック化してクリック領域を確保 */
                    pointer-events: auto;   /* クリックイベントを確実に有効化 */
                }
                .masked-word:hover {
                    background-color: #333;
                }
            </style>
            <script>
                function wrapMaskedWords() {
                    const text = document.body.innerHTML;
                    const pattern = /(◻︎)+/g;
                    let maskIndex = 0;
                    const wrappedText = text.replace(pattern, function(match) {
                        return `<span class="masked-word" data-mask-index="${maskIndex++}">${match}</span>`;
                    });
                    document.body.innerHTML = wrappedText;
                    
                    console.log('Total masked groups:', maskIndex);
                }
                window.addEventListener('load', wrapMaskedWords);
            </script>
        </HEAD>
        <BODY>
    """

    let codeRegex = "<code.*?>"
    let contentWithCodeStyling = unescapedContent.replacingOccurrences(
        of: codeRegex,
        with: "$0",
        options: .regularExpression,
        range: nil
    )

    let htmlEnd = """
        <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/10.7.2/highlight.min.js"></script>
        <script>
            hljs.highlightAll();
        </script>
        </BODY>
        </HTML>
    """

    return htmlStart + contentWithCodeStyling + htmlEnd
}

extension DefaultWebView.Coordinator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        let isOriginal = navigationAction.request.url?.absoluteString == "about:blank"
        if isOriginal {
            return .allow
        }
        let canShowOnThisWebView = webView.url?.absoluteString != "about:blank"
        if canShowOnThisWebView {
            return .allow
        }
        if let destinationURL = navigationAction.request.url {
            onNavigate(destinationURL)
        }
        return .cancel
    }
}

extension DefaultWebView.Coordinator: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "maskedWordTapped",
           let body = message.body as? [String: Any],
           let maskIndex = body["maskIndex"] as? Int {
            onMaskedWordTap(maskIndex)
        }
    }
}
