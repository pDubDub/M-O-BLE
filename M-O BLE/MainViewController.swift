//
//  ViewController.swift
//  M-O BLE
//
//  Created by Patrick Wheeler on 5/19/20.
//  Copyright © 2020 Patrick Wheeler. All rights reserved.
//

import UIKit
import CoreBluetooth
import AVFoundation

class MainViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    var manager:CBCentralManager? = nil
    var mainPeripheral:CBPeripheral? = nil
    var mainCharacteristic:CBCharacteristic? = nil

    var isConnected:Bool = false
    var stringForArduino:String = ""

//    let BLEService = "DFB0"
//    let BLECharacteristic = "DFB1"

    // pw: these changed from tutorial to match the AT-09
    let BLEService = "FFE0"
    let BLECharacteristic = "FFE1"

    // outlets for accessing UI elements
    @IBOutlet weak var sleepLabel: UILabel!
    @IBOutlet weak var sleepSwitch: UISwitch!
    @IBOutlet weak var readyLabel: UILabel!

    @IBOutlet weak var helloButton: UIButton!
    @IBOutlet weak var moButton: UIButton!
    @IBOutlet weak var yipButton: UIButton!

    @IBOutlet weak var recievedMessageText: UILabel!

    var player: AVPlayer?

    override func viewDidLoad() {
        super.viewDidLoad()

        manager = CBCentralManager(delegate: self, queue: nil);

        customiseNavigationBar()

        helloButton.layer.borderWidth = 1
        helloButton.layer.cornerRadius = 10
        helloButton.layer.borderColor = UIColor.gray.cgColor

        moButton.layer.borderWidth = 1
        moButton.layer.cornerRadius = 10
        moButton.layer.borderColor = UIColor.gray.cgColor

        yipButton.layer.borderWidth = 1
        yipButton.layer.cornerRadius = 10
        yipButton.layer.borderColor = UIColor.gray.cgColor
    }

    func customiseNavigationBar () {

        self.navigationItem.rightBarButtonItem = nil

        let rightButton = UIButton()

        if (mainPeripheral == nil) {
            isConnected = false
            helloButton.isEnabled = false
            moButton.isEnabled = false
            yipButton.isEnabled = false
            rightButton.setTitle("Scan", for: [])
            rightButton.setTitleColor(UIColor.blue, for: [])
            rightButton.frame = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: 60, height: 30))
            rightButton.addTarget(self, action: #selector(self.scanButtonPressed), for: .touchUpInside)
        } else {
            // This means we're connected
            isConnected = true
            helloButton.isEnabled = true
            moButton.isEnabled = true
            yipButton.isEnabled = true
            rightButton.setTitle("Disconnect", for: [])
            rightButton.setTitleColor(UIColor.blue, for: [])
            rightButton.frame = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: 100, height: 30))
            rightButton.addTarget(self, action: #selector(self.disconnectButtonPressed), for: .touchUpInside)
        }

        let rightBarButton = UIBarButtonItem()
        rightBarButton.customView = rightButton
        self.navigationItem.rightBarButtonItem = rightBarButton

    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

        if (segue.identifier == "scan-segue") {
            let scanController : ScanTableViewController = segue.destination as! ScanTableViewController

            //set the manager's delegate to the scan view so it can call relevant connection methods
            manager?.delegate = scanController
            scanController.manager = manager
            scanController.parentView = self
        }

    }

    // MARK: UI Methods
    @objc func scanButtonPressed() {
        performSegue(withIdentifier: "scan-segue", sender: nil)
    }

    @objc func disconnectButtonPressed() {
        //this will call didDisconnectPeripheral, but if any other apps are using the device it will not immediately disconnect
        manager?.cancelPeripheralConnection(mainPeripheral!)
    }

    @IBAction func switchChanged(_ sender: UISwitch) {
//        var switchMessage = ""
        if (sleepSwitch.isOn) {
//            stringForArduino = "wake"
            sendBTLEDataMessageToArduino(message: "wake")
        } else {
//            stringForArduino = "sleep"
            sendBTLEDataMessageToArduino(message: "sleep")
        }
//        sendBTLEDataMessageToArduino()
    }
    
    // action when button1 is pressed
    @IBAction func helloButtonPressed(_ sender: Any) {


        // button used to assign variables, convert string to data, and then pass data to send func.
        // now they just send a literal string, and send() func does the conversion to data itself (once, less code)
        //        stringForArduino = "Hello World!"
        //        let dataToSend = stringForArduino.data(using: String.Encoding.utf8)
        //        sendBTLEDataMessageToArduino(dataMessage: dataToSend!)
        sendBTLEDataMessageToArduino(message: "Hello World!")
    }

    @IBAction func nameButtonPressed(_ sender: Any) {
//        stringForArduino = "M-O"
        sendBTLEDataMessageToArduino(message: "M-O")
    }

    @IBAction func yipButtonPressed(_ sender: Any) {
//        stringForArduino = "Yip"
        sendBTLEDataMessageToArduino(message: "Yip")
    }

    // these commands used to live in original helloButtonPressed() IB Action.
    // moved out so future buttons could all call the same 'send' function
    func sendBTLEDataMessageToArduino() {
        let dataMessage = stringForArduino.data(using: String.Encoding.utf8)!
        if (mainPeripheral != nil) {
            mainPeripheral?.writeValue(dataMessage, for: mainCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
            playInAppSound(number: 1)
        } else {
            print("haven't discovered device yet")
        }
    }

    func sendBTLEDataMessageToArduino(message: String) {
        let dataMessage = message.data(using: String.Encoding.utf8)!
        if (mainPeripheral != nil) {
            mainPeripheral?.writeValue(dataMessage, for: mainCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
            playInAppSound(number: 1)
            print("Sending \"\(message)\" to Arduino")
        } else {
            print("haven't discovered device yet")
        }
    }

    // MARK: - CBCentralManagerDelegate Methods

    // called when peripheral is requested to be disconnected
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        mainPeripheral = nil
        customiseNavigationBar()
        print("Disconnected from " + peripheral.name!)
        recievedMessageText.text = "*not connected*"
    }

    // not using here, but required
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print(central.state)
    }

    // MARK: CBPeripheralDelegate Methods
    // looping through peripheral services array
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {

        for service in peripheral.services! {

            print("Service found with UUID: " + service.uuid.uuidString)

            //device information service
            if (service.uuid.uuidString == "180A") {
                peripheral.discoverCharacteristics(nil, for: service)
            }

            //GAP (Generic Access Profile) for Device Name
            // This replaces the deprecated CBUUIDGenericAccessProfileString
            if (service.uuid.uuidString == "1800") {
                peripheral.discoverCharacteristics(nil, for: service)
            }

            //Bluno Service
            if (service.uuid.uuidString == BLEService) {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }


    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {

        //get device name
        if (service.uuid.uuidString == "1800") {
            for characteristic in service.characteristics! {
                if (characteristic.uuid.uuidString == "2A00") {
                    peripheral.readValue(for: characteristic)
                    print("Found Device Name Characteristic")
                }
            }
        }

        if (service.uuid.uuidString == "180A") {
            for characteristic in service.characteristics! {
                if (characteristic.uuid.uuidString == "2A29") {
                    peripheral.readValue(for: characteristic)
                    print("Found a Device Manufacturer Name Characteristic")
                } else if (characteristic.uuid.uuidString == "2A23") {
                    peripheral.readValue(for: characteristic)
                    print("Found System ID")
                }
            }
        }

        if (service.uuid.uuidString == BLEService) {
            for characteristic in service.characteristics! {
                if (characteristic.uuid.uuidString == BLECharacteristic) {
                    //we'll save the reference, we need it to write data
                    mainCharacteristic = characteristic

                    //Set Notify is useful to read incoming data async
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("Found AT-09 Data Characteristic")

                    sendBTLEDataMessageToArduino(message: "iOSOK")
                    print("Send \"iosOK\" to Arduino")
                    // let's send a 'connected' message to Arduino, and have Arduino send a 'connection aknowledged' message back to screen
                    // Previously had this in the Else statement in the customiseNavigationBar() func above, but it crashed the app when there.
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        if (characteristic.uuid.uuidString == "2A00") {
            //value for device name recieved
            let deviceName = characteristic.value
            print(deviceName ?? "No Device Name")
        } else if (characteristic.uuid.uuidString == "2A29") {
            //value for manufacturer name recieved
            let manufacturerName = characteristic.value
            print(manufacturerName ?? "No Manufacturer Name")
        } else if (characteristic.uuid.uuidString == "2A23") {
            //value for system ID recieved
            let systemID = characteristic.value
            print(systemID ?? "No System ID")
        } else if (characteristic.uuid.uuidString == BLECharacteristic) {
            //data recieved
            if(characteristic.value != nil) {
                let stringValue = String(data: characteristic.value!, encoding: String.Encoding.utf8)!

                recievedMessageText.text = stringValue
                playInAppSound(number: 2)
//                print("received BT message: \(stringValue)")

                reactToBTMessage(message: stringValue)
            }
        }
    }

    func reactToBTMessage(message: String) {
        if (message.starts(with: "isAsleep")) {
            print("MO says \"isAsleep\"")
            recievedMessageText.text = "MO says he's sleeping"
            sleepSwitch.isOn = false
        } else if (message.starts(with: "isAwake")) {
            print("MO says \"isAwake\"")
            recievedMessageText.text = "MO says he's awake"
            sleepSwitch.isOn = true
        } else if (message.starts(with: "isReady")) {                   // this is my model for new message format
            if (message.hasSuffix("0")) {
                // react to !isReady
            } else {
                // react to isReady
                print("MO says \"isReady\"")
                recievedMessageText.text = "Microbe Obliterator Ready"
            }
        }

        else {
            print("Bluetooth connections message: \(message)")
        }
    }

    // TODO - would be nice if the recievedMessageText cleared after a couple of seconds.

    func playInAppSound(number: Int) {

        // TODO - would be good to add a simple error sound to go with 'haven't discovered device yet' putton push

        // or perhaps better, disable the send button if 'haven't discovered device yet'

        if(number == 1) {
            guard let url = Bundle.main.url(forResource: "simpleBeep", withExtension: "wav") else {
                 print("error to get the audio file")
                 return
            }
            player = AVPlayer(url: url)
        } else if (number == 2) {
            guard let url = Bundle.main.url(forResource: "simpleBeep2", withExtension: "wav") else {
                print("error to get the audio file")
                return
            }
            player = AVPlayer(url: url)
        }

        //player = AVPlayer(url: url)

        player?.play()
    }
}

