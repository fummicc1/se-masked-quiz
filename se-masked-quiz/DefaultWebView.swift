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

    let htmlContent: String

    func makeUIView(context: Context) -> UIViewType {
        let view = UIViewType()
        view.loadHTMLString(parse(html: htmlContent), baseURL: nil)
        return view
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        uiView.loadHTMLString(parse(html: htmlContent), baseURL: nil)
    }
}
#endif

#if canImport(AppKit)
import AppKit

struct DefaultWebView: NSViewRepresentable {
    typealias NSViewType = WKWebView
    
    let htmlContent: HTMLContent
    let onNavigate: (URL) -> Void

    func makeNSView(context: Context) -> NSViewType {
        let view = NSViewType()
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
        Coordinator(onNavigate: onNavigate)
    }
    
    final class Coordinator: NSObject {
        let onNavigate: (URL) -> Void
        
        init(onNavigate: @escaping (URL) -> Void) {
            self.onNavigate = onNavigate
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
            </style>
        </HEAD>
        <BODY>
    """

    let codeRegex = "<code.*?>"
    let contentWithCodeStyling = htmlContent.replacingOccurrences(
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
        if let destinationURL = navigationAction.request.url {
            onNavigate(destinationURL)
        }
        return webView.url?.absoluteString == "about:blank" ? .cancel : .allow
    }
}
