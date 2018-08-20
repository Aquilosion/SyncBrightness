//
//  main.swift
//  SyncBrightness
//
//  Created by Robert Pugh on 2018-08-11.
//  Copyright © 2018 Robert Pugh. All rights reserved.
//

import Foundation
import Cocoa

let standardBrightnessRange: ClosedRange<Float> = 0.0 ... 1.0

let serialBrightnessAdjustment: [String:ClosedRange<Float>] = {
	let path = "~/.SyncBrightness.conf"
	let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
	
	guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
		return [:]
	}
	
	let lines = contents.components(separatedBy: "\n")
	
	return Dictionary(lines.compactMap { line in
		let components = line.components(separatedBy: " ")
		
		guard components.count >= 3 else {
			return nil
		}
		
		let serialNumber = components[0]
		
		guard let lowerBound = Float(components[1]), let upperBound = Float(components[2]), lowerBound <= upperBound else {
			return nil
		}
		
		return (serialNumber, lowerBound ... upperBound)
	}, uniquingKeysWith: { first, _ in first })
}()

var displayBrightnessAdjustment = [CGDirectDisplayID:ClosedRange<Float>]()

func brightnessRange(for display: CGDirectDisplayID) -> ClosedRange<Float> {
	if let range = displayBrightnessAdjustment[display] {
		return range
	}
	
	let chosenBrightness: ClosedRange<Float>
	
	getRange: do {
		guard let serialNumber = serialNumber(for: display) else {
			chosenBrightness = standardBrightnessRange
			break getRange
		}
		
		chosenBrightness = serialBrightnessAdjustment[serialNumber] ?? standardBrightnessRange
	}
	
	displayBrightnessAdjustment[display] = chosenBrightness
	return chosenBrightness
	
}

func serialNumber(for display: CGDirectDisplayID) -> String? {
	var edid = EDID()
	
	guard EDIDTest(display, &edid) else {
		print("Failed to poll display!")
		return nil
	}
	
	let descriptors = [
		edid.descriptors.0,
		edid.descriptors.1,
		edid.descriptors.2,
		edid.descriptors.3
	]
	
	var serialNumber: String?
	var screenName: String?
	
	for descriptor in descriptors {
		var data = [
			descriptor.text.data.0,
			descriptor.text.data.1,
			descriptor.text.data.2,
			descriptor.text.data.3,
			descriptor.text.data.4,
			descriptor.text.data.5,
			descriptor.text.data.6,
			descriptor.text.data.7,
			descriptor.text.data.8,
			descriptor.text.data.9,
			descriptor.text.data.10,
			descriptor.text.data.11,
			descriptor.text.data.12
		]
		
		switch descriptor.text.type {
		case 0xff:
			serialNumber = EDIDString(&data)
			
		case 0xfc:
			screenName = EDIDString(&data)
			
		default:
			break
			
		}
	}
	
	if let serialNumber = serialNumber {
		print("Display serial number: \(serialNumber) for \(screenName ?? "Unknown")")
	}
	
	return serialNumber
}

func externalDisplays() -> [CGDirectDisplayID] {
	return NSScreen.screens.compactMap { screen in
		let description = screen.deviceDescription
		
		guard description[.isScreen] != nil else {
			return nil
		}
		
		let displayId = description[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as! CGDirectDisplayID
		
		guard CGDisplayIsBuiltin(displayId) == 0 else {
			return nil
		}
		
		return displayId
	}
}

func setBrightness(for display: CGDirectDisplayID, value: Float) -> Bool {
	var edid = EDID()
	
	guard EDIDTest(display, &edid) else {
		print("Failed to poll display!")
		return false
	}
	
	let adjustmentRange = brightnessRange(for: display)
	
	let brightness = UInt32(max(min((value - adjustmentRange.lowerBound) / (adjustmentRange.upperBound - adjustmentRange.lowerBound), 1), 0) * 100)
	
	let controlId = UInt32(BRIGHTNESS)
	setControl(display, controlId, brightness)
	
	return true
}

/*func getBrightness(for display: CGDirectDisplayID) -> Float {
	var edid = EDID()
	
	guard EDIDTest(display, &edid) else {
		print("Failed to poll display!")
		return 0
	}
	
	let controlId = UInt32(BRIGHTNESS)
	let brightness = getControl(display, controlId)
	
	return Float(brightness) / 100
}*/

func updateBrightness() {
	print("BRIGHTNESS: \(currentBrightness)")
	
	let totalRange = getTotalRange()
	let adjustedBrightness = totalRange.lowerBound + (totalRange.upperBound - totalRange.lowerBound) * currentBrightness
	
	let displays = externalDisplays()
	
	for display in displays {
		_ = setBrightness(for: display, value: adjustedBrightness)
	}
}

func getTotalRange() -> ClosedRange<Float> {
	let brightnessRanges = externalDisplays().map(brightnessRange)
	
	guard let firstRange = brightnessRanges.first else {
		return standardBrightnessRange
	}
	
	let totalRange = brightnessRanges.dropFirst().reduce(firstRange, { min($0.lowerBound, $1.lowerBound) ... max($0.upperBound, $1.upperBound) })
	
	return totalRange
}

var currentBrightness: Float = 0.5

func acquirePrivileges() -> Bool {
	let accessEnabled = AXIsProcessTrustedWithOptions([
		kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
	] as CFDictionary)
	
	if accessEnabled != true {
		print("You need to enable the keylogger in the System Preferences")
	}
	
	return accessEnabled == true
}

class ApplicationDelegate: NSObject, NSApplicationDelegate {
	func applicationDidFinishLaunching(_ notification: Notification) {
		guard acquirePrivileges() else {
			exit(1)
		}
		
		NSEvent.addGlobalMonitorForEvents(
			matching: NSEvent.EventTypeMask.keyDown,
			handler: { event in
				let f1: UInt16 = 122
				let f2: UInt16 = 120
				
				let delta: Float = 1 / 16
				
				if event.keyCode == f1 {
					currentBrightness = max(0, currentBrightness - delta)
					updateBrightness()
				} else if event.keyCode == f2 {
					currentBrightness = min(1, currentBrightness + delta)
					updateBrightness()
				}
			}
		)
	}
}

let application = NSApplication.shared
let applicationDelegate = ApplicationDelegate()

application.delegate = applicationDelegate
application.activate(ignoringOtherApps: true)
application.run()
