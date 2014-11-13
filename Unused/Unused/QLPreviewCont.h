//
//  QLPreviewCont.h
//  Unused
//
//  Created by Damien Legrand on 13/11/2014.
//
//

#import <Foundation/Foundation.h>
#import <QuickLook/QuickLook.h>
#import <Quartz/Quartz.h>

@interface QLPreviewCont : NSResponder <QLPreviewPanelDataSource, QLPreviewPanelDelegate>
{
    NSMutableArray *pictures;
}

-(void)setPictures:(NSArray*)theArray;
-(NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel;
-(id <QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)index;
-(BOOL)previewPanel:(QLPreviewPanel *)panel handleEvent:(NSEvent *)event;
-(NSRect)previewPanel:(QLPreviewPanel *)panel sourceFrameOnScreenForPreviewItem:(id <QLPreviewItem>)item;

@end
