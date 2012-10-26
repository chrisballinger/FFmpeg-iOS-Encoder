//
//  FFAudioEncoder.m
//  RosyWriter
//
//  Created by Christopher Ballinger on 10/25/12.
//
//

#import "FFAudioEncoder.h"
#include <libavutil/audioconvert.h>

@implementation FFAudioEncoder

/* check that a given sample format is supported by the encoder */
static int check_sample_fmt(AVCodec *codec, enum AVSampleFormat sample_fmt)
{
    const enum AVSampleFormat *p = codec->sample_fmts;
    
    while (*p != AV_SAMPLE_FMT_NONE) {
        if (*p == sample_fmt)
            return 1;
        p++;
    }
    return 0;
}

/* just pick the highest supported samplerate */
static int select_sample_rate(AVCodec *codec)
{
    const int *p;
    int best_samplerate = 0;
    
    if (!codec->supported_samplerates)
        return 44100;
    
    p = codec->supported_samplerates;
    while (*p) {
        best_samplerate = FFMAX(*p, best_samplerate);
        p++;
    }
    return best_samplerate;
}

/* select layout with the highest channel count */
static int select_channel_layout(AVCodec *codec)
{
    const uint64_t *p;
    uint64_t best_ch_layout = 0;
    int best_nb_channells   = 0;
    
    if (!codec->channel_layouts)
        return AV_CH_LAYOUT_STEREO;
    
    p = codec->channel_layouts;
    while (*p) {
        int nb_channels = av_get_channel_layout_nb_channels(*p);
        
        if (nb_channels > best_nb_channells) {
            best_ch_layout    = *p;
            best_nb_channells = nb_channels;
        }
        p++;
    }
    return best_ch_layout;
}


- (void) setupEncoderWithFormatDescription:(CMFormatDescriptionRef)newFormatDescription {
    c = NULL;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    NSString *movieName = [NSString stringWithFormat:@"%f.mp2",[[NSDate date] timeIntervalSince1970]];
    const char *filename = [[NSString stringWithFormat:@"%@/%@", basePath, movieName] UTF8String];
    
    printf("Encode audio file %s\n", filename);
    
    /* find the MP2 encoder */
    codec = avcodec_find_encoder(AV_CODEC_ID_MP2);
    if (!codec) {
        fprintf(stderr, "Codec not found\n");
        exit(1);
    }
    
    c = avcodec_alloc_context3(codec);
    
    /* put sample parameters */
    c->bit_rate = 64000;
    
    /* check that the encoder supports s16 pcm input */
    c->sample_fmt = AV_SAMPLE_FMT_S16;
    if (!check_sample_fmt(codec, c->sample_fmt)) {
        fprintf(stderr, "Encoder does not support sample format %s",
                av_get_sample_fmt_name(c->sample_fmt));
        exit(1);
    }
    
    /* select other audio parameters supported by the encoder */
    //c->sample_rate    = select_sample_rate(codec);
    c->sample_rate = 48000;
    //c->channel_layout = select_channel_layout(codec);
    c->channel_layout = AV_CH_LAYOUT_MONO;
    c->channels       = av_get_channel_layout_nb_channels(c->channel_layout);
    
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
    
    /* frame containing input raw audio */
    frame = avcodec_alloc_frame();
    if (!frame) {
        fprintf(stderr, "Could not allocate audio frame\n");
        exit(1);
    }
    
    frame->nb_samples     = c->frame_size;
    frame->format         = c->sample_fmt;
    frame->channel_layout = c->channel_layout;
    
    /* the codec gives us the frame size, in samples,
     * we calculate the size of the samples buffer in bytes */
    buffer_size = av_samples_get_buffer_size(NULL, c->channels, c->frame_size,
                                             c->sample_fmt, 0);
    samples = av_malloc(buffer_size);
    if (!samples) {
        fprintf(stderr, "Could not allocate %d bytes for samples buffer\n",
                buffer_size);
        exit(1);
    }
    /* setup the data pointers in the AVFrame */
    ret = avcodec_fill_audio_frame(frame, c->channels, c->sample_fmt,
                                   (const uint8_t*)samples, buffer_size, 0);
    if (ret < 0) {
        fprintf(stderr, "Could not setup audio frame\n");
        exit(1);
    }
    [super setupEncoderWithFormatDescription:newFormatDescription];
}
- (void) finishEncoding {
    /* get the delayed frames */
    int i = 0;
    for (got_output = 1; got_output; i++) {
        ret = avcodec_encode_audio2(c, &pkt, NULL, &got_output);
        if (ret < 0) {
            fprintf(stderr, "Error encoding frame\n");
            exit(1);
        }
        
        if (got_output) {
            fwrite(pkt.data, 1, pkt.size, f);
            av_free_packet(&pkt);
        }
    }
    fclose(f);
    
    av_freep(&samples);
    avcodec_free_frame(&frame);
    avcodec_close(c);
    av_free(c);
    [super finishEncoding];
}
- (void) encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    // NSLog(@"%@",ref);
    //copy data to file
    //read next one
    AudioBufferList audioBufferList;
    CMBlockBufferRef blockBuffer;
    CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, NULL, &audioBufferList, sizeof(audioBufferList), NULL, NULL, 0, &blockBuffer);
    // NSLog(@"%@",blockBuffer);
    
    for( int y=0; y<audioBufferList.mNumberBuffers; y++ )
    {
        AudioBuffer audioBuffer = audioBufferList.mBuffers[y];
        UInt32 mNumberChannels = audioBuffer.mNumberChannels;
        UInt32 mDataByteSize = audioBuffer.mDataByteSize;
        
        //[data appendBytes:audio_frame length:audioBuffer.mDataByteSize];
        
        av_init_packet(&pkt);
        pkt.data = NULL; // packet data will be allocated by the encoder
        pkt.size = 0;
        
        int bufferSize = audioBuffer.mDataByteSize / sizeof(Float32);
        int frameSize = c->frame_size;
        Float32 *audio_frame = audioBuffer.mData;
        for( int i=0; i<bufferSize; i++ ) {
            Float32 currentSample = (Float32)audio_frame[i];
            samples[i] =  currentSample;
        }
        
        /* encode the samples */
        ret = avcodec_encode_audio2(c, &pkt, frame, &got_output);
        if (ret < 0) {
            fprintf(stderr, "Error encoding audio frame\n");
            exit(1);
        }
        if (got_output) {
            fwrite(pkt.data, 1, pkt.size, f);
            av_free_packet(&pkt);
        }
        
    }
    CFRelease(blockBuffer);
}

@end
