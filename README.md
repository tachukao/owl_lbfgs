# Owl_lbfgs

This is a simple module that interfaces [Lbfgs](https://github.com/Chris00/L-BFGS-ocaml/) with [Owl's](https://github.com/owlbarn/owl) `Algodiff` module.
To use this interface one begins with definig a cost function `f` using functions within the `Algodiff` module.
One definies an optimisation problem by putting `f` and initial parameters `init_prms` into a record with type
```ocaml
open Owl_lbfgs
type t = Algodiff.D.t
type problem_t : 
 | S {f: (t -> t); init_prms: t}
 | P {f: (t -> t -> t); init_prms: t * t}
 | T {f: (t -> t -> t -> t); init_prms: t * t * t}
 | M {f: (t array -> t); init_prms: t array}
```
Here `S`, `P`, `T`, and `M` corresponds to `f` taking a single, a pair, a triple, and an array of inputs respectively. 
Note that `init_prms` must also have the corresponding input type `t`, `t*t`, `t*t*t`, and `t array`.
After this one can simply call `minimise` on the problem defined:

* single input
```ocaml
let c, prms = minimise (S {f; init_prms})
let prm = unpack_s prms 
```

* pair inputs
```ocaml
let c, prms = minimise (P {f; init_prms})
let prm1, prm2 = unpack_p prms 
```

* three inputs
```ocaml
let c, prms = minimise (T {f; init_prms})
let prm = unpack_s prms 
```


* an array of inputs
```ocaml
let c, prms = minimise (M {f; init_prms})
let prms = unpack_m prms 
```

There's also the option of defining one's own `stop` function, which is used by `Lbfgs` as a function for determining when to stop. By default the `stop` function prints the iteration and the cost at every step.




