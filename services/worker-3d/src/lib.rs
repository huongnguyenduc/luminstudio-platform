use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};
use std::env;
use std::fmt;
use std::io::{BufRead, BufReader, Read, Write};
use std::net::TcpStream;
use std::time::Duration;

pub mod glb_optimizer;
pub mod processing_pipeline;
pub mod runtime;
pub mod sprite_renderer;

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

const TASK_CREATED_EVENT_TYPE: &str = "3d.task.created";
const EVENT_SCHEMA_VERSION: &str = "v1";
pub const TASK_CREATED_SUBJECT: &str = "lumin.3d.task.created";

#[derive(Debug, Deserialize, Eq, PartialEq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct TaskCreatedEvent {
    pub id: String,
    #[serde(rename = "type")]
    pub event_type: String,
    pub schema_version: String,
    pub occurred_at: String,
    pub correlation_id: String,
    pub payload: TaskCreatedPayload,
}

#[derive(Debug, Deserialize, Eq, PartialEq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct TaskCreatedPayload {
    pub task_id: String,
    pub product_id: String,
    pub source_asset: ObjectRef,
    pub mesh_color_config: MeshColorConfig,
}

#[derive(Debug, Clone, Deserialize, Serialize, Eq, PartialEq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ObjectRef {
    pub bucket: String,
    pub key: String,
    #[serde(default)]
    pub content_type: Option<String>,
    #[serde(default)]
    pub etag: Option<String>,
    #[serde(default)]
    pub size_bytes: Option<u64>,
}

#[derive(Debug, Clone, Deserialize, Eq, PartialEq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct MeshColorOption {
    pub default: String,
    pub allowed: Vec<String>,
}

pub type MeshColorConfig = BTreeMap<String, MeshColorOption>;

#[derive(Debug, Eq, PartialEq)]
pub struct ProcessingTask {
    pub event_id: String,
    pub task_id: String,
    pub product_id: String,
    pub correlation_id: String,
    pub source_asset: ObjectRef,
    pub mesh_color_config: MeshColorConfig,
    pub source_bytes: Vec<u8>,
}

#[derive(Debug, Eq, PartialEq)]
pub enum TaskError {
    InvalidJSON(String),
    InvalidEvent(String),
    SourceRead(String),
}

impl fmt::Display for TaskError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidJSON(error) => write!(formatter, "decode 3d.task.created event: {error}"),
            Self::InvalidEvent(error) => {
                write!(formatter, "invalid 3d.task.created event: {error}")
            }
            Self::SourceRead(error) => write!(formatter, "read source GLB: {error}"),
        }
    }
}

impl std::error::Error for TaskError {}

pub trait SourceAssetReader {
    fn read_source_asset(&mut self, source: &ObjectRef) -> Result<Vec<u8>, String>;
}

pub struct TaskProcessor<R> {
    source_reader: R,
}

impl<R: SourceAssetReader> TaskProcessor<R> {
    pub fn new(source_reader: R) -> Self {
        Self { source_reader }
    }

    pub fn handle_task_created(&mut self, data: &[u8]) -> Result<ProcessingTask, TaskError> {
        let event = parse_task_created_event(data)?;
        let source_bytes = self
            .source_reader
            .read_source_asset(&event.payload.source_asset)
            .map_err(TaskError::SourceRead)?;

        Ok(ProcessingTask {
            event_id: event.id,
            task_id: event.payload.task_id,
            product_id: event.payload.product_id,
            correlation_id: event.correlation_id,
            source_asset: event.payload.source_asset,
            mesh_color_config: event.payload.mesh_color_config,
            source_bytes,
        })
    }
}

pub fn parse_task_created_event(data: &[u8]) -> Result<TaskCreatedEvent, TaskError> {
    let mut deserializer = serde_json::Deserializer::from_slice(data);
    let event = TaskCreatedEvent::deserialize(&mut deserializer)
        .map_err(|error| TaskError::InvalidJSON(error.to_string()))?;
    deserializer
        .end()
        .map_err(|error| TaskError::InvalidJSON(error.to_string()))?;
    validate_task_created_event(&event)?;
    Ok(event)
}

