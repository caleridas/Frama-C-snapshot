(**************************************************************************)
(*                                                                        *)
(*  Copyright (C) 2009 INRIA                                              *)
(*    INRIA (Institut National de Recherche en Informatique et en         *)
(*           Automatique)                                                 *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*                                                                        *)
(*  Redistribution and use in source and binary forms, with or without    *)
(*  modification, are permitted provided that the following conditions    *)
(*  are met:                                                              *)
(*    * Redistributions of source code must retain the above copyright    *)
(*      notice, this list of conditions and the following disclaimer.     *)
(*    * Redistributions in binary form must reproduce the above           *)
(*      copyright notice, this list of conditions and the following       *)
(*      disclaimer in the documentation and/or other materials provided   *)
(*      with the distribution.                                            *)
(*    * Neither the name of the <organization> nor the names of its       *)
(*      contributors may be used to endorse or promote products derived   *)
(*      from this software without specific prior written permission.     *)
(*                                                                        *)
(*  THIS SOFTWARE IS PROVIDED BY <INRIA> ''AS IS'' AND ANY                *)
(*  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE     *)
(*  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR    *)
(*  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL <copyright holder> BE       *)
(*  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR   *)
(*  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT     *)
(*  OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR    *)
(*  BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF            *)
(*  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT             *)
(*  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE     *)
(*  USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH      *)
(*  DAMAGE.                                                               *)
(*                                                                        *)
(**************************************************************************)

(* caml_unmarshal by Ineffable Casters *)

(* Version 3.11.1.9 *)


(* Warning:

   If you are new to OCaml, don't take this as an example of good code.

*)

open Printf;;

type t =
  | Abstract
  | Structure of structure
  | Transform of t * (Obj.t -> Obj.t)
  | Return of t * (unit -> Obj.t)
  | Dynamic of (unit -> t)
and structure = Sum of t array array | Array of t

;;

let arch_sixtyfour = Sys.word_size = 64;;
let arch_bigendian = (Obj.magic [| 0x00002600 |] : string).[1] <> 'L';;
let arch_float_endianness = (Obj.magic 1.23530711838574823e-307 : string).[1];;

let intext_magic_number = "\x84\x95\xA6\xBE";;

let ill_formed () = failwith "input_value: ill-formed message"

let zeroword = Obj.field (Obj.repr 0L) 0;;
let null = zeroword;;

let id x = x;;

(* Functions for deserializers. *)

let getword ch =
  let c3 = Char.code (input_char ch) in
  let c2 = Char.code (input_char ch) in
  let c1 = Char.code (input_char ch) in
  let c0 = Char.code (input_char ch) in
  Int32.logor (Int32.shift_left (Int32.of_int c3) 24)
              (Int32.of_int ((c2 lsl 16) lor (c1 lsl 8) lor c0))
;;

let read8s ch =
  let c = Char.code (input_char ch) in
  if c < 128 then c else c lor (-1 lsl 8)
;;

let read16s ch =
  let c1 = Char.code (input_char ch) in
  let c0 = Char.code (input_char ch) in
  let c1x = if c1 < 128 then c1 else c1 lor (-1 lsl 8) in
  (c1x lsl 8) lor c0
;;

let read32s ch =
  let c3 = Char.code (input_char ch) in
  let c2 = Char.code (input_char ch) in
  let c1 = Char.code (input_char ch) in
  let c0 = Char.code (input_char ch) in
  let c3x = if c3 < 128 then c3 else c3 lor (-1 lsl 8) in
  (c3x lsl 24) lor (c2 lsl 16) lor (c1 lsl 8) lor c0
;;

let read64s =
  if arch_sixtyfour then begin
    fun ch ->
      let c7 = Char.code (input_char ch) in
      let c6 = Char.code (input_char ch) in
      let c5 = Char.code (input_char ch) in
      let c4 = Char.code (input_char ch) in
      let c3 = Char.code (input_char ch) in
      let c2 = Char.code (input_char ch) in
      let c1 = Char.code (input_char ch) in
      let c0 = Char.code (input_char ch) in
      (c7 lsl 56) lor (c6 lsl 48) lor (c5 lsl 40) lor (c4 lsl 32)
      lor (c3 lsl 24) lor (c2 lsl 16) lor (c1 lsl 8) lor c0
  end else begin
    fun _ -> failwith "input_value: integer too large"
  end
