// Code taken and modified from:
// https://medium.com/@theobendixson/handmade-hero-osx-platform-layer-day-1-9348559e9211

#include "main.h"
#include "clock.cpp"

// Declared in main.h
// #include <stdlib.h>
// #include <stdio.h>
// #include <errno.h>


// https://clang.llvm.org/docs/LanguageExtensions.html#introduction


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


struct RecordData
{
    u16 current_frame;
    u16 frames_recorded;
    u16 max_frames_to_record;
    KeyBoard* keyboard_data;
};
static RecordData record_data;



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
    ASSERT((size % 4096) == 0, "You should allocate so you're page aligned (i.e. allocates a multiple of 4096). Tried allocating %lu bytes.\n", size);

    // https://www.gnu.org/software/hurd/gnumach-doc/Memory-Allocation.html
    vm_address_t  address = TERABYTES(2);
    kern_return_t error   = vm_allocate((vm_map_t) mach_task_self(), &address, size, false);

    if (error != KERN_SUCCESS)
    {
        if (error == KERN_INVALID_ADDRESS)
            ERROR("Address %lu is invalid.\n", address);
        if (error == KERN_NO_SPACE)
            ERROR("Not enough space to allocate %lu bytes at the specified address %lu.\n", size, address);
    }

    memset((u8*)address, 0, size);


    // mmap: https://hero.handmade.network/forums/code-discussion/t/134-mac_os_x_vm_allocate_vs_win__virtualalloc
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


void SaveGameState(Memory& memory)
{
    static const char* save_path = GetNameByExecutable("game.save");  // LEAK(ted): Making static for now.

    FILE* file = fopen(save_path, "wb");
    if (!file)
    {
        ERROR("Couldn't create save file!\n");
        return;
    }

    u32 elements_written = 0;

    elements_written = fwrite(memory.persistent.data, memory.persistent.size, 1, file);
    if (elements_written == 0)
        ERROR("Couldn't write persistent memory to save file!\n");

    elements_written = fwrite(memory.temporary.data, memory.temporary.size, 1, file);
    if (elements_written == 0)
        ERROR("Couldn't write temporary memory to save file!\n");

    fclose(file);
}

void LoadGameState(Memory& memory)
{
    static const char* save_path = GetNameByExecutable("game.save");  // LEAK(ted): Making static for now.

    FILE* file = fopen(save_path, "rb");
    if (!file)
    {
        ERROR("Couldn't open save file!\n");
        return;
    }

    u32 elements_read = 0;

    elements_read = fread(memory.persistent.data, memory.persistent.size, 1, file);
    if (elements_read == 0)
        ERROR("Couldn't read persistent memory from save file!\n");

    elements_read = fread(memory.temporary.data, memory.temporary.size, 1, file);
    if (elements_read == 0)
        ERROR("Couldn't read temporary memory from save file!\n");

    fclose(file);
}

void StartRecording(Memory& memory)
{
    SaveGameState(memory);
}

void StopRecording(RecordData& record)
{
    if (record_data.current_frame == 0)  // Already stopped.
        return;

    record_data.frames_recorded = record_data.current_frame;
    record_data.current_frame = 0;
}

// Returns true if we're still recording.
bool RecordFrame(Memory& memory, RecordData& record, KeyBoard& keyboard)
{
    if (record_data.current_frame >= record_data.max_frames_to_record)
    {
        StopRecording(record);
        return false;
    }
    else
    {
        record_data.keyboard_data[record_data.current_frame] = keyboard;
        ++record_data.current_frame;
    }

    return true;
}

void Playback(Memory& memory, RecordData& record, KeyBoard& keyboard)
{
    // Load game state at first frame.
    if (record_data.current_frame == 0)
    {
        LoadGameState(memory);
    }

    keyboard = record_data.keyboard_data[record_data.current_frame++];
    if (record_data.current_frame >= record_data.frames_recorded)
    {
        LoadGameState(memory);
        record_data.current_frame = 0;
    }
}


int main(int argc, char* argv[])
{
    // ---- INITIALIZE MEMORY ----
    {
        // https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/calloc.3.html
        u64 total_size = KILOBYTES(4);
        u8* raw_virtual_memory = AllocateVirtualMemory(total_size);  // LEAK(ted): Never freed, as it'll likely live to the end of the program.

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


    // ---- INITIALIZE DLL AND HOTLOADER ----
    const char* dll_path;
    FileEventMonitor dll_monitor;
    {
        dll_path = GetNameByExecutable("libGame.A.dylib");  // LEAK(ted): Making static for now.
        dll_monitor = CreateMonitor(dll_path);
        if (!dll_monitor.queue)
            return 1;
        game = TryLoadGame(dll_path);
    }


    // ---- INITIALIZE GAME ----
    game.initialize(memory);

    // ---- INITIALIZE WINDOW ----
    NSWindow* window;
    {
        int default_width  = 512;
        int default_height = 512;
        window = CreateWindow(default_width, default_height);  // LEAK(ted): Does the window need to be freed?
        ResizeBuffer(window, framebuffer);
    }

    // ---- INITIALIZE AUDIO -----
    AudioQueueRef audio_queue;
    {
        audio_queue = SetupAudioQueue();  // LEAK(ted): Does the audio queue need to be freed?
    }


    NanoClock clock;
    NanoClock frame_clock;

    u8  frame_time_result_count = 0;
    u64 frame_time_results[255];

    u8  cycle_result_count = 0;
    u64 cycle_results[255];

    int frames = 0;

    // ---- INITIALIZE RECORD DATA ----
    bool record_user_input   = false;
    bool playback_user_input = false;
    record_data.max_frames_to_record = 65535;
    record_data.keyboard_data = cast(malloc(record_data.max_frames_to_record * sizeof(KeyBoard)), KeyBoard*);  // LEAK(ted): Never freed, as it'll likely live to the end of the program.
    record_data.current_frame = 0;

    while (running)
    {
        u64 start = CycleCount();

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
        uint64_t delta = Tick(clock, MILLI_TO_NANO(32));
        frame_time_results[frame_time_result_count++] = delta;

        // ---- EVENTS ----
        HandleEvents(keyboard);
        // if (CheckForFileEvents(dll_monitor))
        // {
        //     game = TryLoadGame(dll_path);
        //     dll_monitor = CreateMonitor(dll_path);
        // }


        // ---- RECORD AND PLAYBACK ----
        {
            for (u8 i = 0; i < keyboard.used; ++i)
            {
                if (keyboard.keys[i].character == ',')  // Toggle recording
                {
                    playback_user_input = false;
                    if (!record_user_input)
                    {
                        record_user_input = true;
                        StartRecording(memory);
                    }
                    else
                    {
                        record_user_input = false;
                        StopRecording(record_data);
                    }
                }
                else if (keyboard.keys[i].character == '.')  // Toggle playback
                {
                    if (playback_user_input)
                    {
                        playback_user_input = false;
                    }
                    else
                    {
                        playback_user_input = true;
                        record_user_input   = false;
                        StopRecording(record_data);
                    }
                }
            }

            if (record_user_input)
            {
                if (!RecordFrame(memory, record_data, keyboard))
                {
                    printf("Recording exceeded max capacity. Recording stopped.");
                    record_user_input = false;
                    StopRecording(record_data);
                }
            }

            if (playback_user_input)  // Here we'll overwrite the user input with previous input, and cycle on end.
            {
                Playback(memory, record_data, keyboard);
            }
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