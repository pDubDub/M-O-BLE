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

    let buttonBlue = UIColor(red: 0.215, green: 0.388, blue: 0.866, alpha: 1)

    var manager:CBCentralManager? = nil                     // core bluetooth
    var mainPeripheral:CBPeripheral? = nil
    var mainCharacteristic:CBCharacteristic? = nil

    var stringForArduino:String = ""

    var botIsConnected:Bool = false                            // my state variable
    var botIsReady: Bool = false
    var botIsAwake: Bool = false

    var timerIsDone:Bool = true                             // might not be used anymore
    var timerIsRunning:Bool = false
    var previousSliderOneSent:Int = 0

//    let BLEService = "DFB0"
//    let BLECharacteristic = "DFB1"

    // pw: these changed from tutorial to match the AT-09
    let BLEService = "FFE0"
    let BLECharacteristic = "FFE1"

    // outlets for accessing UI elements
    @IBOutlet weak var moIcon: UIImageView!
    @IBOutlet weak var arrowIcon: UILabel!
    @IBOutlet weak var testButton: UIButton!
    @IBOutlet weak var sleepLabel: UILabel!
    @IBOutlet weak var sleepSwitch: UISwitch!
    @IBOutlet weak var readyLabel: UILabel!

    @IBOutlet weak var moButton: UIButton!
    @IBOutlet weak var yipButton: UIButton!
    @IBOutlet weak var huhButton: UIButton!
    @IBOutlet weak var speakButton: UIButton!

    @IBOutlet weak var dirtScanButton: UIButton!
    @IBOutlet weak var contaminantButton: UIButton!
    @IBOutlet weak var reallyDirtyButton: UIButton!

    @IBOutlet weak var sirenLabel: UILabel!
    @IBOutlet weak var sirenSwitch: UISwitch!
    @IBOutlet weak var allCleanButton: UIButton!

    @IBOutlet weak var sliderOne: UISlider!
    @IBOutlet weak var sliderTwo: UISlider!

    @IBOutlet weak var oneSegmentedControl: UISegmentedControl!
    @IBOutlet weak var messageHeadingLabel: UILabel!
    @IBOutlet weak var recievedMessageText: UILabel!

    var player: AVPlayer?                                   // for playing interface sounds (beeps)

    override func viewDidLoad() {
        super.viewDidLoad()

        manager = CBCentralManager(delegate: self, queue: nil);

        // from tutorial. controls scan/disconnect menu buttons
        customiseNavigationBar()

        // removes the navigation bar background
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)

//        customiseLookOf(helloButton)          // setting my custom button style
//        customiseLookOf(moButton)
//        customiseLookOf(yipButton)
//        customiseLookOf(huhButton)
//        customiseLookOf(speakButton)
        customiseLookOf(dirtScanButton)
        customiseLookOf(contaminantButton)
        customiseLookOf(reallyDirtyButton)
        customiseLookOf(allCleanButton)
        // I think there may be an even easier way to do this, like looping through all subviews of type UIButton.

//        for family in UIFont.familyNames.sorted() {                       // this code was used to find actual font name below
//            let names = UIFont.fontNames(forFamilyName: family)
//            print("Family: \(family) Font names: \(names)")
//        }

        // changing font style of segmented control
        let font = UIFont.init(name: "HandelGothic", size: 14)
        oneSegmentedControl.setTitleTextAttributes([NSAttributedString.Key.font: font!], for: .normal)
        // changing text color of selected segmented control segment
        oneSegmentedControl.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.white], for: UIControl.State.selected)

        // attempting to set nav bar color (eventually to black) - none work
        // UINavigationBar.appearance().backgroundColor = UIColor.green
