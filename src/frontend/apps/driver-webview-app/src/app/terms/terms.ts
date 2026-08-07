import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-terms',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="webview-container">
      <header class="header">
        <h1>Driver Terms & Agreement</h1>
        <p>Last Updated: August 2026</p>
      </header>

      <main class="content">
        <section class="section">
          <h2>1. General Driver Code of Conduct</h2>
          <p>
            Drivers operating on the Red Taxi platform must maintain a clean, well-serviced vehicle, possess a valid taxi driver license, and treat all passengers with respect.
          </p>
        </section>

        <section class="section">
          <h2>2. Shift and Location Tracking</h2>
          <p>
            While on shift (marked "Online"), the application collects and transmits high-accuracy GPS coordinates to the dispatch server. This tracking is mandatory for job allocations and customer live-tracking views.
          </p>
        </section>

        <section class="section">
          <h2>3. Fares, Payments & Commission</h2>
          <p>
            Fares are dynamically calculated by the Red Taxi pricing engine based on mileage, zone tariffs, and timing. 
            For cash bookings, the driver collects payment directly from the passenger. Commission is calculated based on the tenant's specified rate and is invoiced weekly.
          </p>
        </section>

        <section class="section">
          <h2>4. Cancellation Policies</h2>
          <p>
            Accepting a booking represents a commitment. Repeatedly rejecting or cancelling jobs after allocation can result in warning blocks or temporary suspension from the dispatch queue.
          </p>
        </section>
      </main>
    </div>
  `,
  styles: [`
    .webview-container {
      padding: 16px;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    }
    .header {
      margin-bottom: 24px;
      border-bottom: 1px solid var(--border-color);
      padding-bottom: 12px;
    }
    .header h1 {
      font-size: 24px;
      margin: 0 0 6px 0;
      color: var(--text-primary);
    }
    .header p {
      font-size: 12px;
      margin: 0;
      color: var(--text-secondary);
    }
    .content {
      display: flex;
      flex-direction: column;
      gap: 20px;
    }
    .section h2 {
      font-size: 16px;
      margin: 0 0 8px 0;
      font-weight: 600;
      color: var(--text-primary);
    }
    .section p {
      font-size: 14px;
      line-height: 1.6;
      margin: 0;
      color: var(--text-secondary);
    }
  `]
})
export class TermsComponent {}
