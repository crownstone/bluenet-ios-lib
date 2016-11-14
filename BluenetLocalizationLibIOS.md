# Bluenet Localization

This lib is used to interact with the indoor localization algorithms of the Crownstone.
With this lib you train fingerprints, get and load them and determine in which location you are.
It wraps around the CoreLocation services to handle all iBeacon logic.
As long as you can ensure that each beacon's UUID+major+minor combination is unique, you can use this
localization lib.

You input groups by adding their tracking UUIDs
You input locations by providing their fingerprints or training them.

This lib broadcasts the following data:


|  topic:                  |    dataType:          |    when:
| :---------- | ---------- | :---------- |
|  "iBeaconAdvertisement"  |    [iBeaconPacket]    |    Once a second when the iBeacon's are ranged   (array of iBeaconPacket objects)
|  "enterRegion"           |    String             |    When a region (denoted by referenceId) is entered (data is the referenceId as String)
|  "exitRegion"            |    String             |    When a region (denoted by referenceId) is no longer detected (data is the referenceId as String)
|  "enterLocation"         |    String             |    When the classifier determines the user has entered a new location (data is the locationId as String)
|  "exitLocation"          |    String             |    When the classifier determines the user has left his location in favor of a new one. Not triggered when region is left (data is the locationId as String)
|  "currentLocation"       |    String             |    Once a second when the iBeacon's are ranged and the classifier makes a prediction (data is the locationId as String)
 

## Getting Started

### BluenetLocalization is initialized without arguments.
```
// this passes a view controller and app name to the lib.
// This is used for the pop ups for location usage and bluetooth warnings.
// Remember to add the capability and to add the description in your info.plist.
BluenetLibIOS.setBluenetGlobals(viewController: self, appName: "Crownstone")

// start the Bluenet Localization lib.
let bluenetLocalization = BluenetLocalization()
```


## Using the events

You subscribe to the events using this method:

#### on(_ topic: String, _ callback: @escaping eventCallback) -> voidCallback
> Subscribe to a topic with a callback. This method returns an Int which is used as identifier of the subscription.
> This identifier is supplied to the off method to unsubscribe.

A voidCallback is defined as:

```
public typealias voidCallback = () -> Void
```

This callback can be invoked to unsubscribe from the event.

Example:
```
let unsubscribe = BluenetLocalization.on("enterRegion", {data -> Void in
    if let castData = data as? String {
        // Do something with the region
    }
})

// a while later

unsubscribe() // now you are unsubscribed and the callback will not be invoked again!
```




### Tracking iBeacons

#### trackIBeacon(uuid: String, referenceId: String)
> This method configures starts tracking the iBeaconUUID you provide. The dataId is used to notify
> you when this region is entered as well as to keep track of which classifiers belong to which data point in your reference.
> When this method has been used, the iBeaconAdvertisement event will update you when new data comes in.


#### clearTrackedBeacons()
> This will stop listening to any and all updates from the iBeacon tracking. Your app may fall asleep.
> It will also remove the list of all tracked iBeacons.



#### stopTrackingIBeacon(_ uuid: String)
> This will stop listening to a single iBeacon uuid and remove it from the list. This is called when you remove the region from
> the list of stuff you want to listen to. It will not be resumed by resumeTracking.



#### pauseTracking()
> This will pause listening to any and all updates from the iBeacon tracking. Your app may fall asleep. It can be resumed by
> the resumeTracking method.



#### resumeTracking()
> Continue tracking iBeacons. Will trigger enterRegion and enterLocation again.
> Can be called multiple times without duplicate events.


#### forceClearActiveRegion()
> This can be used to have another way of resetting the enter/exit events. In certain cases (ios 10) the exitRegion event might not be fired correctly.
> The app can correct for this and implement it's own exitRegion logic. By calling this method afterwards the lib will fire a new enter region event when it sees new beacons.


## Indoor localization

Starting and stopping the usasge of the classifier will also start and stop the emitting of the "enterLocation", "exitLocation"
and "currentLocation" events. If there is no fingerprint loaded, none of these events will be emitted regardless. The default state of the
indoor localization is **OFF**.

#### startIndoorLocalization()
> This will enable the classifier. It requires the fingerprints to be setup and will trigger the current/enter/exitRoom events
> This should be used if the user is sure the fingerprinting process has been finished.


#### stopIndoorLocalization()
> This will disable the classifier. The current/enter/exitRoom events will no longer be fired.


## Fingerprinting

You do not need to know the format of the fingerprint in order to use them.
You can tell the lib to start collecting a fingerprint by calling this method:

#### startCollectingFingerprint()
> Start collecting a fingerprint.

#### pauseCollectingFingerprint()
> Pause collecting a fingerprint. Usually when something in the app would interrupt the user.

#### resumeCollectingFingerprint()
> Resume collecting a fingerprint.

#### abortCollectingFingerprint()
> Stop collecting a fingerprint without loading it into the classifier.

Once your usecase has determined that the fingerprint is big enough, you call the finalize method.
This will also load and initialize the fingerprint. Only at this point do you give the fingerprint a referenceId and a locationId.
These are commonly used for region and location ids.

#### finalizeFingerprint(referenceId: String, locationId: String)
> Finalize collecting a fingerprint and store it in the appropriate classifier based on the referenceId and the locationId.

### Storage of fingerprints

The lib does not store the fingerprints. This is up to your app. You can get the fingerprint using the getFingerprint method.
You can use the Fingerprint class to stringify the data and store it as a string.

#### getFingerprint(referenceId: String, locationId: String) -> Fingerprint?
> Obtain the fingerprint for this referenceId and locationId. usually done after collecting it.
> The user is responsible for persistently storing and loading the fingerprints.

You can use the string you stored to initialize a new Fingerprint Object which you can then load back into the lib using the loadFingerprint:

#### loadFingerprint(referenceId: String, locationId: String, fingerprint: Fingerprint)
> Load a fingerprint into the classifier(s) for the specified referenceId and locationId.
> The fingerprint can be constructed from a string by using the initializer when creating the Fingerprint object
