# Simple test file for thread and GC functionality
using Base.Threads

export test, rust_test

function rust_test()
    N = 2
    @assert Threads.nthreads() == 2 "This test requires multiple threads"

    println("Testing safe gc")
    Threads.@threads :greedy for i in 1:N
        if i % 2 == 0
            res, t = @ttime blackbox(rust_gc_safe)
            println("Expect 5 seconds")
            println("safe rust_gc_safe time: ", t)
            # @assert upper_bound(t)/1e9 > 5. "rust_busy should of course take 5 seconds"
        else
            res, t = @ttime blackbox(gc_busy)
            println("Expect <<5 seconds")
            println("safe gc_busy time: ", t)
            # @assert upper_bound(t)/1e9 < 5. "gc_busy should be quick"
        end
    end

    println("Testing unsafe gc")
    Threads.@threads :greedy for i in 1:N
        if i % 2 == 0
            res, t = @ttime blackbox(rust_gc_unsafe)
            println("Expect 5 seconds")
            println("unsafe rust_gc_unsafe time: ", t)
            # @assert upper_bound(t)/1e9 > 5. "rust_busy should of course take 5 seconds"
        else
            res, t = @ttime blackbox(gc_busy)
            println("Expect >>5 seconds")
            println("unsafe gc_busy time: ", t)
            # @assert upper_bound(t)/1e9 > 3. "gc_busy should compete with unsafe and take long"
        end
    end
end


function gc_busy()
    x = []
    for i in 1:100000000
        push!(x, i)
    end
    return nothing
end



function test()
    ttime_init() # must happen outside of @threads if you want to see task_metrics

    N = 4
    times = Vector{NamedTuple}(undef, N)
    @threads :greedy for i in 1:N
        # first time should be slow because it's compiling
        res, t1 = @ttime blackbox(compiles_a_lot)
        # second time should be fast because it's compiled
        res, t2 = @ttime blackbox(compiles_a_lot)
        times[i] = (; t1, t2)
    end

    for (i, (;t1, t2)) in enumerate(times)
        printstyled("workload $i: \n", color=:green)
        printstyled("first time: \n", color=:yellow)
        println(t1)
        printstyled("second time: \n", color=:yellow)
        println(t2)
    end

end


function compiles_a_lot()
    x = []
    for i in 1:1000000 # adjust iterations to change work time
        if (log(abs(i*2 + 100 - i * i)) == 0) || (i % 10 == 0) # adjust % (i mod _) to change gc time
            push!(x, i)
        end
    end
    return nothing
end
