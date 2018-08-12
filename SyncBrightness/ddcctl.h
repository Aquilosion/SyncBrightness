//
//  ddcctl.h
//  SyncBrightness
//
//  Created by Robert Pugh on 2018-08-11.
//  Copyright © 2018 Robert Pugh. All rights reserved.
//

#import <Foundation/Foundation.h>

NSString *EDIDString(char *string);
uint getControl(CGDirectDisplayID cdisplay, uint control_id);
void setControl(CGDirectDisplayID cdisplay, uint control_id, uint new_value);