//        UINavigationBar.appearance().barTintColor = .black
//        UINavigationBar.appearance().isTranslucent = true
        self.navigationController?.navigationBar.barTintColor = .black      // this works! Found it myself throught documentation too!

        // TODO - bar is still slightly visible. Might be the translucent property
        // - maybe there is a background tint = none option.

        // setting the UI to startup conditions
        updateUIOnConnection(to: false)

        readyLabel.textColor = UIColor.red
        readyLabel.text = "NOT READY"

        updateUIOnSleep(to: true)
    }

    func customiseNavigationBar () {
        // tutorial method for scan/disconnect menu bar button
        // I'm also using this to trigger UI changes on Connect/Disconnect

        self.navigationItem.rightBarButtonItem = nil

        let rightButton = UIButton()

        if (mainPeripheral == nil) {
            // This means we have disconnected

            arrowIcon.isHidden = false
            messageHeadingLabel.text = "* Not Connected *"
            recievedMessageText.text = "--"

            rightButton.setTitle("Scan", for: [])
            rightButton.setTitleColor(UIColor.yellow, for: [])
            rightButton.frame = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: 60, height: 30))
            rightButton.addTarget(self, action: #selector(self.scanButtonPressed), for: .touchUpInside)
        } else {
            // This means we have attempted to connect

            arrowIcon.isHidden = true
            messageHeadingLabel.text = "Incoming Messsge:"
            recievedMessageText.text = "  "

            rightButton.setTitle("Disconnect", for: [])
            rightButton.setTitleColor(UIColor.red, for: [])
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

    @IBAction func stateSegmentControlChanged(_ sender: Any) {
        // Arduino wants to hear "goSleep", "goIdle" or "goActiv"

        switch oneSegmentedControl.selectedSegmentIndex {
            case 0:
                print("Sleep mode selected")
                sendBTLEDataMessageToArduino(message: "goSleep")        // was ready:1
            case 1:
                print("Ready mode selected")
                sendBTLEDataMessageToArduino(message: "goIdle")       // ready:2
            case 2:
                print("Active state selected")
                sendBTLEDataMessageToArduino(message: "goActiv")        // ready:3
            default:
                break
        }
    }


    @objc func scanButtonPressed() {
        performSegue(withIdentifier: "scan-segue", sender: nil)
    }

    @objc func disconnectButtonPressed() {
        //this will call didDisconnectPeripheral, but if any other apps are using the device it will not immediately disconnect
        manager?.cancelPeripheralConnection(mainPeripheral!)
    }

    // TODO - delete this switch, its references and its method
//    @IBAction func switchChanged(_ sender: UISwitch) {
//        // this is the old switch, which I'm replacing with the segmented control
//
//        // note, I don't think it's correct that I've been enabling the UI here. Instead, it should just send the message, and the response from MO-Arduino should be the thing that activated the UI
//
////        var switchMessage = ""
//        if (sleepSwitch.isOn) {
////            stringForArduino = "wake"
//            sendBTLEDataMessageToArduino(message: "wake")
////            moIcon.image = UIImage(named: "MO_onscreen_ON")
////            sleepLabel.textColor = UIColor.lightGray
////            readyLabel.textColor = UIColor.black
//            wakeTheUI()
//        } else {
////            stringForArduino = "sleep"
//            sendBTLEDataMessageToArduino(message: "sleep")
////            moIcon.image = UIImage(named: "MO_onscreen_OFF")
////            sleepLabel.textColor = UIColor.black
////            readyLabel.textColor = UIColor.lightGray
//            sleepTheUI()
//        }
////        sendBTLEDataMessageToArduino()
//    }


    // action when button1 is pressed
    @IBAction func testButtonPressed(_ sender: Any) {
        // button used to assign variables, convert string to data, and then pass data to send func.
        // now they just send a literal string, and send() func does the conversion to data itself (once, less code)
        //        stringForArduino = "Hello World!"
        //        let dataToSend = stringForArduino.data(using: String.Encoding.utf8)
        //        sendBTLEDataMessageToArduino(dataMessage: dataToSend!)
        sendBTLEDataMessageToArduino(message: "Hello World!")
    }

    @IBAction func nameButtonPressed(_ sender: Any) {
        sendBTLEDataMessageToArduino(message: "M-O")
    }

    @IBAction func yipButtonPressed(_ sender: Any) {
        sendBTLEDataMessageToArduino(message: "Yip")
    }

    @IBAction func huhButtonPressed(_ sender: Any) {
        sendBTLEDataMessageToArduino(message: "Huh")
    }

    @IBAction func speakButtonPressed(_ sender: Any) {
        sendBTLEDataMessageToArduino(message: "speak")
    }

    @IBAction func dirtScanButtonPressed(_ sender: Any) {               // note: can't use "scanButtonPressed" as that is already used for BTLE scan
        sendBTLEDataMessageToArduino(message: "scan")
    }

    @IBAction func dirtyButtonPressed(_ sender: Any) {
        sendBTLEDataMessageToArduino(message: "dirty")
    }

    @IBAction func reallyDirtyButtonPressed(_ sender: Any) {
        sendBTLEDataMessageToArduino(message: "whoa")
    }

    @IBAction func sirenSwitchChanged(_ sender: Any) {
        if (sirenSwitch.isOn) {
            sendBTLEDataMessageToArduino(message: "siren:1")
            toggleUIEnabled(to: true)                          // temp for testing UI
        } else {
            sendBTLEDataMessageToArduino(message: "siren:0")
            toggleUIEnabled(to: false)                          // temp for testing UI
        }
    }


    @IBAction func allCleanButtonPressed(_ sender: Any) {
        sendBTLEDataMessageToArduino(message: "clean")
    }


    // pw: Here I implement a timer dalay system, so bluetooth commands are separated by 0.5 seconds. Sending messages than that were found to confuse or even crash the Arduino.
    @IBAction func sliderOneChanged(_ sender: Any) {
        if timerIsRunning {
            print("change dumped 'cause a timer is running")
        } else {
            print("\n starting timer")
            timerIsRunning = true
            _ = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: {_ in self.endChangeTimer()})
        }
    }

    @objc func endChangeTimer() {
        // this is the endTimer() called above
        timerIsRunning = false
        print("          ** timer done! **")
        sendSlider()
   }

    @objc func sendSlider() {
        let sliderInt:Int = Int(sliderOne.value)
    //        if sliderInt < 0 {
    //            sliderInt = 0
    //        } else if sliderInt > 180 {
    //            sliderInt = 180
    //        }
        print("  delayed final slider value is \(sliderInt)")
        let stringForAruino = "A1:\(sliderInt) "            // temp set to F1: to spot
        sendBTLEDataMessageToArduino(message: stringForAruino)
        previousSliderOneSent = sliderInt
    }

    @IBAction func sliderReleasedInside(_ sender: Any) {
        print("touch up inside")
        if timerIsRunning {
            print("release inside is waiting 1.0")
            _ = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: {_ in self.sendSlider()})
        } else {
            print("release inside is waiting 0.5")
            _ = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: {_ in self.sendSlider()})
        }
    }

    @IBAction func sliderRealeased(_ sender: Any) {
        print("touch up outside")
        if timerIsRunning {
            print("release outside is waiting 1.0")
            _ = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: {_ in self.sendSlider()})
        } else {
            print("release outside is waiting 0.5")
            _ = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: {_ in self.sendSlider()})
        }
    }
    // 10 june 2020 - not convinced that I need the touch up actions anymore, since adding delay to all commands.
    // slider over bluetooth may not provide ability to make small, back and forth movements (head wiggle) but we will see.

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

        // HERE IS BEHAVIOR UPON DISCONNECTING *************************
        botIsConnected = false
        updateUIOnConnection(to: botIsConnected)
        updateUIOnSleep(to: false)              // by default, we sleep all controls on disconnection
