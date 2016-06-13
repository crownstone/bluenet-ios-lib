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


class NaiveBayes {
    var fingerPrints = [String: FingerPrint]()
    var summaries = [String: [String: NBSummary]]() // classId: observableId: summary
    
    init() {}
    
    func loadFingerprint(id: String, _ fingerPrint: FingerPrint) {
        self.fingerPrints[id] = fingerPrint
        self._processFingerPrint(id, fingerPrint)
    }
    
    func predict(inputVector: [String: NSNumber]) -> String {
        var highestPrediction : Double = 0
        var highestPredictionLabel = ""
        
        for (label, summary) in self.summaries {
            var prediction = self._predict(inputVector, summary)
            if (highestPrediction < prediction) {
                highestPrediction = prediction
                highestPredictionLabel = label
            }
        }
        
        return highestPredictionLabel
    }
    
    func _predict(inputVector: [String: NSNumber], _ summary: [String: NBSummary]) -> Double {
        var totalProbability : Double = 1
        var totalMatches : Double = 0
        for (stoneId, rssi) in inputVector {
            if (summary[stoneId] != nil) {
                let RSSI = Double(rssi);
                let mean = summary[stoneId]!.mean
                let std =  summary[stoneId]!.std
                var exponent = exp(-(pow(RSSI - mean,2)/(2*pow(std,2))))
                totalProbability *= exponent / (sqrt(2*M_PI) * std)
                totalMatches += 1
            }
        }
        // we average to ensure missing datapoints will not influence the result.
        return totalProbability / totalMatches
    }
    
    
    
    func _processFingerPrint(id: String, _ fingerPrint: FingerPrint) {
        for (stoneId, measurements) in fingerPrint.data {
            let mean = self._getMean(measurements)
            let std = self._getSTD(mean, measurements)
            let summary = NBSummary(mean, std)
            self._addToSummary(id, stoneId: stoneId, summary: summary)
        }
    }
    
    func _addToSummary(id: String, stoneId: String, summary: NBSummary) {
        // we clear the existing summery if it existed
        self.summaries[id] = [String: NBSummary]()
        self.summaries[id]![stoneId] = summary
    }
    
    func _getMean(measurements: [NSNumber]) -> Double {
        var total : Double = 0
        for measurement in measurements {
            total += Double(measurement)
        }
        return (total / Double(measurements.count))
    }
    
    func _getSTD(mean: Double, _ measurements: [NSNumber]) -> Double {
        var total : Double = 0
        for measurement in measurements {
            total += pow(Double(measurement) - mean, 2)
        }
        var variance = total / Double(measurements.count)
        return sqrt(variance)
    }
}