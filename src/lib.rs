pub mod cli;

mod generator;
mod sha;

use anyhow::Result;
use clap::Parser;

use crate::generator::ReleaseNameGenerator;

/// Parse CLI flags, resolve a checksum or git SHA, and emit the release name.
pub fn run() -> Result<()> {
    let cli = cli::Cli::parse();
    let name = generate_from_cli(cli)?;
    println!("{name}");
    Ok(())
}

/// Generate a release name based on CLI inputs without printing it.
pub fn generate_from_cli(cli: cli::Cli) -> Result<String> {
    generate_from_checksum(cli.checksum.as_deref())
}

/// Core entry-point for programmatic usage (tests, integrations, etc.).
pub fn generate_from_checksum(checksum: Option<&str>) -> Result<String> {
    let sha = sha::resolve(checksum)?;
    Ok(ReleaseNameGenerator.generate(&sha))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn generates_from_explicit_checksum() {
        let name =
            generate_from_checksum(Some("abcd")).expect("checksum-based generation should succeed");
        assert_eq!(name, "loony-lionfish");
    }
}
