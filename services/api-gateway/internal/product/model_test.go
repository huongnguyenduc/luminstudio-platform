package product

import (
	"strings"
	"testing"
	"time"
)

func validDraft() ProductDraft {
	size := int64(42)
	compareAt := int64(15900)
	return ProductDraft{
		Name:        "Arc Chair",
		Slug:        "arc-chair",
		Description: "Configurable chair with one source model.",
		Price: ProductPrice{
			AmountCents:          12900,
			Currency:             "USD",
			CompareAtAmountCents: &compareAt,
		},
		InformationSections: []InformationSection{
			{Title: "Materials", Body: "Powder coated steel.", CollapsedByDefault: true},
		},
		MeshColorConfig: MeshColorConfig{
			"mesh_body": {
				Default: "#FFFFFF",
				Allowed: []string{
					"#FFFFFF",
					"#000000",
				},
			},
		},
		SourceAsset: &ObjectRef{
			Bucket:      "lumin-source-glb",
			Key:         "products/prod_12345678/source.glb",
			ContentType: "model/gltf-binary",
			SizeBytes:   &size,
		},
	}
}

func TestProductDraftValidateAcceptsContractShape(t *testing.T) {
	if err := validDraft().Validate(); err != nil {
		t.Fatalf("valid draft was rejected: %v", err)
	}
}

func TestProductDraftValidateRejectsContractViolations(t *testing.T) {
	tests := []struct {
		name   string
		mutate func(*ProductDraft)
		want   string
	}{
		{
			name: "bad slug",
			mutate: func(draft *ProductDraft) {
				draft.Slug = "Arc Chair"
			},
			want: "slug",
		},
		{
			name: "zero price",
			mutate: func(draft *ProductDraft) {
				draft.Price.AmountCents = 0
			},
			want: "amountCents",
		},
		{
			name: "bad currency",
			mutate: func(draft *ProductDraft) {
				draft.Price.Currency = "usd"
			},
			want: "currency",
		},
		{
			name: "compare at not above amount",
			mutate: func(draft *ProductDraft) {
				compareAt := draft.Price.AmountCents
				draft.Price.CompareAtAmountCents = &compareAt
			},
			want: "compareAtAmountCents",
		},
		{
			name: "empty section title",
			mutate: func(draft *ProductDraft) {
				draft.InformationSections[0].Title = ""
			},
			want: "informationSections[0]",
		},
		{
			name: "bad mesh id",
			mutate: func(draft *ProductDraft) {
				draft.MeshColorConfig = MeshColorConfig{" mesh": draft.MeshColorConfig["mesh_body"]}
			},
			want: "mesh id",
		},
		{
			name: "bad hex color",
			mutate: func(draft *ProductDraft) {
				option := draft.MeshColorConfig["mesh_body"]
				option.Allowed = []string{"blue"}
				draft.MeshColorConfig["mesh_body"] = option
			},
			want: "invalid hex",
		},
		{
			name: "duplicate allowed color",
			mutate: func(draft *ProductDraft) {
				option := draft.MeshColorConfig["mesh_body"]
				option.Allowed = []string{"#ffffff", "#FFFFFF"}
				draft.MeshColorConfig["mesh_body"] = option
			},
			want: "unique",
		},
		{
			name: "default not allowed",
			mutate: func(draft *ProductDraft) {
				option := draft.MeshColorConfig["mesh_body"]
				option.Allowed = []string{"#000000"}
				draft.MeshColorConfig["mesh_body"] = option
			},
			want: "default color",
		},
		{
			name: "bad bucket",
			mutate: func(draft *ProductDraft) {
				draft.SourceAsset.Bucket = "unknown"
			},
			want: "bucket",
		},
		{
			name: "bad key",
			mutate: func(draft *ProductDraft) {
				draft.SourceAsset.Key = "../source.glb"
			},
			want: "key",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			draft := validDraft()
			tt.mutate(&draft)
			err := draft.Validate()
			if err == nil {
				t.Fatal("expected validation error")
			}
			if !strings.Contains(err.Error(), tt.want) {
				t.Fatalf("expected %q in error %q", tt.want, err)
			}
		})
	}
}

func TestProductRecordValidateRejectsInvalidStatusAndTime(t *testing.T) {
	now := time.Date(2026, 6, 15, 12, 0, 0, 0, time.UTC)
	record := ProductRecord{
		ID:                  "prod_12345678",
		Name:                "Arc Chair",
		Slug:                "arc-chair",
		Description:         "Configurable chair.",
		Price:               validDraft().Price,
		InformationSections: validDraft().InformationSections,
		CreatedAt:           now,
		UpdatedAt:           now.Add(-time.Second),
		ProcessingStatus:    "unknown",
	}
	if err := record.Validate(); err == nil {
		t.Fatal("expected invalid record to be rejected")
	}
}
