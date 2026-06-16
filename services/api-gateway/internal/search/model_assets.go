package search

import (
	"context"
	"errors"
	"fmt"
	"io"

	"github.com/minio/minio-go/v7"

	"lumin.studio/services/api-gateway/internal/product"
)

type MinIOModelAssetStore struct {
	client *minio.Client
}

func NewMinIOModelAssetStore(client *minio.Client) MinIOModelAssetStore {
	return MinIOModelAssetStore{client: client}
}

func (store MinIOModelAssetStore) GetModelAsset(ctx context.Context, ref product.ObjectRef) (io.ReadCloser, error) {
	if store.client == nil {
		return nil, errors.New("MinIO client is not configured")
	}
	if ref.Bucket != "lumin-source-glb" && ref.Bucket != "lumin-optimized-glb" {
		return nil, errors.New("model asset must use a v1 GLB bucket")
	}
	if ref.Key == "" {
		return nil, errors.New("model asset key is required")
	}
	object, err := store.client.GetObject(ctx, ref.Bucket, ref.Key, minio.GetObjectOptions{})
	if err != nil {
		return nil, fmt.Errorf("get model asset object: %w", err)
	}
	return object, nil
}