fn validate_task_created_event(event: &TaskCreatedEvent) -> Result<(), TaskError> {
    if !valid_event_id(&event.id) {
        return invalid_event("id must match the v1 event id contract");
    }
    if event.event_type != TASK_CREATED_EVENT_TYPE || event.schema_version != EVENT_SCHEMA_VERSION {
        return invalid_event("event must be a v1 3d.task.created envelope");
    }
    if event.occurred_at.trim().is_empty() {
        return invalid_event("occurredAt is required");
    }
    if !valid_correlation_id(&event.correlation_id) {
        return invalid_event("correlationId must match the v1 contract");
    }
    if !valid_prefixed_id(&event.payload.task_id, "task_") {
        return invalid_event("taskId must match the v1 processing task id contract");
    }
    if !valid_prefixed_id(&event.payload.product_id, "prod_") {
        return invalid_event("productId must match the v1 product id contract");
    }
    validate_source_asset(&event.payload.source_asset)?;
    validate_mesh_color_config(&event.payload.mesh_color_config)?;
    Ok(())
}

fn validate_source_asset(source: &ObjectRef) -> Result<(), TaskError> {
    if source.bucket != "lumin-source-glb" {
        return invalid_event("sourceAsset.bucket must be lumin-source-glb");
    }
    if source.key.is_empty() || source.key.len() > 1024 || !valid_object_key(&source.key) {
        return invalid_event("sourceAsset.key must match the v1 object key contract");
    }
    if matches!(source.content_type.as_ref(), Some(value) if value.is_empty() || value.len() > 128)
    {
        return invalid_event("sourceAsset.contentType must be from 1 to 128 characters");
    }
    if matches!(source.etag.as_ref(), Some(value) if value.is_empty() || value.len() > 256) {
        return invalid_event("sourceAsset.etag must be from 1 to 256 characters");
    }
    Ok(())
}

fn validate_mesh_color_config(config: &MeshColorConfig) -> Result<(), TaskError> {
    if config.is_empty() {
        return invalid_event("meshColorConfig must contain at least one mesh");
    }
    for (mesh_id, option) in config {
        if !valid_mesh_id(mesh_id) {
            return invalid_event("meshColorConfig mesh id must match the v1 contract");
        }
        if !valid_hex_color(&option.default) {
            return invalid_event("meshColorConfig default must be a hex color");
        }
        if option.allowed.is_empty() {
            return invalid_event("meshColorConfig allowed must contain at least one color");
        }
        let mut seen = BTreeSet::new();
        for color in &option.allowed {
            if !valid_hex_color(color) {
                return invalid_event("meshColorConfig allowed contains an invalid hex color");
            }
            if !seen.insert(color.to_ascii_uppercase()) {
                return invalid_event("meshColorConfig allowed colors must be unique");
            }
        }
        if !seen.contains(&option.default.to_ascii_uppercase()) {
            return invalid_event("meshColorConfig default color must be in allowed");
        }
    }
    Ok(())
}

fn invalid_event<T>(message: &str) -> Result<T, TaskError> {
    Err(TaskError::InvalidEvent(message.to_owned()))
}

fn valid_event_id(value: &str) -> bool {
    valid_length_without_outer_space(value, 8, 128)
}

fn valid_correlation_id(value: &str) -> bool {
    valid_length_without_outer_space(value, 8, 128)
}

fn valid_length_without_outer_space(value: &str, min: usize, max: usize) -> bool {
    let length = value.len();
    length >= min && length <= max && value.trim() == value
}

fn valid_prefixed_id(value: &str, prefix: &str) -> bool {
    let Some(rest) = value.strip_prefix(prefix) else {
        return false;
    };
    rest.len() >= 8
        && rest.len() <= 64
        && rest
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || byte == b'_' || byte == b'-')
        && rest
            .as_bytes()
            .first()
            .is_some_and(u8::is_ascii_alphanumeric)
}

