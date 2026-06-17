use std::process::ExitCode;

use worker_3d::runtime::{
    run_forever_from_env, run_once_from_env, runtime_enabled, runtime_once_enabled,
};
use worker_3d::{Config, startup_message};

fn main() -> ExitCode {
    if runtime_once_enabled() {
        return match run_once_from_env() {
            Ok(()) => ExitCode::SUCCESS,
            Err(error) => {
                eprintln!("worker-3d runtime error: {error}");
                ExitCode::from(1)
            }
        };
    }
    if runtime_enabled() {
        return match run_forever_from_env() {
            Ok(()) => ExitCode::SUCCESS,
            Err(error) => {
                eprintln!("worker-3d runtime error: {error}");
                ExitCode::from(1)
            }
        };
    }
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
