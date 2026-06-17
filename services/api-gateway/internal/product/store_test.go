package product

import (
	"encoding/json"
	"testing"
	"time"
)

func TestNewInsertProductArgsEncodesValidatedDraft(t *testing.T) {
	now := time.Date(2026, 6, 15, 12, 0, 0, 0, time.UTC)
	args, err := NewInsertProductArgs("prod_12345678", validDraft(), now)
	if err != nil {
		t.Fatalf("building insert args failed: %v", err)
	}
	if args.ProcessingStatus != ProcessingNotStarted {
		t.Fatalf("processing status = %q, want %q", args.ProcessingStatus, ProcessingNotStarted)
	}
	var sections []InformationSection
	if err := json.Unmarshal(args.InformationSections, &sections); err != nil {
		t.Fatalf("information sections were not JSON: %v", err)
	}
	if len(sections) != 1 || sections[0].Title != "Materials" {
		t.Fatalf("unexpected information sections: %#v", sections)
	}
	var price ProductPrice
	if err := json.Unmarshal(args.Price, &price); err != nil {
		t.Fatalf("price was not JSON: %v", err)
	}
	if price.AmountCents != 12900 || price.Currency != "USD" {
		t.Fatalf("unexpected price: %#v", price)
	}
	var categories []ProductCategory
	if err := json.Unmarshal(args.Categories, &categories); err != nil {
		t.Fatalf("categories were not JSON: %v", err)
	}
	if len(categories) != 1 || categories[0].Slug != "chairs" {
		t.Fatalf("unexpected categories: %#v", categories)
	}
	var meshConfig MeshColorConfig
	if err := json.Unmarshal(args.MeshColorConfig, &meshConfig); err != nil {
		t.Fatalf("mesh config was not JSON: %v", err)
	}
	if meshConfig["mesh_body"].Default != "#FFFFFF" {
		t.Fatalf("unexpected mesh config: %#v", meshConfig)
	}
	var source ObjectRef
	if err := json.Unmarshal(args.SourceAsset, &source); err != nil {
		t.Fatalf("source asset was not JSON: %v", err)
	}
	if source.Bucket != "lumin-source-glb" {
		t.Fatalf("source bucket = %q", source.Bucket)
	}
}

func TestNewInsertProductArgsUsesSQLNullForNilOptionalJSON(t *testing.T) {
	draft := validDraft()
	draft.MeshColorConfig = nil
	draft.SourceAsset = nil

	args, err := NewInsertProductArgs("prod_12345678", draft, time.Now())
	if err != nil {
		t.Fatalf("building insert args failed: %v", err)
	}
	if args.MeshColorConfig != nil {
		t.Fatalf("mesh config = %q, want SQL NULL", string(args.MeshColorConfig))
	}
	if args.SourceAsset != nil {
		t.Fatalf("source asset = %q, want SQL NULL", string(args.SourceAsset))
	}
}

func TestNewInsertProductArgsRejectsInvalidID(t *testing.T) {
	_, err := NewInsertProductArgs("bad", validDraft(), time.Now())
	if err == nil {
		t.Fatal("expected invalid id to be rejected")
	}
}

func TestNewUpdateProductArgsEncodesValidatedDraft(t *testing.T) {
	now := time.Date(2026, 6, 15, 13, 0, 0, 0, time.UTC)
	args, err := NewUpdateProductArgs("prod_12345678", validDraft(), now)
	if err != nil {
		t.Fatalf("building update args failed: %v", err)
	}
	if args.ID != "prod_12345678" {
		t.Fatalf("id = %q", args.ID)
	}
	if args.UpdatedAt != now {
		t.Fatalf("updated at = %s", args.UpdatedAt)
	}
	var sections []InformationSection
	if err := json.Unmarshal(args.InformationSections, &sections); err != nil {
		t.Fatalf("information sections were not JSON: %v", err)
	}
	if len(sections) != 1 || sections[0].Title != "Materials" {
		t.Fatalf("unexpected information sections: %#v", sections)
	}
	var price ProductPrice
	if err := json.Unmarshal(args.Price, &price); err != nil {
		t.Fatalf("price was not JSON: %v", err)
	}
	if price.AmountCents != 12900 || price.Currency != "USD" {
		t.Fatalf("unexpected price: %#v", price)
	}
	var categories []ProductCategory
	if err := json.Unmarshal(args.Categories, &categories); err != nil {
		t.Fatalf("categories were not JSON: %v", err)
	}
	if len(categories) != 1 || categories[0].Name != "Chairs" {
		t.Fatalf("unexpected categories: %#v", categories)
	}
}

