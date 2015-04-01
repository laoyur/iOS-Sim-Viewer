//
//  AppDelegate.m
//  iOS-Sim-Viewer
//
//  Created by laoyur on 14-10-15.
//  Copyright (c) 2014年 laoyur. All rights reserved.
//

#import "AppDelegate.h"

#define KDevicesDirPath @"Library/Developer/CoreSimulator/Devices/"

@interface DeviceInfo : NSObject
@property NSString* UUID;
@property NSString* Name;
@property int TableViewTag; //related NSTableView tag
@end

@implementation DeviceInfo
@end

#pragma mark -

@interface AppInfo : NSObject
@property NSString* BundleUUID;
@property NSString* DataUUID;
@property NSString* BundleId;   //com.laoyur.xxx
@property NSString* AppName;    //xxx.app
@end

@implementation AppInfo
@end

#pragma mark -

@interface AppDelegate () {
    
    BOOL    mReloading;
    NSDictionary*   mDict;
    NSString*       mOsKeyString;
    
    /*
     @element: NSString*
     */
    NSMutableArray* mOsKeys;
    
    /*
     @key:  DeviceInfo.Name
     @val:  NSMutableArray<AppInfo*>*
     */
    NSMutableDictionary*    mDevicesDict;
    
    /**
     @element: DeviceInfo*
     */
    NSMutableArray*         mDevicesArray;
}
@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTabView *mTabView;
@property (weak) IBOutlet NSComboBox *mOsCombo;
- (IBAction)copyrightPressed:(id)sender;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    
    mOsKeys = [NSMutableArray new];
    //read devices info
    NSString* devicesInfoPlist = [NSHomeDirectory() stringByAppendingPathComponent:[KDevicesDirPath stringByAppendingPathComponent:@".default_created.plist"]];
    mDict = [NSDictionary dictionaryWithContentsOfFile:devicesInfoPlist];
    NSArray* keys = [mDict allKeys];
    for (NSString* key in keys) {
        NSRange rg = [key rangeOfString:@"com.apple.CoreSimulator.SimRuntime."];
        if(rg.location == 0) {
            [mOsKeys addObject:key];
            [self.mOsCombo addItemWithObjectValue:[key substringFromIndex:rg.location + rg.length]];
        }
    }
    mOsKeyString = [mOsKeys firstObject];
    [self.mOsCombo selectItemAtIndex:0];
    [self.mOsCombo setDelegate:self];
    
    [self.mTabView setDelegate:self];
    
    [self reloadAll];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}


#pragma mark -
- (void)reloadAll {
    
    //clear all
    mDevicesDict = [NSMutableDictionary new];
    mDevicesArray = [NSMutableArray new];
    NSArray* tabs = self.mTabView.tabViewItems;

    mReloading = YES;
    for (NSTabViewItem* tab in tabs) {
        [self.mTabView removeTabViewItem:tab];
    }
    mReloading = NO;

    NSDictionary* devicesDict = [mDict objectForKey:mOsKeyString];
    
    int deviceIdx = 0;
    for (NSString* key in devicesDict) {
        
        NSString* deviceName = [key substringFromIndex:[key rangeOfString:@"." options:NSBackwardsSearch].location + 1];
        NSString* deviceUUID = [devicesDict objectForKey:key];
        
        DeviceInfo* di = [DeviceInfo new];
        di.UUID = deviceUUID;
        di.Name = deviceName;
        di.TableViewTag = deviceIdx;
        
        //create tab
        NSTabViewItem* tabViewItem = [[NSTabViewItem alloc] initWithIdentifier:[NSNumber numberWithInt:deviceIdx]];
        tabViewItem.label = deviceName;
        [self.mTabView addTabViewItem:tabViewItem];
        
        [mDevicesDict setObject:di forKey:di.Name];
        [mDevicesArray addObject:di];
        
        [self reloadDevice:di];
        
        deviceIdx++;
    }
}

