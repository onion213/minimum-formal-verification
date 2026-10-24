import MinimumFormalVerification.Verification.ProofObligations
import Lean.Util.CollectAxioms

/- Inspect the actual, transitive proof dependencies, including dependencies
   from imported libraries. A text search for unfinished proofs is insufficient. -/
open Lean in
run_cmd do
  let allowed := #[``propext, ``Quot.sound, ``Classical.choice]
  for declaration in #[
    ``MinimumFormalVerification.spend_correct,
    ``MinimumFormalVerification.spend_none_iff,
    ``MinimumFormalVerification.spend_conserves
  ] do
    let axioms ← collectAxioms declaration
    for axiomName in axioms do
      unless allowed.contains axiomName do
        throwError "Unexpected axiom in {declaration}: {axiomName}"
    logInfo m!"Axiom audit passed: {declaration}: {axioms}"