;;

let read8u ch = Char.code (input_char ch);;

let read16u ch =
  let c1 = Char.code (input_char ch) in
  let c0 = Char.code (input_char ch) in
  (c1 lsl 8) lor c0
;;

let read32u ch =
  let c3 = Char.code (input_char ch) in
  let c2 = Char.code (input_char ch) in
  let c1 = Char.code (input_char ch) in
  let c0 = Char.code (input_char ch) in
  (c3 lsl 24) lor (c2 lsl 16) lor (c1 lsl 8) lor c0
;;

let read64u = read64s;;

let readheader32 ch =
  let c3 = Char.code (input_char ch) in
  let c2 = Char.code (input_char ch) in
  let c1 = Char.code (input_char ch) in
  let c0 = Char.code (input_char ch) in
  (c0, (c1 lsr 2) lor (c2 lsl 6) lor (c3 lsl 14))
;;

let readheader64 =
  if arch_sixtyfour then begin
    fun ch ->
      let c7 = Char.code (input_char ch) in
      let c6 = Char.code (input_char ch) in
      let c5 = Char.code (input_char ch) in
      let c4 = Char.code (input_char ch) in
      let c3 = Char.code (input_char ch) in
      let c2 = Char.code (input_char ch) in
      let c1 = Char.code (input_char ch) in
      let c0 = Char.code (input_char ch) in
      (c0, (c1 lsr 2) lor (c2 lsr 6) lor (c3 lsr 14) lor (c4 lsr 22)
           lor (c5 lsr 30) lor (c6 lsr 38) lor (c7 lsr 46))
  end else begin
    fun _ -> failwith "input_value: data block too large"
  end
;;

let readblock ch dest ofs len =
  unsafe_really_input ch (Obj.obj dest : string) ofs len
;;

let readblock_rev ch dest ofs len =
  for i = len - 1 + ofs downto ofs do
    String.unsafe_set (Obj.obj dest : string) i (input_char ch);
  done
;;

(* Auxiliary functions for handling floats. *)

let readfloat_same ch v i = readblock ch v (i * 8) 8;;

let readfloat_reverse ch v i = readblock_rev ch v (i * 8) 8;;

let readfloat_little =
  match arch_float_endianness with
  | '1' -> readfloat_same
  | '6' -> readfloat_reverse
  | '5' ->
     begin
       fun ch v i ->
       readblock ch v (i * 8 + 4) 4;
       readblock ch v (i * 8) 4;
     end
  | _ -> fun _ch _v _i -> failwith "input_value: non-standard floats"
;;

let readfloat_big =
  match arch_float_endianness with
  | '1' -> readfloat_reverse
  | '6' -> readfloat_same
  | '5' ->
     begin
       fun ch v i ->
       readblock_rev ch v (i * 8) 4;
       readblock_rev ch v (i * 8 + 4) 4;
     end
  | _ -> fun _ch _v _i -> failwith "input_value: non-standard floats"
;;

(* Auxiliary functions for handling closures. *)

let raw_value_big32 x =
  let result = Obj.dup (Obj.repr 0L) in
  Obj.set_field result 2 (Obj.repr x);
  (Obj.obj result : Int64.t)
;;

let raw_value_other x =
  let result = Obj.dup (Obj.repr 0L) in
  Obj.set_field result 1 (Obj.repr x);
  (Obj.obj result : Int64.t)
;;

let raw_value =
  if arch_bigendian && not arch_sixtyfour
  then raw_value_big32
  else raw_value_other
;;

let value_raw_big32 x = Obj.field (Obj.repr x) 2;;
let value_raw_other x = Obj.field (Obj.repr x) 1;;

