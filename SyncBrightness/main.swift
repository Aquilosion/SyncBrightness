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

func builtInDisplayBrightness() -> Float {
	let service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IODisplayConnect"))
	
	var level: Float = 0
	IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &level)
	
	IOObjectRelease(service)
	
	return level
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
	let adjusted = UInt32((min(max(adjustmentRange.lowerBound + value * (adjustmentRange.upperBound - adjustmentRange.lowerBound), 0), 1) * 100).rounded())
	
	let controlId = UInt32(BRIGHTNESS)
	setControl(display, controlId, adjusted)
	
	return true
}

func updateBrightness(_ brightness: Float) {
	let displays = externalDisplays()
	
	for display in displays {
		_ = setBrightness(for: display, value: brightness)
	}
}

var currentBrightness = builtInDisplayBrightness()
updateBrightness(currentBrightness)

repeat {
	let newBrightness = builtInDisplayBrightness()
	
	if newBrightness != currentBrightness {
		currentBrightness = newBrightness
		updateBrightness(currentBrightness)
	}
	
	sleep(1)
} while true
