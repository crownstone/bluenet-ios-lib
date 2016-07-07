# Bluenet-lib-ios
### Bluenet lib for iOS

[![Carthage compatible](https:img.shields.iobadgeCarthage-compatible-4BC51D.svg?style=flat)](https:github.comCarthageCarthage)

Current implementation is in prototype stage. First actual release expected in July.

# Getting started

The Bluenet ios lib uses Carthage to handle it's dependencies. It's also the way you install Bluenet ios in other projects.
If you're unfamiliar with Carthage, take a look at the project here: https://github.com/Carthage/Carthage

To get the Bluenet ios lib up and running, first you need to have Carthage installed. Then navigate to the project dir in which you want to include Bluenet ios and create a cartfile if one did not exist yet.
(a cartfile is just a file, called "Cartfile" without extensions. Edit it in a text editor or XCode).

To add the dependency to the Cartfile, copy paste the lines below into it, save it and close it:

```
# BluenetLibIOS
github "crownstone/bluenet-lib-ios"
```

Once this is finished, run the following command in your terminal (in the same folder as the Cartfile)

```
carthage update --platform ios
```

All dependencies will then be downloaded, built and placed in a Carthage/Build folder. You then drag the frameworks into your XCode project and you're good to go!



# API

This lib has two parts, the BLE one called Bluenet and the location one called BluenetLocalization.
We use PromiseKit to handle all async events. If you see the return type is Promise<DataType> that
means this method is asynchronous and you'll have to use promises.

# Bluenet (BLE)

This lib is used to interact with the Crownstone family of devices. There are convenience methods that wrap the corebluetooth backend as well as methods that simplify the services and characteristics.

With this lib you can setup, pair, configure and control the Crownstone family of products. The lib uses an pubsub event system instead of
callbacks to relay its information to a user.



## Events
This lib broadcasts the following data:

| topic                    | dataType       | when  |
| :-------------           |:-------------  | :-----|
| "advertisementData"      | Advertisement  | When an advertisement packet is received |


## Methods

##### ```startScanning()```
Start actively scanning for BLE devices.
Scan results will be broadcasted on the "advertisementData" topic.


##### ```startScanningForCrownstones()```
Start actively scanning for Crownstones based on the scan response service uuid.
Scan results will be broadcasted on the "advertisementData" topic.

##### ```startScanningForService(serviceUUID: String)```
Start actively scanning for BLE devices containing a specific serviceUUID.
Scan results will be broadcasted on the "advertisementData" topic.
 
##### ```stopScanning()```
Stop actively scanning for BLE devices.

##### ```isReady() -> Promise<Void>```
Fulfills if the BLE manager is initialized.
Should be used to make sure commands are not send before it's finished and get stuck.

##### ```connect(uuid: String) -> Promise<Void>```
Connect to a BLE device with the provided UUID.
 This UUID is unique per BLE device per iOS device and is NOT the MAC address.
 Timeout is set to 3 seconds starting from the actual start of the connection.
   - It will abort other pending connection requests
   - It will disconnect from a connected device if that is the case


##### ```disconnect() -> Promise<Void>```
Disconnect from the connected device. Will also fulfil if there is nothing connected.
Timeout is set to 2 seconds.

##### ```setSwitchState(state: NSNumber) -> Promise<Void>```
Set the switch state. If 0 or 1, switch on or off. If 0 < x < 1 then dim.
In current implementation, only 0 or 1 are supported. Dimming will be added in the future.

### Event Methods:

##### ```on(topic: String, _ callback: (AnyObject) -> Void) -> Int```
Subscribe to a topic with a callback. This method returns an Int which is used as identifier of the subscription.
This identifier is supplied to the off method to unsubscribe.

##### ```off(id: Int)```
Unsubscribe from a subscription.
 This identifier is obtained as a return of the on() method.


# Bluenet Localization
This lib is used to interact with the indoor localization algorithms of the Crownstone.


With this lib you train fingerprints, get and load them and determine in which location you are.
It wraps around the CoreLocation services to handle all iBeacon logic.
As long as you can ensure that each beacon's UUID+major+minor combination is unique, you can use this
localization lib.

