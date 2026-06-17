package cart

import (
	"errors"
	"fmt"
	"regexp"
	"sort"
	"strings"
	"time"

	"lumin.studio/services/api-gateway/internal/product"
)

const maxCartItems = 100

var cartIDPattern = regexp.MustCompile(`^cart_[A-Za-z0-9][A-Za-z0-9_-]{7,63}$`)

type ItemInput struct {
	ProductID      string            `json:"productId"`
	SelectedColors map[string]string `json:"selectedColors,omitempty"`
	Quantity       int               `json:"quantity"`
	Selected       bool              `json:"selected"`
}

type UpsertRequest struct {
	Items []ItemInput `json:"items"`
}

type ItemSnapshot struct {
	ProductID               string                    `json:"productId"`
	ProductName             string                    `json:"productName"`
	Price                   product.ProductPrice      `json:"price"`
	Categories              []product.ProductCategory `json:"categories,omitempty"`
	SelectedColors          map[string]string         `json:"selectedColors,omitempty"`
	Quantity                int                       `json:"quantity"`
	Selected                bool                      `json:"selected"`
	ProductUpdatedAt        time.Time                 `json:"productUpdatedAt"`
	ProductProcessingStatus product.ProcessingStatus  `json:"productProcessingStatus"`
}

type Totals struct {
	SelectedItemCount      int     `json:"selectedItemCount"`
	SelectedQuantity       int     `json:"selectedQuantity"`
	Currency               *string `json:"currency,omitempty"`
	SelectedAmountCents    int64   `json:"selectedAmountCents"`
	SelectedCompareAtCents *int64  `json:"selectedCompareAtAmountCents,omitempty"`
	SelectedSavingsCents   int64   `json:"selectedSavingsCents"`
	MixedCurrency          bool    `json:"mixedCurrency"`
}

type Record struct {
	ID        string         `json:"id"`
	Items     []ItemSnapshot `json:"items"`
	Totals    Totals         `json:"totals"`
	CreatedAt time.Time      `json:"createdAt"`
	UpdatedAt time.Time      `json:"updatedAt"`
}

func ValidCartID(id string) bool {
	return cartIDPattern.MatchString(id)
}

func (request UpsertRequest) Validate() error {
	if len(request.Items) > maxCartItems {
		return fmt.Errorf("items must contain at most %d entries", maxCartItems)
	}
	seen := map[string]struct{}{}
	for index, item := range request.Items {
		if err := item.Validate(); err != nil {
			return fmt.Errorf("items[%d]: %w", index, err)
		}
		key := item.identityKey()
		if _, ok := seen[key]; ok {
			return fmt.Errorf("items[%d]: duplicate product and color configuration", index)
		}
		seen[key] = struct{}{}
	}
	return nil
}

func (item ItemInput) Validate() error {
	if !product.ValidProductID(item.ProductID) {
		return errors.New("productId must match the v1 product id contract")
	}
	if item.Quantity < 1 || item.Quantity > 99 {
		return errors.New("quantity must be from 1 to 99")
	}
	for meshID, color := range item.SelectedColors {
		if strings.TrimSpace(meshID) == "" {
			return errors.New("selectedColors mesh ids must not be empty")
		}
		if !regexp.MustCompile(`^#[0-9A-Fa-f]{6}$`).MatchString(color) {
			return errors.New("selectedColors values must be hex colors")
		}
	}
	return nil
}

func (record Record) Validate() error {
	if !ValidCartID(record.ID) {
		return errors.New("id must match the v1 cart id contract")
	}
	if record.CreatedAt.IsZero() || record.UpdatedAt.IsZero() {
		return errors.New("createdAt and updatedAt are required")
	}
	if record.UpdatedAt.Before(record.CreatedAt) {
		return errors.New("updatedAt must not be before createdAt")
	}
	if len(record.Items) > maxCartItems {
		return fmt.Errorf("items must contain at most %d entries", maxCartItems)
	}
	for index, item := range record.Items {
		if err := item.Validate(); err != nil {
			return fmt.Errorf("items[%d]: %w", index, err)
		}
	}
	if !totalsEqual(record.Totals, CalculateTotals(record.Items)) {
		return errors.New("totals must match cart items")
	}
	return nil
}

func (item ItemSnapshot) Validate() error {
	if err := (ItemInput{
		ProductID:      item.ProductID,
		SelectedColors: item.SelectedColors,
		Quantity:       item.Quantity,
		Selected:       item.Selected,
	}).Validate(); err != nil {
		return err
	}
	if item.ProductName == "" || len(item.ProductName) > 160 {
		return errors.New("productName length must be from 1 to 160")
	}
	if err := (product.ProductDraft{
		Name:                item.ProductName,
		Slug:                "cart-snapshot",
		Description:         "cart snapshot",
		Price:               item.Price,
		Categories:          item.Categories,
		InformationSections: []product.InformationSection{},
	}).Validate(); err != nil {
		return fmt.Errorf("product snapshot: %w", err)
	}
	if item.ProductUpdatedAt.IsZero() {
		return errors.New("productUpdatedAt is required")
	}
	return nil
}