let value_raw =
  if arch_bigendian && not arch_sixtyfour
  then value_raw_big32
  else value_raw_other
;;

(* Note: this is buggy if we're unlucky with the GC.
   To do it correctly, we need a primitive to add an offset to a value. *)
let obj_add_offset v ofs =
  value_raw (Int64.add (raw_value v) (Int64.of_int32 ofs))
;;

let (code_area_start, cksum) =
  let s = Marshal.to_string id [Marshal.Closures] in
  let cksum = String.sub s 0x1E 16 in
  let c0 = Char.code s.[0x1D] in
  let c1 = Char.code s.[0x1C] in
  let c2 = Char.code s.[0x1B] in
  let c3 = Char.code s.[0x1A] in
  let ofs = Int32.logor (Int32.shift_left (Int32.of_int c3) 24)
                        (Int32.of_int ((c2 lsl 16) lor (c1 lsl 8) lor c0))
  in
  let start = obj_add_offset (Obj.field (Obj.repr id) 0) (Int32.neg ofs) in
  (start, cksum)
;;

let check_const ch s msg =
  for i = 0 to String.length s - 1 do
    if input_char ch <> s.[i] then failwith msg;
  done
;;

(* Auxiliary functions for handling Custom blocks. *)

let buflen = 100;;
let buf = String.create buflen;;
let bufs = ref [];;
let read_customident ch =
  let rec loop i =
    let c = input_char ch in
    if c = '\000' then begin
      if !bufs = []
      then String.sub buf 0 i
      else begin
        let res = String.concat "" (List.rev (String.sub buf 0 i :: !bufs)) in
        bufs := [];
        res
      end
    end else if i >= buflen then begin
      assert (i = buflen);
      bufs := String.copy buf :: !bufs;
      loop 0
    end else begin
      buf.[i] <- c;
      loop (i + 1)
    end
  in
  loop 0
;;

let custom_table =
  (Hashtbl.create 13 : (string, in_channel -> Obj.t) Hashtbl.t)
;;

let register_custom id f = Hashtbl.add custom_table id f;;

let read_custom ch id =
  try (Hashtbl.find custom_table id) ch
  with Not_found -> failwith ("input_value: unknown custom data type: " ^ id)
;;

(* Large arrays. *)

(* Wish there were a way to do it conditionally on Sys.word_size *)
module LA = struct
  type 'a t = 'a array array;;

  let inner_sz_log = 21;;
  let inner_sz = 1 lsl inner_sz_log;;
  let mask = inner_sz - 1;;

  let make size init =
    let outer_sz = size / inner_sz + 1 in
    let res = Array.make outer_sz [| |] in
    let rec loop sz i =
      if sz > inner_sz then begin
        res.(i) <- Array.make inner_sz init;
        loop (sz - inner_sz) (i + 1);
      end else begin
        res.(i) <- Array.make sz init;
      end
    in
    loop size 0;
    res
  ;;

  let get a i = a.(i asr inner_sz_log).(i land mask);;
  let set a i v = a.(i asr inner_sz_log).(i land mask) <- v;;
end

(* Main function. *)

type frame = {
  st_ty : t;
  st_ctr : int;
  st_constr : int;
  mutable st_cur : int;
  st_obj : Obj.t;
};;

let rec get_field_type t tag i =
  match t with
  | Abstract -> Abstract
  | Structure (Sum a) -> a.(tag).(i)
  | Structure (Array a) -> a
  | Transform (t1, _) -> get_field_type t1 tag i
  | Return (t1, _) -> get_field_type t1 tag i
  | Dynamic _ -> assert false
;;

let rec do_transform t v =
  match t with
  | Abstract | Structure _ -> v
  | Transform (t1, f) -> f (do_transform t1 v)
  | Return (t1, f) -> ignore (do_transform t1 v); f ()
  | Dynamic _ -> assert false
;;

