#![forbid(unsafe_code)]

//! A single operation whose extracted implementation is proved in Lean 4.

/// Spend `amount` from `balance`, returning the remainder when affordable.
///
/// ```
/// use minimum_formal_verification::spend;
///
/// assert_eq!(spend(10, 3), Some(7));
/// assert_eq!(spend(10, 10), Some(0));
/// assert_eq!(spend(10, 11), None);
/// ```
pub fn spend(balance: u32, amount: u32) -> Option<u32> {
    if amount <= balance {
        Some(balance - amount)
    } else {
        None
    }
}
