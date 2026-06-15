use std::env;
use std::fmt;

const DEFAULT_CONCURRENCY: usize = 1;

#[derive(Debug, Eq, PartialEq)]
pub struct Config {
    pub concurrency: usize,
}

#[derive(Debug, Eq, PartialEq)]
pub enum ConfigError {
    InvalidConcurrency(String),
}

impl fmt::Display for ConfigError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidConcurrency(value) => write!(
                formatter,
                "WORKER_CONCURRENCY must be a positive integer, got {value:?}"
            ),
        }
    }
}

impl std::error::Error for ConfigError {}

impl Config {
    pub fn from_env() -> Result<Self, ConfigError> {
        let value = env::var("WORKER_CONCURRENCY").ok();
        Self::parse(value.as_deref())
    }

    pub fn parse(value: Option<&str>) -> Result<Self, ConfigError> {
        let concurrency = match value {
            None | Some("") => DEFAULT_CONCURRENCY,
            Some(raw) => raw
                .parse::<usize>()
                .ok()
                .filter(|parsed| *parsed > 0)
                .ok_or_else(|| ConfigError::InvalidConcurrency(raw.to_owned()))?,
        };

        Ok(Self { concurrency })
    }
}

pub fn startup_message(config: &Config) -> String {
    format!(
        "{{\"level\":\"info\",\"component\":\"worker-3d\",\"status\":\"ready\",\"concurrency\":{}}}",
        config.concurrency
    )
}

#[cfg(test)]
mod tests {
    use super::{Config, ConfigError, startup_message};

    #[test]
    fn defaults_to_one_worker() {
        assert_eq!(Config::parse(None), Ok(Config { concurrency: 1 }));
        assert_eq!(Config::parse(Some("")), Ok(Config { concurrency: 1 }));
    }

    #[test]
    fn parses_positive_concurrency() {
        assert_eq!(Config::parse(Some("4")), Ok(Config { concurrency: 4 }));
    }

    #[test]
    fn rejects_invalid_concurrency() {
        assert_eq!(
            Config::parse(Some("0")),
            Err(ConfigError::InvalidConcurrency("0".to_owned()))
        );
        assert_eq!(
            Config::parse(Some("many")),
            Err(ConfigError::InvalidConcurrency("many".to_owned()))
        );
    }

    #[test]
    fn formats_structured_startup_message() {
        assert_eq!(
            startup_message(&Config { concurrency: 2 }),
            "{\"level\":\"info\",\"component\":\"worker-3d\",\"status\":\"ready\",\"concurrency\":2}"
        );
    }
}
