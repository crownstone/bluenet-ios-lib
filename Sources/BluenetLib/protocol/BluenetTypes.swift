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
    case allow_dimming          = 29
    case lock_switch            = 30
    case setup                  = 31
    case enable_switchcraft     = 32
}

public func mapControlType_toV3(type: ControlType) -> ControlTypeV3 {
    switch (type) {
        case .`switch`:
            return ControlTypeV3.`switch`
        case .pwm:
            return ControlTypeV3.pwm
        case .set_TIME:
            return ControlTypeV3.set_TIME
        case .goto_DFU:
            return ControlTypeV3.goto_DFU
        case .reset:
            return ControlTypeV3.reset
        case .factory_RESET:
            return ControlTypeV3.factory_RESET
        case .relay:
            return ControlTypeV3.relay
        case .disconnect:
            return ControlTypeV3.disconnect
        case .no_OPERATION:
            return ControlTypeV3.no_OPERATION
        case .reset_ERRORS:
            return ControlTypeV3.reset_ERRORS
        case .mesh_command:
            return ControlTypeV3.mesh_command
        case .allow_dimming:
            return ControlTypeV3.allow_dimming
        case .lock_switch:
            return ControlTypeV3.lock_switch
        case .setup:
            return ControlTypeV3.setup
        default:
            return ControlTypeV3.UNSPECIFIED

    }
}

public enum ControlTypeV3 : UInt16 {
    case setup                  = 0
    case factory_RESET          = 1
    case getState               = 2
    case setState               = 3
    case GET_BOOTLOADER_VERSION = 4
    case GET_UICR_DATA          = 5
    case reset                  = 10
    case goto_DFU               = 11
    case no_OPERATION           = 12
    case disconnect             = 13
    case `switch`               = 20
    case multiSwitch            = 21
    case pwm                    = 22
    case relay                  = 23
    case set_TIME               = 30
    case setTX                  = 31
    case reset_ERRORS           = 32
    case mesh_command           = 33 // ?
    case allow_dimming          = 40
    case lock_switch            = 41
    case UART_message           = 50
    case hub_data               = 51
    case addBehaviour           = 60
    case replaceBehaviour       = 61
    case removeBehaviour        = 62
    case getBehaviour           = 63
    case getBehaviourIndices    = 64
    
    case getBehaviourDebug      = 69
    case registerTrackedDevice  = 70
    case trackedDeviceHeartbeat = 71
    
    case getUptime              = 80
    case getAdcRestart          = 81
    case getSwitchHistory       = 82
    case getPowerSamples        = 83
    case getMinSchedulerFreeSpace = 84
    case getLastResetReason     = 85
    case getGPREGRET            = 86
    case getAdcChannelSwaps     = 87
    case getRAMStatistics       = 88
    case uploadMicroApp         = 90
    case cleanFlashMemory       = 100
    
    case UNSPECIFIED = 65535
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
    case CURRENT_CONSUMPTION_THRESHOLD = 50
    case CURRENT_CONSUMPTION_THRESHOLD_DIMMER = 51
    case DIMMER_TEMP_UP_VOLTAGE = 52
    case DIMMER_TEMP_DOWN_VOLTAGE = 53
    case PWM_ALLOWED = 54
    case SWITCH_LOCKED = 55
    case SWITCHCRAFT_ENABLED = 56
    case SWITCHCRAFT_THRESHOLD = 57
    case MESH_CHANNEL = 58
    case UART_ENABLED = 59
    case DEVICE_NAME = 60
    case SERVICE_DATA_KEY = 61
    case MESH_DEVICE_KEY = 62
    case MESH_APPLICATION_KEY = 63
    case MESH_NETWORK_KEY = 64
    case LOCALIZATION_KEY = 65
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
}

//*********** Mesh ***********//

public enum MeshCommandType : UInt8 {
    case control = 0
}

public enum IntentType : UInt8 {
    case regionEnter = 0
    case regionExit  = 1
    case enter       = 2
    case exit        = 3
    case manual      = 4
}

public enum MeshKeepAliveTypes : UInt8 {
    case sharedTimeout = 1
}

