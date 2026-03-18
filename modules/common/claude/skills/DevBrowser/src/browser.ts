/**
 * Browser management using Playwright with persistent context
 */

import { homedir } from "os";
import { join } from "path";
import { type BrowserContext, chromium, type Page } from "playwright";

/**
 * Manages a persistent Playwright browser instance
 */
export class BrowserManager {
  private context: BrowserContext | null = null;
  private page: Page | null = null;
  private sessionId: string;

  constructor(sessionId: string) {
    this.sessionId = sessionId;
  }

  /**
   * Launch a persistent browser context
   */
  async launch(): Promise<void> {
    const userDataDir = join(
      homedir(),
      ".cache",
      "dev-browser",
      this.sessionId
    );

    console.log(`Launching browser with userDataDir: ${userDataDir}`);

    this.context = await chromium.launchPersistentContext(userDataDir, {
      headless: true,
      executablePath: process.env.CHROMIUM_PATH,
      args: ["--no-sandbox", "--disable-setuid-sandbox"],
    });

    // Get the first page or create a new one
    this.page = this.context.pages()[0] || (await this.context.newPage());

    // Handle page crashes
    this.page.on("crash", () => {
      console.error("Page crashed, will restart on next command");
      this.page = null;
    });
  }

  /**
   * Navigate to a URL and return page information
   */
  async navigate(url: string): Promise<{ url: string; title: string }> {
    const page = await this.ensurePage();
    await page.goto(url, { waitUntil: "domcontentloaded" });
    return { url: page.url(), title: await page.title() };
  }

  /**
   * Click an element by selector
   */
  async click(selector: string): Promise<void> {
    const page = await this.ensurePage();
    await page.click(selector);
  }

  /**
   * Type text into an element
   */
  async type(selector: string, text: string): Promise<void> {
    const page = await this.ensurePage();
    await page.fill(selector, text);
  }

  /**
   * Evaluate JavaScript in the page
   */
  async evaluate(script: string): Promise<unknown> {
    const page = await this.ensurePage();
    return page.evaluate(script);
  }

  /**
   * Wait for a selector to appear
   */
  async waitForSelector(selector: string, timeout = 30000): Promise<void> {
    const page = await this.ensurePage();
    await page.waitForSelector(selector, { timeout });
  }

  /**
   * Take a screenshot of the current page
   */
  async screenshot(path?: string): Promise<{ data?: string; path?: string }> {
    const page = await this.ensurePage();

    if (path) {
      // Save to file
      await page.screenshot({ path, fullPage: false });
      return { path };
    } else {
      // Return base64
      const buffer = await page.screenshot({ fullPage: false });
      return { data: buffer.toString("base64") };
    }
  }

  /**
   * Get the current page URL
   */
  getCurrentUrl(): string | null {
    return this.page?.url() || null;
  }

  /**
   * Get the current page instance
   */
  getPage(): Page {
    if (!this.page) {
      throw new Error("Browser page not initialized");
    }
    return this.page;
  }

  /**
   * Close the browser context
   */
  async close(): Promise<void> {
    if (this.context) {
      await this.context.close();
      this.context = null;
      this.page = null;
    }
  }

  /**
   * Ensure page is ready, restart if crashed
   */
  private async ensurePage(): Promise<Page> {
    if (!this.page) {
      if (!this.context) {
        throw new Error("Browser not initialized");
      }
      console.log("Page was crashed, creating new page");
      this.page = await this.context.newPage();
    }
    return this.page;
  }
}
