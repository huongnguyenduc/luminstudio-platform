import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import { App } from "./App";

describe("App", () => {
  it("renders the Phase 1 Web Admin boundary", () => {
    const markup = renderToStaticMarkup(<App />);

    expect(markup).toContain("Admin workspace");
    expect(markup).toContain("selected Phase 2 stories");
  });
});
