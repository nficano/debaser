use clap::Parser;

#[derive(Parser, Debug, Clone)]
#[command(
    author,
    version,
    about = "Generates deterministic release names",
    long_about = None
)]
pub struct Cli {
    /// A key to make names deterministic.
    #[arg(short, long, value_name = "HEX")]
    pub checksum: Option<String>,
}
