// Code taken and modified from:
// https://medium.com/@theobendixson/handmade-hero-osx-platform-layer-day-1-9348559e9211

#include "main.h"
#include "clock.cpp"
#include "window.mm"

#include <fcntl.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include <dlfcn.h>

#include <AppKit/AppKit.h>
#include <CoreServices/CoreServices.h>
#include <mach-o/dyld.h>



// Memory
#define KILOBYTES(x) (         (x) * 1024)
#define MEGABYTES(x) (KILOBYTES(x) * 1024)
#define GIGABYTES(x) (GIGABYTES(x) * 1024)

// NOTE(ted): Mac OSX uses bottom-up coordinate system.

struct Game
{
    UpdateFunction update;
    SoundFunction  sound;
};
static Game game;
static Memory memory;

static bool running = true;
static FrameBuffer framebuffer;
static Key key;




void ResizeBuffer(NSWindow* window, FrameBuffer& framebuffer)
{
    // TODO(ted): I see no need to deallocate if the buffer gets smaller, as memory is cheap.
    if (framebuffer.pixels)
    {
        free(framebuffer.pixels);
    }

    framebuffer.width  = window.contentView.bounds.size.width;
    framebuffer.height = window.contentView.bounds.size.height;
    framebuffer.pixels = static_cast<Pixel*>(malloc(framebuffer.width * framebuffer.height * sizeof(Pixel)));
}


void DrawBufferToWindow(NSWindow* window, FrameBuffer& framebuffer)
{
    ASSERT(sizeof(Pixel) == 4, "sizeof(Pixel) is %lu\n", sizeof(Pixel));

    uint8_t* data = reinterpret_cast<uint8_t*>(framebuffer.pixels);

    NSBitmapImageRep* representation = [
            [NSBitmapImageRep alloc]
            initWithBitmapDataPlanes: &data
                          pixelsWide: framebuffer.width
                          pixelsHigh: framebuffer.height
                       bitsPerSample: 8              // Amount of bits for one channel in one pixel.
                     samplesPerPixel: 4              // Amount of channels.
                            hasAlpha: YES
                            isPlanar: NO             // Single buffer to represent the entire image (mixed mode).
                      colorSpaceName: NSDeviceRGBColorSpace
                         bytesPerRow: framebuffer.width * sizeof(Pixel)
                        bitsPerPixel: 32
    ];

    NSSize   size  = NSMakeSize(framebuffer.width, framebuffer.height);
    NSImage* image = [[NSImage alloc] initWithSize: size];
    [image addRepresentation: representation];
    window.contentView.layer.contents = image;

    // TODO(ted): Pre-allocate these.
    [representation release];
    [image release];
}


void HandleEvents()
{
    NSCAssert([NSThread isMainThread], @"Processing Application events must occur on main thread.");

    while (NSEvent* event = [NSApp nextEventMatchingMask: NSEventMaskAny
                                   untilDate: nil
                                      inMode: NSDefaultRunLoopMode
                                     dequeue: YES])
    {

        // https://developer.apple.com/documentation/appkit/nsevent/eventtype
        switch ([event type])
        {
            case NSEventTypeKeyDown:
                if ([event.characters isEqualToString:@"a"])
                    NSLog(@"Pressed a");
                else if ([event.characters isEqualToString:@"d"])
                    NSLog(@"Pressed d");
                else if ([event.characters isEqualToString:@"w"])
                    NSLog(@"Pressed w");
                else if ([event.characters isEqualToString:@"s"])
                    NSLog(@"Pressed s");
                if (event.keyCode == 53)  // Escape
                    running = false;
            case NSEventTypeLeftMouseDown:
                break;

        }

        // Dispatch to window.
        [NSApp sendEvent: event];
    }
}

void* LoadDLLFunction(void* dll, const char* name)
{
    void* function = dlsym(dll, name);
    if (!function)
        printf("Couldn't load function '%s'. %s\n", name, dlerror());
    return function;
}

Game TryLoadGame(const char* path)
{
    static void* dll_handle = nullptr;

    if (dll_handle)
        ASSERT(dlclose(dll_handle), "Couldn't close dll. %s\n", dlerror());


    dll_handle = dlopen(path, RTLD_LOCAL|RTLD_LAZY);
    ASSERT(dll_handle, "Couldn't load dll. %s\n", dlerror());

    game.update = reinterpret_cast<UpdateFunction>(LoadDLLFunction(dll_handle, "Update"));
    if (!game.update)
        game.update = DEFAULT_Update;

    game.sound = reinterpret_cast<SoundFunction>(LoadDLLFunction(dll_handle, "Sound"));
    if (!game.sound)
        game.sound = DEFAULT_Sound;

    return game;
}


struct FileEventMonitor
{
    int queue;
    int file;
};

FileEventMonitor CreateMonitor(const char* path)
{
    int event_queue_handle = kqueue();
    if (event_queue_handle == -1)
        ERROR("Couldn't create event queue.\n");

    int file_handle = open(path, O_EVTONLY);
    if (file_handle == -1)
        ERROR("Couldn't open %s'.\n", path);

    FileEventMonitor result;
    result.queue = event_queue_handle;
    result.file  = file_handle;
    return result;
}


