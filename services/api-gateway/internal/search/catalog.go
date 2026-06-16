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
	"sort"
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
	ListCategories(ctx context.Context) ([]product.ProductCategory, error)
}

type CatalogProductReader interface {
	GetProduct(ctx context.Context, id string) (product.ProductRecord, error)
}

type SpriteAssetStore interface {
	GetSpriteAsset(ctx context.Context, ref product.ObjectRef) (io.ReadCloser, error)
}

type ModelAssetStore interface {
	GetModelAsset(ctx context.Context, ref product.ObjectRef) (io.ReadCloser, error)
}

type ProductSearchQuery struct {
	Query        string
	CategorySlug string
	Sort         string
	Limit        int
	Offset       int
}

type ProductSearchResult struct {
	Hits  []ProductDocument
	Total int
}

type CatalogItem struct {
	ID               string                    `json:"id"`
	Name             string                    `json:"name"`
	Slug             string                    `json:"slug"`
	Description      string                    `json:"description"`
	Price            product.ProductPrice      `json:"price"`
	Categories       []product.ProductCategory `json:"categories,omitempty"`
	ProcessingStatus product.ProcessingStatus  `json:"processingStatus"`
	SpriteAsset      *product.ObjectRef        `json:"spriteAsset,omitempty"`
	UpdatedAt        time.Time                 `json:"updatedAt"`
}

type CatalogSearchResponse struct {
	Items        []CatalogItem `json:"items"`
	Total        int           `json:"total"`
	Limit        int           `json:"limit"`
	Offset       int           `json:"offset"`
	Query        string        `json:"query,omitempty"`
	CategorySlug string        `json:"categorySlug,omitempty"`
	Sort         string        `json:"sort,omitempty"`
}

type CategoryListResponse struct {
	Categories []product.ProductCategory `json:"categories"`
}

type ProductDetailResponse struct {
	ID                  string                       `json:"id"`
	Name                string                       `json:"name"`
	Slug                string                       `json:"slug"`
	Description         string                       `json:"description"`
	Price               product.ProductPrice         `json:"price"`
	Categories          []product.ProductCategory    `json:"categories,omitempty"`
	InformationSections []product.InformationSection `json:"informationSections"`
	MeshColorConfig     product.MeshColorConfig      `json:"meshColorConfig,omitempty"`
	ProcessingStatus    product.ProcessingStatus     `json:"processingStatus"`
	ModelTier           string                       `json:"modelTier"`
	ModelAsset          *product.ObjectRef           `json:"modelAsset,omitempty"`
	ModelURL            string                       `json:"modelUrl,omitempty"`
	SpriteAsset         *product.ObjectRef           `json:"spriteAsset,omitempty"`
	SpriteURL           string                       `json:"spriteUrl,omitempty"`
	UpdatedAt           time.Time                    `json:"updatedAt"`
}

type Handler struct {
	searcher      ProductSearcher
	productReader CatalogProductReader
	spriteAssets  SpriteAssetStore
	modelAssets   ModelAssetStore
}

func NewHandler(searcher ProductSearcher) Handler {
	return Handler{searcher: searcher}
}

func (handler Handler) WithCatalogProductReader(reader CatalogProductReader) Handler {
	handler.productReader = reader
	return handler
}

func (handler Handler) WithSpriteAssetStore(store SpriteAssetStore) Handler {
	handler.spriteAssets = store
	return handler
}

func (handler Handler) WithModelAssetStore(store ModelAssetStore) Handler {
	handler.modelAssets = store
	return handler
}

func (handler Handler) ListCatalogProducts(response http.ResponseWriter, request *http.Request) {
	handler.search(response, request, false)
}

func (handler Handler) SearchCatalogProducts(response http.ResponseWriter, request *http.Request) {
	handler.search(response, request, true)
}

func (handler Handler) ListCatalogCategories(response http.ResponseWriter, request *http.Request) {
	if handler.searcher == nil {
		writeError(response, http.StatusServiceUnavailable, "catalog search is not configured")
		return
	}
	categories, err := handler.searcher.ListCategories(request.Context())
	if err != nil {
		writeError(response, http.StatusBadGateway, "could not list catalog categories")
		return
	}
	writeJSON(response, http.StatusOK, CategoryListResponse{Categories: categories})
}

