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
    case PWM
    case SET_TIME
    case GOTO_DFU
    case RESET
    case FACTORY_RESET
    case KEEP_ALIVE_STATE
    case KEEP_ALIVE
    case ENABLE_MESH
    case ENABLE_ENCRYPTION
    case ENABLE_IBEACON
    case ENABLE_CONTINUOUS_POWER_MANAGEMENT
    case ENABLE_SCANNER
    case SCAN_FOR_DEVICES
    case USER_FEEDBACK
    case SCHEDULE_ENTRY
}

enum ConfigurationType : UInt8 {
    case DEVICE_NAME = 0
    case DEVICE_TYPE
    case ROOM
    case FLOOR
    case NEARBY_TIMEOUT
    case PWM_FREQUENCY
    case IBEACON_MAJOR
    case IBEACON_MINOR
    case IBEACON_UUID
    case IBEACON_TX_POWER
    case WIFI_SETTINGS
    case TX_POWER
    case ADVERTISEMENT_INTERVAL
    case PASSKEY
    case MIN_ENV_TEMP
    case MAX_ENV_TEMP
    case SCAN_DURATION
    case SCAN_SEND_DELAY
    case SCAN_BREAK_DURATION
    case BOOT_DELAY
    case MAX_CHIP_TEMP
    case SCAN_FILTER
    case SCAN_FILTER_FRACTION
    case CURRENT_LIMIT
    case MESH_ENABLED
    case ENCRYPTION_ENABLED
    case IBEACON_ENABLED
    case SCANNER_ENABLED
    case CONTINUOUS_POWER_MEASUREMENT_ENABLED
    case TRACKER_ENABLED
    case ADC_SAMPLE_RATE
    case POWER_SAMPLE_BURST_INTERVAL
    case POWER_SAMPLE_CONTINUOUS_INTERVAL
    case POWER_SAMPLE_CONTINUOUS_NUMBER_SAMPLES
    case CROWNSTONE_IDENTIFIER
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