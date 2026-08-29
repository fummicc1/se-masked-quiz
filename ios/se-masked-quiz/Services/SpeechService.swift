//
//  SpeechService.swift
//  se-masked-quiz
//
//  マスククイズ中の読み上げを担う音声合成レイヤー。オンデバイスで完結する。
//

import AVFoundation
import Foundation

/// いま読み上げている対象
enum SpeechTarget: Equatable, Sendable {
  /// フォーカス中の空欄を含む段落
  case paragraph
  /// 答えの用語
  case term
}

/// @mockable
@MainActor
protocol SpeechService: AnyObject {
  /// 読み上げが完了する、または `stop()` されるまで待つ
  func speak(_ text: String, languageCode: String) async
  func stop()
}

@MainActor
final class AVSpeechService: SpeechService {
  private let synthesizer = AVSpeechSynthesizer()
  private let completionDelegate = SpeechCompletionDelegate()

  init() {
    synthesizer.delegate = completionDelegate
  }

  func speak(_ text: String, languageCode: String) async {
    synthesizer.stopSpeaking(at: .immediate)

    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: languageCode)

    activateSession()
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      completionDelegate.setCompletion(for: utterance) { continuation.resume() }
      synthesizer.speak(utterance)
    }
    deactivateSession()
  }

  func stop() {
    synthesizer.stopSpeaking(at: .immediate)
  }

  #if !os(macOS)
    private func activateSession() {
      let session = AVAudioSession.sharedInstance()
      // interruptSpokenAudioAndMixWithOthers は VoiceOver の発話まで止めてしまうため使わない
      try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
      try? session.setActive(true)
    }

    private func deactivateSession() {
      try? AVAudioSession.sharedInstance().setActive(
        false, options: [.notifyOthersOnDeactivation])
    }
  #else
    private func activateSession() {}
    private func deactivateSession() {}
  #endif
}

/// 発話の完了を待つための橋渡し。`AVSpeechSynthesizerDelegate` の呼び出し元スレッドを問わないよう
/// ロックで保護し、発話ごとの継続をちょうど1回だけ解放する。
private final class SpeechCompletionDelegate: NSObject, AVSpeechSynthesizerDelegate,
  @unchecked Sendable
{
  private let lock = NSLock()
  private var pendingUtterance: AVSpeechUtterance?
  private var pendingCompletion: (@Sendable () -> Void)?

  func setCompletion(for utterance: AVSpeechUtterance, _ completion: @escaping @Sendable () -> Void)
  {
    lock.lock()
    let previous = pendingCompletion
    pendingUtterance = utterance
    pendingCompletion = completion
    lock.unlock()
    previous?()
  }

  /// 直前の発話が停止された通知が遅れて届いても新しい発話の継続を奪わないよう、同一性を確認する
  private func takeCompletion(for utterance: AVSpeechUtterance) -> (@Sendable () -> Void)? {
    lock.lock()
    defer { lock.unlock() }
    guard pendingUtterance === utterance else { return nil }
    let completion = pendingCompletion
    pendingUtterance = nil
    pendingCompletion = nil
    return completion
  }

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance
  ) {
    takeCompletion(for: utterance)?()
  }

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance
  ) {
    takeCompletion(for: utterance)?()
  }
}