func (handler Handler) ListCategoryProducts(response http.ResponseWriter, request *http.Request) {
	handler.search(response, request, false)
}

func (handler Handler) GetCatalogProductDetail(response http.ResponseWriter, request *http.Request) {
	if handler.productReader == nil {
		writeError(response, http.StatusServiceUnavailable, "catalog products are not configured")
		return
	}

	id := request.PathValue("id")
	if !product.ValidProductID(id) {
		writeError(response, http.StatusBadRequest, "id must match the v1 product id contract")
		return
	}
	tier, err := modelTierFromRequest(request)
	if err != nil {
		writeError(response, http.StatusBadRequest, err.Error())
		return
	}

	record, err := handler.productReader.GetProduct(request.Context(), id)
	if err != nil {
		if errors.Is(err, product.ErrProductNotFound) {
			writeError(response, http.StatusNotFound, "product not found")
			return
		}
		writeError(response, http.StatusInternalServerError, "could not read product")
		return
	}
	modelAsset, ok := modelAssetForTier(record, tier)
	if !ok {
		writeError(response, http.StatusNotFound, "model asset not found")
		return
	}

	detail := ProductDetailResponse{
		ID:                  record.ID,
		Name:                record.Name,
		Slug:                record.Slug,
		Description:         record.Description,
		Price:               record.Price,
		Categories:          record.Categories,
		InformationSections: record.InformationSections,
		MeshColorConfig:     record.MeshColorConfig,
		ProcessingStatus:    record.ProcessingStatus,
		ModelTier:           tier,
		ModelAsset:          modelAsset,
		ModelURL:            fmt.Sprintf("/catalog/products/%s/model?tier=%s", record.ID, tier),
		SpriteAsset:         record.SpriteAsset,
		UpdatedAt:           record.UpdatedAt,
	}
	if record.SpriteAsset != nil {
		detail.SpriteURL = fmt.Sprintf("/catalog/products/%s/sprite", record.ID)
	}
	writeJSON(response, http.StatusOK, detail)
}

func (handler Handler) GetCatalogProductModel(response http.ResponseWriter, request *http.Request) {
	if handler.productReader == nil || handler.modelAssets == nil {
		writeError(response, http.StatusServiceUnavailable, "catalog model assets are not configured")
		return
	}

	id := request.PathValue("id")
	if !product.ValidProductID(id) {
		writeError(response, http.StatusBadRequest, "id must match the v1 product id contract")
		return
	}
	tier, err := modelTierFromRequest(request)
	if err != nil {
		writeError(response, http.StatusBadRequest, err.Error())
		return
	}

	record, err := handler.productReader.GetProduct(request.Context(), id)
	if err != nil {
		if errors.Is(err, product.ErrProductNotFound) {
			writeError(response, http.StatusNotFound, "product not found")
			return
		}
		writeError(response, http.StatusInternalServerError, "could not read product")
		return
	}
	modelAsset, ok := modelAssetForTier(record, tier)
	if !ok {
		writeError(response, http.StatusNotFound, "model asset not found")
		return
	}

	asset, err := handler.modelAssets.GetModelAsset(request.Context(), *modelAsset)
	if err != nil {
		writeError(response, http.StatusBadGateway, "could not read model asset")
		return
	}
	defer asset.Close()

	contentType := modelAsset.ContentType
	if contentType == "" {
		contentType = "model/gltf-binary"
	}
	response.Header().Set("Content-Type", contentType)
	response.Header().Set("Cache-Control", "public, max-age=300")
	if modelAsset.ETag != "" {
		response.Header().Set("ETag", modelAsset.ETag)
	}
	if modelAsset.SizeBytes != nil {
		response.Header().Set("Content-Length", strconv.FormatInt(*modelAsset.SizeBytes, 10))
	}
	response.WriteHeader(http.StatusOK)
	if _, err := io.Copy(response, asset); err != nil {
		return
	}
}

