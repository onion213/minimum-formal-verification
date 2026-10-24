use minimum_formal_verification::spend;

#[test]
fn boundaries() {
    assert_eq!(spend(0, 0), Some(0));
    assert_eq!(spend(0, 1), None);
    assert_eq!(spend(u32::MAX, 0), Some(u32::MAX));
    assert_eq!(spend(u32::MAX, u32::MAX), Some(0));
    assert_eq!(spend(u32::MAX - 1, u32::MAX), None);
}

#[test]
fn small_inputs_agree_with_independent_integer_arithmetic() {
    for balance in 0..=255 {
        for amount in 0..=255 {
            let difference = i64::from(balance) - i64::from(amount);
            let expected = u32::try_from(difference).ok();
            assert_eq!(spend(balance, amount), expected, "{balance}, {amount}");
        }
    }
}
