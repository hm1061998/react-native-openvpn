import React
import UIKit
import TunnelKitCore
import TunnelKitManager
import TunnelKitOpenVPN
import NetworkExtension


enum VpnState: Int {
  case VpnStateDisconnected
  case VpnStateConnecting
  case VpnStateConnected
  case VpnStateDisconnecting
  case VpnOtherState
}

@objc(RNOpenvpn)
class RNOpenvpn: RCTEventEmitter {
  public static var emitter: RCTEventEmitter!
  
  private let vpn = NetworkExtensionVPN()
  
  private let STATE_CHANGED_EVENT: String = "stateChanged"
  private var cfg: OpenVPN.ProviderConfiguration?
  
  private var vpnStateObserver: Any?
  var currentManager: NETunnelProviderManager?
  
  override init() {
    super.init()
    RNOpenvpn.emitter = self
  }
  
  
  open override func supportedEvents() -> [String] {
    return [STATE_CHANGED_EVENT] // Đảm bảo STATE_CHANGED_EVENT đã được định nghĩa trong mã Swift
  }
  
  @objc
  func dispose(){
    if(currentManager?.connection.status != .disconnected){
      Task {
        await vpn.disconnect()
        
      }
    }
  }
  
  
  
  
  private func lookupAll() async throws -> [NETunnelProviderManager] {
    try await NETunnelProviderManager.loadAllFromPreferences()
  }
  
  // Hàm kết nối VPN
  @objc(connect:withResolver:withRejecter:)
  func connect(_ options: NSDictionary, _ resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
    
    Task {
      await vpn.prepare()
      let managers = try await lookupAll()
      guard let manager = managers.first else {
        return
      }
      currentManager = manager
    }
    
    let ovpnString = options["ovpnString"] as? String ?? ""
    let tunnelIdentifier = options["tunnelIdentifier"] as? String ?? ""
    let username = options["username"] as? String ?? ""
    let password = options["password"] as? String ?? ""
    let appGroup = options["appGroup"] as? String ?? ""
    let notificationTitle = options["notificationTitle"] as? String ?? "VPN"
    
    let keychain = Keychain(group: appGroup)
    
    let credentials = OpenVPN.Credentials(username, password)
    
    var resultParsed : OpenVPN.ConfigurationParser.Result
    do {
      resultParsed = try OpenVPN.ConfigurationParser.parsed(fromContents: ovpnString)
    }
    catch {
      
      rejecter("E_GET_CONFIG_OVPN_ERROR","get config ovpn fail: ",error)
      
      return
    }
    
    
    cfg = OpenVPN.ProviderConfiguration(notificationTitle, appGroup: appGroup, configuration: resultParsed.configuration)
    cfg?.shouldDebug = true
    cfg?.masksPrivateData = true
    cfg?.username = credentials.username
    
    let passwordReference: Data
    do {
      passwordReference = try keychain.set(password: credentials.password, for: credentials.username, context: tunnelIdentifier)
      
    } catch {
      rejecter("E_KEYCHAIN_FAILURE","Keychain failure: ", error)
      return
    }
    
    Task {
      var extra = NetworkExtensionExtra()
      extra.passwordReference = passwordReference
      try await vpn.reconnect(
        tunnelIdentifier,
        configuration: cfg!,
        extra: extra,
        after: .seconds(1)
      )
    }
  }
  
  // Hàm ngắt kết nối VPN
  @objc(disconnect:withRejecter:)
  func disconnect(_ resolve: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
    Task {
      await vpn.disconnect()
      
    }
    resolve(nil)
  }
  
  
  override func startObserving() {
    let center = NotificationCenter.default
    vpnStateObserver = center.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: nil, queue: nil) { [weak self] notification in
      guard let strongSelf = self else { return }
      if let nevpnConnection = notification.object as? NEVPNConnection {
        let vpnState = strongSelf.getVpnState(status: nevpnConnection.status)
        strongSelf.sendEvent(withName: strongSelf.STATE_CHANGED_EVENT, body: vpnState)
      }
    }
    
  }
  
  
  override func stopObserving() {
    let center = NotificationCenter.default
    if let observer = vpnStateObserver {
      center.removeObserver(observer)
      vpnStateObserver = nil
    }
    
  }
  
  
  
  @objc(observeState:withRejecter:)
  func observeState(_ resolve: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
    let center = NotificationCenter.default
    vpnStateObserver = center.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: nil, queue: nil) { [weak self] notification in
      guard let strongSelf = self else { return }
      if let nevpnConnection = notification.object as? NEVPNConnection {
        let vpnState = strongSelf.getVpnState(status: nevpnConnection.status)
        strongSelf.sendEvent(withName: strongSelf.STATE_CHANGED_EVENT, body: vpnState)
      }
    }
    resolve(nil)
  }
  
  @objc(stopObserveState:withRejecter:)
  func stopObserveState(_ resolve: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
    let center = NotificationCenter.default
    if let observer = vpnStateObserver {
      center.removeObserver(observer)
      vpnStateObserver = nil
    }
    resolve(nil)
  }
  
  
  @objc(getCurrentState:withRejecter:)
  func getCurrentState(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    
    Task {
      let managers = try await lookupAll()
      guard let manager = managers.first else {
        return
      }
      let vpnState : NSDictionary = getVpnState(status:NEVPNStatus(rawValue: manager.connection.status.rawValue ) ?? .disconnected)
      
      resolve(vpnState["state"])
    }
    
  }
  
  private func getVpnState(status: NEVPNStatus) -> NSDictionary {
    var state: Int
    var message: String
    
    switch status {
    case .disconnected:
      state = VpnState.VpnStateDisconnected.rawValue
      message = "The VPN is disconnected"
    case .connecting:
      state = VpnState.VpnStateConnecting.rawValue
      message = "The VPN is in the process of connecting"
    case .connected:
      state = VpnState.VpnStateConnected.rawValue
      message = "The VPN is connected"
    case .disconnecting:
      state = VpnState.VpnStateDisconnecting.rawValue
      message = "The VPN is in the process of disconnecting"
    case .reasserting:
      state = VpnState.VpnOtherState.rawValue
      message = "The VPN is in the process of reconnecting"
    case .invalid:
      state = VpnState.VpnOtherState.rawValue
      message = "The VPN configuration does not exist in the Network Extension preferences or is not enabled"
    default:
      state = VpnState.VpnOtherState.rawValue
      message = "The VPN State is unknown"
    }
    
    return ["state": state, "message": message]
  }
}
