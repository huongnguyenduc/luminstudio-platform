use crate::glb_optimizer::{OptimizationConfig, optimize_glb, optimized_object_key};
use crate::sprite_renderer::sprite_object_key;
use crate::{ObjectRef, ProcessingTask, TaskEventHandler, TaskProcessor};
use serde::Serialize;
use std::fmt;

pub const OPTIMIZED_BUCKET: &str = "lumin-optimized-glb";
pub const SPRITE_BUCKET: &str = "lumin-360-sprites";
pub const TASK_COMPLETED_SUBJECT: &str = "lumin.3d.task.completed";

#[derive(Debug, Clone, Serialize, Eq, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct TaskCompletedEvent {
    pub id: String,
    #[serde(rename = "type")]
    pub event_type: String,
    pub schema_version: String,
    pub occurred_at: String,
    pub correlation_id: String,
    pub payload: TaskCompletedPayload,
}

#[derive(Debug, Clone, Serialize, Eq, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct TaskCompletedPayload {
    pub task_id: String,
    pub product_id: String,
    pub optimized_asset: ObjectRef,
    pub sprite_asset: ObjectRef,
}

pub trait GlbOptimizer {
    fn optimize(&mut self, source: &[u8]) -> Result<Vec<u8>, String>;
}

pub struct MeshoptGlbOptimizer {
    config: OptimizationConfig,
}

impl MeshoptGlbOptimizer {
    pub fn new(config: OptimizationConfig) -> Self {
        Self { config }
    }
}

impl GlbOptimizer for MeshoptGlbOptimizer {
    fn optimize(&mut self, source: &[u8]) -> Result<Vec<u8>, String> {
        optimize_glb(source, self.config)
            .map(|output| output.bytes)
            .map_err(|error| error.to_string())
    }
}

pub trait SpriteRenderer {
    fn render(&mut self, task_id: &str, source: &[u8]) -> Result<Vec<u8>, String>;
}

pub trait ProcessedAssetStore {
    fn put_processed_asset(
        &mut self,
        bucket: &str,
        key: &str,
        content_type: &str,
        bytes: Vec<u8>,
    ) -> Result<ObjectRef, String>;
}

pub trait CompletionPublisher {
    fn publish_task_completed(&mut self, event: &TaskCompletedEvent) -> Result<(), String>;
}

pub trait Clock {
    fn now_rfc3339(&mut self) -> Result<String, String>;
}

#[derive(Debug, Eq, PartialEq)]
pub enum PipelineError {
    Optimize(String),
    Render(String),
    UploadOptimized(String),
    UploadSprite(String),
    Clock(String),
    Publish(String),
    InvalidProduct(String),
}

impl fmt::Display for PipelineError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Optimize(error) => write!(formatter, "optimize source GLB: {error}"),
            Self::Render(error) => write!(formatter, "render 360 sprite: {error}"),
            Self::UploadOptimized(error) => write!(formatter, "upload optimized GLB: {error}"),
            Self::UploadSprite(error) => write!(formatter, "upload 360 sprite: {error}"),
            Self::Clock(error) => write!(formatter, "create completion timestamp: {error}"),
            Self::Publish(error) => write!(formatter, "publish 3d.task.completed: {error}"),
            Self::InvalidProduct(error) => {
                write!(formatter, "derive processed object key: {error}")
            }
        }
    }
}

impl std::error::Error for PipelineError {}

pub struct ProcessingPipeline<O, R, S, P, C> {
    optimizer: O,
    renderer: R,
    asset_store: S,
    publisher: P,
    clock: C,
}

impl<O, R, S, P, C> ProcessingPipeline<O, R, S, P, C>
where
    O: GlbOptimizer,
    R: SpriteRenderer,
    S: ProcessedAssetStore,
    P: CompletionPublisher,
    C: Clock,
{
    pub fn new(optimizer: O, renderer: R, asset_store: S, publisher: P, clock: C) -> Self {
        Self {
            optimizer,
            renderer,
            asset_store,
            publisher,
            clock,
        }
    }

    pub fn process(&mut self, task: ProcessingTask) -> Result<TaskCompletedEvent, PipelineError> {
        let optimized_key = optimized_object_key(&task.product_id)
            .map_err(|error| PipelineError::InvalidProduct(error.to_string()))?;
        let sprite_key = sprite_object_key(&task.product_id)
            .map_err(|error| PipelineError::InvalidProduct(error.to_owned()))?;

        let optimized_bytes = self
            .optimizer
            .optimize(&task.source_bytes)
            .map_err(PipelineError::Optimize)?;
        let sprite_bytes = self
            .renderer
            .render(&task.task_id, &task.source_bytes)
            .map_err(PipelineError::Render)?;

        let optimized_asset = self
            .asset_store
            .put_processed_asset(
                OPTIMIZED_BUCKET,
                &optimized_key,
                "model/gltf-binary",
                optimized_bytes,
            )
            .map_err(PipelineError::UploadOptimized)?;
        let sprite_asset = self
            .asset_store
            .put_processed_asset(SPRITE_BUCKET, &sprite_key, "image/jpeg", sprite_bytes)
            .map_err(PipelineError::UploadSprite)?;

        let event = TaskCompletedEvent {
            id: format!("{}-completed", task.task_id),
            event_type: "3d.task.completed".to_owned(),
            schema_version: "v1".to_owned(),
            occurred_at: self.clock.now_rfc3339().map_err(PipelineError::Clock)?,
            correlation_id: task.correlation_id,
            payload: TaskCompletedPayload {
                task_id: task.task_id,
                product_id: task.product_id,
                optimized_asset,
                sprite_asset,
            },
        };
        self.publisher
            .publish_task_completed(&event)
            .map_err(PipelineError::Publish)?;
        Ok(event)
    }
}

