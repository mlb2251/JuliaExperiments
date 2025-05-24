"""
RustBackend.jl - Julia bindings for Rust backend functions

This module provides Julia wrappers for functions implemented in Rust.
"""
module RustBackend

export hello_world, greet, add_numbers

# Get the path to the dynamic library
const LIB_PATH = joinpath(@__DIR__, "target", "release", "librust_backend.dylib")

function __init__()
    # Check if the library exists
    if !isfile(LIB_PATH)
        error("Rust backend library not found at $LIB_PATH. Please run 'cargo build --release' in the rust_backend directory.")
    end
end

"""
    hello_world()

Calls the Rust hello_world function that prints "Hello World from Rust!"
"""
function hello_world()
    @ccall LIB_PATH.hello_world()::Cvoid
end

"""
    greet(name::String) -> Int

Calls the Rust greet function with a name and returns the length of the greeting message.
"""
function greet(name::String)
    # Convert Julia string to bytes for passing to Rust
    name_bytes = Vector{UInt8}(name)
    greeting_length = @ccall LIB_PATH.greet(pointer(name_bytes)::Ptr{Int8}, length(name_bytes)::UInt64)::UInt64
    return Int(greeting_length)
end

"""
    add_numbers(a::Integer, b::Integer) -> Int32

Simple addition function implemented in Rust for testing basic FFI.
"""
function add_numbers_unsafe(a::Integer, b::Integer)
    println("thread $(Threads.threadid()) entering add_numbers")
    result = @ccall LIB_PATH.add_numbers(Int32(a)::Int32, Int32(b)::Int32)::Int32
    println("thread $(Threads.threadid()) exiting add_numbers")
    return result
end

function add_numbers(a::Integer, b::Integer)
    println("thread $(Threads.threadid()) entering add_numbers")
    result = @ccall gc_safe=true LIB_PATH.add_numbers(Int32(a)::Int32, Int32(b)::Int32)::Int32
    println("thread $(Threads.threadid()) exiting add_numbers")
    return result
end

end # module RustBackend 