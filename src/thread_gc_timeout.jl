# Simple test file for thread and GC functionality
using Base.Threads

export test


isbeta() = occursin("beta", string(VERSION))

global_fake = true

function rust_test()

    N = 2

    Threads.@threads :greedy for i in 1:N
        if i % 2 == 0
            println("starting rust_busy from thread $(Threads.threadid())")
            @time "rust" rust_busy()
            println("ending rust_busy from thread $(Threads.threadid())")
        else
            println("starting gc_busy from thread $(Threads.threadid())")
            # printstyled("gc_before\n", color=:green)
            # print_gc(Base.gc_num())
            # before = Base.gc_num()
            t = do_timing(gc_busy)

            print_run(t)
            # printstyled("gc_after\n", color=:green)
            # print_gc(Base.gc_num())
            # diff_gc(Base.gc_num(), before)
            println("ending gc_busy from thread $(Threads.threadid())")
        end
    end

end

function diff_gc(before, after)
    for field in fieldnames(typeof(before))
        println(field, ": ", (getfield(before, field) - getfield(after, field))/1e9)
    end
end

function rust_busy()
    add_numbers(1, 2)
end

function gc_busy()
    x = []
    for i in 1:100000000
        push!(x, i)
    end
    return nothing
end



function test()
    println("Julia version: $(VERSION)")
    # res = add_numbers(10, 20)
    # println("added numbers: 10 + 20 = $res")

    # before = Base.gc_num()
    # t = @timed compiles_a_lot()

    isbeta() && Base.Experimental.task_metrics(true)

    N = 8

    times = Vector{NamedTuple}(undef, N)


    # do_timing(() -> nothing, fake=global_fake)

    tstart = time()

    @threads :greedy for i in 1:N
        # t = @timed compiles_a_lot()
        # println("t: $(t.time) c: $(t.compile_time) gc: $(t.gctime)")
        # do_timing(() -> nothing)

        println("[$(time() - tstart)] starting: $i on thread $(Threads.threadid())")

        run1 = do_timing(() -> compiles_a_lot)

        println("[$(time() - tstart)] midway: $i on thread $(Threads.threadid())")

        run2 = do_timing(compiles_a_lot)
        println("[$(time() - tstart)] ending: $i on thread $(Threads.threadid())")

        times[i] = (; i, run1, run2)
    end
    # return
    # print_gc(Base.gc_num())

    for (;i, run1, run2) in times
        printstyled("workload $i: \n", color=:green)
        printstyled("run1: \n", color=:yellow)
        print_run(run1)
        printstyled("run2: \n", color=:yellow)
        print_run(run2)
    end
    # after = Base.gc_num()
    # printstyled("before: \n", color=:yellow)
    # print_timed(t1)
    # printstyled("after: \n", color=:yellow)
    # print_timed(t2)
    # print_gc(Base.GC_Diff(after, before))
end


function goodtimer(@nospecialize f)
    println("starting goodtimer for thread $(Threads.threadid())")
    Threads.lock_profiling(true)
    local lock_conflicts = Threads.LOCK_CONFLICT_COUNT[]
    local stats = Base.gc_num()
    local elapsedtime = time_ns()
    Base.cumulative_compile_timing(true)
    local compile_elapsedtimes = Base.cumulative_compile_time_ns()

    val = nothing

    try
        println("hi from thread $(Threads.threadid()) before comptime: $(compile_elapsedtimes[1]/1e9)")
        @time val = f()
    finally
        elapsedtime = time_ns() - elapsedtime;
        Base.cumulative_compile_timing(false);
        compile_elapsedtimes = Base.cumulative_compile_time_ns() .- compile_elapsedtimes;
        println("hi from thread $(Threads.threadid()) after comptime: $(compile_elapsedtimes[1]/1e9)");
        lock_conflicts = Threads.LOCK_CONFLICT_COUNT[] - lock_conflicts;
        Threads.lock_profiling(false)
    end
    local stats_after = Base.gc_num()
    local diff = Base.GC_Diff(stats_after, stats)
    return (
        value=val,
        time=elapsedtime/1e9,
        bytes=diff.allocd,
        gctime=diff.total_time/1e9,
        gcstats=diff,
        lock_conflicts=lock_conflicts,
        compile_time=compile_elapsedtimes[1]/1e9,
        recompile_time=compile_elapsedtimes[2]/1e9,
        safepoint_time= (stats_after.total_time_to_safepoint - stats.total_time_to_safepoint)/1e9
    )
