//
//  UnusedAppDelegate.m
//  Unused
//
//  Created by Jeff Hodnett on 19/11/2011.
//  Copyright 2011 Seamonster Ltd. All rights reserved.
//

#import "UnusedAppDelegate.h"

#define SHOULD_FILTER_ENUM_VARIANTS YES

@implementation UnusedAppDelegate
@synthesize DeleteSelected = _DeleteSelected;
@synthesize DeleteAllUnUsed = _DeleteAllUnUsed;

@synthesize resultsTableView=_resultsTableView;
@synthesize processIndicator=_processIndicator;
@synthesize statusLabel=_statusLabel;
@synthesize window=_window;
@synthesize mCheckbox=_mCheckbox;
@synthesize xibCheckbox=_xibCheckbox;
@synthesize storyboardCheckbox = _storyboardCheckbox;
@synthesize cppCheckbox=_cppCheckbox;
@synthesize mmCheckbox=_mmCheckbox;
@synthesize htmlCheckbox =_htmlCheckbox;
@synthesize plistCheckbox =_plistCheckbox;
@synthesize browseButton=_browseButton;
@synthesize pathTextField=_pathTextField;
@synthesize searchButton=_searchButton;
@synthesize exportButton=_exportButton;
@synthesize searchDirectoryPath=_searchDirectoryPath;
@synthesize typeSearchRadio=_typeSearchRadio;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    // Setup the results array
    _results = [[NSMutableArray alloc] init];

    // Setup the retina images array
    _retinaImagePaths = [[NSMutableArray alloc] init];
    _retinaHDImagePaths = [[NSMutableArray alloc] init];
    _iPadImagePaths = [[NSMutableArray alloc] init];
    _retinaiPadImagePaths = [[NSMutableArray alloc] init];

    // Setup the queue
    _queue = [[NSOperationQueue alloc] init];

    // Setup double click
    [_resultsTableView setDoubleAction:@selector(tableViewDoubleClicked)];

    // Setup labels
    [_statusLabel setTextColor:[NSColor lightGrayColor]];

    // Setup search button
    [_searchButton setBezelStyle:NSRoundedBezelStyle];
    [_searchButton setKeyEquivalent:@"\r"];
    [_resultsTableView setAllowsMultipleSelection: YES];
    
    NSEvent * (^monitorHandler)(NSEvent *);
    monitorHandler = ^NSEvent * (NSEvent * theEvent){
        
        if([theEvent keyCode] == 49)
        {
            [self spacePressed];
        }
        
        return theEvent;
    };
    
    eventMon = [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDownMask
                                                     handler:monitorHandler];
    

    
}

- (void)dealloc {
    
    [_searchDirectoryPath release];
    [_pngFiles release];
    [_imagesetFolders release];
    [_results release];
    [_retinaImagePaths release];
    [_retinaHDImagePaths release];
    [_queue release];
    [eventMon release];

    [super dealloc];
}

#pragma mark - Actions

-(void)spacePressed
{
    if ([QLPreviewPanel sharedPreviewPanelExists] && [[QLPreviewPanel sharedPreviewPanel] isVisible]) {
        [[QLPreviewPanel sharedPreviewPanel] orderOut:nil];
    } else {
        if(_results.count == 0) return;
        [[QLPreviewPanel sharedPreviewPanel] updateController];
        [[QLPreviewPanel sharedPreviewPanel] makeKeyAndOrderFront:nil];
    }
}

- (IBAction)browseButtonSelected:(id)sender {
    
    // Show an open panel
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];

    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanChooseFiles:NO];

    NSInteger option = [openPanel runModal];
    if (option == NSModalResponseOK) {
        // Store the path
        self.searchDirectoryPath = [[openPanel directoryURL] path];

        // Update the path text field
        [self.pathTextField setStringValue:self.searchDirectoryPath];
    }
}

