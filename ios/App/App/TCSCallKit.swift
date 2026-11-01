//
//  TCSCallKit.swift
//  📞 아이폰에서 '일반 전화처럼' 받기
//
//  지금까지는 전화가 오면 알림이 한 번 "딩" 했습니다. 앱이 꺼져 있으면
//  그 알림을 눌러 들어와야 벨이 울렸습니다. CallKit 을 쓰면 **잠금화면에
//  전체화면 전화 화면**이 뜨고, 시스템 벨소리로 계속 울리고, 잠금을 풀지
//  않고 받을 수 있습니다.
//
//  ── 일을 어떻게 나눴나 ───────────────────────────────────────────
//  CallKit 은 **벨 울리고 받는 화면까지만** 맡습니다. 받고 나서 오가는
//  소리는 지금처럼 웹뷰(WebRTC)가 맡습니다.
//
//  왜 이렇게 나눴나: CallKit 은 앱이 소리를 직접 쥐고 있다고 봅니다.
//  그런데 우리 소리는 웹뷰 안에서 납니다. 둘이 서로 소리를 가져가려고
//  다투면 '받았는데 안 들리는' 일이 생깁니다 — 그 증상으로 이미 한 번
//  크게 고생했습니다. 그래서 소리에는 손대지 않습니다.
//
//  ── 꼭 지켜야 하는 것 ───────────────────────────────────────────
//  ⚠️ iOS 13 부터, VoIP 푸시를 받으면 **그 자리에서 반드시**
//     reportNewIncomingCall 을 불러야 합니다. 안 부르면 iOS 가 앱을
//     죽이고, 몇 번 반복되면 **VoIP 푸시를 아예 안 보내 줍니다.**
//     그래서 아래 didReceiveIncomingPush 는 어떤 경우에도 먼저 전화를
//     알리고, 그 다음에 다른 일을 합니다.
//
//  설치: Info.plist 의 UIBackgroundModes 에 voip
//        서버는 apns-push-type: voip · apns-topic: <번들>.voip 로 보냅니다
//

import Foundation
import UIKit
import PushKit
import CallKit
import AVFoundation

final class TCSCallKit: NSObject {

  static let shared = TCSCallKit()

  private var provider: CXProvider?
  private var registry: PKPushRegistry?
  private let callController = CXCallController()

  /// 지금 울리고 있거나 통화 중인 전화 (CallKit 쪽 번호)
  private(set) var currentUUID: UUID?
  /// 그 전화의 우리 쪽 번호 (calls 표의 id). 보통 UUID 와 같습니다.
  private(set) var currentCallId: String?

  /// 화면(웹)이 아직 안 떴을 때 생긴 일을 모아 둡니다.
  /// 잠금화면에서 바로 받으면 웹뷰가 아직 준비 전일 수 있습니다 —
  /// 그때 흘려버리면 전화를 받았는데 아무 일도 안 일어납니다.
  private var pending: [[String: Any]] = []
  /// 화면이 붙으면 이걸로 건네줍니다.
  var onEvent: (([String: Any]) -> Void)? {
    didSet { flush() }
  }

  private func emit(_ name: String, _ data: [String: Any]) {
    var d = data
    d["event"] = name
    if let f = onEvent { f(d) } else { pending.append(d) }
  }
  private func flush() {
    guard let f = onEvent, !pending.isEmpty else { return }
    let q = pending; pending = []
    q.forEach { f($0) }
  }

  // ── 켜기 ────────────────────────────────────────────────────────
  //  AppDelegate 의 didFinishLaunching 에서 부릅니다.
  //  ⚠️ 플러그인이 만들어질 때까지 기다리면 늦습니다. 꺼져 있던 앱이
  //     VoIP 푸시로 깨어날 때, 푸시가 플러그인보다 **먼저** 옵니다.
  func start() {
    if provider == nil {
      let cfg = CXProviderConfiguration()
      cfg.supportsVideo = false
      cfg.maximumCallGroups = 1
      cfg.maximumCallsPerCallGroup = 1
      //  전화번호가 아니라 이름으로 겁니다
      cfg.supportedHandleTypes = [.generic]
      cfg.includesCallsInRecents = true
      if let img = UIImage(named: "AppIcon") {
        cfg.iconTemplateImageData = img.pngData()
      }
      let p = CXProvider(configuration: cfg)
      p.setDelegate(self, queue: nil)
      provider = p
    }
    if registry == nil {
      let r = PKPushRegistry(queue: .main)
      r.delegate = self
      r.desiredPushTypes = [.voIP]
      registry = r
    }
  }

