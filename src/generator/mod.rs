mod data;

use std::collections::HashMap;
use std::time::{SystemTime, UNIX_EPOCH};

use once_cell::sync::Lazy;

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
        let normalized = normalize_sha(raw_sha);
        let bytes = normalized.as_bytes();
        let adj_seed = hex_pair_to_value(&bytes[0..2]);
        let noun_seed = hex_pair_to_value(&bytes[2..4]);

        let adjective = ADJECTIVES[adj_seed % ADJECTIVES.len()];
        let noun = select_noun(adjective, noun_seed);

        format!("{adjective}-{noun}").to_lowercase()
    }
}

fn select_noun(adjective: &str, noun_seed: usize) -> &'static str {
    let letter = adjective
        .chars()
        .next()
        .map(|c| c.to_ascii_uppercase())
        .unwrap_or('A');

    if let Some(matching) = NOUNS_BY_LETTER.get(&letter) {
        if !matching.is_empty() {
            return matching[noun_seed % matching.len()];
        }
    }

    NOUNS[noun_seed % NOUNS.len()]
}

fn normalize_sha(raw: &str) -> String {
    let mut sanitized: String = raw.chars().filter(|c| c.is_ascii_hexdigit()).collect();

    if sanitized.is_empty() {
        sanitized = fallback_timestamp_hex();
    }

    while sanitized.len() < 4 {
        sanitized.push('0');
    }

    sanitized
}

fn fallback_timestamp_hex() -> String {
    let duration = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default();
    format!("{:x}", duration.as_secs())
}

fn hex_pair_to_value(bytes: &[u8]) -> usize {
    let text = std::str::from_utf8(bytes).expect("hex pair conversion needs ASCII input");
    usize::from_str_radix(text, 16).unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn generator_respects_shared_initial() {
        let generator = ReleaseNameGenerator::default();
        assert!(generator.generate("0000").starts_with("airy-a"));
    }

    #[test]
    fn pads_short_inputs() {
        assert_eq!(normalize_sha("1"), "1000");
    }

    #[test]
    fn filters_non_hex() {
        let normalized = normalize_sha("xyz");
        assert!(normalized.chars().all(|c| c.is_ascii_hexdigit()));
    }
}
