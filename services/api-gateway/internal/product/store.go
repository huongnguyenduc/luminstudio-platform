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
  information_sections,
  mesh_color_config,
  source_asset,
  processing_status,
  created_at,
  updated_at
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
RETURNING id, slug, name, description, information_sections, mesh_color_config,
  source_asset, created_at, updated_at, processing_status, optimized_asset,
  sprite_asset`

const selectProductColumns = `
SELECT id, slug, name, description, information_sections, mesh_color_config,
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
	InformationSections []byte
	MeshColorConfig     []byte
	SourceAsset         []byte
	ProcessingStatus    ProcessingStatus
	CreatedAt           time.Time
	UpdatedAt           time.Time
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
		InformationSections: sections,
		MeshColorConfig:     meshConfig,
		SourceAsset:         sourceAsset,
		ProcessingStatus:    ProcessingNotStarted,
		CreatedAt:           now,
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