bool CheckForFileEvents(FileEventMonitor monitor)
{
    struct kevent change;
    int filter  = EVFILT_VNODE;
    int flags   = EV_ADD | EV_CLEAR;
    int fflags  = NOTE_DELETE | NOTE_WRITE | NOTE_EXTEND | NOTE_ATTRIB | NOTE_LINK | NOTE_RENAME | NOTE_REVOKE;
    int data    = 0;
    void* udata = 0;
    EV_SET(&change, monitor.file, filter, flags, fflags, data, udata);

    int change_array_count = 1;
    int event_array_count  = 1;
    struct timespec timeout;
    timeout.tv_sec  = 0;  // Seconds to wait.
    timeout.tv_nsec = 0;  // Nanoseconds to wait.
    struct kevent event;
    int error_code = kevent(monitor.queue, &change, change_array_count, &event, event_array_count, &timeout);

    if (error_code == -1)
    {
        ERROR("Error fetching event!\n");
        return false;
    }
    else if (error_code > 0)
    {
        if (event.fflags & NOTE_DELETE)
            return true;
        if (event.fflags & NOTE_WRITE)
            return true;
        if (event.fflags & NOTE_EXTEND)
            return true;
        if (event.fflags & NOTE_ATTRIB)
            return true;
        if (event.fflags & NOTE_LINK)
            return true;
        if (event.fflags & NOTE_RENAME)
            return true;
        if (event.fflags & NOTE_REVOKE)
            return true;
    }
    return false;
}



// ---- AUDIO START -----
#include <AudioToolbox/AudioToolbox.h>
#include <AVFoundation/AVFoundation.h>

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

    for (u8 buffer_index = 0; buffer_index < 2; ++buffer_index)
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


const char* GetDLLByExecutable(const char* name)
{
    u16 dll_name_size = strlen(name) + 1;
    u16 max_size = MAXPATHLEN + dll_name_size;

    char* path = cast(malloc(max_size), char*);  // +1 null, +1 delimiter

    u32 size  = MAXPATHLEN;
    s32 error = _NSGetExecutablePath(path, &size);
    ASSERT(error != -1, "Buffer too small. %u bytes required, %u given.\n", size, MAXPATHLEN);
    u32 actual_size = strlen(path) + 1;

    u16 last_parenthesis = 0;
    for (u16 i = actual_size; i > 0; --i)  // NOTE(ted): Beware of underflow.
    {
        if (path[i] == '/')
        {
            last_parenthesis = i;
            break;
        }
    }

    u16 x = last_parenthesis == 0 ? 0 : 1;

    for (u16 i = 0; i < dll_name_size; ++i)
        path[last_parenthesis + i + x] = name[i];

    return path;
}



// ---- AUDIO END -----

int main(int argc, char* argv[])
{
    {
        u64 total_size = KILOBYTES(1);
        void* raw_memory = malloc(total_size);

        Buffer persistent;
        persistent.size = total_size / 2;
        persistent.used = 0;
        persistent.data = raw_memory;

        Buffer temporary;
        temporary.size = total_size / 2;
        temporary.used = 0;
        temporary.data = static_cast<char*>(raw_memory) + persistent.size;

        memory.initialized = false;
        memory.persistent  = persistent;
        memory.temporary   = temporary;
    }

    const char* dll_path = GetDLLByExecutable("libGame.A.dylib");

    FileEventMonitor dll_monitor = CreateMonitor(dll_path);
    if (!dll_monitor.queue)
        return 1;

    game = TryLoadGame(dll_path);

    // ---- WINDOW START ----
    static int DEFAULT_WIDTH  = 512;
    static int DEFAULT_HEIGHT = 512;

    InitializeWindow();
    NSWindow* window = CreateWindow(DEFAULT_WIDTH, DEFAULT_HEIGHT);
    // ---- WINDOW END ----
    // ---- AUDIO START -----
    AudioQueueRef audio_queue = SetupAudioQueue();
    // ---- AUDIO END -----

    ResizeBuffer(window, framebuffer);

    NanoClock clock;
    NanoClock frame_clock;

    int frames = 0;
    while (running)
    {
        // ---- FRAME COUNT ----
        if (Timer(frame_clock, SECONDS_TO_NANO(1)))
        {
            NSLog(@"Frames: %i", frames);
            frames = 0;
        }
        ++frames;

        // ---- SLEEP ----
        uint64_t delta = Tick(clock, MILLI_TO_NANO(32));

        // ---- EVENTS ----
        HandleEvents();
        if (CheckForFileEvents(dll_monitor))
        {
            game = TryLoadGame(dll_path);
            dll_monitor = CreateMonitor(dll_path);
        }

        // ---- UPDATE ----
        // static f32 volume = 0;
        // OSStatus error = AudioQueueSetParameter(audio_queue, kAudioQueueParam_Volume, volume);
        // volume += 0.05f;
        // if (error != noErr)
        // {
        //     printf("Couldn't change Audio Queue parameter. Error: %i\n", error);
        //     exit(1);
        // }

        // ---- RENDERING ----
        game.update(memory, framebuffer, key);
        DrawBufferToWindow(window, framebuffer);
    }

}