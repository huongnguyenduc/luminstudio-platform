import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import {
  ProductListPage,
  adminProductsUrl,
  formatPrice,
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