- (IBAction)exportButtonSelected:(id)sender {
    
    NSSavePanel *save = [NSSavePanel savePanel];
    [save setAllowedFileTypes:[NSArray arrayWithObject:@"txt"]];
    NSInteger result = [save runModal];

    if (result == NSModalResponseOK) {
        NSString *selectedFile = [[save URL] path];

        NSMutableString *outputResults = [[NSMutableString alloc] init];
        [outputResults appendFormat:@"Unused Files in project %@\n\n",self.searchDirectoryPath];

        for (NSString *path in _results) {
            [outputResults appendFormat:@"%@\n",path];
        }

        // Output
        [outputResults writeToFile:selectedFile atomically:YES encoding:NSUTF8StringEncoding error:nil];

        [outputResults release];
    }
}

-(IBAction)startSearch:(id)sender {
    
    // Check for a path
    if (!self.searchDirectoryPath) {
        // Show an alert
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert setMessageText:@"Project Path Error"];
        [alert setInformativeText:@"Please select a valid project folder!"];
        [alert runModal];

        return;
    }

    // Check the path
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.searchDirectoryPath]) {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert setMessageText:@"Project Path Error"];
        [alert setInformativeText:@"Path is not valid!! Please select a valid project folder!"];
        [alert runModal];

        return;
    }

    // Change the button text
    [_searchButton setEnabled:NO];
    [_searchButton setKeyEquivalent:@""];

    // Reset
    [_results removeAllObjects];
    [_retinaImagePaths removeAllObjects];
    [_retinaHDImagePaths removeAllObjects];
    [_iPadImagePaths removeAllObjects];
    [_retinaiPadImagePaths removeAllObjects];
    [_resultsTableView reloadData];

    
    NSInvocationOperation *op = nil;
    
    // Start the search
    if(_typeSearchRadio.selectedRow == 0)
    {
        op = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(runXcassetsSearch) object:nil];
    }
    else
    {
        op = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(runImageSearch) object:nil];
    }
    
    // Start the ui
    [self setUIEnabled:NO];
    
    [_queue addOperation:op];
    [op release];

    isSearching = YES;
}

- (void)runXcassetsSearch {
    
    [_imagesetFolders release];
    _imagesetFolders = [[self imagesetFoldersAtDirectory:_searchDirectoryPath] retain];
    
    NSArray *imagesetFolders = _imagesetFolders;
    
    if (SHOULD_FILTER_ENUM_VARIANTS) {
        
        NSMutableArray *mutableImagesetFiles = [NSMutableArray arrayWithArray:imagesetFolders];
        
        // Trying to filter image names like: "Section_0.imageset", "Section_1.imageset", etc (these names can possibly be created by [NSString stringWithFormat:@"Section_%d", (int)] constructions) to just "Section_" item
        for (NSInteger index = 0, count = [mutableImagesetFiles count]; index < count; index++) {
            
            NSString *imageName = [mutableImagesetFiles objectAtIndex:index];
            NSRegularExpression *regExp = [NSRegularExpression regularExpressionWithPattern:@"[_-].*\\d.*.imageset" options:NSRegularExpressionCaseInsensitive error:nil];
            NSString *newImageName = [regExp stringByReplacingMatchesInString:imageName options:NSMatchingReportProgress range:NSMakeRange(0, [imageName length]) withTemplate:@""];
            if (newImageName != nil)
                [mutableImagesetFiles replaceObjectAtIndex:index withObject:newImageName];
        }
        
        // Remove duplicates and update imagesetFolders array
        imagesetFolders = [[NSSet setWithArray:mutableImagesetFiles] allObjects];
    }
    
    // Now loop and check
    for (NSString *imagesetPath in imagesetFolders) {
        
        // Check that the png path is not empty
        if (![imagesetPath isEqualToString:@""]) {
            // Grab the file name
            NSString *imageName = [imagesetPath lastPathComponent];
            
            imageName = [imageName stringByReplacingOccurrencesOfString:@".imageset" withString:@""];
            
            // Run the checks
            if ([_mCheckbox state] && [self occurancesOfImageNamed:imageName atDirectory:_searchDirectoryPath inFileExtensionType:@"m"]) {
                continue;
            }
            
            if ([_xibCheckbox state] && [self occurancesOfImageNamed:imageName atDirectory:_searchDirectoryPath inFileExtensionType:@"xib"]) {
                continue;
            }
            
            if ([_storyboardCheckbox state] && [self occurancesOfImageNamed:imageName atDirectory:_searchDirectoryPath inFileExtensionType:@"storyboard"]) {
                continue;
            }
            
            if ([_cppCheckbox state] && [self occurancesOfImageNamed:imageName atDirectory:_searchDirectoryPath inFileExtensionType:@"cpp"]) {
                continue;
            }
            
            if ([_mmCheckbox state] && [self occurancesOfImageNamed:imageName atDirectory:_searchDirectoryPath inFileExtensionType:@"mm"]) {
                continue;
            }
            
            if ([_htmlCheckbox state] && [self occurancesOfImageNamed:imageName atDirectory:_searchDirectoryPath inFileExtensionType:@"html"]) {
                continue;
            }
            
            if ([_plistCheckbox state] && [self occurancesOfImageNamed:imageName atDirectory:_searchDirectoryPath inFileExtensionType:@"plist"]) {
                continue;
            }
            
            // Is it not found
            // Update results
            [self addImagesetNewResult:imagesetPath];
        }
    }
    
    // Sorting results and refreshing table
    [_results sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    [_resultsTableView reloadData];
    
    // Calculate how much file size we saved and update the label
    int fileSize = 0;
    for (NSString *path in _results) {
        fileSize += [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] fileSize];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^(void){
        // Enable the ui
        [_statusLabel setStringValue:[NSString stringWithFormat:@"Completed - Found %ld - Size %@", (unsigned long)[_results count], [self stringFromFileSize:fileSize]]];
        [self setUIEnabled:YES];
    });
    
    isSearching = NO;
    
}

