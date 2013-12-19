//
//  AACEncoder.m
//  FFmpegEncoder
//
//  Created by Christopher Ballinger on 12/18/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//
//  http://stackoverflow.com/questions/10817036/can-i-use-avcapturesession-to-encode-an-aac-stream-to-memory

#import "AACEncoder.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface AACEncoder()
@property (nonatomic) AudioConverterRef audioConverter;
@property (nonatomic) uint8_t *aacBuffer;
@property (nonatomic) NSUInteger aacBufferSize;
@property (nonatomic) char *pcmBuffer;
@property (nonatomic) size_t pcmBufferSize;

@end

@implementation AACEncoder

- (void) dealloc {
    AudioConverterDispose(_audioConverter);
}

- (id) init {
    if (self = [super init]) {
        _encoderQueue = dispatch_queue_create("AAC Encoder Queue", DISPATCH_QUEUE_SERIAL);
        _callbackQueue = dispatch_get_main_queue();
        _audioConverter = NULL;
        _pcmBufferSize = 0;
        _pcmBuffer = NULL;
        _aacBufferSize = 1024;
        _aacBuffer = malloc(_aacBufferSize * sizeof(char));
        memset(_aacBuffer, 0, _aacBufferSize);
    }
    return self;
}

- (void) setupEncoderFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    AudioStreamBasicDescription inAudioStreamBasicDescription = *CMAudioFormatDescriptionGetStreamBasicDescription((CMAudioFormatDescriptionRef)CMSampleBufferGetFormatDescription(sampleBuffer));
    
    AudioStreamBasicDescription outAudioStreamBasicDescription = {0}; // Always initialize the fields of a new audio stream basic description structure to zero, as shown here: ...
    outAudioStreamBasicDescription.mSampleRate = inAudioStreamBasicDescription.mSampleRate; // The number of frames per second of the data in the stream, when the stream is played at normal speed. For compressed formats, this field indicates the number of frames per second of equivalent decompressed data. The mSampleRate field must be nonzero, except when this structure is used in a listing of supported formats (see “kAudioStreamAnyRate”).
    outAudioStreamBasicDescription.mFormatID = kAudioFormatMPEG4AAC; // kAudioFormatMPEG4AAC_HE does not work. Can't find `AudioClassDescription`. `mFormatFlags` is set to 0.
    outAudioStreamBasicDescription.mFormatFlags = kMPEG4Object_AAC_LC; // Format-specific flags to specify details of the format. Set to 0 to indicate no format flags. See “Audio Data Format Identifiers” for the flags that apply to each format.
    outAudioStreamBasicDescription.mBytesPerPacket = 0; // The number of bytes in a packet of audio data. To indicate variable packet size, set this field to 0. For a format that uses variable packet size, specify the size of each packet using an AudioStreamPacketDescription structure.
    outAudioStreamBasicDescription.mFramesPerPacket = 1024; // The number of frames in a packet of audio data. For uncompressed audio, the value is 1. For variable bit-rate formats, the value is a larger fixed number, such as 1024 for AAC. For formats with a variable number of frames per packet, such as Ogg Vorbis, set this field to 0.
    outAudioStreamBasicDescription.mBytesPerFrame = 0; // The number of bytes from the start of one frame to the start of the next frame in an audio buffer. Set this field to 0 for compressed formats. ...
    outAudioStreamBasicDescription.mChannelsPerFrame = 1; // The number of channels in each frame of audio data. This value must be nonzero.
    outAudioStreamBasicDescription.mBitsPerChannel = 0; // ... Set this field to 0 for compressed formats.
    outAudioStreamBasicDescription.mReserved = 0; // Pads the structure out to force an even 8-byte alignment. Must be set to 0.
    AudioClassDescription *description = [self
                                          getAudioClassDescriptionWithType:kAudioFormatMPEG4AAC
                                          fromManufacturer:kAppleSoftwareAudioCodecManufacturer];

    OSStatus status = AudioConverterNewSpecific(&inAudioStreamBasicDescription, &outAudioStreamBasicDescription, 1, description, &_audioConverter);
    if (status != 0) {
        NSLog(@"setup converter: %d", (int)status);
    }
}

