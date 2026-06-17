import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, describe, expect, it, vi } from "vitest";

import {
  ProductCreatePanel,
  ProductEditPanel,
  ProductListPage,
  ProductSourceUploadPanel,
  adminProductUrl,
  adminProductsUrl,
  adminSourceUploadUrl,
  buildProductDraft,
  createAdminProduct,
  formatPrice,
  productRecordToFormValues,
  updateAdminProduct,
  uploadProductSource,
  validateSourceUpload,
  type ProductFormValues,
  type ProductRecord,
} from "./App";

const product: ProductRecord = {
  id: "prod_12345678",
  name: "Matte ceramic pet tag",
  slug: "matte-ceramic-pet-tag",
  description: "Configurable tag with processed 3D assets.",
  price: {
    amountCents: 12900,
    currency: "USD",
    compareAtAmountCents: 15900,
  },
  categories: [
    {
      slug: "pets",
      name: "Pets",
    },
  ],
  informationSections: [
    {
      title: "Materials",
      body: "Ceramic body with brass ring.",
    },
  ],
  meshColorConfig: {
    mesh_body: {
      default: "#FFFFFF",
      allowed: ["#FFFFFF", "#111111"],
    },
  },
  sourceAsset: {
    bucket: "lumin-source-glb",
    key: "products/prod_12345678/source.glb",
    contentType: "model/gltf-binary",
  },
  updatedAt: "2026-06-16T04:30:00Z",
  processingStatus: "completed",
};

const validFormValues: ProductFormValues = {
  name: "Matte ceramic pet tag",
  slug: "matte-ceramic-pet-tag",
  description: "Configurable tag with processed 3D assets.",
  amountCents: "12900",
  currency: "USD",
  compareAtAmountCents: "15900",
  categoriesJson: '[{"slug":"pets","name":"Pets"}]',
  informationSectionsJson:
    '[{"title":"Materials","body":"Ceramic body with brass ring."}]',
  meshColorConfigJson:
    '{"mesh_body":{"default":"#FFFFFF","allowed":["#FFFFFF","#111111"]}}',
};

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

describe("adminProductsUrl", () => {
  it("builds the admin product route from the configured API base URL", () => {
    expect(adminProductsUrl("http://localhost:8080/")).toBe(
      "http://localhost:8080/admin/products",
    );
  });

  it("uses same-origin API routing when no base URL is configured", () => {
    expect(adminProductsUrl("")).toBe("/admin/products");
  });
});

describe("adminProductUrl", () => {
  it("builds the admin product detail route with encoded product identity", () => {
    expect(adminProductUrl("prod_12345678", "http://localhost:8080/")).toBe(
      "http://localhost:8080/admin/products/prod_12345678",
    );
  });
});

describe("adminSourceUploadUrl", () => {
  it("builds the source upload route with encoded product identity", () => {
    expect(adminSourceUploadUrl("prod_12345678", "http://localhost:8080/")).toBe(
      "http://localhost:8080/admin/products/prod_12345678/source-glb",
    );
  });
});

describe("buildProductDraft", () => {
  it("builds the v1 product draft body from form values", () => {
    expect(buildProductDraft(validFormValues)).toEqual({
      name: "Matte ceramic pet tag",
      slug: "matte-ceramic-pet-tag",
      description: "Configurable tag with processed 3D assets.",
      price: {
        amountCents: 12900,
        currency: "USD",
        compareAtAmountCents: 15900,
      },
      categories: [{ slug: "pets", name: "Pets" }],
      informationSections: [
        { title: "Materials", body: "Ceramic body with brass ring." },
      ],
      meshColorConfig: {
        mesh_body: {
          default: "#FFFFFF",
          allowed: ["#FFFFFF", "#111111"],
        },
      },
    });
  });

  it("rejects invalid slug and malformed JSON before submit", () => {
    expect(() =>
      buildProductDraft({ ...validFormValues, slug: "Bad Slug" }),
    ).toThrow("Slug must use lowercase letters");

    expect(() =>
      buildProductDraft({ ...validFormValues, categoriesJson: "{}" }),
    ).toThrow("categories must be a JSON array");
  });
});

describe("productRecordToFormValues", () => {
  it("hydrates the product draft form from a product record", () => {
    expect(productRecordToFormValues(product)).toEqual({
      name: "Matte ceramic pet tag",
      slug: "matte-ceramic-pet-tag",
      description: "Configurable tag with processed 3D assets.",
      amountCents: "12900",
      currency: "USD",
      compareAtAmountCents: "15900",
      categoriesJson: '[{"slug":"pets","name":"Pets"}]',
      informationSectionsJson:
        '[{"title":"Materials","body":"Ceramic body with brass ring."}]',
      meshColorConfigJson:
        '{"mesh_body":{"default":"#FFFFFF","allowed":["#FFFFFF","#111111"]}}',
    });
  });
});

