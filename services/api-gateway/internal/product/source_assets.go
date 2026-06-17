package product

import (
	"context"
	"errors"
	"fmt"
	"io"

	"github.com/minio/minio-go/v7"
)

const (
	sourceGLBBucket      = "lumin-source-glb"
	sourceGLBContentType = "model/gltf-binary"
)

type MinIOSourceAssetStore struct {
	client *minio.Client
}

func NewMinIOSourceAssetStore(client *minio.Client) MinIOSourceAssetStore {
	return MinIOSourceAssetStore{client: client}
}

func (store MinIOSourceAssetStore) PutSourceAsset(ctx context.Context, productID string, source io.Reader, sizeBytes int64) (ObjectRef, error) {
	if store.client == nil {
		return ObjectRef{}, errors.New("MinIO client is not configured")
	}
	if !productIDPattern.MatchString(productID) {
		return ObjectRef{}, errors.New("product id must match the v1 product id contract")
	}
	if source == nil {
		return ObjectRef{}, errors.New("source reader is required")
	}
	if sizeBytes <= 0 {
		return ObjectRef{}, errors.New("source size must be positive")
	}

	key := fmt.Sprintf("products/%s/source.glb", productID)
	info, err := store.client.PutObject(ctx, sourceGLBBucket, key, source, sizeBytes, minio.PutObjectOptions{
		ContentType: sourceGLBContentType,
	})
	if err != nil {
		return ObjectRef{}, fmt.Errorf("put source GLB object: %w", err)
	}
	return ObjectRef{
		Bucket:      sourceGLBBucket,
		Key:         key,
		ContentType: sourceGLBContentType,
		ETag:        info.ETag,
		SizeBytes:   &sizeBytes,
	}, nil
}
