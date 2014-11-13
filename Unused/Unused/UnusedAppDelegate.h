//
//  UnusedAppDelegate.h
//  Unused
//
//  Created by Jeff Hodnett on 19/11/2011.
//  Copyright 2011 Seamonster Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuickLook/QuickLook.h>
#import <Quartz/Quartz.h>
#import "QLPreviewCont.h"

@interface UnusedAppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate> {
@private

    // Arrays
    NSArray *_pngFiles;
    NSArray *_imagesetFolders;
    NSMutableArray *_results;
    NSMutableArray *_retinaImagePaths;
    NSMutableArray *_retinaHDImagePaths;
    NSMutableArray *_iPadImagePaths;
    NSMutableArray *_retinaiPadImagePaths;

    NSOperationQueue *_queue;
    BOOL isSearching;
    NSButton *_DeleteAllUnUsed;
    NSButton *_DeleteSelected;
    
    QLPreviewCont *_quickLookCont;
    
    NSEvent *eventMon;
}

// Outlets
@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSTableView *resultsTableView;
@property (assign) IBOutlet NSProgressIndicator *processIndicator;
@property (assign) IBOutlet NSTextField *statusLabel;
@property (assign) IBOutlet NSButton *exportButton;
@property (assign) IBOutlet NSButton *mCheckbox;
@property (assign) IBOutlet NSButton *xibCheckbox;
@property (assign) IBOutlet NSButton *storyboardCheckbox;
@property (assign) IBOutlet NSButton *cppCheckbox;
@property (assign) IBOutlet NSButton *htmlCheckbox;
@property (assign) IBOutlet NSButton *mmCheckbox;
@property (assign) IBOutlet NSButton *plistCheckbox;
@property (assign) IBOutlet NSButton *browseButton;
@property (assign) IBOutlet NSTextField *pathTextField;
@property (assign) IBOutlet NSButton *searchButton;
@property (assign) IBOutlet NSMatrix *typeSearchRadio;

// The search directory path
@property(nonatomic, retain) NSString *searchDirectoryPath;

// Actions
- (IBAction)browseButtonSelected:(id)sender;
- (IBAction)startSearch:(id)sender;
- (IBAction)exportButtonSelected:(id)sender;
@property (assign) IBOutlet NSButton *DeleteAllUnUsed;
- (IBAction)DeleteAllUnUsed:(id)sender;

// Methods
- (NSArray *)pngFilesAtDirectory:(NSString *)directoryPath;
- (BOOL)isValidImageAtPath:(NSString *)imagePath;
- (int)occurancesOfImageNamed:(NSString *)imageName atDirectory:(NSString *)directoryPath inFileExtensionType:(NSString *)extension;
@property (assign) IBOutlet NSButton *DeleteSelected;
- (IBAction)DeleteSelected:(id)sender;

- (void)addNewResult:(NSString *)pngPath;

// Handle the ui updates
- (void)setUIEnabled:(BOOL)state;

- (NSString *)stringFromFileSize:(int)theSize;

@end