func (handler Handler) GetCatalogProductSprite(response http.ResponseWriter, request *http.Request) {
	if handler.productReader == nil || handler.spriteAssets == nil {
		writeError(response, http.StatusServiceUnavailable, "catalog sprite assets are not configured")
		return
	}

	id := request.PathValue("id")
	if !product.ValidProductID(id) {
		writeError(response, http.StatusBadRequest, "id must match the v1 product id contract")
		return
	}
	record, err := handler.productReader.GetProduct(request.Context(), id)
	if err != nil {
		if errors.Is(err, product.ErrProductNotFound) {
			writeError(response, http.StatusNotFound, "product not found")
			return
		}
		writeError(response, http.StatusInternalServerError, "could not read product")
		return
	}
	if record.ProcessingStatus != product.ProcessingCompleted || record.SpriteAsset == nil {
		writeError(response, http.StatusNotFound, "sprite asset not found")
		return
	}
	if record.SpriteAsset.Bucket != "lumin-360-sprites" {
		writeError(response, http.StatusBadGateway, "sprite asset uses an unsupported bucket")
		return
	}

	asset, err := handler.spriteAssets.GetSpriteAsset(request.Context(), *record.SpriteAsset)
	if err != nil {
		writeError(response, http.StatusBadGateway, "could not read sprite asset")
		return
	}
	defer asset.Close()

	contentType := record.SpriteAsset.ContentType
	if contentType == "" {
		contentType = "image/jpeg"
	}
	response.Header().Set("Content-Type", contentType)
	response.Header().Set("Cache-Control", "public, max-age=300")
	if record.SpriteAsset.ETag != "" {
		response.Header().Set("ETag", record.SpriteAsset.ETag)
	}
	if record.SpriteAsset.SizeBytes != nil {
		response.Header().Set("Content-Length", strconv.FormatInt(*record.SpriteAsset.SizeBytes, 10))
	}
	response.WriteHeader(http.StatusOK)
	if _, err := io.Copy(response, asset); err != nil {
		return
	}
}

func modelTierFromRequest(request *http.Request) (string, error) {
	tier := strings.TrimSpace(request.URL.Query().Get("tier"))
	if tier == "" {
		tier = "low"
	}
	switch tier {
	case "low", "high":
		return tier, nil
	default:
		return "", errors.New("tier must be low or high")
	}
}

