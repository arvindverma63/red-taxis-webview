import { Component, OnInit, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute } from '@angular/router';
import { DriverService } from '../services/driver.service';
import { Subscription, interval } from 'rxjs';
import { takeWhile } from 'rxjs/operators';

interface JobDetails {
  id: string;
  fare: number;
  pickup: string;
  dropoff: string;
  paymentType: string;
}

@Component({
  selector: 'app-job-offer',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="dark-container">
      <!-- Muted Header Tag -->
      <div class="offer-header">
        <span class="header-tag">NEW BOOKING OFFER</span>
        <div class="divider-line"></div>
      </div>

      <!-- Circular Timer and Progress -->
      <div class="timer-section">
        <div class="circle-timer">
          <svg class="progress-ring" width="100" height="100">
            <circle
              class="progress-ring-circle"
              stroke="#D32F2F"
              stroke-width="5"
              fill="transparent"
              r="44"
              cx="50"
              cy="50"
              [style.strokeDashoffset]="strokeDashoffset"
            />
          </svg>
          <div class="timer-text-container">
            <span class="seconds-num">{{ secondsRemaining }}</span>
            <span class="seconds-lbl">SEC</span>
          </div>
        </div>
      </div>

      <!-- Main Clean Details Box -->
      <div class="details-card" *ngIf="job">
        <div class="fare-header">
          <span class="fare-label">ESTIMATED FARE</span>
          <span class="fare-val">£{{ job.fare.toFixed(2) }}</span>
        </div>

        <div class="badge-row">
          <span class="payment-badge" [ngClass]="job.paymentType.toLowerCase()">
            {{ job.paymentType }}
          </span>
        </div>

        <div class="route-section">
          <div class="route-timeline">
            <div class="timeline-line"></div>
            <div class="timeline-dot green"></div>
            <div class="timeline-dot red"></div>
          </div>
          
          <div class="route-addresses">
            <div class="address-node">
              <span class="addr-label">PICKUP</span>
              <span class="addr-text">{{ job.pickup }}</span>
            </div>
            <div class="address-node">
              <span class="addr-label">DROPOFF</span>
              <span class="addr-text">{{ job.dropoff }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Action Buttons -->
      <div class="action-footer">
        <button class="accept-btn" (click)="accept()">
          ACCEPT OFFER
        </button>
        <button class="decline-btn" (click)="decline()">
          Decline Job
        </button>
      </div>
    </div>
  `,
  styles: [`
    .dark-container {
      background-color: #0E0F12;
      color: #FFFFFF;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      padding: 32px 24px;
      font-family: 'Roboto', sans-serif;
      box-sizing: border-box;
    }

    .offer-header {
      text-align: center;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 12px;
    }

    .header-tag {
      font-size: 11px;
      font-weight: 700;
      color: #90A4AE;
      letter-spacing: 2px;
    }

    .divider-line {
      width: 40px;
      height: 2px;
      background-color: #D32F2F;
      border-radius: 1px;
    }

    /* Timer styles */
    .timer-section {
      display: flex;
      justify-content: center;
      margin: 20px 0;
    }

    .circle-timer {
      position: relative;
      width: 100px;
      height: 100px;
      display: flex;
      justify-content: center;
      align-items: center;
    }

    .progress-ring {
      position: absolute;
      top: 0;
      left: 0;
      transform: rotate(-90deg);
    }

    .progress-ring-circle {
      stroke-dasharray: 276.46; /* 2 * PI * r (r=44) */
      transition: stroke-dashoffset 0.1s linear;
    }

    .timer-text-container {
      display: flex;
      flex-direction: column;
      align-items: center;
    }

    .seconds-num {
      font-size: 32px;
      font-weight: 900;
      line-height: 1;
      color: #FFFFFF;
    }

    .seconds-lbl {
      font-size: 9px;
      font-weight: 700;
      color: #78909C;
      letter-spacing: 0.5px;
      margin-top: 2px;
    }

    /* Card Layout */
    .details-card {
      background-color: #16181E;
      border-radius: 20px;
      border: 1px solid #242831;
      padding: 24px;
      display: flex;
      flex-direction: column;
      gap: 18px;
    }

    .fare-header {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 4px;
    }

    .fare-label {
      font-size: 10px;
      font-weight: 700;
      color: #78909C;
      letter-spacing: 1px;
    }

    .fare-val {
      font-size: 40px;
      font-weight: 900;
      color: #4CAF50;
    }

    .badge-row {
      display: flex;
      justify-content: center;
    }

    .payment-badge {
      font-size: 10px;
      font-weight: 800;
      padding: 4px 12px;
      border-radius: 20px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    .payment-badge.cash {
      background-color: rgba(76, 175, 80, 0.12);
      color: #4CAF50;
      border: 1px solid rgba(76, 175, 80, 0.25);
    }

    .payment-badge.card,
    .payment-badge.account {
      background-color: rgba(33, 150, 243, 0.12);
      color: #2196F3;
      border: 1px solid rgba(33, 150, 243, 0.25);
    }

    /* Route Timeline */
    .route-section {
      display: flex;
      gap: 16px;
      margin-top: 6px;
    }

    .route-timeline {
      position: relative;
      display: flex;
      flex-direction: column;
      align-items: center;
      width: 12px;
    }

    .timeline-line {
      position: absolute;
      top: 6px;
      bottom: 6px;
      width: 2px;
      background-color: #2D323E;
    }

    .timeline-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      z-index: 2;
    }

    .timeline-dot.green {
      background-color: #4CAF50;
      margin-top: 4px;
    }

    .timeline-dot.red {
      background-color: #F44336;
      margin-top: auto;
      margin-bottom: 4px;
    }

    .route-addresses {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 20px;
    }

    .address-node {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    .addr-label {
      font-size: 8px;
      font-weight: 700;
      color: #78909C;
      letter-spacing: 0.5px;
    }

    .addr-text {
      font-size: 14px;
      font-weight: 700;
      color: #ECEFF1;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: normal;
      line-height: 1.4;
    }

    /* Action Buttons */
    .action-footer {
      display: flex;
      flex-direction: column;
      gap: 12px;
      align-items: center;
    }

    .accept-btn {
      width: 100%;
      background-color: #2E7D32;
      color: #FFFFFF;
      font-weight: 700;
      font-size: 16px;
      padding: 16px;
      border: none;
      border-radius: 16px;
      cursor: pointer;
      box-shadow: 0 4px 12px rgba(46, 125, 50, 0.2);
      transition: all 0.2s ease;
    }

    .accept-btn:active {
      transform: scale(0.98);
      background-color: #1B5E20;
    }

    .decline-btn {
      background: none;
      border: none;
      color: #B0BEC5;
      font-size: 14px;
      font-weight: 600;
      cursor: pointer;
      padding: 8px 16px;
      text-decoration: none;
    }

    .decline-btn:active {
      color: #F44336;
    }
  `]
})
export class JobOfferComponent implements OnInit, OnDestroy {
  secondsRemaining = 15;
  strokeDasharray = 276.46; // 2 * PI * 44
  job: JobDetails | null = null;
  
  private timerSub: Subscription | null = null;

  constructor(
    private route: ActivatedRoute,
    private driverService: DriverService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    // Attempt to parse query parameters from the URL
    this.route.queryParams.subscribe(params => {
      const id = params['jobId'];
      const fareVal = parseFloat(params['fare']);
      const pickup = params['pickup'];
      const dropoff = params['dropoff'];
      const paymentType = params['paymentType'];

      if (id && !isNaN(fareVal) && pickup && dropoff) {
        this.job = {
          id: id.toString(),
          fare: fareVal,
          pickup: decodeURIComponent(pickup),
          dropoff: decodeURIComponent(dropoff),
          paymentType: paymentType || 'Cash'
        };
        this.cdr.detectChanges();
      } else {
        // Fallback: Fetch active job offers from the API
        this.fetchJobFromApi();
      }
    });

    this.startTimer();
  }

  fetchJobFromApi(): void {
    this.driverService.getJobOffers().subscribe(offers => {
      const data = offers?.value || offers || [];
      if (Array.isArray(data) && data.length > 0) {
        const item = data[0];
        this.job = {
          id: (item.bookingNo || item.id || '').toString(),
          fare: parseFloat(item.fare || item.amount || item.price || '0.00'),
          pickup: item.pickupAddress || item.pickup || 'Unknown Pickup',
          dropoff: item.destinationAddress || item.dropoff || item.dropoffAddress || 'Unknown Dropoff',
          paymentType: item.paymentType || item.paymentMethod || 'Cash'
        };
        this.cdr.detectChanges();
      } else {
        // Mock fallback if offline/no connection
        this.job = {
          id: 'sim-cash-booking',
          fare: 45.00,
          pickup: 'Heathrow Airport Terminal 5',
          dropoff: 'Red Taxi Office, London Central',
          paymentType: 'Cash'
        };
        this.cdr.detectChanges();
      }
    });
  }

  startTimer(): void {
    this.timerSub = interval(1000)
      .pipe(takeWhile(() => this.secondsRemaining > 0))
      .subscribe({
        next: () => {
          this.secondsRemaining--;
          this.cdr.detectChanges();
          if (this.secondsRemaining === 0) {
            this.autoReject();
          }
        }
      });
  }

  get strokeDashoffset(): number {
    return this.strokeDasharray * (1 - this.secondsRemaining / 15);
  }

  accept(): void {
    this.timerSub?.unsubscribe();
    if (this.job && !this.job.id.startsWith('sim-')) {
      this.driverService.replyJobOffer(parseInt(this.job.id) || 0, 2000).subscribe(() => {
        this.notifyNativeApp('job_accepted');
      });
    } else {
      this.notifyNativeApp('job_accepted');
    }
  }

  decline(): void {
    this.timerSub?.unsubscribe();
    if (this.job && !this.job.id.startsWith('sim-')) {
      this.driverService.replyJobOffer(parseInt(this.job.id) || 0, 2001).subscribe(() => {
        this.notifyNativeApp('job_rejected');
      });
    } else {
      this.notifyNativeApp('job_rejected');
    }
  }

  private autoReject(): void {
    if (this.job && !this.job.id.startsWith('sim-')) {
      this.driverService.replyJobOffer(parseInt(this.job.id) || 0, 2001).subscribe(() => {
        this.notifyNativeApp('job_rejected');
      });
    } else {
      this.notifyNativeApp('job_rejected');
    }
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

  ngOnDestroy(): void {
    this.timerSub?.unsubscribe();
  }
}
