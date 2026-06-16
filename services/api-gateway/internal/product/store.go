package product

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

const insertProductSQL = `
INSERT INTO products (
  id,
  slug,
  name,
  description,
  price,
  information_sections,
  mesh_color_config,
  source_asset,
  processing_status,
  created_at,
  updated_at
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
RETURNING id, slug, name, description, price, information_sections, mesh_color_config,
  source_asset, created_at, updated_at, processing_status, optimized_asset,
  sprite_asset`

const updateProductSQL = `
UPDATE products
SET slug = $2,
  name = $3,
  description = $4,
  price = $5,
  information_sections = $6,
  mesh_color_config = $7,
  source_asset = $8,
  updated_at = $9
WHERE id = $1
RETURNING id, slug, name, description, price, information_sections, mesh_color_config,
  source_asset, created_at, updated_at, processing_status, optimized_asset,
  sprite_asset`

const queueSourceAssetSQL = `
UPDATE products
SET source_asset = $2,
  processing_status = $3,
  updated_at = $4
WHERE id = $1
RETURNING id, slug, name, description, price, information_sections, mesh_color_config,
  source_asset, created_at, updated_at, processing_status, optimized_asset,
  sprite_asset`

const completeProcessingSQL = `
UPDATE products
SET optimized_asset = $2,
  sprite_asset = $3,
  processing_status = $4,
  updated_at = $5
WHERE id = $1
  AND updated_at <= $5
RETURNING id, slug, name, description, price, information_sections, mesh_color_config,
  source_asset, created_at, updated_at, processing_status, optimized_asset,
  sprite_asset`

const selectProductColumns = `
SELECT id, slug, name, description, price, information_sections, mesh_color_config,
  source_asset, created_at, updated_at, processing_status, optimized_asset,
  sprite_asset
FROM products`

const getProductSQL = selectProductColumns + `
WHERE id = $1`

const listProductsSQL = selectProductColumns + `
ORDER BY updated_at DESC, id ASC`

var ErrProductNotFound = errors.New("product not found")