//        recievedMessageText.text = r"--"
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
        print("Message from M-O says \"\(message)\"")
        if (message.starts(with: "M-O Connected")) {
            print("M-O confirms BT connection!")

            // HERE IS RESPONSE TO CONFIRMED CONNECTION *************************
            botIsConnected = true
//            updateUIOnConnection(to: botIsConnected)
                // this is incorrect. I don't want the segmentedControl enabled if notReady.
            testButton.isEnabled = true
            testButton.alpha = 1.0
                // this has desired behavior, but might not be the cleanest code

            /*
                    By default, we won't be able to connect if notReady, however, it's possible due to a failure of some kind, to go back to notReady.
             */

            // other controls should wake or sleep based on ready/awake response to follow {

        } else if (message.starts(with: "ready")) {                   // this is my model for new message format
            if (message.contains("0")) {
                // TODO - react to not-isReady
                /*
                        change local bools
                        sleep the UI
                        disable the segmentedControl
                        change readyLabel color to red and text to NOT READY
                 */
            } else if (message.contains("1")) || (message.contains("2"))  || (message.contains("3")){
                // react to isReady

                // On BT connection, iOS sends "iosOK" to which Arduino should respond "M-O Connected" then "ready:x" (and for now still, "awake:x")

                updateUIOnConnection(to: true)
                readyLabel.textColor = buttonBlue
                readyLabel.text = "READY"
                // TODO - should set the segmented control based on ready:1, vs ready:2 or ready:3
                // should also updateUIOnSleep(on)

                recievedMessageText.text = "Microbe Obliterator Ready"
            }
        } else if (message.starts(with: "awake")) {
            if (message.contains("0")) {
                // react to !isAwake
                print("MO says \"not isAwake\"")
                recievedMessageText.text = "MO says he's sleeping"
                // these image and such commands seem to duplicate above
//                moIcon.image = UIImage(named: "MO_onscreen_OFF")
//                sleepSwitch.isOn = false
                oneSegmentedControl.selectedSegmentIndex = 0
//                sleepLabel.textColor = UIColor.black
//                readyLabel.textColor = UIColor.lightGray
                sleepTheUI()
                updateUIOnSleep(to: true)
            } else {
                // react to isAwake:1
                print("MO says \"isAwake\"")
                recievedMessageText.text = "MO says he's awake"
//                moIcon.image = UIImage(named: "MO_onscreen_ON")
//                sleepSwitch.isOn = true
                oneSegmentedControl.selectedSegmentIndex = 1            // eventually, need to set this to either 1 or 2
//                sleepLabel.textColor = UIColor.lightGray
//                readyLabel.textColor = UIColor.black
                wakeTheUI()
                updateUIOnSleep(to: false)
            }
        } else {
            print("Bluetooth message received: \(message)")
        }
    }

    // TODO - would be nice if the recievedMessageText cleared after a couple of seconds.

    func playInAppSound(number: Int) {

        if(number == 1) {       // this condition is temporarily disabled.
//            guard let url = Bundle.main.url(forResource: "simpleBeep", withExtension: "wav") else {
//                 print("error to get the audio file")
//                 return
//            }
//            player = AVPlayer(url: url)
        } else if (number == 2) {
            guard let url = Bundle.main.url(forResource: "simpleBeep2", withExtension: "wav") else {
                print("error to get the audio file")
                return
            }
            player = AVPlayer(url: url)
        }

        player?.play()
    }

    // MARK: - UI Methods

    /* TODO - there should be four stages here:
            1st - navigation bar changes upon connect/disconnect commands
            2nd - enable/disable the test button and segmented control based on BT connection
            3rd - readyLabel changes based on isReady response from M-O
            4th - enable/disable select UI based on sleep state
     */

    func wakeTheUI() {
        moIcon.image = UIImage(named: "MO_onscreen_ON")
//        sleepLabel.textColor = UIColor.lightGray
//        readyLabel.textColor = UIColor.black
    }

    func sleepTheUI(){
        moIcon.image = UIImage(named: "MO_onscreen_OFF")
//        sleepLabel.textColor = UIColor.black
//        readyLabel.textColor = UIColor.lightGray
    }

    func updateUIOnConnection(to isConnected: Bool) {
        // toggling UI elements based on BT connection
        testButton.isEnabled = isConnected
        testButton.alpha = isConnected ? 1.0 : 0.5
//        arrowIcon.isHidden = isConnected
        oneSegmentedControl.isEnabled = isConnected
    }

    func updateUIOnSleep(to isAsleep: Bool) {
        // toggling UI elements based on sleep state or upon disconnection

        if !isAsleep {
//            testButton.alpha = 1.0
            moButton.alpha = 1.0
            yipButton.alpha = 1.0
            huhButton.alpha = 1.0
            speakButton.alpha = 1.0
        } else {
//            testButton.alpha = 0.5
            moButton.alpha = 0.5
            yipButton.alpha = 0.5
            huhButton.alpha = 0.5
            speakButton.alpha = 0.5
        }
    }

    func toggleUIEnabled(to isEnabled: Bool) {
        // this is old method, that I'm moving away from

//        arrowIcon.isHidden = isEnabled                      // I don't know if this is the correct location.
//        botIsConnected = isEnabled
//        sleepSwitch.isEnabled = isEnabled
//        oneSegmentedControl.isEnabled = isEnabled
//        testButton.isEnabled = isEnabled
        moButton.isEnabled = isEnabled
        yipButton.isEnabled = isEnabled
        huhButton.isEnabled = isEnabled
        speakButton.isEnabled = isEnabled
        dirtScanButton.isEnabled = isEnabled
        contaminantButton.isEnabled = isEnabled
        reallyDirtyButton.isEnabled = isEnabled
        allCleanButton.isEnabled = isEnabled
        sliderOne.isEnabled = isEnabled

        // this should probably be in a function that accepts a button
        if isEnabled {
//            testButton.alpha = 1.0
            moButton.alpha = 1.0
            yipButton.alpha = 1.0
            huhButton.alpha = 1.0
            speakButton.alpha = 1.0
        } else {
//            testButton.alpha = 0.5
            moButton.alpha = 0.5
            yipButton.alpha = 0.5
            huhButton.alpha = 0.5
            speakButton.alpha = 0.5
        }
    }

    func customiseLookOf(_ button: UIButton) {
//        button.layer.borderWidth = 2
//        button.layer.cornerRadius = 8
//        let axiomLightBlue: UIColor = UIColor(red: 90, green: 140, blue: 240, alpha: 0.5)
//        button.layer.borderColor = UIColor(red: 90, green: 140, blue: 240, alpha: 1).cgColor

        // maybe what I really do is make a new button class that inherits from UIButton but adds these properties?
    }
}

// I think the slider logic could be redone.
//
// In short, any time sliderValueChanged() we want to send slider.value.
//
// The exception is, if we have already sent in the last .5 seconds, we should not send.
//
// BUT we want to make sure we follow through and send slider.value again 0.5 seconds after the last send,
// whenever sliderValue stops changing.
//
// Is this correct?
