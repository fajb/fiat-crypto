Require Import Coq.ZArith.ZArith.
Require Import Crypto.Language.Language.
Require Import Crypto.Language.Wf.
Require Import Crypto.Language.WfExtra.
Require Import Crypto.Rewriter.AllTacticsExtra.
Require Import Crypto.Rewriter.RulesProofs.

Module Compilers.
  Import Language.Compilers.
  Import Language.Wf.Compilers.
  Import Identifier.Compilers.
  Import Language.WfExtra.Compilers.
  Import Rewriter.AllTactics.Compilers.RewriteRules.GoalType.
  Import Rewriter.AllTacticsExtra.Compilers.RewriteRules.Tactic.
  Import Compilers.Classes.

  Module Import RewriteRules.
    Section __.
      Context (bitwidth : Z)
              (lgcarrymax : Z).

      Definition VerifiedRewriterMulSplit : VerifiedRewriter.
      Proof using All. make_rewriter false (mul_split_rewrite_rules_proofs bitwidth lgcarrymax). Defined.

      Definition RewriteMulSplit {t} := Eval hnf in @Rewrite VerifiedRewriterMulSplit t.

      Lemma Wf_RewriteMulSplit {t} e (Hwf : Wf e) : Wf (@RewriteMulSplit t e).
      Proof. now apply VerifiedRewriterMulSplit. Qed.

      Lemma Interp_gen_RewriteMulSplit {cast_outside_of_range t} e (Hwf : Wf e)
        : expr.Interp (@ident.gen_interp cast_outside_of_range) (@RewriteMulSplit t e)
          == expr.Interp (@ident.gen_interp cast_outside_of_range) e.
      Proof. now apply VerifiedRewriterMulSplit. Qed.

      Lemma Interp_RewriteMulSplit {t} e (Hwf : Wf e) : expr.Interp (@ident.interp) (@RewriteMulSplit t e) == expr.Interp (@ident.interp) e.
      Proof. apply Interp_gen_RewriteMulSplit; assumption. Qed.
    End __.
  End RewriteRules.

  Module Export Hints.
    Hint Resolve Wf_RewriteMulSplit : wf wf_extra.
    Hint Rewrite @Interp_gen_RewriteMulSplit @Interp_RewriteMulSplit : interp interp_extra.
  End Hints.
End Compilers.