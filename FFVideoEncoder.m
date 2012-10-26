//
//  FFVideoEncoder.m
//  RosyWriter
//
//  Created by Christopher Ballinger on 10/25/12.
//
//

#import "FFVideoEncoder.h"
#include <libavutil/opt.h>
#include <libavutil/audioconvert.h>
#include <libavutil/common.h>
#include <libavutil/imgutils.h>
#include <libavutil/mathematics.h>
#include <libavutil/samplefmt.h>


@implementation FFVideoEncoder

- (void) setupEncoderWithFormatDescription:(CMFormatDescriptionRef)newFormatDescription {
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(newFormatDescription);
    
    c = NULL;
    frameNumber = 0;
    int codec_id = AV_CODEC_ID_MPEG1VIDEO;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    NSString *movieName = [NSString stringWithFormat:@"%f.mpg",[[NSDate date] timeIntervalSince1970]];
    const char *filename = [[NSString stringWithFormat:@"%@/%@", basePath, movieName] UTF8String];
    printf("Encode video file %s\n", filename);
    
    /* find the mpeg1 video encoder */
    codec = avcodec_find_encoder(codec_id);
    if (!codec) {
        fprintf(stderr, "Codec not found\n");
        exit(1);
    }
    
    c = avcodec_alloc_context3(codec);
    
    /* put sample parameters */
    c->bit_rate = 400000;
    /* resolution must be a multiple of two */
    c->width = dimensions.width;
    c->height = dimensions.height;
    /* frames per second */
    c->time_base= (AVRational){1,25};
    c->gop_size = 10; /* emit one intra frame every ten frames */
    c->max_b_frames=1;
    c->pix_fmt = PIX_FMT_YUV420P;
    
    if(codec_id == AV_CODEC_ID_H264)
        av_opt_set(c->priv_data, "preset", "slow", 0);
    
    /* open it */
    if (avcodec_open2(c, codec, NULL) < 0) {
        fprintf(stderr, "Could not open codec\n");
        exit(1);
    }
    
    f = fopen(filename, "wb");
    if (!f) {
        fprintf(stderr, "Could not open %s\n", filename);
        exit(1);
    }
    
    frame = avcodec_alloc_frame();
    if (!frame) {
        fprintf(stderr, "Could not allocate video frame\n");
        exit(1);
    }
    frame->format = c->pix_fmt;
    frame->width  = c->width;
    frame->height = c->height;
    
    /* the image can be allocated by any means and av_image_alloc() is
     * just the most convenient way if av_malloc() is to be used */
    ret = av_image_alloc(frame->data, frame->linesize, c->width, c->height,
                         c->pix_fmt, 32);
    if (ret < 0) {
        fprintf(stderr, "Could not allocate raw picture buffer\n");
        exit(1);
    }
    
    [super setupEncoderWithFormatDescription:newFormatDescription];
}

- (void) finishEncoding {
    uint8_t endcode[] = { 0, 0, 1, 0xb7 };
    
    for (got_output = 1; got_output; frameNumber++) {
        fflush(stdout);
        
        ret = avcodec_encode_video2(c, &pkt, NULL, &got_output);
        if (ret < 0) {
            fprintf(stderr, "Error encoding frame\n");
            exit(1);
        }
        
        if (got_output) {
            printf("Write frame %3d (size=%5d)\n", frameNumber, pkt.size);
            fwrite(pkt.data, 1, pkt.size, f);
            av_free_packet(&pkt);
        }
    }
    
    /* add sequence end code to have a real mpeg file */
    fwrite(endcode, 1, sizeof(endcode), f);
    fclose(f);
    
    avcodec_close(c);
    av_free(c);
    av_freep(&frame->data[0]);
    avcodec_free_frame(&frame);
    printf("\n");
    [super finishEncoding];
}

- (void) encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
    
	int bufferWidth = CVPixelBufferGetWidth(pixelBuffer);
	int bufferHeight = CVPixelBufferGetHeight(pixelBuffer);
	unsigned char *pixel = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);
    
    av_init_packet(&pkt);
    pkt.data = NULL;    // packet data will be allocated by the encoder
    pkt.size = 0;
    
    //unsigned char y_pixel = pixel[0];
    
    
    fflush(stdout);
    for (int y = 0; y < bufferHeight; y++) {
        for (int x = 0; x < bufferWidth; x++) {
            frame->data[0][y * frame->linesize[0] + x] = pixel[0];
            pixel++;
        }
    }
    
    /* Cb and Cr */
    
    for (int y = 0; y < bufferHeight / 2; y++) {
        for (int x = 0; x < bufferWidth / 2; x++) {
            frame->data[1][y * frame->linesize[1] + x] = pixel[0];
            pixel++;
            frame->data[2][y * frame->linesize[2] + x] = pixel[0];
            pixel++;
        }
    }
    
    frame->pts = frameNumber;
    
    /* encode the image */
    ret = avcodec_encode_video2(c, &pkt, frame, &got_output);
    if (ret < 0) {
        fprintf(stderr, "Error encoding frame\n");
        exit(1);
    }
    
    if (got_output) {
        printf("Write frame %3d (size=%5d)\n", frameNumber, pkt.size);
        fwrite(pkt.data, 1, pkt.size, f);
        av_free_packet(&pkt);
    }
    frameNumber++;
    CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
}

@end