end



macro my_timed(ex)
    quote
        Base.Experimental.@force_compile
        Threads.lock_profiling(true)
        local lock_conflicts = Threads.LOCK_CONFLICT_COUNT[]
        local stats = Base.gc_num()
        local elapsedtime = time_ns()
        Base.cumulative_compile_timing(true)
        local compile_elapsedtimes = Base.cumulative_compile_time_ns()

        local val = @__tryfinally($(esc(ex)),
            (elapsedtime = time_ns() - elapsedtime;
            Base.cumulative_compile_timing(false);
            compile_elapsedtimes = Base.cumulative_compile_time_ns() .- compile_elapsedtimes;
            lock_conflicts = Threads.LOCK_CONFLICT_COUNT[] - lock_conflicts;
            Threads.lock_profiling(false))
        )
        local diff = Base.GC_Diff(Base.gc_num(), stats)
        (
            value=val,
            time=elapsedtime/1e9,
            bytes=diff.allocd,
            gctime=diff.total_time/1e9,
            gcstats=diff,
            lock_conflicts=lock_conflicts,
            compile_time=compile_elapsedtimes[1]/1e9,
            recompile_time=compile_elapsedtimes[2]/1e9
        )
    end
end

macro __tryfinally(ex, fin)
    Expr(:tryfinally,
       :($(esc(ex))),
       :($(esc(fin)))
       )
end

# function do_timing(f; fake=false)
function do_timing((@nospecialize f); fake=false)
    fake && return
    isbeta() && (tstart_running_time = Base.Experimental.task_running_time_ns())
    isbeta() && (tstart_wall_time = Base.Experimental.task_wall_time_ns())
    tstart = time()
    # @time f()
    # timed = @my_timed f()
    timed = goodtimer(f)
    running_time = isbeta() && !isnothing(tstart_running_time) ? (Base.Experimental.task_running_time_ns() - tstart_running_time) / 1e9 : 0.
    wall_time = isbeta() && !isnothing(tstart_wall_time) ? (Base.Experimental.task_wall_time_ns() - tstart_wall_time) / 1e9 : 0.
    time_time = time() - tstart
    return (; timed, running_time, wall_time, time_time)
end





function print_run(run)
    printstyled("running time: $(run.running_time)\n", color=:blue)
    printstyled("wall time: $(run.wall_time)\n", color=:blue)
    printstyled("time time: $(run.time_time)\n", color=:blue)
    print_timed(run.timed, run.running_time, run.time_time)
end


function print_timed(t, running_time, time_time)
    println("time: $(t.time)")
    println("gctime: $(t.gctime)")
    println("compile_time: $(t.compile_time)")
    println("recompile_time: $(t.recompile_time)")
    println("work_time: $(t.time - t.gctime - t.compile_time - t.recompile_time)")
    println("run_minus_gc: $(running_time - t.gctime)")
    UPPER_BOUND = time_time - t.gctime - t.safepoint_time
    printstyled("UPPER BOUND: $(UPPER_BOUND)\n", color=:green)
    LOWER_BOUND = max(0., time_time - t.gctime - t.safepoint_time - t.compile_time - t.recompile_time)
    printstyled("LOWER BOUND: $(LOWER_BOUND)\n", color=:green)
    printstyled("DIFF BOUND: $(UPPER_BOUND - LOWER_BOUND)\n", color=:green)
end




function print_gc(gcnum)
    for field in fieldnames(typeof(gcnum))
        println(field, ": ", getfield(gcnum, field))
    end
end


# work: .04
# compile: .02
# gc: .03

# total = running time if multithread, or time time if single thread. running time is time time minus sleep and such switches.






function compiles_a_lot_inner()
    x = []
    for i in 1:10000000
        if (log(abs(i*2 + 100 - i * i)) == 0) || (i % 10 == 0)
            push!(x, i)
        end
    end
    add_numbers(1, 2)

    # sleep(.1)
    # yield()
    # sleep(1.)
    return nothing
end

compiles_a_lot = compiles_a_lot_inner
