use meshopt::{SimplifyOptions, VertexDataAdapter, simplify};
use serde_json::Value;
use std::collections::{BTreeMap, BTreeSet};
use std::fmt;

const GLB_MAGIC: &[u8; 4] = b"glTF";
const GLB_VERSION: u32 = 2;
const JSON_CHUNK_TYPE: u32 = 0x4e4f534a;
const BIN_CHUNK_TYPE: u32 = 0x004e4942;
const TRIANGLES_MODE: u64 = 4;
const UNSIGNED_SHORT: u64 = 5123;
const UNSIGNED_INT: u64 = 5125;
const FLOAT: u64 = 5126;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct OptimizationConfig {
    pub target_ratio: f32,
    pub target_error: f32,
}

impl Default for OptimizationConfig {
    fn default() -> Self {
        Self {
            target_ratio: 0.5,
            target_error: 0.01,
        }
    }
}

#[derive(Debug, Eq, PartialEq)]
pub struct OptimizationReport {
    pub source_bytes: usize,
    pub optimized_bytes: usize,
    pub primitives_optimized: usize,
    pub source_triangles: usize,
    pub optimized_triangles: usize,
}

#[derive(Debug, Eq, PartialEq)]
pub struct OptimizedGlb {
    pub bytes: Vec<u8>,
    pub report: OptimizationReport,
}

#[derive(Debug, Eq, PartialEq)]
pub enum OptimizationError {
    InvalidConfig(String),
    InvalidGlb(String),
    UnsupportedGlb(String),
    Simplification(String),
}

impl fmt::Display for OptimizationError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidConfig(message) => {
                write!(formatter, "invalid optimization config: {message}")
            }
            Self::InvalidGlb(message) => write!(formatter, "invalid GLB: {message}"),
            Self::UnsupportedGlb(message) => write!(formatter, "unsupported GLB: {message}"),
            Self::Simplification(message) => write!(formatter, "simplify GLB: {message}"),
        }
    }
}

impl std::error::Error for OptimizationError {}

pub fn optimized_object_key(product_id: &str) -> Result<String, OptimizationError> {
    let Some(id) = product_id.strip_prefix("prod_") else {
        return Err(OptimizationError::InvalidConfig(
            "product id must start with prod_".to_owned(),
        ));
    };
    if id.len() < 8
        || id.len() > 64
        || !id.as_bytes().first().is_some_and(u8::is_ascii_alphanumeric)
        || !id
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'_' | b'-'))
    {
        return Err(OptimizationError::InvalidConfig(
            "product id must match the v1 product identity contract".to_owned(),
        ));
    }

    Ok(format!("{product_id}_low.glb"))
}

pub fn optimize_glb(
    source: &[u8],
    config: OptimizationConfig,
) -> Result<OptimizedGlb, OptimizationError> {
    validate_config(config)?;
    let (mut document, binary) = parse_glb(source)?;
    validate_single_binary_buffer(&document)?;

    let accessor_view_usage = accessor_view_usage(&document)?;
    let primitive_pairs = primitive_accessor_pairs(&document)?;
    if primitive_pairs.is_empty() {
        return Err(OptimizationError::UnsupportedGlb(
            "no indexed triangle primitives were found".to_owned(),
        ));
    }

    let mut replacements = BTreeMap::new();
    let mut source_triangles = 0;
    let mut optimized_triangles = 0;

    for (index_accessor, position_accessor) in primitive_pairs {
        let index_view = accessor_buffer_view(&document, index_accessor)?;
        if accessor_view_usage
            .get(&index_view)
            .is_some_and(|count| *count != 1)
        {
            return Err(OptimizationError::UnsupportedGlb(format!(
                "index bufferView {index_view} is shared by multiple accessors"
            )));
        }

        let indices = read_indices(&document, &binary, index_accessor)?;
        let positions = position_adapter(&document, &binary, position_accessor)?;
        let target_count = target_index_count(indices.len(), config.target_ratio);
        let mut result_error = 0.0;
        let simplified = simplify(
            &indices,
            &positions,
            target_count,
            config.target_error,
            SimplifyOptions::None,
            Some(&mut result_error),
        );
        if simplified.is_empty() || !simplified.len().is_multiple_of(3) {
            return Err(OptimizationError::Simplification(format!(
                "primitive accessor {index_accessor} returned an invalid triangle list"
            )));
        }
        if simplified.len() >= indices.len() {
            return Err(OptimizationError::Simplification(format!(
                "primitive accessor {index_accessor} could not be reduced within error {}",
                config.target_error
            )));
        }

        let replacement = encode_indices(&document, index_accessor, &simplified)?;
        replacements.insert(index_view, replacement);
        update_index_accessor(&mut document, index_accessor, &simplified)?;
        source_triangles += indices.len() / 3;
        optimized_triangles += simplified.len() / 3;
    }

    let optimized_binary = rebuild_binary(&mut document, &binary, &replacements)?;
    update_binary_length(&mut document, optimized_binary.len())?;
    let bytes = encode_glb(&document, &optimized_binary)?;
    let report = OptimizationReport {
        source_bytes: source.len(),
        optimized_bytes: bytes.len(),
        primitives_optimized: replacements.len(),
        source_triangles,
        optimized_triangles,
    };

    Ok(OptimizedGlb { bytes, report })
}