describe("createAdminProduct", () => {
  it("posts the product draft to the admin create route", async () => {
    const draft = buildProductDraft(validFormValues);
    const fetchMock = vi.fn(async () => {
      return new Response(JSON.stringify(product), {
        status: 201,
        headers: { "Content-Type": "application/json" },
      });
    });
    vi.stubGlobal("fetch", fetchMock);

    await expect(createAdminProduct(draft, "http://localhost:8080/")).resolves.toEqual(
      product,
    );

    expect(fetchMock).toHaveBeenCalledWith(
      "http://localhost:8080/admin/products",
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify(draft),
      }),
    );
    const [, requestInit] = fetchMock.mock.calls[0] as unknown as [
      string,
      RequestInit,
    ];
    expect(requestInit).toMatchObject({
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
      },
    });
  });
});

describe("updateAdminProduct", () => {
  it("puts the product draft to the admin update route", async () => {
    const draft = buildProductDraft(validFormValues);
    const fetchMock = vi.fn(async () => {
      return new Response(JSON.stringify(product), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    });
    vi.stubGlobal("fetch", fetchMock);

    await expect(
      updateAdminProduct(product.id, draft, "http://localhost:8080/"),
    ).resolves.toEqual(product);

    expect(fetchMock).toHaveBeenCalledWith(
      "http://localhost:8080/admin/products/prod_12345678",
      expect.objectContaining({
        method: "PUT",
        body: JSON.stringify(draft),
      }),
    );
    const [, requestInit] = fetchMock.mock.calls[0] as unknown as [
      string,
      RequestInit,
    ];
    expect(requestInit).toMatchObject({
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
      },
    });
  });
});

describe("uploadProductSource", () => {
  it("posts a multipart source file to the product source route", async () => {
    const sourceFile = new File(["glTF"], "source.glb", {
      type: "model/gltf-binary",
    });
    const fetchMock = vi.fn(async () => {
      return new Response(
        JSON.stringify({ ...product, processingStatus: "queued" }),
        {
          status: 200,
          headers: { "Content-Type": "application/json" },
        },
      );
    });
    vi.stubGlobal("fetch", fetchMock);

    await expect(
      uploadProductSource(product.id, sourceFile, "http://localhost:8080/"),
    ).resolves.toMatchObject({ processingStatus: "queued" });

    expect(fetchMock).toHaveBeenCalledWith(
      "http://localhost:8080/admin/products/prod_12345678/source-glb",
      expect.objectContaining({
        method: "POST",
      }),
    );
    const [, requestInit] = fetchMock.mock.calls[0] as unknown as [
      string,
      RequestInit,
    ];
    expect(requestInit.headers).toEqual({ Accept: "application/json" });
    expect(requestInit.body).toBeInstanceOf(FormData);
    expect((requestInit.body as FormData).get("source")).toBe(sourceFile);
  });
});

describe("validateSourceUpload", () => {
  it("accepts non-empty GLB files for products with mesh color config", () => {
    const sourceFile = new File(["glTF"], "source.glb");

    expect(() => validateSourceUpload(product, sourceFile)).not.toThrow();
  });

  it("rejects missing files, non-GLB files, and records without mesh config", () => {
    expect(() => validateSourceUpload(product, null)).toThrow(
      "Choose a .glb file",
    );
    expect(() =>
      validateSourceUpload(product, new File(["text"], "source.txt")),
    ).toThrow("must use a .glb file");
    expect(() =>
      validateSourceUpload(
        { ...product, meshColorConfig: undefined },
        new File(["glTF"], "source.glb"),
      ),
    ).toThrow("Mesh color config is required");
  });
});

describe("formatPrice", () => {
  it("formats integer-cent display pricing", () => {
    expect(formatPrice(product.price)).toBe("$129.00");
  });
});

