import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute } from '@angular/router';

interface JobDetails {
  id: string;
  fare: number;
  pickup: string;
  dropoff: string;
  paymentType: string;
}

@Component({
  selector: 'app-trip-complete',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="light-container">
      <!-- Ambient map backdrop overlay -->
      
      <!-- Content Container -->
      <div class="complete-sheet" *ngIf="job">
        <!-- Success State Icons -->
        <div class="success-header">
          <div class="check-circle">
            <span class="check-mark">✓</span>
          </div>
          <h1 class="complete-title">Trip Complete</h1>
          <p class="complete-subtitle">Successfully completed trip routing</p>
        </div>

        <!-- Breakdown Details Box -->
        <div class="details-card">
          <span class="breakdown-lbl">FARE BREAKDOWN</span>
          <span class="breakdown-val">£{{ job.fare.toFixed(2) }}</span>
          <span class="method-val">Payment Method: {{ job.paymentType }}</span>
          
          <div class="divider-line"></div>

          <!-- Cash Collection Banner -->
          <div class="collection-banner cash" *ngIf="isCash">
            <div class="banner-title-row">
              <span class="banner-icon">💵</span>
              <span class="banner-title">CASH COLLECTION REQUIRED</span>
            </div>
            <p class="banner-desc">
              Please collect £{{ job.fare.toFixed(2) }} directly from the passenger.
            </p>
          </div>

          <!-- Card/Account Banner -->
          <div class="collection-banner card" *ngIf="!isCash">
            <div class="banner-title-row">
              <span class="banner-icon">💳</span>
              <span class="banner-title">CARD/ACCOUNT BOOKING</span>
            </div>
            <p class="banner-desc">
              Payment is handled via Card/Account. Do NOT collect cash from the customer.
            </p>
          </div>
        </div>

        <!-- Action Button -->
        <div class="action-footer">
          <button class="return-btn" (click)="returnToDashboard()">
            Return to Dashboard
          </button>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .light-container {
      position: relative;
      background: #ECEFF1 url('/map_bg.png') no-repeat center center;
      background-size: cover;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      justify-content: flex-end; /* Aligns content to the bottom */
      font-family: 'Roboto', sans-serif;
      box-sizing: border-box;
      overflow: hidden;
    }

    /* Ambient glassmorphism overlay */
    .light-container::before {
      content: '';
      position: absolute;
      top: 0; left: 0; right: 0; bottom: 0;
      background-color: rgba(240, 244, 248, 0.4);
      backdrop-filter: blur(2px);
      z-index: 1;
    }

    /* Complete Page Panel Sheet */
    .complete-sheet {
      position: relative;
      z-index: 2;
      background-color: #FFFFFF;
      border-radius: 28px 28px 0 0;
      box-shadow: 0 -12px 36px rgba(0,0,0,0.12);
      padding: 24px 20px 64px 20px; /* Safe padding for system nav */
      display: flex;
      flex-direction: column;
      gap: 20px;
      animation: slideUp 0.35s cubic-bezier(0.16, 1, 0.3, 1);
    }

    @keyframes slideUp {
      from { transform: translateY(100%); }
      to { transform: translateY(0); }
    }

    /* Success Header components */
    .success-header {
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
      margin-top: 10px;
    }

    .check-circle {
      width: 76px;
      height: 76px;
      background-color: rgba(76, 175, 80, 0.1);
      border-radius: 50%;
      display: flex;
      justify-content: center;
      align-items: center;
      margin-bottom: 16px;
    }

    .check-mark {
      font-size: 40px;
      font-weight: bold;
      color: #2E7D32;
    }

    .complete-title {
      margin: 0 0 6px 0;
      font-size: 24px;
      font-weight: 900;
      color: #263238;
    }

    .complete-subtitle {
      margin: 0;
      font-size: 13px;
      color: #78909C;
    }

    /* Details card style */
    .details-card {
      background-color: #FFFFFF;
      border-radius: 20px;
      border: 1px solid #ECEFF1;
      padding: 20px;
      display: flex;
      flex-direction: column;
      align-items: center;
      box-sizing: border-box;
    }

    .breakdown-lbl {
      font-size: 9px;
      font-weight: 800;
      color: #90A4AE;
      letter-spacing: 1px;
      margin-bottom: 6px;
    }

    .breakdown-val {
      font-size: 38px;
      font-weight: 900;
      color: #263238;
      margin-bottom: 4px;
    }

    .method-val {
      font-size: 12px;
      color: #78909C;
      margin-bottom: 16px;
    }

    .divider-line {
      width: 100%;
      height: 1px;
      background-color: #ECEFF1;
      margin-bottom: 16px;
    }

    /* Warning/Notice banner boxes */
    .collection-banner {
      width: 100%;
      padding: 14px;
      border-radius: 12px;
      display: flex;
      flex-direction: column;
      gap: 6px;
      box-sizing: border-box;
    }

    .collection-banner.cash {
      background-color: rgba(76, 175, 80, 0.08);
      border: 1px solid rgba(76, 175, 80, 0.2);
      color: #2E7D32;
    }

    .collection-banner.card {
      background-color: rgba(33, 150, 243, 0.08);
      border: 1px solid rgba(33, 150, 243, 0.2);
      color: #1565C0;
    }

    .banner-title-row {
      display: flex;
      align-items: center;
      gap: 8px;
      font-weight: 900;
      font-size: 12px;
    }

    .banner-desc {
      margin: 0;
      font-size: 13px;
      line-height: 1.4;
      font-weight: 600;
    }

    .collection-banner.cash .banner-desc {
      color: #1B5E20;
    }

    .collection-banner.card .banner-desc {
      color: #0D47A1;
    }

    /* Footer Button code */
    .action-footer {
      width: 100%;
    }

    .return-btn {
      width: 100%;
      background-color: #D32F2F;
      color: #FFFFFF;
      font-weight: 800;
      font-size: 16px;
      padding: 14px;
      border: none;
      border-radius: 14px;
      cursor: pointer;
      box-shadow: 0 4px 12px rgba(211, 47, 47, 0.25);
      transition: all 0.2s ease;
      letter-spacing: 0.5px;
      margin-bottom: 24px; /* Space from virtual bottom bar */
    }

    .return-btn:active {
      background-color: #B71C1C;
    }
  `]
})
export class TripCompleteComponent implements OnInit {
  job: JobDetails | null = null;

  constructor(
    private route: ActivatedRoute,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.route.queryParams.subscribe(params => {
      const id = params['jobId'];
      const fareVal = parseFloat(params['fare']);
      const pickup = params['pickup'];
      const dropoff = params['dropoff'];
      const paymentType = params['paymentType'];

      if (id && !isNaN(fareVal)) {
        this.job = {
          id: id.toString(),
          fare: fareVal,
          pickup: pickup ? decodeURIComponent(pickup) : 'Unknown Pickup',
          dropoff: dropoff ? decodeURIComponent(dropoff) : 'Unknown Dropoff',
          paymentType: paymentType || 'Cash'
        };
        this.cdr.detectChanges();
      }
    });
  }

  get isCash(): boolean {
    return this.job?.paymentType.toLowerCase() === 'cash';
  }

  returnToDashboard(): void {
    this.notifyNativeApp('return_to_dashboard');
  }

  private notifyNativeApp(message: string): void {
    try {
      const channel = (window as any).FlutterChannel;
      if (channel) {
        channel.postMessage(message);
      } else {
        console.log(`Native notification bypassed (channel not active): ${message}`);
      }
    } catch (err) {
      console.error('Failed to notify native app:', err);
    }
  }
}
