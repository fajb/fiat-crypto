Require Import Coq.Bool.Bool.
Require Import Coq.ZArith.ZArith.
Require Import Coq.micromega.Lia.

Require Import Crypto.Util.ZUtil.Definitions.
Require Import Crypto.Util.ZUtil.Notations.
Require Import Crypto.Util.ZUtil.Land.
Require Import Crypto.Util.ZUtil.Lor.
Require Import Crypto.Util.ZUtil.Testbit.
Require Import Crypto.Util.ZUtil.Div.
Require Import Crypto.Util.ZUtil.LandLorShiftBounds.
Require Import Crypto.Util.ZUtil.Zselect.
Require Import Crypto.Util.ZUtil.Ones.
Require Import Crypto.Util.ZUtil.OnesFrom.
Require Import Crypto.Util.ZUtil.Pow.
Require Import Crypto.Util.ZUtil.TruncatingShiftl.
Require Import Crypto.Util.ZUtil.SignBit.
Require Import Crypto.Util.ZUtil.TwosComplement.

Require Import Crypto.Util.Decidable.
Require Import Crypto.Util.LetIn.
Require Import Crypto.Util.ListUtil.
Require Import Crypto.Util.ZUtil.Tactics.SolveRange.
Require Import Crypto.Util.ZUtil.Tactics.SolveTestbit.

Local Open Scope Z_scope.

Module Z.
  Lemma arithmetic_shiftr1_testbit_spec m a i (Hm : 0 < m) (Hi : 0 <= i) (Ha : 0 <= a < 2 ^ m) :
    Z.testbit (Z.arithmetic_shiftr1 m a) i =
    if i =? (m - 1) then Z.testbit a (m - 1) else Z.testbit a (i + 1).
  Proof. unfold Z.arithmetic_shiftr1; solve_testbit. Qed.

  Hint Rewrite arithmetic_shiftr1_testbit_spec : testbit_rewrite.

  Lemma arithmetic_shiftr1_bound m a (Ha : 0 <= a < 2 ^ m) :
    0 <= Z.arithmetic_shiftr1 m a < 2 ^ m.
  Proof. unfold Z.arithmetic_shiftr1; solve_range. Qed.

  Hint Resolve arithmetic_shiftr1_bound : zarith.

  Lemma arithmetic_shiftr1_spec m a
        (Hm : 0 < m)
        (Ha : 0 <= a < 2 ^ m) :
    Z.twos_complement m (Z.arithmetic_shiftr1 m a) = (Z.twos_complement m a) / 2.
  Proof. solve_using_testbit. Qed.

  Lemma arithmetic_shiftr_bound m a k
        (Hm : 0 <= m)
        (Ha : 0 <= a < 2 ^ m)
        (Hk : 0 <= k) :
    0 <= Z.arithmetic_shiftr m a k < 2 ^ m.
  Proof.
    unfold Z.arithmetic_shiftr; rewrite unfold_Let_In, Zselect.Z.zselect_correct.
    destruct (dec (Z.sign_bit m a = 0)); [solve_range|].
    destruct (dec (m - k <= 0)); solve_range. Qed.

  Hint Resolve arithmetic_shiftr_bound : zarith.

  Lemma arithmetic_shiftr_testbit_spec m a k i
        (Hm : 0 < m)
        (Hk : 0 <= k)
        (Hi : 0 <= i)
        (Ha : 0 <= a < 2 ^ m) :
    Z.testbit (Z.arithmetic_shiftr m a k) i =
    if (m - k <=? i) && (i <? m) then Z.testbit a (m - 1) else Z.testbit a (i + k).
  Proof.
    unfold Z.arithmetic_shiftr; rewrite unfold_Let_In, Zselect.Z.zselect_correct.
    rewrite (Z.testbit_b2z a), Z.sign_bit_testbit by lia.
    destruct (Z.testbit a (m - 1)); solve_testbit. Qed.

  Hint Rewrite arithmetic_shiftr_testbit_spec : testbit_rewrite.

  Lemma arithmetic_shiftr_1' m a (Hm : 0 < m) (Ha : 0 <= a < 2 ^ m) :
    Z.arithmetic_shiftr m a 1 = Z.arithmetic_shiftr1 m a.
  Proof. solve_using_testbit. Qed.

  Lemma arithmetic_shiftr_0 m a :
    Z.arithmetic_shiftr m a 0 = a.
  Proof.
    unfold Z.arithmetic_shiftr; rewrite unfold_Let_In, !Zselect.Z.zselect_correct.
    rewrite Z.shiftr_0_r, Z.ones_from_0.
    destruct (dec (Z.sign_bit m a = 0)); reflexivity. Qed.

  Lemma ones_lor_shift n m k
        (Hn : 0 <= n)
        (Hm : 0 <= m)
        (Hk : 0 <= k) :
    Z.ones n << k |' Z.ones m << (k - m) = Z.ones (n + m) << (k - m).
  Proof. solve_using_testbit. Qed.

  Lemma arithmetic_shiftr_sign_bit m a k
        (Hm : 0 < m)
        (Ha : 0 <= a < 2 ^ m)
        (Hk : 0 <= k) :
    Z.sign_bit m (Z.arithmetic_shiftr m a k) = Z.sign_bit m a.
  Proof.
    rewrite !Z.sign_bit_testbit
      by (try apply arithmetic_shiftr_bound; lia). apply f_equal; solve_testbit. Qed.

  Lemma arithmetic_shiftr_arithmetic_shiftr m a p q
        (Hm : 0 < m)
        (Ha : 0 <= a < 2 ^ m)
        (Hp : 0 <= p)
        (Hq : 0 <= q) :
    Z.arithmetic_shiftr m (Z.arithmetic_shiftr m a p) q =
    Z.arithmetic_shiftr m a (p + q).
  Proof. solve_using_testbit. Qed.

  Lemma arithmetic_shiftr_arithmetic_shiftr1 m a k
        (Hm : 0 < m)
        (Ha : 0 <= a < 2 ^ m)
        (Hk : 0 <= k) :
    Z.arithmetic_shiftr m (Z.arithmetic_shiftr1 m a) k =
    Z.arithmetic_shiftr m a (k + 1).
  Proof. solve_using_testbit. Qed.

  Lemma arithmetic_shiftr_spec m a k
        (Hm : 0 < m)
        (Ha : 0 <= a < 2 ^ m)
        (Hk : 0 <= k) :
    Z.twos_complement m (Z.arithmetic_shiftr m a k) = (Z.twos_complement m a) / 2 ^ k.
  Proof. solve_using_testbit. Qed.
End Z.