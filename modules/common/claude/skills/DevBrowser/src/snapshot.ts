/**
 * AI-optimized DOM snapshot generation using Playwright accessibility tree
 */

import type { Page } from "playwright";

interface AccessibilityNode {
  role: string;
  name?: string;
  value?: string;
  description?: string;
  keyshortcuts?: string;
  roledescription?: string;
  valuetext?: string;
  disabled?: boolean;
  expanded?: boolean;
  focused?: boolean;
  modal?: boolean;
  multiline?: boolean;
  multiselectable?: boolean;
  readonly?: boolean;
  required?: boolean;
  selected?: boolean;
  checked?: boolean | "mixed";
  pressed?: boolean | "mixed";
  level?: number;
  valuemin?: number;
  valuemax?: number;
  autocomplete?: string;
  haspopup?: string;
  invalid?: string;
  orientation?: string;
  children?: AccessibilityNode[];
}

interface Element {
  locator: string;
  role: string;
  name?: string;
  value?: string;
  children?: Element[];
}

interface SnapshotResult {
  url: string;
  title: string;
  snapshot: string;
  locators: Record<string, string>;
}

/**
 * Interactive roles that should receive locator IDs
 */
const interactiveRoles = new Set([
  "button",
  "link",
  "textbox",
  "checkbox",
  "radio",
  "combobox",
  "listbox",
  "menuitem",
  "tab",
  "slider",
  "spinbutton",
  "searchbox",
  "switch",
  "menuitemcheckbox",
  "menuitemradio",
  "option",
  "treeitem",
  "gridcell",
  "rowheader",
  "columnheader",
]);

/**
 * Generate an AI-optimized snapshot of the current page
 *
 * Uses Playwright's accessibility tree to create a token-efficient
 * representation with semantic locators for interactive elements.
 */
export async function generateSnapshot(page: Page): Promise<SnapshotResult> {
  const url = page.url();
  const title = await page.title();
  const tree = await (page as unknown as { accessibility: { snapshot(): Promise<AccessibilityNode | null> } }).accessibility.snapshot();

  if (!tree) {
    return {
      url,
      title,
      snapshot: "",
      locators: {},
    };
  }

  let locatorCounter = 0;
  const locatorMap = new Map<string, string>();

  /**
   * Process accessibility tree node and assign locators to interactive elements
   */
  function processNode(node: AccessibilityNode): Element | null {
    // Skip empty nodes
    if (
      !node.name &&
      !node.value &&
      (!node.children || node.children.length === 0)
    ) {
      return null;
    }

    const element: Element = {
      locator: "",
      role: node.role,
    };

    // Assign locator to interactive elements
    if (interactiveRoles.has(node.role)) {
      locatorCounter++;
      element.locator = `@e${String(locatorCounter)}`;
      locatorMap.set(element.locator, node.name || node.role);
    }

    if (node.name) element.name = node.name;
    if (node.value) element.value = node.value;

    if (node.children) {
      const children = node.children
        .map(processNode)
        .filter((c): c is Element => c !== null);
      if (children.length > 0) {
        element.children = children;
      }
    }

    return element;
  }

  const processed = processNode(tree);

  /**
   * Convert element tree to YAML-like format
   */
  function toYaml(el: Element, indent = 0): string {
    const pad = "  ".repeat(indent);
    let line = `${pad}- ${el.role}`;
    if (el.locator) line += ` ${el.locator}`;
    if (el.name) line += ` "${el.name}"`;
    if (el.value) line += ` [value="${el.value}"]`;
    line += "\n";

    if (el.children) {
      for (const child of el.children) {
        line += toYaml(child, indent + 1);
      }
    }
    return line;
  }

  const yamlTree = processed ? toYaml(processed) : "";

  return {
    url,
    title,
    snapshot: yamlTree,
    locators: Object.fromEntries(locatorMap),
  };
}