func modelAssetForTier(record product.ProductRecord, tier string) (*product.ObjectRef, bool) {
	if record.ProcessingStatus != product.ProcessingCompleted {
		return nil, false
	}
	switch tier {
	case "low":
		if record.OptimizedAsset == nil || record.OptimizedAsset.Bucket != "lumin-optimized-glb" {
			return nil, false
		}
		return record.OptimizedAsset, true
	case "high":
		if record.SourceAsset == nil || record.SourceAsset.Bucket != "lumin-source-glb" {
			return nil, false
		}
		return record.SourceAsset, true
	default:
		return nil, false
	}
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
			Price:            hit.Price,
			Categories:       hit.Categories,
			ProcessingStatus: hit.ProcessingStatus,
			SpriteAsset:      hit.SpriteAsset,
			UpdatedAt:        hit.UpdatedAt,
		})
	}
	writeJSON(response, http.StatusOK, CatalogSearchResponse{
		Items:        items,
		Total:        result.Total,
		Limit:        query.Limit,
		Offset:       query.Offset,
		Query:        query.Query,
		CategorySlug: query.CategorySlug,
		Sort:         query.Sort,
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
	categorySlug := strings.TrimSpace(request.PathValue("slug"))
	if categorySlug != "" && !product.ValidSlug(categorySlug) {
		return ProductSearchQuery{}, errors.New("category slug must match the v1 category slug contract")
	}
	sortValue, err := productSortFromRequest(values)
	if err != nil {
		return ProductSearchQuery{}, err
	}

	limit, err := boundedIntQuery(values, "limit", defaultCatalogLimit, 1, maxCatalogLimit)
	if err != nil {
		return ProductSearchQuery{}, err
	}
	offset, err := boundedIntQuery(values, "offset", 0, 0, 1_000_000)
	if err != nil {
		return ProductSearchQuery{}, err
	}
	return ProductSearchQuery{Query: query, CategorySlug: categorySlug, Sort: sortValue, Limit: limit, Offset: offset}, nil
}

func productSortFromRequest(values url.Values) (string, error) {
	sortValue := strings.TrimSpace(values.Get("sort"))
	if sortValue == "" {
		return "", nil
	}
	switch sortValue {
	case "newest", "price_asc", "price_desc", "name_asc":
		return sortValue, nil
	default:
		return "", errors.New("sort must be newest, price_asc, price_desc, or name_asc")
	}
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

	payload := map[string]any{
		"q":      query.Query,
		"limit":  query.Limit,
		"offset": query.Offset,
	}
	if query.CategorySlug != "" {
		payload["filter"] = fmt.Sprintf("categorySlugs = %q", query.CategorySlug)
	}
	if sortExpr, ok := sortExpression(query.Sort); ok {
		payload["sort"] = []string{sortExpr}
	}
	encodedPayload, err := json.Marshal(payload)
	if err != nil {
		return ProductSearchResult{}, fmt.Errorf("marshal product search request: %w", err)
	}

	target := *searcher.baseURL
	target.Path = strings.TrimRight(target.Path, "/") + "/indexes/" + productIndexUID + "/search"

	request, err := http.NewRequestWithContext(ctx, http.MethodPost, target.String(), bytes.NewReader(encodedPayload))
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

func (searcher MeilisearchSearcher) ListCategories(ctx context.Context) ([]product.ProductCategory, error) {
	if searcher.baseURL == nil || searcher.baseURL.Host == "" {
		return nil, errors.New("Meilisearch URL is not configured")
	}
	if searcher.apiKey == "" {
		return nil, errors.New("Meilisearch API key is not configured")
	}

	payload, err := json.Marshal(map[string]any{
		"q":      "",
		"limit":  0,
		"offset": 0,
		"facets": []string{"categoryKeys"},
	})
	if err != nil {
		return nil, fmt.Errorf("marshal category list request: %w", err)
	}

	target := *searcher.baseURL
	target.Path = strings.TrimRight(target.Path, "/") + "/indexes/" + productIndexUID + "/search"

	request, err := http.NewRequestWithContext(ctx, http.MethodPost, target.String(), bytes.NewReader(payload))
	if err != nil {
		return nil, err
	}
	request.Header.Set("Authorization", "Bearer "+searcher.apiKey)
	request.Header.Set("Content-Type", "application/json")

	response, err := searcher.httpClient.Do(request)
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		body, _ := io.ReadAll(io.LimitReader(response.Body, 1024))
		return nil, fmt.Errorf("Meilisearch returned HTTP %d: %s", response.StatusCode, strings.TrimSpace(string(body)))
	}

	var decoded struct {
		FacetDistribution map[string]map[string]int `json:"facetDistribution"`
	}
	decoder := json.NewDecoder(response.Body)
	if err := decoder.Decode(&decoded); err != nil {
		return nil, fmt.Errorf("decode category list response: %w", err)
	}
	bySlug := map[string]product.ProductCategory{}
	for key := range decoded.FacetDistribution["categoryKeys"] {
		slug, name, ok := strings.Cut(key, "\t")
		if ok && slug != "" && name != "" {
			bySlug[slug] = product.ProductCategory{Slug: slug, Name: name}
		}
	}
	categories := make([]product.ProductCategory, 0, len(bySlug))
	for _, category := range bySlug {
		categories = append(categories, category)
	}
	sort.Slice(categories, func(i, j int) bool {
		if categories[i].Name == categories[j].Name {
			return categories[i].Slug < categories[j].Slug
		}
		return categories[i].Name < categories[j].Name
	})
	return categories, nil
}

func sortExpression(sortValue string) (string, bool) {
	switch sortValue {
	case "newest":
		return "updatedAt:desc", true
	case "price_asc":
		return "priceAmountCents:asc", true
	case "price_desc":
		return "priceAmountCents:desc", true
	case "name_asc":
		return "name:asc", true
	default:
		return "", false
	}
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
