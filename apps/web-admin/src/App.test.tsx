import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, describe, expect, it, vi } from "vitest";

import {
  ProductCreatePanel,
  ProductListPage,
  adminProductsUrl,
  buildProductDraft,
  createAdminProduct,
  formatPrice,
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
