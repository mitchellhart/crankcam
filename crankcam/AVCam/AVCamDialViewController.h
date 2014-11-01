//
//  AVCamDialViewController.h
//  AVCam
//
//  Created by Mitchell Hart on 8/9/14.
//  Copyright (c) 2014 Apple Inc. All rights reserved.
//

#import "AVCamViewController.h"
#import <UIKit/UIKit.h>

@class AVCamDialViewController;

@protocol AVCamViewController
- (void) AVCamDialViewController: (AVCamDialViewController*) AVCamDialViewController didTakeFrame: (UIColor*) color;
@end

@interface AVCamDialViewController : UIView {
    @private
        id<AVCamViewController> _delegate;
    @private
    UIView* _lastView;
}

@property (nonatomic,assign) IBOutlet id<AVCamViewController> delegate;

@end
