use std::process::{Command, Stdio};

use anyhow::{ensure, Context, Result};

pub fn resolve(checksum: Option<&str>) -> Result<String> {
    if let Some(custom) = checksum {
        let trimmed = custom.trim();
        ensure!(
            !trimmed.is_empty(),
            "--checksum must contain at least one hexadecimal character"
        );
        return Ok(trimmed.to_owned());
    }

    ensure_inside_git_repo()?;
    read_git_head()
}

fn ensure_inside_git_repo() -> Result<()> {
    let status = Command::new("git")
        .args(["rev-parse", "--is-inside-work-tree"])
        .stdout(Stdio::null())
        .status()
        .context("Failed to determine if current directory is inside a git repository")?;

    ensure!(
        status.success(),
        "--checksum required when not inside a git repository"
    );
    Ok(())
}

fn read_git_head() -> Result<String> {
    let output = Command::new("git")
        .args(["rev-parse", "HEAD"])
        .output()
        .context("Failed to read latest git commit hash")?;

    ensure!(
        output.status.success(),
        "git rev-parse HEAD exited with status {}",
        output.status
    );

    let sha = String::from_utf8(output.stdout)
        .context("Git commit hash was not valid UTF-8")?
        .trim()
        .to_owned();

    ensure!(
        !sha.is_empty(),
        "Git returned an empty commit hash; supply --checksum instead"
    );

    Ok(sha)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_custom_checksum() {
        let result = resolve(Some("beef"));
        assert_eq!(result.unwrap(), "beef");
    }

    #[test]
    fn rejects_empty_checksum() {
        let error = resolve(Some("   ")).unwrap_err();
        assert!(format!("{error}").contains("checksum"));
    }
}
