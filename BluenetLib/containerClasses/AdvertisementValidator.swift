//
//  AdvertismentTester
//  BluenetLib
//
//  Created by Alex de Mulder on 30/08/2018.
//  Copyright © 2018 Alex de Mulder. All rights reserved.
//

import Foundation


struct validationSet {
    var uniqueIdentifier: NSNumber? = nil
    var crownstoneId: UInt8          = 0
    var validMeasurementCount: UInt8 = 0
}


/**
 *
 * Every Crownstone has one of these classes, it is used to check which keys we should use to decrypt the payload.
 *
 */
public class AdvertismentValidator {
    
    public var validated = false
    public var validatedMode : CrownstoneMode = .unknown
    public var validatedReferenceId : String?
    public var cantDecrypt = false
    public var failedTime : Double = 0
    
    let retryValidationTimeoutSeconds : Double = 300 // we will retry decrypting these Crownstones in 5 minutes.
    let validationMatchThreshold = 2 // this means the measurement has been the same for 3 times
    let decryptionAttemptThreshold = 10 // we will try to decrypt this payload with all keys for 10 times. If that does not work, we stop trying for a while.
    
    public var operationMode = CrownstoneMode.unknown
    
    var settings : BluenetSettings!
    var validationMap = [String: validationSet]()
    var failedValidationCounter = 0
    
    init(settings: BluenetSettings) {
        self.settings = settings
    }
    
    public func releaseLockOnDecryption() {
        self.cantDecrypt = false
        self.failedValidationCounter = 0
    }
    
    public func update(advertisement: Advertisement) {
        // dfu and setup crownstones can be identified without decryption.
        let incomingOperationMode = advertisement.getOperationMode()
        if (incomingOperationMode == CrownstoneMode.dfu || incomingOperationMode == CrownstoneMode.setup) {
            self.advertisementIsValidated(validatedMode: incomingOperationMode)
            self.operationMode = incomingOperationMode
            
            return
        }
        
        // we have verified this Crownstone before
        if (self.validated && self.validatedMode == incomingOperationMode) {
            // we assume it's in operation mode, if not --> we're not verified
            if (incomingOperationMode == CrownstoneMode.unknown) {
                self.invalidate()
            }
            else if (self.validatedReferenceId != nil) {
                // check if we can validate this message with the established key
                if (!self.validate(advertisement, referenceId: self.validatedReferenceId!)) {
                    // if we fail to validate this with the previously accepted referenceId --> not verified!
                    self.invalidate()
                    self.attemptValidation(advertisement: advertisement)
                }
            }
            else {
                // we do not have a validated reference Id --> we're not validated for operation mode.
                self.invalidate()
                self.attemptValidation(advertisement: advertisement)
            }
        }
        else {
            // if there is a mode change, we should invalidate.
            if (self.validated && self.validatedMode != incomingOperationMode) {
                self.invalidate()
            }
            
            // if we have given up on this Crownstone, we don't have to validate it.
            if (self.cantDecrypt == false) {
                self.attemptValidation(advertisement: advertisement)
            }
            else {
                let timeSinceGivenUp = Date().timeIntervalSince1970 - self.failedTime
                if (timeSinceGivenUp > self.retryValidationTimeoutSeconds) {
                    self.releaseLockOnDecryption()
                    self.attemptValidation(advertisement: advertisement)
                }
                
            }
        }
    }
   
    
    func attemptValidation(advertisement: Advertisement) {
        let incomingOperationMode = advertisement.getOperationMode()
        var initialRun = false;
        if (incomingOperationMode == CrownstoneMode.operation) {
            for keySet in self.settings.keySetList {
                // we want to check if this is the first time we try validation. The first time no key will return a valid measurement.
                if (self.validationMap[keySet.referenceId] == nil) {
                    initialRun = true
                }
                
                if (self.validate(advertisement, referenceId: keySet.referenceId)) {
                    self.addValidMeasurement(operationMode: incomingOperationMode, referenceId: keySet.referenceId)
                    return
                }
            }
        }
    
        // we we're here and all the validation maps have been initiated, we invalidate the advertisement
        // this means that we could not validate the decrypted scan response with any of our keys
        if (initialRun == false) {
            self.invalidate()
        }
    }
    
    
    
    func advertisementIsValidated(validatedMode: CrownstoneMode, referenceId : String? = nil) {
        self.validated = true
        self.validatedMode = validatedMode
        self.cantDecrypt = false
        self.validatedReferenceId = referenceId
        self.failedValidationCounter = 0
    }
    
    
    func addValidMeasurement(operationMode: CrownstoneMode, referenceId: String) {
        if (self.validationMap[referenceId] != nil) {
            // the validate method will add 1 to the validMeasurementCount
            if (self.validationMap[referenceId]!.validMeasurementCount >= self.validationMatchThreshold) {
                self.advertisementIsValidated(validatedMode: operationMode, referenceId: referenceId)
            }
            
            self.cantDecrypt = false
            self.failedValidationCounter = 0
        }
    }
    
    func invalidate() {
        self.validated = false
        self.validatedReferenceId = nil
        self.failedValidationCounter += 1
        
        if (self.failedValidationCounter >= self.decryptionAttemptThreshold) {
            self.cantDecrypt = true
            self.failedTime = Date().timeIntervalSince1970
        }
    }
    
    
    /**
    *   This method will check if the Crownstone can be validated by the provided referenceId.
    *   It will only be called on operation mode Crownstones.
    *   This method is the owner of the validationMap objects and is the only one that changes them.
    **/
    func validate(_ advertisement: Advertisement, referenceId: String) -> Bool {
        
        // we need to have a guest key for this reference Id
        let guestKey = self.settings.getGuestKey(referenceId: referenceId)
        if (guestKey == nil) {
            return false
        }
    
        if (self.validationMap[referenceId] == nil) {
            self.validationMap[referenceId] = validationSet()
        }
        
        let scanResponse = advertisement.scanResponse!
        var validationMap = self.validationMap[referenceId]!
        
        scanResponse.decrypt(guestKey!)
        
        var validMeasurement = false
        if (validationMap.uniqueIdentifier != nil) {
            // we match the unique identifier to check if the advertisement is different. If it is the same, we're checking duplicates.
            if (validationMap.uniqueIdentifier! != scanResponse.uniqueIdentifier) {
                if (scanResponse.validation != 0 && (scanResponse.opCode == 5 || scanResponse.opCode == 3)) {
                    //datatype 1 is the error packet, this does not have a validation element
                    if (scanResponse.dataType != 1) {
                        if (scanResponse.validation == 0xFA) {
                            validMeasurement = true
                        }
                    }
                    else {
                        if (validationMap.crownstoneId == scanResponse.crownstoneId) {
                            validMeasurement = true
                        }
                    }
                }
                else if (scanResponse.opCode == 1) {
                    if (validationMap.crownstoneId == scanResponse.crownstoneId) {
                        validMeasurement = true
                    }
                }
            }

            if (validMeasurement) {
                // dont overflow.
                if (validationMap.validMeasurementCount < 10) {
                    validationMap.validMeasurementCount += 1
                }
            }
            else {
                // if this is an invalid measurement, we set the valid measurement counter back to 0
                validationMap.validMeasurementCount = 0
            }
        }
        
        validationMap.uniqueIdentifier = scanResponse.uniqueIdentifier
        validationMap.crownstoneId     = scanResponse.crownstoneId
        
        // false here means not completely validated yet.
        return validMeasurement
    }
    
    
}
