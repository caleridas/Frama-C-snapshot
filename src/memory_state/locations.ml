(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2009                                               *)
(*    CEA (Commissariat � l'�nergie Atomique)                             *)
(*                                                                        *)
(*  you can redistribute it and/or modify it under the terms of the GNU   *)
(*  Lesser General Public License as published by the Free Software       *)
(*  Foundation, version 2.1.                                              *)
(*                                                                        *)
(*  It is distributed in the hope that it will be useful,                 *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU Lesser General Public License for more details.                   *)
(*                                                                        *)
(*  See the GNU Lesser General Public License version 2.1                 *)
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
(*                                                                        *)
(**************************************************************************)

(* $Id: locations.ml,v 1.87 2009-02-23 12:52:19 uid562 Exp $ *)

open Cil_types
open Cil
open Abstract_interp
open Abstract_value

open BaseUtils

module Initial_Values = struct
  let v = [ [Base.null,Ival.singleton_zero];
	    [Base.null,Ival.singleton_one];
	    [Base.null,Ival.zero_or_one];
	    [Base.null,Ival.top];
	    [Base.null,Ival.top_float];
	    [] ]
end

module BaseSetLattice = Make_Hashconsed_Lattice_Set(Base)

module MapLattice =
  Map_Lattice.Make(Base)(BaseSetLattice)(Ival)(Initial_Values)(struct let zone = false end)

module Location_Bytes = struct

  include MapLattice

  type z = t =
    | Top of Top_Param.t * Origin.t
    | Map of M.t

  let inject_ival i = inject Base.null i

  let top_float = inject_ival Ival.top_float

  let singleton_zero = inject_ival Ival.singleton_zero
  let singleton_one = inject_ival Ival.singleton_one
  let zero_or_one = inject_ival Ival.zero_or_one

  (* true iff [v] is exactly 0 *)
  let is_zero v = equal v singleton_zero

  (* [location_shift offset l] is the location [l] shifted by [offset] *)
  let location_shift offset l =
    try
      map_offsets (Ival.add offset) l
    with Error_Top -> l

  let top_leaf_origin () =
    Top(Top_Param.top,
	(Origin.Leaf (LocationSetLattice.currentloc_singleton())))

 let topify_with_origin o v =
   let result =
   match v with
   | Top (s,a) ->
       Top (s, Origin.join a o)
   | v when is_zero v -> v
   | Map m ->
       if is_bottom v then v
       else inject_top_origin o (get_bases m)
   in
(*   Format.printf "topify_with_origin : %a %a -> %a@."
     Origin.pretty o
     pretty v
     pretty result;*)
   result

 let get_bases m =
   match m with
   | Top(top_param,_) -> top_param
   | Map m -> Top_Param.inject (get_bases m)

 let under_topify v =
     match v with
   | Top _ -> v
   | Map _ ->
       if is_included singleton_zero v
       then singleton_zero
       else bottom

 let topify_merge_origin v =
   topify_with_origin (Origin.Merge (LocationSetLattice.currentloc_singleton())) v

 let topify_misaligned_read_origin v =
   topify_with_origin (Origin.Misalign_read (LocationSetLattice.currentloc_singleton())) v

 let topify_arith_origin v =
   topify_with_origin (Origin.Arith (LocationSetLattice.currentloc_singleton())) v

 let is_included_actual_generic bases q instanciation v1 v2 =
   let null_1, v1 = split Base.null v1 in
   let null_2, v2 = split Base.null v2 in
   Ival.is_included_exn null_1 null_2;
   try
     (*Format.printf "LB.is_included_actual_generic: v1: %a v2: %a@\n"
       pretty v1
       pretty v2; *)
     let base, offs = find_lonely_key v2 in
     if Base.is_hidden_variable base
     then begin
   (*    Format.printf "LB.is_included_actual_generic: hidden var %a@\n"
	 Base.pretty base; *)
       try
	 let base_val = BaseMap.find base !instanciation in
	 if not (cardinal_zero_or_one base_val)
	 then raise Is_not_included;
	 if not (equal v1 (location_shift offs base_val))
	 then raise Is_not_included;
       with Not_found ->
	 (* check non-aliasing condition between, on the one hand,
	    the new value for the hidden variable [base]
	    and on the other hand, the generic in/outs of the function
	    plus already instanciated hidden variables*)
	 fold_bases
	   (fun b () ->
	      if BaseSet.mem b bases then raise Is_not_included;
	      BaseMap.fold
		(fun _bi vi () ->
		  fold_bases
		    (fun vib () ->
(*		      Format.printf "comparing bases %a %a@."
			Base.pretty b
			Base.pretty vib;*)
		      if Base.compare b vib = 0
		      then raise Is_not_included)
		    vi
		    ())
		!instanciation
		())
	   v1
	   ();
	 let new_val = location_shift (Ival.neg offs) v1 in
	 instanciation := BaseMap.add base new_val !instanciation;
(*	 Format.printf "LB.is_included_actual_generic: %a in? %a@\n"
	   Base.pretty base
	   BaseSet.pretty bases; *)
	 if BaseSet.mem base bases
	 then q := BaseSet.add base !q;
     end
     else is_included_exn v1 v2
   with Not_found (* from find_lonely_key *) ->
     is_included_exn v1 v2

 let may_reach base loc =
   if Base.is_null base then true else
     match loc with
     | Top (toparam,_) -> Top_Param.is_included (Top_Param.inject_singleton base) toparam
     | Map m -> try
         ignore (M.find base m);
         true
       with Not_found -> false

 exception Contains_local


 let contains_addresses_of_locals is_local =
   let f base _offsets = is_local base
   in
   let projection _base = Ival.top in
   let cached_f =
     cached_fold
       ~cache:("loc_top_locals", 653)
       ~f
       ~projection
       ~joiner:(||)
       ~empty:false
   in
   fun loc ->
     try
       cached_f loc
     with Error_Top ->
       assert (match loc with
       | Top (Top_Param.Top,_) -> true
       | Top (Top_Param.Set _top_param,_orig) ->
	   false
       | Map _ -> false);
       true

 (**  TODO: merge with above function *)
   let remove_escaping_locals is_local v =
    match v with
    | Top (Top_Param.Top,_) -> v
    | Top (Top_Param.Set topparam,orig) ->
        inject_top_origin
          orig
          (Top_Param.O.filter
             (fun base -> not (is_local base))
             topparam)
    | Map m ->
        Map (M.fold (fun base _ acc ->
                  if is_local base then
                    M.remove base acc
                  else acc)
          m
          m)

 let contains_addresses_of_any_locals =
   let f base _offsets = Base.is_any_formal_or_local base
   in
   let projection _base = Ival.top in
   let cached_f =
     cached_fold
       ~cache:("loc_top_any_locals", 777)
       ~f
       ~projection
       ~joiner:(||)
       ~empty:false
   in
   fun loc ->
     try
       cached_f loc
     with Error_Top ->
       assert (match loc with
       | Top (Top_Param.Top,_) -> true
       | Top (Top_Param.Set _top_param,_orig) ->
	   false
       | Map _ -> false);
       true

end

module Location_Bits = Location_Bytes

module Zone = struct

  module Initial_Values = struct let v = [ [] ] end

  include Map_Lattice.Make(Base)(BaseSetLattice)(Int_Intervals)(Initial_Values)
  (struct let zone = true end)

  let default base bi ei = inject base (Int_Intervals.inject [bi,ei])
  let defaultall base = inject base Int_Intervals.top

  let pretty fmt m =
    match m with
    | Top (Top_Param.Top,a) ->
	Format.fprintf fmt "ANYTHING(origin:%a)"
	  Origin.pretty a
    | Top (s,a) ->
	Format.fprintf fmt "Unknown(%a, origin:%a)"
	  Top_Param.pretty s
	  Origin.pretty a
    | Map _ when equal m bottom ->
	Format.fprintf fmt "\\nothing@ "
    | Map off ->
	let print_binding k v =
	  Format.fprintf fmt "@[<h>%a%a;@,@]@ " Base.pretty k
            (Int_Intervals.pretty_typ (Base.typeof k)) v
	in
	(M.iter print_binding) off
(*
  let pretty_caml fmt m =
    match m with
    | Top (Top_Param.Top,a) ->
	assert false (* TODO *)
    | Top (s,a) ->
	assert false (* TODO *)
    | Map _ when equal m bottom ->
	Format.fprintf "Locations.Zone.bottom"
    | Map off ->
	Format.fprintf "Locations.Zone.inject_list [";
	let print_binding k v =
	  Format.fprintf fmt "@[%a,@ %a;@,]@ "
	    Base.pretty_caml k
            Int_Intervals.pretty_caml v
	in
	(M.iter print_binding) off
*)
  let out_some_or_bottom zone =
    match zone with
      | None -> bottom
      | Some l -> l

  let id = "Zone"

  let tag = hash


  exception Found_inter

  let valid_intersects m1 m2 =
    let result =
      match m1,m2 with
      | Map _, Map _ ->
	  intersects m1 m2
      | Top (toparam, _), m | m, Top (toparam, _) ->
	  (equal m bottom) ||
	    let f base () =
	      if Top_Param.is_included (Top_Param.inject_singleton base) toparam
	      then raise Found_inter
	    in
	    try
	      fold_bases f m ();
	      false
	    with Found_inter | Error_Top -> true
    in
    result

 let get_bases m =
   match m with
   | Top(top_param,_) -> top_param
   | Map m -> Top_Param.inject (get_bases m)

end

exception Not_valid

module Location__ = Datatype.Couple(Location_Bits.Datatype)(Int_Base.Datatype)

type location =
    { loc : Location_Bits.t;
      size : Int_Base.t }

module Location =
struct
  module Datatype =
    Project.Datatype.Register
      (struct
	type t = location
	let copy _x = assert false
	let rehash { loc = loc ; size = size } =
	  { loc = Location_Bits.Datatype.rehash loc ;
	    size = Int_Base.Datatype.rehash size }
	let descr = Unmarshal.Abstract (* TODO: use Data.descr *)
	let name = "Abstract Location"
      end)
end



let can_be_accessed {loc=loc;size=size} =
  try
    let size = Int_Base.project size in
    match loc with
      | Location_Bits.Top _ -> false
      | Location_Bits.Map m ->
          Location_Bits.M.iter
            (fun varid offset ->
               match Base.validity varid with
               | Base.Known (min_valid,max_valid) | Base.Unknown (min_valid,max_valid)->
                   let min = Ival.min_int offset in
                   begin match min with
                   | None -> raise Not_valid
                   | Some v -> if Int.lt v min_valid then raise Not_valid
                   end;
                   let max = Ival.max_int offset in
                   begin match max with
                   | None -> raise Not_valid
                   | Some v ->
                       if Int.gt (Int.pred (Int.add v size)) max_valid then
                         raise Not_valid
                   end
               | Base.All -> ())
            m;
          true
  with
    | Int_Base.Error_Top | Int_Base.Error_Bottom | Not_valid -> false

let is_valid {loc=loc;size=size} =
  try
    let size = Int_Base.project size in
    let is_valid_offset = Base.is_valid_offset size in
    match loc with
      | Location_Bits.Top _ -> false
      | Location_Bits.Map m ->
          Location_Bits.M.iter is_valid_offset m;
          true
  with
  | Int_Base.Error_Top | Int_Base.Error_Bottom 
  | Base.Not_valid_offset -> false

exception Found_two

let valid_cardinal_zero_or_one {loc=loc;size=size} =
  Location_Bits.equal Location_Bits.bottom loc ||
    let found_one =
      let already = ref false in
      function () ->
	if !already then raise Found_two;
	already := true
    in
    try
    let size = Int_Base.project size in
    match loc with
      | Location_Bits.Top _ -> false
      | Location_Bits.Map m ->
          Location_Bits.M.iter
            (fun base offset ->
	       let inter =
		 match Base.validity base with
		 | Base.Known (min_valid,max_valid) | Base.Unknown (min_valid,max_valid) ->
		     let itv =
		       Ival.inject_range
			 (Some min_valid)
			 (Some (Int.succ (Int.sub max_valid size)))
		     in
		     Ival.narrow itv offset
		 | Base.All -> offset
	       in
	       if Ival.cardinal_zero_or_one inter
	       then begin
		 if not (Ival.equal inter Ival.bottom)
		 then found_one ()
	       end
	       else raise Found_two)
            m;
          true
  with
    | Int_Base.Error_Top -> false
    | Found_two -> false
    | Int_Base.Error_Bottom ->
        Format.printf "Bottom size for:%a@\n" Location_Bits.pretty loc;
        assert false



let loc_bytes_to_loc_bits x =
  match x with
    | Location_Bytes.Map _ ->
        begin try
          Location_Bytes.map_offsets
            (Ival.scale (Bit_utils.sizeofchar())) x
        with Location_Bytes.Error_Top -> assert false
        end
    | Location_Bytes.Top _ -> x

let loc_bits_to_loc_bytes x =
    match x with
      | Location_Bits.Map _ ->
          begin try
            Location_Bits.map_offsets
              (Ival.scale_div ~pos:true (Bit_utils.sizeofchar())) x
          with Location_Bits.Error_Top -> assert false
          end
      | Location_Bits.Top _ -> x

let loc_to_loc_without_size {loc = loc} =
  loc_bits_to_loc_bytes loc
let loc_size { size = size } = size

let make_loc loc_bits size =
  if (match size with
            | Int_Base.Value v -> Int.gt v Int.zero
            | _ -> true)
  then
    { loc = loc_bits; size = size }
  else
    { loc = loc_bits; size = Int_Base.top }

let loc_bits_to_loc lv (loc_bits:Location_Bits.t) =
  let size = Bit_utils.sizeof_lval lv in
  make_loc loc_bits size

let size_of_varinfo =
  let h = Hashtbl.create 1000 in
  fun v ->
    try
      Hashtbl.find h v.vid
    with Not_found ->
      let s = bitsSizeOf v.vtype in
      Hashtbl.add h v.vid s ;
      s

let loc_of_varinfo v =
  let base = Base.create_varinfo v in
  make_loc
    (Location_Bits.inject base Ival.zero)
    (Int_Base.inject (Big_int.big_int_of_int (size_of_varinfo v)))

let loc_of_base v =
  make_loc
    (Location_Bits.inject v Ival.zero)
    (Base.bits_sizeof v)

let loc_of_typoffset v typ offset =
  try
    let offs, size = bitsOffset typ offset in
    let size = if size = 0 then
      Int_Base.top
    else Int_Base.inject (Int.of_int size)
    in
    make_loc
      (Location_Bits.inject v (Ival.of_int offs))
      size
  with SizeOfError _ ->
    make_loc
      (Location_Bits.inject v Ival.top)
      Int_Base.top

let loc_without_size_to_loc
    lv
    loc_without_size =
  loc_bits_to_loc
    lv
    (loc_bytes_to_loc_bits loc_without_size)

let loc_bottom = make_loc Location_Bits.bottom Int_Base.bottom

let cardinal_zero_or_one { loc = loc ; size = size } =
  Location_Bits.cardinal_zero_or_one loc &&
    Int_Base.cardinal_zero_or_one size

let loc_equal { loc = loc1 ; size = size1 } { loc = loc2 ; size = size2 } =
  Int_Base.equal size1 size2 &&
  Location_Bits.equal loc1 loc2

let pretty fmt { loc = loc ; size = size } =
  Format.fprintf fmt "%a (size:%a)"
    Location_Bits.pretty loc
    Int_Base.pretty size

let valid_enumerate_bits ({loc = loc_bits; size = size} as _arg)=
(*  Format.printf "valid_enumerate_bits:%a@\n" pretty _arg; *)
  let result = match loc_bits with
    | Location_Bits.Top (Location_Bits.Top_Param.Top, _) -> Zone.top
    | Location_Bits.Top (Location_Bits.Top_Param.Set s, _) ->
	(* Zone.inject_top_origin a s   [pc 2007/10] we used to do this,
 but let's be more agressive re "valid_" *)
(*	let compute_base base acc =
          let valid_base =
            match Base.validity base with
            | Base.Known (min_valid,max_valid) ->
		Int.le min_valid max_valid
	    | Base.All | Base.Unknown _ -> true
	  in
	  if valid_base
	  then Location_Bits.Top_Param.O.add base acc
	  else acc
        in
        Zone.inject_top_origin a
          (Location_Bits.Top_Param.O.fold
	      compute_base
	      s
	      (compute_base Base.null Location_Bits.Top_Param.O.empty))
 *)
        let compute_offset base acc =
          let valid_offset =
            match Base.validity base, size with
            | (Base.Known (min_valid,max_valid)|Base.Unknown (min_valid,max_valid)), Int_Base.Value size ->
(*		Format.printf "min_valid:%a@\nmax_valid:%a@."
		  Int.pretty min_valid
		  Int.pretty max_valid; *)
		let max_valid = Int.succ (Int.sub max_valid size) in
		Ival.inject_range (Some min_valid) (Some max_valid)
            | _,Int_Base.Bottom -> assert false
	    | Base.All,_ | _,Int_Base.Top -> Ival.top
	  in
	  if Ival.equal Ival.bottom valid_offset
	  then acc
	  else
            let valid_offset = Int_Intervals.from_ival_size valid_offset size
            in
            Zone.M.add base valid_offset acc
        in
        Zone.inject_map
          (Location_Bits.Top_Param.O.fold compute_offset s Zone.M.empty)
    | Location_Bits.Map m ->
        let compute_offset base offs acc =
          let valid_offset =
            match Base.validity base, size with
            | (Base.Known (min_valid,max_valid)|Base.Unknown (min_valid,max_valid)), Int_Base.Value size ->
		let max_valid = Int.succ (Int.sub max_valid size) in
(*		Format.printf "min_valid:%a@\nmax_valid:%a@."
		  Int.pretty min_valid
		  Int.pretty max_valid; *)
		Ival.meet
		  (Ival.inject_range (Some min_valid) (Some max_valid))
		  offs
	    | (Base.All|Base.Unknown _|Base.Known _),_  -> offs
	  in
	  if Ival.equal Ival.bottom valid_offset
	  then acc
	  else
            let valid_offset = Int_Intervals.from_ival_size valid_offset size
            in
            Zone.M.add base valid_offset acc
        in
        Zone.inject_map
          (Location_Bits.M.fold compute_offset m Zone.M.empty)
  in
(*      Format.printf "valid_enumerate_bits leads to %a@\n" Zone.pretty result; *)
    result


(** [valid_part l] is an over-approximation of the valid part
   of the location [l] *)
let valid_part ({loc = loc; size = size } as l) =
(*  Format.printf "valid_part: loc=%a@." pretty l;*)
  match loc with
    | Location_Bits.Top _ -> l
    | Location_Bits.Map m ->
        let compute_offset base offs acc =
          let valid_offset =
            match Base.validity base, size with
            | (Base.Known (min_valid,max_valid)|Base.Unknown (min_valid,max_valid)), Int_Base.Value size ->
		let max_valid = Int.succ (Int.sub max_valid size) in
(*		Format.printf "min_valid:%a@\nmax_valid:%a@."
		  Int.pretty min_valid
		  Int.pretty max_valid; *)
		let valid_ival =
		  Ival.inject_range (Some min_valid) (Some max_valid)
		in
		let result = Ival.narrow offs valid_ival in
(*		Format.printf "base:%a offs:%a valid:%a result:%a@."
		  Base.pretty base
		  Ival.pretty offs
		  Ival.pretty valid_ival
		  Ival.pretty result; *)
		result

	    | (Base.All|Base.Unknown _|Base.Known _),_  -> offs
	  in
	  if Ival.equal Ival.bottom valid_offset
	  then acc
	  else
            Location_Bits.M.add base valid_offset acc
        in
        let loc =
	  Location_Bits.inject_map
            (Location_Bits.M.fold compute_offset m Location_Bits.M.empty)
	in
	make_loc loc size

(** [invalid_part l] is an over-approximation of the invalid part
   of the location [l] *)
let invalid_part l = l
(*  this implementation sucks, the complexity is too high.
   The function should fold on the bases instead of folding on the atomic
   locations
let invalid_part ({loc = loc; size = size } as l) =
    try
      let result =
	Location_Bits.fold_enum
	  (fun loc_bits acc ->
	    if not (can_be_accessed (make_loc loc_bits size))
	    then Location_Bits.join loc_bits acc
	    else acc)
	  loc
	  Location_Bits.bottom
      in
      make_loc result size
    with Location_Bits.Error_Top -> l *)

let filter_loc ({loc = loc; size = size } as initial) zone =
  try
    let result = Location_Bits.fold_i
      (fun base ival acc ->
         let result_ival =
           match zone,size with
           | Zone.Top _, _ | _,(Int_Base.Top|Int_Base.Bottom) -> ival
           | Zone.Map zone_m,Int_Base.Value size ->
               Int_Intervals.fold
                 (fun (bi,ei) acc ->
                    let width = Int.length bi ei in
                    if Int.lt width size 
		    then acc
                    else 
		      Ival.inject_range (Some bi) (Some (Int.length size ei)))
                 (Zone.find_or_bottom base zone_m)
                 Ival.bottom
         in
         Location_Bits.join acc (Location_Bits.inject base result_ival))
      loc
      Location_Bits.bottom
    in
    make_loc result size
  with Location_Bits.Error_Top -> initial

(*
Local Variables:
compile-command: "make -C ../.."
End:
*)