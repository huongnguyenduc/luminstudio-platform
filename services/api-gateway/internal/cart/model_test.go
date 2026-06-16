package cart

import (
	"testing"
	"time"

	"lumin.studio/services/api-gateway/internal/product"
)

func TestBuildSnapshotsUsesAuthoritativeProductData(t *testing.T) {
	compareAt := int64(15900)
	now := time.Date(2026, 6, 16, 10, 0, 0, 0, time.UTC)
	record := validProduct(now)
	record.Price.CompareAtAmountCents = &compareAt

	items, err := BuildSnapshots(UpsertRequest{Items: []ItemInput{{
		ProductID:      record.ID,
		SelectedColors: map[string]string{"mesh_body": "#ffffff"},
		Quantity:       2,
		Selected:       true,
	}}}, map[string]product.ProductRecord{record.ID: record})
	if err != nil {
		t.Fatalf("build snapshots failed: %v", err)
	}
	if len(items) != 1 {
		t.Fatalf("item count = %d", len(items))
	}
	item := items[0]
	if item.ProductName != record.Name || item.Price.AmountCents != record.Price.AmountCents {
		t.Fatalf("snapshot did not use authoritative product data: %#v", item)
	}
	if item.SelectedColors["mesh_body"] != "#FFFFFF" {
		t.Fatalf("selected color was not normalized: %#v", item.SelectedColors)
	}

	totals := CalculateTotals(items)
	if totals.Currency == nil || *totals.Currency != "USD" {
		t.Fatalf("currency = %#v", totals.Currency)
	}
	if totals.SelectedAmountCents != 25800 || totals.SelectedSavingsCents != 6000 {
		t.Fatalf("unexpected totals: %#v", totals)
	}
}

func TestBuildSnapshotsRejectsUnconfiguredColor(t *testing.T) {
	record := validProduct(time.Now())
	_, err := BuildSnapshots(UpsertRequest{Items: []ItemInput{{
		ProductID:      record.ID,
		SelectedColors: map[string]string{"mesh_body": "#000000"},
		Quantity:       1,
		Selected:       true,
	}}}, map[string]product.ProductRecord{record.ID: record})
	if err == nil {
		t.Fatal("expected unconfigured color to fail")
	}
}

func TestUpsertRequestRejectsDuplicateConfigurations(t *testing.T) {
	request := UpsertRequest{Items: []ItemInput{
		{ProductID: "prod_12345678", SelectedColors: map[string]string{"mesh_body": "#FFFFFF"}, Quantity: 1},
		{ProductID: "prod_12345678", SelectedColors: map[string]string{"mesh_body": "#ffffff"}, Quantity: 2},
	}}
	if err := request.Validate(); err == nil {
		t.Fatal("expected duplicate configuration to fail")
	}
}

func TestCalculateTotalsMarksMixedCurrency(t *testing.T) {
	items := []ItemSnapshot{
		{ProductID: "prod_12345678", ProductName: "A", Price: product.ProductPrice{AmountCents: 100, Currency: "USD"}, Quantity: 1, Selected: true, ProductUpdatedAt: time.Now()},
		{ProductID: "prod_87654321", ProductName: "B", Price: product.ProductPrice{AmountCents: 200, Currency: "EUR"}, Quantity: 1, Selected: true, ProductUpdatedAt: time.Now()},
	}
	totals := CalculateTotals(items)
	if !totals.MixedCurrency || totals.Currency != nil || totals.SelectedAmountCents != 0 {
		t.Fatalf("unexpected mixed currency totals: %#v", totals)
	}
}

func validProduct(now time.Time) product.ProductRecord {
	return product.ProductRecord{
		ID:               "prod_12345678",
		Name:             "Arc Chair",
		Slug:             "arc-chair",
		Description:      "Configurable chair.",
		Price:            product.ProductPrice{AmountCents: 12900, Currency: "USD"},
		Categories:       []product.ProductCategory{{Slug: "chairs", Name: "Chairs"}},
		MeshColorConfig:  product.MeshColorConfig{"mesh_body": {Default: "#FFFFFF", Allowed: []string{"#FFFFFF"}}},
		CreatedAt:        now,
		UpdatedAt:        now,
		ProcessingStatus: product.ProcessingCompleted,
	}
}
