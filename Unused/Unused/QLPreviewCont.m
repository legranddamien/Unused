//
//  QLPreviewCont.m
//  Unused
//
//  Created by Damien Legrand on 13/11/2014.
//
//
#import "QLPreviewCont.h"
#import "UnusedAppDelegate.h"
@implementation QLPreviewCont

-(id)init
{
    if (self == [super init]) {
        pictures = [[NSMutableArray alloc]init];
        return self;
    }
    return nil;
}

-(void)setPictures:(NSArray*)theArray
{
    [pictures removeAllObjects];
    [pictures setArray:theArray];
}

// Quick Look panel data source
- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel
{
    return [pictures count];
}

- (id <QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)index
{
    
    //I’m going to assume that you’ve stored the NSURL’s as strings…
    return [NSURL URLWithString:[pictures objectAtIndex:index]];
}

// Quick Look panel delegate
- (BOOL)previewPanel:(QLPreviewPanel *)panel handleEvent:(NSEvent *)event
{
    UnusedAppDelegate *appController = (UnusedAppDelegate *)[[NSApplication sharedApplication] delegate];
    // redirect all key down events to the table view
    if ([event type] == NSKeyDown) {
        [[appController resultsTableView] keyDown:event];
        return YES;
    }
    return NO;
}

// This delegate method provides the rect on screen from which the panel will zoom.
- (NSRect)previewPanel:(QLPreviewPanel *)panel sourceFrameOnScreenForPreviewItem:(id <QLPreviewItem>)item
{
    UnusedAppDelegate *appController = (UnusedAppDelegate *)[[NSApplication sharedApplication] delegate];
    //get table rect in window co-ords
    NSRect tempRect = [[appController resultsTableView] convertRectToBase:[[appController resultsTableView] visibleRect]];
    //and then to main screen co-ords
    tempRect = [[appController window] convertRectToScreen:tempRect];
    return tempRect;
}

@end