- (void)reloadDevice:(DeviceInfo*)device {
    
    NSMutableArray* apps = [NSMutableArray new];
    
    //enumerate app bundles
    NSFileManager* fm = [NSFileManager defaultManager];
    NSString* bundlesPath = [NSHomeDirectory() stringByAppendingPathComponent:[KDevicesDirPath stringByAppendingPathComponent:[device.UUID stringByAppendingPathComponent:@"data/Containers/Bundle/Application/"]]];
    
    NSArray* bundleUUIDs = [fm contentsOfDirectoryAtPath:bundlesPath error:nil];
    for (NSString* bdUUID in bundleUUIDs) {
        
        AppInfo* app = [AppInfo new];
        
        ////get bundle uuid
        app.BundleUUID = bdUUID;
        NSArray* appPaths = [fm contentsOfDirectoryAtPath:[bundlesPath stringByAppendingPathComponent:bdUUID] error:nil];
        
        ////get app name
        for (NSString* appPath in appPaths) {
            
            //end with .app
            if([appPath rangeOfString:@".app" options:NSCaseInsensitiveSearch | NSBackwardsSearch].location == [appPath length] - 4) {
                app.AppName = appPath;
                break;
            }
        }
        
        ////get bundleid
        NSString* metaPlistPath = [[bundlesPath stringByAppendingPathComponent:bdUUID] stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
        /*
        NSString* metaPlistBak = [metaPlistPath stringByAppendingPathComponent:@".bak"];
        [fm copyItemAtPath:metaPlistPath toPath:metaPlistBak error:nil];
        system([[@"plutil -convert xml1 " stringByAppendingString:metaPlistBak] UTF8String]);
         */
        
        NSDictionary* metaDic = [NSDictionary dictionaryWithContentsOfFile:metaPlistPath];
        app.BundleId = [metaDic objectForKey:@"MCMMetadataIdentifier"];
        
        ////get data uuid
        NSString* dataPath = [NSHomeDirectory() stringByAppendingPathComponent:[KDevicesDirPath stringByAppendingPathComponent:[device.UUID stringByAppendingPathComponent:@"data/Containers/Data/Application/"]]];
        
        NSArray* dataUUIDs = [fm contentsOfDirectoryAtPath:dataPath error:nil];
        for (NSString* dUUID in dataUUIDs) {
            
            NSString* metaPath = [dataPath stringByAppendingPathComponent:[dUUID stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"]];
            NSDictionary* metaDic = [NSDictionary dictionaryWithContentsOfFile:metaPath];
            if([(NSString*)[metaDic objectForKey:@"MCMMetadataIdentifier"] isEqualToString:app.BundleId]) {
                
                app.DataUUID = dUUID;
                break;
            }
        }
        
        [apps addObject:app];
    }
    
    [mDevicesDict setObject:apps forKey:device.Name];
    
    // create a table view and a scroll view
    NSScrollView * tableContainer = [[NSScrollView alloc] init];
    NSTableView * tableView = [[NSTableView alloc] init];
    [tableView setRowSizeStyle:NSTableViewRowSizeStyleLarge];
    tableView.tag = device.TableViewTag;
    
    // create columns for our table
    NSTableColumn * col0 = [[NSTableColumn alloc] initWithIdentifier:@"0"];
    [col0 setWidth:150];
    NSTableColumn * col1 = [[NSTableColumn alloc] initWithIdentifier:@"1"];
    [col1 setMinWidth:200];
    NSTableColumn * col2 = [[NSTableColumn alloc] initWithIdentifier:@"2"];
    [col2 setWidth:100];
    NSTableColumn * col3 = [[NSTableColumn alloc] initWithIdentifier:@"3"];
    [col3 setWidth:100];
    NSTableColumn * col4 = [[NSTableColumn alloc] initWithIdentifier:@"4"];
    [col4 setWidth:70];
    NSTableColumn * col5 = [[NSTableColumn alloc] initWithIdentifier:@"5"];
    [col5 setMaxWidth:100];
    [[col0 headerCell] setStringValue:@"App Name"];
    [[col1 headerCell] setStringValue:@"BundleId"];
    [[col2 headerCell] setStringValue:@"Bundle"];
    [[col3 headerCell] setStringValue:@"Copy Bundle Path"];
    [[col4 headerCell] setStringValue:@"Data"];
    [[col5 headerCell] setStringValue:@"Copy Data Path"];
    
    // generally you want to add at least one column to the table view.
    [tableView addTableColumn:col0];
    [tableView addTableColumn:col1];
    [tableView addTableColumn:col2];
    [tableView addTableColumn:col3];
    [tableView addTableColumn:col4];
    [tableView addTableColumn:col5];
    [tableView setDelegate:self];
    [tableView setDataSource:self];

    // embed the table view in the scroll view, and add the scroll view
    // to our window.
    [tableContainer setDocumentView:tableView];
    [tableContainer setHasVerticalScroller:YES];
    [self.mTabView.tabViewItems[device.TableViewTag] setView:tableContainer];
   
}

- (DeviceInfo*)retrieveDeviceInfoWithTableViewTag:(NSInteger)tag {

    for (DeviceInfo* dv in mDevicesDict) {
        if(dv.TableViewTag == tag) {
            return dv;
        }
    }
    
    return nil;
}

#pragma mark -
#pragma mark NSTableViewDataSource
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    
    if(mReloading)
        return 0;
    
    DeviceInfo* device = mDevicesArray[tableView.tag];
    return [((NSArray*)[mDevicesDict objectForKey:device.Name]) count];

}

- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {

    if(mReloading)
        return nil;
    
    if(tableColumn) {
        
        NSButtonCell* cell = nil;
        if(![tableColumn.identifier isEqualToString:@"0"]
           && ![tableColumn.identifier isEqualToString:@"1"]){
            
            cell = [[NSButtonCell alloc] init];
            [cell setAllowsMixedState:YES];
            [cell setButtonType:NSMomentaryLightButton];
            [cell setBezelStyle:NSRoundedBezelStyle];
            [cell setTitle:@"Go"];
            [cell setTarget:self];
            [cell setAction:@selector(buttonPressed:)];
            
        } else {
            cell = [tableColumn dataCell];
        }  

        return cell;
    } else {
        NSCell *cell = [tableColumn dataCell];
        return cell;
    }
    
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    
    if(mReloading)
        return 0;
    
    DeviceInfo* device = mDevicesArray[tableView.tag];
    AppInfo* app = (AppInfo*)((NSArray*)[mDevicesDict objectForKey:device.Name])[row];
    if([tableColumn.identifier isEqualToString:@"0"]) {
        //app name
        return app.AppName;
    } else if([tableColumn.identifier isEqualToString:@"1"]) {
        //bundleid
        return app.BundleId;
    } else {
        return nil;
    }
}

-(NSMutableString*)bundlePathForApp:(AppInfo*)app ofDevice:(DeviceInfo*)device {
    NSMutableString* bundlePath = [[NSHomeDirectory() stringByAppendingPathComponent:[KDevicesDirPath stringByAppendingPathComponent:[device.UUID stringByAppendingPathComponent:@"data/Containers/Bundle/Application/"]]] mutableCopy];
    [bundlePath appendString:@"/"];
    [bundlePath appendString:app.BundleUUID];
    [bundlePath appendString:@"/"];
    [bundlePath appendString:app.AppName];
    [bundlePath appendString:@"/"];
    
    return bundlePath;
}

-(NSMutableString*)dataPathForApp:(AppInfo*)app ofDevice:(DeviceInfo*)device {
    NSMutableString* dataPath = [[NSHomeDirectory() stringByAppendingPathComponent:[KDevicesDirPath stringByAppendingPathComponent:[device.UUID stringByAppendingPathComponent:@"data/Containers/Data/Application/"]]] mutableCopy];
    [dataPath appendString:@"/"];
    [dataPath appendString:app.DataUUID];
    [dataPath appendString:@"/"];
    
    return dataPath;
}

-(void)buttonPressed:(NSTableView*)table {
    
    NSInteger row = [table clickedRow];
    NSInteger col = [table clickedColumn];
    //NSLog(@"row:%ld, col:%ld", row, col);
    DeviceInfo* device = mDevicesArray[table.tag];
    AppInfo* app = ((NSArray*)mDevicesDict[device.Name])[row];
    
    if(col == 2) {
        //open bundle
        NSMutableString* bundlePath = [self bundlePathForApp:app ofDevice:device];
        
        //get the first file name inside the .app
        NSFileManager* fm = [NSFileManager defaultManager];
        NSString* firstFile = [[fm contentsOfDirectoryAtPath:bundlePath error:nil] objectAtIndex:0];
        [bundlePath appendString:firstFile];
        
        NSString* cmd = [NSString stringWithFormat:@"open -R %@", bundlePath];
        
        system([cmd UTF8String]);
    } else if(col == 3) {
        //copy bundle path
        NSMutableString* bundlePath = [self bundlePathForApp:app ofDevice:device];
        
        NSPasteboard* pb = [NSPasteboard generalPasteboard];
        [pb declareTypes:[NSArray arrayWithObject:NSPasteboardTypeString] owner:nil];
        [pb setString:bundlePath forType:NSStringPboardType];
        
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setAlertStyle:NSInformationalAlertStyle];
        [alert setMessageText:@"Info"];
        [alert setInformativeText:@"app bundle path has been copied to your pasteboard."];
        
        [alert beginSheetModalForWindow:self.window
                          modalDelegate:self 
                         didEndSelector:nil
                            contextInfo:nil];
        
    } else if(col == 4) {
        //open data
        NSMutableString* dataPath = [self dataPathForApp:app ofDevice:device];
        
        NSString* cmd = [NSString stringWithFormat:@"open %@", dataPath];
        
        system([cmd UTF8String]);
        
    } else if(col == 5) {
        //copy data path
        NSMutableString* dataPath = [self dataPathForApp:app ofDevice:device];
        
        NSPasteboard* pb = [NSPasteboard generalPasteboard];
        [pb declareTypes:[NSArray arrayWithObject:NSPasteboardTypeString] owner:nil];
        [pb setString:dataPath forType:NSStringPboardType];
        
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setAlertStyle:NSInformationalAlertStyle];
        [alert setMessageText:@"Info"];
        [alert setInformativeText:@"path has been copied to your pasteboard."];
         
         [alert beginSheetModalForWindow:self.window
                           modalDelegate:self 
                          didEndSelector:nil
                             contextInfo:nil];
    }
}

- (IBAction)copyrightPressed:(id)sender {
    
    [[NSWorkspace sharedWorkspace] openURL:
     [NSURL URLWithString:@"https://laoyur.com/"]];
}

#pragma mark -
#pragma mark NSComboBoxDelegate

- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
    
    mOsKeyString = [NSString stringWithFormat:@"com.apple.CoreSimulator.SimRuntime.%@", self.mOsCombo.objectValueOfSelectedItem];
    
    NSInteger sel = [self.mTabView indexOfTabViewItem:self.mTabView.selectedTabViewItem];
    [self reloadAll];
    [self.mTabView selectTabViewItemAtIndex:sel];
}

@end
