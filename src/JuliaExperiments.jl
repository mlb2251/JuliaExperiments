module JuliaExperiments

include("rust_backend/RustBackend.jl")
using .RustBackend

include("timing.jl")
include("thread_gc_timeout.jl")

end # module JuliaExperiments
