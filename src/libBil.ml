(** libBIL top-level interface

    @author Sang Kil Cha <sangkil.cha\@gmail.com>
*)
(*
    Copyright (c) 2014, Sang Kil Cha
    All rights reserved.
    This software is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License version 2, with the special exception on linking
    described in file LICENSE.

    This software is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
*)

open Disasm
open Asmir
open Arch

(* BIL type *)
type t = asmir_handle

let bil_open ?arch:(arch=X86_32) file =
  asmir_open arch file

let bil_close bh =
  asmir_close bh

let of_bytesequence bh bytes addr =
  byte_sequence_to_bil bh bytes addr

let of_addr bh addr =
  instr_to_bil bh addr

let entry_point bh =
  get_entry_point bh

let print_program prog =
  List.iter (fun instr ->
    List.iter (fun stmt -> print_endline (Pp.ast_stmt_to_string stmt)) instr
  ) prog

