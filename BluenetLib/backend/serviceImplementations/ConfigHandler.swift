//
//  ConfigHandler.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 10/08/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit
import CoreBluetooth

open class ConfigHandler {
    let bleManager : BleManager!
    var settings : BluenetSettings!
    let eventBus : EventBus!
    
    init (bleManager:BleManager, eventBus: EventBus, settings: BluenetSettings) {
        self.bleManager = bleManager
        self.settings   = settings
        self.eventBus   = eventBus
    }
    
    open func setIBeaconUUID(_ uuid: String) -> Promise<Void> {
        let data = WriteConfigPacket(type: ConfigurationType.ibeacon_UUID, payload: uuid)
        return self._writeToConfig(packet: data.getPacket())
    }
    
    open func getDimmerTempUp() -> Promise<Float> {
        return self._getConfig(ConfigurationType.DIMMER_TEMP_UP_VOLTAGE)
    }
    
    open func setDimmerTempUp(_ voltage: Float) -> Promise<Void> {
        let data = WriteConfigPacket(type: ConfigurationType.DIMMER_TEMP_UP_VOLTAGE, payloadFloat: voltage)
        return self._writeToConfig(packet: data.getPacket())
    }
    
    open func setIBeaconMajor(_ major: UInt16) -> Promise<Void> {
        let data = WriteConfigPacket(type: ConfigurationType.ibeacon_MAJOR, payload16: major)
        return self._writeToConfig(packet: data.getPacket())
    }
    
    open func setIBeaconMinor(_ minor: UInt16) -> Promise<Void> {
        let data = WriteConfigPacket(type: ConfigurationType.ibeacon_MINOR, payload16: minor)
        return self._writeToConfig(packet: data.getPacket())
    }
    
    open func setPWMPeriod(_ pwmPeriod: NSNumber) -> Promise<Void> {
        let data = WriteConfigPacket(type: ConfigurationType.pwm_PERIOD, payload32: pwmPeriod.uint32Value)
        return self._writeToConfig(packet: data.getPacket())
    }

    
    open func getPWMPeriod() -> Promise<NSNumber> {
        return Promise<NSNumber> { fulfill, reject in
            let configPromise : Promise<UInt32> = self._getConfig(ConfigurationType.pwm_PERIOD)
            configPromise.then{ period -> Void in fulfill(NSNumber(value: period)) }.catch{err in reject(err)}
        }
    }
    
    open func setScanDuration(_ scanDurationsMs: NSNumber) -> Promise<Void> {
        let data = WriteConfigPacket(type: ConfigurationType.scan_DURATION, payload16: scanDurationsMs.uint16Value)
        return self._writeToConfig(packet: data.getPacket())
    }
    
    open func setScanSendDelay(_ scanSendDelay: NSNumber) -> Promise<Void> {
        let data = WriteConfigPacket(type: ConfigurationType.scan_SEND_DELAY, payload16: scanSendDelay.uint16Value)
        return self._writeToConfig(packet: data.getPacket())
    }
    
    open func setScanBreakDuration(_ scanBreakDuration: NSNumber) -> Promise<Void> {
        let data = WriteConfigPacket(type: ConfigurationType.scan_BREAK_DURATION, payload16: scanBreakDuration.uint16Value)
        return self._writeToConfig(packet: data.getPacket())
    }
    
    open func setScanFilter(_ scanFilter: NSNumber) -> Promise<Void> {
        let data = WriteConfigPacket(type: ConfigurationType.scan_BREAK_DURATION, payload8: scanFilter.uint8Value)
        return self._writeToConfig(packet: data.getPacket())
    }
    
    open func setScanFilterFraction(_ scanFilterFraction: NSNumber) -> Promise<Void> {
        let data = WriteConfigPacket(type: ConfigurationType.scan_FILTER_FRACTION, payload16: scanFilterFraction.uint16Value)
        return self._writeToConfig(packet: data.getPacket())
    }
    
    open func setUartState(_ state: NSNumber) -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            if (state == 3 || state == 1 || state == 0) {
                let data = WriteConfigPacket(type: ConfigurationType.UART_ENABLED, payload8: state.uint8Value)
                self._writeToConfig(packet: data.getPacket())
                    .then{ _ in fulfill(()) }
                    .catch{err in reject(err)}
            }
            else {
                LOG.warn("BluenetLib: setUartState: Only 0, 1, or 3 are allowed inputs. You gave: \(state).")
                reject(BleError.INVALID_INPUT)
            }
        }
    }
    
    open func setMeshChannel(_ channel: NSNumber) -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            if (channel == 37 || channel == 38 || channel == 39) {
                let data = WriteConfigPacket(type: ConfigurationType.MESH_CHANNEL, payload8: channel.uint8Value)
                self._writeToConfig(packet: data.getPacket())
                    .then{ _ in fulfill(()) }
                    .catch{err in reject(err)}
            }
            else {
                LOG.warn("BluenetLib: setMeshChannel: Only 37, 38 or 39 are allowed inputs. You gave: \(channel).")
                reject(BleError.INVALID_INPUT)
            }
        }
    }
    
    open func getMeshChannel() -> Promise<NSNumber> {
        return Promise<NSNumber> { fulfill, reject in
            let configPromise : Promise<UInt8> = self._getConfig(ConfigurationType.MESH_CHANNEL)
            configPromise.then{ channel -> Void in fulfill(NSNumber(value: channel)) }.catch{err in reject(err)}
        }
    }
    
    open func setTxPower (_ txPower: NSNumber) -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            if (txPower == -40 || txPower == -30 || txPower == -20 || txPower == -16 || txPower == -12 || txPower == -8 || txPower == -4 || txPower == 0 || txPower == 4) {
                let data = WriteConfigPacket(type: ConfigurationType.tx_POWER, payload8: txPower.int8Value)
                self._writeToConfig(packet: data.getPacket())
                    .then{ _ in fulfill(()) }
                    .catch{ err in reject(err) }
            }
            else {
                reject(BleError.INVALID_TX_POWER_VALUE)
            }
        }
    }
    
    func _writeToConfig(packet: [UInt8]) -> Promise<Void> {
        return self.bleManager.writeToCharacteristic(
            CSServices.CrownstoneService,
            characteristicId: CrownstoneCharacteristics.ConfigControl,
            data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
            type: CBCharacteristicWriteType.withResponse
        )
    }
    
    
    public func _getConfig<T>(_ config : ConfigurationType) -> Promise<T> {
        return Promise<T> { fulfill, reject in
            let writeCommand : voidPromiseCallback = { 
                return self.bleManager.writeToCharacteristic(
                    CSServices.CrownstoneService,
                    characteristicId: CrownstoneCharacteristics.ConfigControl,
                    data: ReadConfigPacket(type: config).getNSData(),
                    type: CBCharacteristicWriteType.withResponse);
            }
            self.bleManager.setupSingleNotification(CSServices.CrownstoneService, characteristicId: CrownstoneCharacteristics.ConfigRead, writeCommand: writeCommand)
                .then{ data -> Void in
                    var validData = [UInt8]()
                    if (data.count > 3) {
                        for i in (4...data.count - 1) {
                            validData.append(data[i])
                        }
                        
                        do {
                            let result : T = try Convert(validData)
                            fulfill(result)
                        }
                        catch let err {
                            reject(err)
                        }
                    }
                    else {
                        reject(BleError.INCORRECT_RESPONSE_LENGTH)
                    }
                }
                .catch{ err in reject(err) }
        }
    }


    
    
}