fn validate_config(config: OptimizationConfig) -> Result<(), OptimizationError> {
    if !(0.0..1.0).contains(&config.target_ratio) {
        return Err(OptimizationError::InvalidConfig(
            "target_ratio must be greater than zero and less than one".to_owned(),
        ));
    }
    if !config.target_error.is_finite() || config.target_error <= 0.0 {
        return Err(OptimizationError::InvalidConfig(
            "target_error must be a positive finite number".to_owned(),
        ));
    }
    Ok(())
}

fn parse_glb(source: &[u8]) -> Result<(Value, Vec<u8>), OptimizationError> {
    if source.len() < 20 || &source[..4] != GLB_MAGIC {
        return invalid_glb("missing GLB 2.0 header");
    }
    let version = read_u32(source, 4)?;
    let declared_length = read_u32(source, 8)? as usize;
    if version != GLB_VERSION || declared_length != source.len() {
        return invalid_glb("header version or declared length is invalid");
    }

    let mut offset = 12;
    let mut document = None;
    let mut binary = None;
    while offset < source.len() {
        if source.len() - offset < 8 {
            return invalid_glb("truncated chunk header");
        }
        let chunk_length = read_u32(source, offset)? as usize;
        let chunk_type = read_u32(source, offset + 4)?;
        offset += 8;
        let end = offset
            .checked_add(chunk_length)
            .filter(|end| *end <= source.len())
            .ok_or_else(|| OptimizationError::InvalidGlb("truncated chunk data".to_owned()))?;
        match chunk_type {
            JSON_CHUNK_TYPE if document.is_none() => {
                document = Some(
                    serde_json::from_slice(&source[offset..end]).map_err(|error| {
                        OptimizationError::InvalidGlb(format!("decode JSON chunk: {error}"))
                    })?,
                );
            }
            BIN_CHUNK_TYPE if binary.is_none() => binary = Some(source[offset..end].to_vec()),
            JSON_CHUNK_TYPE | BIN_CHUNK_TYPE => {
                return invalid_glb("duplicate JSON or BIN chunk");
            }
            _ => return unsupported_glb("unknown GLB chunk type"),
        }
        offset = end;
    }

    let document =
        document.ok_or_else(|| OptimizationError::InvalidGlb("missing JSON chunk".to_owned()))?;
    let binary =
        binary.ok_or_else(|| OptimizationError::InvalidGlb("missing BIN chunk".to_owned()))?;
    Ok((document, binary))
}

fn validate_single_binary_buffer(document: &Value) -> Result<(), OptimizationError> {
    let buffers = json_array(document, "buffers")?;
    if buffers.len() != 1 || buffers[0].get("uri").is_some() {
        return unsupported_glb("exactly one embedded binary buffer is required");
    }
    Ok(())
}

