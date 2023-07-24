//
//  Configuration.swift
//  Demo
//
//  Created by Davide De Rosa on 6/13/20.
//  Copyright (c) 2023 Davide De Rosa. All rights reserved.
//
//  https://github.com/keeshux
//
//  This file is part of TunnelKit.
//
//  TunnelKit is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  TunnelKit is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with TunnelKit.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import TunnelKitCore
import TunnelKitOpenVPN

extension OpenVPN {
    struct DemoConfiguration {
   
      

        struct Parameters {
            let title: String

            let appGroup: String

            let ovpnString: String

        }

      static func make(params: Parameters) -> OpenVPN.ProviderConfiguration? {
      
        do {
          let cfg = try OpenVPN.ConfigurationParser.parsed(fromContents: params.ovpnString)
          
          print("Error: \(String(describing: cfg.warning))")
          var providerConfiguration = OpenVPN.ProviderConfiguration(params.title, appGroup: params.appGroup, configuration: cfg.configuration)
          providerConfiguration.shouldDebug = true
          providerConfiguration.masksPrivateData = true
          return providerConfiguration
        } catch {
          return nil
        }
      
        
      }
    }
}


