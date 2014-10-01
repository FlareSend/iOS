
/*
     File: RosyWriterCPURenderer.m
 Abstract: The RosyWriter CPU-based effect renderer
  Version: 2.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 
 */

#import "RosyWriterCPURenderer.h"

int *recordedColors;
int numIndexes = -1;
int same = 0;
int lastR = -2;
int lastG = - 2;
int lastB = -2;
int lastNormR = -2;
int lastNormG = -2;
int lastNormB = -2;
int recordState = 0;

@implementation RosyWriterCPURenderer {
    RosyWriterViewController * centralViewController;
}
- (id) initWithViewController:(RosyWriterViewController *) vc {
    
    self = [super init];
    if (self) {
        centralViewController = vc;
    }
    
    return self;
}

- (void) setState: (int) n {
    
    if (n == 1) {
        [self reset];
    } else if (n == 0) {
        
    }

    recordState = n;
}

int defineBit(int n) {
    if (n < 10) return 0;
    if (n < 197) return 138;
    return 255;
}

int modVal(val, up) {
    if (up == 1){
        return 255;
    } else {
        return 138;
    }
}

//best in class function:
int addToRecordedColors(int r, int g, int b) {
    int cr = defineBit(r);
    int cg = defineBit(g);
    int cb = defineBit(b);
    BOOL isNotIdenticle = !(recordedColors[numIndexes - 3] == cr && recordedColors[numIndexes - 2] == cg && recordedColors[numIndexes - 1] == cb);
    if (numIndexes > 6 && !isNotIdenticle) {
        same += 1;
        if (same > 10) {
            same = 0;
            return -99;
        }
    } else {
        same = 0;
    }

    if (cr < 0 || cg < 0 || cb < 0) return -1;
    if (cr *cg*cb == 0 && cr+cg+cb>0) return -1;
//    NSLog(@"%i", abs(r * r + g * g + b * b - (lastR * lastR + lastG * lastG + lastB * lastB)));
    
    lastR = r;
    lastG = g;
    lastB = b;
    
    if (numIndexes == -1) return (numIndexes = numIndexes + 1);
   

    if ((numIndexes == 0 || isNotIdenticle) && ((lastNormR == cr && lastNormG == cg && lastNormB == cb) || lastNormG == -2)) {
        numIndexes += 3;
        recordedColors = realloc(recordedColors, numIndexes * sizeof(int));
        recordedColors[numIndexes - 3] = cr;
        recordedColors[numIndexes - 2] = cg;
        recordedColors[numIndexes - 1] = cb;
    }
    
    lastNormR = cr;
    lastNormG = cg;
    lastNormB = cb;
    return numIndexes;
}

- (void) translateCode {
    NSString * lookUpTable = @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
//    for (int i = 0; i < numIndexes; i+= 3) {
//        NSLog(@"%i, %i, %i",recordedColors[i], recordedColors[i + 1], recordedColors[i + 2]);
//    }

    NSMutableString * b64 = [NSMutableString stringWithString:@""];
    int startPosition = -1;
    for (int i = 0; i < numIndexes; i+=6){
        if(recordedColors[i] == 0 && recordedColors[i+1]==0 && recordedColors[i+2]==0){
            startPosition = i+3;
            break;
        }
        if(recordedColors[i+3] == 0 && recordedColors[i+4]==0 && recordedColors[i+5]==0){
            startPosition = i+6;
            break;
        }
    }

//    NSLog(@"starting position: %i", startPosition);
    
    for (int i= startPosition; i<numIndexes;i+=6){
        if (recordedColors[i] + recordedColors[i + 1] + recordedColors[i + 2] == 0) {
            recordedColors[i + 2] = recordedColors[i + 2 - 3];
            recordedColors[i + 1] = recordedColors[i + 1 - 3];
            recordedColors[i] = recordedColors[i - 3];
        }

        if (recordedColors[i + 5] + recordedColors[i + 4] + recordedColors[i + 3] == 0) {
            recordedColors[i + 5] = recordedColors[i + 5 - 3];
            recordedColors[i + 4] = recordedColors[i + 4 - 3];
            recordedColors[i + 3] = recordedColors[i + 3 - 3];
        }

        int num = (recordedColors[i + 5] == 138 ? 0 : 1);
        num += 2 * (recordedColors[i + 4] == 138 ? 0 : 1);
        num += 2 * 2 * (recordedColors[i + 3] == 138 ? 0 : 1);

        num += 2 * 2 * 2 * (recordedColors[i + 2] == 138 ? 0 : 1);
        num += 2 * 2 * 2 * 2 * (recordedColors[i + 1] == 138 ? 0 : 1);
        num += 2 * 2 * 2 * 2 * 2 * (recordedColors[i ] == 138 ? 0 : 1);
        
        NSString * character = [lookUpTable substringWithRange:NSMakeRange(num, 1)];
        [b64 appendString:character];
    }
    
    NSUInteger spaceLeft = 4-([b64 length] % 4);
    for(int i =0;i<spaceLeft;i+=1){
        [b64 appendString:@"="];
    }

    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:b64 options:0];
    NSString *decodedString = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];

