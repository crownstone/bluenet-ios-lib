//
//  characteristics.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 13/06/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation

/*
 *
 *
 *  These are valid for SDK 0.8.1
 *
 *
 */

public struct DeviceCharacteristics {
    public static let HardwareRevision = "2a27"
    public static let FirmwareRevision = "2a26"
}

public struct CrownstoneCharacteristics {
    public static let Control          = "24f00001-7d10-4805-bfc1-7663a01c3bff"
    public static let MeshControl      = "24f00002-7d10-4805-bfc1-7663a01c3bff"
    public static let ConfigControl    = "24f00004-7d10-4805-bfc1-7663a01c3bff"
    public static let ConfigRead       = "24f00005-7d10-4805-bfc1-7663a01c3bff"
    public static let StateControl     = "24f00006-7d10-4805-bfc1-7663a01c3bff"
    public static let StateRead        = "24f00007-7d10-4805-bfc1-7663a01c3bff"
    public static let SessionNonce     = "24f00008-7d10-4805-bfc1-7663a01c3bff"
    public static let SessionNonceV5   = "24f0000e-7d10-4805-bfc1-7663a01c3bff"
    public static let SessionNonceV5_2 = "24f0000f-7d10-4805-bfc1-7663a01c3bff"
    public static let FactoryReset     = "24f00009-7d10-4805-bfc1-7663a01c3bff"
    public static let ControlV3        = "24f0000a-7d10-4805-bfc1-7663a01c3bff"
    public static let ResultV3         = "24f0000b-7d10-4805-bfc1-7663a01c3bff"
    public static let ControlV5        = "24f0000c-7d10-4805-bfc1-7663a01c3bff" // V5 to match protocol v5
    public static let ResultV5         = "24f0000d-7d10-4805-bfc1-7663a01c3bff" // V5 to match protocol v5
}

public struct SetupCharacteristics {
    public static let Control          = "24f10001-7d10-4805-bfc1-7663a01c3bff"
    public static let MacAddress       = "24f10002-7d10-4805-bfc1-7663a01c3bff"
    public static let SessionKey       = "24f10003-7d10-4805-bfc1-7663a01c3bff"
    public static let ConfigControl    = "24f10004-7d10-4805-bfc1-7663a01c3bff"
    public static let ConfigRead       = "24f10005-7d10-4805-bfc1-7663a01c3bff"
    public static let SetupControl     = "24f10007-7d10-4805-bfc1-7663a01c3bff"
    public static let GoToDFU          = "24f10006-7d10-4805-bfc1-7663a01c3bff"
    public static let SessionNonce     = "24f10008-7d10-4805-bfc1-7663a01c3bff"
    public static let SessionNonceV5   = "24f1000e-7d10-4805-bfc1-7663a01c3bff"
    public static let SessionNonceV5_2 = "24f1000f-7d10-4805-bfc1-7663a01c3bff"
    public static let SetupControlV2   = "24f10009-7d10-4805-bfc1-7663a01c3bff"
    public static let SetupControlV3   = "24f1000a-7d10-4805-bfc1-7663a01c3bff"// setupControlV3 uses controlV2 protocols, and is paired with resultV3
    public static let SetupControlV5   = "24f1000c-7d10-4805-bfc1-7663a01c3bff"// V5 to match protocol v5
    public static let ResultV3         = "24f1000b-7d10-4805-bfc1-7663a01c3bff"
    public static let ResultV5         = "24f1000d-7d10-4805-bfc1-7663a01c3bff"// V5 to match protocol v5
}

public struct GeneralCharacteristics {
    public static let Temperature      = "24f20001-7d10-4805-bfc1-7663a01c3bff"
    public static let Reset            = "24f20002-7d10-4805-bfc1-7663a01c3bff"
}

public struct PowerCharacteristics {
    public static let PWM              = "24f30001-7d10-4805-bfc1-7663a01c3bff"
    public static let Relay            = "24f30002-7d10-4805-bfc1-7663a01c3bff"
    public static let PowerSamples     = "24f30003-7d10-4805-bfc1-7663a01c3bff"
    public static let PowerConsumption = "24f30004-7d10-4805-bfc1-7663a01c3bff"
}

public struct IndoorLocalizationCharacteristics {
    public static let TrackControl     = "24f40001-7d10-4805-bfc1-7663a01c3bff"
    public static let TrackedDevices   = "24f40002-7d10-4805-bfc1-7663a01c3bff"
    public static let ScanControl      = "24f40003-7d10-4805-bfc1-7663a01c3bff"
    public static let ScannedDevices   = "24f40004-7d10-4805-bfc1-7663a01c3bff"
    public static let RSSI             = "24f40005-7d10-4805-bfc1-7663a01c3bff"
}

public struct ScheduleCharacteristics {
    public static let SetTime          = "24f50001-7d10-4805-bfc1-7663a01c3bff"
    public static let ScheduleWrite    = "24f50002-7d10-4805-bfc1-7663a01c3bff"
    public static let ScheduleRead     = "24f50003-7d10-4805-bfc1-7663a01c3bff"
}

public struct MeshCharacteristics {
    public static let MeshData         = "2a1e0004-fd51-d882-8ba8-b98c0000cd1e"
    public static let Value            = "2a1e0005-fd51-d882-8ba8-b98c0000cd1e"
}

public struct SecureDFUCharacteristics {
    public static let ControlPoint   = "8EC90001-F315-4F60-9FB8-838830DAEA50"
    public static let Packet         = "8EC90002-F315-4F60-9FB8-838830DAEA50"
}

public struct DFUCharacteristics {
    public static let ControlPoint   = "00001531-1212-EFDE-1523-785FEABCD123"
    public static let Packet         = "00001532-1212-EFDE-1523-785FEABCD123"
}