func TestNewUpdateProductArgsRejectsInvalidInput(t *testing.T) {
	if _, err := NewUpdateProductArgs("bad", validDraft(), time.Now()); err == nil {
		t.Fatal("expected invalid id to be rejected")
	}
	draft := validDraft()
	draft.Slug = "Bad Slug"
	if _, err := NewUpdateProductArgs("prod_12345678", draft, time.Now()); err == nil {
		t.Fatal("expected invalid draft to be rejected")
	}
}

func TestNewQueueSourceAssetArgsEncodesQueuedSourceAsset(t *testing.T) {
	now := time.Date(2026, 6, 15, 15, 0, 0, 0, time.UTC)
	source := ObjectRef{
		Bucket:      "lumin-source-glb",
		Key:         "products/prod_12345678/source.glb",
		ContentType: "model/gltf-binary",
	}

	args, err := NewQueueSourceAssetArgs("prod_12345678", source, now)
	if err != nil {
		t.Fatalf("building queue source args failed: %v", err)
	}

	if args.ProcessingStatus != ProcessingQueued {
		t.Fatalf("processing status = %q, want %q", args.ProcessingStatus, ProcessingQueued)
	}
	if args.UpdatedAt != now {
		t.Fatalf("updated at = %s", args.UpdatedAt)
	}
	var got ObjectRef
	if err := json.Unmarshal(args.SourceAsset, &got); err != nil {
		t.Fatalf("source asset was not JSON: %v", err)
	}
	if got.Key != "products/prod_12345678/source.glb" {
		t.Fatalf("source key = %q", got.Key)
	}
}

func TestNewCompleteProcessingArgsEncodesProcessedAssets(t *testing.T) {
	now := time.Date(2026, 6, 15, 16, 0, 0, 0, time.UTC)
	optimized := ObjectRef{Bucket: "lumin-optimized-glb", Key: "prod_12345678_low.glb"}
	sprite := ObjectRef{Bucket: "lumin-360-sprites", Key: "prod_12345678_360_sprite.jpg"}

	args, err := NewCompleteProcessingArgs("prod_12345678", optimized, sprite, now)
	if err != nil {
		t.Fatalf("building completion args failed: %v", err)
	}
	if args.ProcessingStatus != ProcessingCompleted || args.UpdatedAt != now {
		t.Fatalf("unexpected completion args: %#v", args)
	}
	var gotOptimized ObjectRef
	if err := json.Unmarshal(args.OptimizedAsset, &gotOptimized); err != nil {
		t.Fatalf("optimized asset was not JSON: %v", err)
	}
	if gotOptimized.Key != optimized.Key {
		t.Fatalf("optimized key = %q", gotOptimized.Key)
	}
}

func TestNewCompleteProcessingArgsRejectsWrongBuckets(t *testing.T) {
	now := time.Now()
	optimized := ObjectRef{Bucket: "lumin-source-glb", Key: "source.glb"}
	sprite := ObjectRef{Bucket: "lumin-360-sprites", Key: "sprite.jpg"}
	if _, err := NewCompleteProcessingArgs("prod_12345678", optimized, sprite, now); err == nil {
		t.Fatal("wrong optimized bucket must fail")
	}
}
