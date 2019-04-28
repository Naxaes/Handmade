#pragma once

// These are shared across all platforms.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>

#define ERROR(...)                                                                             \
{                                                                                                       \
    char buffer[255];                                                                                   \
    sprintf(buffer, __VA_ARGS__);                                                              \
    fprintf(stderr, "[Error]:\n\tFile: %s\n\tLine: %i\n\tMessage: %s", __FILE__, __LINE__, buffer);     \
}
#define ERROR_ONCE(...)                                                                        \
{                                                                                                       \
    static bool reported = false;                                                                       \
    if (!reported)                                                                                      \
        ERROR(__VA_ARGS__);                                                                    \
    reported = true;                                                                                    \
}
#define ASSERT(status, ...)                                                                                  \
{                                                                                                                     \
    if (!(status))                                                                                                    \
    {                                                                                                                 \
        char buffer[255];                                                                                             \
        sprintf(buffer, __VA_ARGS__);                                                                        \
        fprintf(stderr, "[Assertion failed]:\n\tCondition: "#status"\n\tFile: %s\n\tLine: %i\n\tMessage: %s", __FILE__, __LINE__, buffer);    \
        exit(-1);                                                                                                     \
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
    bool   initialized;
    Buffer persistent;
    Buffer temporary;
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

struct SoundBuffer
{
    s32  size;
    s16* data;
};


struct Key
{
    s32  value;
    s32  transitions;
    bool ended_on_down;
};


// EXPORT_FUNCTION(name, parameters):
//    1. Forward declares the function with 'extern "C"' and default visibility.
//    2. Type defines the function as "<name>Function".
//    3. Creates an empty stub function called "DEFAULT_<name>.
#define EXPORT_FUNCTION(name, ...)                                          \
extern "C" __attribute__((visibility("default"))) void name(__VA_ARGS__);   \
typedef void (*name##Function)(__VA_ARGS__);                                \
void DEFAULT_##name(__VA_ARGS__) {}                                         \


EXPORT_FUNCTION(Update, Memory&, FrameBuffer&, Key);
EXPORT_FUNCTION(Sound,  Memory&, SoundBuffer&);