let rec get_structure t context =
  match t with
  | Abstract | Structure _ -> (t, context)
  | Transform (t1, _) -> get_structure t1 true
  | Return (t1, _) -> get_structure t1 false
  | Dynamic _ -> assert false
;;

let input_val ch t =
  set_binary_mode_in ch true;
  check_const ch intext_magic_number "input_value: bad object";
  let _block_len = getword ch in
  let num_objects = read32u ch in
  let _size_32 = getword ch in
  let _size_64 = getword ch in
  let tbl = LA.make num_objects null in
  let patch = LA.make num_objects [] in

  let ctr = ref 0 in

  let rec intern_rec stk t =
    match t with
    | Dynamic f -> intern_rec stk (f ())
    | _ ->
       let code = read8u ch in
       match code with

       | 0x00 (* CODE_INT8 *) ->
          let v = Obj.repr (read8s ch) in
          return stk (do_transform t v)
       | 0x01 (* CODE_INT16 *) ->
          let v = Obj.repr (read16s ch) in
          return stk (do_transform t v)
       | 0x02 (* CODE_INT32 *) ->
          let v = Obj.repr (read32s ch) in
          return stk (do_transform t v)
       | 0x03 (* CODE_INT64 *) ->
          if arch_sixtyfour then begin
            let v = Obj.repr (read64s ch) in
            return stk (do_transform t v)
          end else begin
            failwith "input_value: integer too large"
          end

       | 0x04 (* CODE_SHARED8 *) ->
          let ofs = read8u ch in
          read_shared stk ofs
       | 0x05 (* CODE_SHARED16 *) ->
          let ofs = read16u ch in
          read_shared stk ofs
       | 0x06 (* CODE_SHARED32 *) ->
          let ofs = read32u ch in
          read_shared stk ofs

       | 0x08 (* CODE_BLOCK32 *) ->
          let (tag, size) = readheader32 ch in
          read_block stk t tag size
       | 0x13 (* CODE_BLOCK64 *) ->
          let (tag, size) = readheader64 ch in
          read_block stk t tag size

       | 0x09 (* CODE_STRING8 *) ->
          let len = read8u ch in
          read_string stk t len
       | 0x0A (* CODE_STRING32 *) ->
          let len = read32u ch in
          read_string stk t len

       | 0x0C (* CODE_DOUBLE_LITTLE *) ->
          read_double stk t readfloat_little
       | 0x0B (* CODE_DOUBLE_BIG *) ->
          read_double stk t readfloat_big
       | 0x0E (* CODE_DOUBLE_ARRAY8_LITTLE *) ->
          let len = read8u ch in
          read_double_array stk t len readfloat_little
       | 0x0D (* CODE_DOUBLE_ARRAY8_BIG *) ->
          let len = read8u ch in
          read_double_array stk t len readfloat_big
       | 0x07 (* CODE_DOUBLE_ARRAY32_LITTLE *) ->
          let len = read32u ch in
          read_double_array stk t len readfloat_little
       | 0x0F (* CODE_DOUBLE_ARRAY32_BIG *) ->
          let len = read32u ch in
          read_double_array stk t len readfloat_big

       | 0x10 (* CODE_CODEPOINTER *) ->
          let ofs = getword ch in
          check_const ch cksum "input_value: code mismatch";
          return stk (do_transform t (obj_add_offset code_area_start ofs))
       | 0x11 (* CODE_INFIXPOINTER *) ->
          let ofs = getword ch in
          let clos = intern_rec [] t in
          return stk (obj_add_offset clos ofs)

       | 0x12 (* CODE_CUSTOM *) ->
          let id = read_customident ch in
          let v = read_custom ch id in
          let dest = !ctr in
          ctr := dest + 1;
          return_block stk t v dest

       | _ when code >= 0x80 (* PREFIX_SMALL_BLOCK *) ->
          let tag = code land 0xF in
          let size = (code lsr 4) land 0x7 in
          read_block stk t tag size
       | _ when code >= 0x40 (* PREFIX_SMALL_INT *) ->
          let v = Obj.repr (code land 0x3F) in
          return stk (do_transform t v)
       | _ when code >= 0x20 (* PREFIX_SMALL_STRING *) ->
          let len = code land 0x1F in
          read_string stk t len

       | _ -> ill_formed ()

  and read_block stk t tag size =
    (* read one block of the given tag and size *)
    let (t1, alloc) = get_structure t true in
    begin match t1 with
    | Abstract -> ()
    | Structure (Sum a) ->
       if tag >= Array.length a
          || size != Array.length a.(tag)
       then ill_formed ()
    | Structure (Array _) -> ()
    | _ -> assert false
    end;
    let v = if alloc then Obj.new_block tag size else Obj.repr size in
    if size > 0 then begin
      let fr = {
        st_ty = t;
        st_ctr = !ctr;
        st_constr = tag;
        st_cur = 0;
        st_obj = v;
      } in
      let t2 = get_field_type t tag 0 in
      ctr := !ctr + 1;
      intern_rec (fr :: stk) t2
    end else begin
      return stk (do_transform t v)
    end

  and read_string stk t len =
    let v = Obj.repr (String.create len) in
    readblock ch v 0 len;
    let dest = !ctr in
    ctr := dest + 1;
    return_block stk t v dest

  and read_double stk t readfloat =
    let v = Obj.dup (Obj.repr 1.0) in
    readfloat ch v 0;
    let dest = !ctr in
    ctr := dest + 1;
    return_block stk t v dest

  and read_double_array stk t len readfloat =
    let v = Obj.repr (Array.make len 0.0) in
    for i = 0 to len - 1 do readfloat ch v i done;
    let dest = !ctr in
    ctr := dest + 1;
    return_block stk t v dest

  and read_shared stk ofs =
    if ofs <= 0 || ofs > !ctr then ill_formed ();
    let v = LA.get tbl (!ctr - ofs) in
    if v == null then begin
      match stk with
      | [] -> assert false
      | f :: _ ->
         let p = LA.get patch (!ctr - ofs) in
         LA.set patch (!ctr - ofs) ((f.st_ctr, f.st_cur) :: p);
         return stk null
    end else begin
      return stk v
    end

  and return stk v =
    match stk with
    | [] -> Obj.obj v
    | f :: stk1 ->
       let sz = if Obj.is_int f.st_obj
                then (Obj.obj f.st_obj : int)
                else begin
                  Obj.set_field f.st_obj f.st_cur v;
                  Obj.size f.st_obj
                end
       in
       f.st_cur <- f.st_cur + 1;
       if f.st_cur >= sz
       then return_block stk1 f.st_ty f.st_obj f.st_ctr
       else intern_rec stk (get_field_type f.st_ty f.st_constr f.st_cur)

  and return_block stk t v dest =  (* call alloc, patch, and return *)
    let res = do_transform t v in
    LA.set tbl dest res;
    let f (ix, ofs) = Obj.set_field (LA.get tbl ix) ofs res in
    List.iter f (LA.get patch dest);
    LA.set patch dest [];
    return stk res

  in intern_rec [] t
