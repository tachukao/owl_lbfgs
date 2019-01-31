open Owl

module AD = Algodiff.D

type n_inputs_t = 
  | One
  | Two
  | Three
  | Many

type input_t =
  | SI  of  AD.t
  | PI  of  AD.t * AD.t
  | TI  of  AD.t * AD.t * AD.t
  | MI  of  AD.t array

type problem_t = 
  | S of {f: (AD.t -> AD.t); init_prms: AD.t}
  | P of {f: (AD.t -> AD.t -> AD.t); init_prms: (AD.t * AD.t)}
  | T of {f: (AD.t -> AD.t -> AD.t -> AD.t); init_prms: (AD.t * AD.t * AD.t)}
  | M of {f: (AD.t array -> AD.t) ; init_prms: (AD.t array)}

type prms_info = { 
  n_inputs: n_inputs_t; 
  n_prms: int; 
  summary: (int * int * int array * int) array
}

(* helper function to extract single input *)
val unpack_s : input_t -> AD.t

(* helper function to extract pair inputs *)
val unpack_p : input_t -> AD.t * AD.t

(* helper function to extract triple inputs *)
val unpack_t : input_t -> AD.t * AD.t * AD.t

(* helper function to extract array inputs *)
val unpack_m : input_t -> AD.t array

(* default stop function *)
val default_stop : every:int -> Lbfgs.state -> bool

(* main function for minimisation *)
val minimise : 
  ?pgtol:float -> 
  ?factr:float -> 
  ?corrections:int -> 
  ?stop:(Lbfgs.state -> bool) ->
  problem_t ->
  float * input_t


