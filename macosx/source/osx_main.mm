// Code taken and modified from:
// https://medium.com/@theobendixson/handmade-hero-osx-platform-layer-day-1-9348559e9211

#include "main.h"
#include "clock.cpp"

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

// TODO(ted): Requires global framebuffer and keyboard.
#include "window.mm"

// TODO(ted): Requires global game object. Pass it in as 'user_data'.
#include "sound.cpp"

// TODO(ted): Requires global game object.
#include "hotloader.cpp"



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
        HandleEvents(keyboard);
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