- (void)runImageSearch {

    // Find all the .png files in the folder
    [_pngFiles release];
    _pngFiles = [[self pngFilesAtDirectory:_searchDirectoryPath] retain];

    NSArray *pngFiles = _pngFiles;

    if (SHOULD_FILTER_ENUM_VARIANTS) {
        
        NSMutableArray *mutablePngFiles = [NSMutableArray arrayWithArray:pngFiles];

        // Trying to filter image names like: "Section_0.png", "Section_1.png", etc (these names can possibly be created by [NSString stringWithFormat:@"Section_%d", (int)] constructions) to just "Section_" item
        for (NSInteger index = 0, count = [mutablePngFiles count]; index < count; index++) {
            
            NSString *imageName = [mutablePngFiles objectAtIndex:index];
            NSRegularExpression *regExp = [NSRegularExpression regularExpressionWithPattern:@"[_-].*\\d.*.png" options:NSRegularExpressionCaseInsensitive error:nil];
            NSString *newImageName = [regExp stringByReplacingMatchesInString:imageName options:NSMatchingReportProgress range:NSMakeRange(0, [imageName length]) withTemplate:@""];
            if (newImageName != nil)
                [mutablePngFiles replaceObjectAtIndex:index withObject:newImageName];
        }

        // Remove duplicates and update pngFiles array
        pngFiles = [[NSSet setWithArray:mutablePngFiles] allObjects];
    }

    // Setup all the @2x image firstly
    for (NSString *pngPath in _pngFiles) {
        NSString *imageName = [pngPath lastPathComponent];

        // Does the image have a @3x
        NSRange retinaHDRange = [imageName rangeOfString:@"@3x"];
        if (retinaHDRange.location != NSNotFound) {
            // Add to retina image paths
            [_retinaHDImagePaths addObject:pngPath];
        }
        
        // Does the image have a @2x
        NSRange retinaRange = [imageName rangeOfString:@"@2x"];
        if (retinaRange.location != NSNotFound) {
            // Add to retina image paths
            [_retinaImagePaths addObject:pngPath];
        }
        
        NSRange iPadRange = [imageName rangeOfString:@"~ipad"];
        if (iPadRange.location != NSNotFound) {
            
            [_iPadImagePaths addObject:pngPath];
        }
        
        NSRange retinaiPadRange = [imageName rangeOfString:@"@2x~ipad"];
        if (retinaiPadRange.location != NSNotFound) {
            
            [_retinaiPadImagePaths addObject:pngPath];
        }
    }

    // Now loop and check
    for (NSString *pngPath in pngFiles) {

        // Check that the png path is not empty
        if (![pngPath isEqualToString:@""]) {
            // Grab the file name
            NSString *imageName = [pngPath lastPathComponent];

            // Check that it's not a @2x or reserved image name
            if ([self isValidImageAtPath:pngPath]) {

                // Run the checks
                if ([_mCheckbox state] && [self occurancesOfImageNamed:imageName atDirectory:_searchDirectoryPath inFileExtensionType:@"m"]) {
                    continue;
                }

                if ([_xibCheckbox state] && [self occurancesOfImageNamed:imageName atDirectory:_searchDirectoryPath inFileExtensionType:@"xib"]) {
                    continue;
                }
                
                if ([_storyboardCheckbox state] && [self occurancesOfImageNamed:imageName atDirectory:_searchDirectoryPath inFileExtensionType:@"storyboard"]) {
                    continue;
                }

                if ([_cppCheckbox state] && [self occurancesOfImageNamed:imageName atDirectory:_searchDirectoryPath inFileExtensionType:@"cpp"]) {
                    continue;
                }

                if ([_mmCheckbox state] && [self occurancesOfImageNamed:imageName atDirectory:_searchDirectoryPath inFileExtensionType:@"mm"]) {
                    continue;
                }

                if ([_htmlCheckbox state] && [self occurancesOfImageNamed:imageName atDirectory:_searchDirectoryPath inFileExtensionType:@"html"]) {
                    continue;
                }

                if ([_plistCheckbox state] && [self occurancesOfImageNamed:imageName atDirectory:_searchDirectoryPath inFileExtensionType:@"plist"]) {
                    continue;
                }

                // Is it not found
                // Update results
                [self addNewResult:pngPath];
            }
        }
    }

    // Sorting results and refreshing table
    [_results sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    [_resultsTableView reloadData];

    // Calculate how much file size we saved and update the label
    int fileSize = 0;
    for (NSString *path in _results) {
        fileSize += [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] fileSize];
    }

    dispatch_async(dispatch_get_main_queue(), ^(void){
        // Enable the ui
        [_statusLabel setStringValue:[NSString stringWithFormat:@"Completed - Found %ld - Size %@", (unsigned long)[_results count], [self stringFromFileSize:fileSize]]];
        [self setUIEnabled:YES];
    });

    isSearching = NO;
}

