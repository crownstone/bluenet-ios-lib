//
//  types.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 09/06/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation

enum ControlType : UInt8 {
    case SWITCH = 0
    case PWM = 1
    case SET_TIME = 2
    case GOTO_DFU = 3
    case RESET = 4
    case FACTORY_RESET = 5
    case KEEP_ALIVE_STATE = 6
    case KEEP_ALIVE = 7
    case ENABLE_MESH = 8
    case ENABLE_ENCRYPTION = 9
    case ENABLE_IBEACON = 10
    case ENABLE_CONTINUOUS_POWER_MANAGEMENT = 11
    case ENABLE_SCANNER = 12
    case SCAN_FOR_DEVICES = 13
    case USER_FEEDBACK = 14
    case SCHEDULE_ENTRY = 15
    case RELAY = 16
    case VALIDATE_SETUP = 17
    case REQUEST_SERVICE_DATA = 18
    case DISCONNECT = 19
}

enum ConfigurationType : UInt8 {
    case DEVICE_NAME = 0
    case DEVICE_TYPE = 1
    case ROOM = 2
    case FLOOR = 3
    case NEARBY_TIMEOUT = 4
    case PWM_FREQUENCY = 5
    case IBEACON_MAJOR = 6
    case IBEACON_MINOR = 7
    case IBEACON_UUID = 8
    case IBEACON_TX_POWER = 9
    case WIFI_SETTINGS = 10
    case TX_POWER = 11
    case ADVERTISEMENT_INTERVAL = 12
    case PASSKEY = 13
    case MIN_ENV_TEMP = 14
    case MAX_ENV_TEMP = 15
    case SCAN_DURATION = 16
    case SCAN_SEND_DELAY = 17
    case SCAN_BREAK_DURATION = 18
    case BOOT_DELAY = 19
    case MAX_CHIP_TEMP = 20
    case SCAN_FILTER = 21
    case SCAN_FILTER_FRACTION = 22
    case CURRENT_LIMIT = 23
    case MESH_ENABLED = 24
    case ENCRYPTION_ENABLED = 25
    case IBEACON_ENABLED = 26
    case SCANNER_ENABLED = 27
    case CONTINUOUS_POWER_MEASUREMENT_ENABLED = 28
    case TRACKER_ENABLED = 29
    case ADC_SAMPLE_RATE = 30
    case POWER_SAMPLE_BURST_INTERVAL = 31
    case POWER_SAMPLE_CONTINUOUS_INTERVAL = 32
    case POWER_SAMPLE_CONTINUOUS_NUMBER_SAMPLES = 33
    case CROWNSTONE_IDENTIFIER = 34
    case ADMIN_ENCRYPTION_KEY = 35
    case MEMBER_ENCRYPTION_KEY = 36
    case GUEST_ENCRYPTION_KEY = 37
    case DEFAULT_ON = 38
    case SCAN_INTERVAL = 39
    case SCAN_WINDOW = 40
    case RELAY_HIGH_DURATION = 41
    case LOW_TX_POWER = 42
    case VOLTAGE_MULTIPLIER = 43
    case CURRENT_MULITPLIER = 44
    case VOLTAGE_ZERO = 45
    case CURRENT_ZERO = 46
    case POWER_ZERO = 47
    case POWER_AVERAGE_WINDOW = 48
    case MESH_ACCESS_ADDRESS = 49
}

//TODO: update to 0.4.0
enum MeshHandle : UInt8 {
    case Hub = 1
    case Data
}

enum StateType : UInt8 {
    case RESET_COUNTER = 0
    case SWITCH_STATE
    case ACCUMULATED_ENERGY
    case POWER_USAGE
    case TRACKED_DEVICES
    case SCHEDULE
    case OPERATION_MODE
    case TEMPERATURE}

enum OpCode : UInt8 {
    case READ = 0
    case WRITE
    case NOTIFY
}

//*********** DFU ************//

enum DfuOpcode : UInt8 {
    case START_DFU = 1
    case INITIALIZE_DFU = 2
    case RECEIVE_FIRMWARE_IMAGE = 3
    case VALIDATE_FIRMWARE_IMAGE = 4
    case ACTIVATE_FIRMWARE_AND_RESET = 5
    case SYSTEM_RESET = 6
    case REPORT_RECEIVED_IMAGE_SIZE = 7
    case PACKET_RECEIPT_NOTIFICATION_REQUEST = 8
    case RESPONSE_CODE = 16
    case PACKET_RECEIPT_NOTIFICATION = 17
}

enum DfuImageType : UInt8 {
    case NONE = 0
    case SOFTDEVICE = 1
    case BOOTLOADER = 2
    case SOFTDEVICE_WITH_BOOTLOADER = 3
    case APPLICATION = 4
}

enum DfuResponseValue : UInt8 {
    case SUCCESS = 1
    case INVALID_STATE = 2
    case NOT_SUPPORTED = 3
    case DATA_SIZE_EXCEEDS_LIMIT = 4
    case CRC_ERROR = 5
    case OPERATION_FAILED = 6
}

enum DfuInitPacket : UInt8 {
    case RECEIVE_INIT_PACKET = 0
    case INIT_PACKET_COMPLETE = 1
}