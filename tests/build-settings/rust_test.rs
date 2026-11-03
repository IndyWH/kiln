// Kiln Linux: built with make.conf's RUSTFLAGS. Refuses to compile unless Rust was really
// told about this chip, then proves the result runs. The instructions must also be safe
// on the fast and the efficient cores, so check.py runs it on both.
#[cfg(not(all(target_feature = "avx2", target_feature = "avxvnni")))]
compile_error!("RUSTFLAGS did not target this CPU");

fn main() {
    let numbers: Vec<u64> = (0..100_000).collect();
    let total: u64 = numbers.iter().map(|n| n * 3).sum();
    assert_eq!(total, 14_999_850_000);
    println!("ok");
}