func BuildSnapshots(request UpsertRequest, products map[string]product.ProductRecord) ([]ItemSnapshot, error) {
	if err := request.Validate(); err != nil {
		return nil, err
	}
	items := make([]ItemSnapshot, 0, len(request.Items))
	for index, item := range request.Items {
		record, ok := products[item.ProductID]
		if !ok {
			return nil, fmt.Errorf("items[%d]: product not found", index)
		}
		if err := validateSelectedColors(item.SelectedColors, record.MeshColorConfig); err != nil {
			return nil, fmt.Errorf("items[%d]: %w", index, err)
		}
		items = append(items, ItemSnapshot{
			ProductID:               record.ID,
			ProductName:             record.Name,
			Price:                   record.Price,
			Categories:              record.Categories,
			SelectedColors:          normalizeColorMap(item.SelectedColors),
			Quantity:                item.Quantity,
			Selected:                item.Selected,
			ProductUpdatedAt:        record.UpdatedAt,
			ProductProcessingStatus: record.ProcessingStatus,
		})
	}
	return items, nil
}

func CalculateTotals(items []ItemSnapshot) Totals {
	var totals Totals
	var currency string
	var compareTotal int64
	var hasCompare bool
	for _, item := range items {
		if !item.Selected {
			continue
		}
		totals.SelectedItemCount++
		totals.SelectedQuantity += item.Quantity
		lineAmount := item.Price.AmountCents * int64(item.Quantity)
		if currency == "" {
			currency = item.Price.Currency
			totals.Currency = &currency
			totals.SelectedAmountCents += lineAmount
		} else if currency == item.Price.Currency && !totals.MixedCurrency {
			totals.SelectedAmountCents += lineAmount
		} else {
			totals.MixedCurrency = true
			totals.Currency = nil
			totals.SelectedAmountCents = 0
			totals.SelectedSavingsCents = 0
			totals.SelectedCompareAtCents = nil
		}
		if totals.MixedCurrency {
			continue
		}
		if item.Price.CompareAtAmountCents != nil {
			hasCompare = true
			compareTotal += *item.Price.CompareAtAmountCents * int64(item.Quantity)
		} else {
			compareTotal += lineAmount
		}
	}
	if !totals.MixedCurrency && totals.SelectedItemCount > 0 && hasCompare {
		totals.SelectedCompareAtCents = &compareTotal
		if compareTotal > totals.SelectedAmountCents {
			totals.SelectedSavingsCents = compareTotal - totals.SelectedAmountCents
		}
	}
	return totals
}

func validateSelectedColors(selected map[string]string, config product.MeshColorConfig) error {
	for meshID, color := range selected {
		option, ok := config[meshID]
		if !ok {
			return fmt.Errorf("selectedColors[%q] is not configured for the product", meshID)
		}
		allowed := false
		for _, candidate := range option.Allowed {
			if strings.EqualFold(candidate, color) {
				allowed = true
				break
			}
		}
		if !allowed {
			return fmt.Errorf("selectedColors[%q] must be an allowed product color", meshID)
		}
	}
	return nil
}

func normalizeColorMap(input map[string]string) map[string]string {
	if len(input) == 0 {
		return nil
	}
	output := make(map[string]string, len(input))
	for meshID, color := range input {
		output[meshID] = strings.ToUpper(color)
	}
	return output
}

func (item ItemInput) identityKey() string {
	parts := make([]string, 0, len(item.SelectedColors)+1)
	parts = append(parts, item.ProductID)
	for meshID, color := range normalizeColorMap(item.SelectedColors) {
		parts = append(parts, meshID+"="+color)
	}
	sort.Strings(parts[1:])
	return strings.Join(parts, "|")
}

func totalsEqual(left, right Totals) bool {
	if left.SelectedItemCount != right.SelectedItemCount ||
		left.SelectedQuantity != right.SelectedQuantity ||
		left.SelectedAmountCents != right.SelectedAmountCents ||
		left.SelectedSavingsCents != right.SelectedSavingsCents ||
		left.MixedCurrency != right.MixedCurrency {
		return false
	}
	if (left.Currency == nil) != (right.Currency == nil) {
		return false
	}
	if left.Currency != nil && *left.Currency != *right.Currency {
		return false
	}
	if (left.SelectedCompareAtCents == nil) != (right.SelectedCompareAtCents == nil) {
		return false
	}
	if left.SelectedCompareAtCents != nil && *left.SelectedCompareAtCents != *right.SelectedCompareAtCents {
		return false
	}
	return true
}
