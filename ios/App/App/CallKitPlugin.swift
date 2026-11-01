//
//  CallKitPlugin.swift
//  📞 전화 화면(CallKit)과 웹 화면 사이의 다리
//
//  실제 일은 TCSCallKit 이 합니다. 여기는 그걸 자바스크립트 쪽에서
//  부를 수 있게 이어 주기만 합니다.
//
//  화면 쪽에서:
//    const CK = Capacitor.Plugins.CallKit;
//    CK.addListener('voipToken', e => …)   // 애플이 준 VoIP 기기 표
//    CK.addListener('incoming',  e => …)   // 전화가 왔다 (화면이 떠 있을 때)
//    CK.addListener('answer',    e => …)   // 받기를 눌렀다
//    CK.addListener('ended',     e => …)   // 끊기·거절을 눌렀다
//    CK.start()                            // 쌓여 있던 일을 받아 온다
//    CK.endCall({ callId })                // 통화가 끝났다 — 화면을 내려라
//    CK.connected({ callId })              // 소리 길이 붙었다
//

import Foundation
import Capacitor

@objc(CallKitPlugin)
public class CallKitPlugin: CAPPlugin, CAPBridgedPlugin {

  public let identifier = "CallKitPlugin"
  public let jsName = "CallKit"
  public let pluginMethods: [CAPPluginMethod] = [
    CAPPluginMethod(name: "start",     returnType: CAPPluginReturnPromise),
    CAPPluginMethod(name: "endCall",   returnType: CAPPluginReturnPromise),
    CAPPluginMethod(name: "connected", returnType: CAPPluginReturnPromise),
    CAPPluginMethod(name: "pending",   returnType: CAPPluginReturnPromise),
  ]

  override public func load() {
    TCSCallKit.shared.start()
  }

  /// 화면이 준비됐다 — 이제부터 일어난 일을 건네 달라.
  /// ⚠️ 잠금화면에서 바로 받으면 웹뷰가 아직 없을 수 있습니다. 그동안의
  ///    일은 TCSCallKit 이 모아 두었다가 여기서 한꺼번에 넘겨 줍니다.
  @objc func start(_ call: CAPPluginCall) {
    TCSCallKit.shared.onEvent = { [weak self] data in
      let name = (data["event"] as? String) ?? "callkit"
      var out = data
      out.removeValue(forKey: "event")
      //  retainUntilConsumed: 듣는 쪽이 늦게 붙어도 흘려버리지 않는다
      self?.notifyListeners(name, data: out, retainUntilConsumed: true)
    }
    TCSCallKit.shared.start()
    call.resolve()
  }

  @objc func endCall(_ call: CAPPluginCall) {
    TCSCallKit.shared.endCall(call.getString("callId"))
    call.resolve()
  }

  @objc func connected(_ call: CAPPluginCall) {
    TCSCallKit.shared.connected(call.getString("callId"))
    call.resolve()
  }

  /// 지금 울리고 있는 전화가 있나
  @objc func pending(_ call: CAPPluginCall) {
    call.resolve(["callId": TCSCallKit.shared.pendingCall() ?? ""])
  }
}