  // ── 화면 쪽에서 부르는 것 ───────────────────────────────────────

  /// 통화가 끝났다 — 전화 화면을 내린다.
  func endCall(_ callId: String?) {
    guard let uuid = currentUUID else { return }
    if let want = callId, let cur = currentCallId, want != cur { return }
    provider?.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
    currentUUID = nil
    currentCallId = nil
  }

  /// 소리 길이 붙었다 — '통화 중' 으로 바꾸고 시간을 센다.
  func connected(_ callId: String?) {
    guard let uuid = currentUUID else { return }
    if let want = callId, let cur = currentCallId, want != cur { return }
    provider?.reportOutgoingCall(with: uuid, connectedAt: Date())
  }

  /// 지금 울리는 전화가 있나 (화면이 뜬 뒤 물어봅니다)
  func pendingCall() -> String? { return currentCallId }
}

// ── VoIP 푸시 ─────────────────────────────────────────────────────
extension TCSCallKit: PKPushRegistryDelegate {

  func pushRegistry(_ registry: PKPushRegistry,
                    didUpdate pushCredentials: PKPushCredentials,
                    for type: PKPushType) {
    guard type == .voIP else { return }
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    emit("voipToken", ["token": token])
  }

  func pushRegistry(_ registry: PKPushRegistry,
                    didInvalidatePushTokenFor type: PKPushType) {
    guard type == .voIP else { return }
    emit("voipToken", ["token": ""])
  }

  func pushRegistry(_ registry: PKPushRegistry,
                    didReceiveIncomingPushWith payload: PKPushPayload,
                    for type: PKPushType,
                    completion: @escaping () -> Void) {
    guard type == .voIP else { completion(); return }

    //  ⚠️ 여기서 **무조건** 전화를 알립니다. 쪽지가 이상해도 알립니다.
    //     안 알리면 iOS 가 앱을 죽이고, 몇 번 반복되면 VoIP 푸시를
    //     아예 끊어 버립니다. 되돌릴 길이 없습니다.
    let dict = payload.dictionaryPayload
    let callId = (dict["callId"] as? String) ?? ""
    let name = (dict["callerName"] as? String) ?? "전화"
    let uuid = UUID(uuidString: callId) ?? UUID()

    start()   // 꺼져 있다 깨어난 길이면 아직 없을 수 있습니다

    let update = CXCallUpdate()
    update.remoteHandle = CXHandle(type: .generic, value: name)
    update.localizedCallerName = name
    update.hasVideo = false
    update.supportsHolding = false
    update.supportsGrouping = false
    update.supportsUngrouping = false
    update.supportsDTMF = false

    currentUUID = uuid
    currentCallId = callId.isEmpty ? uuid.uuidString : callId

    provider?.reportNewIncomingCall(with: uuid, update: update) { [weak self] err in
      if let e = err {
        //  못 알렸다 — 그래도 조용히 넘어가면 안 된다. 기록은 남긴다.
        NSLog("📞 전화 화면을 못 띄웠습니다: %@", e.localizedDescription)
        self?.currentUUID = nil
        self?.currentCallId = nil
      } else {
        self?.emit("incoming", ["callId": self?.currentCallId ?? "", "callerName": name])
      }
      completion()
    }
  }
}

// ── 전화 화면에서 누른 것 ─────────────────────────────────────────
extension TCSCallKit: CXProviderDelegate {

  func providerDidReset(_ provider: CXProvider) {
    currentUUID = nil
    currentCallId = nil
    emit("ended", ["callId": "", "reason": "reset"])
  }

  /// 받기
  func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    emit("answer", ["callId": currentCallId ?? ""])
    action.fulfill()
  }

  /// 끊기 · 거절
  func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    let id = currentCallId ?? ""
    currentUUID = nil
    currentCallId = nil
    emit("ended", ["callId": id, "reason": "user"])
    action.fulfill()
  }

  /// 음소거
  func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
    emit("muted", ["callId": currentCallId ?? "", "muted": action.isMuted])
    action.fulfill()
  }

  //  ⚠️ 소리 길은 **웹뷰가 쥐고 있습니다.** 여기서 AVAudioSession 을
  //     건드리면 웹뷰가 잡아 둔 마이크·스피커와 다툽니다. 일부러 비워
  //     둡니다 — 비어 있는 게 맞습니다.
  func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) { }
  func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) { }
}
