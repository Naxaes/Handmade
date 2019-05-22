#include <mach-o/dyld.h>  // _NSGetExecutablePath
#include <dlfcn.h>        // dlsym, dlerror, RTLD_LOCAL, RTLD_LAZY

// RESULT MUST BE FREED
char* GetExecutableDirectory(const char* name)
{
    char* path = cast(malloc(MAXPATHLEN), char*);

    u32 size  = MAXPATHLEN;
    s32 error = _NSGetExecutablePath(path, &size);
    ASSERT(error != -1, "Buffer too small. %u bytes required, %u given.\n", size, MAXPATHLEN);
    u32 actual_size = strlen(path) + 1;


    // Cut off executable name.
    for (u16 i = actual_size; i > 0; --i)  // NOTE(ted): Beware of underflow.
    {
        if (path[i] == '/')
        {
            path[i+1] = '\0';
            break;
        }
    }

    return path;
}

// RESULT MUST BE FREED
const char* GetNameByExecutable(const char* name)
{
    u16 dll_name_size = strlen(name) + 1;
    u16 max_size = MAXPATHLEN + dll_name_size;

    char* path = cast(malloc(max_size), char*);  // +1 null, +1 delimiter

    u32 size  = MAXPATHLEN;
    s32 error = _NSGetExecutablePath(path, &size);
    ASSERT(error != -1, "Buffer too small. %u bytes required, %u given.\n", size, MAXPATHLEN);
    u32 actual_size = strlen(path) + 1;

    u16 last_parenthesis = 0;
    for (u16 i = actual_size; i > 0; --i)  // NOTE(ted): Beware of underflow.
    {
        if (path[i] == '/')
        {
            last_parenthesis = i;
            break;
        }
    }

    u16 x = last_parenthesis == 0 ? 0 : 1;

    for (u16 i = 0; i < dll_name_size; ++i)
        path[last_parenthesis + i + x] = name[i];

    return path;
}

void* LoadDLLFunction(void* dll, const char* name)
{
    void* function = dlsym(dll, name);
    if (!function)
        printf("Couldn't load function '%s'. %s\n", name, dlerror());
    return function;
}

Game TryLoadGame(const char* path)
{
    static void* dll_handle = nullptr;

    if (dll_handle)
        ASSERT(!dlclose(dll_handle), "Couldn't close dll. %s\n", dlerror());


    dll_handle = dlopen(path, RTLD_LOCAL|RTLD_LAZY);
    ASSERT(dll_handle, "Couldn't load dll. %s\n", dlerror());

    game.initialize = reinterpret_cast<InitializeFunction>(LoadDLLFunction(dll_handle, "Initialize"));
    if (!game.initialize)
        game.initialize = DEFAULT_Initialize;

    game.update = reinterpret_cast<UpdateFunction>(LoadDLLFunction(dll_handle, "Update"));
    if (!game.update)
        game.update = DEFAULT_Update;

    game.sound = reinterpret_cast<SoundFunction>(LoadDLLFunction(dll_handle, "Sound"));
    if (!game.sound)
        game.sound = DEFAULT_Sound;

    return game;
}


struct FileEventMonitor
{
    int queue;
    int file;
};

FileEventMonitor CreateMonitor(const char* path)
{
    int event_queue_handle = kqueue();
    if (event_queue_handle == -1)
        ERROR("Couldn't create event queue.\n");

    int file_handle = open(path, O_EVTONLY);
    if (file_handle == -1)
        ERROR("Couldn't open %s'.\n", path);

    FileEventMonitor result;
    result.queue = event_queue_handle;
    result.file  = file_handle;
    return result;
}


bool CheckForFileEvents(FileEventMonitor monitor)
{
    struct kevent change;
    int filter  = EVFILT_VNODE;
    int flags   = EV_ADD | EV_CLEAR;
    int fflags  = NOTE_DELETE | NOTE_WRITE | NOTE_EXTEND | NOTE_ATTRIB | NOTE_LINK | NOTE_RENAME | NOTE_REVOKE;
    int data    = 0;
    void* udata = 0;
    EV_SET(&change, monitor.file, filter, flags, fflags, data, udata);

    int change_array_count = 1;
    int event_array_count  = 1;
    struct timespec timeout;
    timeout.tv_sec  = 0;  // Seconds to wait.
    timeout.tv_nsec = 0;  // Nanoseconds to wait.
    struct kevent event;
    int error_code = kevent(monitor.queue, &change, change_array_count, &event, event_array_count, &timeout);

    if (error_code == -1)
    {
        ERROR("Error fetching event!\n");
        return false;
    }
    else if (error_code > 0)
    {
        if (event.fflags & NOTE_DELETE)
            return true;
        if (event.fflags & NOTE_WRITE)
            return true;
        if (event.fflags & NOTE_EXTEND)
            return true;
        if (event.fflags & NOTE_ATTRIB)
            return true;
        if (event.fflags & NOTE_LINK)
            return true;
        if (event.fflags & NOTE_RENAME)
            return true;
        if (event.fflags & NOTE_REVOKE)
            return true;
    }
    return false;
}