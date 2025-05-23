# Simple test file for thread and GC functionality
using Base.Threads

function test()
    res = add_numbers(10, 20)
    println("added numbers: 10 + 20 = $res")
end
