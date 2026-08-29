//
//  SpeechButton.swift
//  se-masked-quiz
//
//  読み上げの開始と停止を兼ねるボタン。読み上げ中はアイコンとラベルが停止操作を示す。
//

import SwiftUI

struct SpeechButton: View {
  let titleKey: LocalizedStringKey
  let isSpeaking: Bool
  let isEnabled: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(titleKey, systemImage: isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
        .font(AppFont.subheadline)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.borderless)
    .disabled(!isEnabled)
    .accessibilityLabel(isSpeaking ? Text("読み上げを停止") : Text(titleKey))
  }
}

#Preview("停止中") {
  SpeechButton(titleKey: "この段落を聞く", isSpeaking: false, isEnabled: true, action: {})
}

#Preview("読み上げ中") {
  SpeechButton(titleKey: "この段落を聞く", isSpeaking: true, isEnabled: true, action: {})
}

#Preview("無効") {
  SpeechButton(titleKey: "答えの発音", isSpeaking: false, isEnabled: false, action: {})
}