- (void)setUIEnabled:(BOOL)state {
    
    if (state) {
        [_searchButton setTitle:@"Search"];
        [_searchButton setKeyEquivalent:@"\r"];
        [_searchButton setEnabled:YES];
        [_processIndicator setHidden:YES];
        [_processIndicator stopAnimation:self];
        [_mCheckbox setEnabled:YES];
        [_xibCheckbox setEnabled:YES];
        [_storyboardCheckbox setEnabled:YES];
        [_cppCheckbox setEnabled:YES];
        [_mmCheckbox setEnabled:YES];
        [_htmlCheckbox setEnabled:YES];
        [_plistCheckbox setEnabled:YES];
        [_browseButton setEnabled:YES];
        [_pathTextField setEnabled:YES];
        [_exportButton setHidden:NO];
        [_DeleteAllUnUsed setHidden:NO];
        [_DeleteSelected setHidden:NO];
        [_typeSearchRadio setEnabled:YES];

        

    }
    else {
        [_processIndicator setHidden:NO];
        [_processIndicator startAnimation:self];
        [_statusLabel setStringValue:@"Searching..."];
        [_mCheckbox setEnabled:NO];
        [_xibCheckbox setEnabled:NO];
        [_storyboardCheckbox setEnabled:NO];
        [_cppCheckbox setEnabled:NO];
        [_mmCheckbox setEnabled:NO];
        [_htmlCheckbox setEnabled:NO];
        [_plistCheckbox setEnabled:NO];
        [_browseButton setEnabled:NO];
        [_pathTextField setEnabled:NO];
        [_exportButton setHidden:YES];
        [_DeleteAllUnUsed setHidden:YES];
        [_DeleteSelected setHidden:YES];
        [_typeSearchRadio setEnabled:NO];
    }
}

