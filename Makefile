

thread_gc_timeout: instantiate
	julia --project -e 'using JuliaExperiments; JuliaExperiments.test()'



instantiate: bindings
	julia --project -e 'using Pkg; Pkg.instantiate()'

bindings:
	cd src/rust_backend && cargo build --release