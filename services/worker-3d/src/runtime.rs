use crate::glb_optimizer::OptimizationConfig;
use crate::processing_pipeline::{
    Clock, CompletionPublisher, MeshoptGlbOptimizer, ProcessedAssetStore, ProcessingPipeline,
    RuntimeTaskHandler, SpriteRenderer, TASK_COMPLETED_SUBJECT, TaskCompletedEvent,
};
use crate::{NATS_CONNECT, NATSSubscriber, ObjectRef, SourceAssetReader, TaskProcessor};
use minio::s3::client::{MinioClient, MinioClientBuilder};
use minio::s3::creds::StaticProvider;
use minio::s3::http::BaseUrl;
use minio::s3::response_traits::HasEtagFromHeaders;
use minio::s3::types::S3Api;
use std::env;
use std::fs;
use std::io::{BufRead, BufReader, Write};
use std::net::TcpStream;
use std::path::PathBuf;
use std::process::Command;
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;
use time::OffsetDateTime;
use time::format_description::well_known::Rfc3339;
use tokio::runtime::Runtime;

static RENDER_DIRECTORY_SEQUENCE: AtomicU64 = AtomicU64::new(1);

pub struct RuntimeConfig {
    pub nats_host: String,
    pub minio_endpoint: String,
    pub minio_access_key: String,
    pub minio_secret_key: String,
    pub blender_binary: PathBuf,
    pub renderer_script: PathBuf,
    pub dependency_timeout: Duration,
}

impl RuntimeConfig {
    pub fn from_env() -> Result<Self, String> {
        Ok(Self {
            nats_host: required_env("NATS_HOST")?,
            minio_endpoint: required_env("MINIO_ENDPOINT")?,
            minio_access_key: required_env("MINIO_ACCESS_KEY")?,
            minio_secret_key: required_env("MINIO_SECRET_KEY")?,
            blender_binary: PathBuf::from(
                env::var("BLENDER_BINARY").unwrap_or_else(|_| "blender".to_owned()),
            ),
            renderer_script: PathBuf::from(required_env("BLENDER_RENDER_SCRIPT")?),
            dependency_timeout: Duration::from_secs(parse_timeout_seconds(
                env::var("WORKER_DEPENDENCY_TIMEOUT_SECONDS")
                    .ok()
                    .as_deref(),
            )?),
        })
    }
}

fn required_env(name: &str) -> Result<String, String> {
    env::var(name)
        .ok()
        .filter(|value| !value.trim().is_empty())
        .ok_or_else(|| format!("{name} is required when WORKER_RUN_ONCE=1"))
}

fn parse_timeout_seconds(value: Option<&str>) -> Result<u64, String> {
    match value {
        None | Some("") => Ok(30),
        Some(raw) => raw
            .parse::<u64>()
            .ok()
            .filter(|seconds| *seconds > 0 && *seconds <= 300)
            .ok_or_else(|| {
                "WORKER_DEPENDENCY_TIMEOUT_SECONDS must be between 1 and 300".to_owned()
            }),
    }
}

#[derive(Clone)]
pub struct MinioAssetStore {
    client: MinioClient,
    runtime: Arc<Runtime>,
}

impl MinioAssetStore {
    pub fn new(endpoint: &str, access_key: &str, secret_key: &str) -> Result<Self, String> {
        let base_url = endpoint
            .parse::<BaseUrl>()
            .map_err(|error| format!("parse MINIO_ENDPOINT: {error}"))?;
        let provider = StaticProvider::new(access_key, secret_key, None);
        let client = MinioClientBuilder::new(base_url)
            .provider(Some(provider))
            .skip_region_lookup(true)
            .build()
            .map_err(|error| format!("create MinIO client: {error}"))?;
        let runtime = Runtime::new().map_err(|error| format!("create async runtime: {error}"))?;
        Ok(Self {
            client,
            runtime: Arc::new(runtime),
        })
    }
}

impl SourceAssetReader for MinioAssetStore {
    fn read_source_asset(&mut self, source: &ObjectRef) -> Result<Vec<u8>, String> {
        let response = self.runtime.block_on(async {
            self.client
                .get_object(&source.bucket, &source.key)
                .map_err(|error| error.to_string())?
                .build()
                .send()
                .await
                .map_err(|error| error.to_string())
        })?;
        let content = response.content().map_err(|error| error.to_string())?;
        let bytes = self
            .runtime
            .block_on(content.to_segmented_bytes())
            .map_err(|error| error.to_string())?;
        Ok(bytes.to_bytes().to_vec())
    }
}