- (NSArray *)imagesetFoldersAtDirectory:(NSString *)directoryPath {
    
    // Create a find task
    NSTask *task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath: @"/usr/bin/find"];
    
    // Search for all png files
    NSArray *argvals = [NSArray arrayWithObjects:directoryPath,@"-name",@"*.imageset", nil];
    [task setArguments: argvals];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    [task launch];
    
    // Read the response
    NSData *data;
    data = [file readDataToEndOfFile];
    
    NSString *string;
    string = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];
    
    // See if we can create a lines array
    NSArray *lines = [string componentsSeparatedByString:@"\n"];
    
    return lines;
    
}

- (NSArray *)pngFilesAtDirectory:(NSString *)directoryPath {
    
    // Create a find task
    NSTask *task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath: @"/usr/bin/find"];

    // Search for all png files
    NSArray *argvals = [NSArray arrayWithObjects:directoryPath,@"-name",@"*.png", nil];
    [task setArguments: argvals];

    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];

    NSFileHandle *file;
    file = [pipe fileHandleForReading];

    [task launch];

    // Read the response
    NSData *data;
    data = [file readDataToEndOfFile];

    NSString *string;
    string = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];

    // See if we can create a lines array
    NSArray *lines = [string componentsSeparatedByString:@"\n"];

    return lines;
}

- (BOOL)isValidImageAtPath:(NSString *)imagePath {
    
    NSString *imageName = [imagePath lastPathComponent];

    // Does the image have a @3x
    NSRange retinaHDRange = [imageName rangeOfString:@"@3x"];
    if(retinaHDRange.location != NSNotFound) {
        return NO;
    }
    
    // Does the image have a @2x
    NSRange retinaRange = [imageName rangeOfString:@"@2x"];
    if(retinaRange.location != NSNotFound) {
        return NO;
    }
    
    NSRange iPadImage = [imageName rangeOfString:@"~ipad"];
    if (iPadImage.location != NSNotFound) {
        return NO;
    }
    
    NSRange iPhoneImage = [imageName rangeOfString:@"~iphone"];
    if (iPhoneImage.location != NSNotFound) {
        return NO;
    }

    // Is the name a part of 3rd party bundle
    if([imagePath rangeOfString:@".bundle"].length > 0) {
        return NO;
    }

    // Is the name is Default
    if([imageName isEqualToString:@"Default.png"]) {
        return NO;
    }

    // Is the name Icon
    if([imageName isEqualToString:@"Icon.png"] || [imageName isEqualToString:@"Icon@2x.png"] || [imageName isEqualToString:@"Icon@3x.png"] || [imageName isEqualToString:@"Icon-72.png"]) {
        return NO;
    }

    return YES;
}

- (int)occurancesOfImageNamed:(NSString *)imageName atDirectory:(NSString *)directoryPath inFileExtensionType:(NSString *)extension {
    
    NSTask *task;
    task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath: @"/bin/sh"];

    // Setup the call
    NSString *cmd = [NSString stringWithFormat:@"export IFS=""; while read file; do cat $file | grep -o %@ ; done <<< $(find %@ -name *.%@)", [imageName stringByDeletingPathExtension], directoryPath, extension];
    NSArray *argvals = [NSArray arrayWithObjects: @"-c", cmd, nil];
    [task setArguments: argvals];

    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];

    NSFileHandle *file;
    file = [pipe fileHandleForReading];

    [task launch];

    // Read the response
    NSData *data;
    data = [file readDataToEndOfFile];

    NSString *string;
    string = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];

    // Calculate the count
    NSScanner *scanner = [NSScanner scannerWithString: string];
    NSCharacterSet *newline = [NSCharacterSet newlineCharacterSet];
    int count = 0;
    while ([scanner scanUpToCharactersFromSet: newline  intoString: nil]) {
        count++;
    }

    return count;
}

