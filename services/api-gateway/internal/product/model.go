package product

import (
	"encoding/json"
	"errors"
	"fmt"
	"reflect"
	"regexp"
	"strings"
	"time"
)

type ProcessingStatus string

const (
	ProcessingNotStarted ProcessingStatus = "not_started"
	ProcessingQueued     ProcessingStatus = "queued"
	ProcessingInProgress ProcessingStatus = "processing"
	ProcessingCompleted  ProcessingStatus = "completed"
	ProcessingFailed     ProcessingStatus = "failed"
)

type ObjectRef struct {
	Bucket      string `json:"bucket"`
	Key         string `json:"key"`
	ContentType string `json:"contentType,omitempty"`
	ETag        string `json:"etag,omitempty"`
	SizeBytes   *int64 `json:"sizeBytes,omitempty"`
}

type InformationSection struct {
	Title              string `json:"title"`
	Body               string `json:"body"`
	CollapsedByDefault bool   `json:"collapsedByDefault"`
}

type ProductPrice struct {
	AmountCents          int64  `json:"amountCents"`
	Currency             string `json:"currency"`
	CompareAtAmountCents *int64 `json:"compareAtAmountCents,omitempty"`
}

type ProductCategory struct {
	Slug string `json:"slug"`
	Name string `json:"name"`
}

type MeshColorOption struct {
	Default string            `json:"default"`
	Allowed []string          `json:"allowed"`
	Labels  map[string]string `json:"labels,omitempty"`
}

type MeshColorConfig map[string]MeshColorOption

type ProductDraft struct {
	Name                string               `json:"name"`
	Slug                string               `json:"slug"`
	Description         string               `json:"description"`
	Price               ProductPrice         `json:"price"`
	Categories          []ProductCategory    `json:"categories,omitempty"`
	InformationSections []InformationSection `json:"informationSections"`
	MeshColorConfig     MeshColorConfig      `json:"meshColorConfig,omitempty"`
	SourceAsset         *ObjectRef           `json:"sourceAsset,omitempty"`
}

type ProductRecord struct {
	ID                  string               `json:"id"`
	Name                string               `json:"name"`
	Slug                string               `json:"slug"`
	Description         string               `json:"description"`
	Price               ProductPrice         `json:"price"`
	Categories          []ProductCategory    `json:"categories,omitempty"`
	InformationSections []InformationSection `json:"informationSections"`
	MeshColorConfig     MeshColorConfig      `json:"meshColorConfig,omitempty"`
	SourceAsset         *ObjectRef           `json:"sourceAsset,omitempty"`
	CreatedAt           time.Time            `json:"createdAt"`
	UpdatedAt           time.Time            `json:"updatedAt"`
	ProcessingStatus    ProcessingStatus     `json:"processingStatus"`
	OptimizedAsset      *ObjectRef           `json:"optimizedAsset,omitempty"`
	SpriteAsset         *ObjectRef           `json:"spriteAsset,omitempty"`
}