pub struct RuntimeTaskHandler<Reader, O, R, S, P, C> {
    task_processor: TaskProcessor<Reader>,
    pipeline: ProcessingPipeline<O, R, S, P, C>,
}

impl<Reader, O, R, S, P, C> RuntimeTaskHandler<Reader, O, R, S, P, C> {
    pub fn new(
        task_processor: TaskProcessor<Reader>,
        pipeline: ProcessingPipeline<O, R, S, P, C>,
    ) -> Self {
        Self {
            task_processor,
            pipeline,
        }
    }
}

impl<Reader, O, R, S, P, C> TaskEventHandler for RuntimeTaskHandler<Reader, O, R, S, P, C>
where
    Reader: crate::SourceAssetReader,
    O: GlbOptimizer,
    R: SpriteRenderer,
    S: ProcessedAssetStore,
    P: CompletionPublisher,
    C: Clock,
{
    fn handle_task_created(&mut self, data: &[u8]) -> Result<(), String> {
        let task = self
            .task_processor
            .handle_task_created(data)
            .map_err(|error| error.to_string())?;
        self.pipeline
            .process(task)
            .map(|_| ())
            .map_err(|error| error.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::MeshColorConfig;

    #[test]
    fn uploads_both_assets_before_publishing_completion() {
        let mut pipeline = ProcessingPipeline::new(
            OptimizerStub,
            RendererStub,
            StoreStub::default(),
            PublisherStub::default(),
            ClockStub,
        );

        let event = pipeline.process(task()).expect("process task");

        assert_eq!(event.event_type, "3d.task.completed");
        assert_eq!(event.schema_version, "v1");
        assert_eq!(event.correlation_id, "corr_12345678");
        assert_eq!(event.payload.task_id, "task_12345678");
        assert_eq!(event.payload.product_id, "prod_12345678");
        assert_eq!(event.payload.optimized_asset.bucket, OPTIMIZED_BUCKET);
        assert_eq!(event.payload.optimized_asset.key, "prod_12345678_low.glb");
        assert_eq!(event.payload.optimized_asset.size_bytes, Some(9));
        assert_eq!(event.payload.sprite_asset.bucket, SPRITE_BUCKET);
        assert_eq!(
            event.payload.sprite_asset.key,
            "prod_12345678_360_sprite.jpg"
        );

        let json = serde_json::to_value(&event).expect("serialize event");
        assert_eq!(json["type"], "3d.task.completed");
        assert_eq!(json["occurredAt"], "2026-06-15T12:00:00Z");
        assert_eq!(
            json["payload"]["optimizedAsset"]["contentType"],
            "model/gltf-binary"
        );
        assert_eq!(json["payload"]["spriteAsset"]["contentType"], "image/jpeg");
    }

    #[test]
    fn does_not_publish_when_second_upload_fails() {
        let mut pipeline = ProcessingPipeline::new(
            OptimizerStub,
            RendererStub,
            StoreStub {
                upload_count: 0,
                fail_second: true,
            },
            PublisherStub::default(),
            ClockStub,
        );

        let error = pipeline
            .process(task())
            .expect_err("sprite upload must fail");

        assert_eq!(
            error,
            PipelineError::UploadSprite("store unavailable".to_owned())
        );
        assert!(pipeline.publisher.events.is_empty());
    }

    #[test]
    fn does_not_upload_or_publish_when_optimization_fails() {
        let mut pipeline = ProcessingPipeline::new(
            FailingOptimizer,
            RendererStub,
            StoreStub::default(),
            PublisherStub::default(),
            ClockStub,
        );

        let error = pipeline
            .process(task())
            .expect_err("optimization must fail");

        assert_eq!(error, PipelineError::Optimize("unsupported GLB".to_owned()));
        assert_eq!(pipeline.asset_store.upload_count, 0);
        assert!(pipeline.publisher.events.is_empty());
    }

    #[test]
    fn runtime_handler_composes_event_parsing_source_read_and_pipeline() {
        let task_processor = TaskProcessor::new(ReaderStub);
        let pipeline = ProcessingPipeline::new(
            OptimizerStub,
            RendererStub,
            StoreStub::default(),
            PublisherStub::default(),
            ClockStub,
        );
        let mut handler = RuntimeTaskHandler::new(task_processor, pipeline);

        handler
            .handle_task_created(valid_task_created_json().as_bytes())
            .expect("handle raw task event");

        assert_eq!(handler.pipeline.publisher.events.len(), 1);
        assert_eq!(
            handler.pipeline.publisher.events[0].payload.product_id,
            "prod_12345678"
        );
    }

    fn task() -> ProcessingTask {
        ProcessingTask {
            event_id: "event_12345678".to_owned(),
            task_id: "task_12345678".to_owned(),
            product_id: "prod_12345678".to_owned(),
            correlation_id: "corr_12345678".to_owned(),
            source_asset: ObjectRef {
                bucket: "lumin-source-glb".to_owned(),
                key: "products/prod_12345678/source.glb".to_owned(),
                content_type: Some("model/gltf-binary".to_owned()),
                etag: None,
                size_bytes: Some(4),
            },
            mesh_color_config: MeshColorConfig::new(),
            source_bytes: b"glTF".to_vec(),
        }
    }

    struct OptimizerStub;

    impl GlbOptimizer for OptimizerStub {
        fn optimize(&mut self, source: &[u8]) -> Result<Vec<u8>, String> {
            assert_eq!(source, b"glTF");
            Ok(b"optimized".to_vec())
        }
    }

    struct FailingOptimizer;

    impl GlbOptimizer for FailingOptimizer {
        fn optimize(&mut self, _source: &[u8]) -> Result<Vec<u8>, String> {
            Err("unsupported GLB".to_owned())
        }
    }

    struct RendererStub;

    impl SpriteRenderer for RendererStub {
        fn render(&mut self, task_id: &str, source: &[u8]) -> Result<Vec<u8>, String> {
            assert_eq!(task_id, "task_12345678");
            assert_eq!(source, b"glTF");
            Ok(b"jpeg".to_vec())
        }
    }

    #[derive(Default)]
    struct StoreStub {
        upload_count: usize,
        fail_second: bool,
    }

    impl ProcessedAssetStore for StoreStub {
        fn put_processed_asset(
            &mut self,
            bucket: &str,
            key: &str,
            content_type: &str,
            bytes: Vec<u8>,
        ) -> Result<ObjectRef, String> {
            self.upload_count += 1;
            if self.fail_second && self.upload_count == 2 {
                return Err("store unavailable".to_owned());
            }
            Ok(ObjectRef {
                bucket: bucket.to_owned(),
                key: key.to_owned(),
                content_type: Some(content_type.to_owned()),
                etag: Some(format!("etag-{}", self.upload_count)),
                size_bytes: Some(bytes.len() as u64),
            })
        }
    }

    #[derive(Default)]
    struct PublisherStub {
        events: Vec<TaskCompletedEvent>,
    }

    impl CompletionPublisher for PublisherStub {
        fn publish_task_completed(&mut self, event: &TaskCompletedEvent) -> Result<(), String> {
            self.events.push(event.clone());
            Ok(())
        }
    }

    struct ClockStub;

    impl Clock for ClockStub {
        fn now_rfc3339(&mut self) -> Result<String, String> {
            Ok("2026-06-15T12:00:00Z".to_owned())
        }
    }

    struct ReaderStub;

    impl crate::SourceAssetReader for ReaderStub {
        fn read_source_asset(&mut self, source: &ObjectRef) -> Result<Vec<u8>, String> {
            assert_eq!(source.bucket, "lumin-source-glb");
            assert_eq!(source.key, "products/prod_12345678/source.glb");
            Ok(b"glTF".to_vec())
        }
    }

    fn valid_task_created_json() -> String {
        r##"{
          "id":"event_12345678",
          "type":"3d.task.created",
          "schemaVersion":"v1",
          "occurredAt":"2026-06-15T12:00:00Z",
          "correlationId":"corr_12345678",
          "payload":{
            "taskId":"task_12345678",
            "productId":"prod_12345678",
            "sourceAsset":{
              "bucket":"lumin-source-glb",
              "key":"products/prod_12345678/source.glb",
              "contentType":"model/gltf-binary"
            },
            "meshColorConfig":{
              "mesh_body":{"default":"#FFFFFF","allowed":["#FFFFFF"]}
            }
          }
        }"##
        .to_owned()
    }
}
