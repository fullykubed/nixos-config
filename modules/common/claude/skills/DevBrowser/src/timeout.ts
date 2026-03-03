/**
 * IdleTimeout - Monitors inactivity and triggers a callback after a specified timeout period
 */
export class IdleTimeout {
  private lastActivity: number = Date.now();
  private intervalId: ReturnType<typeof setInterval> | null = null;
  private timeoutMs: number;
  private onTimeout: () => void;

  constructor(timeoutMs: number, onTimeout: () => void) {
    this.timeoutMs = timeoutMs;
    this.onTimeout = onTimeout;
  }

  /**
   * Update the last activity timestamp to the current time
   */
  touch(): void {
    this.lastActivity = Date.now();
  }

  /**
   * Start monitoring for idle timeout
   * Checks every minute if the elapsed time exceeds the timeout threshold
   */
  start(): void {
    // Check at reasonable intervals: every minute for long timeouts, more frequently for short ones
    const checkInterval = Math.min(60000, Math.max(1000, Math.floor(this.timeoutMs / 5)));
    this.intervalId = setInterval(() => {
      const elapsed = Date.now() - this.lastActivity;
      if (elapsed >= this.timeoutMs) {
        console.log(`Idle timeout reached (${this.timeoutMs}ms), shutting down`);
        this.stop();
        this.onTimeout();
      }
    }, checkInterval);
  }

  /**
   * Stop monitoring for idle timeout and clear the interval
   */
  stop(): void {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
  }
}
