import MinimumFormalVerification.Extraction

open Aeneas Aeneas.Std CoreModels

namespace MinimumFormalVerification

/-- The mathematical requirement: conserve the balance on success;
    reject exactly when there is insufficient balance. Arithmetic is in Nat. -/
def SpendSpec (balance amount : Nat) (result : core.option.Option U32) : Prop :=
  match result with
  | .Some remaining => remaining.val + amount = balance
  | .None => balance < amount

/-- Every input terminates normally and satisfies the specification.
    `spend` is imported from the Rust extraction, not reimplemented here. -/
theorem spend_correct (balance amount : U32) :
    ∃ result, minimum_formal_verification.spend balance amount = .ok result ∧
      SpendSpec balance.val amount.val result := by
  by_cases h : amount ≤ balance
  · have hsub := UScalar.sub_equiv balance amount
    change amount.val ≤ balance.val at h
    cases heq : (balance - amount : RustM U32) with
    | ok remaining =>
        simp only [heq] at hsub
        refine ⟨.Some remaining, ?_, hsub.2.1.symm⟩
        simp [minimum_formal_verification.spend, h, heq]
    | fail error =>
        simp only [heq] at hsub
        omega
    | div =>
        simp [heq] at hsub
  · refine ⟨.None, ?_, ?_⟩
    · simp [minimum_formal_verification.spend, h]
    · change balance.val < amount.val
      change ¬ amount.val ≤ balance.val at h
      omega

/-- An insufficient balance is a normal `None`, not a panic. -/
theorem spend_none_iff (balance amount : U32) :
    minimum_formal_verification.spend balance amount = .ok .None ↔
      balance.val < amount.val := by
  obtain ⟨result, heq, hspec⟩ := spend_correct balance amount
  cases result <;> simp_all [SpendSpec]
  omega

/-- A successful result preserves the exact amount, using unbounded arithmetic. -/
theorem spend_conserves (balance amount remaining : U32)
    (h : minimum_formal_verification.spend balance amount = .ok (.Some remaining)) :
    remaining.val + amount.val = balance.val := by
  obtain ⟨result, heq, hspec⟩ := spend_correct balance amount
  have : result = .Some remaining := RustM.ok.inj (heq.symm.trans h)
  simpa [this, SpendSpec] using hspec

end MinimumFormalVerification
