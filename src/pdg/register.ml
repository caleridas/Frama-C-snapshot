(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2009                                               *)
(*    CEA   (Commissariat � l'�nergie Atomique)                           *)
(*    INRIA (Institut National de Recherche en Informatique et en         *)
(*           Automatique)                                                 *)
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
(*  See the GNU Lesser General Public License version v2.1                *)
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
(*                                                                        *)
(**************************************************************************)

let compute kf =
  let pdg = Build.compute_pdg kf in
      (* Annot.add_annotations kf pdg; *)
  pdg

let pretty ?(bw=false) fmt pdg =
    let kf = PdgTypes.Pdg.get_kf pdg in
    Format.fprintf fmt "@[RESULT for %s:@]@\n@[%a@]"
      (Kernel_function.get_name kf) (Print.pretty_pdg ~bw) pdg

let pretty_node short =
  if short then PdgTypes.Node.pretty
  else Print.pretty_node

let pretty_key = Print.pretty_key

let print_dot pdg filename =
  Print.build_dot filename pdg;
  Pdg_parameters.result "dot file generated in %s" filename

module Tbl =
  Kernel_function.Make_Table
    (PdgTypes.Pdg.Datatype)
    (struct
       let name = "Pdg.State"
       let dependencies = [] (* postponed *)
       let size = 97
    end)

let () =
  Cmdline.run_after_extended_stage
    (fun () ->
       let add = Project.Computation.add_dependency Tbl.self in
       add !Db.From.self)

(** Register external functions into Db. *)
let () =
  Db.Pdg.self := Tbl.self;
  Db.Pdg.get := Tbl.memo compute;
  Db.Pdg.node_key :=  PdgTypes.Node.elem_key;

  Db.Pdg.find_decl_var_node := Sets.find_decl_var_node;
  Db.Pdg.find_entry_point_node := Sets.find_entry_point_node;
  Db.Pdg.find_top_input_node := Sets.find_top_input_node;
  Db.Pdg.find_simple_stmt_nodes := Sets.find_simple_stmt_nodes;
  Db.Pdg.find_stmt_and_blocks_nodes := Sets.find_stmt_and_blocks_nodes;
  Db.Pdg.find_stmt_node := Sets.find_stmt_node;
  Db.Pdg.find_location_nodes_at_stmt := Sets.find_location_nodes_at_stmt;
  Db.Pdg.find_location_nodes_at_begin := Sets.find_location_nodes_at_begin;
  Db.Pdg.find_location_nodes_at_end := Sets.find_location_nodes_at_end;
  Db.Pdg.find_call_ctrl_node := Sets.find_call_ctrl_node;
  Db.Pdg.find_call_input_node := Sets.find_call_num_input_node;
  Db.Pdg.find_call_output_node := Sets.find_call_output_node;
  Db.Pdg.find_input_node := Sets.find_input_node;
  Db.Pdg.find_ret_output_node := Sets.find_output_node;
  Db.Pdg.find_output_nodes := Sets.find_output_nodes;
  Db.Pdg.find_all_inputs_nodes := Sets.find_all_input_nodes;

  Db.Pdg.find_call_stmts := Sets.find_call_stmts;

  Db.Pdg.find_code_annot_nodes := Annot.find_code_annot_nodes;
  Db.Pdg.find_fun_precond_nodes := Annot.find_fun_precond_nodes;
  Db.Pdg.find_fun_postcond_nodes := Annot.find_fun_postcond_nodes;

  Db.Pdg.find_call_out_nodes_to_select := Sets.find_call_out_nodes_to_select;
  Db.Pdg.find_in_nodes_to_select_for_this_call := 
         Sets.find_in_nodes_to_select_for_this_call;

  Db.Pdg.direct_dpds := Sets.direct_dpds;
  Db.Pdg.direct_ctrl_dpds := Sets.direct_ctrl_dpds;
  Db.Pdg.direct_data_dpds := Sets.direct_data_dpds;
  Db.Pdg.direct_addr_dpds := Sets.direct_addr_dpds;

  Db.Pdg.all_dpds := Sets.find_nodes_all_dpds;
  Db.Pdg.all_ctrl_dpds := Sets.find_nodes_all_ctrl_dpds;
  Db.Pdg.all_data_dpds := Sets.find_nodes_all_data_dpds;
  Db.Pdg.all_addr_dpds := Sets.find_nodes_all_addr_dpds;

  Db.Pdg.direct_uses := Sets.direct_uses;
  Db.Pdg.direct_ctrl_uses := Sets.direct_ctrl_uses;
  Db.Pdg.direct_data_uses := Sets.direct_data_uses;
  Db.Pdg.direct_addr_uses := Sets.direct_addr_uses;

  Db.Pdg.all_uses := Sets.all_uses;

  Db.Pdg.custom_related_nodes := Sets.custom_related_nodes;

  Db.Pdg.iter_nodes := PdgTypes.Pdg.iter_nodes;

  Db.Pdg.pretty := pretty ;
  Db.Pdg.pretty_node := pretty_node ;
  Db.Pdg.pretty_key := pretty_key ;
  Db.Pdg.extract := print_dot

  (*Db.Pdg.translate_marks_to_prop := Marks.add_new_marks_to_rqs*)

(* polymorphic functions : cannot be registered in Db.
* Can be used through Pdg.Register (see Pdg.mli) *)
let translate_marks_to_prop = Marks.translate_marks_to_prop
let call_out_marks_to_called = Marks.call_out_marks_to_called
let in_marks_to_caller = Marks.in_marks_to_caller
let translate_in_marks = Marks.translate_in_marks

module F_Proj (C : PdgMarks.T_Config) = Marks.F_Proj (C)

let main () =
  let force_pdg = 
    Pdg_parameters.BuildAll.get ()
    || not (Cilutil.StringSet.is_empty (Pdg_parameters.BuildFct.get ()))
  in
  if force_pdg then begin
    Pdg_parameters.feedback "in progress...";
    let do_kf_pdg kf =
      let fname = Kernel_function.get_name kf in
      if Pdg_parameters.BuildAll.get () ||
	Cilutil.StringSet.mem fname (Pdg_parameters.BuildFct.get ())
      then begin
	let pdg = !Db.Pdg.get kf in
        let dot_postdom = Pdg_parameters.DotPostdomBasename.get () in
          if dot_postdom <> "" then !Db.Postdominators.print_dot dot_postdom kf;
        let bw  = Pdg_parameters.PrintBw.get () in
	Pdg_parameters.result "@[%a@]" (!Db.Pdg.pretty ~bw) pdg;
	if Pdg_parameters.DotBasename.get () <> "" then
          !Db.Pdg.extract pdg
	    (Pdg_parameters.DotBasename.get ()^"."^fname^".dot")
      end
    in
    !Db.Semantic_Callgraph.topologically_iter_on_functions do_kf_pdg;
    if Pdg_parameters.BuildAll.get () then
      Pdg_parameters.feedback "====== PDG GRAPH COMPUTED ======";
  end

let () = Db.Main.extend main

(*
  Local Variables:
  compile-command: "LC_ALL=C make -C ../.. -j"
  End:
*)