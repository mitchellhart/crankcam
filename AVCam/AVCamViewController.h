/*
     File: AVCamViewController.h
 Abstract: View controller for camera interface.
  Version: 3.1
 
 */

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>


@interface AVCamViewController : UIViewController
{
    
    
    IBOutlet UIView* m_block;
    CGPoint m_locationBegan;
    float m_currentAngle;
    
    IBOutlet UIView *crankView;
    IBOutlet UIImageView *frameOne;
    IBOutlet UIImageView *pictureTake;
    
    int timerInt;
    __weak IBOutlet UILabel *timerLabel;
    NSTimer *timer;
    

    
    BOOL started;
    CMTime frameDuration;
    CMTime nextPTS;
    AVAssetWriter *assetWriter;
    AVAssetWriterInput *assetWriterInput;
    AVCaptureStillImageOutput *stillImageOutput;
    NSURL *outputURL;
  
    __weak IBOutlet UILabel *savedLabel;
    __weak IBOutlet UILabel *frameLabel;
    __weak IBOutlet UILabel *infoLabel;
    __weak IBOutlet UILabel *speedLabel;

}


- (void)countDown;


- (void)delay;
- (void)toggleMovieRecording;

- (float) updateRotation:(CGPoint)_location;



@end




