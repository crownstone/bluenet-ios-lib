//
//  StateHandler
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 10/08/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit
import CoreBluetooth

open class StateHandler {
    let bleManager : BleManager!
    var settings : BluenetSettings!
    let eventBus : EventBus!
    var deviceList : [String: AvailableDevice]!
    
    init (bleManager:BleManager, eventBus: EventBus, settings: BluenetSettings, deviceList: [String: AvailableDevice]) {
        self.bleManager = bleManager
        self.settings   = settings
        self.eventBus   = eventBus
        self.deviceList = deviceList
    }
    
    
    open func getError() -> Promise<CrownstoneErrors> {
        return Promise<CrownstoneErrors> { fulfill, reject in
            self.getErrorBitmask()
                .then{ data -> Void in
                    let uint32 = Conversion.uint8_array_to_uint32(data)
                    let csError = CrownstoneErrors(bitMask: uint32)
                    fulfill(csError)
                }
                .catch{ err in reject(err) }
        }
    }
    
    
    open func getErrorBitmask() -> Promise<[UInt8]> {
        return self.bleManager.setupSingleNotification(CSServices.CrownstoneService, characteristicId: CrownstoneCharacteristics.StateRead) { () -> Promise<Void> in
            let packet = WriteStatePacket(type: StateType.error_BITMASK).getPacket()
            return self.bleManager.writeToCharacteristic(
                CSServices.CrownstoneService,
                characteristicId: CrownstoneCharacteristics.StateControl,
                data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
                type: CBCharacteristicWriteType.withResponse
            )
        }
    }
    
    func _writeToState(packet: [UInt8]) -> Promise<Void> {
        return self.bleManager.writeToCharacteristic(
            CSServices.CrownstoneService,
            characteristicId: CrownstoneCharacteristics.ConfigControl,
            data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
            type: CBCharacteristicWriteType.withResponse
        )
    }
    
    
    
}