;;

(* Functions for handling Int32, Int64, and Nativeint custom blocks. *)

let readint64_little32 ch =
  let result = Obj.dup (Obj.repr 0L) in
  readblock_rev ch result 4 8;
  result
;;

let readint64_big32 ch =
  let result = Obj.dup (Obj.repr 0L) in
  readblock ch result 4 8;
  result
;;

let readint64_little64 ch =
  let result = Obj.dup (Obj.repr 0L) in
  readblock_rev ch result 8 8;
  result
;;

let readint64_big64 ch =
  let result = Obj.dup (Obj.repr 0L) in
  readblock ch result 8 8;
  result
;;

register_custom "_j"
  (if arch_bigendian then
     if arch_sixtyfour then readint64_big64 else readint64_big32
   else
     if arch_sixtyfour then readint64_little64 else readint64_little32
  )
;;

let readint32_little32 ch =
  let result = Obj.dup (Obj.repr 0l) in
  readblock_rev ch result 4 4;
  result
;;

let readint32_big32 ch =
  let result = Obj.dup (Obj.repr 0l) in
  readblock ch result 4 4;
  result
;;

let readint32_little64 ch =
  let result = Obj.dup (Obj.repr 0l) in
  readblock_rev ch result 8 4;
  result
;;

let readint32_big64 ch =
  let result = Obj.dup (Obj.repr 0l) in
  readblock ch result 8 4;
  result
