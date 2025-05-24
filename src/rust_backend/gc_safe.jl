function rust_gc_safe()
    res = @ccall gc_safe=true LIB_PATH.add_numbers(Int32(0)::Int32, Int32(4)::Int32)::Int32
    return nothing
end