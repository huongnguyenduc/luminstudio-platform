use std::process::ExitCode;

use worker_3d::{Config, startup_message};

fn main() -> ExitCode {
    match Config::from_env() {
        Ok(config) => {
            println!("{}", startup_message(&config));
            ExitCode::SUCCESS
        }
        Err(error) => {
            eprintln!("worker-3d configuration error: {error}");
            ExitCode::from(2)
        }
    }
}
