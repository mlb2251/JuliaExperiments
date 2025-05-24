"""
RustBackend.jl - Julia bindings for Rust backend functions

This module provides Julia wrappers for functions implemented in Rust.
"""
module RustBackend

export hello_world, greet, rust_gc_unsafe, rust_gc_safe

# Get the path to the dynamic library
const LIB_PATH = joinpath(@__DIR__, "target", "release", "librust_backend.dylib")

function __init__()
    # Check if the library exists
    if !isfile(LIB_PATH)
        error("Rust backend library not found at $LIB_PATH. Please run 'cargo build --release' in the rust_backend directory.")
    end
end

function rust_gc_unsafe()
    res = @ccall LIB_PATH.add_numbers(Int32(0)::Int32, Int32(4)::Int32)::Int32
    return nothing
end

if VERSION >= v"1.12.0-beta3"
    include("gc_safe.jl")
end



end # module RustBackend 