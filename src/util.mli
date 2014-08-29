(** Utility functions that are not BAP specific.

    @author Ivan Jager
*)

(** The identity function *)
val id : 'a -> 'a

(** Memoize the results of a function *)
val memoize : ?size:int -> ('a -> 'b) -> 'a -> 'b

(** Extension of [Hashtbl]s *)
module HashUtil :
  functor (H : Hashtbl.S) ->
sig
  (** Test if two [Hashtbl]s are equal. Keys are tested for equality
      with [eq], which defaults to [(=)]. *)
  val hashtbl_eq : ?eq:('a -> 'a -> bool) -> 'a H.t -> 'a H.t -> bool

  (** Implementation of {!Hashtbl.replace} to work around OCaml
      bug. *)
  val hashtbl_replace : 'a H.t -> H.key -> 'a -> unit

  (** Get the keys from a hash table.  If a key has multiple bindings,
      it is included once per binding *)
  val get_hash_keys : ?sort_keys:bool -> 'a H.t -> H.key list

  (** Get the values from a hash table.  If a key has multiple bindings,
      the value is included once per binding *)
  val get_hash_values : ?sort_values:bool -> 'a H.t -> 'a list

end

(** Convert [big_int] to hex string for printing *)
val big_int_to_hex : Big_int_Z.big_int -> string

(** load a file into string *)
val load_file : string -> string

