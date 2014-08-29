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

module IntervalTree = Map.Make(struct
  type t = int64 * int64
  let compare (s1,e1) (s2,e2) =
    if Int64.compare s1 s2 >= 0 && Int64.compare e1 e2 < 0 then 0
    else if Int64.compare s1 s2 <= 0 && Int64.compare e1 e2 > 0 then 0
    else if Int64.compare s1 s2 > 0 then 1
    else -1
end)

type asmir_handle =
  {
    arch     : Bfdarch.architecture;
    bhp      : bhp;
    sections : (string * int64 * int64) IntervalTree.t;
  }

let update_disasm_buf handle bytes addr =
  let len = String.length bytes in
  update_disasm_info handle.bhp bytes len addr;
  handle

let string_of_insn handle addr =
  disasm handle addr

let toil arch get_exec addr =
  try
    (Disasm.disasm_instr arch get_exec addr)
  with Disasm_exc.DisasmException s -> begin
    Printf.eprintf "BAP unknown disasm_instr %Lx: %s" addr s;
    Printf.eprintf "disasm_instr %Lx: %s" addr s;
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

let byte_sequence_to_bil handle bytes addr =
  let handle = update_disasm_buf handle bytes addr in
  let len = String.length bytes in
  let end_addr = Int64.add addr (Int64.of_int len) in
  let get_exec a = String.get bytes (Int64.to_int (Int64.sub a addr)) in
  let rec read_all acc cur_addr =
    if cur_addr >= end_addr then List.rev acc
    else
      let prog, next = asm_addr_to_bil handle get_exec cur_addr in
      read_all (prog::acc) next
  in
  read_all [] addr

let find_section addr sections =
  IntervalTree.find (addr, addr) sections

let instr_to_bil handle addr =
  let data, s_addr, _e_addr = find_section addr handle.sections in
  let get_exec a =
    let offset = Int64.to_int (Int64.sub a s_addr) in
    String.get data offset
  in
  let (il, next_addr) as v = toil handle.arch get_exec addr in
  let offset = Int64.to_int (Int64.sub addr s_addr) in
  let len = Int64.to_int (Int64.sub next_addr addr) in
  let bytes = String.sub data offset len in
  let handle = update_disasm_buf handle bytes addr in
  update_asm v handle.bhp addr

let asmir_open ?arch:(arch=Bfdarch.Arch_i386) file =
  let bhp =
    match file with
      | Some file -> new_bfd_from_file file
      | None -> new_bfd_from_buf arch
  in
  let sections =
    List.fold_left (fun acc ((content, sa, ea) as tupl) ->
      IntervalTree.add (sa, ea) tupl acc
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

