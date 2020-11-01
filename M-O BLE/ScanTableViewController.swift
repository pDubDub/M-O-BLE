//
//  ScanTableViewController.swift
//  M-O BLE
//
//  Created by Patrick Wheeler on 5/19/20.
//  Copyright © 2020 Patrick Wheeler. All rights reserved.
//

import UIKit
import CoreBluetooth

class ScanTableViewController: UITableViewController, CBCentralManagerDelegate {

    var peripherals:[CBPeripheral] = [] // array for holding scanned peripherals
    var manager:CBCentralManager? = nil // optional for manager passed from MainView
    var parentView:MainViewController? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        scanBLEDevices()
        // pw: functionality here in the tutorial moved by author to function below
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // return the number of rows equal to number of peripherals in array
        return peripherals.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "       Select MO's BTLE signal:"
    }


    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "scanTableCell", for: indexPath)
        let peripheral = peripherals[indexPath.row]
        cell.textLabel?.text = peripheral.name
        if (peripheral.name == "M-O") {
            print("Found M-O!")
            // pw: this is just me experimenting to see if I can detect M-O. I hope to one day make the app auto-connect.
            //   I'm wondering if this is the wrong place to do this. Will it print() every time it builds the table.
            //   If so, I really want to build an action that occurs only when we scan.
        }
        return cell
    }

    // upon selecting a table row, this connects to chosen peripheral
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let peripheral = peripherals[indexPath.row]

        manager?.connect(peripheral, options: nil)
    }

    // MARK: BLE Scanning
    func scanBLEDevices() {
        //manager?.scanForPeripherals(withServices: [CBUUID.init(string: parentView!.BLEService)], options: nil)

        //if you pass nil in the first parameter, then scanForPeriperals will look for any devices.
        manager?.scanForPeripherals(withServices: nil, options: nil)

        //stop scanning after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.stopScanForBLEDevices()
        }
    }

    func stopScanForBLEDevices() {
        manager?.stopScan()
    }

    // MARK: - CBCentralManagerDelegate Methods
    // 1
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if(!peripherals.contains(peripheral)) {
            peripherals.append(peripheral)
        }
        // if found, then it adds found peripherals to the array and repopulates the table
        self.tableView.reloadData()
    }

//    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : AnyObject], rssi RSSI: NSNumber) {
//
//        if(!peripherals.contains(peripheral)) {
//            peripherals.append(peripheral)
//        }
//
//        self.tableView.reloadData()
//    }

    // 2
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print(central.state)
        // not actually used, but required by interface
    }

    // 3
    // sends us back to MainViewController
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {

        //pass reference to connected peripheral to parent view
        parentView?.mainPeripheral = peripheral
        peripheral.delegate = parentView
        peripheral.discoverServices(nil)

        //set the manager's delegate view to parent so it can call relevant disconnect methods
        manager?.delegate = parentView
        parentView?.customiseNavigationBar()

        if let navController = self.navigationController {
            navController.popViewController(animated: true)
        }

        print("Connected to " +  peripheral.name!)
    }

    // 4
    // not actually used here, but required to include
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print(error!)
    }

}

