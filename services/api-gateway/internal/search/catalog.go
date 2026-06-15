package search

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"lumin.studio/services/api-gateway/internal/product"
)

const (
	defaultCatalogLimit = 20
	maxCatalogLimit     = 100
	maxSearchQueryBytes = 160
)

type ProductSearcher interface {
	SearchProducts(ctx context.Context, query ProductSearchQuery) (ProductSearchResult, error)
}

type ProductSearchQuery struct {
	Query  string
	Limit  int
	Offset int
}

type ProductSearchResult struct {
	Hits  []ProductDocument
	Total int
}

type CatalogItem struct {
	ID               string                   `json:"id"`
	Name             string                   `json:"name"`
	Slug             string                   `json:"slug"`
	Description      string                   `json:"description"`
	ProcessingStatus product.ProcessingStatus `json:"processingStatus"`
	SpriteAsset      *product.ObjectRef       `json:"spriteAsset,omitempty"`
	UpdatedAt        time.Time                `json:"updatedAt"`
}

type CatalogSearchResponse struct {
	Items  []CatalogItem `json:"items"`
	Total  int           `json:"total"`
	Limit  int           `json:"limit"`
	Offset int           `json:"offset"`
	Query  string        `json:"query,omitempty"`
}

type Handler struct {
	searcher ProductSearcher
}

func NewHandler(searcher ProductSearcher) Handler {
	return Handler{searcher: searcher}
}

func (handler Handler) ListCatalogProducts(response http.ResponseWriter, request *http.Request) {
	handler.search(response, request, false)
}

func (handler Handler) SearchCatalogProducts(response http.ResponseWriter, request *http.Request) {
	handler.search(response, request, true)
}

func (handler Handler) search(response http.ResponseWriter, request *http.Request, requireQuery bool) {
	if handler.searcher == nil {
		writeError(response, http.StatusServiceUnavailable, "catalog search is not configured")
		return
	}

	query, err := productSearchQueryFromRequest(request, requireQuery)
	if err != nil {
		writeError(response, http.StatusBadRequest, err.Error())
		return
	}
	result, err := handler.searcher.SearchProducts(request.Context(), query)
	if err != nil {
		writeError(response, http.StatusBadGateway, "could not search catalog products")
		return
	}

	items := make([]CatalogItem, 0, len(result.Hits))
	for _, hit := range result.Hits {
		items = append(items, CatalogItem{
			ID:               hit.ID,
			Name:             hit.Name,
			Slug:             hit.Slug,
			Description:      hit.Description,
			ProcessingStatus: hit.ProcessingStatus,
			SpriteAsset:      hit.SpriteAsset,
			UpdatedAt:        hit.UpdatedAt,
		})
	}
	writeJSON(response, http.StatusOK, CatalogSearchResponse{
		Items:  items,
		Total:  result.Total,
		Limit:  query.Limit,
		Offset: query.Offset,
		Query:  query.Query,
	})
}

func productSearchQueryFromRequest(request *http.Request, requireQuery bool) (ProductSearchQuery, error) {
	values := request.URL.Query()
	query := strings.TrimSpace(values.Get("q"))
	if requireQuery && query == "" {
		return ProductSearchQuery{}, errors.New("q query parameter is required")
	}
	if len(query) > maxSearchQueryBytes {
		return ProductSearchQuery{}, fmt.Errorf("q must be at most %d bytes", maxSearchQueryBytes)
	}

	limit, err := boundedIntQuery(values, "limit", defaultCatalogLimit, 1, maxCatalogLimit)
	if err != nil {
		return ProductSearchQuery{}, err
	}
	offset, err := boundedIntQuery(values, "offset", 0, 0, 1_000_000)
	if err != nil {
		return ProductSearchQuery{}, err
	}
	return ProductSearchQuery{Query: query, Limit: limit, Offset: offset}, nil
}

func boundedIntQuery(values url.Values, name string, defaultValue, minimum, maximum int) (int, error) {
	raw := values.Get(name)
	if raw == "" {
		return defaultValue, nil
	}
	value, err := strconv.Atoi(raw)
	if err != nil || value < minimum || value > maximum {
		return 0, fmt.Errorf("%s must be an integer from %d to %d", name, minimum, maximum)
	}
	return value, nil
}

type MeilisearchSearcher struct {
	baseURL    *url.URL
	apiKey     string
	httpClient *http.Client
}

func NewMeilisearchSearcher(baseURL *url.URL, apiKey string, timeout time.Duration) MeilisearchSearcher {
	return MeilisearchSearcher{
		baseURL: baseURL,
		apiKey:  apiKey,
		httpClient: &http.Client{
			Timeout: timeout,
		},
	}
}

func (searcher MeilisearchSearcher) SearchProducts(ctx context.Context, query ProductSearchQuery) (ProductSearchResult, error) {
	if searcher.baseURL == nil || searcher.baseURL.Host == "" {
		return ProductSearchResult{}, errors.New("Meilisearch URL is not configured")
	}
	if searcher.apiKey == "" {
		return ProductSearchResult{}, errors.New("Meilisearch API key is not configured")
	}

	payload, err := json.Marshal(map[string]any{
		"q":      query.Query,
		"limit":  query.Limit,
		"offset": query.Offset,
	})
	if err != nil {
		return ProductSearchResult{}, fmt.Errorf("marshal product search request: %w", err)
	}

	target := *searcher.baseURL
	target.Path = strings.TrimRight(target.Path, "/") + "/indexes/" + productIndexUID + "/search"

	request, err := http.NewRequestWithContext(ctx, http.MethodPost, target.String(), bytes.NewReader(payload))
	if err != nil {
		return ProductSearchResult{}, err
	}
	request.Header.Set("Authorization", "Bearer "+searcher.apiKey)
	request.Header.Set("Content-Type", "application/json")

	response, err := searcher.httpClient.Do(request)
	if err != nil {
		return ProductSearchResult{}, err
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		body, _ := io.ReadAll(io.LimitReader(response.Body, 1024))
		return ProductSearchResult{}, fmt.Errorf("Meilisearch returned HTTP %d: %s", response.StatusCode, strings.TrimSpace(string(body)))
	}

	var decoded struct {
		Hits               []ProductDocument `json:"hits"`
		EstimatedTotalHits *int              `json:"estimatedTotalHits"`
		TotalHits          *int              `json:"totalHits"`
	}
	decoder := json.NewDecoder(response.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&decoded); err != nil {
		return ProductSearchResult{}, fmt.Errorf("decode product search response: %w", err)
	}
	total := len(decoded.Hits)
	if decoded.EstimatedTotalHits != nil {
		total = *decoded.EstimatedTotalHits
	} else if decoded.TotalHits != nil {
		total = *decoded.TotalHits
	}
	return ProductSearchResult{Hits: decoded.Hits, Total: total}, nil
}

func writeJSON(response http.ResponseWriter, status int, payload any) {
	response.Header().Set("Content-Type", "application/json")
	response.WriteHeader(status)
	if err := json.NewEncoder(response).Encode(payload); err != nil {
		http.Error(response, "could not encode response", http.StatusInternalServerError)
	}
}

func writeError(response http.ResponseWriter, status int, message string) {
	response.Header().Set("Content-Type", "application/json")
	response.WriteHeader(status)
	_ = json.NewEncoder(response).Encode(map[string]string{"error": message})
}