fn accessor_view_usage(document: &Value) -> Result<BTreeMap<usize, usize>, OptimizationError> {
    let mut usage = BTreeMap::new();
    for accessor in json_array(document, "accessors")? {
        let view = json_usize(accessor, "bufferView")?;
        *usage.entry(view).or_insert(0) += 1;
    }
    Ok(usage)
}

fn primitive_accessor_pairs(document: &Value) -> Result<Vec<(usize, usize)>, OptimizationError> {
    let mut pairs = Vec::new();
    let mut seen_indices = BTreeSet::new();
    for mesh in json_array(document, "meshes")? {
        for primitive in json_array(mesh, "primitives")? {
            if json_u64_default(primitive, "mode", TRIANGLES_MODE)? != TRIANGLES_MODE {
                return unsupported_glb("only triangle-list primitives are supported");
            }
            let index_accessor = json_usize(primitive, "indices")?;
            if !seen_indices.insert(index_accessor) {
                return unsupported_glb("an index accessor is shared by multiple primitives");
            }
            let position_accessor = primitive
                .get("attributes")
                .and_then(|value| value.get("POSITION"))
                .and_then(Value::as_u64)
                .map(|value| value as usize)
                .ok_or_else(|| {
                    OptimizationError::UnsupportedGlb(
                        "every primitive must have a POSITION accessor".to_owned(),
                    )
                })?;
            pairs.push((index_accessor, position_accessor));
        }
    }
    Ok(pairs)
}

fn read_indices(
    document: &Value,
    binary: &[u8],
    accessor_index: usize,
) -> Result<Vec<u32>, OptimizationError> {
    let accessor = json_index(
        json_array(document, "accessors")?,
        accessor_index,
        "accessor",
    )?;
    if accessor.get("type").and_then(Value::as_str) != Some("SCALAR") {
        return unsupported_glb("index accessors must use SCALAR values");
    }
    let count = json_usize(accessor, "count")?;
    if count < 6 || count % 3 != 0 || accessor.get("sparse").is_some() {
        return unsupported_glb("index accessors must be non-sparse triangle lists");
    }
    let component_type = json_u64(accessor, "componentType")?;
    let component_size = match component_type {
        UNSIGNED_SHORT => 2,
        UNSIGNED_INT => 4,
        _ => return unsupported_glb("indices must use unsigned 16-bit or 32-bit components"),
    };
    let view_index = json_usize(accessor, "bufferView")?;
    let view = json_index(
        json_array(document, "bufferViews")?,
        view_index,
        "bufferView",
    )?;
    if view.get("byteStride").is_some() || json_usize_default(accessor, "byteOffset", 0)? != 0 {
        return unsupported_glb("index accessors must own a tightly packed bufferView");
    }
    let view_bytes = buffer_view_bytes(view, binary)?;
    if view_bytes.len() != count * component_size {
        return unsupported_glb("index bufferView must contain only its accessor data");
    }

    Ok(match component_type {
        UNSIGNED_SHORT => view_bytes
            .chunks_exact(2)
            .map(|chunk| u16::from_le_bytes([chunk[0], chunk[1]]) as u32)
            .collect(),
        UNSIGNED_INT => view_bytes
            .chunks_exact(4)
            .map(|chunk| u32::from_le_bytes(chunk.try_into().expect("four-byte chunk")))
            .collect(),
        _ => unreachable!(),
    })
}

