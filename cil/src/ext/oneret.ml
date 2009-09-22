(**************************************************************************)
(*                                                                        *)
(*  Copyright (C) 2001-2003,                                              *)
(*   George C. Necula    <necula@cs.berkeley.edu>                         *)
(*   Scott McPeak        <smcpeak@cs.berkeley.edu>                        *)
(*   Wes Weimer          <weimer@cs.berkeley.edu>                         *)
(*   Ben Liblit          <liblit@cs.berkeley.edu>                         *)
(*  All rights reserved.                                                  *)
(*                                                                        *)
(*  Redistribution and use in source and binary forms, with or without    *)
(*  modification, are permitted provided that the following conditions    *)
(*  are met:                                                              *)
(*                                                                        *)
(*  1. Redistributions of source code must retain the above copyright     *)
(*  notice, this list of conditions and the following disclaimer.         *)
(*                                                                        *)
(*  2. Redistributions in binary form must reproduce the above copyright  *)
(*  notice, this list of conditions and the following disclaimer in the   *)
(*  documentation and/or other materials provided with the distribution.  *)
(*                                                                        *)
(*  3. The names of the contributors may not be used to endorse or        *)
(*  promote products derived from this software without specific prior    *)
(*  written permission.                                                   *)
(*                                                                        *)
(*  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS   *)
(*  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT     *)
(*  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS     *)
(*  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE        *)
(*  COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,   *)
(*  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,  *)
(*  BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;      *)
(*  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER      *)
(*  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT    *)
(*  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN     *)
(*  ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE       *)
(*  POSSIBILITY OF SUCH DAMAGE.                                           *)
(*                                                                        *)
(*  File modified by CEA (Commissariat � l'�nergie Atomique).             *)
(**************************************************************************)

(*
 *
 * Copyright (c) 2001-2002,
 *  George C. Necula    <necula@cs.berkeley.edu>
 *  Scott McPeak        <smcpeak@cs.berkeley.edu>
 *  Wes Weimer          <weimer@cs.berkeley.edu>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 * 1. Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 *
 * 3. The names of the contributors may not be used to endorse or promote
 * products derived from this software without specific prior written
 * permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 * IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
 * OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *)

(* Make sure that there is exactly one Return statement in the whole body.
 * Replace all the other returns with Goto. This is convenient if you later
 * want to insert some finalizer code, since you have a precise place where
 * to put it *)
open Cil_types
open Cilutil
open Cil

let dummyVisitor = new nopCilVisitor

let oneret (f: fundec) : unit =
  let fname = f.svar.vname in
  (* Get the return type *)
  let retTyp =
    match f.svar.vtype with
      TFun(rt, _, _, _) -> rt
    | _ ->
	Cilmsg.abort "Function %s does not have a function type" f.svar.vname
  in
  (* Does it return anything ? *)
  let hasRet = match unrollType retTyp with TVoid _ -> false | _ -> true in

  (* Memoize the return result variable. Use only if hasRet *)
  let lastloc = ref locUnknown in
  let retVar : varinfo option ref = ref None in
  let getRetVar (_x: unit) : varinfo =
      match !retVar with
	Some rv ->
(*	  Format.printf "variable %s glob %b formal %b function_scope%b@."
	    rv.vname
	    rv.vglob
	    rv.vformal
	    rv.vfunction_scope; *)
	  if not rv.vglob && not rv.vformal
	  then rv.vfunction_scope <- true;
	  rv
      | None -> begin
            let rv = makeLocalVar f "__retres" retTyp in (* don't collide *)
	    rv.vfunction_scope <- true;
            retVar := Some rv;
            rv
	end
  in
  (* Remember if we have introduced goto's *)
  let haveGoto = ref false in
  (* Memoize the return statement *)
  let retStmt : stmt ref = ref dummyStmt in
  let getRetStmt (_x: unit) : stmt =
    if !retStmt == dummyStmt then begin
      (* Must create a statement *)
      let rv =
        if hasRet then Some (new_exp(Lval(Var (getRetVar ()), NoOffset)))
        else None
      in
      let sr =
        let getLastLoc () = (* CEA modified to have a good [!lastloc] *)
          let rec setLastLoc = function
            | [] -> ()
            | {skind=Block b} :: [] -> setLastLoc b.bstmts
            | {skind=UnspecifiedSequence seq}::[] ->
                setLastLoc (List.map (fun (x,_,_,_) -> x) seq)
            | {skind=s} :: [] -> lastloc := get_stmtLoc s
            | {skind=_s} :: l -> setLastLoc l
          in setLastLoc f.sbody.bstmts; !lastloc
        in
        mkStmt (Return (rv, getLastLoc ()))
      in retStmt := sr;
        sr
    end else
      !retStmt
  in
  (* Now scan all the statements. Know if you are the main body of the
   * function and be prepared to add new statements at the end *)
  let rec scanStmts (mainbody: bool) = function
    | [] when mainbody -> (* We are at the end of the function. Now it is
                           * time to add the return statement *)
        let rs = getRetStmt () in
        if !haveGoto then
          rs.labels <- (Label("return_label", !lastloc, false)) :: rs.labels;
        [rs]

    | [] -> []

    | [{skind=Return (Some ({enode = Lval(Var rv,NoOffset)}), _l)} as s]
        when mainbody && not !haveGoto
          ->
	if not rv.vglob && not rv.vformal
	then rv.vfunction_scope <- true;
	[s]

    | ({skind=Return (retval, l)} as s) :: rests ->
        (*CEA currentLoc := l; *)
(*
        ignore (E.log "Fixing return(%a) at %a\n"
                  insert
                  (match retval with None -> text "None"
                  | Some e -> d_exp () e)
                  d_loc l);
*)
        if hasRet && retval = None then
          (Cil.error "Found return without value in function %s" fname) ;
	if not hasRet && retval <> None then
          (Cil.error "Found return in subroutine %s" fname);
        (* Keep this statement because it might have labels. But change it to
         * an instruction that sets the return value (if any). *)
        s.skind <- begin
           match retval with
             Some rval -> Instr (Set((Var (getRetVar ()), NoOffset), rval, l))
           | None -> Instr (Skip (*locUnknown*)l)
        end;
        (* See if this is the last statement in function *)
        if mainbody && rests == [] then
          s :: scanStmts mainbody rests
        else begin
          (* Add a Goto *)
          let sgref = ref (getRetStmt ()) in
          let sg = mkStmt (Goto (sgref, l)) in
          haveGoto := true;
          s :: sg :: (scanStmts mainbody rests)
        end

    | ({skind=If(eb,t,e,l)} as s) :: rests ->
        (*CEA currentLoc := l;*)
        s.skind <- If(eb, scanBlock false t, scanBlock false e, l);
        s :: scanStmts mainbody rests
    | ({skind=Loop(a,b,l,lb1,lb2)} as s) :: rests ->
        (*CEA currentLoc := l;*)
        s.skind <- Loop(a,scanBlock false b, l,lb1,lb2);
        s :: scanStmts mainbody rests
    | ({skind=Switch(e, b, cases, l)} as s) :: rests ->
        (*CEA currentLoc := l;*)
        s.skind <- Switch(e, scanBlock false b, cases, l);
        s :: scanStmts mainbody rests
    | ({skind=Block b} as s) :: rests ->
        s.skind <- Block (scanBlock false b);
        s :: scanStmts mainbody rests
    | ({skind = UnspecifiedSequence seq} as s) :: rests ->
        s.skind <-
          UnspecifiedSequence
          (List.concat
             (List.map (fun (s,m,w,r) ->
                          let res = scanStmts false [s] in
                          (List.hd res,m,w,r)::
                            (List.map (fun x -> x,[],[],[]) (List.tl res)))
                seq));
        s::scanStmts mainbody rests
    | ({skind=(Goto _ | Instr _ | Continue _ | Break _
               | TryExcept _ | TryFinally _)} as s)
      :: rests -> s :: scanStmts mainbody rests

  and scanBlock (mainbody: bool) (b: block) =
    { b with bstmts = scanStmts mainbody b.bstmts;}

  in
  (*CEA since CurrentLoc isn't set
    ignore (visitCilBlock dummyVisitor f.sbody) ; *)(* sets CurrentLoc *)
  (*CEA so, [scanBlock] will set [lastloc] when necessary
    lastloc := !currentLoc ;  *) (* last location in the function *)
  f.sbody <- scanBlock true f.sbody