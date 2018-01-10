//
//  types.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 09/06/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation

public enum ControlType : UInt8 {
    case `switch`               = 0
    case pwm                    = 1
    case set_TIME               = 2
    case goto_DFU               = 3
    case reset                  = 4
    case factory_RESET          = 5
    case keep_ALIVE_STATE       = 6
    case keepAliveRepeat        = 7
    case enable_MESH            = 8
    case enable_ENCRYPTION      = 9
    case enable_IBEACON         = 10
    case enable_CONTINUOUS_POWER_MANAGEMENT = 11
    case enable_SCANNER         = 12
    case scan_FOR_DEVICES       = 13
    case user_FEEDBACK          = 14
    case schedule_ENTRY         = 15
    case relay                  = 16
    case validate_SETUP         = 17
    case request_SERVICE_DATA   = 18
    case disconnect             = 19
    case set_LED                = 20
    case no_OPERATION           = 21
    case increase_TX            = 22
    case reset_ERRORS           = 23
    case mesh_keepAliveRepeat   = 24
    case mesh_multiSwitch       = 25
    case schedule_REMOVE        = 26
    case mesh_keepAliveState    = 27
    case mesh_command           = 28
}

public enum ConfigurationType : UInt8 {
    case device_NAME = 0
    case device_TYPE = 1
    case room = 2
    case floor = 3
    case nearby_TIMEOUT = 4
    case pwm_PERIOD = 5
    case ibeacon_MAJOR = 6
    case ibeacon_MINOR = 7
    case ibeacon_UUID = 8
    case ibeacon_TX_POWER = 9
    case wifi_SETTINGS = 10
    case tx_POWER = 11
    case advertisement_INTERVAL = 12
    case passkey = 13
    case min_ENV_TEMP = 14
    case max_ENV_TEMP = 15
    case scan_DURATION = 16
    case scan_SEND_DELAY = 17
    case scan_BREAK_DURATION = 18
    case boot_DELAY = 19
    case max_CHIP_TEMP = 20
    case scan_FILTER = 21
    case scan_FILTER_FRACTION = 22
    case current_LIMIT = 23
    case mesh_ENABLED = 24
    case encryption_ENABLED = 25
    case ibeacon_ENABLED = 26
    case scanner_ENABLED = 27
    case continuous_POWER_MEASUREMENT_ENABLED = 28
    case tracker_ENABLED = 29
    case adc_SAMPLE_RATE = 30
    case power_SAMPLE_BURST_INTERVAL = 31
    case power_SAMPLE_CONTINUOUS_INTERVAL = 32
    case power_SAMPLE_CONTINUOUS_NUMBER_SAMPLES = 33
    case crownstone_IDENTIFIER = 34
    case admin_ENCRYPTION_KEY = 35
    case member_ENCRYPTION_KEY = 36
    case guest_ENCRYPTION_KEY = 37
    case default_ON = 38
    case scan_INTERVAL = 39
    case scan_WINDOW = 40
    case relay_HIGH_DURATION = 41
    case low_TX_POWER = 42
    case voltage_MULTIPLIER = 43
    case current_MULITPLIER = 44
    case voltage_ZERO = 45
    case current_ZERO = 46
    case power_ZERO = 47
    case power_AVERAGE_WINDOW = 48
    case mesh_ACCESS_ADDRESS = 49
}

public enum MeshHandle : UInt8 {
    case hub = 1
    case data
}

public enum StateType : UInt8 {
    case reset_COUNTER = 128
    case switch_STATE = 129
    case accumulated_ENERGY = 130
    case power_USAGE = 131
    case tracked_DEVICES = 132
    case schedule = 133
    case operation_MODE = 134
    case temperature = 135
    case time = 136
    case error_BITMASK = 139
}

public enum OpCode : UInt8 {
    case read = 0
    case write
    case notify
}

//*********** Mesh ***********//

public enum MeshCommandType : UInt8 {
    case control = 0
    case beacon
    case config
    case state
}

public enum IntentType : UInt8 {
    case regionEnter = 0
    case regionExit
    case enter
    case exit
    case manual
}

public enum MeshKeepAliveTypes : UInt8 {
    case sharedTimeout = 0
}

public enum MeshMultiSwitchType : UInt8 {
    case simpleList = 0
}


//*********** DFU ************//

public enum DfuOpcode : UInt8 {
    case start_DFU = 1
    case initialize_DFU = 2
    case receive_FIRMWARE_IMAGE = 3
    case validate_FIRMWARE_IMAGE = 4
    case activate_FIRMWARE_AND_RESET = 5
    case system_RESET = 6
    case report_RECEIVED_IMAGE_SIZE = 7
    case packet_RECEIPT_NOTIFICATION_REQUEST = 8
    case response_CODE = 16
    case packet_RECEIPT_NOTIFICATION = 17
}

public enum DfuImageType : UInt8 {
    case none = 0
    case softdevice = 1
    case bootloader = 2
    case softdevice_WITH_BOOTLOADER = 3
    case application = 4
}

public enum DfuResponseValue : UInt8 {
    case success = 1
    case invalid_STATE = 2
    case not_SUPPORTED = 3
    case data_SIZE_EXCEEDS_LIMIT = 4
    case crc_ERROR = 5
    case operation_FAILED = 6
}

public enum DfuInitPacket : UInt8 {
    case receive_INIT_PACKET = 0
    case init_PACKET_COMPLETE = 1
}
