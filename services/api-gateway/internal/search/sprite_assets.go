package search

import (
	"context"
	"errors"
	"fmt"
	"io"

	"github.com/minio/minio-go/v7"

	"lumin.studio/services/api-gateway/internal/product"
)

const spriteAssetBucket = "lumin-360-sprites"

type MinIOSpriteAssetStore struct {
	client *minio.Client
}

func NewMinIOSpriteAssetStore(client *minio.Client) MinIOSpriteAssetStore {
	return MinIOSpriteAssetStore{client: client}
}

func (store MinIOSpriteAssetStore) GetSpriteAsset(ctx context.Context, ref product.ObjectRef) (io.ReadCloser, error) {
	if store.client == nil {
		return nil, errors.New("MinIO client is not configured")
	}
	if ref.Bucket != spriteAssetBucket {
		return nil, errors.New("sprite asset must use the lumin-360-sprites bucket")
	}
	if ref.Key == "" {
		return nil, errors.New("sprite asset key is required")
	}
	object, err := store.client.GetObject(ctx, ref.Bucket, ref.Key, minio.GetObjectOptions{})
	if err != nil {
		return nil, fmt.Errorf("get sprite asset object: %w", err)
	}
	return object, nil
}