impl ProcessedAssetStore for MinioAssetStore {
    fn put_processed_asset(
        &mut self,
        bucket: &str,
        key: &str,
        content_type: &str,
        bytes: Vec<u8>,
    ) -> Result<ObjectRef, String> {
        let size_bytes = bytes.len() as u64;
        let response = self.runtime.block_on(async {
            self.client
                .put_object_content(bucket, key, bytes)
                .map_err(|error| error.to_string())?
                .content_type(Some(content_type.to_owned()))
                .build()
                .send()
                .await
                .map_err(|error| error.to_string())
        })?;
        let etag = response
            .etag()
            .map_err(|error| error.to_string())?
            .to_string();
        Ok(ObjectRef {
            bucket: bucket.to_owned(),
            key: key.to_owned(),
            content_type: Some(content_type.to_owned()),
            etag: Some(etag),
            size_bytes: Some(size_bytes),
        })
    }
}

pub struct BlenderSpriteRenderer {
    binary: PathBuf,
    script: PathBuf,
}

impl BlenderSpriteRenderer {
    pub fn new(binary: PathBuf, script: PathBuf) -> Result<Self, String> {
        if !script.is_file() {
            return Err(format!(
                "Blender renderer script does not exist: {}",
                script.display()
            ));
        }
        Ok(Self { binary, script })
    }
}

impl SpriteRenderer for BlenderSpriteRenderer {
    fn render(&mut self, task_id: &str, source: &[u8]) -> Result<Vec<u8>, String> {
        let sequence = RENDER_DIRECTORY_SEQUENCE.fetch_add(1, Ordering::Relaxed);
        let directory = env::temp_dir().join(format!(
            "lumin-worker-{task_id}-{}-{sequence}",
            std::process::id()
        ));
        fs::create_dir(&directory)
            .map_err(|error| format!("create render directory {}: {error}", directory.display()))?;
        let cleanup = TemporaryDirectory(directory.clone());
        let input = directory.join("source.glb");
        let output = directory.join("sprite.jpg");
        fs::write(&input, source)
            .map_err(|error| format!("write Blender input {}: {error}", input.display()))?;

        let result = Command::new(&self.binary)
            .args([
                "--background",
                "--factory-startup",
                "--disable-autoexec",
                "--python-exit-code",
                "1",
                "--python",
            ])
            .arg(&self.script)
            .arg("--")
            .arg(&input)
            .arg(&output)
            .output()
            .map_err(|error| format!("start Blender {}: {error}", self.binary.display()))?;
        if !result.status.success() {
            return Err(format!(
                "Blender exited with {}: {}",
                result.status,
                String::from_utf8_lossy(&result.stderr).trim()
            ));
        }
        let bytes = fs::read(&output)
            .map_err(|error| format!("read rendered sprite {}: {error}", output.display()))?;
        drop(cleanup);
        Ok(bytes)
    }
}

struct TemporaryDirectory(PathBuf);

