mod data;

use std::collections::HashMap;
use std::time::{SystemTime, UNIX_EPOCH};

use once_cell::sync::Lazy;
use rand::rngs::StdRng;
use rand::{Rng, SeedableRng};

use data::{ADJECTIVES, NOUNS};

static NOUNS_BY_LETTER: Lazy<HashMap<char, Vec<&'static str>>> = Lazy::new(|| {
    let mut map: HashMap<char, Vec<&'static str>> = HashMap::new();
    for &noun in NOUNS {
        if let Some(letter) = noun.chars().next() {
            map.entry(letter.to_ascii_uppercase())
                .or_default()
                .push(noun);
        }
    }
    map
});

#[derive(Default)]
pub struct ReleaseNameGenerator;

impl ReleaseNameGenerator {
    pub fn generate(&self, raw_sha: &str) -> String {
        let mut rng = sha_to_rng(raw_sha);

        let adjective = ADJECTIVES[rng.gen_range(0..ADJECTIVES.len())];
        let noun = select_noun(adjective, &mut rng);

        format!("{adjective}-{noun}").to_lowercase()
    }
}

fn select_noun(adjective: &str, rng: &mut StdRng) -> &'static str {
    let letter = adjective
        .chars()
        .next()
        .map(|c| c.to_ascii_uppercase())
        .unwrap_or('A');

    if let Some(matching) = NOUNS_BY_LETTER.get(&letter) {
        if !matching.is_empty() {
            return matching[rng.gen_range(0..matching.len())];
        }
    }

    NOUNS[rng.gen_range(0..NOUNS.len())]
}

/// Convert a hex SHA string into a seeded `StdRng` (ChaCha12).
///
/// This gives uniform distribution across the full word lists while
/// remaining fully deterministic: the same SHA always yields the same name.
fn sha_to_rng(raw: &str) -> StdRng {
    let hex: String = raw.chars().filter(|c| c.is_ascii_hexdigit()).collect();

    let mut seed = [0u8; 32];

    if hex.is_empty() {
        let secs = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();
        seed[..8].copy_from_slice(&secs.to_le_bytes());
    } else {
        let mut i = 0;
        let mut j = 0;
        let bytes = hex.as_bytes();
        while j < 32 && i < bytes.len() {
            let hi = bytes[i];
            let lo = if i + 1 < bytes.len() {
                bytes[i + 1]
            } else {
                b'0'
            };
            if let Ok(byte) = u8::from_str_radix(
                std::str::from_utf8(&[hi, lo]).unwrap_or("00"),
                16,
            ) {
                seed[j] = byte;
            }
            i += 2;
            j += 1;
        }
    }

    StdRng::from_seed(seed)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn deterministic_same_sha_same_name() {
        let gen = ReleaseNameGenerator;
        let a = gen.generate("abcdef1234567890");
        let b = gen.generate("abcdef1234567890");
        assert_eq!(a, b);
    }

    #[test]
    fn different_shas_produce_different_names() {
        let gen = ReleaseNameGenerator;
        let a = gen.generate("0000000000000000");
        let b = gen.generate("ffffffffffffffff");
        assert_ne!(a, b);
    }

    #[test]
    fn alliterative_names() {
        let gen = ReleaseNameGenerator;
        for sha in ["abcd", "1234", "dead", "beef", "cafe", "face", "babe"] {
            let name = gen.generate(sha);
            let parts: Vec<&str> = name.split('-').collect();
            assert_eq!(parts.len(), 2, "expected adjective-noun, got: {name}");
            assert_eq!(
                parts[0].chars().next(),
                parts[1].chars().next(),
                "not alliterative: {name}"
            );
        }
    }

    #[test]
    fn handles_short_input() {
        let gen = ReleaseNameGenerator;
        let name = gen.generate("1");
        assert!(!name.is_empty());
        assert!(name.contains('-'));
    }

    #[test]
    fn filters_non_hex() {
        let gen = ReleaseNameGenerator;
        let name = gen.generate("xyz__!!ab12");
        assert!(!name.is_empty());
        assert!(name.contains('-'));
    }
}
