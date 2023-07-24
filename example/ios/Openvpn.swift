import React
import UIKit
import TunnelKitCore
import TunnelKitManager
import TunnelKitOpenVPN
import NetworkExtension

enum VpnState: Int {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case otherState
}

@objc(Openvpn)
class Openvpn: RCTEventEmitter {
    public static var emitter: RCTEventEmitter!
    private let vpn = NetworkExtensionVPN()

    @objc static var STATE_CHANGED_EVENT: String = "stateChanged"
    private var cfg: OpenVPN.ProviderConfiguration?
   
    private var vpnStateObserver: Any?
    var currentManager: NETunnelProviderManager?

    override init() {
      super.init()
      Openvpn.emitter = self
      
    }
  
  
  @objc
  func dispose(){
    if(currentManager?.connection.status != .disconnected){
      Task {
           await vpn.disconnect()

      }
    }
  }
  

   open override func supportedEvents() -> [String] {
    return [Openvpn.STATE_CHANGED_EVENT] // Đảm bảo STATE_CHANGED_EVENT đã được định nghĩa trong mã Swift
    }
  
 // Hàm kết nối VPN
  @objc(connect:withResolver:withRejecter:)
  func connect(_ options: NSDictionary, _ resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
      
      Task {
                await vpn.prepare()
            }
        // Code của hàm connect ở đây
     
  
     
    
        let ovpnString = options["ovpnString"] as? String ?? ""
        let tunnelIdentifier = options["tunnelIdentifier"] as? String ?? ""
        let username = options["username"] as? String ?? ""
        let password = options["password"] as? String ?? ""
        let appGroup = options["appGroup"] as? String ?? ""
        
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



        cfg = OpenVPN.ProviderConfiguration("VPN", appGroup: appGroup, configuration: resultParsed.configuration)
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
                after: .seconds(2)
            )
          
        
        }


    }
    
    // Hàm ngắt kết nối VPN
    @objc(disconnect:withRejecter:)
    func disconnect(_ resolve: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
      Task {
           await vpn.disconnect()

      }

    }
  

  
    
    override  func startObserving() {
      let center = NotificationCenter.default
      vpnStateObserver = center.addObserver(forName: VPNNotification.didChangeStatus, object: nil, queue: nil) { [weak self] notification in
              guard let strongSelf = self else { return }
              if let nevpnConnection = notification.object as? NEVPNConnection {
                  let vpnState = strongSelf.getVpnState(status: nevpnConnection.status)
                strongSelf.sendEvent(withName: Openvpn.STATE_CHANGED_EVENT, body: vpnState)
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

  


  @objc
   func getCurrentState(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    
     if let vpnState = getVpnState(status:NEVPNStatus(rawValue: (currentManager?.connection.status)!.rawValue) ?? .disconnected) as? [String: Any] {
           resolve(vpnState["state"])
       } else {
           reject("ERROR", "Failed to get VPN state", nil)
       }
   }

     private func getVpnState(status: NEVPNStatus) -> [String: Any] {
         var state: String
         var message: String

         switch status {
         case .disconnected:
             state = "VPN_STATE_DISCONNECTED"
             message = "The VPN is disconnected"
         case .connecting:
             state = "VPN_STATE_CONNECTING"
             message = "The VPN is in the process of connecting"
         case .connected:
             state = "VPN_STATE_CONNECTED"
             message = "The VPN is connected"
         case .disconnecting:
             state = "VPN_STATE_DISCONNECTING"
             message = "The VPN is in the process of disconnecting"
         case .reasserting:
             state = "VPN_OTHER_STATE"
             message = "The VPN is in the process of reconnecting"
         case .invalid:
             state = "VPN_OTHER_STATE"
             message = "The VPN configuration does not exist in the Network Extension preferences or is not enabled"
         default:
             state = "VPN_OTHER_STATE"
             message = "The VPN State is unknown"
         }

         return ["state": state, "message": message]
     }
}