//    if (![decodedString isEqualToString:@""] || decodedString == nil || decodedString == NULL) {
//        self.detectionDone = [NSString stringWithFormat:@"%@", decodedString];
//    } else {
//        self.detectionDone = @"!___err___!";
//    }
    self.detectionDone = decodedString;
    self.cachedString = decodedString;
    
    //[centralViewController recordingStopped];
}



#pragma mark RosyWriterRenderer

- (BOOL)operatesInPlace
{
	return YES;
}

- (FourCharCode)inputPixelFormat
{
	return kCVPixelFormatType_32BGRA;
}

- (void)prepareForInputWithFormatDescription:(CMFormatDescriptionRef)inputFormatDescription outputRetainedBufferCountHint:(size_t)outputRetainedBufferCountHint
{
	// nothing to do, we are stateless
}

- (void)reset
{
	// nothing to do, we are stateless
//    memset(recordedColors, 0, numRecordedColors * sizeof(recordedColors[0]);
//    numRecordedColors = 0;
    same = 0;
    lastR = -2;
    lastG = - 2;
    lastB = -2;
    lastNormR = -2;
    lastNormG = -2;
    lastNormB = -2;
    recordedColors = realloc(recordedColors, 3 * sizeof(int));
    recordedColors[0] = 2;
    recordedColors[1] = 2;
    recordedColors[2] = 2;
    
    numIndexes = 3;

}

- (CVPixelBufferRef) copyRenderedPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    const int kBytesPerPixel = 4;

    CVPixelBufferLockBaseAddress( pixelBuffer, 0 );

    int bufferWidth = (int)CVPixelBufferGetWidth( pixelBuffer );
    int bufferHeight = (int)CVPixelBufferGetHeight( pixelBuffer );
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow( pixelBuffer );
    uint8_t *baseAddress = CVPixelBufferGetBaseAddress( pixelBuffer );
    int greenAvg = 0;
    int redAvg = 0;
    int blueAvg = 0;
    int ct = 0;
    for ( int row = 0; row < bufferHeight; row++ )
    {
        uint8_t * pixel = baseAddress + row * bytesPerRow;
        for ( int column = 0; column < bufferWidth; column++) {
      
    //            if (abs(row - bufferHeight/2) < rect_space && abs(column - bufferWidth/2) < rect_space) {
            blueAvg += pixel[0]; // De-green (second pixel in BGRA is green)
            greenAvg += pixel[1]; // De-green (second pixel in BGRA is green)
            redAvg += pixel[2]; // De-green (second pixel in BGRA is green)
            ct++;
    //            }
            
            pixel += kBytesPerPixel;
        }
    }

    if (ct == 0) return (CVPixelBufferRef)CFRetain( pixelBuffer );
    blueAvg /= ct;
    redAvg /= ct;
    greenAvg /= ct;
    if (recordState == 1) {
        int q = addToRecordedColors(redAvg, greenAvg, blueAvg);
        if (q == -99) {
            [self setState:0];
            [self translateCode];
            //[centralViewController recordingStopped];
        }
    }

    for (int row = 0; row < bufferHeight; row++) {
        uint8_t * pixel = baseAddress + row * bytesPerRow;
        for ( int column = 0; column < bufferWidth; column++ ) {
            if (recordState == 1) {
                pixel[0] = (uint8_t) recordedColors[numIndexes - 1]; // De-green (second pixel in BGRA is green)
                pixel[1] = (uint8_t) recordedColors[numIndexes - 2]; // De-green (second pixel in BGRA is green)
                pixel[2] = (uint8_t) recordedColors[numIndexes - 3]; // De-green (second pixel in BGRA is green)
            } else {
                pixel[0] = (uint8_t) blueAvg; // De-green (second pixel in BGRA is green)
                pixel[1] = (uint8_t) greenAvg; // De-green (second pixel in BGRA is green)
                pixel[2] = (uint8_t) redAvg; // De-green (second pixel in BGRA is green)
            }

            pixel += kBytesPerPixel;
        }
    }

    CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
	return (CVPixelBufferRef)CFRetain( pixelBuffer );
}

@end
