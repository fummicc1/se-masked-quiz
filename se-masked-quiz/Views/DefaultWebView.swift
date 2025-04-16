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
    @Binding var isCorrect: [Int: Bool]
    @Binding var answers: [Int: String]

    func makeUIView(context: Context) -> UIViewType {
      let view = UIViewType(
        frame: .zero, configuration: Self.makeConfiguration(coordinator: context.coordinator))
      view.navigationDelegate = context.coordinator

      Task {
        await view.loadHtmlContent(
          htmlContent,
          isCorrect: isCorrect,
          answers: answers
        )
      }
      return view
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
      Task {
        print("contentoffsetY in updateUIView: \(context.coordinator.scrollContentOffsetY)")
        await uiView.loadHtmlContent(
          htmlContent,
          isCorrect: context.coordinator.isCorrect,
          answers: context.coordinator.answers,
          scrollContentOffsetY: context.coordinator.scrollContentOffsetY
        )
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
    @Binding var isCorrect: [Int: Bool]
    @Binding var answers: [Int: String]

    func makeNSView(context: Context) -> NSViewType {
      let view = NSViewType(
        frame: .zero, configuration: Self.makeConfiguration(coordinator: context.coordinator))
      view.navigationDelegate = context.coordinator

      Task {
        await view.loadHtmlContent(
          htmlContent,
          isCorrect: isCorrect,
          answers: answers
        )
      }
      return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
      Task {
        await nsView.loadHtmlContent(
          htmlContent,
          isCorrect: isCorrect,
          answers: answers,
          scrollContentOffsetY: context.coordinator.scrollContentOffsetY
        )
      }
    }
  }
#endif

extension DefaultWebView {

  func makeCoordinator() -> Coordinator {
    .init(
      isCorrect: $isCorrect,
      answers: $answers,
      onNavigate: onNavigate,
      onMaskedWordTap: onMaskedWordTap
    )
  }

  final class Coordinator: NSObject {
    let onNavigate: (URL) -> Void
    let onMaskedWordTap: (Int) -> Void
    var scrollContentOffsetY: CGFloat
    @Binding var isCorrect: [Int: Bool]
    @Binding var answers: [Int: String]

    init(
      isCorrect: Binding<[Int: Bool]>,
      answers: Binding<[Int: String]>,
      onNavigate: @escaping (URL) -> Void,
      onMaskedWordTap: @escaping (Int) -> Void
    ) {
      self._isCorrect = isCorrect
      self._answers = answers
      self.scrollContentOffsetY = 0
      self.onNavigate = onNavigate
      self.onMaskedWordTap = onMaskedWordTap
    }
  }
}

extension WKWebView {

  fileprivate func loadHtmlContent(
    _ htmlContent: HTMLContent,
    isCorrect: [Int: Bool],
    answers: [Int: String],
    scrollContentOffsetY: CGFloat = 0
  ) async {
    if let url = htmlContent.url {
      load(URLRequest(url: url))
    } else {
      loadHTMLString(
        await parse(
          html: htmlContent,
          isCorrect: isCorrect,
          answers: answers,
          scrollContentOffsetY: scrollContentOffsetY
        ),
        baseURL: nil
      )
    }
  }
}

// ref: https://designcode.io/swiftui-advanced-handbook-code-highlighting-in-a-webview
private func parse(
  html: HTMLContent,
  isCorrect: [Int: Bool],
  answers: [Int: String],
  scrollContentOffsetY: CGFloat = 0
) async -> String {
  let htmlContent = await html.content
  if case .url = html {
    // if the content is from URL, we don't need to add any styling.
    return htmlContent
  }

  // Convert dictionaries to JSON
  let jsonEncoder = JSONEncoder()
  let isCorrectJSON =
    (try? jsonEncoder.encode(isCorrect)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
  let answersJSON =
    (try? jsonEncoder.encode(answers)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

  // HTMLエスケープを解除
  let unescapedContent =
    htmlContent
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
                    color: #fff;
                    padding: 2px 6px;
                    border-radius: 4px;
                    cursor: pointer;
                    user-select: none;
                    display: inline-block;  /* インライン要素をブロック化してクリック領域を確保 */
                    pointer-events: auto;   /* クリックイベントを確実に有効化 */
                }
                .masked-word.correct {
                    background-color: #4CAF50;
                }
                .masked-word.incorrect {
                    background-color: #f44336;
                }
                .masked-word:hover {
                    background-color: #333;
                }
                .masked-word.correct:hover {
                    background-color: #45a049;
                }
                .masked-word.incorrect:hover {
                    background-color: #da190b;
                }
            </style>
            <script>
                let currentIndex = 0;
                const isCorrectMap = \(isCorrectJSON);
                const answersMap = \(answersJSON);
                const initialScrollY = \(scrollContentOffsetY);
                
                function wrapMaskedWords() {
                    const text = document.body.innerHTML;
                    const pattern = /(＿)+/g;
                    const wrappedText = text.replace(pattern, function(match) {
                        const index = currentIndex++;
                        const isAnswered = isCorrectMap.hasOwnProperty(index.toString());
                        const isCorrect = isAnswered ? isCorrectMap[index.toString()] : false;
                        const answer = isAnswered ? answersMap[index.toString()] : '';
                        let message = isAnswered ? answer : match;
                        const className = isAnswered ? (isCorrect ? 'masked-word correct' : 'masked-word incorrect') : 'masked-word';
                        return `<span class="${className}" data-mask-index="${index}">${message}</span>`;
                    });
                    document.body.innerHTML = wrappedText;
                    
                    console.log('Total masked groups:', currentIndex);
                    
                    // Set initial scroll position after content is loaded
                    window.scrollTo(0, initialScrollY);
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
  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async
    -> WKNavigationActionPolicy
  {
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
  func userContentController(
    _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
  ) {
    if message.name == "maskedWordTapped",
      let body = message.body as? [String: Any],
      let maskIndex = body["maskIndex"] as? Int
    {
      onMaskedWordTap(maskIndex)
    } else if message.name == "scrollPositionChanged",
      let body = message.body as? [String: Any],
      let scrollY = body["scrollY"] as? CGFloat
    {
      print("scrollY from JavaScript: \(scrollY)")
      scrollContentOffsetY = scrollY
    }
  }
}

// Common WebView configuration
extension DefaultWebView {
  fileprivate static func makeConfiguration(coordinator: Coordinator) -> WKWebViewConfiguration {
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

        // Add scroll event listener
        let scrollTimeout;
        window.addEventListener('scroll', function() {
            clearTimeout(scrollTimeout);
            scrollTimeout = setTimeout(function() {
                window.webkit.messageHandlers.scrollPositionChanged.postMessage({
                    scrollY: window.scrollY
                });
            }, 100);
        });
        """,
      injectionTime: .atDocumentEnd,
      forMainFrameOnly: true
    )
    config.userContentController.addUserScript(userScript)
    config.userContentController.add(coordinator, name: "maskedWordTapped")
    config.userContentController.add(coordinator, name: "scrollPositionChanged")

    // デバッグ用のコンソールメッセージを有効化
    config.preferences.setValue(true, forKey: "developerExtrasEnabled")

    return config
  }
}
