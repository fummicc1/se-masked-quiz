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

    @Binding var htmlContent: String

    func makeUIView(context: Context) -> UIViewType {
        let view = UIViewType()
        view.loadHTMLString(htmlContent, baseURL: nil)
        return view
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        uiView.loadHTMLString(htmlContent, baseURL: nil)
    }
}
#endif

#if canImport(AppKit)
import AppKit

struct DefaultWebView: NSViewRepresentable {
    typealias NSViewType = WKWebView
    
    @Binding var htmlContent: String
    
    func makeNSView(context: Context) -> NSViewType {
        let view = NSViewType()
        view.loadHTMLString(htmlContent, baseURL: nil)
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(htmlContent, baseURL: nil)
    }
}
#endif
