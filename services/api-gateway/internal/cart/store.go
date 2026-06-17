package cart

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"reflect"
	"time"

	"github.com/jackc/pgx/v5"
)

const insertCartSQL = `
INSERT INTO carts (
  id,
  items,
  totals,
  created_at,
  updated_at
) VALUES ($1, $2, $3, $4, $5)
RETURNING id, items, totals, created_at, updated_at`

const updateCartSQL = `
UPDATE carts
SET items = $2,
  totals = $3,
  updated_at = $4
WHERE id = $1
RETURNING id, items, totals, created_at, updated_at`

const getCartSQL = `
SELECT id, items, totals, created_at, updated_at
FROM carts
WHERE id = $1`

var ErrCartNotFound = errors.New("cart not found")

type queryer interface {
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

type Store struct {
	db queryer
}

func NewStore(db queryer) Store {
	return Store{db: db}
}

type upsertCartArgs struct {
	ID        string
	Items     []byte
	Totals    []byte
	CreatedAt time.Time
	UpdatedAt time.Time
}

func NewInsertCartArgs(id string, items []ItemSnapshot, now time.Time) (upsertCartArgs, error) {
	args, err := newUpsertCartArgs(id, items, now)
	if err != nil {
		return upsertCartArgs{}, err
	}
	args.CreatedAt = now
	return args, nil
}

func NewUpdateCartArgs(id string, items []ItemSnapshot, now time.Time) (upsertCartArgs, error) {
	return newUpsertCartArgs(id, items, now)
}

func newUpsertCartArgs(id string, items []ItemSnapshot, now time.Time) (upsertCartArgs, error) {
	if !ValidCartID(id) {
		return upsertCartArgs{}, fmt.Errorf("id must match the v1 cart id contract")
	}
	if now.IsZero() {
		return upsertCartArgs{}, errors.New("updatedAt is required")
	}
	totals := CalculateTotals(items)
	record := Record{ID: id, Items: items, Totals: totals, CreatedAt: now, UpdatedAt: now}
	if err := record.Validate(); err != nil {
		return upsertCartArgs{}, err
	}
	encodedItems, err := encodeJSON(items)
	if err != nil {
		return upsertCartArgs{}, fmt.Errorf("encode cart items: %w", err)
	}
	encodedTotals, err := encodeJSON(totals)
	if err != nil {
		return upsertCartArgs{}, fmt.Errorf("encode cart totals: %w", err)
	}
	return upsertCartArgs{
		ID:        id,
		Items:     encodedItems,
		Totals:    encodedTotals,
		UpdatedAt: now,
	}, nil
}

func (store Store) InsertCart(ctx context.Context, id string, items []ItemSnapshot, now time.Time) (Record, error) {
	args, err := NewInsertCartArgs(id, items, now)
	if err != nil {
		return Record{}, err
	}
	record, err := scanCart(store.db.QueryRow(ctx, insertCartSQL, args.ID, args.Items, args.Totals, args.CreatedAt, args.UpdatedAt))
	if err != nil {
		return Record{}, err
	}
	return record, record.Validate()
}

func (store Store) UpdateCart(ctx context.Context, id string, items []ItemSnapshot, now time.Time) (Record, error) {
	args, err := NewUpdateCartArgs(id, items, now)
	if err != nil {
		return Record{}, err
	}
	record, err := scanCart(store.db.QueryRow(ctx, updateCartSQL, args.ID, args.Items, args.Totals, args.UpdatedAt))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Record{}, ErrCartNotFound
		}
		return Record{}, err
	}
	return record, record.Validate()
}

func (store Store) GetCart(ctx context.Context, id string) (Record, error) {
	if !ValidCartID(id) {
		return Record{}, fmt.Errorf("id must match the v1 cart id contract")
	}
	record, err := scanCart(store.db.QueryRow(ctx, getCartSQL, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Record{}, ErrCartNotFound
		}
		return Record{}, err
	}
	return record, record.Validate()
}

type cartRow interface {
	Scan(dest ...any) error
}

func scanCart(row cartRow) (Record, error) {
	var record Record
	var items []byte
	var totals []byte
	if err := row.Scan(&record.ID, &items, &totals, &record.CreatedAt, &record.UpdatedAt); err != nil {
		return Record{}, err
	}
	var err error
	if record.Items, err = decodeJSON[[]ItemSnapshot](items); err != nil {
		return Record{}, fmt.Errorf("decode cart items: %w", err)
	}
	if record.Totals, err = decodeJSON[Totals](totals); err != nil {
		return Record{}, fmt.Errorf("decode cart totals: %w", err)
	}
	return record, nil
}

func encodeJSON(value any) ([]byte, error) {
	if value == nil {
		return nil, nil
	}
	reflected := reflect.ValueOf(value)
	switch reflected.Kind() {
	case reflect.Chan, reflect.Func, reflect.Interface, reflect.Map, reflect.Pointer, reflect.Slice:
		if reflected.IsNil() {
			return nil, nil
		}
	}
	return json.Marshal(value)
}

func decodeJSON[T any](data []byte) (T, error) {
	var value T
	if len(data) == 0 {
		return value, nil
	}
	if err := json.Unmarshal(data, &value); err != nil {
		return value, err
	}
	return value, nil
}
