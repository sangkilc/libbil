(** ocamlbuild script *)
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

open Ocamlbuild_plugin
open Ocamlbuild_pack

(* these functions are not really officially exported *)
let run_and_read = Ocamlbuild_pack.My_unix.run_and_read
let blank_sep_strings = Ocamlbuild_pack.Lexers.blank_sep_strings

let split s ch =
  let x = ref [] in
  let rec go s =
    let pos = String.index s ch in
    x := (String.before s pos)::!x;
    go (String.after s (pos + 1))
  in
  try
    go s
  with Not_found -> !x

let split_nl s = split s '\n'

let before_space s =
  try
    String.before s (String.index s ' ')
  with Not_found -> s

(* this lists all supported packages *)
let find_packages () =
  List.map before_space (split_nl & run_and_read "ocamlfind list")

(* ocamlfind command *)
let ocamlfind x = S[A"ocamlfind"; x]

(* camlidl command *)
let camlidl = S([A"camlidl"])

(* ocaml path *)
let ocamlpath = List.hd & split_nl & run_and_read "ocamlfind printconf path"

(* camlidl path *)
let camlidl_path = List.hd & split_nl & run_and_read "ocamlfind query camlidl"

let _ = dispatch begin function
  | Before_options ->

      (* override default commands by ocamlfind ones *)
      Options.ocamlc     := ocamlfind & A"ocamlc";
      Options.ocamlopt   := ocamlfind & A"ocamlopt";
      Options.ocamldep   := ocamlfind & A"ocamldep";
      Options.ocamldoc   := ocamlfind & A"ocamldoc";
      Options.ocamlmktop := ocamlfind & A"ocamlmktop";

      (* taggings *)
      tag_any
        ["pkg_str";
         "pkg_unix";
         "pkg_zarith";
         "pkg_batteries";
         "pkg_ocamlgraph";
        ];

      tag_file "libbfd/bfdwrap_stubs.c" ["stubs"];
      tag_file "libbfd/bfdarch_stubs.c" ["stubs"];

  | After_rules ->

      flag ["ocaml"; "link"; "program"] & A"-linkpkg";

      (* For each ocamlfind package one inject the -package option when
       * compiling, computing dependencies, generating documentation and
       * linking. *)
      List.iter begin fun pkg ->
        flag ["ocaml"; "compile";  "pkg_"^pkg] & S[A"-package"; A pkg];
        flag ["ocaml"; "ocamldep"; "pkg_"^pkg] & S[A"-package"; A pkg];
        flag ["ocaml"; "doc";      "pkg_"^pkg] & S[A"-package"; A pkg];
        flag ["ocaml"; "link";     "pkg_"^pkg] & S[A"-package"; A pkg];
        flag ["ocaml"; "infer_interface"; "pkg_"^pkg] & S[A"-package"; A pkg];
      end (find_packages ());

      (* The default "thread" tag is not compatible with ocamlfind.
         Indeed, the default rules add the "threads.cma" or "threads.cmxa"
         options when using this tag. When using the "-linkpkg" option with
         ocamlfind, this module will then be added twice on the command line.

         To solve this, one approach is to add the "-thread" option when using
         the "threads" package using the previous plugin.
       *)
      flag ["ocaml"; "pkg_threads"; "compile"] (S[A "-thread"]);
      flag ["ocaml"; "pkg_threads"; "link"] (S[A "-thread"]);
      flag ["ocaml"; "pkg_threads"; "infer_interface"] (S[A "-thread"]);

      (* debugging info *)
      flag ["ocaml"; "compile"]
        (S[A"-g"]);
      flag ["ocaml"; "link"]
        (S[A"-g"]);
      flag ["ocaml"; "compile"; "native"]
        (S[A"-inline";A"10"]);

      (* c stub generated from camlidl *)
      flag ["c"; "compile"; "stubs"]
        (S[A"-ccopt";A("-I"^camlidl_path);]);

      (* camlidl needs to consider bfdarch *)
      flag ["camlidl"; "compile"]
        (S[A"-header"; A"-I"; A"libbfd"]);

      dep ["camlidl"; "compile"]
        [
          "libbfd/bfdarch.idl"
        ];

      (* compile dependencies *)
      dep ["ocaml"; "compile"]
        [
          "libbfdarch_stubs.a";
          "libbfdwrap_stubs.a";
        ];

      (* linking rule *)
      flag ["ocaml"; "link"; "native"]
        (S[
          A"-inline"; A"10";
          A"-cclib"; A"-L.";
          A"-cclib"; A"-lbfdwrap_stubs";
          A"-cclib"; A"-lbfdarch_stubs";
          A"-cclib"; A"-lbfd";
          A"-cclib"; A"-lopcodes";
          A"-cclib"; A("-L"^camlidl_path);
          A"-cclib"; A"-lcamlidl";
        ]);

      (* camlidl rules starts here *)
      rule "camlidl"
        ~prods:["%.mli"; "%.ml"; "%_stubs.c"]
        ~deps:["%.idl"]
        begin fun env _build ->
          let idl = env "%.idl" in
          let tags = tags_of_pathname idl ++ "compile" ++ "camlidl" in
          let cmd = Cmd( S[camlidl; T tags; P idl] ) in
          Seq [cmd]
        end;

      flag ["ocamlmklib"; "c"]
        (S[A"-L."])

  | _ -> ()
end

