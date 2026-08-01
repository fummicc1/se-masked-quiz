//
//  AppTab.swift
//  se-masked-quiz
//
//  アプリのトップレベルタブ。SE/STのトラックタブに加え、
//  トラック横断データ（ストリーク・正答率）を扱う学習記録タブを独立させる。
//

enum AppTab: Hashable {
  case track(ProposalTrack)
  case stats
}
