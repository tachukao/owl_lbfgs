open Bigarray
open Owl
module AD = Algodiff.D

type n_inputs_t = One | Two | Three | Many

type input_t =
  | SI of AD.t
  | PI of AD.t * AD.t
  | TI of AD.t * AD.t * AD.t
  | MI of AD.t array

type problem_t =
  | S of {f: AD.t -> AD.t; init_prms: AD.t}
  | P of {f: AD.t -> AD.t -> AD.t; init_prms: AD.t * AD.t}
  | T of {f: AD.t -> AD.t -> AD.t -> AD.t; init_prms: AD.t * AD.t * AD.t}
  | M of {f: AD.t array -> AD.t; init_prms: AD.t array}

type prms_info =
  { n_inputs: n_inputs_t;
    n_prms: int;
    summary: (int * int * int array * int) array }

let unpack_s = function SI x -> x | _ -> assert false
let unpack_p = function PI (x1, x2) -> (x1, x2) | _ -> assert false
let unpack_t = function TI (x1, x2, x3) -> (x1, x2, x3) | _ -> assert false
let unpack_m = function MI x -> x | _ -> assert false
let wrap_s_f f x = f (unpack_s x)

let wrap_p_f f x =
  let x1, x2 = unpack_p x in
  f x1 x2

let wrap_t_f f x =
  let x1, x2, x3 = unpack_t x in
  f x1 x2 x3

let wrap_m_f f x = f (unpack_m x)

let build_prms_info prms =
  let n_inputs, prms =
    match prms with
    | SI prm ->
        (One, [|prm|])
    | PI (prm1, prm2) ->
        (Two, [|prm1; prm2|])
    | TI (prm1, prm2, prm3) ->
        (Three, [|prm1; prm2; prm3|])
    | MI prms ->
        (Many, prms)
  in
  let i = ref 0 in
  let summary =
    Array.map
      (fun prm ->
        let open AD in
        let idx = !i in
        let l, s, t =
          match prm with
          | F _ ->
              (1, [|1|], 0)
          | Arr _ ->
              (numel prm, shape prm, 1)
          | _ ->
              assert false
        in
        i := !i + l ;
        (idx, l, s, t) )
      prms
  in
  let n_prms = Array.fold_left (fun a (_, b, _, _) -> a + b) 0 summary in
  {n_inputs; summary; n_prms}

(* Lbfgs prms to Owl prm array *)
let extract_prms ~prms_info prms =
  let prms =
    Array.map
      (fun (idx, l, s, t) ->
        assert (t = 0 || t = 1) ;
        if t = 0 then AD.pack_flt (Array1.get prms idx)
        else
          Array1.sub prms idx l |> genarray_of_array1
          |> (fun x -> reshape x s)
          |> AD.pack_arr )
      prms_info.summary
  in
  match prms_info.n_inputs with
  | One ->
      SI prms.(0)
  | Two ->
      PI (prms.(0), prms.(1))
  | Three ->
      TI (prms.(0), prms.(1), prms.(2))
  | Many ->
      MI prms

(* blit a: Algodiff.t into b: Array1.t *)
let blit ~prms_info extract src dst =
  let src =
    match src with
    | SI x ->
        [|x|]
    | PI (x1, x2) ->
        [|x1; x2|]
    | TI (x1, x2, x3) ->
        [|x1; x2; x3|]
    | MI x ->
        x
  in
  let dst =
    Array.map
      (fun (idx, l, s, _) ->
        Array1.sub dst idx l |> genarray_of_array1 |> fun x -> reshape x s )
      prms_info.summary
  in
  let open AD in
  Array.iter2
    (fun a b ->
      match extract a with
      | F x ->
          Genarray.set b [|0|] x
      | Arr x ->
          Genarray.blit x b
      | _ ->
          assert false )
    src dst

let default_callback ~every st _prms =
  let k = Lbfgs.iter st in
  let cost = Lbfgs.previous_f st in
  if k mod every = 0 then (
    Gc.minor () ;
    Printf.printf "iteration %6i | cost = %10.5f\n%!" k cost ) ;
  false

let minimise ?(pgtol = 0.) ?(factr = 1E9) ?(corrections = 20)
    ?(callback = default_callback ~every:1) problem =
  let f, prms0 =
    match problem with
    | S {f; init_prms} ->
        (wrap_s_f f, SI init_prms)
    | P {f; init_prms} ->
        (wrap_p_f f, PI (fst init_prms, snd init_prms))
    | T {f; init_prms} ->
        let a, b, c = init_prms in
        (wrap_t_f f, TI (a, b, c))
    | M {f; init_prms} ->
        (wrap_m_f f, MI init_prms)
  in
  let prms_info = build_prms_info prms0 in
  let open AD in
  let f_df x g =
    let x = extract_prms ~prms_info x in
    let t = tag () in
    let x =
      match x with
      | SI x ->
          SI (make_reverse x t)
      | PI (x1, x2) ->
          PI (make_reverse x1 t, make_reverse x2 t)
      | TI (x1, x2, x3) ->
          TI (make_reverse x1 t, make_reverse x2 t, make_reverse x3 t)
      | MI x ->
          MI (Array.map (fun x -> make_reverse x t) x)
    in
    let c = f x in
    reverse_prop (F 1.) c ; blit ~prms_info adjval x g ; unpack_flt c
  in
  let prms =
    let x =
      reshape_1 Owl.Arr.(zeros [|1; prms_info.n_prms|]) prms_info.n_prms
    in
    (*Array1.(create float64 c_layout total_n_prms) in*)
    blit ~prms_info primal prms0 x ;
    x
  in
  let stop st =
    let prms = extract_prms ~prms_info prms in
    let b = callback st prms in
    Gc.minor () ; b
  in
  Lbfgs.(C.min ~print:No ~pgtol ~factr ~corrections ~stop f_df prms |> ignore) ;
  let prms = extract_prms ~prms_info prms in
  (unpack_flt (f prms), prms)