impl Drop for TemporaryDirectory {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

pub struct NATSTaskCompletedPublisher {
    host: String,
    timeout: Duration,
}

impl NATSTaskCompletedPublisher {
    pub fn new(host: String, timeout: Duration) -> Self {
        Self { host, timeout }
    }
}

impl CompletionPublisher for NATSTaskCompletedPublisher {
    fn publish_task_completed(&mut self, event: &TaskCompletedEvent) -> Result<(), String> {
        let payload = serde_json::to_vec(event)
            .map_err(|error| format!("encode completion event: {error}"))?;
        publish_nats(&self.host, self.timeout, TASK_COMPLETED_SUBJECT, &payload)
    }
}

fn publish_nats(
    host: &str,
    timeout: Duration,
    subject: &str,
    payload: &[u8],
) -> Result<(), String> {
    let mut stream = TcpStream::connect(host).map_err(|error| error.to_string())?;
    stream
        .set_read_timeout(Some(timeout))
        .map_err(|error| error.to_string())?;
    stream
        .set_write_timeout(Some(timeout))
        .map_err(|error| error.to_string())?;
    let mut reader = BufReader::new(stream.try_clone().map_err(|error| error.to_string())?);
    let mut line = String::new();
    reader
        .read_line(&mut line)
        .map_err(|error| format!("read NATS greeting: {error}"))?;
    if !line.starts_with("INFO ") {
        return Err("unexpected NATS greeting".to_owned());
    }
    write!(stream, "{NATS_CONNECT}PUB {subject} {}\r\n", payload.len())
        .and_then(|_| stream.write_all(payload))
        .and_then(|_| stream.write_all(b"\r\nPING\r\n"))
        .and_then(|_| stream.flush())
        .map_err(|error| format!("publish completion event: {error}"))?;
    loop {
        line.clear();
        reader
            .read_line(&mut line)
            .map_err(|error| format!("confirm completion publication: {error}"))?;
        match line.trim_end_matches(['\r', '\n']) {
            "PONG" => return Ok(()),
            "PING" => stream
                .write_all(b"PONG\r\n")
                .and_then(|_| stream.flush())
                .map_err(|error| format!("respond to NATS ping: {error}"))?,
            value if value.starts_with("+OK") => continue,
            value if value.starts_with("-ERR") => return Err(value.to_owned()),
            value => return Err(format!("unexpected NATS publication response: {value}")),
        }
    }
}

pub struct SystemClock;

impl Clock for SystemClock {
    fn now_rfc3339(&mut self) -> Result<String, String> {
        OffsetDateTime::now_utc()
            .format(&Rfc3339)
            .map_err(|error| error.to_string())
    }
}

pub fn run_once(config: RuntimeConfig) -> Result<(), String> {
    let store = MinioAssetStore::new(
        &config.minio_endpoint,
        &config.minio_access_key,
        &config.minio_secret_key,
    )?;
    let reader = store.clone();
    let renderer = BlenderSpriteRenderer::new(config.blender_binary, config.renderer_script)?;
    let publisher =
        NATSTaskCompletedPublisher::new(config.nats_host.clone(), config.dependency_timeout);
    let pipeline = ProcessingPipeline::new(
        MeshoptGlbOptimizer::new(OptimizationConfig::default()),
        renderer,
        store,
        publisher,
        SystemClock,
    );
    let mut handler = RuntimeTaskHandler::new(TaskProcessor::new(reader), pipeline);
    NATSSubscriber::new(config.nats_host, config.dependency_timeout).run_once(&mut handler)
}

pub fn run_once_from_env() -> Result<(), String> {
    run_once(RuntimeConfig::from_env()?)
}

pub fn run_forever(config: RuntimeConfig) -> Result<(), String> {
    let store = MinioAssetStore::new(
        &config.minio_endpoint,
        &config.minio_access_key,
        &config.minio_secret_key,
    )?;
    let reader = store.clone();
    let renderer = BlenderSpriteRenderer::new(config.blender_binary, config.renderer_script)?;
    let publisher =
        NATSTaskCompletedPublisher::new(config.nats_host.clone(), config.dependency_timeout);
    let pipeline = ProcessingPipeline::new(
        MeshoptGlbOptimizer::new(OptimizationConfig::default()),
        renderer,
        store,
        publisher,
        SystemClock,
    );
    let mut handler = RuntimeTaskHandler::new(TaskProcessor::new(reader), pipeline);
    let subscriber = NATSSubscriber::new(config.nats_host, config.dependency_timeout);
    loop {
        match subscriber.run_forever(&mut handler) {
            Ok(()) => return Ok(()),
            Err(error) if error.starts_with("connect to NATS:") => {
                eprintln!("worker-3d waiting for NATS: {error}");
                std::thread::sleep(Duration::from_secs(2));
            }
            Err(error) => return Err(error),
        }
    }
}

pub fn run_forever_from_env() -> Result<(), String> {
    run_forever(RuntimeConfig::from_env()?)
}

pub fn runtime_once_enabled() -> bool {
    env::var("WORKER_RUN_ONCE").as_deref() == Ok("1")
}

pub fn runtime_enabled() -> bool {
    env::var("WORKER_RUNTIME").as_deref() == Ok("1")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_dependency_timeout() {
        assert_eq!(parse_timeout_seconds(None), Ok(30));
        assert_eq!(parse_timeout_seconds(Some("15")), Ok(15));
        assert!(parse_timeout_seconds(Some("0")).is_err());
        assert!(parse_timeout_seconds(Some("301")).is_err());
        assert!(parse_timeout_seconds(Some("slow")).is_err());
    }

    #[test]
    fn rejects_missing_renderer_script() {
        let error = BlenderSpriteRenderer::new(
            std::path::Path::new("blender").to_path_buf(),
            std::path::Path::new("missing-renderer.py").to_path_buf(),
        )
        .err()
        .expect("missing script must fail");

        assert!(error.contains("does not exist"));
    }

    #[test]
    fn exposes_completion_subject() {
        assert_eq!(TASK_COMPLETED_SUBJECT, "lumin.3d.task.completed");
    }

    #[test]
    fn runtime_modes_are_separate() {
        unsafe {
            env::set_var("WORKER_RUN_ONCE", "1");
            env::remove_var("WORKER_RUNTIME");
        }
        assert!(runtime_once_enabled());
        assert!(!runtime_enabled());

        unsafe {
            env::remove_var("WORKER_RUN_ONCE");
            env::set_var("WORKER_RUNTIME", "1");
        }
        assert!(!runtime_once_enabled());
        assert!(runtime_enabled());

        unsafe {
            env::remove_var("WORKER_RUNTIME");
        }
    }
}
