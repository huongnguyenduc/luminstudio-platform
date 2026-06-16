package cart

import (
	"encoding/json"
	"testing"
	"time"

	"lumin.studio/services/api-gateway/internal/product"
)

func TestNewInsertCartArgsEncodesItemsAndTotals(t *testing.T) {
	now := time.Date(2026, 6, 16, 11, 0, 0, 0, time.UTC)
	items := []ItemSnapshot{validCartItem(now)}

	args, err := NewInsertCartArgs("cart_12345678", items, now)
	if err != nil {
		t.Fatalf("building insert args failed: %v", err)
	}
	if args.CreatedAt != now || args.UpdatedAt != now {
		t.Fatalf("unexpected timestamps: %#v", args)
	}
	var decodedItems []ItemSnapshot
	if err := json.Unmarshal(args.Items, &decodedItems); err != nil {
		t.Fatalf("items were not JSON: %v", err)
	}
	if len(decodedItems) != 1 || decodedItems[0].ProductID != "prod_12345678" {
		t.Fatalf("unexpected items: %#v", decodedItems)
	}
	var totals Totals
	if err := json.Unmarshal(args.Totals, &totals); err != nil {
		t.Fatalf("totals were not JSON: %v", err)
	}
	if totals.SelectedAmountCents != 12900 {
		t.Fatalf("unexpected totals: %#v", totals)
	}
}

func TestNewUpdateCartArgsRejectsInvalidCart(t *testing.T) {
	if _, err := NewUpdateCartArgs("bad", []ItemSnapshot{validCartItem(time.Now())}, time.Now()); err == nil {
		t.Fatal("expected invalid cart id to fail")
	}
}

func validCartItem(now time.Time) ItemSnapshot {
	return ItemSnapshot{
		ProductID:               "prod_12345678",
		ProductName:             "Arc Chair",
		Price:                   product.ProductPrice{AmountCents: 12900, Currency: "USD"},
		Categories:              []product.ProductCategory{{Slug: "chairs", Name: "Chairs"}},
		SelectedColors:          map[string]string{"mesh_body": "#FFFFFF"},
		Quantity:                1,
		Selected:                true,
		ProductUpdatedAt:        now,
		ProductProcessingStatus: product.ProcessingCompleted,
	}
}
