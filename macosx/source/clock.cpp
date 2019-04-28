#include <sys/event.h>
#include <sys/time.h>
#include <mach/mach_time.h>


#define SECONDS_TO_MILLI(x) ((x)*1000)
#define SECONDS_TO_MICRO(x) ((x)*1000000)
#define SECONDS_TO_NANO(x)  ((x)*1000000000)
#define MILLI_TO_SECONDS(x) ((x)/1000)
#define MILLI_TO_MICRO(x)   ((x)*1000)
#define MILLI_TO_NANO(x)    ((x)*1000000)
#define MICRO_TO_SECONDS(x) ((x)/1000000)
#define MICRO_TO_MILLI(x)   ((x)/1000)
#define MICRO_TO_NANO(x)    ((x)*1000)
#define NANO_TO_SECONDS(x)  ((x)/1000000000)
#define NANO_TO_MILLI(x)    ((x)/1000000)
#define NANO_TO_MICRO(x)    ((x)/1000)


struct NanoClock
{
    u64 last_time;
    mach_timebase_info_data_t info;

    NanoClock()
    {
        last_time = mach_absolute_time();
        mach_timebase_info(&info);
    }
};

u64 Sleep(NanoClock clock, u64 time)
{
    struct timespec remaining_sleep_time;
    struct timespec sleep_time;
    sleep_time.tv_sec  = 0;
    sleep_time.tv_nsec = time;
    if (nanosleep(&sleep_time, &remaining_sleep_time) == -1)
        return SECONDS_TO_NANO(remaining_sleep_time.tv_sec) + remaining_sleep_time.tv_nsec;
    else
        return 0;
}

u64 Tick(NanoClock& clock, u64 cap)
{
    ASSERT(cap < SECONDS_TO_NANO(60), "Cannot sleep more than a minute. Cap was %llu ns.\n", cap);

    u64 current  = mach_absolute_time();
    u64 duration = current - clock.last_time;
    duration = static_cast<u64>((duration * clock.info.numer) / static_cast<f64>(clock.info.denom));

    // Sleep if program runs faster than cap.
    if (duration < cap)
    {
        if (u64 remaining_time = Sleep(clock, cap - duration))
            fprintf(stderr, "Sleep interrupted. Errno %i. Remaining: %lluns\n", errno, remaining_time);

        current  = mach_absolute_time();
        duration = current - clock.last_time;
        duration = static_cast<u64>((duration * clock.info.numer) / static_cast<f64>(clock.info.denom));
    }

    clock.last_time = current;
    return duration;
}

u64 Tick(NanoClock& clock)
{
    u64 current  = mach_absolute_time();
    u64 duration = current - clock.last_time;
    duration = static_cast<u64>((duration * clock.info.numer) / static_cast<f64>(clock.info.denom));

    clock.last_time = current;
    return duration;
}

bool Timer(NanoClock& clock, u64 time)
{
    u64 current  = mach_absolute_time();
    u64 duration = current - clock.last_time;
    duration = cast((duration * clock.info.numer) / cast(clock.info.denom, f64), u64);
    if (duration >= time)
    {
        clock.last_time = current;
        return true;
    }
    return false;
}