public enum MeshMultiSwitchType : UInt8 {
    case simpleList = 0
}

//****************** DEVICE TYPES IN ADVERTISEMENTS *************//

public enum DeviceType : UInt8 {
    case undefined = 0
    case plug = 1
    case guidestone = 2
    case builtin = 3
    case crownstoneUSB = 4
    case builtinOne = 5
    case plugOne = 6
    case hub = 7
    
    case unset = 255
}


//****************** RESULT VALUES *************//

public enum ResultValue: UInt16 {
    case SUCCESS                = 0      // Completed successfully.
    case WAIT_FOR_SUCCESS       = 1      // Command is successful so far, but you need to wait for SUCCESS.
    case BUFFER_UNASSIGNED      = 16     // No buffer was assigned for the command.
    case BUFFER_LOCKED          = 17     // Buffer is locked, failed queue command.
    case BUFFER_TO_SMALL        = 18
    case WRONG_PAYLOAD_LENGTH   = 32     // Wrong payload lenght provided.
    case WRONG_PARAMETER        = 33     // Wrong parameter provided.
    case INVALID_MESSAGE        = 34     // invalid message provided.
    case UNKNOWN_OP_CODE        = 35     // Unknown operation code provided.
    case UNKNOWN_TYPE           = 36     // Unknown type provided.
    case NOT_FOUND              = 37     // The thing you were looking for was not found.
    case NO_SPACE               = 38
    case BUSY                   = 39
    case ERR_ALREADY_EXISTS     = 41
    case ERR_TIMEOUT            = 42
    case ERR_CANCELLED          = 43
    case ERR_PROTOCOL_UNSUPPORTED = 44
    case NO_ACCESS              = 48     // Invalid access for this command.
    case NOT_AVAILABLE          = 64     // Command currently not available.
    case NOT_IMPLEMENTED        = 65     // Command not implemented (not yet or not anymore).
    case WRITE_DISABLED         = 80     // Write is disabled for given type.
    case ERR_WRITE_NOT_ALLOWED  = 81     // Direct write is not allowed for this type, use command instead.
    case ADC_INVALID_CHANNEL    = 96     // Invalid adc input channel selected.
    
    
    case UNSPECIFIED            = 65535
}

//****************** PROCESS TYPES *************//

public enum ProcessType: UInt16 {
    case CONTINUE = 0
    case FINISHED = 1
    case ABORT_ERROR = 2
}



// NOTE: YOU CANNOT DELETE FROM THIS LIST AS IT MUST SHARE THE VALUES WITH THE CONFIG AND STATE LEGACY ENUMS
public enum StateTypeV3 : UInt16 {
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
    case CURRENT_CONSUMPTION_THRESHOLD = 50
    case CURRENT_CONSUMPTION_THRESHOLD_DIMMER = 51
    case DIMMER_TEMP_UP_VOLTAGE = 52
    case DIMMER_TEMP_DOWN_VOLTAGE = 53
    case PWM_ALLOWED = 54
    case SWITCH_LOCKED = 55
    case SWITCHCRAFT_ENABLED = 56
    case SWITCHCRAFT_THRESHOLD = 57
    case MESH_CHANNEL = 58
    case UART_ENABLED = 59
    case DEVICE_NAME = 60
    case SERVICE_DATA_KEY = 61
    case MESH_DEVICE_KEY = 62
    case MESH_APPLICATION_KEY = 63
    case MESH_NETWORK_KEY = 64
    case LOCALIZATION_KEY = 65
    case START_DIMMER_ON_ZERO_CROSSING = 66
    case TAP_TO_TOGGLE_ENABLED = 67
    case TAP_TO_TOGGLE_RSSI_THRESHOLD_OFFSET = 68
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
    case sunTimes = 149
    case behaviourSettings = 150
    case softOnSpeed = 156
    case hubMode = 157
    case uartKey = 158
}

public enum GetPersistenceMode : UInt8 {
    case CURRENT = 0
    case STORED = 1
    case FIRMWARE_DEFAULT = 2
}

public enum SetPersistenceMode : UInt8 {
    case TEMPORARY = 0
    case STORED = 1
}
