#include <stdio.h>
#include <math.h>
#include <string.h>

#include "main.h"


struct GameState
{
    s32 offset;
    bool increase;
    f32 theta;
    f32 alpha;

    s32 x;
    s32 y;
};

void DrawRectangle(FrameBuffer& framebuffer, s32 left, s32 top, s32 right, s32 bottom)
{
    if (left < 0) left = 0;
    if (top  < 0) top  = 0;
    if (right  >= framebuffer.width)  right  = framebuffer.width;
    if (bottom >= framebuffer.height) bottom = framebuffer.height;

    for (u16 y = top; y < bottom; ++y)
    {
        for (u16 x = left; x < right; ++x)
        {
            Pixel& pixel = framebuffer.pixels[y * framebuffer.width + x];

            pixel.r = 255;
            pixel.g = 255;
            pixel.b = 0;
            pixel.a = 255;
        }
    }
}


void Update(Memory& memory, FrameBuffer& framebuffer, KeyBoard keyboard)
{
    GameState* state = static_cast<GameState*>(memory.persistent.data);

    if (!memory.initialized)
    {
        state->offset = 0;
        state->increase = true;
        state->theta = 0;
        state->alpha = 0;
        state->x = 0;
        state->y = 0;
        memory.initialized = true;
    }

    for (u16 i = 0; i < keyboard.used; ++i)
    {
        Key& key = keyboard.keys[i];
        int speed = 10;
        if (key.character == 'a')
            state->x -= speed;
        else if (key.character == 'd')
            state->x += speed;
        else if (key.character == 'w')
            state->y -= speed;
        else if (key.character == 's')
            state->y += speed;
    }

    if (state->offset >= 255)
        state->increase = false;
    if (state->offset <= 0)
        state->increase = true;

    if (state->increase)
        ++state->offset;
    else
        --state->offset;

    // Fill screen
    for (int y = 0; y < framebuffer.height; ++y)
    {
        for(int x = 0; x < framebuffer.width ; ++x)
        {
            /* Pixel in memory: RR GG BB AA */
            Pixel& pixel = framebuffer.pixels[y * framebuffer.width + x];

            pixel.r = 0;
            pixel.g = state->offset;
            pixel.b = 0;
            pixel.a = 255;
        }
    }

    // Draw rectangle
    DrawRectangle(framebuffer, 20+state->x, 20+state->y, 100+state->x, 100+state->y);
}


void Sound(Memory& memory, SoundBuffer& buffer)
{
    if (!memory.initialized)
    {
        memset(buffer.data, 0, buffer.size);
        return;
    }

    GameState* state = static_cast<GameState*>(memory.persistent.data);

    u16 left_tone  = 440;
    u16 right_tone = 220;

    for (u32 left = 0, right = 1; right < buffer.size / 2; left+=2, right+=2)
    {
        buffer.data[left]  = cast(sin(state->theta) * 32767.0f, s16);
        buffer.data[right] = cast(sin(state->alpha) * 32767.0f, s16);

        state->theta += 2.0 * M_PI * left_tone  / 44100;
        state->alpha += 2.0 * M_PI * right_tone / 44100;
        if (state->theta > 2.0 * M_PI)
            state->theta -= 2.0 * M_PI;
        if (state->alpha > 2.0 * M_PI)
            state->alpha -= 2.0 * M_PI;
    }
}


