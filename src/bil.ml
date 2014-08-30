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

let of_bytesequence bytes arch addr =
  byte_sequence_to_bil bytes arch addr

let print_program prog =
  List.iter (fun instr ->
    List.iter (fun stmt -> print_endline (Pp.ast_stmt_to_string stmt)) instr
  ) prog

