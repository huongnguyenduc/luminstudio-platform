package product

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"

	"github.com/minio/minio-go/v7"
)

const (
	productImageBucket           = "lumin-product-images"
	defaultProductImageMediaType = "image/webp"
)

// ErrProductImageNotFound is returned when a product has no uploaded image.
var ErrProductImageNotFound = errors.New("product image not found")

// ProductImageInfo carries the delivery metadata for a stored product image.
type ProductImageInfo struct {
	ContentType string
	Size        int64
	ETag        string
}

// MinIOProductImageStore stores and serves the supplementary product image that
// is embedded inside the markdown description (separate from the 360 sprite).
type MinIOProductImageStore struct {
	client *minio.Client
}

func NewMinIOProductImageStore(client *minio.Client) MinIOProductImageStore {
	return MinIOProductImageStore{client: client}
}

func productImageKey(productID string) string {
	return productID + ".webp"
}

func (store MinIOProductImageStore) PutProductImage(ctx context.Context, productID string, source io.Reader, sizeBytes int64, contentType string) (ObjectRef, error) {
	if store.client == nil {
		return ObjectRef{}, errors.New("MinIO client is not configured")
	}
	if !productIDPattern.MatchString(productID) {
		return ObjectRef{}, errors.New("product id must match the v1 product id contract")
	}
	if source == nil {
		return ObjectRef{}, errors.New("image reader is required")
	}
	if sizeBytes <= 0 {
		return ObjectRef{}, errors.New("image size must be positive")
	}
	if contentType == "" {
		contentType = defaultProductImageMediaType
	}

	key := productImageKey(productID)
	info, err := store.client.PutObject(ctx, productImageBucket, key, source, sizeBytes, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return ObjectRef{}, fmt.Errorf("put product image object: %w", err)
	}
	return ObjectRef{
		Bucket:      productImageBucket,
		Key:         key,
		ContentType: contentType,
		ETag:        info.ETag,
		SizeBytes:   &sizeBytes,
	}, nil
}

func (store MinIOProductImageStore) GetProductImage(ctx context.Context, productID string) (io.ReadCloser, ProductImageInfo, error) {
	if store.client == nil {
		return nil, ProductImageInfo{}, errors.New("MinIO client is not configured")
	}
	if !productIDPattern.MatchString(productID) {
		return nil, ProductImageInfo{}, errors.New("product id must match the v1 product id contract")
	}

	key := productImageKey(productID)
	object, err := store.client.GetObject(ctx, productImageBucket, key, minio.GetObjectOptions{})
	if err != nil {
		return nil, ProductImageInfo{}, fmt.Errorf("get product image object: %w", err)
	}
	stat, err := object.Stat()
	if err != nil {
		object.Close()
		if minio.ToErrorResponse(err).StatusCode == http.StatusNotFound {
			return nil, ProductImageInfo{}, ErrProductImageNotFound
		}
		return nil, ProductImageInfo{}, fmt.Errorf("stat product image object: %w", err)
	}
	contentType := stat.ContentType
	if contentType == "" {
		contentType = defaultProductImageMediaType
	}
	return object, ProductImageInfo{ContentType: contentType, Size: stat.Size, ETag: stat.ETag}, nil
}