type queryer interface {
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

type Store struct {
	db queryer
}

func NewStore(db queryer) Store {
	return Store{db: db}
}

type insertProductArgs struct {
	ID                  string
	Slug                string
	Name                string
	Description         string
	Price               []byte
	InformationSections []byte
	MeshColorConfig     []byte
	SourceAsset         []byte
	ProcessingStatus    ProcessingStatus
	CreatedAt           time.Time
	UpdatedAt           time.Time
}

type updateProductArgs struct {
	ID                  string
	Slug                string
	Name                string
	Description         string
	Price               []byte
	InformationSections []byte
	MeshColorConfig     []byte
	SourceAsset         []byte
	UpdatedAt           time.Time
}

type queueSourceAssetArgs struct {
	ID               string
	SourceAsset      []byte
	ProcessingStatus ProcessingStatus
	UpdatedAt        time.Time
}

type completeProcessingArgs struct {
	ID               string
	OptimizedAsset   []byte
	SpriteAsset      []byte
	ProcessingStatus ProcessingStatus
	UpdatedAt        time.Time
}

func NewInsertProductArgs(id string, draft ProductDraft, now time.Time) (insertProductArgs, error) {
	if !productIDPattern.MatchString(id) {
		return insertProductArgs{}, fmt.Errorf("id must match the v1 product id contract")
	}
	if err := draft.Validate(); err != nil {
		return insertProductArgs{}, err
	}
	sections, err := encodeJSON(draft.InformationSections)
	if err != nil {
		return insertProductArgs{}, fmt.Errorf("encode information sections: %w", err)
	}
	price, err := encodeJSON(draft.Price)
	if err != nil {
		return insertProductArgs{}, fmt.Errorf("encode price: %w", err)
	}
	meshConfig, err := encodeJSON(draft.MeshColorConfig)
	if err != nil {
		return insertProductArgs{}, fmt.Errorf("encode mesh color config: %w", err)
	}
	sourceAsset, err := encodeJSON(draft.SourceAsset)
	if err != nil {
		return insertProductArgs{}, fmt.Errorf("encode source asset: %w", err)
	}
	return insertProductArgs{
		ID:                  id,
		Slug:                draft.Slug,
		Name:                draft.Name,
		Description:         draft.Description,
		Price:               price,
		InformationSections: sections,
		MeshColorConfig:     meshConfig,
		SourceAsset:         sourceAsset,
		ProcessingStatus:    ProcessingNotStarted,
		CreatedAt:           now,
		UpdatedAt:           now,
	}, nil
}

func NewQueueSourceAssetArgs(id string, sourceAsset ObjectRef, now time.Time) (queueSourceAssetArgs, error) {
	if !productIDPattern.MatchString(id) {
		return queueSourceAssetArgs{}, fmt.Errorf("id must match the v1 product id contract")
	}
	if err := sourceAsset.validate(); err != nil {
		return queueSourceAssetArgs{}, fmt.Errorf("sourceAsset: %w", err)
	}
	encodedSourceAsset, err := encodeJSON(&sourceAsset)
	if err != nil {
		return queueSourceAssetArgs{}, fmt.Errorf("encode source asset: %w", err)
	}
	return queueSourceAssetArgs{
		ID:               id,
		SourceAsset:      encodedSourceAsset,
		ProcessingStatus: ProcessingQueued,
		UpdatedAt:        now,
	}, nil
}

func NewCompleteProcessingArgs(id string, optimizedAsset, spriteAsset ObjectRef, now time.Time) (completeProcessingArgs, error) {
	if !productIDPattern.MatchString(id) {
		return completeProcessingArgs{}, fmt.Errorf("id must match the v1 product id contract")
	}
	if now.IsZero() {
		return completeProcessingArgs{}, errors.New("updatedAt is required")
	}
	if err := optimizedAsset.validate(); err != nil {
		return completeProcessingArgs{}, fmt.Errorf("optimizedAsset: %w", err)
	}
	if optimizedAsset.Bucket != "lumin-optimized-glb" {
		return completeProcessingArgs{}, errors.New("optimizedAsset must use the lumin-optimized-glb bucket")
	}
	if err := spriteAsset.validate(); err != nil {
		return completeProcessingArgs{}, fmt.Errorf("spriteAsset: %w", err)
	}
	if spriteAsset.Bucket != "lumin-360-sprites" {
		return completeProcessingArgs{}, errors.New("spriteAsset must use the lumin-360-sprites bucket")
	}
	optimizedJSON, err := encodeJSON(&optimizedAsset)
	if err != nil {
		return completeProcessingArgs{}, fmt.Errorf("encode optimized asset: %w", err)
	}
	spriteJSON, err := encodeJSON(&spriteAsset)
	if err != nil {
		return completeProcessingArgs{}, fmt.Errorf("encode sprite asset: %w", err)
	}
	return completeProcessingArgs{
		ID:               id,
		OptimizedAsset:   optimizedJSON,
		SpriteAsset:      spriteJSON,
		ProcessingStatus: ProcessingCompleted,
		UpdatedAt:        now,
	}, nil
}

func NewUpdateProductArgs(id string, draft ProductDraft, now time.Time) (updateProductArgs, error) {
	if !productIDPattern.MatchString(id) {
		return updateProductArgs{}, fmt.Errorf("id must match the v1 product id contract")
	}
	if err := draft.Validate(); err != nil {
		return updateProductArgs{}, err
	}
	sections, err := encodeJSON(draft.InformationSections)
	if err != nil {
		return updateProductArgs{}, fmt.Errorf("encode information sections: %w", err)
	}
	price, err := encodeJSON(draft.Price)
	if err != nil {
		return updateProductArgs{}, fmt.Errorf("encode price: %w", err)
	}
	meshConfig, err := encodeJSON(draft.MeshColorConfig)
	if err != nil {
		return updateProductArgs{}, fmt.Errorf("encode mesh color config: %w", err)
	}
	sourceAsset, err := encodeJSON(draft.SourceAsset)
	if err != nil {
		return updateProductArgs{}, fmt.Errorf("encode source asset: %w", err)
	}
	return updateProductArgs{
		ID:                  id,
		Slug:                draft.Slug,
		Name:                draft.Name,
		Description:         draft.Description,
		Price:               price,
		InformationSections: sections,
		MeshColorConfig:     meshConfig,
		SourceAsset:         sourceAsset,
		UpdatedAt:           now,
	}, nil
}

func (store Store) InsertProduct(ctx context.Context, id string, draft ProductDraft, now time.Time) (ProductRecord, error) {
	args, err := NewInsertProductArgs(id, draft, now)
	if err != nil {
		return ProductRecord{}, err
	}
	row := store.db.QueryRow(ctx, insertProductSQL,
		args.ID,
		args.Slug,
		args.Name,
		args.Description,
		args.Price,
		args.InformationSections,
		args.MeshColorConfig,
		args.SourceAsset,
		args.ProcessingStatus,
		args.CreatedAt,
		args.UpdatedAt,
	)
	record, err := scanProduct(row)
	if err != nil {
		return ProductRecord{}, err
	}
	return record, record.Validate()
}

func (store Store) UpdateProduct(ctx context.Context, id string, draft ProductDraft, now time.Time) (ProductRecord, error) {
	args, err := NewUpdateProductArgs(id, draft, now)
	if err != nil {
		return ProductRecord{}, err
	}
	row := store.db.QueryRow(ctx, updateProductSQL,
		args.ID,
		args.Slug,
		args.Name,
		args.Description,
		args.Price,
		args.InformationSections,
		args.MeshColorConfig,
		args.SourceAsset,
		args.UpdatedAt,
	)
	record, err := scanProduct(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ProductRecord{}, ErrProductNotFound
		}
		return ProductRecord{}, err
	}
	return record, record.Validate()
}

