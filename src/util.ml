(* open BatString -- overrides compare for some reason! *)
open Big_int_Z

module List = struct include List include BatList end

let id = fun x -> x

let memoize ?(size = 128) f =
  let results = Hashtbl.create size in
  fun x ->
    try Hashtbl.find results x
    with Not_found ->
      let y = f x in
      Hashtbl.add results x y;
      y

module HashUtil (H:Hashtbl.S) =
struct

  let hashtbl_eq ?(eq=(=)) h1 h2 =
    let subtbl h1 h2 =
      H.fold
        (fun k v r ->
           try r && eq v (H.find h2 k)
           with Not_found -> false )
        h1 true
    in
      subtbl h1 h2 && subtbl h2 h1

  (* Work around buggy replace in older versions of ocaml *)
  let hashtbl_replace table x y =
    H.remove table x;
    H.add table x y

  let get_hash_keys ?(sort_keys=false) htbl =
    let l = H.fold (fun key data prev -> key::prev) htbl [] in
    if (sort_keys) then List.sort (Pervasives.compare) l
    else l

  let get_hash_values ?(sort_values=false) htbl =
    let l = H.fold (fun key data prev -> data::prev) htbl [] in
    if (sort_values) then List.sort (Pervasives.compare) l
    else l
end

let big_int_to_hex n =
  Z.format "%x" n

let load_file file =
  let ic = open_in file in
  let n = in_channel_length ic in
  let s = String.create n in
  really_input ic s 0 n;
  close_in ic;
  s

