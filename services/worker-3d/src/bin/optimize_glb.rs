use std::env;
use std::fs;
use std::process::ExitCode;

use worker_3d::glb_optimizer::{OptimizationConfig, optimize_glb};

fn main() -> ExitCode {
    let mut args = env::args();
    let program = args.next().unwrap_or_else(|| "optimize-glb".to_owned());
    let Some(input) = args.next() else {
        eprintln!("usage: {program} <input.glb> <output.glb>");
        return ExitCode::from(2);
    };
    let Some(output) = args.next() else {
        eprintln!("usage: {program} <input.glb> <output.glb>");
        return ExitCode::from(2);
    };
    if args.next().is_some() {
        eprintln!("usage: {program} <input.glb> <output.glb>");
        return ExitCode::from(2);
    }

    let source = match fs::read(&input) {
        Ok(source) => source,
        Err(error) => {
            eprintln!("read {input}: {error}");
            return ExitCode::FAILURE;
        }
    };
    let optimized = match optimize_glb(&source, OptimizationConfig::default()) {
        Ok(optimized) => optimized,
        Err(error) => {
            eprintln!("optimize {input}: {error}");
            return ExitCode::FAILURE;
        }
    };
    if let Err(error) = fs::write(&output, &optimized.bytes) {
        eprintln!("write {output}: {error}");
        return ExitCode::FAILURE;
    }

    println!(
        "{{\"input_bytes\":{},\"output_bytes\":{},\"primitives\":{},\"input_triangles\":{},\"output_triangles\":{}}}",
        optimized.report.source_bytes,
        optimized.report.optimized_bytes,
        optimized.report.primitives_optimized,
        optimized.report.source_triangles,
        optimized.report.optimized_triangles,
    );
    ExitCode::SUCCESS
}