describe("ProductListPage", () => {
  it("renders the loading state", () => {
    const markup = renderToStaticMarkup(
      <ProductListPage state={{ status: "loading" }} onRetry={() => undefined} />,
    );

    expect(markup).toContain("Loading products");
    expect(markup).toContain("Product records");
  });

  it("renders an empty state", () => {
    const markup = renderToStaticMarkup(
      <ProductListPage
        state={{ status: "ready", products: [] }}
        onRetry={() => undefined}
      />,
    );

    expect(markup).toContain("No products yet");
    expect(markup).toContain("0");
  });

  it("renders an error state with retry affordance", () => {
    const markup = renderToStaticMarkup(
      <ProductListPage
        state={{ status: "error", message: "Product list request failed" }}
        onRetry={() => undefined}
      />,
    );

    expect(markup).toContain("Product list unavailable");
    expect(markup).toContain("Retry");
  });

  it("renders product rows from v1 product records", () => {
    const markup = renderToStaticMarkup(
      <ProductListPage
        state={{ status: "ready", products: [product] }}
        onRetry={() => undefined}
      />,
    );

    expect(markup).toContain("Matte ceramic pet tag");
    expect(markup).toContain("matte-ceramic-pet-tag");
    expect(markup).toContain("prod_12345678");
    expect(markup).toContain("$129.00");
    expect(markup).toContain("Completed");
    expect(markup).toContain("Pets");
    expect(markup).toContain("Edit");
  });

  it("renders the selected product edit workflow", () => {
    const markup = renderToStaticMarkup(
      <ProductListPage
        state={{ status: "ready", products: [product] }}
        selectedProductId={product.id}
        editState={{ status: "idle" }}
        sourceUploadState={{ status: "idle" }}
        onRetry={() => undefined}
      />,
    );

    expect(markup).toContain("Edit product");
    expect(markup).toContain("Save changes");
    expect(markup).toContain("Upload GLB");
    expect(markup).toContain("matte-ceramic-pet-tag");
  });
});

describe("ProductCreatePanel", () => {
  it("renders the create form", () => {
    const markup = renderToStaticMarkup(
      <ProductCreatePanel
        createState={{ status: "idle" }}
        onCreate={() => undefined}
      />,
    );

    expect(markup).toContain("New product draft");
    expect(markup).toContain("Categories JSON");
    expect(markup).toContain("Create product");
  });

  it("renders submitting and success states", () => {
    const submittingMarkup = renderToStaticMarkup(
      <ProductCreatePanel
        createState={{ status: "submitting" }}
        onCreate={() => undefined}
      />,
    );
    const successMarkup = renderToStaticMarkup(
      <ProductCreatePanel
        createState={{ status: "success", productName: product.name }}
        onCreate={() => undefined}
      />,
    );

    expect(submittingMarkup).toContain("Saving draft");
    expect(submittingMarkup).toContain("Saving");
    expect(successMarkup).toContain("Created Matte ceramic pet tag.");
  });

  it("renders create failure inline", () => {
    const markup = renderToStaticMarkup(
      <ProductCreatePanel
        createState={{
          status: "error",
          message: "Product create request failed with HTTP 400",
        }}
        onCreate={() => undefined}
      />,
    );

    expect(markup).toContain("Product create request failed with HTTP 400");
  });
});

describe("ProductEditPanel", () => {
  it("renders success and failure states inline", () => {
    const successMarkup = renderToStaticMarkup(
      <ProductEditPanel
        product={product}
        editState={{ status: "success", productName: product.name }}
        sourceUploadState={{ status: "idle" }}
        onCancel={() => undefined}
        onUpdate={() => undefined}
        onUploadSource={() => undefined}
      />,
    );
    const errorMarkup = renderToStaticMarkup(
      <ProductEditPanel
        product={product}
        editState={{
          status: "error",
          message: "Product update request failed with HTTP 400",
        }}
        sourceUploadState={{ status: "idle" }}
        onCancel={() => undefined}
        onUpdate={() => undefined}
        onUploadSource={() => undefined}
      />,
    );

    expect(successMarkup).toContain("Updated Matte ceramic pet tag.");
    expect(errorMarkup).toContain("Product update request failed with HTTP 400");
  });
});

describe("ProductSourceUploadPanel", () => {
  it("renders source asset summary and the upload control", () => {
    const markup = renderToStaticMarkup(
      <ProductSourceUploadPanel
        product={product}
        sourceUploadState={{ status: "idle" }}
        onUploadSource={() => undefined}
      />,
    );

    expect(markup).toContain("3D intake");
    expect(markup).toContain("Upload GLB");
    expect(markup).toContain("products/prod_12345678/source.glb");
    expect(markup).toContain("Completed");
  });

  it("renders upload progress, success, and failure states inline", () => {
    const submittingMarkup = renderToStaticMarkup(
      <ProductSourceUploadPanel
        product={product}
        sourceUploadState={{ status: "submitting", productId: product.id }}
        onUploadSource={() => undefined}
      />,
    );
    const successMarkup = renderToStaticMarkup(
      <ProductSourceUploadPanel
        product={product}
        sourceUploadState={{ status: "success", productName: product.name }}
        onUploadSource={() => undefined}
      />,
    );
    const errorMarkup = renderToStaticMarkup(
      <ProductSourceUploadPanel
        product={product}
        sourceUploadState={{
          status: "error",
          message: "Source upload request failed with HTTP 400",
        }}
        onUploadSource={() => undefined}
      />,
    );

    expect(submittingMarkup).toContain("Uploading");
    expect(successMarkup).toContain("Uploaded GLB for Matte ceramic pet tag.");
    expect(errorMarkup).toContain("Source upload request failed with HTTP 400");
  });
});
