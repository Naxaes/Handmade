// https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/kqueue.2.html

// NAME
//      kqueue, kevent -- kernel event notification mechanism
//
// LIBRARY
//      Standard C Library (libc, -lc)

#include <sys/event.h>
#include <sys/time.h>

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>


int main()
{
    int event_queue_handle = kqueue();
    if (event_queue_handle == -1)
    {
        printf("Couldn't open event queue.\n");
        return -1;
    }

    int file_handle = open("temp.txt", O_EVTONLY);
    if (file_handle == -1)
    {
        printf("Couldn't open 'temp.txt'.\n");
        return -1;
    }

    struct kevent change;
    int filter = EVFILT_VNODE;
    int flags  = EV_ADD | EV_CLEAR;
    int fflags = NOTE_DELETE | NOTE_WRITE | NOTE_EXTEND | NOTE_ATTRIB | NOTE_LINK | NOTE_RENAME | NOTE_REVOKE;
    int data   = 0;
    void* udata  = 0;
    EV_SET(&change, file_handle, filter, flags, fflags, data, udata);

    while (true)
    {
        int change_array_count = 1;
        int event_array_count  = 1;
        struct timespec timeout;
        timeout.tv_sec  = 0;  // Seconds to wait.
        timeout.tv_nsec = 0;  // Nanoseconds to wait.
        struct kevent event;
        int error_code = kevent(event_queue_handle, &change, change_array_count, &event, event_array_count, NULL);

        if (error_code == -1)
        {
            printf("Error getting event!\n");
            return -1;
        }
        else if (error_code > 0)
        {
            // NOTE_DELETE deletes a reference to the file descriptor (calls unlink()), which seems to mean that it was
            // closed.
            if (event.fflags & NOTE_DELETE)
                printf("NOTE_DELETE was set.\n");
            if (event.fflags & NOTE_WRITE)
                printf("NOTE_WRITE was set.\n");
            if (event.fflags & NOTE_EXTEND)
                printf("NOTE_EXTEND was set.\n");
            if (event.fflags & NOTE_ATTRIB)
                printf("NOTE_ATTRIB was set.\n");
            if (event.fflags & NOTE_LINK)
                printf("NOTE_LINK was set.\n");
            if (event.fflags & NOTE_RENAME)
                printf("NOTE_RENAME was set.\n");
            if (event.fflags & NOTE_REVOKE)
                printf("NOTE_REVOKE was set.\n");
        }

        struct timespec remaining_sleep_time;
        struct timespec sleep_time;
        sleep_time.tv_sec  = 0;
        sleep_time.tv_nsec = 250000000;  // 1/4 second.
        if (nanosleep(&sleep_time, &remaining_sleep_time) == -1)
        {
            printf("Sleep interrupted. Errno %i. Remaining: %lis %lins\n",
                    errno, remaining_sleep_time.tv_sec, remaining_sleep_time.tv_nsec
            );
        }
    }

    close(event_queue_handle);
    close(file_handle);
    return EXIT_SUCCESS;

}










