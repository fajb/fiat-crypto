Require Import Coq.ZArith.ZArith.
Require Import Coq.Strings.Ascii.
Require Import Coq.Lists.List.
Require Import Coq.Strings.String.
Require Crypto.Util.Strings.String.
Require Import Crypto.Util.Strings.Decimal.
Require Import Crypto.Util.Strings.HexString.
Require Import Crypto.Util.Option.
Require Import Crypto.Util.Strings.Show.
Require Import Crypto.Experiments.NewPipeline.Toplevel1.
Require Import Crypto.Experiments.NewPipeline.CStringification.
Import ListNotations. Local Open Scope Z_scope. Local Open Scope string_scope.

Import CStringification.Compilers.

Module ForExtraction.
  Definition parse_neg (s : string) : string * Z
    := match s with
       | String a b
         => if Ascii.ascii_dec a "-"
            then (b, -1)
            else if Ascii.ascii_dec a "+"
                 then (b, 1)
                 else (s, 1)
       | _ => (s, 1)
       end.
  Definition parse_N (s : string) : N
    := DecimalHelpers.N.of_uint (DecimalHelpers.String.to_uint s).
  Definition parse_Z (s : string) : Z
    := let '(s, sgn) := parse_neg s in
       sgn * Z.of_N (parse_N s).
  Definition parse_nat (s : string) : nat
    := N.to_nat (parse_N s).

  Definition parse_n (n : string) : nat
    := parse_nat n.

  Definition parse_pow (s : string) : option Z
    := let '(s, sgn) := parse_neg s in
       match String.split "^" s with
       | v::nil
         => Some (sgn * parse_Z v)
       | b::e::nil
         => Some (sgn * parse_Z b ^ parse_Z e)
       | _ => None
       end.

  Definition parse_mul (s : string) : option Z
    := List.fold_right
         (fun a b => (a <- a; b <- b; Some (Z.mul a b))%option)
         (Some 1)
         (List.map parse_pow (String.split "*" s)).

  (** We take in [c] in the format [a,b;c,d;e,f;...] becoming the list
    [[(a,b), (c,d), (e, f), ...]] *)
  Definition parse_s (s : string) : option Z
    := parse_mul s.
  Definition parse_c (s : string) : option (list (Z * Z))
    := List.fold_right
         (fun ls rest
          => (rest <- rest;
                match ls with
                | a::b::nil => (a <- parse_mul a; b <- parse_mul b; Some ((a, b)::rest))
                | _ => None
                end)%option)
         (Some nil)
         (List.map (String.split ",") (String.split ";" s)).

  Definition parse_machine_wordsize (s : string) : Z
    := parse_Z s.

  Local Open Scope string_scope.
  Local Notation NewLine := (String "010" "") (only parsing).

  Definition CollectErrors
             (res : list (string * Pipeline.ErrorT (list string)) + list string)
    : list (list string) + list (list string)
    := match res with
       | inl res
         => let header := hd "" (List.map (@fst _ _) res) in
            let res :=
                List.fold_right
                  (fun '(name, res) rest
                   => match res, rest with
                      | ErrorT.Error err, rest
                        => let in_name := ("In " ++ name ++ ":") in
                           let cur :=
                               match show_lines false err with
                               | [serr] => [in_name ++ " " ++ serr]
                               | serr => in_name::serr
                               end in
                           let rest := match rest with inl _ => nil | inr rest => rest end in
                           inr (cur :: rest)
                      | ErrorT.Success v, inr ls => inr ls
                      | ErrorT.Success v, inl ls
                        => inl (v :: ls)
                      end)
                  (inl nil)
                  res in
            match res with
            | inl ls => inl ls
            | inr err => inr ([header]::err)
            end
       | inr res
         => inr [res]
       end.

  Definition curve_description_help
    := "  curve_description       A string which will be prefixed to every function name generated".
  Definition n_help
    := "  n                       The number of limbs".
  Definition s_help
    := "  s                       The largest component of the prime (e.g., '2^255' in '2^255-19')".
  Definition c_help
    := "  c                       The semi-colon separated list of taps, each of which is specified as weight,value (no parentheses) (e.g., '2^96,1;1,-1' in '2^224 - 2^96 + 1')".
  Definition machine_wordsize_help
    := "  machine_wordsize        The machine bitwidth (e.g., 32 or 64)".
  Definition function_to_synthesize_help (valid_names : string)
    := "  function_to_synthesize  A list of functions that should be synthesized.  If no functions are given, all functions are synthesized."
         ++ String.NewLine ++
       "                            Valid options are " ++ valid_names.

  Module UnsaturatedSolinas.
    Definition PipelineLines
               (curve_description : string)
               (n : string)
               (s : string)
               (c : string)
               (machine_wordsize : string)
               (requests : list string)
    : list (string * Pipeline.ErrorT (list string)) + list string
      := let prefix := ("fiat_" ++ curve_description ++ "_")%string in
         let str_n := n in
         let n : nat := parse_n n in
         let str_machine_wordsize := machine_wordsize in
         let str_c := c in
         let str_s := s in
         let machine_wordsize := parse_machine_wordsize machine_wordsize in
         let show_requests := match requests with nil => "(all)" | _ => String.concat ", " requests end in
         match parse_s s, parse_c c with
         | None, None
           => inr ["Could not parse s (" ++ s ++ ") nor c (" ++ c ++ ")"]
         | None, _
           => inr ["Could not parse s (" ++ s ++ ")"]
         | _, None
           => inr ["Could not parse c (" ++ c ++ ")"]
         | Some s, Some c
           => let '(res, types_used)
                 := UnsaturatedSolinas.Synthesize n s c machine_wordsize prefix requests in
             let header :=
                 ((["/* Autogenerated */";
                       "/* curve description: " ++ curve_description ++ " */";
                       "/* requested operations: " ++ show_requests ++ " */";
                       "/* n = " ++ show false n ++ " (from """ ++ str_n ++ """) */";
                       "/* s = " ++ Hex.show_Z false s ++ " (from """ ++ str_s ++ """) */";
                       "/* c = " ++ show false c ++ " (from """ ++ str_c ++ """) */";
                       "/* machine_wordsize = " ++ show false machine_wordsize ++ " (from """ ++ str_machine_wordsize ++ """) */";
                       ""]%string)
                     ++ ToString.C.String.typedef_header prefix types_used
                     ++ [""])%list in
             inl
               ([("check_args" ++ NewLine ++ String.concat NewLine header,
                  UnsaturatedSolinas.check_args
                    n s c machine_wordsize
                    (ErrorT.Success header))%string]
                  ++ res)%list
         end.

    Definition ProcessedLines
               (curve_description : string)
               (n : string)
               (s : string)
               (c : string)
               (machine_wordsize : string)
               (requests : list string)
      : list string + list string
      := match CollectErrors (PipelineLines curve_description n s c machine_wordsize requests) with
         | inl ls
           => inl
               (List.map (fun s => String.concat NewLine s ++ NewLine ++ NewLine)
                         ls)
         | inr nil => inr nil
         | inr (l :: ls)
           => inr (l ++ (List.flat_map
                           (fun e => NewLine :: e)
                           ls))%list
         end.

    Definition Pipeline
               {A}
               (curve_description : string)
               (n : string)
               (s : string)
               (c : string)
               (machine_wordsize : string)
               (requests : list string)
               (success : list string -> A)
               (error : list string -> A)
      : A
      := match ProcessedLines curve_description n s c machine_wordsize requests with
         | inl s => success s
         | inr s => error s
         end.

    Definition PipelineMain
               {A}
               (argv : list string)
               (success : list string -> A)
               (error : list string -> A)
      : A
      := match argv with
         | _::curve_description::n::s::c::machine_wordsize::requests
           => Pipeline
               curve_description n s c machine_wordsize requests
               success
               error
         | nil => error ["empty argv"]
         | prog::args
           => error ["Expected arguments curve_description, n, s, c, machine_wordsize, [function_to_synthesize*] got " ++ show false (List.length args) ++ " arguments in " ++ prog;
                       "";
                       curve_description_help;
                       n_help;
                       s_help;
                       c_help;
                       machine_wordsize_help;
                       function_to_synthesize_help UnsaturatedSolinas.valid_names;
                       ""]
         end.


  End UnsaturatedSolinas.

  Module WordByWordMontgomery.
    Definition PipelineLines
               (curve_description : string)
               (s : string)
               (c : string)
               (machine_wordsize : string)
               (requests : list string)
    : list (string * Pipeline.ErrorT (list string)) + list string
      := let prefix := ("fiat_" ++ curve_description ++ "_")%string in
         let str_machine_wordsize := machine_wordsize in
         let str_c := c in
         let str_s := s in
         let machine_wordsize := parse_machine_wordsize machine_wordsize in
         let show_requests := match requests with nil => "(all)" | _ => String.concat ", " requests end in
         match parse_s s, parse_c c with
         | None, None
           => inr ["Could not parse s (" ++ s ++ ") nor c (" ++ c ++ ")"]
         | None, _
           => inr ["Could not parse s (" ++ s ++ ")"]
         | _, None
           => inr ["Could not parse c (" ++ c ++ ")"]
         | Some s, Some c
           => let '(res, types_used)
                 := WordByWordMontgomery.Synthesize s c machine_wordsize prefix requests in
             let header :=
                 ((["/* Autogenerated */";
                       "/* curve description: " ++ curve_description ++ " */";
                       "/* requested operations: " ++ show_requests ++ " */";
                       "/* s = " ++ Hex.show_Z false s ++ " (from """ ++ str_s ++ """) */";
                       "/* c = " ++ show false c ++ " (from """ ++ str_c ++ """) */";
                       "/* machine_wordsize = " ++ show false machine_wordsize ++ " (from """ ++ str_machine_wordsize ++ """) */";
                       "/*                                                                    */";
                       "/* NOTE: In addition to the bounds specified above each function, all */";
                       "/*   functions synthesized for this Montgomery arithmetic require the */";
                       "/*   input to be strictly less than the prime modulus (s-c), and also */";
                       "/*   require the input to be in the unique saturated representation.  */";
                       "/*   All functions also ensure that these two properties are true of  */";
                       "/*   return values.                                                   */";
                       ""]%string)
                     ++ ToString.C.String.typedef_header prefix types_used
                     ++ [""])%list in
             inl
               ([("check_args" ++ NewLine ++ String.concat NewLine header,
                  WordByWordMontgomery.check_args
                    s c machine_wordsize
                    (ErrorT.Success header))%string]
                  ++ res)%list
         end.

    Definition ProcessedLines
               (curve_description : string)
               (s : string)
               (c : string)
               (machine_wordsize : string)
               (requests : list string)
      : list string + list string
      := match CollectErrors (PipelineLines curve_description s c machine_wordsize requests) with
         | inl ls
           => inl
               (List.map (fun s => String.concat NewLine s ++ NewLine ++ NewLine)
                         ls)
         | inr nil => inr nil
         | inr (l :: ls)
           => inr (l ++ (List.flat_map
                           (fun e => NewLine :: e)
                           ls))%list
         end.

    Definition Pipeline
               {A}
               (curve_description : string)
               (s : string)
               (c : string)
               (machine_wordsize : string)
               (requests : list string)
               (success : list string -> A)
               (error : list string -> A)
      : A
      := match ProcessedLines curve_description s c machine_wordsize requests with
         | inl s => success s
         | inr s => error s
         end.

    Definition PipelineMain
               {A}
               (argv : list string)
               (success : list string -> A)
               (error : list string -> A)
      : A
      := match argv with
         | _::curve_description::s::c::machine_wordsize::requests
           => Pipeline
               curve_description s c machine_wordsize requests
               success
               error
         | nil => error ["empty argv"]
         | prog::args
           => error ["Expected arguments curve_description, s, c, machine_wordsize, [function_to_synthesize*] got " ++ show false (List.length args) ++ " arguments in " ++ prog;
                       "";
                       curve_description_help;
                       s_help;
                       c_help;
                       machine_wordsize_help;
                       function_to_synthesize_help WordByWordMontgomery.valid_names;
                       ""]
         end.
  End WordByWordMontgomery.

  Module SaturatedSolinas.
    Definition PipelineLines
               (curve_description : string)
               (s : string)
               (c : string)
               (machine_wordsize : string)
               (requests : list string)
    : list (string * Pipeline.ErrorT (list string)) + list string
      := let prefix := ("fiat_" ++ curve_description ++ "_")%string in
         let str_machine_wordsize := machine_wordsize in
         let str_c := c in
         let str_s := s in
         let machine_wordsize := parse_machine_wordsize machine_wordsize in
         let show_requests := match requests with nil => "(all)" | _ => String.concat ", " requests end in
         match parse_s s, parse_c c with
         | None, None
           => inr ["Could not parse s (" ++ s ++ ") nor c (" ++ c ++ ")"]
         | None, _
           => inr ["Could not parse s (" ++ s ++ ")"]
         | _, None
           => inr ["Could not parse c (" ++ c ++ ")"]
         | Some s, Some c
           => let '(res, types_used)
                 := SaturatedSolinas.Synthesize s c machine_wordsize prefix requests in
             let header :=
                 ((["/* Autogenerated */";
                      "/* curve description: " ++ curve_description ++ " */";
                      "/* requested operations: " ++ show_requests ++ " */";
                      "/* s = " ++ Hex.show_Z false s ++ " (from """ ++ str_s ++ """) */";
                      "/* c = " ++ show false c ++ " (from """ ++ str_c ++ """) */";
                      "/* machine_wordsize = " ++ show false machine_wordsize ++ " (from """ ++ str_machine_wordsize ++ """) */";
                      ""]%string)
                    ++ ToString.C.String.typedef_header prefix types_used
                    ++ [""])%list in
             inl
               ([("check_args" ++ NewLine ++ String.concat NewLine header,
                  SaturatedSolinas.check_args
                    s c machine_wordsize
                    (ErrorT.Success header))%string]
                  ++ res)%list
         end.

    Definition ProcessedLines
               (curve_description : string)
               (s : string)
               (c : string)
               (machine_wordsize : string)
               (requests : list string)
      : list string + list string
      := match CollectErrors (PipelineLines curve_description s c machine_wordsize requests) with
         | inl ls
           => inl
               (List.map (fun s => String.concat NewLine s ++ NewLine ++ NewLine)
                         ls)
         | inr nil => inr nil
         | inr (l :: ls)
           => inr (l ++ (List.flat_map
                           (fun e => NewLine :: e)
                           ls))%list
         end.

    Definition Pipeline
               {A}
               (curve_description : string)
               (s : string)
               (c : string)
               (machine_wordsize : string)
               (requests : list string)
               (success : list string -> A)
               (error : list string -> A)
      : A
      := match ProcessedLines curve_description s c machine_wordsize requests with
         | inl s => success s
         | inr s => error s
         end.

    Definition PipelineMain
               {A}
               (argv : list string)
               (success : list string -> A)
               (error : list string -> A)
      : A
      := match argv with
         | _::curve_description::s::c::machine_wordsize::requests
           => Pipeline
               curve_description s c machine_wordsize requests
               success
               error
         | nil => error ["empty argv"]
         | prog::args
           => error ["Expected arguments curve_description, s, c, machine_wordsize, [function_to_synthesize*] got " ++ show false (List.length args) ++ " arguments in " ++ prog;
                       "";
                       curve_description_help;
                       s_help;
                       c_help;
                       machine_wordsize_help;
                       function_to_synthesize_help SaturatedSolinas.valid_names;
                       ""]
         end.
  End SaturatedSolinas.
End ForExtraction.
