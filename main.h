#pragma once

// These are shared across all platforms.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>

// FIX(ted): THIS PRESUMABLY ONLY WORKS ON UNIX. FIX!
#include <signal.h>    // raise(SIGINT)


#define ERROR(...)                                                                                      \
{                                                                                                       \
    char buffer[255];                                                                                   \
    sprintf(buffer, __VA_ARGS__);                                                                       \
    fprintf(stderr, "[Error]:\n\tFile: %s\n\tLine: %i\n\tMessage: %s", __FILE__, __LINE__, buffer);     \
}
#define ERROR_ONCE(...)                                                                                 \
{                                                                                                       \
    static bool reported = false;                                                                       \
    if (!reported)                                                                                      \
        ERROR(__VA_ARGS__);                                                                             \
    reported = true;                                                                                    \
}
#define ASSERT(status, ...)                                                                                           \
{                                                                                                                     \
    if (!(status))                                                                                                    \
    {                                                                                                                 \
        char buffer[255];                                                                                             \
        sprintf(buffer, __VA_ARGS__);                                                                                 \
        fprintf(stderr, "[Assertion failed]:\n\tCondition: %s\n\tFile: %s\n\tLine: %i\n\tMessage: %s", #status, __FILE__, __LINE__, buffer);    \
        raise(SIGINT);                                                                                                \
    }                                                                                                                 \
}



#define cast(x, type) static_cast<type>(x)

typedef uint8_t  u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;

typedef int8_t  s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;

typedef float  f32;
typedef double f64;


struct Allocator
{
    u64 capacity;
    u64 memory_allocated;
    void* memory;
};
void* Allocate(Allocator& allocater, u64 size) {}
void  Free(Allocator& allocater, void* memory) {}

struct Logger
{
    u8*   file;
    u8*   function;
    u32   line;
    FILE* file;
};

struct Context
{
    Allocator& allocator;
    Logger&    logger;
};


struct Buffer
{
    u32   size;  // Maximum 4GB
    u32   used;
    void* data;
};


struct Memory
{
    Buffer persistent;
    Buffer temporary;
    bool   initialized;
};



struct Pixel
{
    u8 r, g, b, a;
};

struct FrameBuffer
{
    s32 width;
    s32 height;
    Pixel* pixels;
};

struct Sample { s16 left; s16 right; };
struct SoundBuffer
{
    s32  size;
    s16* data;
};


struct Key
{
    s8   character;
    s32  transitions;
    bool ended_on_down;
};

struct KeyBoard
{
    u16 used;
    Key keys[128];
};


// EXPORT_FUNCTION(name, parameters):
//    1. Forward declares the function with 'extern "C"' and default visibility.
//    2. Type defines the function as "<name>Function".
//    3. Creates an empty stub function called "DEFAULT_<name>.
#define EXPORT_FUNCTION(name, ...)                                          \
extern "C" __attribute__((visibility("default"))) void name(__VA_ARGS__);   \
typedef void (*name##Function)(__VA_ARGS__);                                \
void DEFAULT_##name(__VA_ARGS__) {}                                         \


EXPORT_FUNCTION(Initialize, Memory&);
EXPORT_FUNCTION(Update, Memory&, FrameBuffer&, KeyBoard);
EXPORT_FUNCTION(Sound,  Memory&, SoundBuffer&);




