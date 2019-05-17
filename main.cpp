#include <stdio.h>
#include <math.h>
#include <string.h>

#include "main.h"


struct SoundState
{
    f32 theta;
    f32 alpha;
};

struct GameState
{
    s32 offset;
    bool increase;

    s32 x;
    s32 y;
};

struct State
{
    GameState  game;
    SoundState sound;
};


void DrawRectangle(FrameBuffer& framebuffer, s32 left, s32 top, s32 right, s32 bottom)
{
    if (left < 0) left = 0;
    if (top  < 0) top  = 0;
    if (right  >= framebuffer.width)  right  = framebuffer.width;
    if (bottom >= framebuffer.height) bottom = framebuffer.height;

    for (u16 y = cast(top, u16); y < cast(bottom, u16); ++y)
    {
        for (u16 x = cast(left, u16); x < cast(right, u16); ++x)
        {
            Pixel& pixel = framebuffer.pixels[y * framebuffer.width + x];

            pixel.r = 255;
            pixel.g = 255;
            pixel.b = 0;
            pixel.a = 255;
        }
    }
}


void Initialize(Memory& memory)
{
    ASSERT(&memory.persistent.data != 0, "Invalid persistent memory.\n");
    ASSERT(&memory.temporary.data  != 0, "Invalid temporary memory.\n");

    State* state = cast(memory.persistent.data, State*);

    if (!memory.initialized)
    {
        state->game.offset = 0;
        state->game.increase = true;
        state->game.x = 0;
        state->game.y = 0;

        state->sound.theta = 0;
        state->sound.alpha = 0;

        memory.initialized = true;
        memory.persistent.used = sizeof(State);
    }
}

void Update(Memory& memory, FrameBuffer& framebuffer, KeyBoard keyboard)
{
    GameState& state = cast(memory.persistent.data, State*)->game;

    for (u16 i = 0; i < keyboard.used; ++i)
    {
        Key& key = keyboard.keys[i];
        int speed = 10;
        if (key.character == 'a')
            state.x -= speed;
        else if (key.character == 'd')
            state.x += speed;
        else if (key.character == 'w')
            state.y -= speed;
        else if (key.character == 's')
            state.y += speed;
    }

    if (state.offset >= 255)
        state.increase = false;
    if (state.offset <= 0)
        state.increase = true;

    if (state.increase)
        ++state.offset;
    else
        --state.offset;

    // Fill screen
    for (int y = 0; y < framebuffer.height; ++y)
    {
        for(int x = 0; x < framebuffer.width ; ++x)
        {
            /* Pixel in memory: RR GG BB AA */
            Pixel& pixel = framebuffer.pixels[y * framebuffer.width + x];

            pixel.r = 0;
            pixel.g = cast(state.offset, u8);
            pixel.b = 0;
            pixel.a = 255;
        }
    }

    // Draw rectangle
    DrawRectangle(framebuffer, 20+state.x, 20+state.y, 100+state.x, 100+state.y);
}


void Sound(Memory& memory, SoundBuffer& buffer)
{
    SoundState& state = cast(memory.persistent.data, State*)->sound;

    u16 left_tone  = 440;
    u16 right_tone = 220;

    for (u32 left = 0, right = 1; right < buffer.size / 2; left+=2, right+=2)
    {
        buffer.data[left]  = cast(sin(state.theta) * 32767.0f, s16);
        buffer.data[right] = cast(sin(state.alpha) * 32767.0f, s16);

        state.theta += 2.0f * PI32 * left_tone  / 44100;
        state.alpha += 2.0f * PI32 * right_tone / 44100;
        if (state.theta > 2.0f * PI32)
            state.theta -= 2.0f * PI32;
        if (state.alpha > 2.0f * PI32)
            state.alpha -= 2.0f * PI32;
    }
}


