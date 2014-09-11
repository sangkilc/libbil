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

(** libBIL handle *)
type t

(** libBIL architecture *)
type arch =
  | I386
  | Amd64

val bil_open : ?arch:arch -> string option -> t

val bil_close : t -> unit

val of_bytesequence : t -> string -> Type.addr -> Ast.stmt list list

val of_addr : t -> Type.addr -> Ast.stmt list * int64

val entry_point : t -> int64

val print_program : Ast.program list -> unit

