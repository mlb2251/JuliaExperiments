



const ttime_is_init = Ref(false)
const has_task_metrics = isdefined(Base.Experimental, :task_metrics)

function ttime_init()
    if !ttime_is_init[]
        Base.cumulative_compile_timing(true)
        has_task_metrics && Base.Experimental.task_metrics(true)
        ttime_is_init[] = true
    end
end

function ttime_deinit()
    if ttime_is_init[]
        Base.cumulative_compile_timing(false)
        has_task_metrics && Base.Experimental.task_metrics(false)
        ttime_is_init[] = false
    end
end

function blackbox(@nospecialize f)
    return f()
end

macro ttime(ex)
    quote
        local tstart = ttime()
        local val = $(esc(ex))
        local t = ttime() - tstart
        val, t
    end
end

struct TimeState
    wall_time::Float64 # wall clock
    gc_total_time::Float64 # gc time
    gc_total_time_to_safepoint::Float64 # gc time to safepoint (not included in gc_total_time for some reason)
    compile_time::Float64 # compile time
    task_running_time::Float64 # task running time
    task_wall_time::Float64 # task wall time
end

function Base.show(io::IO, t::TimeState)
    lb = lower_bound(t)
    ub = upper_bound(t)
    ubjl = upper_bound_julia(t)
    print(io, "(wall_time=$(t.wall_time), lower_bound=$(lb), upper_bound_julia=$(ubjl), upper_bound=$(ub), bound_diff=$(ub-lb), gc=$(t.gc_total_time), safepoint=$(t.gc_total_time_to_safepoint), compile_time=$(t.compile_time), task_running_time=$(t.task_running_time), task_wall_time=$(t.task_wall_time))")
end

function Base.:(-)(a::TimeState, b::TimeState)
    TimeState(a.wall_time - b.wall_time, a.gc_total_time - b.gc_total_time, a.gc_total_time_to_safepoint - b.gc_total_time_to_safepoint, a.compile_time - b.compile_time, a.task_running_time - b.task_running_time, a.task_wall_time - b.task_wall_time)
end



"""
Upper bound on the time spent in pure julia code, which would have to block on the GC.
We wish we could subtract off the gc_total_time_to_safepoint, but technically only the very first
thread thats waiting at the safepoint logs that number so other threads might get more work done.

If you know that the code is in pure julia, this can put a much tighter upper bound on the time.
"""
function upper_bound_julia(t::TimeState)
    t.wall_time - t.gc_total_time
end

"""
For a true upper bound that includes C/Rust code that can run while GC is happening,
we can only use the wall clock time.
"""
function upper_bound(t::TimeState)
    t.wall_time
end

"""
A lower bound on the time spent actually doing work, obtained by subtracting various upper bounds off the wall clock time.
* gc_total_time: time spent in GC was not work. Loose bound because we might have been in Rust/C code with gc_safe=true.
* gc_total_time_to_safepoint: time spent waiting at a safepoint is not work. Loose bound because we might not have been the thread that started the safepoint wait (so we might have waited less time), or also we might be in Rust/C code with gc_safe=true.
* compile_time: time spent compiling is not work. Loose bound due to a double-counting bug in julia's compile time logging.
"""
function lower_bound(t::TimeState)
    max(0., t.wall_time - t.gc_total_time - t.gc_total_time_to_safepoint - t.compile_time)
end

function ttime()
    ttime_init()
    gc_num = Base.gc_num()
    task_run = has_task_metrics ? Base.Experimental.task_running_time_ns() : UInt64(0)
    task_wall = has_task_metrics ? Base.Experimental.task_wall_time_ns() : UInt64(0)
    TimeState(
        time_ns()/1e9,
        gc_num.total_time/1e9,
        gc_num.total_time_to_safepoint/1e9,
        Base.cumulative_compile_time_ns()[1]/1e9,
        isnothing(task_run) ? 0. : task_run/1e9,
        isnothing(task_wall) ? 0. : task_wall/1e9
    )
end