- (AudioClassDescription *)getAudioClassDescriptionWithType:(UInt32)type
                                           fromManufacturer:(UInt32)manufacturer
{
    static AudioClassDescription desc;
    
    UInt32 encoderSpecifier = type;
    OSStatus st;
    
    UInt32 size;
    st = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders,
                                    sizeof(encoderSpecifier),
                                    &encoderSpecifier,
                                    &size);
    if (st) {
        NSLog(@"error getting audio format propery info: %d", (int)(st));
        return nil;
    }
    
    unsigned int count = size / sizeof(AudioClassDescription);
    AudioClassDescription descriptions[count];
    st = AudioFormatGetProperty(kAudioFormatProperty_Encoders,
                                sizeof(encoderSpecifier),
                                &encoderSpecifier,
                                &size,
                                descriptions);
    if (st) {
        NSLog(@"error getting audio format propery: %d", (int)(st));
        return nil;
    }
    
    for (unsigned int i = 0; i < count; i++) {
        if ((type == descriptions[i].mSubType) &&
            (manufacturer == descriptions[i].mManufacturer)) {
            memcpy(&desc, &(descriptions[i]), sizeof(desc));
            return &desc;
        }
    }
    
    return nil;
}

static OSStatus inInputDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{
    AACEncoder *encoder = (__bridge AACEncoder *)(inUserData);
    //NSLog(@"Number of packets requested: %d", (unsigned int)(*ioNumberDataPackets));
    [encoder copyPCMSamplesIntoBuffer:ioData];
    return noErr;
}

- (void) copyPCMSamplesIntoBuffer:(AudioBufferList*)ioData {
    if (!_pcmBufferSize) {
        NSLog(@"PCM buffer is empty!");
        return;
    }
    ioData->mBuffers[0].mData = _pcmBuffer;
    ioData->mBuffers[0].mDataByteSize = _pcmBufferSize;
    NSLog(@"Copied %zu samples into ioData", _pcmBufferSize);
    _pcmBuffer = NULL;
    _pcmBufferSize = 0;
}


- (void) encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer completionBlock:(void (^)(NSData * encodedData, NSError* error))completionBlock {
    CFRetain(sampleBuffer);
    dispatch_async(_encoderQueue, ^{
        if (!_audioConverter) {
            [self setupEncoderFromSampleBuffer:sampleBuffer];
        }
        CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
        CFRetain(blockBuffer);
        OSStatus status = CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &_pcmBufferSize, &_pcmBuffer);
        NSError *error = nil;
        if (status != kCMBlockBufferNoErr) {
            error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        }
        NSLog(@"PCM Buffer Size: %zu", _pcmBufferSize);
        
        memset(_aacBuffer, 0, _aacBufferSize);
        AudioBufferList outAudioBufferList = {0};
        outAudioBufferList.mNumberBuffers = 1;
        outAudioBufferList.mBuffers[0].mNumberChannels = 1;
        outAudioBufferList.mBuffers[0].mDataByteSize = _aacBufferSize;
        outAudioBufferList.mBuffers[0].mData = _aacBuffer;
        UInt32 ioOutputDataPacketSize = 1;
        status = AudioConverterFillComplexBuffer(_audioConverter, inInputDataProc, (__bridge void *)(self), &ioOutputDataPacketSize, &outAudioBufferList, NULL);
        NSLog(@"ioOutputDataPacketSize: %d", (unsigned int)ioOutputDataPacketSize);
        NSData *data = nil;
        if (status == 0) {
            data = [NSData dataWithBytes:outAudioBufferList.mBuffers[0].mData length:outAudioBufferList.mBuffers[0].mDataByteSize];
        } else {
            error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        }
        if (completionBlock) {
            dispatch_async(_callbackQueue, ^{
                completionBlock(data, error);
            });
        }
        CFRelease(sampleBuffer);
        CFRelease(blockBuffer);
   });
}


@end