;;

register_custom "_i"
  (if arch_bigendian then
     if arch_sixtyfour then readint32_big64 else readint32_big32
   else
     if arch_sixtyfour then readint32_little64 else readint32_little32
  )
;;

let readnativeint_little32 ch =
  let code = read8u ch in
  let result = Obj.dup (Obj.repr 0n) in
  if code = 1 then (readblock_rev ch result 4 4; result)
  else if code = 2 then failwith "input_value: native integer value too large"
  else failwith "input_value: ill-formed native integer"
;;

let readnativeint_big32 ch =
  let code = read8u ch in
  let result = Obj.dup (Obj.repr 0n) in
  if code = 1 then (readblock ch result 4 4; result)
  else if code = 2 then failwith "input_value: native integer value too large"
  else failwith "input_value: ill-formed native integer"
;;

let readnativeint_little64 ch =
  let code = read8u ch in
  let result = Obj.dup (Obj.repr 0n) in
  if code = 1 then (readblock_rev ch result 8 4; result)
  else if code = 2 then (readblock_rev ch result 8 8; result)
  else failwith "input_value: ill-formed native integer"
;;

let readnativeint_big64 ch =
  let code = read8u ch in
  let result = Obj.dup (Obj.repr 0n) in
  if code = 1 then (readblock ch result 12 4; result)
  else if code = 2 then (readblock ch result 8 8; result)
  else failwith "input_value: ill-formed native integer"
;;

register_custom "_n"
  (if arch_bigendian then
     if arch_sixtyfour then readnativeint_big64 else readnativeint_big32
   else
     if arch_sixtyfour then readnativeint_little64 else readnativeint_little32
  )
;;

let t_int = Abstract;;
let t_string = Abstract;;
let t_float = Abstract;;
let t_bool = Abstract;;
let t_int32 = Abstract;;
let t_int64 = Abstract;;
let t_nativeint = Abstract;;

let t_record args = Structure (Sum [| args |]);;
let t_tuple = t_record;;
let t_list a = let rec x = Structure (Sum [| [| a; x |] |]) in x;;
let t_ref a = t_record [| a |];;
let t_option = t_ref;;

let t_array a = Structure (Array a)

(**** Hash tables ***)

type ('a, 'b) caml_hashtable =
  { mutable size: int;                        (* number of elements *)
    mutable data: ('a, 'b) bucketlist array } (* the buckets *)

and ('a, 'b) bucketlist =
    Empty
  | Cons of 'a * 'b * ('a, 'b) bucketlist

(* version 1: loading keys do not change their hash value *)
let t_hashtbl_unchangedhashs key value =
  let rec bucket = Structure (Sum [| [| key; value; bucket |] |]) in
  t_record [| Abstract ; t_array bucket |]

(* version 2: keys change hash value in the unmarshalling+transformation *)
let t_hashtbl_changedhashs key value create add =
  Dynamic 
    (fun () ->
      let new_hashtbl = create 27 in
      (* Pascal -> Damien: Si tu me garantis que les champs d'un constructeur
	 sont parcourus dans l'ordre, je peux cr�er la table directement de la
	 bonne taille *)

      let rec bucket = 
	Transform
	  (Structure (Sum [| [| key; value; bucket |] |]),
	  fun cell -> 
	    ( match Obj.obj cell with
	      Empty -> ()
	    | Cons (k, v, _) ->
		add new_hashtbl k v);
	    Obj.repr Empty
	  )
      in
      Return (t_record [| Abstract ; t_array bucket |], new_hashtbl))