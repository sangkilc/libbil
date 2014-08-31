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

open Ast
open Type
open Libbfd

type asmir_handle =
  {
    arch     : Bfdarch.architecture;
    bfdp     : bfdp;
    disasp   : disasp;
  }

let update_disasm_buf bh bytes addr =
  let len = Array.length bytes in
  update_disasm_info bh.disasp bytes len addr;
  bh

let string_of_insn prog addr =
  disasm prog.bfdp prog.disasp addr

let asm_addr_to_bil bh get_exec addr =
  let (ir, na) as v =
    (try (Disasm.disasm_instr bh.arch get_exec addr)
     with Disasm_i386.Disasm_i386_exception s ->
       Printf.eprintf "BAP unknown disasm_instr %Lx: %s" addr s;
       Printf.eprintf "disasm_instr %Lx: %s" addr s;
       raise Disasm.Unimplemented
    )
  in
  (match ir with
    | Label (l, [])::rest ->
        (Label (l, [Asm (string_of_insn bh addr)])::rest, na)
    | _ -> v)

let byte_sequence_to_bil bh bytes addr =
  let bh = update_disasm_buf bh bytes addr in
  let len = Array.length bytes in
  let end_addr = Int64.add addr (Int64.of_int len) in
  let get_exec a = bytes.(Int64.to_int (Int64.sub a addr)) in
  let rec read_all acc cur_addr =
    if cur_addr >= end_addr then List.rev acc
    else
      let prog, next = asm_addr_to_bil bh get_exec cur_addr in
      read_all (prog::acc) next
  in
  read_all [] addr

let asmir_open ?arch:(arch=Bfdarch.Arch_i386) file =
  let bfdp =
    match file with
      | Some file -> new_bfd_from_file file
      | None -> new_bfd_from_buf arch
  in
  let disasp = new_disasm_info bfdp in
  {
    arch = arch;
    bfdp = bfdp;
    disasp = disasp
  }

let asmir_close handle =
  delete_disasm_info handle.disasp;
  delete_bfd handle.bfdp