fn position_adapter<'a>(
    document: &Value,
    binary: &'a [u8],
    accessor_index: usize,
) -> Result<VertexDataAdapter<'a>, OptimizationError> {
    let accessor = json_index(
        json_array(document, "accessors")?,
        accessor_index,
        "accessor",
    )?;
    if accessor.get("type").and_then(Value::as_str) != Some("VEC3")
        || json_u64(accessor, "componentType")? != FLOAT
        || accessor.get("sparse").is_some()
    {
        return unsupported_glb("POSITION accessors must be non-sparse float32 VEC3 values");
    }
    let count = json_usize(accessor, "count")?;
    let view_index = json_usize(accessor, "bufferView")?;
    let view = json_index(
        json_array(document, "bufferViews")?,
        view_index,
        "bufferView",
    )?;
    let view_bytes = buffer_view_bytes(view, binary)?;
    let accessor_offset = json_usize_default(accessor, "byteOffset", 0)?;
    let stride = json_usize_default(view, "byteStride", 12)?;
    if stride < 12 || !stride.is_multiple_of(4) {
        return unsupported_glb("POSITION byteStride must be at least 12 and four-byte aligned");
    }
    let data_length = count.checked_mul(stride).ok_or_else(|| {
        OptimizationError::InvalidGlb("POSITION accessor is too large".to_owned())
    })?;
    let end = accessor_offset
        .checked_add(data_length)
        .filter(|end| *end <= view_bytes.len())
        .ok_or_else(|| {
            OptimizationError::InvalidGlb("POSITION accessor exceeds its bufferView".to_owned())
        })?;
    VertexDataAdapter::new(&view_bytes[accessor_offset..end], stride, 0)
        .map_err(|error| OptimizationError::InvalidGlb(error.to_string()))
}

fn encode_indices(
    document: &Value,
    accessor_index: usize,
    indices: &[u32],
) -> Result<Vec<u8>, OptimizationError> {
    let accessor = json_index(
        json_array(document, "accessors")?,
        accessor_index,
        "accessor",
    )?;
    match json_u64(accessor, "componentType")? {
        UNSIGNED_SHORT => {
            let mut bytes = Vec::with_capacity(indices.len() * 2);
            for index in indices {
                let value = u16::try_from(*index).map_err(|_| {
                    OptimizationError::Simplification(
                        "simplified index exceeds the source u16 component type".to_owned(),
                    )
                })?;
                bytes.extend_from_slice(&value.to_le_bytes());
            }
            Ok(bytes)
        }
        UNSIGNED_INT => {
            let mut bytes = Vec::with_capacity(indices.len() * 4);
            for index in indices {
                bytes.extend_from_slice(&index.to_le_bytes());
            }
            Ok(bytes)
        }
        _ => unsupported_glb("unsupported index component type"),
    }
}

fn update_index_accessor(
    document: &mut Value,
    accessor_index: usize,
    indices: &[u32],
) -> Result<(), OptimizationError> {
    let accessors = json_array_mut(document, "accessors")?;
    let accessor = json_index_mut(accessors, accessor_index, "accessor")?;
    let object = accessor
        .as_object_mut()
        .ok_or_else(|| OptimizationError::InvalidGlb("accessor must be an object".to_owned()))?;
    object.insert("count".to_owned(), Value::from(indices.len()));
    if object.contains_key("min") {
        object.insert(
            "min".to_owned(),
            Value::Array(vec![Value::from(
                indices.iter().copied().min().unwrap_or(0),
            )]),
        );
    }
    if object.contains_key("max") {
        object.insert(
            "max".to_owned(),
            Value::Array(vec![Value::from(
                indices.iter().copied().max().unwrap_or(0),
            )]),
        );
    }
    Ok(())
}

fn rebuild_binary(
    document: &mut Value,
    binary: &[u8],
    replacements: &BTreeMap<usize, Vec<u8>>,
) -> Result<Vec<u8>, OptimizationError> {
    let original_views = json_array(document, "bufferViews")?.clone();
    let mut rebuilt = Vec::new();
    let views = json_array_mut(document, "bufferViews")?;
    for (index, view) in views.iter_mut().enumerate() {
        while !rebuilt.len().is_multiple_of(4) {
            rebuilt.push(0);
        }
        let bytes = match replacements.get(&index) {
            Some(replacement) => replacement.as_slice(),
            None => buffer_view_bytes(json_index(&original_views, index, "bufferView")?, binary)?,
        };
        let object = view.as_object_mut().ok_or_else(|| {
            OptimizationError::InvalidGlb("bufferView must be an object".to_owned())
        })?;
        object.insert("byteOffset".to_owned(), Value::from(rebuilt.len()));
        object.insert("byteLength".to_owned(), Value::from(bytes.len()));
        rebuilt.extend_from_slice(bytes);
    }
    Ok(rebuilt)
}

