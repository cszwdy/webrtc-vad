//
//  WVAudioSegment.m
//  webrtcvad
//
//  Created by Peiqiang Hao on 2016/11/27.
//  Copyright © 2016年 Peiqiang Hao. All rights reserved.
//

#import "WVAudioSegment.h"
#import "AudioConvert.h"

@implementation WVAudioSegment

+(WVVad *)shardVad {
    
    static WVVad *_vad = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _vad = [[WVVad alloc] init];
    });
    return _vad;
}

void putInVoiceBuffer(void *frame,UInt32 frameSize) {
    
    const UInt32 voiceBufsize = 320;
    static char* voiceBuffer = NULL;
    static UInt32 pos = 0;
    
    if (voiceBuffer == NULL) {
        
        voiceBuffer = malloc(voiceBufsize);
    }
    
    UInt32 framePos = 0;
    static int n = 0;
    while(framePos<frameSize) {
        
        UInt32 size = frameSize-framePos;
        if(pos+size>voiceBufsize) {
            
            size = voiceBufsize - pos;
        }
        
        memcpy(voiceBuffer+pos, frame+framePos, size);
        pos += size;
        framePos += size;
        if(pos >= voiceBufsize) {
            
            WVVad* vad = [WVAudioSegment shardVad];
            int voice;
            voice = [vad isVoice:(const int16_t*)voiceBuffer sample_rate:16000 length:voiceBufsize/2];
            if(voice != 1) {
                NSLog(@"== %2e s",n*10/1000.0);
            }
            pos = 0;
            n++;
        }
    }
}


- (NSArray*)segmentAudio:(NSURL *) fileURL {
    
    NSURL* pcmFileURL = [self cover2PCM16000fromSrcFile:fileURL];
    
    AudioFileID pcmFileID;
    CheckResult (AudioFileOpenURL((__bridge CFURLRef _Nonnull)(pcmFileURL),
                                  kAudioFileReadPermission ,
                                  0,
                                  &pcmFileID),
                 "PcmFileOpenURL failed");
    
    UInt32 pos = 0;
    UInt32 bufferSize = 320;
    char* voiceBuffer = malloc(bufferSize);

    while (1) {
     
        OSStatus status = AudioFileReadBytes(pcmFileID,
                           false,
                           pos,
                           &bufferSize,
                                              voiceBuffer);
        if (status == kAudioFileEndOfFileError || bufferSize==0)
            break;
        
        putInVoiceBuffer(voiceBuffer, bufferSize);
        pos += bufferSize;
    }
    
    return nil;
}

- (NSURL*)cover2PCM16000fromSrcFile:(NSURL*) fileURL {
    
    AudioConverterSettings audioConverterSettings = {0};
    
    CheckResult (AudioFileOpenURL((__bridge CFURLRef _Nonnull)(fileURL), kAudioFileReadPermission , 0, &audioConverterSettings.inputFile),
                 "AudioFileOpenURL failed");
    UInt32 propSize = sizeof(audioConverterSettings.inputFormat);
    CheckResult (AudioFileGetProperty(audioConverterSettings.inputFile, kAudioFilePropertyDataFormat, &propSize, &audioConverterSettings.inputFormat),
                 "couldn't get file's data format");
    
    // get the total number of packets in the file
    propSize = sizeof(audioConverterSettings.inputFilePacketCount);
    CheckResult (AudioFileGetProperty(audioConverterSettings.inputFile, kAudioFilePropertyAudioDataPacketCount, &propSize, &audioConverterSettings.inputFilePacketCount),
                 "couldn't get file's packet count");
    
    // get size of the largest possible packet
    propSize = sizeof(audioConverterSettings.inputFilePacketMaxSize);
    CheckResult(AudioFileGetProperty(audioConverterSettings.inputFile, kAudioFilePropertyMaximumPacketSize, &propSize, &audioConverterSettings.inputFilePacketMaxSize),
                "couldn't get file's max packet size");
    
    audioConverterSettings.outputFormat = [self pcm16000Format];
//    audioConverterSettings.outputFormat.mSampleRate = 16000.0;
//    audioConverterSettings.outputFormat.mFormatID = kAudioFormatLinearPCM;
//    audioConverterSettings.outputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
//    audioConverterSettings.outputFormat.mChannelsPerFrame = 1;
//    audioConverterSettings.outputFormat.mBytesPerPacket = 2*audioConverterSettings.outputFormat.mChannelsPerFrame;
//    audioConverterSettings.outputFormat.mFramesPerPacket = 1;
//    audioConverterSettings.outputFormat.mBytesPerFrame = 2*audioConverterSettings.outputFormat.mChannelsPerFrame;
//    audioConverterSettings.outputFormat.mBitsPerChannel = 16;
    
    NSString *path = [self pathForTemporaryFileWithPrefix:@"PCM16000" andExt:@"caf"];
    NSLog(@"%@",path);
    NSURL *outfileURL = [NSURL URLWithString:path];
    CheckResult (AudioFileCreateWithURL((__bridge CFURLRef _Nonnull)(outfileURL), kAudioFileCAFType, &audioConverterSettings.outputFormat, kAudioFileFlags_EraseFile, &audioConverterSettings.outputFile),
                 "AudioFileCreateWithURL failed");
    
    Convert(&audioConverterSettings);
    AudioFileClose(audioConverterSettings.inputFile);
    AudioFileClose(audioConverterSettings.outputFile);
    return [NSURL URLWithString:path];
}

- (NSString *)pathForTemporaryFileWithPrefix:(NSString *)prefix andExt:(NSString*)ExtName
{
    NSString *  result;
    CFUUIDRef   uuid;
    CFStringRef uuidStr;
    
    uuid = CFUUIDCreate(NULL);
    assert(uuid != NULL);
    
    uuidStr = CFUUIDCreateString(NULL, uuid);
    assert(uuidStr != NULL);
    
    result = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.%@", prefix, uuidStr,ExtName]];
    assert(result != nil);
    
    CFRelease(uuidStr);
    CFRelease(uuid);
    
    return result;
}

- (AudioStreamBasicDescription) pcm16000Format {

    AudioStreamBasicDescription pcm16000Format = {0};
    pcm16000Format.mSampleRate = 16000.0;
    pcm16000Format.mFormatID = kAudioFormatLinearPCM;
    pcm16000Format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    pcm16000Format.mChannelsPerFrame = 1;
    pcm16000Format.mBytesPerPacket = 2 * pcm16000Format.mChannelsPerFrame;
    pcm16000Format.mFramesPerPacket = 1;
    pcm16000Format.mBytesPerFrame = 2 * pcm16000Format.mChannelsPerFrame;
    pcm16000Format.mBitsPerChannel = 16;
    return pcm16000Format;
}


@end
