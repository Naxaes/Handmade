// Code taken and modified from:
// https://medium.com/@theobendixson/handmade-hero-osx-platform-layer-day-1-9348559e9211

#include "main.h"
#include "clock.cpp"
#include "window.mm"

// Declared in main.h
// #include <stdlib.h>
// #include <stdio.h>
// #include <errno.h>


// #include <fcntl.h>
// #include <unistd.h>



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
static KeyBoard keyboard;

// TODO(ted): Requires global game object. Pass it in as 'user_data'.
#include "sound.cpp"
#include "hotloader.cpp"


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
                {
                    Key& key = keyboard.keys[keyboard.used++];
                    key.character     = 'a';
                    key.transitions   = 0;
                    key.ended_on_down = true;
                }
                else if ([event.characters isEqualToString:@"d"])
                {
                    Key& key = keyboard.keys[keyboard.used++];
                    key.character     = 'd';
                    key.transitions   = 0;
                    key.ended_on_down = true;
                }
                else if ([event.characters isEqualToString:@"w"])
                {
                    Key& key = keyboard.keys[keyboard.used++];
                    key.character     = 'w';
                    key.transitions   = 0;
                    key.ended_on_down = true;
                }
                else if ([event.characters isEqualToString:@"s"])
                {
                    Key& key = keyboard.keys[keyboard.used++];
                    key.character     = 's';
                    key.transitions   = 0;
                    key.ended_on_down = true;
                }
                if (event.keyCode == 53)  // Escape
                {
                    running = false;
                }
                break;
            default:
                // Dispatch to window.
                [NSApp sendEvent: event];
        }
    }
}

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
        keyboard.used = 0;

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
        game.update(memory, framebuffer, keyboard);
        DrawBufferToWindow(window, framebuffer);
    }

}