#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

typedef NS_ENUM(NSInteger, VpnState) {
  VpnStateDisconnected,
  VpnStateConnecting,
  VpnStateConnected,
  VpnStateDisconnecting,
  VpnOtherState,
};


@interface RCT_EXTERN_MODULE(RNOpenvpn, RCTEventEmitter)
RCT_EXTERN_METHOD(supportedEvents)
RCT_EXTERN_METHOD(dispose)

RCT_EXTERN_METHOD(connect:(NSDictionary *)options
                  withResolver:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(disconnect:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getCurrentState:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(observeState:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(stopObserveState:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

- (NSDictionary *)constantsToExport {
  return @{
    @"VpnState" : @{
      @"VPN_STATE_DISCONNECTED" : @(VpnStateDisconnected),
      @"VPN_STATE_CONNECTING" : @(VpnStateConnecting),
      @"VPN_STATE_CONNECTED" : @(VpnStateConnected),
      @"VPN_STATE_DISCONNECTING" : @(VpnStateDisconnecting),
      @"VPN_OTHER_STATE" : @(VpnOtherState),
    }
  };
};


+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

@end