fn update_binary_length(document: &mut Value, length: usize) -> Result<(), OptimizationError> {
    let buffers = json_array_mut(document, "buffers")?;
    let buffer = json_index_mut(buffers, 0, "buffer")?;
    let object = buffer
        .as_object_mut()
        .ok_or_else(|| OptimizationError::InvalidGlb("buffer must be an object".to_owned()))?;
    object.insert("byteLength".to_owned(), Value::from(length));
    Ok(())
}

fn encode_glb(document: &Value, binary: &[u8]) -> Result<Vec<u8>, OptimizationError> {
    let mut json = serde_json::to_vec(document)
        .map_err(|error| OptimizationError::InvalidGlb(format!("encode JSON chunk: {error}")))?;
    while !json.len().is_multiple_of(4) {
        json.push(b' ');
    }
    let mut bin = binary.to_vec();
    while !bin.len().is_multiple_of(4) {
        bin.push(0);
    }
    let total_length = 12usize
        .checked_add(8 + json.len())
        .and_then(|length| length.checked_add(8 + bin.len()))
        .and_then(|length| u32::try_from(length).ok())
        .ok_or_else(|| OptimizationError::InvalidGlb("optimized GLB is too large".to_owned()))?;
    let mut output = Vec::with_capacity(total_length as usize);
    output.extend_from_slice(GLB_MAGIC);
    output.extend_from_slice(&GLB_VERSION.to_le_bytes());
    output.extend_from_slice(&total_length.to_le_bytes());
    output.extend_from_slice(&(json.len() as u32).to_le_bytes());
    output.extend_from_slice(&JSON_CHUNK_TYPE.to_le_bytes());
    output.extend_from_slice(&json);
    output.extend_from_slice(&(bin.len() as u32).to_le_bytes());
    output.extend_from_slice(&BIN_CHUNK_TYPE.to_le_bytes());
    output.extend_from_slice(&bin);
    Ok(output)
}

fn target_index_count(source_count: usize, ratio: f32) -> usize {
    let target_triangles = ((source_count / 3) as f32 * ratio).floor() as usize;
    target_triangles.max(1) * 3
}

fn accessor_buffer_view(
    document: &Value,
    accessor_index: usize,
) -> Result<usize, OptimizationError> {
    let accessor = json_index(
        json_array(document, "accessors")?,
        accessor_index,
        "accessor",
    )?;
    json_usize(accessor, "bufferView")
}

fn buffer_view_bytes<'a>(view: &Value, binary: &'a [u8]) -> Result<&'a [u8], OptimizationError> {
    if json_usize_default(view, "buffer", 0)? != 0 {
        return unsupported_glb("all bufferViews must reference the embedded buffer");
    }
    let offset = json_usize_default(view, "byteOffset", 0)?;
    let length = json_usize(view, "byteLength")?;
    let end = offset
        .checked_add(length)
        .filter(|end| *end <= binary.len())
        .ok_or_else(|| OptimizationError::InvalidGlb("bufferView exceeds BIN chunk".to_owned()))?;
    Ok(&binary[offset..end])
}

fn read_u32(bytes: &[u8], offset: usize) -> Result<u32, OptimizationError> {
    let value = bytes
        .get(offset..offset + 4)
        .ok_or_else(|| OptimizationError::InvalidGlb("truncated u32 value".to_owned()))?;
    Ok(u32::from_le_bytes(
        value.try_into().expect("four-byte slice"),
    ))
}

fn json_array<'a>(value: &'a Value, key: &str) -> Result<&'a Vec<Value>, OptimizationError> {
    value
        .get(key)
        .and_then(Value::as_array)
        .ok_or_else(|| OptimizationError::InvalidGlb(format!("{key} must be an array")))
}

fn json_array_mut<'a>(
    value: &'a mut Value,
    key: &str,
) -> Result<&'a mut Vec<Value>, OptimizationError> {
    value
        .get_mut(key)
        .and_then(Value::as_array_mut)
        .ok_or_else(|| OptimizationError::InvalidGlb(format!("{key} must be an array")))
}

