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

type asmir_prog =
  {
    bfdp     : bfdp;
    disasp   : disasp;
  }

let byte_insn_to_asmp arch addr bytes =
  let bfdp = new_bfd "/dev/null" arch in
  let len = Array.length bytes in
  {
    bfdp = bfdp;
    disasp = new_disasm_info bfdp bytes len addr;
  }

let string_of_insn prog addr =
  disasm prog.bfdp prog.disasp addr

let asmir_close prog =
  delete_disasm_info prog.disasp;
  if delete_bfd prog.bfdp then ()
  else failwith "failed to close bfd handle"

let asm_addr_to_bil prog arch get_exec addr =
  let (ir, na) as v =
    (try (Disasm.disasm_instr arch get_exec addr)
     with Disasm_i386.Disasm_i386_exception s ->
       Printf.eprintf "BAP unknown disasm_instr %Lx: %s" addr s;
       Printf.eprintf "disasm_instr %Lx: %s" addr s;
       raise Disasm.Unimplemented
    )
  in
  (match ir with
    | Label (l, [])::rest ->
        (Label (l, [Asm (string_of_insn prog addr)])::rest, na)
    | _ -> v)

let byte_sequence_to_bil bytes arch addr =
  let prog = byte_insn_to_asmp arch addr bytes in
  let len = Array.length bytes in
  let end_addr = Int64.add addr (Int64.of_int len) in
  let get_exec a = bytes.(Int64.to_int (Int64.sub a addr)) in
  let rec read_all acc cur_addr =
    if cur_addr >= end_addr then List.rev acc
    else
      let prog, next = asm_addr_to_bil prog arch get_exec cur_addr in
      read_all (prog::acc) next
  in
  let il = read_all [] addr in
  asmir_close prog;
  il

