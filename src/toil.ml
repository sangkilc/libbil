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

type load_method =
  | LoadBytes (* just consider the file as a byte sequence *)
  | LoadExec  (* parse the file as an ELF executable *)

let current_method = ref LoadBytes

let load_bytes file =
  let bh = bil_open ~arch:I386 None in
  let bytes = Util.load_file file in
  let p = of_bytesequence bh bytes 0L in
  print_program p;
  bil_close bh

let load_exec file =
  let bh = bil_open ~arch:I386 (Some file) in
  let entry = entry_point bh in
  let p, next = of_addr bh entry in
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

