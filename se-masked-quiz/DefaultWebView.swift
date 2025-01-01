//
//  DefaultWebView.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/01.
//

import SwiftUI
import WebKit

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
    
    let htmlContent: String

    func makeNSView(context: Context) -> NSViewType {
        let view = NSViewType()
        view.loadHTMLString(parse(html: htmlContent), baseURL: nil)
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(parse(html: htmlContent), baseURL: nil)
    }
}
#endif

// ref: https://designcode.io/swiftui-advanced-handbook-code-highlighting-in-a-webview
fileprivate func parse(html: String) -> String {
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
    let contentWithCodeStyling = html.replacingOccurrences(
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
