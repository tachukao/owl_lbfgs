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
 | M {f: (t array -> t); init_prms: t array}
```
Here `S`, `P`, and `M` corresponds to `f` taking 1 input, 2 inputs, and multiple (an array of) inputs respectively. 
Note that `init_prms` must also have the corresponding input type `t`, `t*t` and `t array`.
After this one can simply call `minimise` on the problem defined:
```ocaml
let problem = S {f; init_prms}
let c, prms = minimise problem
```
This function returns cost and the final parameters. To extract the parameters `prms` corresponding to each input type, one can use:

S: 
```ocaml
let prm = unpack_s prms 
```
P:
```ocaml
let prm1, prm2 = unpack_p prms
```
M:
```ocaml
let prms = unpack_m prms
```

There's also the option of defining one's own `stop` function, which is used by `Lbfgs` as a function for determining when to stop. By default the `stop` function prints the iteration and the cost at every step.




