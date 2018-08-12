//
//  ddcctl.m
//  query and control monitors through their on-wire data channels and OSD microcontrollers
//  http://en.wikipedia.org/wiki/Display_Data_Channel#DDC.2FCI
//  http://en.wikipedia.org/wiki/Monitor_Control_Command_Set
//
//  Copyright Joey Korkames 2016 http://github.com/kfix
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt

//  Now using argv[] instead of user-defaults to handle commandline arguments.
//  Added optional use of an external app 'OSDisplay' to have a BezelUI like OSD.
//  Have fun! Marc (Saman-VDR) 2016

#import "ddcctl.h"
#import "DDC.h"

#define MyLog NSLog

NSString *EDIDString(char *string)
{
	NSString *temp = [[NSString alloc] initWithBytes:string length:13 encoding:NSASCIIStringEncoding];
	return ([temp rangeOfString:@"\n"].location != NSNotFound) ? [[temp componentsSeparatedByString:@"\n"] objectAtIndex:0] : temp;
}

/* Get current value for control from display */
uint getControl(CGDirectDisplayID cdisplay, uint control_id)
{
	struct DDCReadCommand command;
	command.control_id = control_id;
	command.max_value = 0;
	command.current_value = 0;
	MyLog(@"D: querying VCP control: #%u =?", command.control_id);
	
	if (!DDCRead(cdisplay, &command)) {
		MyLog(@"E: DDC send command failed!");
		MyLog(@"E: VCP control #%u (0x%02hhx) = current: %u, max: %u", command.control_id, command.control_id, command.current_value, command.max_value);
	} else {
		MyLog(@"I: VCP control #%u (0x%02hhx) = current: %u, max: %u", command.control_id, command.control_id, command.current_value, command.max_value);
	}
	return command.current_value;
}

/* Set new value for control from display */
void setControl(CGDirectDisplayID cdisplay, uint control_id, uint new_value)
{
	struct DDCWriteCommand command;
	command.control_id = control_id;
	command.new_value = new_value;
	
	MyLog(@"D: setting VCP control #%u => %u", command.control_id, command.new_value);
	if (!DDCWrite(cdisplay, &command)){
		MyLog(@"E: Failed to send DDC command!");
	}
#ifdef OSD
	if (useOsd) {
		NSString *OSDisplay = @"/Applications/OSDisplay.app/Contents/MacOS/OSDisplay";
		switch (control_id) {
			case 16:
				[NSTask launchedTaskWithLaunchPath:OSDisplay
										 arguments:[NSArray arrayWithObjects:
													@"-l", [NSString stringWithFormat:@"%u", new_value],
													@"-i", @"brightness", nil]];
				break;
				
			case 18:
				[NSTask launchedTaskWithLaunchPath:OSDisplay
										 arguments:[NSArray arrayWithObjects:
													@"-l", [NSString stringWithFormat:@"%u", new_value],
													@"-i", @"contrast", nil]];
				break;
				
			default:
				break;
		}
	}
#endif
}

/* Get current value to Set relative value for control from display */
void getSetControl(CGDirectDisplayID cdisplay, uint control_id, NSString *new_value, NSString *operator)
{
	struct DDCReadCommand command;
	command.control_id = control_id;
	command.max_value = 0;
	command.current_value = 0;
	
	// read
	MyLog(@"D: querying VCP control: #%u =?", command.control_id);
	
	if (!DDCRead(cdisplay, &command)) {
		MyLog(@"E: DDC send command failed!");
		MyLog(@"E: VCP control #%u (0x%02hhx) = current: %u, max: %u", command.control_id, command.control_id, command.current_value, command.max_value);
	} else {
		MyLog(@"I: VCP control #%u (0x%02hhx) = current: %u, max: %u", command.control_id, command.control_id, command.current_value, command.max_value);
	}
	
	// calculate
	NSString *formula = [NSString stringWithFormat:@"%u %@ %@", command.current_value, operator, new_value];
	NSExpression *exp = [NSExpression expressionWithFormat:formula];
	NSNumber *set_value = [exp expressionValueWithObject:nil context:nil];
	
	// validate and write
	if (set_value.intValue >= 0 && set_value.intValue <= command.max_value) {
		MyLog(@"D: relative setting: %@ = %d", formula, set_value.intValue);
		setControl(cdisplay, control_id, set_value.unsignedIntValue);
	} else {
		MyLog(@"D: relative setting: %@ = %d is out of range!", formula, set_value.intValue);
	}
}
