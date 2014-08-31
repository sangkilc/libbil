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

open Bil

let _ =
  (* FIXME *)
  let bh = bil_open ~arch:Bfdarch.Arch_i386 None in
  let p = of_bytesequence bh [|'\xb9'; '\x00'; '\x45'; '\x41'; '\x00'|] 100L in
  print_program p;
  let p = of_bytesequence bh [|'\x31';'\xc0';'\x90'|] 0L in
  print_program p;
  bil_close bh