var (
	slugPattern      = regexp.MustCompile(`^[a-z0-9]+(?:-[a-z0-9]+)*$`)
	productIDPattern = regexp.MustCompile(`^prod_[A-Za-z0-9][A-Za-z0-9_-]{7,63}$`)
	taskIDPattern    = regexp.MustCompile(`^task_[A-Za-z0-9][A-Za-z0-9_-]{7,63}$`)
	meshIDPattern    = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$`)
	hexColorPattern  = regexp.MustCompile(`^#[0-9A-Fa-f]{6}$`)
	objectKeyPattern = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._/-]*$`)
	currencyPattern  = regexp.MustCompile(`^[A-Z]{3}$`)
	validBuckets     = map[string]struct{}{
		"lumin-source-glb":    {},
		"lumin-optimized-glb": {},
		"lumin-360-sprites":   {},
	}
)

func ValidProductID(id string) bool {
	return productIDPattern.MatchString(id)
}

func ValidSlug(slug string) bool {
	return slugPattern.MatchString(slug)
}

func (draft ProductDraft) Validate() error {
	if err := validateText("name", draft.Name, 1, 160); err != nil {
		return err
	}
	if err := validateText("description", draft.Description, 1, 10000); err != nil {
		return err
	}
	if draft.Slug == "" || len(draft.Slug) > 180 || !slugPattern.MatchString(draft.Slug) {
		return errors.New("slug must match the v1 product slug contract")
	}
	if err := draft.Price.validate(); err != nil {
		return fmt.Errorf("price: %w", err)
	}
	if err := validateCategories(draft.Categories); err != nil {
		return err
	}
	for index, section := range draft.InformationSections {
		if err := section.validate(); err != nil {
			return fmt.Errorf("informationSections[%d]: %w", index, err)
		}
	}
	if draft.MeshColorConfig != nil {
		if err := draft.MeshColorConfig.validate(); err != nil {
			return err
		}
	}
	if draft.SourceAsset != nil {
		if err := draft.SourceAsset.validate(); err != nil {
			return fmt.Errorf("sourceAsset: %w", err)
		}
	}
	return nil
}

func (record ProductRecord) Validate() error {
	if record.ID == "" || !productIDPattern.MatchString(record.ID) {
		return errors.New("id must match the v1 product id contract")
	}
	if err := (ProductDraft{
		Name:                record.Name,
		Slug:                record.Slug,
		Description:         record.Description,
		Price:               record.Price,
		Categories:          record.Categories,
		InformationSections: record.InformationSections,
		MeshColorConfig:     record.MeshColorConfig,
		SourceAsset:         record.SourceAsset,
	}).Validate(); err != nil {
		return err
	}
	if !record.ProcessingStatus.valid() {
		return errors.New("processingStatus must be a known product processing status")
	}
	for name, asset := range map[string]*ObjectRef{
		"optimizedAsset": record.OptimizedAsset,
		"spriteAsset":    record.SpriteAsset,
	} {
		if asset != nil {
			if err := asset.validate(); err != nil {
				return fmt.Errorf("%s: %w", name, err)
			}
		}
	}
	if record.CreatedAt.IsZero() || record.UpdatedAt.IsZero() {
		return errors.New("createdAt and updatedAt are required")
	}
	if record.UpdatedAt.Before(record.CreatedAt) {
		return errors.New("updatedAt must not be before createdAt")
	}
	return nil
}

func validateCategories(categories []ProductCategory) error {
	if len(categories) > 8 {
		return errors.New("categories must contain at most 8 entries")
	}
	seen := map[string]struct{}{}
	for index, category := range categories {
		if category.Slug == "" || len(category.Slug) > 120 || !slugPattern.MatchString(category.Slug) {
			return fmt.Errorf("categories[%d]: slug must match the v1 category slug contract", index)
		}
		if err := validateText("name", category.Name, 1, 80); err != nil {
			return fmt.Errorf("categories[%d]: %w", index, err)
		}
		if _, ok := seen[category.Slug]; ok {
			return fmt.Errorf("categories[%d]: slug must be unique", index)
		}
		seen[category.Slug] = struct{}{}
	}
	return nil
}

func (status ProcessingStatus) valid() bool {
	switch status {
	case ProcessingNotStarted, ProcessingQueued, ProcessingInProgress, ProcessingCompleted, ProcessingFailed:
		return true
	default:
		return false
	}
}

func (section InformationSection) validate() error {
	if err := validateText("title", section.Title, 1, 120); err != nil {
		return err
	}
	return validateText("body", section.Body, 1, 5000)
}

func (price ProductPrice) validate() error {
	if price.AmountCents <= 0 {
		return errors.New("amountCents must be greater than zero")
	}
	if !currencyPattern.MatchString(price.Currency) {
		return errors.New("currency must be an ISO 4217 uppercase code")
	}
	if price.CompareAtAmountCents != nil && *price.CompareAtAmountCents <= price.AmountCents {
		return errors.New("compareAtAmountCents must be greater than amountCents")
	}
	return nil
}

func (config MeshColorConfig) validate() error {
	if len(config) == 0 {
		return errors.New("meshColorConfig must contain at least one mesh")
	}
	for meshID, option := range config {
		if meshID == "" || !meshIDPattern.MatchString(meshID) {
			return fmt.Errorf("meshColorConfig[%q]: mesh id must match the v1 contract", meshID)
		}
		if !hexColorPattern.MatchString(option.Default) {
			return fmt.Errorf("meshColorConfig[%q]: default must be a hex color", meshID)
		}
		if len(option.Allowed) == 0 {
			return fmt.Errorf("meshColorConfig[%q]: allowed must contain at least one color", meshID)
		}
		seen := map[string]struct{}{}
		for _, color := range option.Allowed {
			if !hexColorPattern.MatchString(color) {
				return fmt.Errorf("meshColorConfig[%q]: allowed contains an invalid hex color", meshID)
			}
			normalized := strings.ToUpper(color)
			if _, ok := seen[normalized]; ok {
				return fmt.Errorf("meshColorConfig[%q]: allowed colors must be unique", meshID)
			}
			seen[normalized] = struct{}{}
		}
		if _, ok := seen[strings.ToUpper(option.Default)]; !ok {
			return fmt.Errorf("meshColorConfig[%q]: default color must be in allowed", meshID)
		}
		for color, label := range option.Labels {
			normalized := strings.ToUpper(color)
			if !hexColorPattern.MatchString(color) {
				return fmt.Errorf("meshColorConfig[%q]: labels contains an invalid hex color", meshID)
			}
			if _, ok := seen[normalized]; !ok {
				return fmt.Errorf("meshColorConfig[%q]: label color must be in allowed", meshID)
			}
			if err := validateText("label", strings.TrimSpace(label), 1, 80); err != nil {
				return fmt.Errorf("meshColorConfig[%q]: labels[%q]: %w", meshID, color, err)
			}
		}
	}
	return nil
}

func (ref ObjectRef) validate() error {
	if _, ok := validBuckets[ref.Bucket]; !ok {
		return errors.New("bucket must be one of the v1 asset buckets")
	}
	if ref.Key == "" || len(ref.Key) > 1024 || !objectKeyPattern.MatchString(ref.Key) {
		return errors.New("key must match the v1 object key contract")
	}
	if ref.ContentType != "" && len(ref.ContentType) > 128 {
		return errors.New("contentType must be at most 128 characters")
	}
	if ref.ETag != "" && len(ref.ETag) > 256 {
		return errors.New("etag must be at most 256 characters")
	}
	if ref.SizeBytes != nil && *ref.SizeBytes < 0 {
		return errors.New("sizeBytes must be non-negative")
	}
	return nil
}

func validateText(name, value string, minLength, maxLength int) error {
	length := len(value)
	if length < minLength || length > maxLength {
		return fmt.Errorf("%s length must be from %d to %d", name, minLength, maxLength)
	}
	return nil
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
