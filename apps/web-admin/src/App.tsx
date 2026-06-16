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

export type ObjectRef = {
  bucket: string;
  key: string;
  contentType?: string;
  sizeBytes?: number;
};

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
  informationSections?: InformationSection[];
  meshColorConfig?: MeshColorConfig;
  sourceAsset?: ObjectRef;
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

export type ProductEditState =
  | { status: "idle" }
  | { status: "submitting"; productId: string }
  | { status: "success"; productName: string }
  | { status: "error"; message: string };

export type SourceUploadState =
  | { status: "idle" }
  | { status: "submitting"; productId: string }
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

export function adminProductUrl(
  productId: string,
  apiBaseUrl = import.meta.env.VITE_API_BASE_URL,
) {
  return `${adminProductsUrl(apiBaseUrl)}/${encodeURIComponent(productId)}`;
}

export function adminSourceUploadUrl(
  productId: string,
  apiBaseUrl = import.meta.env.VITE_API_BASE_URL,
) {
  return `${adminProductUrl(productId, apiBaseUrl)}/source-glb`;
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

export async function updateAdminProduct(
  productId: string,
  draft: ProductDraft,
  apiBaseUrl = import.meta.env.VITE_API_BASE_URL,
): Promise<ProductRecord> {
  const response = await fetch(adminProductUrl(productId, apiBaseUrl), {
    method: "PUT",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(draft),
  });

  if (!response.ok) {
    throw new Error(`Product update request failed with HTTP ${response.status}`);
  }

  return (await response.json()) as ProductRecord;
}

export async function uploadProductSource(
  productId: string,
  file: File,
  apiBaseUrl = import.meta.env.VITE_API_BASE_URL,
): Promise<ProductRecord> {
  const body = new FormData();
  body.append("source", file);

  const response = await fetch(adminSourceUploadUrl(productId, apiBaseUrl), {
    method: "POST",
    headers: {
      Accept: "application/json",
    },
    body,
  });

  if (!response.ok) {
    throw new Error(`Source upload request failed with HTTP ${response.status}`);
  }

  return (await response.json()) as ProductRecord;
}

export function validateSourceUpload(product: ProductRecord, file: File | null) {
  if (!file) {
    throw new Error("Choose a .glb file before uploading.");
  }
  if (!file.name.toLowerCase().endsWith(".glb")) {
    throw new Error("Source asset must use a .glb file.");
  }
  if (file.size <= 0) {
    throw new Error("Source asset file is empty.");
  }
  if (
    !product.meshColorConfig ||
    Object.keys(product.meshColorConfig).length === 0
  ) {
    throw new Error("Mesh color config is required before uploading a source asset.");
  }
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

export function productRecordToFormValues(
  product: ProductRecord,
): ProductFormValues {
  return {
    name: product.name,
    slug: product.slug,
    description: product.description,
    amountCents: String(product.price.amountCents),
    currency: product.price.currency,
    compareAtAmountCents:
      product.price.compareAtAmountCents === undefined
        ? ""
        : String(product.price.compareAtAmountCents),
    categoriesJson: JSON.stringify(product.categories ?? []),
    informationSectionsJson: JSON.stringify(product.informationSections ?? []),
    meshColorConfigJson: JSON.stringify(product.meshColorConfig ?? {}),
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
  const [editState, setEditState] = React.useState<ProductEditState>({
    status: "idle",
  });
  const [sourceUploadState, setSourceUploadState] =
    React.useState<SourceUploadState>({
      status: "idle",
    });
  const [selectedProductId, setSelectedProductId] = React.useState<string | null>(
    null,
  );

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

  const updateProduct = React.useCallback(
    async (productId: string, values: ProductFormValues) => {
      setEditState({ status: "submitting", productId });
      try {
        const draft = buildProductDraft(values);
        const product = await updateAdminProduct(productId, draft);
        setEditState({ status: "success", productName: product.name });
        await reloadProducts();
        setSelectedProductId(product.id);
      } catch (error) {
        setEditState({
          status: "error",
          message:
            error instanceof Error
              ? error.message
              : "Product update request failed",
        });
      }
    },
    [reloadProducts],
  );

  const uploadSource = React.useCallback(
    async (product: ProductRecord, file: File) => {
      setSourceUploadState({ status: "submitting", productId: product.id });
      try {
        const updatedProduct = await uploadProductSource(product.id, file);
        setSourceUploadState({
          status: "success",
          productName: updatedProduct.name,
        });
        await reloadProducts();
        setSelectedProductId(updatedProduct.id);
      } catch (error) {
        setSourceUploadState({
          status: "error",
          message:
            error instanceof Error
              ? error.message
              : "Source upload request failed",
        });
      }
    },
    [reloadProducts],
  );

  return (
    <ProductListPage
      state={state}
      createState={createState}
      editState={editState}
      sourceUploadState={sourceUploadState}
      selectedProductId={selectedProductId}
      onCreate={(values) => void createProduct(values)}
      onEditProduct={(productId) => {
        setSelectedProductId(productId);
        setEditState({ status: "idle" });
        setSourceUploadState({ status: "idle" });
      }}
      onCancelEdit={() => {
        setSelectedProductId(null);
        setEditState({ status: "idle" });
        setSourceUploadState({ status: "idle" });
      }}
      onUpdate={(productId, values) => void updateProduct(productId, values)}
      onUploadSource={(product, file) => void uploadSource(product, file)}
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
  editState = { status: "idle" },
  sourceUploadState = { status: "idle" },
  selectedProductId = null,
  onCreate = () => undefined,
  onEditProduct = () => undefined,
  onCancelEdit = () => undefined,
  onUpdate = () => undefined,
  onUploadSource = () => undefined,
  onRetry,
}: {
  state: ProductListState;
  createState?: ProductCreateState;
  editState?: ProductEditState;
  sourceUploadState?: SourceUploadState;
  selectedProductId?: string | null;
  onCreate?: (values: ProductFormValues) => void;
  onEditProduct?: (productId: string) => void;
  onCancelEdit?: () => void;
  onUpdate?: (productId: string, values: ProductFormValues) => void;
  onUploadSource?: (product: ProductRecord, file: File) => void;
  onRetry: () => void;
}) {
  const selectedProduct =
    state.status === "ready" && selectedProductId
      ? (state.products.find((product) => product.id === selectedProductId) ??
        null)
      : null;

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

      <ProductEditPanel
        product={selectedProduct}
        editState={editState}
        sourceUploadState={sourceUploadState}
        onCancel={onCancelEdit}
        onUpdate={onUpdate}
        onUploadSource={onUploadSource}
      />

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
        <ProductListContent
          state={state}
          selectedProductId={selectedProductId}
          onEditProduct={onEditProduct}
        />
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

      <ProductDraftForm
        values={values}
        disabled={disabled}
        localError={localError}
        remoteError={
          createState.status === "error" ? createState.message : undefined
        }
        successMessage={
          createState.status === "success"
            ? `Created ${createState.productName}.`
            : undefined
        }
        submitLabel="Create product"
        submittingLabel="Saving"
        onFieldChange={updateField}
        onSubmit={handleSubmit}
      />
    </section>
  );
}

export function ProductEditPanel({
  product,
  editState,
  sourceUploadState,
  onCancel,
  onUpdate,
  onUploadSource,
}: {
  product: ProductRecord | null;
  editState: ProductEditState;
  sourceUploadState: SourceUploadState;
  onCancel: () => void;
  onUpdate: (productId: string, values: ProductFormValues) => void;
  onUploadSource: (product: ProductRecord, file: File) => void;
}) {
  if (!product) {
    return null;
  }

  return (
    <section className="edit-panel" aria-labelledby="edit-title">
      <div className="panel-heading create-heading">
        <div>
          <p className="eyebrow">Selected product</p>
          <h2 id="edit-title">{product.name}</h2>
        </div>
        <button
          className="secondary-button"
          type="button"
          onClick={onCancel}
          disabled={
            editState.status === "submitting" ||
            sourceUploadState.status === "submitting"
          }
        >
          Close
        </button>
      </div>

      <div className="selected-product-grid">
        <ProductEditForm
          key={`edit-${product.id}`}
          product={product}
          editState={editState}
          onUpdate={onUpdate}
        />
        <ProductSourceUploadPanel
          key={`upload-${product.id}`}
          product={product}
          sourceUploadState={sourceUploadState}
          onUploadSource={onUploadSource}
        />
      </div>
    </section>
  );
}

function ProductEditForm({
  product,
  editState,
  onUpdate,
}: {
  product: ProductRecord;
  editState: ProductEditState;
  onUpdate: (productId: string, values: ProductFormValues) => void;
}) {
  const [values, setValues] = React.useState<ProductFormValues>(() =>
    productRecordToFormValues(product),
  );
  const [localError, setLocalError] = React.useState<string | null>(null);
  const disabled =
    editState.status === "submitting" && editState.productId === product.id;

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

    onUpdate(product.id, values);
  }

  return (
    <div className="selected-product-card">
      <div className="selected-card-heading">
        <p className="eyebrow">Edit product</p>
        <h3>Draft fields</h3>
      </div>
      <ProductDraftForm
        values={values}
        disabled={disabled}
        localError={localError}
        remoteError={
          editState.status === "error" ? editState.message : undefined
        }
        successMessage={
          editState.status === "success"
            ? `Updated ${editState.productName}.`
            : undefined
        }
        submitLabel="Save changes"
        submittingLabel="Saving"
        onFieldChange={updateField}
        onSubmit={handleSubmit}
      />
    </div>
  );
}

export function ProductSourceUploadPanel({
  product,
  sourceUploadState,
  onUploadSource,
}: {
  product: ProductRecord;
  sourceUploadState: SourceUploadState;
  onUploadSource: (product: ProductRecord, file: File) => void;
}) {
  const [file, setFile] = React.useState<File | null>(null);
  const [localError, setLocalError] = React.useState<string | null>(null);
  const disabled =
    sourceUploadState.status === "submitting" &&
    sourceUploadState.productId === product.id;
  const hasSourceAsset = product.sourceAsset !== undefined;

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setLocalError(null);

    try {
      validateSourceUpload(product, file);
    } catch (error) {
      setLocalError(
        error instanceof Error ? error.message : "Source asset is invalid.",
      );
      return;
    }

    if (!file) {
      return;
    }
    onUploadSource(product, file);
  }

  return (
    <div className="selected-product-card upload-card">
      <div className="selected-card-heading">
        <p className="eyebrow">3D intake</p>
        <h3>Upload GLB</h3>
      </div>
      <p className="upload-copy">
        Send one binary GLB to the API gateway. The API stores it and queues
        processing for this product.
      </p>
      <dl className="asset-summary" aria-label="Current source asset">
        <div>
          <dt>Current asset</dt>
          <dd>{hasSourceAsset ? product.sourceAsset?.key : "None uploaded"}</dd>
        </div>
        <div>
          <dt>Processing</dt>
          <dd>{statusLabels[product.processingStatus] ?? product.processingStatus}</dd>
        </div>
      </dl>

      <form className="source-upload-form" onSubmit={handleSubmit}>
        <label>
          <span>Source file</span>
          <input
            name="source"
            type="file"
            accept=".glb,model/gltf-binary"
            disabled={disabled}
            onChange={(event) => {
              setLocalError(null);
              setFile(event.target.files?.[0] ?? null);
            }}
          />
        </label>

        {localError ? (
          <p className="form-message form-message-error" role="alert">
            {localError}
          </p>
        ) : null}
        {sourceUploadState.status === "error" ? (
          <p className="form-message form-message-error" role="alert">
            {sourceUploadState.message}
          </p>
        ) : null}
        {sourceUploadState.status === "success" ? (
          <p className="form-message form-message-success" role="status">
            Uploaded GLB for {sourceUploadState.productName}.
          </p>
        ) : null}

        <div className="form-actions">
          <button className="primary-button" type="submit" disabled={disabled}>
            {disabled ? "Uploading" : "Upload GLB"}
          </button>
        </div>
      </form>
    </div>
  );
}

