#pragma once

// These are shared across all platforms.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>

// FIX(ted): THIS PRESUMABLY ONLY WORKS ON UNIX. FIX!
#include <signal.h>    // raise(SIGINT)


#define PI32 3.1415927410125732421875f

#define REPORT_ERROR(...)                                                                                      \
{                                                                                                       \
    char buffer[255];                                                                                   \
    sprintf(buffer, __VA_ARGS__);                                                                       \
    fprintf(stderr, "[Error]:\n\tFile: %s\n\tLine: %i\n\tMessage: %s", __FILE__, __LINE__, buffer);     \
}
#define REPORT_ERROR_ONCE(...)                                                                                 \
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
    u32  size;
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


// https://sourceforge.net/p/predef/wiki/OperatingSystems/

// EXPORT_FUNCTION(name, parameters):
//    1. Forward declares the function with 'extern "C"' and as DLL.
//    2. Type defines the function as "<name>Function".
//    3. Creates an empty stub function called "DEFAULT_<name>.

#if defined(__APPLE__) && defined(__MACH__)
#define EXPORT_FUNCTION(name, ...)                                          \
extern "C" __attribute__((visibility("default"))) void name(__VA_ARGS__);   \
typedef void (*name##Function)(__VA_ARGS__);                                \
void DEFAULT_##name(__VA_ARGS__) {}                                         \

#elif defined(_WIN32) || defined(_WIN64)
#define EXPORT_FUNCTION(name, ...)                                          \
extern "C" __declspec(dllexport) void name(__VA_ARGS__);                    \
typedef void (*name##Function)(__VA_ARGS__);                                \
void DEFAULT_##name(__VA_ARGS__) {}                                         \

#elif defined(__linux__)
#error "Don't support Linux yet."

#else
#error "Couldn't determine operating system!"
#endif


EXPORT_FUNCTION(Initialize, Memory&);
EXPORT_FUNCTION(Update, Memory&, FrameBuffer&, KeyBoard&);
EXPORT_FUNCTION(Sound,  Memory&, SoundBuffer&);


