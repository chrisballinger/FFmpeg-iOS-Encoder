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
#include <libswscale/swscale.h>


@implementation FFVideoEncoder

- (void) setupEncoderWithFormatDescription:(CMFormatDescriptionRef)newFormatDescription {
    CMVideoDimensions dimensions;
    dimensions.width = 320;
    dimensions.height = 240;
    [self setupEncoderWithFormatDescription:newFormatDescription desiredOutputSize:dimensions];
}

- (void) setupEncoderWithFormatDescription:(CMFormatDescriptionRef)newFormatDescription desiredOutputSize:(CMVideoDimensions)desiredOutputSize {
    inputSize = CMVideoFormatDescriptionGetDimensions(newFormatDescription);
    outputSize = desiredOutputSize;
    c = NULL;
    frameNumber = 0;
    int codec_id = AV_CODEC_ID_MPEG4;
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
    c->width = outputSize.width;
    c->height = outputSize.height;
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
    frame->width  = inputSize.width;
    frame->height = inputSize.height;
    
    scaledFrame = avcodec_alloc_frame();
    if (!scaledFrame) {
        fprintf(stderr, "Could not allocate video frame\n");
        exit(1);
    }
    scaledFrame->format = c->pix_fmt;
    scaledFrame->width  = c->width;
    scaledFrame->height = c->height;
    
    /* create scaling context */
    sws_ctx = sws_getContext(inputSize.width, inputSize.height, PIX_FMT_YUV420P, outputSize.width, outputSize.height, PIX_FMT_YUV420P, SWS_BILINEAR, NULL, NULL, NULL);
    if (!sws_ctx) {
        fprintf(stderr,
                "Impossible to create scale context for the conversion "
                "fmt:%s s:%dx%d -> fmt:%s s:%dx%d\n",
                av_get_pix_fmt_name(PIX_FMT_YUV420P), inputSize.width, inputSize.height,
                av_get_pix_fmt_name(PIX_FMT_YUV420P), outputSize.width, outputSize.height);
        ret = AVERROR(EINVAL);
        exit(1);
    }
    
    /* the image can be allocated by any means and av_image_alloc() is
     * just the most convenient way if av_malloc() is to be used */
    ret = av_image_alloc(frame->data, frame->linesize, inputSize.width, inputSize.height,
                         c->pix_fmt, 32);
    if (ret < 0) {
        fprintf(stderr, "Could not allocate raw picture buffer\n");
        exit(1);
    }
    
    /* the image can be allocated by any means and av_image_alloc() is
     * just the most convenient way if av_malloc() is to be used */
    ret = av_image_alloc(scaledFrame->data, scaledFrame->linesize, c->width, c->height,
                         c->pix_fmt, 32);
    if (ret < 0) {
        fprintf(stderr, "Could not allocate raw picture buffer\n");
        exit(1);
    }
    
    [super setupEncoderWithFormatDescription:newFormatDescription];
}

- (void) scaleVideoToOutputSize {
    
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
            //printf("Write frame %3d (size=%5d)\n", frameNumber, pkt.size);
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
    av_freep(&scaledFrame->data[0]);
    avcodec_free_frame(&frame);
    avcodec_free_frame(&scaledFrame);
    sws_freeContext(sws_ctx);
    printf("\n");
    [super finishEncoding];
}

- (void) encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
    
	int bufferWidth = 0;
	int bufferHeight = 0;
	uint8_t *pixel = NULL;
    
    if (CVPixelBufferIsPlanar(pixelBuffer)) {
        //int planeCount = CVPixelBufferGetPlaneCount(pixelBuffer);
        int basePlane = 0;
        pixel = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, basePlane);
        bufferHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, basePlane);
        bufferWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, basePlane);
    } else {
        pixel = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
        bufferWidth = CVPixelBufferGetWidth(pixelBuffer);
        bufferHeight = CVPixelBufferGetHeight(pixelBuffer);
    }
    
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
            frame->data[2][y * frame->linesize[2] + x] = pixel[1];
            pixel+=2;
        }
    }
    
    /* convert to destination format */
    sws_scale(sws_ctx, (const uint8_t * const*)frame->data,
              frame->linesize, 0, inputSize.height, scaledFrame->data, scaledFrame->linesize);
    
    scaledFrame->pts = frameNumber;
    
    /* encode the image */
    ret = avcodec_encode_video2(c, &pkt, scaledFrame, &got_output);
    if (ret < 0) {
        fprintf(stderr, "Error encoding frame\n");
        exit(1);
    }
    
    if (got_output) {
        //printf("Write frame %3d (size=%5d)\n", frameNumber, pkt.size);
        fwrite(pkt.data, 1, pkt.size, f);
        av_free_packet(&pkt);
    }
    frameNumber++;
    CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
}

@end