func (store Store) QueueSourceAsset(ctx context.Context, id string, sourceAsset ObjectRef, now time.Time) (ProductRecord, error) {
	args, err := NewQueueSourceAssetArgs(id, sourceAsset, now)
	if err != nil {
		return ProductRecord{}, err
	}
	row := store.db.QueryRow(ctx, queueSourceAssetSQL,
		args.ID,
		args.SourceAsset,
		args.ProcessingStatus,
		args.UpdatedAt,
	)
	record, err := scanProduct(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ProductRecord{}, ErrProductNotFound
		}
		return ProductRecord{}, err
	}
	return record, record.Validate()
}

func (store Store) CompleteProcessing(ctx context.Context, id string, optimizedAsset, spriteAsset ObjectRef, now time.Time) (ProductRecord, error) {
	args, err := NewCompleteProcessingArgs(id, optimizedAsset, spriteAsset, now)
	if err != nil {
		return ProductRecord{}, err
	}
	record, err := scanProduct(store.db.QueryRow(ctx, completeProcessingSQL,
		args.ID,
		args.OptimizedAsset,
		args.SpriteAsset,
		args.ProcessingStatus,
		args.UpdatedAt,
	))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ProductRecord{}, ErrProductNotFound
		}
		return ProductRecord{}, err
	}
	return record, record.Validate()
}

func (store Store) GetProduct(ctx context.Context, id string) (ProductRecord, error) {
	if !productIDPattern.MatchString(id) {
		return ProductRecord{}, fmt.Errorf("id must match the v1 product id contract")
	}
	record, err := scanProduct(store.db.QueryRow(ctx, getProductSQL, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ProductRecord{}, ErrProductNotFound
		}
		return ProductRecord{}, err
	}
	return record, record.Validate()
}

func (store Store) ListProducts(ctx context.Context) ([]ProductRecord, error) {
	rows, err := store.db.Query(ctx, listProductsSQL)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var records []ProductRecord
	for rows.Next() {
		record, err := scanProduct(rows)
		if err != nil {
			return nil, err
		}
		if err := record.Validate(); err != nil {
			return nil, err
		}
		records = append(records, record)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if records == nil {
		return []ProductRecord{}, nil
	}
	return records, nil
}

type productRow interface {
	Scan(dest ...any) error
}

func scanProduct(row productRow) (ProductRecord, error) {
	var record ProductRecord
	var price []byte
	var sections []byte
	var meshConfig []byte
	var sourceAsset []byte
	var optimizedAsset []byte
	var spriteAsset []byte
	if err := row.Scan(
		&record.ID,
		&record.Slug,
		&record.Name,
		&record.Description,
		&price,
		&sections,
		&meshConfig,
		&sourceAsset,
		&record.CreatedAt,
		&record.UpdatedAt,
		&record.ProcessingStatus,
		&optimizedAsset,
		&spriteAsset,
	); err != nil {
		return ProductRecord{}, err
	}
	var err error
	if record.Price, err = decodeJSON[ProductPrice](price); err != nil {
		return ProductRecord{}, fmt.Errorf("decode price: %w", err)
	}
	if record.InformationSections, err = decodeJSON[[]InformationSection](sections); err != nil {
		return ProductRecord{}, fmt.Errorf("decode information sections: %w", err)
	}
	if record.MeshColorConfig, err = decodeJSON[MeshColorConfig](meshConfig); err != nil {
		return ProductRecord{}, fmt.Errorf("decode mesh color config: %w", err)
	}
	if record.SourceAsset, err = decodeJSON[*ObjectRef](sourceAsset); err != nil {
		return ProductRecord{}, fmt.Errorf("decode source asset: %w", err)
	}
	if record.OptimizedAsset, err = decodeJSON[*ObjectRef](optimizedAsset); err != nil {
		return ProductRecord{}, fmt.Errorf("decode optimized asset: %w", err)
	}
	if record.SpriteAsset, err = decodeJSON[*ObjectRef](spriteAsset); err != nil {
		return ProductRecord{}, fmt.Errorf("decode sprite asset: %w", err)
	}
	return record, nil
}
