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
open Arch
open Type
open Big_int_convenience
open Bfdwrap
open Big_int_Z

module IntervalTree = Map.Make(struct

  type t = string * addr * addr

  let compare (_,s1,e1) (_,s2,e2) =
    if compare_big_int s1 s2 >= 0 && compare_big_int e1 e2 < 0 then 0
    else if compare_big_int s1 s2 <= 0 && compare_big_int e1 e2 > 0 then 0
    else if compare_big_int s1 s2 > 0 then 1
    else -1
end)

type asmir_handle =
  {
    arch     : arch;
    bhp      : bhp;
    sections : (string * addr * addr) IntervalTree.t;
  }

let update_disasm_buf handle bytes addr =
  let len = String.length bytes in
  update_disasm_info handle.bhp bytes len (addr_to_int64 addr);
  handle

let string_of_insn handle addr =
  disasm handle (addr_to_int64 addr)

let toil arch get_exec addr =
  try
    (Disasm.disasm_instr arch get_exec addr)
  with Disasm_exc.DisasmException s -> begin
    Printf.eprintf "BAP unknown disasm_instr %s: %s" (~%addr) s;
    Printf.eprintf "disasm_instr %s: %s" (~%addr) s;
    raise Disasm.Unimplemented
  end

let update_asm ((ir, next_addr) as v) bhp addr =
  match ir with
    | Label (l, [])::rest ->
        (Label (l, [Asm (string_of_insn bhp addr)])::rest, next_addr)
    | _ ->
        v

let asm_addr_to_bil handle get_exec addr =
  let v = toil handle.arch get_exec addr in
  update_asm v handle.bhp addr

let byte_sequence_to_bil handle bytes (addr:Type.addr) =
  (* assume that byte sequence has a correct size (no extra bytes) *)
  let handle = update_disasm_buf handle bytes addr in
  let len = String.length bytes in
  let end_addr = addr +% (big_int_of_int len) in
  let get_exec a = String.get bytes (int_of_big_int (a -% addr)) in
  let rec read_all acc cur_addr =
    if cur_addr >= end_addr then List.rev acc
    else
      let prog, next = asm_addr_to_bil handle get_exec cur_addr in
      read_all ((prog, (next -% cur_addr))::acc) next
  in
  read_all [] addr

let byte_sequence_to_stmt handle bytes (addr:Type.addr) =
  let handle = update_disasm_buf handle bytes addr in
  let get_exec a = String.get bytes (int_of_big_int (a -% addr)) in
  asm_addr_to_bil handle get_exec addr

let find_section addr sections =
  IntervalTree.find ("", addr, addr) sections

let instr_to_bil handle (addr:Type.addr) =
  let data, s_addr, _e_addr = find_section addr handle.sections in
  let get_exec a =
    let offset = int_of_big_int (a -% s_addr) in
    String.get data offset
  in
  let (il, next_addr) as v = toil handle.arch get_exec addr in
  let offset = int_of_big_int (addr -% s_addr) in
  let len = int_of_big_int (next_addr -% addr) in
  let bytes = String.sub data offset len in
  let handle = update_disasm_buf handle bytes addr in
  update_asm v handle.bhp addr

let arch_to_bfd = function
  | X86_32 -> Bfdarch.Arch_i386, 0
  | X86_64 -> Bfdarch.Arch_i386, (1 lsl 3) (* bfd_mach_x86_64 *)

let asmir_open arch file =
  let bhp =
    match file with
      | Some file -> new_bfd_from_file file
      | None -> BatPervasives.uncurry new_bfd_from_buf (arch_to_bfd arch)
  in
  let sections =
    List.fold_left (fun acc (content, sa, ea) ->
      let e = content, biconst64 sa, biconst64 ea in
      IntervalTree.add e e acc
    ) IntervalTree.empty (get_section_data bhp)
  in
  {
    arch = arch;
    bhp = bhp;
    sections = sections;
  }

let asmir_close handle =
  delete_bfd handle.bhp

let get_entry_point handle =
  get_entry_point handle.bhp