fn valid_object_key(value: &str) -> bool {
    value
        .as_bytes()
        .first()
        .is_some_and(u8::is_ascii_alphanumeric)
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'/' | b'-'))
}

fn valid_mesh_id(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 128
        && value
            .as_bytes()
            .first()
            .is_some_and(u8::is_ascii_alphanumeric)
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'_' | b'.' | b':' | b'-'))
}

fn valid_hex_color(value: &str) -> bool {
    value.len() == 7
        && value.starts_with('#')
        && value.as_bytes()[1..]
            .iter()
            .all(|byte| byte.is_ascii_hexdigit())
}

pub trait TaskEventHandler {
    fn handle_task_created(&mut self, data: &[u8]) -> Result<(), String>;
}

pub struct NATSSubscriber {
    host: String,
    subject: String,
    queue_group: String,
    sid: String,
    timeout: Duration,
}

impl NATSSubscriber {
    pub fn new(host: impl Into<String>, timeout: Duration) -> Self {
        Self {
            host: host.into(),
            subject: TASK_CREATED_SUBJECT.to_owned(),
            queue_group: "worker-3d".to_owned(),
            sid: "1".to_owned(),
            timeout,
        }
    }

    pub fn run_once<H: TaskEventHandler>(&self, handler: &mut H) -> Result<(), String> {
        if self.host.trim().is_empty() {
            return Err("NATS host is not configured".to_owned());
        }
        let mut stream = TcpStream::connect(&self.host).map_err(|error| error.to_string())?;
        stream
            .set_read_timeout(Some(self.timeout))
            .map_err(|error| error.to_string())?;
        stream
            .set_write_timeout(Some(self.timeout))
            .map_err(|error| error.to_string())?;

        let mut reader = BufReader::new(stream.try_clone().map_err(|error| error.to_string())?);
        let mut line = String::new();
        reader
            .read_line(&mut line)
            .map_err(|error| format!("read NATS greeting: {error}"))?;
        if !line.starts_with("INFO ") {
            return Err("unexpected NATS greeting".to_owned());
        }

        write!(
            stream,
            "SUB {} {} {}\r\nPING\r\n",
            self.subject, self.queue_group, self.sid
        )
        .map_err(|error| format!("subscribe to 3d.task.created: {error}"))?;
        stream.flush().map_err(|error| error.to_string())?;

        loop {
            line.clear();
            reader
                .read_line(&mut line)
                .map_err(|error| error.to_string())?;
            let trimmed = line.trim_end_matches(['\r', '\n']);
            if trimmed == "PONG" || trimmed.starts_with("+OK") {
                continue;
            }
            if let Some(length) = parse_nats_msg_length(trimmed, &self.subject, &self.sid)? {
                let mut data = vec![0; length];
                reader
                    .read_exact(&mut data)
                    .map_err(|error| format!("read NATS message body: {error}"))?;
                let mut terminator = [0; 2];
                reader
                    .read_exact(&mut terminator)
                    .map_err(|error| format!("read NATS message terminator: {error}"))?;
                if terminator != [b'\r', b'\n'] {
                    return Err("invalid NATS message terminator".to_owned());
                }
                return handler.handle_task_created(&data);
            }
        }
    }
}

fn parse_nats_msg_length(line: &str, subject: &str, sid: &str) -> Result<Option<usize>, String> {
    let parts = line.split_whitespace().collect::<Vec<_>>();
    if parts.is_empty() {
        return Ok(None);
    }
    if parts[0] != "MSG" {
        return Err(format!("unexpected NATS line: {line}"));
    }
    if parts.len() != 4 || parts[1] != subject || parts[2] != sid {
        return Err("unexpected NATS message subject or sid".to_owned());
    }
    parts[3]
        .parse::<usize>()
        .map(Some)
        .map_err(|_| "invalid NATS message length".to_owned())
}

