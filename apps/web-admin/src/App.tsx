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

export type InformationSection = {
  title: string;
  body: string;
  collapsedByDefault?: boolean;
};

export type MeshColorConfig = Record<
  string,
  {
    default: string;
    allowed: string[];
  }
>;

export type ProductDraft = {
  name: string;
  slug: string;
  description: string;
  price: ProductPrice;
  categories?: ProductCategory[];
  informationSections: InformationSection[];
  meshColorConfig?: MeshColorConfig;
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

export type ProductCreateState =
  | { status: "idle" }
  | { status: "submitting" }
  | { status: "success"; productName: string }
  | { status: "error"; message: string };

export type ProductFormValues = {
  name: string;
  slug: string;
  description: string;
  amountCents: string;
  currency: string;
  compareAtAmountCents: string;
  categoriesJson: string;
  informationSectionsJson: string;
  meshColorConfigJson: string;
};

const statusLabels: Record<string, string> = {
  not_started: "Not started",
  queued: "Queued",
  processing: "Processing",
  completed: "Completed",
  failed: "Failed",
};

const slugPattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const currencyPattern = /^[A-Z]{3}$/;

const defaultFormValues: ProductFormValues = {
  name: "",
  slug: "",
  description: "",
  amountCents: "",
  currency: "USD",
  compareAtAmountCents: "",
  categoriesJson: "[]",
  informationSectionsJson: "[]",
  meshColorConfigJson: "{}",
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

export async function createAdminProduct(
  draft: ProductDraft,
  apiBaseUrl = import.meta.env.VITE_API_BASE_URL,
): Promise<ProductRecord> {
  const response = await fetch(adminProductsUrl(apiBaseUrl), {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(draft),
  });

  if (!response.ok) {
    throw new Error(`Product create request failed with HTTP ${response.status}`);
  }

  return (await response.json()) as ProductRecord;
}

export function buildProductDraft(values: ProductFormValues): ProductDraft {
  const name = values.name.trim();
  const slug = values.slug.trim();
  const description = values.description.trim();
  const currency = values.currency.trim();

  if (!name) {
    throw new Error("Name is required.");
  }
  if (!description) {
    throw new Error("Description is required.");
  }
  if (!slugPattern.test(slug)) {
    throw new Error("Slug must use lowercase letters, numbers, and hyphens.");
  }
  if (!currencyPattern.test(currency)) {
    throw new Error("Currency must be a three-letter uppercase code.");
  }

  const amountCents = parseIntegerCents(values.amountCents, "amountCents");
  const compareAtAmountCents =
    values.compareAtAmountCents.trim() === ""
      ? undefined
      : parseIntegerCents(values.compareAtAmountCents, "compareAtAmountCents");

  if (
    compareAtAmountCents !== undefined &&
    compareAtAmountCents <= amountCents
  ) {
    throw new Error("Compare-at price must be greater than the display price.");
  }

  const categories = parseJsonField<ProductCategory[]>(
    values.categoriesJson,
    "categories",
    "array",
  );
  const informationSections = parseJsonField<InformationSection[]>(
    values.informationSectionsJson,
    "informationSections",
    "array",
  );
  const meshColorConfig = parseJsonField<MeshColorConfig>(
    values.meshColorConfigJson,
    "meshColorConfig",
    "object",
  );

  return {
    name,
    slug,
    description,
    price: {
      amountCents,
      currency,
      ...(compareAtAmountCents === undefined ? {} : { compareAtAmountCents }),
    },
    categories,
    informationSections,
    ...(Object.keys(meshColorConfig).length === 0 ? {} : { meshColorConfig }),
  };
}

function parseIntegerCents(value: string, field: string) {
  const trimmed = value.trim();
  if (!/^[0-9]+$/.test(trimmed)) {
    throw new Error(`${field} must be a positive integer cent amount.`);
  }

  const parsed = Number(trimmed);
  if (!Number.isSafeInteger(parsed) || parsed <= 0) {
    throw new Error(`${field} must be a positive integer cent amount.`);
  }

  return parsed;
}

function parseJsonField<T>(
  value: string,
  field: string,
  expected: "array" | "object",
): T {
  const trimmed = value.trim();
  if (!trimmed) {
    return (expected === "array" ? [] : {}) as T;
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(trimmed) as unknown;
  } catch {
    throw new Error(`${field} must be valid JSON.`);
  }

  if (expected === "array" && !Array.isArray(parsed)) {
    throw new Error(`${field} must be a JSON array.`);
  }
  if (
    expected === "object" &&
    (parsed === null || Array.isArray(parsed) || typeof parsed !== "object")
  ) {
    throw new Error(`${field} must be a JSON object.`);
  }

  return parsed as T;
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
  const [state, reloadProducts] = useProducts();
  const [createState, setCreateState] = React.useState<ProductCreateState>({
    status: "idle",
  });

  const createProduct = React.useCallback(
    async (values: ProductFormValues) => {
      setCreateState({ status: "submitting" });
      try {
        const draft = buildProductDraft(values);
        const product = await createAdminProduct(draft);
        setCreateState({ status: "success", productName: product.name });
        await reloadProducts();
      } catch (error) {
        setCreateState({
          status: "error",
          message:
            error instanceof Error
              ? error.message
              : "Product create request failed",
        });
      }
    },
    [reloadProducts],
  );

  return (
    <ProductListPage
      state={state}
      createState={createState}
      onCreate={(values) => void createProduct(values)}
      onRetry={() => void reloadProducts()}
    />
  );
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
  createState = { status: "idle" },
  onCreate = () => undefined,
  onRetry,
}: {
  state: ProductListState;
  createState?: ProductCreateState;
  onCreate?: (values: ProductFormValues) => void;
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

      <ProductCreatePanel createState={createState} onCreate={onCreate} />

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

export function ProductCreatePanel({
  createState,
  onCreate,
}: {
  createState: ProductCreateState;
  onCreate: (values: ProductFormValues) => void;
}) {
  const [values, setValues] =
    React.useState<ProductFormValues>(defaultFormValues);
  const [localError, setLocalError] = React.useState<string | null>(null);
  const disabled = createState.status === "submitting";

  function updateField(field: keyof ProductFormValues, value: string) {
    setValues((current) => ({ ...current, [field]: value }));
  }

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setLocalError(null);

    try {
      buildProductDraft(values);
    } catch (error) {
      setLocalError(
        error instanceof Error ? error.message : "Product draft is invalid.",
      );
      return;
    }

    onCreate(values);
  }

  return (
    <section className="create-panel" aria-labelledby="create-title">
      <div className="panel-heading create-heading">
        <div>
          <p className="eyebrow">Create product</p>
          <h2 id="create-title">New product draft</h2>
        </div>
        {createState.status === "submitting" ? (
          <span className="submit-status">Saving draft</span>
        ) : null}
      </div>

      <form className="product-form" onSubmit={handleSubmit}>
        <div className="form-grid">
          <label>
            <span>Name</span>
            <input
              name="name"
              value={values.name}
              onChange={(event) => updateField("name", event.target.value)}
              disabled={disabled}
              autoComplete="off"
            />
          </label>
          <label>
            <span>Slug</span>
            <input
              name="slug"
              value={values.slug}
              onChange={(event) => updateField("slug", event.target.value)}
              disabled={disabled}
              autoComplete="off"
              placeholder="matte-ceramic-pet-tag"
            />
          </label>
          <label className="wide-field">
            <span>Description</span>
            <textarea
              name="description"
              value={values.description}
              onChange={(event) =>
                updateField("description", event.target.value)
              }
              disabled={disabled}
              rows={3}
            />
          </label>
          <label>
            <span>Amount cents</span>
            <input
              name="amountCents"
              inputMode="numeric"
              value={values.amountCents}
              onChange={(event) =>
                updateField("amountCents", event.target.value)
              }
              disabled={disabled}
              placeholder="12900"
            />
          </label>
          <label>
            <span>Currency</span>
            <input
              name="currency"
              value={values.currency}
              onChange={(event) => updateField("currency", event.target.value)}
              disabled={disabled}
              maxLength={3}
            />
          </label>
          <label>
            <span>Compare-at cents</span>
            <input
              name="compareAtAmountCents"
              inputMode="numeric"
              value={values.compareAtAmountCents}
              onChange={(event) =>
                updateField("compareAtAmountCents", event.target.value)
              }
              disabled={disabled}
              placeholder="15900"
            />
          </label>
          <label className="wide-field">
            <span>Categories JSON</span>
            <textarea
              name="categoriesJson"
              value={values.categoriesJson}
              onChange={(event) =>
                updateField("categoriesJson", event.target.value)
              }
              disabled={disabled}
              rows={3}
            />
          </label>
          <label className="wide-field">
            <span>Information sections JSON</span>
            <textarea
              name="informationSectionsJson"
              value={values.informationSectionsJson}
              onChange={(event) =>
                updateField("informationSectionsJson", event.target.value)
              }
              disabled={disabled}
              rows={4}
            />
          </label>
          <label className="wide-field">
            <span>Mesh color config JSON</span>
            <textarea
              name="meshColorConfigJson"
              value={values.meshColorConfigJson}
              onChange={(event) =>
                updateField("meshColorConfigJson", event.target.value)
              }
              disabled={disabled}
              rows={4}
            />
          </label>
        </div>

        {localError ? (
          <p className="form-message form-message-error" role="alert">
            {localError}
          </p>
        ) : null}
        {createState.status === "error" ? (
          <p className="form-message form-message-error" role="alert">
            {createState.message}
          </p>
        ) : null}
        {createState.status === "success" ? (
          <p className="form-message form-message-success" role="status">
            Created {createState.productName}.
          </p>
        ) : null}

        <div className="form-actions">
          <button className="primary-button" type="submit" disabled={disabled}>
            {disabled ? "Saving" : "Create product"}
          </button>
        </div>
      </form>
    </section>
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
