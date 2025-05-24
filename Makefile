

THREADS=2

beta-ffi-gc:
	julia +1.12.0-beta3 -t$(THREADS) --project -e 'using JuliaExperiments; JuliaExperiments.rust_test()'

stable-ffi-gc:
	julia +1.11.4 -t$(THREADS) --project -e 'using JuliaExperiments; JuliaExperiments.rust_test()'


beta:
	julia +1.12.0-beta3 -t$(THREADS) --project -e 'using JuliaExperiments; JuliaExperiments.test()'

stable:
	julia +1.11.4 -t$(THREADS) --project -e 'using JuliaExperiments; JuliaExperiments.test()'



instantiate: bindings
	julia --project -e 'using Pkg; Pkg.instantiate()'

bindings:
	cd src/rust_backend && cargo build --release