- (IBAction)DeleteSelected:(id)sender {
   NSIndexSet*selectedIndexSet= [_resultsTableView selectedRowIndexes];
    for (int count=0; count<[selectedIndexSet count]; count++) {
     NSUInteger index=   [selectedIndexSet indexGreaterThanOrEqualToIndex:count];
      NSString *path=      [_results objectAtIndex:index];
              [_results removeObjectAtIndex:index];
        
        [_resultsTableView reloadData];
        [self deleteFileWithPath:path];
        [_resultsTableView deselectRow:index];

    }

}

- (void)addImagesetNewResult:(NSString *)imagesetPath {
    
    if ([_imagesetFolders indexOfObject:imagesetPath] == NSNotFound)
        return;
    
    // Add and reload
    [_results addObject:imagesetPath];
    
    dispatch_async(dispatch_get_main_queue(), ^(void){
        // Reload
        [_resultsTableView reloadData];
        
        // Scroll to the bottom
        NSInteger numberOfRows = [_resultsTableView numberOfRows];
        if (numberOfRows > 0)
            [_resultsTableView scrollRowToVisible:numberOfRows - 1];
    });
}

- (void)addNewResult:(NSString *)pngPath {
    
    if ([_pngFiles indexOfObject:pngPath] == NSNotFound)
        return;

    // Add and reload
    [_results addObject:pngPath];

    NSString *imageName = [pngPath lastPathComponent];
    
    // Check for an @3x image too!
    for (NSString *retinaPath in _retinaHDImagePaths) {
        
        // Compare the image name and the retina image name
        
        imageName = [imageName stringByDeletingPathExtension];
        NSString *retinaImageName = [retinaPath lastPathComponent];
        retinaImageName = [retinaImageName stringByDeletingPathExtension];
        retinaImageName = [retinaImageName stringByReplacingOccurrencesOfString:@"@3x" withString:@""];
        
        // Check
        if ([imageName isEqualToString:retinaImageName]) {
            // Add it
            [_results addObject:retinaPath];
            
            break;
        }
    }
    
    // Check for an @2x image too!
    for (NSString *retinaPath in _retinaImagePaths) {

        // Compare the image name and the retina image name
        
        imageName = [imageName stringByDeletingPathExtension];
        NSString *retinaImageName = [retinaPath lastPathComponent];
        retinaImageName = [retinaImageName stringByDeletingPathExtension];
        retinaImageName = [retinaImageName stringByReplacingOccurrencesOfString:@"@2x" withString:@""];

        // Check
        if ([imageName isEqualToString:retinaImageName]) {
            // Add it
            [_results addObject:retinaPath];

            break;
        }
    }
    
    // Check for ~ipad image too
    
    for (NSString *iPadPath in _iPadImagePaths) {
        
        NSString *iPadImageName = [iPadPath lastPathComponent];
        iPadImageName = [iPadImageName stringByDeletingPathExtension];
        iPadImageName = [iPadImageName stringByReplacingOccurrencesOfString:@"~ipad" withString:@""];
        
        if ([imageName isEqualToString:iPadImageName]) {
            
            [_results addObject:imageName];
            break;
        }
    }
    
    for (NSString *iPadPath in _retinaiPadImagePaths) {
        
        NSString *iPadImageName = [iPadPath lastPathComponent];
        iPadImageName = [iPadImageName stringByDeletingPathExtension];
        iPadImageName = [iPadImageName stringByReplacingOccurrencesOfString:@"@2x~ipad" withString:@""];
        
        if ([imageName isEqualToString:iPadImageName]) {
            
            [_results addObject:imageName];
            break;
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^(void){
        // Reload
        [_resultsTableView reloadData];
        
        // Scroll to the bottom
        NSInteger numberOfRows = [_resultsTableView numberOfRows];
        if (numberOfRows > 0)
            [_resultsTableView scrollRowToVisible:numberOfRows - 1];
    });
}

#pragma mark - NSTableView Delegate
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    
    return [_results count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex {
    
    NSString *pngPath = [_results objectAtIndex:rowIndex];

    if ([[tableColumn identifier] isEqualToString:@"shortName"]) {
        
        NSString *imageName = [pngPath lastPathComponent];
        if([imageName rangeOfString:@".imageset"].location != NSNotFound)
        {
            imageName = [imageName stringByReplacingOccurrencesOfString:@".imageset" withString:@""];
        }
        return imageName;
    }
//    if ([[tableColumn identifier] isEqualToString:@"viewImage"]) {
//        
//       NSImage*img= [[NSImage alloc ]initWithContentsOfFile:pngPath];
//        NSImageCell *imageCell = [[NSImageCell alloc] initImageCell:img];
//        return imageCell;
//    }

    return pngPath;
}
#pragma mark - Table View Delegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    
    NSTableView *tableView = notification.object;
    NSLog(@"User has selected row %ld", (long)tableView.selectedRow);
}

- (void)tableViewDoubleClicked {
    
    // Open finder
    NSString *path = [_results objectAtIndex:[_resultsTableView clickedRow]];
    [[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:nil];
}

- (NSString *)stringFromFileSize:(int)theSize {
    
	float floatSize = theSize;
    
	if (theSize < 1023)
		return([NSString stringWithFormat:@"%i bytes",theSize]);
    
	floatSize = floatSize / 1024;
    
	if (floatSize < 1023)
		return([NSString stringWithFormat:@"%1.1f KB",floatSize]);
    
	floatSize = floatSize / 1024;
    
	if (floatSize < 1023)
		return([NSString stringWithFormat:@"%1.1f MB",floatSize]);
    
	floatSize = floatSize / 1024;

	// Add as many as you like

	return ([NSString stringWithFormat:@"%1.1f GB",floatSize]);
}

- (IBAction)DeleteAllUnUsed:(id)sender {
    for (NSString*path in _results) {
        [self deleteFileWithPath:path];
    }

}
-(void)deleteFileWithPath:(NSString*)path{
    NSTask *task;
    task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath: @"/bin/sh"];
    
    // Setup the call
    NSString *cmd = [NSString stringWithFormat:@"rm %@",path];
    NSArray *argvals = [NSArray arrayWithObjects: @"-c", cmd, nil];
    [task setArguments: argvals];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    [task launch];

}


#pragma mark - Quicklook

- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel;
{
    return YES;
}

- (NSArray *)getTheSelectedPicturesInTheTable
{
    if(_results.count > 0
       && _resultsTableView.numberOfRows > 0
       && _resultsTableView.numberOfSelectedRows > 0)
    {
        NSMutableArray *results = [NSMutableArray arrayWithCapacity:_resultsTableView.numberOfSelectedRows];
        
        [_resultsTableView.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            
            NSArray *files = [self pngFilesAtDirectory:_results[idx]];
            
            if(files.count > 0)
            {
                [results addObject:files[0]];
            }
        }];
        
        return results;
    }
    
    return nil;
}

-(void)beginPreviewPanelControl:(QLPreviewPanel *)panel
{
    if (!_quickLookCont) {
        _quickLookCont = [[QLPreviewCont alloc]init];
    }
    [_quickLookCont setPictures:[self getTheSelectedPicturesInTheTable]];
    [[QLPreviewPanel sharedPreviewPanel] setDelegate:_quickLookCont];
    [[QLPreviewPanel sharedPreviewPanel] setDataSource:_quickLookCont];
}

-(void)endPreviewPanelControl:(QLPreviewPanel *)panel
{
    
}

@end
