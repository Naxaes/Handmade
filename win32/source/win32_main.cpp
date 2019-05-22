#include "main.h"

#include <windows.h>
#include <xinput.h>
#include <dsound.h>


struct Win32FrameBuffer
{
	BITMAPINFO info;

	int width;
	int height;
	
	int bytes_per_pixel;

	void* memory;
};

struct Win32Game
{
	InitializeFunction initialize;
	UpdateFunction     update;
	SoundFunction      sound;
};

static Win32FrameBuffer win32_framebuffer;
static Win32Game win32_game;

static void Win32ResizeFrameBuffer(Win32FrameBuffer& buffer, int width, int height)
{
	if (buffer.memory)
		VirtualFree(buffer.memory, 0, MEM_RELEASE);

	buffer.info.bmiHeader.biSize   =  sizeof(buffer.info.bmiHeader);
	buffer.info.bmiHeader.biWidth  =  width;
	buffer.info.bmiHeader.biHeight = -height;  // Negative values makes the bitmap top-down, instead of bottom-up.
	buffer.info.bmiHeader.biPlanes =  1;
	buffer.info.bmiHeader.biBitCount	  = 32;
	buffer.info.bmiHeader.biCompression   = BI_RGB;
	buffer.info.bmiHeader.biSizeImage	  = 0;
	buffer.info.bmiHeader.biXPelsPerMeter = 0;
	buffer.info.bmiHeader.biYPelsPerMeter = 0;
	buffer.info.bmiHeader.biClrUsed		  = 0;
	buffer.info.bmiHeader.biClrImportant  = 0;

	buffer.width  = width;
	buffer.height = height;
	buffer.bytes_per_pixel = 4;

	int memory_size = buffer.width * buffer.height * buffer.bytes_per_pixel;

	buffer.memory = VirtualAlloc(0, memory_size, MEM_COMMIT, PAGE_READWRITE);
}

static void Win32UpdateWindow(HWND window, Win32FrameBuffer buffer)
{
	RECT client_rect;
	GetClientRect(window, &client_rect);

	PAINTSTRUCT paint;
	HDC device_context = BeginPaint(window, &paint);

	RECT dirty_area  = client_rect;
	RECT source_area = client_rect;

	StretchDIBits(
		device_context, 
		dirty_area.left,  dirty_area.top,  dirty_area.right  - dirty_area.left,  dirty_area.bottom  - dirty_area.top,   // Destination
		source_area.left, source_area.top, source_area.right - source_area.left, source_area.bottom - source_area.top,  // Source
		buffer.memory, &buffer.info,
		DIB_RGB_COLORS, SRCCOPY
	);

	EndPaint(window, &paint);
}


LRESULT CALLBACK Win32EventCallback(HWND window, UINT message, WPARAM wParam, LPARAM lParam)
{
	if (message == WM_SIZE)
	{
		RECT client_rect;
		GetClientRect(window, &client_rect);
		int width  = client_rect.right  - client_rect.left;
		int height = client_rect.bottom - client_rect.top;

		Win32ResizeFrameBuffer(win32_framebuffer, width, height);

		return 0;
	}
	else if (message == WM_PAINT)  // We repaint continuously.
	{
		return 0;
	}
	else if (message == WM_CLOSE)
	{
		if (MessageBox(window, L"Really quit?", L"My application", MB_OKCANCEL) == IDOK)
		{
			DestroyWindow(window);
			PostQuitMessage(0);
		}
		return 0;
	}
	else if (message == WM_ACTIVATEAPP)
	{

	}

	return DefWindowProc(window, message, wParam, lParam);
}


void Win32LoadGame(Win32Game& game)
{
	HMODULE game_handle = LoadLibrary(L"main.dll");
	if (!game_handle)
		REPORT_ERROR("Couldn't load game!\n")

	game.initialize = (InitializeFunction) GetProcAddress(game_handle, "Initialize");
	game.update     = (UpdateFunction)     GetProcAddress(game_handle, "Update");
	game.sound      = (SoundFunction)      GetProcAddress(game_handle, "Sound");

	if (!game.initialize || !game.update || !game.sound)
		REPORT_ERROR("Couldn't load all game functions!\n")

	printf("Loaded game.\n");
}



int WINAPI wWinMain(HINSTANCE instance, HINSTANCE _, PWSTR command_line_arguments, int show_code)
{
    // Register the window class.
    const WCHAR CLASS_NAME[]  = L"Sample Window Class";
    
    WNDCLASS window_class = { 0 };

	window_class.lpfnWndProc   = Win32EventCallback;
	window_class.hInstance     = instance;
	window_class.lpszClassName = CLASS_NAME;
	window_class.style         = CS_HREDRAW|CS_VREDRAW;

	if (!RegisterClass(&window_class))
	{
		return -1;
	}

    // Create the window.

    HWND window = CreateWindowEx(
        0,                              // Optional window styles.
        CLASS_NAME,                     // Window class
        L"Learn to Program Windows",    // Window text
        WS_OVERLAPPEDWINDOW,            // Window style

        // Size and position
        CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,

        NULL,       // Parent window    
        NULL,       // Menu
        instance,   // Instance handle
        NULL        // Additional application data
    );

    if (!window)
    {
        return 0;
    }

    ShowWindow(window, show_code);

    Win32LoadGame(win32_game);

	bool running = true;
	while (running)
	{
		MSG message = {};
		while (PeekMessage(&message, 0, 0, 0, PM_REMOVE))
		{
			if (message.message == WM_QUIT)
				running = false;

			TranslateMessage(&message);
			DispatchMessage(&message);


			Memory memory = {0};
			memory.persistent.size = 1024;
			memory.persistent.used = 0;
			memory.persistent.data = malloc(1024);
			memory.temporary.size = 1024;
			memory.temporary.used = 0;
			memory.temporary.data = malloc(1024);
    		memory.initialized = false;

			FrameBuffer framebuffer = {0};
			framebuffer.width  = win32_framebuffer.width;
			framebuffer.height = win32_framebuffer.height;
			framebuffer.pixels = (Pixel*)win32_framebuffer.memory;

			KeyBoard keyboard = {0};
			keyboard.used = 0;
			keyboard.keys;

			win32_game.update(memory, framebuffer, keyboard);

			Win32UpdateWindow(window, win32_framebuffer);

			free(memory.persistent.data);
			free(memory.temporary.data);
		}
	}

    return 0;
}