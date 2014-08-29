(* ocamlbuild script *)

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

(* this is supposed to list available syntaxes, but I don't know how to do it. *)
let find_syntaxes () = ["camlp4o"; "camlp4r"]

(* ocamlfind command *)
let ocamlfind x = S[A"ocamlfind"; x]

(* camlidl command *)
let camlidl = S([A"camlidl"; A"-header"])

let is_all_whitespace s =
  try
    String.iter (fun c -> if c <> ' ' then raise Exit) s;
    true
  with Exit -> false

let get_env_elem s =
  let it = getenv s in
  match is_all_whitespace it with
    | true -> ""
    | false -> it

let _ = dispatch begin function
   | Before_options ->
       (* by using Before_options one let command line options have an higher priority *)
       (* on the contrary using After_options will guarantee to have the higher priority *)

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
         ];

   | After_rules ->

       (* When one link an OCaml library/binary/package, one should use -linkpkg *)
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

       (* Like -package but for extensions syntax. Morover -syntax is useless
        * when linking. *)
       List.iter begin fun syntax ->
         flag ["ocaml"; "compile";  "syntax_"^syntax] & S[A"-syntax"; A syntax];
         flag ["ocaml"; "ocamldep"; "syntax_"^syntax] & S[A"-syntax"; A syntax];
         flag ["ocaml"; "doc";      "syntax_"^syntax] & S[A"-syntax"; A syntax];
         flag ["ocaml"; "infer_interface"; "syntax_"^syntax] & S[A"-syntax"; A syntax];
       end (find_syntaxes ());

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
       flag ["ocaml"; "link"; "native"]
         (S[A"-inline";A"10"]);

       (* bfdarch must be generated first *)
       dep ["ocaml"; "compile"] ["src/bfdarch.ml"];

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

