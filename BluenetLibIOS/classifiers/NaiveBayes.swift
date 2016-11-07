//
//  NaiveBayes.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 13/06/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation

class NBSummary {
    var mean : Double
    var std : Double
    
    init (_ mean: Double, _ std: Double) {
        self.mean = mean
        self.std = std
    }
}

struct ProbabiltyReport {
    let sampleSize : Int
    let probability: Double
}


class NaiveBayes {
    var fingerprints = [String: Fingerprint]()
    var summaries = [String: [String: NBSummary]]() // classId: observableId: summary
    let minimumNumberOfSamples = 3
    
    init() {}
    
    func reset() {
        self.fingerprints = [String: Fingerprint]()
        self.summaries = [String: [String: NBSummary]]()
    }
    
    func loadFingerprint(_ locationId: String, _ fingerprint: Fingerprint) {
        self.fingerprints[locationId] = fingerprint
        self._processFingerPrint(locationId, fingerprint)
    }
    
    func predict(_ inputVector: [iBeaconPacket]) -> ClassifierResult {
        var highestPrediction : Double = 0
        var highestPredictionLabel = ""
        var valid = true
        
        if self.summaries.count == 0 {
            return ClassifierResult(valid: false, location: "")
        }
        
        for (label, summary) in self.summaries {
            let evaluation = self._predict(inputVector, summary)

            // Minimum requirement for good prediction.
            // When connecting for switching, the crownstone is not broadcasting iBeacon packets.
            if (evaluation.sampleSize < self.minimumNumberOfSamples) {
                valid = false
            }
            if (highestPrediction < evaluation.probability) {
                highestPrediction = evaluation.probability
                highestPredictionLabel = label
            }
        }
        
        return ClassifierResult(valid: valid, location: highestPredictionLabel)
    }
    
    func _predict(_ inputVector: [iBeaconPacket], _ summary: [String: NBSummary]) -> ProbabiltyReport {
        var totalProbability : Double = 1
        var samples : Int = 0
        for packet in inputVector {
            let stoneId = packet.idString
            if (summary[stoneId] != nil) {
                let RSSI = Double(packet.rssi);
                let mean = summary[stoneId]!.mean
                let std =  summary[stoneId]!.std
                let exponent = exp(-(pow(RSSI - mean,2)/(2*pow(std,2))))
                totalProbability *= exponent / (sqrt(2*M_PI) * std)
                samples += 1
            }
            else {
                print("CANNOT LOAD SUMMARY FOR \(stoneId)")
            }
        }

        if (samples == 0) {
            totalProbability = 0
        }
        
        return ProbabiltyReport(sampleSize: samples, probability: totalProbability)
    }
    
    
    static func _translateFingerPrint(_ fingerprint: Fingerprint) -> [String: [NSNumber]] {
        var translatedData = [String: [NSNumber]]()
        for (dataPoint) in fingerprint.data {
            for (stoneId, measurement) in dataPoint {
                if (stoneId != "timestamp") {
                    if (translatedData[stoneId] == nil) {
                        translatedData[stoneId] = [NSNumber]()
                    }
                    translatedData[stoneId]!.append(measurement)
                }
            }
        }
        return translatedData
    }
    
    func _processFingerPrint(_ locationId: String, _ fingerprint: Fingerprint) {
        var translatedData = NaiveBayes._translateFingerPrint(fingerprint)
        
        for (stoneId, measurements) in translatedData {
            let mean = self._getMean(measurements)
            let std = self._getSTD(mean, measurements)
            let summary = NBSummary(mean, std)
            
            self._addToSummary(locationId, stoneId: stoneId, summary: summary)
        }
    }
    
    func _addToSummary(_ locationId: String, stoneId: String, summary: NBSummary) {
        // we clear the existing summery if it existed
        if (self.summaries[locationId] == nil) {
            self.summaries[locationId] = [String: NBSummary]()
        }
        self.summaries[locationId]![stoneId] = summary
    }
    
    func _getMean(_ measurements: [NSNumber]) -> Double {
        var total : Double = 0
        for measurement in measurements {
            total += Double(measurement)
        }
        return (total / Double(measurements.count))
    }
    
    func _getSTD(_ mean: Double, _ measurements: [NSNumber]) -> Double {
        var total : Double = 0
        for measurement in measurements {
            total += pow(Double(measurement) - mean, 2)
        }
        let variance = total / Double(measurements.count)
        return sqrt(variance)
    }
}