You input groups by adding their tracking UUIDS
You input locations by providing their fingerprints or training them.

## Events
This lib broadcasts the following data:

| topic                    | dataType       | when  |
| :-------------           |:-------------  | :-----|
| "iBeaconAdvertisement"      | [iBeaconPacket]  | Once a second when the iBeacon's are ranged   (array of iBeaconPacket objects) |
| "enterRegion"     | String  | When a region (denoted by groupId) is entered (data is the groupId as String) |
| "exitRegion"      | String  | When a region (denoted by groupId) is no longer detected (data is the groupId as String) |
| "enterLocation"   | String  | When the classifier determines the user has entered a new location (data is the locationId as String) |
| "exitLocation"    | String  | When the classifier determines the user has left his location in favor of a new one. Not triggered when region is left (data is the locationId as String) |
| "currentLocation" | String  | Once a second when the iBeacon's are ranged and the classifier makes a prediction (data is the locationId as String) |


## Methods

##### ```trackUUID(uuid: String, groupId: String)```
This method configures an ibeacon with the ibeaconUUID you provide. The groupId is used to notify
you when this region is entered as well as to keep track of which classifiers belong to which group.

##### ```loadFingerprint(groupId: String, locationId: String, fingerprint: Fingerprint)```
Load a fingerprint into the classifier(s) for the specified groupId and locationId.
The fingerprint can be constructed from a string by using the initializer when creating the Fingerprint object

##### ```getFingerprint(groupId: String, locationId: String) -> Fingerprint?```
Obtain the fingerprint for this groupId and locationId. usually done after collecting it.
The user is responsible for persistently storing and loading the fingerprints.

##### ```startCollectingFingerprint()```
Start collecting a fingerprint.

##### ```pauseCollectingFingerprint()```
Pause collecting a fingerprint. Usually when something in the app would interrupt the user. Can be resumed later.

##### ```resumeCollectingFingerprint()```
Resume collecting the fingerprint that was put on pause before.

##### ```abortCollectingFingerprint()```
Stop collecting a fingerprint without loading it into the classifier.
```getFingerprint(...)``` will not obtain this fingerprint as the results will be lost on abort.


##### ```finalizeFingerprint(groupId: String, locationId: String)```
Finalize collecting a fingerprint and store it in the appropriate classifier based on the groupId and the locationId.


### Event Methods:

##### ```on(topic: String, _ callback: (AnyObject) -> Void) -> Int```
Subscribe to a topic with a callback. This method returns an Int which is used as identifier of the subscription.
This identifier is supplied to the off method to unsubscribe.

##### ```off(id: Int)```
Unsubscribe from a subscription.
 This identifier is obtained as a return of the on() method.

# Data Objects

The data objects are classes containing data and providing convenience methods. All of them contain the following:

##### ```getJSON() -> JSON```
Returns a JSON representation of the data in this object

##### ```stringify() -> String```
Returns a stringified JSON representation of the data in this object


## Advertisement
Data in the JSON if it is a Crownstone:
```js
{
  uuid: String,
  name: String,
  rssi: NSNumber,
  serviceData: {
    scanResponseServiceUUID: {
      crownstoneId: String
      crownstoneStateId: String
      switchState: NSNumber
      eventBitmask: NSNumber
      reserved: NSNumber
      powerUsage: NSNumber
      accumulatedEnergy: NSNumber
    }
  }
```

If the device is not a Crownstone, the serviceData (if it exists) will be an array of byteValues (0-255).

## iBeaconPacket
Data in the JSON of the iBeaconPacket
```js
{
  uuid: String,
  major: NSNumber,
  minor: NSNumber,
  rssi: NSNumber,
  idString: String // uuid + ".Maj:" + String(major) + ".Min:" + String(minor)
}
```

## Fingerprint
Data in the JSON of the Fingerprint. You can init the Fingerprint with the stringified version of this data.
```js
{
  idStringOfCrownstoneA: [array of NSNumbers (rssi values)],
  idStringOfCrownstoneB: [array of NSNumbers (rssi values)],
  ...
}
```

