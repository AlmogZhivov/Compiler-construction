(* example.ml
 * Handling infix expressions and variables:
 *
 *   E -> E + T | E - T | T 
 *   T -> T * F | T / F | F
 *   F -> (F)
 *
 * Programmer: Almog Zhivov, 2024
 *)

 #use "pc.ml";;

open PC;;
exception X_no_match;;
(* not for natural *)
let maybeify nt none_value = 
  pack (maybe nt) (function 
    | None -> none_value
    | Some x -> x);;

let nt_optional_is_positive = 
  let nt1 = pack (char '-') (fun _ -> false) in
  let nt2 = pack (char '+') (fun _ -> true) in
  let nt1 = maybeify (disj nt1 nt2) true in
  nt1;;

let int_of_digit_char = 
  let delta = int_of_char '0' in
  fun ch -> (int_of_char ch) - delta;;

let nt_digit_0_9 =
  pack (range '0' '9') int_of_digit_char;;

let nt_nat = 
  let nt1 = pack (plus nt_digit_0_9) 
  (fun digits -> List.fold_left
  (fun number digit -> 10 * number +digit)
  0
  digits) in
  nt1;;

let nt_int = 
  let nt1 = caten nt_optional_is_positive nt_nat in
  let nt1 = pack nt1 (fun (is_positive, number) -> 
    if is_positive then number
    else (-number)) in
  nt1;;

let nt_number =
  let nt1 = pack nt_int (fun number -> number) in
  nt1;;

type binary_op = Add | Sub | Mul | Div | Pow | Mod;;

type expr =
  | Num of int
  | Var of string
  | BinOp of binary_op * expr * expr
  | Deref of expr * expr
  | Call of expr * expr list;;

let nt_whitespace = const (fun ch -> ch <= ' ');;
type args_or_index = Args of expr list | Index of expr;;
let make_nt_spaced_out nt = 
  let nt1 = star nt_whitespace in
  let nt1 = pack (caten nt1 (caten nt nt1)) 
  (fun (_, (e, _)) -> e) in
  nt1;;

(* a legal variable will start with letter and contain digits or $ or _ signs*)
let nt_var = 
  let nt1 = range_ci 'a' 'z' in
  let nt2 = range '0' '9' in
  let nt3 = char '$' in
  let nt4 = char '_' in
  let nt1 = caten nt1 (star (disj_list [nt1; nt2; nt3; nt4])) in
  let nt1 = pack nt1 (fun (first, rest) -> 
    string_of_list (first :: rest)) in
  let nt1 = only_if nt1 (fun var -> String.lowercase_ascii var <> "mod") in
  let nt1 = pack nt1 (fun var -> Var var) in
  nt1;;

let make_nt_paren ch_left ch_right nt = 
  let nt1 = make_nt_spaced_out (char ch_left) in
  let nt2 = make_nt_spaced_out (char ch_right) in
  let nt1 = caten nt1 (caten nt nt2) in
  let nt1 = pack nt1 (fun (_, (e, _)) -> e) in
  nt1;;

let rec nt_expr str = nt_expr_0 str
and nt_expr_0 str = 
  let nt1 = pack (char '+') (fun _ -> Add) in
  let nt2 = pack (char '-') (fun _ -> Sub) in
  let nt1 = disj nt1 nt2 in
  (* hirarchy *)
  let nt1 = star (caten nt1 nt_expr_1) in
  let nt1 = pack (caten nt_expr_1 nt1)
        (fun (first, rest) -> List.fold_left
        (fun e1 (op, first') -> BinOp (op, e1, first'))
        first
        rest) in
  let nt1 = make_nt_spaced_out nt1 in
  nt1 str
and nt_expr_1 str =
  let nt1 = pack (char '*') (fun _ -> Mul) in
  let nt2 = pack (char '/') (fun _ -> Div) in
  let nt3 = pack (word_ci "mod") (fun _ -> Mod) in 
  let nt1 = disj nt1 (disj nt2 nt3) in
  (* hirarchy *)
  let nt1 = star (caten nt1 nt_expr_2) in
  let nt1 = pack (caten nt_expr_2 nt1)
        (fun (first, rest) -> List.fold_left
        (fun e1 (op, first') -> BinOp (op, e1, first'))
        first
        rest) in
  let nt1 = make_nt_spaced_out nt1 in
  nt1 str
(* support E^E pow operation but it uses fold right*)
and nt_expr_2 str =
    let nt1 = pack (caten (char '^') nt_expr_3) (fun (_, e) -> e) in
    let nt1 = star nt1 in
    let nt1 = caten nt_expr_3 nt1 in
    let nt1 = pack nt1 (fun (e, es) -> List.rev (e::es) ) in 
    let nt1 = pack nt1 
      (function
      | [] -> raise X_no_match
      | e :: es -> 
        List.fold_left
          (fun b a -> BinOp (Pow, a, b))
          e
          es) in
    let nt1 = make_nt_spaced_out nt1 in
    nt1 str
and nt_expr_3 str =
  let nt_number = pack nt_number (fun number -> Num number) in
  let nt_var = disj nt_number nt_var in
  let nt_call_or_deref =
    let nt_args_list =
      let nt_comma = make_nt_spaced_out (char ',') in
      let nt_arg = nt_expr in
      let nt_arg_list =
        pack (caten nt_arg (star (pack (caten nt_comma nt_arg) (fun (_, e) -> e))))
             (fun (first, rest) -> first :: rest) in
      maybeify nt_arg_list [] in
    let nt_parens = 
      pack (make_nt_paren '(' ')' nt_args_list) 
           (fun args -> Args args) in
    let nt_brackets = 
      pack (make_nt_paren '[' ']' nt_expr) 
           (fun index -> Index index) in
    let nt_operations = disj nt_parens nt_brackets in
    pack (caten nt_var (star nt_operations))
         (fun (base_expr, ops) ->
            List.fold_left (fun acc op ->
              match op with
              | Args args -> Call (acc, args)
              | Index idx -> Deref (acc, idx)
            ) base_expr ops) in
let nt_div_unary_paren =
  make_nt_paren '(' ')' 
    (pack (caten (make_nt_spaced_out (char '/')) nt_var) 
      (fun (_, e) -> BinOp (Div, Num 1, e))) in
let nt_sub_unary_paren =
  make_nt_paren '(' ')' 
    (pack (caten (make_nt_spaced_out (char '-')) nt_var) 
      (fun (_, e) -> BinOp (Sub, Num 0, e))) in
  let nt1 = disj_list [nt_call_or_deref; nt_div_unary_paren; nt_sub_unary_paren; nt_number; nt_var; nt_paren] in
  make_nt_spaced_out nt1 str
and nt_paren str =
  disj_list [make_nt_paren '(' ')' nt_expr; 
             make_nt_paren '[' ']' nt_expr; 
             make_nt_paren '{' '}' nt_expr] str;;



