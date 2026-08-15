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
    var scrollToMaskIndex: Int?
    var focusedMaskIndex: Int?

    func makeUIView(context: Context) -> UIViewType {
      let view = UIViewType(
        frame: .zero, configuration: Self.makeConfiguration(coordinator: context.coordinator))
      view.navigationDelegate = context.coordinator

      Task {
        await view.loadHtmlContent(
          htmlContent,
          isCorrect: isCorrect,
          answers: answers,
          scrollToMaskIndex: scrollToMaskIndex,
          focusedMaskIndex: focusedMaskIndex
        )
      }
      return view
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
      applyQuizState(to: uiView, coordinator: context.coordinator)
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
    var scrollToMaskIndex: Int?
    var focusedMaskIndex: Int?

    func makeNSView(context: Context) -> NSViewType {
      let view = NSViewType(
        frame: .zero, configuration: Self.makeConfiguration(coordinator: context.coordinator))
      view.navigationDelegate = context.coordinator

      Task {
        await view.loadHtmlContent(
          htmlContent,
          isCorrect: isCorrect,
          answers: answers,
          scrollToMaskIndex: scrollToMaskIndex,
          focusedMaskIndex: focusedMaskIndex
        )
      }
      return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
      applyQuizState(to: nsView, coordinator: context.coordinator)
    }
  }
#endif

extension DefaultWebView {

  /// 回答のたびに全リロードすると白いちらつきとスクロール位置の復元が走るため、
  /// 初回ロード後は JavaScript で DOM を部分更新する。
  fileprivate func applyQuizState(to webView: WKWebView, coordinator: Coordinator) {
    guard case .string = htmlContent, coordinator.didLoadInitialContent else { return }
    let script = quizStateScript(
      isCorrect: isCorrect,
      answers: answers,
      focusedMaskIndex: focusedMaskIndex,
      scrollToMaskIndex: scrollToMaskIndex
    )
    webView.evaluateJavaScript(script)
  }

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
    var didLoadInitialContent = false
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
    scrollContentOffsetY: CGFloat = 0,
    scrollToMaskIndex: Int? = nil,
    focusedMaskIndex: Int? = nil
  ) async {
    if let url = htmlContent.url {
      load(URLRequest(url: url))
    } else {
      loadHTMLString(
        await parse(
          html: htmlContent,
          isCorrect: isCorrect,
          answers: answers,
          scrollContentOffsetY: scrollContentOffsetY,
          scrollToMaskIndex: scrollToMaskIndex,
          focusedMaskIndex: focusedMaskIndex
        ),
        baseURL: nil
      )
    }
  }
}

