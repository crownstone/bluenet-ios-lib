//
//  Classifier.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 13/06/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation

enum Classifiers {
    case naive_BAYES
}

struct ClassifierResult {
    let valid : Bool
    let location : String
}


open class ClassifierWrapper {
    var classifierType = Classifiers.naive_BAYES
    var naiveBayes = NaiveBayes()
    
    init() {}
    
    init(classifier: Classifiers) {
        self.classifierType = classifier
    }
    
    func loadFingerprint(_ locationId: String, fingerprint: Fingerprint) {
        switch (self.classifierType) {
            case .naive_BAYES:
                self.naiveBayes.loadFingerprint(locationId, fingerprint)
        }
    }
    
    func predict(_ inputVector: [iBeaconPacket]) -> ClassifierResult {
        switch (self.classifierType) {
            case .naive_BAYES:
                return self.naiveBayes.predict(inputVector)
        }
    }
    
    func reset() {
        self.naiveBayes.reset()
    }
    
    
}
