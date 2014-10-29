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
let current_arch = ref X86_32

let set_arch = function
  | "amd64" -> current_arch := X86_64
  | _ -> current_arch := X86_32

let load_bytes file =
  let bh = bil_open ~arch:!current_arch None in
  let bytes = Util.load_file file in
  let p = of_bytesequence bh bytes Big_int_Z.zero_big_int in
  print_program p;
  bil_close bh

let load_exec file =
  let bh = bil_open ~arch:!current_arch (Some file) in
  let entry = entry_point bh in
  let p, next = of_addr bh (Big_int_Z.big_int_of_int64 entry) in
  print_program [p];
  bil_close bh

let file_to_il file =
  match !current_method with
    | LoadBytes -> load_bytes file
    | LoadExec -> load_exec file

let hexstring_to_string hexstr =
  let hexchar prev curr =
    int_of_string (Printf.sprintf "0x%c%c" prev curr) |> char_of_int
  in
  let len = String.length hexstr in
  assert (len mod 2 = 0);
  let str = String.make (len / 2) '\x00' in
  let _ =
    BatString.fold_left (fun (pos, prev) ch ->
      match prev with
        | None -> pos, Some ch
        | Some prev -> str.[pos] <- (hexchar prev ch); pos+1, None
    ) (0, None) hexstr
  in
  str

let cmd_to_il arg =
  let bytes = hexstring_to_string arg in
  let bh = bil_open ~arch:!current_arch None in
  let p = of_bytesequence bh bytes Big_int_Z.zero_big_int in
  print_program p;
  bil_close bh

let specs =
  [
    ("-arch",
     Arg.String set_arch,
     " specify an architecture (x86|amd64|...)");
    ("-bytes",
     Arg.Unit (fun () -> current_method := LoadBytes),
     " consider the file as a byte sequence");
    ("-exec",
     Arg.Unit (fun () -> current_method := LoadExec),
     " consider the file as an ELF executable");
    ("-cmd",
     Arg.String cmd_to_il,
     " convert a cmd arg. into an il");
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

