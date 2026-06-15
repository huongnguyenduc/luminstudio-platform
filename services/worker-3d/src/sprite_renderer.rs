const MIN_PRODUCT_ID_SUFFIX_LENGTH: usize = 8;

pub const SPRITE_FRAME_COUNT: usize = 24;
pub const SPRITE_COLUMNS: usize = 6;
pub const SPRITE_FRAME_SIZE: usize = 160;

pub fn sprite_object_key(product_id: &str) -> Result<String, &'static str> {
    let Some(suffix) = product_id.strip_prefix("prod_") else {
        return Err("product id must start with prod_");
    };
    if suffix.len() < MIN_PRODUCT_ID_SUFFIX_LENGTH
        || suffix.len() > 64
        || !suffix
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'_' | b'-'))
        || !suffix
            .as_bytes()
            .first()
            .is_some_and(u8::is_ascii_alphanumeric)
    {
        return Err("product id must match the v1 contract");
    }

    Ok(format!("{product_id}_360_sprite.jpg"))
}

#[cfg(test)]
mod tests {
    use super::{SPRITE_COLUMNS, SPRITE_FRAME_COUNT, SPRITE_FRAME_SIZE, sprite_object_key};

    #[test]
    fn uses_the_v1_sprite_contract() {
        assert_eq!(SPRITE_FRAME_COUNT, 24);
        assert_eq!(SPRITE_COLUMNS, 6);
        assert_eq!(SPRITE_FRAME_SIZE, 160);
        assert_eq!(
            sprite_object_key("prod_pet_tag_12345678").unwrap(),
            "prod_pet_tag_12345678_360_sprite.jpg"
        );
    }

    #[test]
    fn rejects_invalid_product_ids() {
        assert!(sprite_object_key("pet-tag").is_err());
        assert!(sprite_object_key("prod_short").is_err());
        assert!(sprite_object_key("prod__invalid123").is_err());
    }
}
