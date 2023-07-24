'use strict';
Object.defineProperty(exports, '__esModule', { value: true });
exports.withVPNSettingsGradle =
  exports.withVPNAppDelegate =
  exports.withAddPathVPN =
    void 0;
const config_plugins_1 = require('@expo/config-plugins');
const { Paths } = require('@expo/config-plugins/build/android');
const path = require('path');
const fs = require('fs');

const withAddPathVPN = (config) => {
  return (0, config_plugins_1.withAndroidManifest)(config, async (config) => {
    const src_file_pat = path.join(__dirname, 'jniLibs');
    let res_file_path = await Paths.getResourceFolderAsync(
      config.modRequest.projectRoot
    );

    res_file_path = res_file_path.replace('res', 'jniLibs');

    try {
      fs.cpSync(src_file_pat, res_file_path, { recursive: true });
    } catch (e) {
      throw e;
    }
    return config;
  });
};

exports.withAddPathVPN = withAddPathVPN;

const withVPNSettingsGradle = (config) => {
  return (0, config_plugins_1.withSettingsGradle)(config, (config) => {
    config.modResults.contents =
      config.modResults.contents +
      `
include ':vpnLib'
project(':vpnLib').projectDir = new File(rootProject.projectDir, '../node_modules/react-native-simple-openvpn/vpnLib')`;
    return config;
  });
};
exports.withVPNSettingsGradle = withVPNSettingsGradle;

const withVPNAppDelegate = (config) => {
  return (0, config_plugins_1.withAppDelegate)(config, (modConfig) => {
    const insertionCodeTop = '#import "RNOpenvpn.h"';
    modConfig.modResults.contents = modConfig.modResults.contents.replace(
      '#import "AppDelegate.h"',
      '#import "AppDelegate.h"\n' + insertionCodeTop
    );

    const insertionCode = `
// Disable VPN connection when app is terminated in iOS
- (void)applicationWillTerminate:(UIApplication *)application
{
  [RNOpenvpn dispose];
}
  
`;
    modConfig.modResults.contents = modConfig.modResults.contents.replace(
      '@end',
      insertionCode + '@end'
    );
    return modConfig;
  });
};

exports.withVPNAppDelegate = withVPNAppDelegate;

const withReactNativeOpenVpn = (config) => {
  // config = (0, exports.withVPNAppDelegate)(config);
  config = (0, exports.withVPNSettingsGradle)(config);
  config = (0, exports.withAddPathVPN)(config);
  return config;
};

const pkg = require('react-native-openvpn/package.json');
exports.default = (0, config_plugins_1.createRunOncePlugin)(
  withReactNativeOpenVpn,
  pkg.name,
  pkg.version
);
