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

open LibBil
open Arch

type load_method =
  | LoadBytes (* just consider the file as a byte sequence *)
  | LoadExec  (* parse the file as an ELF executable *)

let current_method = ref LoadBytes

let load_bytes file =
  let bh = bil_open ~arch:X86_32 None in
  let bytes = Util.load_file file in
  let p = of_bytesequence bh bytes Big_int_Z.zero_big_int in
  print_program p;
  bil_close bh

let load_exec file =
  let bh = bil_open ~arch:X86_32 (Some file) in
  let entry = entry_point bh in
  let p, next = of_addr bh (Big_int_Z.big_int_of_int64 entry) in
  print_program [p];
  bil_close bh

let file_to_il file =
  match !current_method with
    | LoadBytes -> load_bytes file
    | LoadExec -> load_exec file

let specs =
  [
    ("-bytes",
     Arg.Unit (fun () -> current_method := LoadBytes),
     " consider the file as a byte sequence");
    ("-exec",
     Arg.Unit (fun () -> current_method := LoadExec),
     " consider the file as an ELF executable");
    ("--", Arg.Rest file_to_il, " specify files to load");
  ]

let anon x = raise(Arg.Bad("Bad argument: '"^x^"'"))

let usage = "Usage: "^Sys.argv.(0)^" <options>\n"

let _ =
  let () = Printexc.record_backtrace true in
  try
    Arg.parse (Arg.align specs) anon usage
  with e ->
    Printexc.print_backtrace stderr

