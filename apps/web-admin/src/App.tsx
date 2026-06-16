import * as React from "react";

import "./App.css";

export type ProductPrice = {
  amountCents: number;
  currency: string;
  compareAtAmountCents?: number;
};

export type ProductCategory = {
  slug: string;
  name: string;
};

export type ProductRecord = {
  id: string;
  name: string;
  slug: string;
  description: string;
  price: ProductPrice;
  categories?: ProductCategory[];
  updatedAt: string;
  processingStatus: string;
};

export type ProductListState =
  | { status: "loading" }
  | { status: "error"; message: string }
  | { status: "ready"; products: ProductRecord[] };

const statusLabels: Record<string, string> = {
  not_started: "Not started",
  queued: "Queued",
  processing: "Processing",
  completed: "Completed",
  failed: "Failed",
};

export function adminProductsUrl(apiBaseUrl = import.meta.env.VITE_API_BASE_URL) {
  const baseUrl = apiBaseUrl?.trim() || "";
  return `${baseUrl.replace(/\/$/, "")}/admin/products`;
}

export async function fetchAdminProducts(
  apiBaseUrl = import.meta.env.VITE_API_BASE_URL,
): Promise<ProductRecord[]> {
  const response = await fetch(adminProductsUrl(apiBaseUrl), {
    headers: {
      Accept: "application/json",
    },
  });

  if (!response.ok) {
    throw new Error(`Product list request failed with HTTP ${response.status}`);
  }

  const data = (await response.json()) as unknown;
  if (!Array.isArray(data)) {
    throw new Error("Product list response was not an array");
  }

  return data as ProductRecord[];
}

export function formatPrice(price: ProductPrice) {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: price.currency,
  }).format(price.amountCents / 100);
}

export function formatDateTime(value: string) {
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));
}

export function App() {
  const [state, setState] = useProducts();

  return <ProductListPage state={state} onRetry={() => void setState()} />;
}

function useProducts(): [ProductListState, () => Promise<void>] {
  const [state, setState] = React.useState<ProductListState>({
    status: "loading",
  });

  const loadProducts = React.useCallback(async () => {
    setState({ status: "loading" });
    try {
      const products = await fetchAdminProducts();
      setState({ status: "ready", products });
    } catch (error) {
      setState({
        status: "error",
        message:
          error instanceof Error
            ? error.message
            : "Product list request failed",
      });
    }
  }, []);

  React.useEffect(() => {
    void loadProducts();
  }, [loadProducts]);

  return [state, loadProducts];
}

export function ProductListPage({
  state,
  onRetry,
}: {
  state: ProductListState;
  onRetry: () => void;
}) {
  return (
    <main className="admin-shell">
      <header className="topbar" aria-label="Workspace">
        <div>
          <p className="eyebrow">Lumin Studio</p>
          <h1>Products</h1>
        </div>
        <div className="api-chip" aria-label="Current workspace">
          Catalog
        </div>
      </header>

      <section className="summary-panel" aria-labelledby="summary-title">
        <div>
          <p className="eyebrow">Admin catalog</p>
          <h2 id="summary-title">Published product records</h2>
          <p>Catalog records ready for processing and customer preview.</p>
        </div>
        <ProductCount state={state} />
      </section>

      <section className="product-panel" aria-labelledby="products-title">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">Product records</p>
            <h2 id="products-title">Product list</h2>
          </div>
          {state.status === "error" ? (
            <button className="retry-button" type="button" onClick={onRetry}>
              Retry
            </button>
          ) : null}
        </div>
        <ProductListContent state={state} />
      </section>
    </main>
  );
}

function ProductCount({ state }: { state: ProductListState }) {
  if (state.status !== "ready") {
    return (
      <div className="metric-block">
        <span className="metric-value">--</span>
        <span className="metric-label">records</span>
      </div>
    );
  }

  return (
    <div className="metric-block">
      <span className="metric-value">{state.products.length}</span>
      <span className="metric-label">records</span>
    </div>
  );
}

function ProductListContent({ state }: { state: ProductListState }) {
  if (state.status === "loading") {
    return <ProductSkeleton />;
  }

  if (state.status === "error") {
    return (
      <div className="state-message error-state" role="alert">
        <h3>Product list unavailable</h3>
        <p>{state.message}</p>
      </div>
    );
  }

  if (state.products.length === 0) {
    return (
      <div className="state-message">
        <h3>No products yet</h3>
        <p>
          Products created through the admin API will appear here after they are
          persisted.
        </p>
      </div>
    );
  }

  return (
    <div className="product-table" role="table" aria-label="Admin products">
      <div className="product-row product-row-head" role="row">
        <span role="columnheader">Product</span>
        <span role="columnheader">Price</span>
        <span role="columnheader">Status</span>
        <span role="columnheader">Updated</span>
      </div>
      {state.products.map((product) => (
        <article className="product-row" role="row" key={product.id}>
          <div className="product-main" role="cell">
            <h3>{product.name}</h3>
            <p>{product.slug}</p>
            <small>{product.id}</small>
            <CategoryList categories={product.categories ?? []} />
          </div>
          <div className="numeric-cell" role="cell">
            {formatPrice(product.price)}
          </div>
          <div role="cell">
            <span className={`status-pill status-${product.processingStatus}`}>
              {statusLabels[product.processingStatus] ?? product.processingStatus}
            </span>
          </div>
          <time className="muted-cell" dateTime={product.updatedAt} role="cell">
            {formatDateTime(product.updatedAt)}
          </time>
        </article>
      ))}
    </div>
  );
}

function CategoryList({ categories }: { categories: ProductCategory[] }) {
  if (categories.length === 0) {
    return <span className="category-empty">No category</span>;
  }

  return (
    <ul className="category-list" aria-label="Categories">
      {categories.map((category) => (
        <li key={category.slug}>{category.name}</li>
      ))}
    </ul>
  );
}

function ProductSkeleton() {
  return (
    <div className="skeleton-list" aria-label="Loading products">
      {[0, 1, 2].map((item) => (
        <div className="skeleton-row" key={item}>
          <span />
          <span />
          <span />
          <span />
        </div>
      ))}
    </div>
  );
}
