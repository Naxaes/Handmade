// Code taken and modified from:
// https://medium.com/@theobendixson/handmade-hero-osx-platform-layer-day-1-9348559e9211

#include "main.h"
#include "clock.cpp"

// Declared in main.h
// #include <stdlib.h>
// #include <stdio.h>
// #include <errno.h>


// https://clang.llvm.org/docs/LanguageExtensions.html#introduction



// Memory
#define KILOBYTES(x) (         (x) * 1024ULL)
#define MEGABYTES(x) (KILOBYTES(x) * 1024ULL)
#define GIGABYTES(x) (MEGABYTES(x) * 1024ULL)
#define TERABYTES(x) (GIGABYTES(x) * 1024ULL)

// NOTE(ted): Mac OSX uses bottom-up coordinate system.

struct Game
{
    InitializeFunction initialize;
    UpdateFunction     update;
    SoundFunction      sound;
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




void BubbleSort(u64* array, u64 count)
{
    for (u64 i = 0; i < count; ++i)
    {
        for (u64 j = i+1; j < count; ++j)
        {
            if (array[i] > array[j])
            {
                u64 temp = array[i];
                array[i] = array[j];
                array[j] = temp;
            }
        }
    }
}


// https://developer.apple.com/library/archive/documentation/Performance/Conceptual/ManagingMemory/Articles/MemoryAlloc.html#//apple_ref/doc/uid/20001881-CJBCFDGA
u8* AllocateVirtualMemory(vm_offset_t size)
{
    // In debug builds, check that we have
    // correct VM page alignment
    ASSERT(size != 0, "Cannot allocate 0 bytes.\n");
    ASSERT((size % 4096) == 0, "You should allocate so you're page aligned (i.e. allocates a multiple of 4096). Tried allocating %llu bytes.\n", size);

    // https://www.gnu.org/software/hurd/gnumach-doc/Memory-Allocation.html
    vm_address_t  address = TERABYTES(2);
    kern_return_t error   = vm_allocate((vm_map_t) mach_task_self(), &address, size, false);

    if (error != KERN_SUCCESS)
    {
        if (error == KERN_INVALID_ADDRESS)
            ERROR("Address %llu is invalid.\n", address);
        if (error == KERN_NO_SPACE)
            ERROR("Not enough space to allocate %llu bytes at the specified address %llu.\n", size, address);
    }

    memset((u8*)address, 0, size);


    // // Switched to mmap: https://hero.handmade.network/forums/code-discussion/t/134-mac_os_x_vm_allocate_vs_win__virtualalloc
    // u8* address = (u8*)GIGABYTES(8lu); // Make this somewhere above 4GB
    // void* data = mmap(address, size, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_ANON, -1, 0);
    // if (data == MAP_FAILED)
    //     ERROR("'mmap' failed. Error code: %d. Message: %s\n", errno, strerror(errno));

    return (u8*)address;
}

void PrintStatus(u64* frame_time_results, u8 frame_time_result_count,
                 u64* cycle_results,      u8 cycle_result_count,
                 u8   frames)
{
    BubbleSort(frame_time_results, frame_time_result_count);
    BubbleSort(cycle_results,      cycle_result_count);

    u64 i = frame_time_result_count - 1;
    u64 j = cycle_result_count - 1;
    NSLog(@"---- FRAME STATS ----\n"
          "\tFrames per second : %i\n"
          "\tNanos  per frame  : %llu | %llu | %llu | %llu | %llu\n"
          "\tCycles per second : %llu | %llu | %llu | %llu | %llu\n",
          frames,
          frame_time_results[0], frame_time_results[i/4], frame_time_results[i/2], frame_time_results[3*i/4], frame_time_results[i],
          cycle_results[0], cycle_results[j/4], cycle_results[j/2], cycle_results[3*j/4], cycle_results[j]
    );
}


int main(int argc, char* argv[])
{
    {
        // https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/calloc.3.html
        u64 total_size = KILOBYTES(4);
        u8* raw_virtual_memory = AllocateVirtualMemory(total_size);

        Buffer persistent;
        persistent.size = total_size / 2;
        persistent.used = 0;
        persistent.data = raw_virtual_memory;

        Buffer temporary;
        temporary.size = total_size / 2;
        temporary.used = 0;
        temporary.data = raw_virtual_memory + persistent.size;

        memory.persistent  = persistent;
        memory.temporary   = temporary;
        memory.initialized = false;
    }

    const char* dll_path = GetDLLByExecutable("libGame.A.dylib");

    FileEventMonitor dll_monitor = CreateMonitor(dll_path);
    if (!dll_monitor.queue)
        return 1;

    game = TryLoadGame(dll_path);

    game.initialize(memory);

    // ---- WINDOW START ----
    static int DEFAULT_WIDTH  = 512;
    static int DEFAULT_HEIGHT = 512;
    NSWindow* window = CreateWindow(DEFAULT_WIDTH, DEFAULT_HEIGHT);
    ResizeBuffer(window, framebuffer);
    // ---- WINDOW END ----

    // ---- AUDIO START -----
    AudioQueueRef audio_queue = SetupAudioQueue();
    // ---- AUDIO END -----


    NanoClock clock;
    NanoClock frame_clock;

    u8  frame_time_result_count = 0;
    u64 frame_time_results[255];

    u8  cycle_result_count = 0;
    u64 cycle_results[255];

    int frames = 0;
    while (running)
    {
        u64 start = CycleCount();

        keyboard.used = 0;

        // ---- FRAME COUNT ----
        if (Timer(frame_clock, SECONDS_TO_NANO(1)))
        {
            PrintStatus(frame_time_results, frame_time_result_count, cycle_results, cycle_result_count, frames);

            frames = 0;
            cycle_result_count = 0;
            frame_time_result_count = 0;
        }
        ++frames;

        // ---- SLEEP ----
        uint64_t delta = Tick(clock/*, MILLI_TO_NANO(32) */);
        frame_time_results[frame_time_result_count++] = delta;

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

        u64 stop = CycleCount();
        cycle_results[cycle_result_count++] = stop - start;
    }

}