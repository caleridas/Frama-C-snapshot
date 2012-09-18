(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2012                                               *)
(*    CEA (Commissariat a l'�nergie atomique et aux �nergies              *)
(*         alternatives)                                                  *)
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

(** Model Registration *)

type t 
type model = t

type tuning = (model -> unit)

type registry = name:string -> 
  ?id:string -> ?descr:string -> 
  ?tuning:tuning list ->
  unit -> model

val register : registry
val set_parameter : model -> 'a Context.value -> 'a -> string -> unit

val get_id : model -> string
val get_name : model -> string
val get_descr : model -> string option
val get_emitter : model -> Emitter.t

val find : id:string -> model
val iter : (model -> unit) -> unit

val on_model : model -> (unit -> unit) -> unit
val with_model : model -> ('a -> 'b) -> 'a -> 'b
val get_model : unit -> model (** Current model *)

val directory : unit -> string (** Current model in ["-wp-out"] directory *)

module type Entries =
sig
  type key
  type data
  val name : string
  val compare : key -> key -> int
  val pretty : Format.formatter -> key -> unit
end

module type Registry =
sig
  type key
  type data

  val mem : key -> bool
  val find : key -> data
  val get : key -> data option
  val define : key -> data -> unit
    (** no redefinition ; circularity protected *)
  val update : key -> data -> unit
    (** set current value, with no protection *)
  val memoize : (key -> data) -> key -> data
    (** with circularity protection *)
  val compile : (key -> data) -> key -> unit
    (** with circularity protection *)

  val callback : (key -> data -> unit) -> unit

  val iter : (key -> data -> unit) -> unit
  val iter_sorted : (key -> data -> unit) -> unit
end    

module Index(E : Entries) : Registry 
  with type key = E.key 
  and type data = E.data

module type Key =
sig
  type t
  val compare : t -> t -> int
  val pretty : Format.formatter -> t -> unit
end

module type Data =
sig
  type key
  type data
  val name : string
  val compile : key -> data
end

module type Generator =
sig
  type key
  type data
  val get : key -> data
end

module Generator(K : Key)(D : Data with type key = K.t) : Generator 
  with type key = D.key
  and type data = D.data