fn json_index<'a>(
    values: &'a [Value],
    index: usize,
    name: &str,
) -> Result<&'a Value, OptimizationError> {
    values.get(index).ok_or_else(|| {
        OptimizationError::InvalidGlb(format!("{name} index {index} is out of range"))
    })
}

fn json_index_mut<'a>(
    values: &'a mut [Value],
    index: usize,
    name: &str,
) -> Result<&'a mut Value, OptimizationError> {
    values.get_mut(index).ok_or_else(|| {
        OptimizationError::InvalidGlb(format!("{name} index {index} is out of range"))
    })
}

fn json_u64(value: &Value, key: &str) -> Result<u64, OptimizationError> {
    value
        .get(key)
        .and_then(Value::as_u64)
        .ok_or_else(|| OptimizationError::InvalidGlb(format!("{key} must be an unsigned integer")))
}

fn json_usize(value: &Value, key: &str) -> Result<usize, OptimizationError> {
    usize::try_from(json_u64(value, key)?)
        .map_err(|_| OptimizationError::InvalidGlb(format!("{key} is too large")))
}

fn json_u64_default(value: &Value, key: &str, default: u64) -> Result<u64, OptimizationError> {
    match value.get(key) {
        None => Ok(default),
        Some(value) => value.as_u64().ok_or_else(|| {
            OptimizationError::InvalidGlb(format!("{key} must be an unsigned integer"))
        }),
    }
}

fn json_usize_default(
    value: &Value,
    key: &str,
    default: usize,
) -> Result<usize, OptimizationError> {
    usize::try_from(json_u64_default(value, key, default as u64)?)
        .map_err(|_| OptimizationError::InvalidGlb(format!("{key} is too large")))
}

fn invalid_glb<T>(message: &str) -> Result<T, OptimizationError> {
    Err(OptimizationError::InvalidGlb(message.to_owned()))
}

fn unsupported_glb<T>(message: &str) -> Result<T, OptimizationError> {
    Err(OptimizationError::UnsupportedGlb(message.to_owned()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn rejects_invalid_config() {
        let error = optimize_glb(
            b"not a glb",
            OptimizationConfig {
                target_ratio: 1.0,
                target_error: 0.01,
            },
        )
        .unwrap_err();

        assert!(matches!(error, OptimizationError::InvalidConfig(_)));
    }

    #[test]
    fn rejects_invalid_glb_header() {
        let error = optimize_glb(b"not a glb", OptimizationConfig::default()).unwrap_err();

        assert!(matches!(error, OptimizationError::InvalidGlb(_)));
    }

    #[test]
    fn derives_low_poly_object_key() {
        assert_eq!(
            optimized_object_key("prod_pet_tag_12345678").unwrap(),
            "prod_pet_tag_12345678_low.glb"
        );
        assert!(optimized_object_key("pet-tag").is_err());
        assert!(optimized_object_key("prod__invalid123").is_err());
    }

    #[test]
    fn optimizes_pet_tag_fixture_and_preserves_contract_names() {
        let source = std::fs::read(pet_tag_fixture()).expect("read pet tag fixture");
        let optimized =
            optimize_glb(&source, OptimizationConfig::default()).expect("optimize pet tag fixture");

        assert_eq!(optimized.report.primitives_optimized, 2);
        assert!(optimized.report.optimized_triangles < optimized.report.source_triangles);
        assert!(optimized.bytes.len() < source.len());

        let (document, _) = parse_glb(&optimized.bytes).expect("parse optimized GLB");
        let document_text = serde_json::to_string(&document).expect("serialize document");
        for required in ["Tag_Base", "Tag_Text", "Base_Mat", "Text_Mat"] {
            assert!(document_text.contains(required), "missing {required}");
        }
    }

    fn pet_tag_fixture() -> PathBuf {
        if let (Ok(srcdir), Ok(workspace)) = (
            std::env::var("TEST_SRCDIR"),
            std::env::var("TEST_WORKSPACE"),
        ) {
            return PathBuf::from(srcdir)
                .join(workspace)
                .join("resources/pet_tag.glb");
        }
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../..")
            .join("resources/pet_tag.glb")
    }
}
