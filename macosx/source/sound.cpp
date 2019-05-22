#include <AudioToolbox/AudioToolbox.h>
#include <AVFoundation/AVFoundation.h>


// https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/WhatisCoreAudio/WhatisCoreAudio.html
// A sample -
//      is single numerical value for a single channel.
// A frame -
//      is a collection of time-coincident samples. For instance, a stereo sound file has two
//      samples per frame, one for the left channel and one for the right channel.
// A packet -
//      is a collection of one or more contiguous frames. In linear PCM audio, a packet is always
//      a single frame. In compressed formats, it is typically more. A packet defines the smallest
//      meaningful set of frames for a given audio data format.


// Will be called whenever the audio queue needs more data.
// https://developer.apple.com/documentation/audiotoolbox/audioqueueoutputcallback
void AudioQueueCallback(void* user_data, AudioQueueRef audio_queue, AudioQueueBufferRef buffer)
{
    // https://developer.apple.com/documentation/audiotoolbox/audioqueuebuffer
    // AudioQueueBuffer

    // static NanoClock clock;
    // u64 duration = Tick(clock);
    // NSLog(@"Audio Callback time: %f | Samples: %u", NANO_TO_SECONDS(cast(duration, f64)), bytes);

    static f32 theta = 0;
    static f32 alpha = 0;

    s16* data  = cast(buffer->mAudioData, s16*);
    u32  bytes = buffer->mAudioDataBytesCapacity;

    SoundBuffer sound;
    sound.size = bytes;
    sound.data = data;

    game.sound(memory, sound);

    // mAudioDataByteSize must be set.
    buffer->mAudioDataByteSize = bytes;

    // https://developer.apple.com/documentation/audiotoolbox/1502779-audioqueueenqueuebuffer
    // AudioQueueEnqueueBuffer -> error code
    //     - audio queue
    //     - buffer
    //     - number of packets of audio data in buffer
    //     - an array of packet descriptions
    OSStatus error = AudioQueueEnqueueBuffer(audio_queue, buffer, 0, NULL);
    ASSERT(error == noErr, "Couldn't enqueue Audio Buffer. Error code %i.\n", error);
}


AudioQueueRef SetupAudioQueue()
{
    // https://developer.apple.com/documentation/audiotoolbox/audio_queue_services#1651699
    OSStatus error = noErr;

    // https://developer.apple.com/documentation/coreaudio/audiostreambasicdescription
    // Setup the audio device.
    AudioStreamBasicDescription audio_format = {0};
    audio_format.mSampleRate       = 44100;            // Should be named 'Frame rate'.
    audio_format.mFormatID         = kAudioFormatLinearPCM;
    audio_format.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger;
    audio_format.mBytesPerPacket   = 4;
    audio_format.mFramesPerPacket  = 1;
    audio_format.mBytesPerFrame    = 4;
    audio_format.mChannelsPerFrame = 2;
    audio_format.mBitsPerChannel   = 16;
    audio_format.mReserved         = 0;  // Must be set to 0.


    // https://developer.apple.com/documentation/audiotoolbox/1503207-audioqueuenewoutput
    // AudioQueueNewOutput -> error code
    //    - format
    //    - callback
    //    - user data
    //    - callback run loop
    //    - callback run loop mode
    //    - flags (must be 0)
    //    - audio queue (output parameter)
    //

    // Create a new output AudioQueue for the device.
    AudioQueueRef audio_queue;
    error = AudioQueueNewOutput(&audio_format, AudioQueueCallback, NULL,
                                CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &audio_queue);
    ASSERT(error == noErr, "Couldn't create Audio Queue. Error code %i.\n", error);

    // https://developer.apple.com/documentation/audiotoolbox/1502248-audioqueueallocatebuffer
    // AudioQueueAllocateBuffer -> error code
    //     - audio queue
    //     - capacity (in bytes)
    //     - buffer (output parameter

    for (u8 buffer_index = 0; buffer_index < 3; ++buffer_index)
    {
        AudioQueueBufferRef buffer;
        error = AudioQueueAllocateBuffer(audio_queue, KILOBYTES(16), &buffer);
        ASSERT(error == noErr, "Couldn't create Audio Buffer. Error code %i.\n", error);

        // Fill the audio queue buffer.
        // AudioQueueCallback(NULL, audio_queue, buffer);
        AudioQueueCallback(NULL, audio_queue, buffer);
    }


    // https://developer.apple.com/documentation/audiotoolbox/1502689-audioqueuestart
    // AudioQueueStart -> error code
    //     - audio queue
    //     - time to start (AudioTimeStamp)
    error = AudioQueueStart(audio_queue, NULL);
    ASSERT(error == noErr, "Couldn't start Audio Queue. Error code %i.\n", error);

    return audio_queue;
}