function ProductDraftForm({
  values,
  disabled,
  localError,
  remoteError,
  successMessage,
  submitLabel,
  submittingLabel,
  onFieldChange,
  onSubmit,
}: {
  values: ProductFormValues;
  disabled: boolean;
  localError?: string | null;
  remoteError?: string;
  successMessage?: string;
  submitLabel: string;
  submittingLabel: string;
  onFieldChange: (field: keyof ProductFormValues, value: string) => void;
  onSubmit: (event: React.FormEvent<HTMLFormElement>) => void;
}) {
  return (
    <form className="product-form" onSubmit={onSubmit}>
      <div className="form-grid">
        <label>
          <span>Name</span>
          <input
            name="name"
            value={values.name}
            onChange={(event) => onFieldChange("name", event.target.value)}
            disabled={disabled}
            autoComplete="off"
          />
        </label>
        <label>
          <span>Slug</span>
          <input
            name="slug"
            value={values.slug}
            onChange={(event) => onFieldChange("slug", event.target.value)}
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
              onFieldChange("description", event.target.value)
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
              onFieldChange("amountCents", event.target.value)
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
            onChange={(event) => onFieldChange("currency", event.target.value)}
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
              onFieldChange("compareAtAmountCents", event.target.value)
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
              onFieldChange("categoriesJson", event.target.value)
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
              onFieldChange("informationSectionsJson", event.target.value)
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
              onFieldChange("meshColorConfigJson", event.target.value)
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
      {remoteError ? (
        <p className="form-message form-message-error" role="alert">
          {remoteError}
        </p>
      ) : null}
      {successMessage ? (
        <p className="form-message form-message-success" role="status">
          {successMessage}
        </p>
      ) : null}

      <div className="form-actions">
        <button className="primary-button" type="submit" disabled={disabled}>
          {disabled ? submittingLabel : submitLabel}
        </button>
      </div>
    </form>
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

function ProductListContent({
  state,
  selectedProductId,
  onEditProduct,
}: {
  state: ProductListState;
  selectedProductId?: string | null;
  onEditProduct: (productId: string) => void;
}) {
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
        <span role="columnheader">Action</span>
      </div>
      {state.products.map((product) => (
        <article
          className={`product-row${
            selectedProductId === product.id ? " product-row-selected" : ""
          }`}
          role="row"
          key={product.id}
        >
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
          <div role="cell">
            <button
              className="row-action-button"
              type="button"
              onClick={() => onEditProduct(product.id)}
              aria-pressed={selectedProductId === product.id}
            >
              Edit
            </button>
          </div>
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