#[cfg(test)]
mod tests {
    use super::{
        Config, ConfigError, ObjectRef, SourceAssetReader, TASK_CREATED_SUBJECT, TaskError,
        TaskProcessor, parse_task_created_event, startup_message,
    };

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

    #[test]
    fn parses_v1_task_created_event() {
        let event = parse_task_created_event(valid_task_created_json().as_bytes())
            .expect("valid task event");

        assert_eq!(event.event_type, "3d.task.created");
        assert_eq!(event.payload.task_id, "task_12345678");
        assert_eq!(event.payload.product_id, "prod_12345678");
        assert_eq!(event.payload.source_asset.bucket, "lumin-source-glb");
        assert_eq!(
            event.payload.mesh_color_config["mesh_body"].default,
            "#FFFFFF"
        );
    }

    #[test]
    fn rejects_wrong_task_created_event_type() {
        let data = valid_task_created_json().replace("3d.task.created", "product.updated");
        let error = parse_task_created_event(data.as_bytes()).expect_err("wrong type must fail");

        assert!(matches!(error, TaskError::InvalidEvent(_)));
    }

    #[test]
    fn rejects_task_created_event_with_unknown_fields() {
        let data = valid_task_created_json()
            .replace("\"payload\":{", "\"extra\":\"not in schema\",\"payload\":{");
        let error = parse_task_created_event(data.as_bytes()).expect_err("unknown field must fail");

        assert!(matches!(error, TaskError::InvalidJSON(_)));
    }

    #[test]
    fn rejects_invalid_mesh_color_config() {
        let data = valid_task_created_json().replace("\"allowed\":[\"#FFFFFF\"]", "\"allowed\":[]");
        let error = parse_task_created_event(data.as_bytes()).expect_err("empty allowed must fail");

        assert!(matches!(error, TaskError::InvalidEvent(_)));
    }

    #[test]
    fn task_processor_downloads_source_asset_from_event() {
        let mut processor = TaskProcessor::new(reader_stub {
            bytes: b"glTF".to_vec(),
            expected_bucket: "lumin-source-glb".to_owned(),
            expected_key: "products/prod_12345678/source.glb".to_owned(),
        });

        let task = processor
            .handle_task_created(valid_task_created_json().as_bytes())
            .expect("process task event");

        assert_eq!(task.task_id, "task_12345678");
        assert_eq!(task.source_bytes, b"glTF");
        assert_eq!(task.source_asset.key, "products/prod_12345678/source.glb");
        assert_eq!(task.mesh_color_config["mesh_body"].allowed, vec!["#FFFFFF"]);
    }

    #[test]
    fn exposes_task_created_nats_subject() {
        assert_eq!(TASK_CREATED_SUBJECT, "lumin.3d.task.created");
    }

    #[allow(non_camel_case_types)]
    struct reader_stub {
        bytes: Vec<u8>,
        expected_bucket: String,
        expected_key: String,
    }

    impl SourceAssetReader for reader_stub {
        fn read_source_asset(&mut self, source: &ObjectRef) -> Result<Vec<u8>, String> {
            assert_eq!(source.bucket, self.expected_bucket);
            assert_eq!(source.key, self.expected_key);
            Ok(self.bytes.clone())
        }
    }

    fn valid_task_created_json() -> String {
        r##"{
            "id":"evt_12345678",
            "type":"3d.task.created",
            "schemaVersion":"v1",
            "occurredAt":"2026-06-15T15:00:00Z",
            "correlationId":"corr_12345678",
            "payload":{
                "taskId":"task_12345678",
                "productId":"prod_12345678",
                "sourceAsset":{
                    "bucket":"lumin-source-glb",
                    "key":"products/prod_12345678/source.glb",
                    "contentType":"model/gltf-binary",
                    "sizeBytes":4
                },
                "meshColorConfig":{
                    "mesh_body":{
                        "default":"#FFFFFF",
                        "allowed":["#FFFFFF"]
                    }
                }
            }
        }"##
        .to_owned()
    }
}