private func jsonObject<Value: Encodable>(_ dictionary: [Int: Value]) -> String {
  (try? JSONEncoder().encode(dictionary)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
}

func quizStateScript(
  isCorrect: [Int: Bool],
  answers: [Int: String],
  focusedMaskIndex: Int?,
  scrollToMaskIndex: Int?
) -> String {
  """
  window.applyQuizState(\(jsonObject(isCorrect)), \(jsonObject(answers)), \
  \(focusedMaskIndex.map(String.init) ?? "null"), \
  \(scrollToMaskIndex.map(String.init) ?? "null"));
  """
}

// ref: https://designcode.io/swiftui-advanced-handbook-code-highlighting-in-a-webview
private func parse(
  html: HTMLContent,
  isCorrect: [Int: Bool],
  answers: [Int: String],
  scrollContentOffsetY: CGFloat = 0,
  scrollToMaskIndex: Int? = nil,
  focusedMaskIndex: Int? = nil
) async -> String {
  let htmlContent = await html.content
  if case .url = html {
    // if the content is from URL, we don't need to add any styling.
    return htmlContent
  }

  let isCorrectJSON = jsonObject(isCorrect)
  let answersJSON = jsonObject(answers)
  let scrollTargetJSON = scrollToMaskIndex.map(String.init) ?? "null"
  let focusedJSON = focusedMaskIndex.map(String.init) ?? "null"

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
                :root {
                    color-scheme: light dark;
                    --bg: #ffffff;
                    --fg: #1c1c1e;
                    --code-bg: #f0f0f0;
                    --code-fg: #9a2c1f;
                    --mask-bg: rgba(10, 132, 255, 0.10);
                    --mask-bg-hover: rgba(10, 132, 255, 0.20);
                    --mask-fg: #1c1c1e;
                    --mask-border: rgba(10, 132, 255, 0.45);
                    --correct-bg: #2e7d32;
                    --incorrect-bg: #c62828;
                    --focus: #0a84ff;
                    --focus-halo: rgba(10, 132, 255, 0.20);
                }
                @media (prefers-color-scheme: dark) {
                    :root {
                        --bg: #1c1c1e;
                        --fg: #f2f2f7;
                        --code-bg: #2c2c2e;
                        --code-fg: #ff9e91;
                        --mask-bg: rgba(10, 132, 255, 0.22);
                        --mask-bg-hover: rgba(10, 132, 255, 0.34);
                        --mask-fg: #f2f2f7;
                        --mask-border: rgba(100, 180, 255, 0.60);
                        --focus-halo: rgba(10, 132, 255, 0.28);
                    }
                }
                * {
                    font-family: -apple-system, BlinkMacSystemFont, SF Mono, Menlo, monospace;
                }
                body {
                    font-size: 20px;
                    line-height: 1.6;
                    padding: 16px;
                    background-color: var(--bg);
                    color: var(--fg);
                    overflow-wrap: break-word;
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
                    background: var(--code-bg);
                    padding: 2px 6px;
                    border-radius: 4px;
                    color: var(--code-fg);
                }
                .masked-word {
                    color: var(--mask-fg);
                    background-color: var(--mask-bg);
                    border-bottom: 2px solid var(--mask-border);
                    padding: 2px 6px;
                    border-radius: 4px;
                    cursor: pointer;
                    user-select: none;
                    display: inline-block;
                    position: relative;
                    touch-action: manipulation;
                    -webkit-tap-highlight-color: transparent;
                }
                .masked-word.correct {
                    color: #fff;
                    background-color: var(--correct-bg);
                    border-bottom-color: transparent;
                }
                .masked-word.incorrect {
                    color: #fff;
                    background-color: var(--incorrect-bg);
                    border-bottom-color: transparent;
                }
                .masked-word.current {
                    outline: 3px solid var(--focus);
                    outline-offset: 2px;
                    box-shadow: 0 0 0 7px var(--focus-halo);
                    z-index: 1;
                }
                @keyframes mask-pulse {
                    0%   { transform: scale(1); }
                    35%  { transform: scale(1.08); }
                    100% { transform: scale(1); }
                }
                .masked-word.current.pulse {
                    animation: mask-pulse 450ms cubic-bezier(0.34, 1.56, 0.64, 1) 2;
                }
                @media (prefers-reduced-motion: reduce) {
                    .masked-word.current.pulse { animation: none; }
                    .masked-word.current { box-shadow: 0 0 0 10px var(--focus-halo); }
                }
                @media (hover: hover) {
                    .masked-word:hover { background-color: var(--mask-bg-hover); }
                }
                .masked-word:active {
                    transform: scale(0.97);
                }
            </style>
            <script>
                let currentIndex = 0;
                const initialScrollY = \(scrollContentOffsetY);
                let quizState = {
                    isCorrect: \(isCorrectJSON),
                    answers: \(answersJSON),
                    focused: \(focusedJSON),
                    scrollTarget: \(scrollTargetJSON)
                };
                let appliedScrollTarget = null;

                function wrapMaskedWords() {
                    const text = document.body.innerHTML;
                    const pattern = /(＿)+/g;
                    const wrappedText = text.replace(pattern, function(match) {
                        const index = currentIndex++;
                        return `<span class="masked-word" data-mask-index="${index}" data-placeholder="${match}" role="button" tabindex="0" lang="ja">${match}</span>`;
                    });
                    document.body.innerHTML = wrappedText;
                    renderQuizState();
                    if (quizState.scrollTarget === null) {
                        window.scrollTo(0, initialScrollY);
                    }
                }

                function maskedWordLabel(key, answered, isCorrect, answer) {
                    const position = Number(key) + 1;
                    if (!answered) { return '空欄 ' + position + '、未解答'; }
                    return '空欄 ' + position + '、' + (isCorrect ? '正解' : '不正解') + '、答えは ' + answer;
                }

                function renderQuizState() {
                    document.querySelectorAll('.masked-word').forEach(function(el) {
                        const key = el.dataset.maskIndex;
                        const answered = Object.prototype.hasOwnProperty.call(quizState.isCorrect, key);
                        const isCorrect = answered && quizState.isCorrect[key];
                        const isFocused = String(quizState.focused) === key;
                        el.classList.toggle('correct', isCorrect);
                        el.classList.toggle('incorrect', answered && !isCorrect);
                        el.classList.toggle('current', isFocused);
                        el.textContent = answered ? quizState.answers[key] : el.dataset.placeholder;
                        el.setAttribute(
                            'aria-label',
                            maskedWordLabel(key, answered, isCorrect, quizState.answers[key])
                        );
                        if (isFocused) {
                            el.setAttribute('aria-current', 'true');
                        } else {
                            el.removeAttribute('aria-current');
                        }
                    });
                    if (quizState.scrollTarget === null || quizState.scrollTarget === appliedScrollTarget) {
                        return;
                    }
                    const target = document.querySelector('[data-mask-index="' + quizState.scrollTarget + '"]');
                    if (!target) { return; }
                    appliedScrollTarget = quizState.scrollTarget;
                    target.scrollIntoView({ block: 'center' });
                    target.classList.remove('pulse');
                    void target.offsetWidth;
                    target.classList.add('pulse');
                }

                window.applyQuizState = function(isCorrect, answers, focused, scrollTarget) {
                    quizState = {
                        isCorrect: isCorrect,
                        answers: answers,
                        focused: focused,
                        scrollTarget: scrollTarget
                    };
                    renderQuizState();
                };
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
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    didLoadInitialContent = true
  }

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
        function maskedWordFrom(target) {
            return target && target.closest ? target.closest('.masked-word') : null;
        }

        function postMaskedWordTap(element) {
            window.webkit.messageHandlers.maskedWordTapped.postMessage({
                maskIndex: parseInt(element.dataset.maskIndex)
            });
        }

        document.addEventListener('click', function(e) {
            const element = maskedWordFrom(e.target);
            if (element) { postMaskedWordTap(element); }
        });

        document.addEventListener('keydown', function(e) {
            if (e.key !== 'Enter' && e.key !== ' ') { return; }
            const element = maskedWordFrom(e.target);
            if (!element) { return; }
            e.preventDefault();
            postMaskedWordTap(element);
        });

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
