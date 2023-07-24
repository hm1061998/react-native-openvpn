import {
  NativeModules,
  Platform,
  NativeEventEmitter,
  type EmitterSubscription,
} from 'react-native';

const LINKING_ERROR =
  `The package 'react-native-openvpn' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

const RNOpenvpn = NativeModules.RNOpenvpn
  ? NativeModules.RNOpenvpn
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

const localEventEmitter = new NativeEventEmitter(RNOpenvpn);
let stateListener: EmitterSubscription | null = null;

export const addVpnStateListener = (callback: (arg0: any) => void) => {
  stateListener = localEventEmitter.addListener('stateChanged', (e) =>
    callback(e)
  );
};

export const removeVpnStateListener = () => {
  if (!stateListener) {
    return;
  }
  stateListener.remove();
  stateListener = null;
};

export function connect(options: {
  ovpnString: string;
  tunnelIdentifier: string;
  username: string;
  password: string;
  appGroup: string;
  notificationTitle: string;
  compatMode: any;
  useLegacyProvider: boolean;
}): Promise<any> {
  return RNOpenvpn.connect(options);
}

export function disconnect(): Promise<any> {
  return RNOpenvpn.disconnect();
}

export default RNOpenvpn;
