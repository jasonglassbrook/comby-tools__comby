open Core

open Comby_kernel

open Matchers

let configuration = Configuration.create ~match_kind:Fuzzy ()

let format s =
  let s = String.chop_prefix_exn ~prefix:"\n" s in
  let leading_indentation = Option.value_exn (String.lfindi s ~f:(fun _ c -> not (Char.equal c ' '))) in
  s
  |> String.split ~on:'\n'
  |> List.map ~f:(Fn.flip String.drop_prefix leading_indentation)
  |> String.concat ~sep:"\n"
  |> String.chop_suffix_exn ~suffix:"\n"

let print_matches matches =
  List.map matches ~f:Match.to_yojson
  |> (fun matches -> `List matches)
  |> Yojson.Safe.pretty_to_string
  |> print_string

let print_only_match matches =
  List.map matches ~f:(fun matched -> `String matched.Match.matched)
  |> (fun matches -> `List matches)
  |> Yojson.Safe.pretty_to_string
  |> print_string

let run ?(configuration = configuration) (module M : Matchers.Matcher.S) source match_template ?rule rewrite_template =
  let rule =
    match rule with
    | Some rule -> Matchers.Rule.create rule |> Or_error.ok_exn
    | None -> Rule.create "where true" |> Or_error.ok_exn
  in
  M.all ~rule ~configuration ~template:match_template ~source ()
  |> function
  | [] -> print_string "No matches."
  | results ->
    Option.value_exn (Rewrite.all ~source ~rewrite_template results)
    |> (fun { rewritten_source; _ } -> rewritten_source)
    |> print_string

let run_nested
    (module M : Matchers.Matcher.S)
    ?(configuration = configuration)
    ?rule
    source
    match_template
    () =
  let nested =
    match rule with
    | None -> true
    | Some rule ->
      let options = Rule.create rule |> Or_error.ok_exn |> Rule.options in
      options.nested
  in
  M.all ~configuration ~nested ~template:match_template ~source ()
  |> function
  | [] -> print_string "No matches."
  | matches ->
    let matches = List.map matches ~f:(Match.convert_offset ~fast:true ~source) in
    Format.asprintf "%a" Match.pp (None, matches)
    |> print_string

let make_env bindings =
  List.fold bindings
    ~init:(Match.Environment.create ())
    ~f:(fun env (var, value) -> Match.Environment.add env var value)

let parse_template metasyntax template =
  let (module M) = Matchers.Metasyntax.create metasyntax in
  let module Template_parser = Template.Make(M) in
  let tree = Template_parser.parse template in
  Sexp.to_string_hum (Template.sexp_of_t tree)

let run_match (module M : Matchers.Matcher.S) source match_template =
  M.all ~configuration ~template:match_template ~source ()
  |> function
  | [] -> print_string "No matches."
  | hd :: _ ->
    print_string (Yojson.Safe.to_string (Match.to_yojson hd))

let run_all_matches (module M : Matchers.Matcher.S) source match_template =
  M.all ~configuration ~template:match_template ~source ()
  |> function
  | [] -> print_string "No matches."
  | l -> Format.printf "%a" Match.pp_json_lines (None, l)
