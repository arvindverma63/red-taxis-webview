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
  vehicleType: string;
  passenger: string;
  notes: string;
}

@Component({
  selector: 'app-job-offer',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="light-container">
      <!-- Muted Header Tag -->
      <div class="offer-header">
        <span class="header-tag">NEW BOOKING REQUEST</span>
        <div class="divider-line"></div>
      </div>

      <!-- Circular Timer and Progress -->
      <div class="timer-section">
        <div class="circle-timer">
          <svg class="progress-ring" width="90" height="90">
            <circle
              class="progress-ring-track"
              stroke="#ECEFF1"
              stroke-width="4"
              fill="transparent"
              r="38"
              cx="45"
              cy="45"
            />
            <circle
              class="progress-ring-circle"
              stroke="#D32F2F"
              stroke-width="4"
              fill="transparent"
              r="38"
              cx="45"
              cy="45"
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
        <!-- Ticket Header -->
        <div class="ticket-header">
          <span class="fare-label">ESTIMATED FARE</span>
          <span class="fare-val">£{{ job.fare.toFixed(2) }}</span>
          
          <div class="badge-row">
            <span class="payment-badge" [ngClass]="job.paymentType.toLowerCase()">
              {{ job.paymentType }}
            </span>
            <span class="vehicle-badge">
              {{ job.vehicleType }}
            </span>
          </div>
        </div>

        <!-- Ticket Tear Separator Line -->
        <div class="ticket-stub-line">
          <div class="stub-notch left"></div>
          <div class="stub-dash"></div>
          <div class="stub-notch right"></div>
        </div>

        <!-- Ticket Body -->
        <div class="ticket-body">
          <!-- Information Grid -->
          <div class="info-grid">
            <div class="info-cell">
              <span class="info-lbl">BOOKING ID</span>
              <span class="info-val">{{ job.id }}</span>
            </div>
            <div class="info-cell">
              <span class="info-lbl">PASSENGER</span>
              <span class="info-val">{{ job.passenger }}</span>
            </div>
          </div>

          <!-- Driver Notes (Only shown if notes present) -->
          <div class="notes-box" *ngIf="job.notes && job.notes.trim().length > 0">
            <span class="info-lbl">DRIVER NOTES</span>
            <p class="notes-txt">"{{ job.notes }}"</p>
          </div>

          <div class="route-section">
            <div class="route-timeline">
              <div class="timeline-dot green">
                <div class="dot-inner"></div>
              </div>
              <div class="timeline-line"></div>
              <div class="timeline-dot red">
                <div class="dot-inner"></div>
              </div>
            </div>
            
            <div class="route-addresses">
              <div class="address-node">
                <span class="addr-label">PICKUP LOCATION</span>
                <span class="addr-text">{{ job.pickup }}</span>
              </div>
              <div class="address-node">
                <span class="addr-label">DROPOFF LOCATION</span>
                <span class="addr-text">{{ job.dropoff }}</span>
              </div>
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
          Decline Job Offer
        </button>
      </div>
    </div>
  `,
  styles: [`
    .light-container {
      background: linear-gradient(135deg, #F8F9FA 0%, #ECEFF1 100%);
      color: #37474F;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      padding: 20px 20px 48px 20px; /* Enhanced bottom padding for device navigation safe-area */
      font-family: 'Roboto', sans-serif;
      box-sizing: border-box;
    }

    .offer-header {
      text-align: center;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 6px;
    }

    .header-tag {
      font-size: 11px;
      font-weight: 800;
      color: #78909C;
      letter-spacing: 2px;
    }

    .divider-line {
      width: 40px;
      height: 3px;
      background-color: #D32F2F;
      border-radius: 2px;
    }

    /* Timer styles - scaled down for compact fit */
    .timer-section {
      display: flex;
      justify-content: center;
      margin: 6px 0;
    }

    .circle-timer {
      position: relative;
      width: 90px;
      height: 90px;
      display: flex;
      justify-content: center;
      align-items: center;
      background-color: #FFFFFF;
      border-radius: 50%;
      box-shadow: 0 4px 12px rgba(0,0,0,0.03);
    }

    .progress-ring {
      position: absolute;
      top: 0;
      left: 0;
      transform: rotate(-90deg);
    }

    .progress-ring-circle {
      stroke-dasharray: 238.76; /* 2 * PI * r (r=38) */
      transition: stroke-dashoffset 0.1s linear;
    }

    .timer-text-container {
      display: flex;
      flex-direction: column;
      align-items: center;
    }

    .seconds-num {
      font-size: 28px;
      font-weight: 900;
      line-height: 1;
      color: #263238;
    }

    .seconds-lbl {
      font-size: 8px;
      font-weight: 700;
      color: #90A4AE;
      letter-spacing: 0.5px;
      margin-top: 2px;
    }

    /* Ticket Card Layout */
    .details-card {
      background-color: #FFFFFF;
      border-radius: 20px;
      box-shadow: 0 10px 25px rgba(0,0,0,0.05);
      border: 1px solid rgba(0,0,0,0.02);
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }

    .ticket-header {
      padding: 18px 20px 14px 20px;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 6px;
    }

    .fare-label {
      font-size: 9px;
      font-weight: 800;
      color: #90A4AE;
      letter-spacing: 1px;
    }

    .fare-val {
      font-size: 38px;
      font-weight: 900;
      color: #2E7D32;
      line-height: 1.1;
    }

    .badge-row {
      display: flex;
      gap: 8px;
      margin-top: 2px;
    }

    .payment-badge, .vehicle-badge {
      font-size: 9px;
      font-weight: 800;
      padding: 4px 10px;
      border-radius: 20px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    .payment-badge.cash {
      background-color: rgba(76, 175, 80, 0.08);
      color: #2E7D32;
      border: 1px solid rgba(76, 175, 80, 0.15);
    }

    .payment-badge.card,
    .payment-badge.account {
      background-color: rgba(33, 150, 243, 0.08);
      color: #1565C0;
      border: 1px solid rgba(33, 150, 243, 0.15);
    }

    .vehicle-badge {
      background-color: #F5F7FA;
      color: #455A64;
      border: 1px solid #E4E7EB;
    }

    /* Ticket Tear line */
    .ticket-stub-line {
      display: flex;
      align-items: center;
      justify-content: space-between;
      height: 14px;
      position: relative;
    }

    .stub-notch {
      width: 14px;
      height: 14px;
      background-color: #ECEFF1;
      border-radius: 50%;
    }

    .stub-notch.left {
      margin-left: -7px;
    }

    .stub-notch.right {
      margin-right: -7px;
    }

    .stub-dash {
      flex: 1;
      border-top: 2px dashed #ECEFF1;
      margin: 0 4px;
      height: 1px;
    }

    /* Ticket Body */
    .ticket-body {
      padding: 16px 20px 20px 20px;
      display: flex;
      flex-direction: column;
      gap: 14px;
    }

    /* Info Grid */
    .info-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
      border-bottom: 1px solid #F5F7FA;
      padding-bottom: 10px;
    }

    .info-cell {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }

    .info-lbl {
      font-size: 8px;
      font-weight: 800;
      color: #90A4AE;
      letter-spacing: 0.5px;
    }

    .info-val {
      font-size: 13px;
      font-weight: 700;
      color: #37474F;
    }

    /* Notes Box */
    .notes-box {
      background-color: #FAFBFD;
      border: 1px solid #E8EFF5;
      border-radius: 10px;
      padding: 8px 12px;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    .notes-txt {
      margin: 0;
      font-size: 12px;
      font-style: italic;
      color: #546E7A;
      line-height: 1.4;
    }

    /* Route Timeline */
    .route-section {
      display: flex;
      gap: 14px;
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
      top: 12px;
      bottom: 12px;
      width: 2px;
      background-color: #CFD8DC;
    }

    .timeline-dot {
      width: 12px;
      height: 12px;
      border-radius: 50%;
      z-index: 2;
      display: flex;
      justify-content: center;
      align-items: center;
      background-color: #FFFFFF;
    }

    .timeline-dot.green {
      border: 2px solid #4CAF50;
    }

    .timeline-dot.red {
      border: 2px solid #D32F2F;
      margin-top: auto;
    }

    .dot-inner {
      width: 4px;
      height: 4px;
      border-radius: 50%;
    }

    .timeline-dot.green .dot-inner {
      background-color: #4CAF50;
    }

    .timeline-dot.red .dot-inner {
      background-color: #D32F2F;
    }

    .route-addresses {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 16px;
    }

    .address-node {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }

    .addr-label {
      font-size: 8px;
      font-weight: 800;
      color: #90A4AE;
      letter-spacing: 0.5px;
    }

    .addr-text {
      font-size: 13px;
      font-weight: 700;
      color: #37474F;
      line-height: 1.4;
    }

    /* Action Buttons */
    .action-footer {
      display: flex;
      flex-direction: column;
      gap: 8px;
      width: 100%;
      align-items: center;
    }

    .accept-btn {
      width: 100%;
      background-color: #2E7D32;
      color: #FFFFFF;
      font-weight: 800;
      font-size: 16px;
      padding: 14px;
      border: none;
      border-radius: 14px;
      cursor: pointer;
      box-shadow: 0 4px 10px rgba(46, 125, 50, 0.15);
      transition: all 0.2s ease;
      letter-spacing: 0.5px;
    }

    .accept-btn:active {
      transform: scale(0.98);
      background-color: #1B5E20;
    }

    .decline-btn {
      background-color: transparent;
      border: none;
      color: #78909C;
      font-size: 14px;
      font-weight: 700;
      cursor: pointer;
      padding: 8px 16px;
      transition: color 0.2s ease;
    }

    .decline-btn:active, .decline-btn:hover {
      color: #D32F2F;
    }
  `]
})
export class JobOfferComponent implements OnInit, OnDestroy {
  secondsRemaining = 15;
  strokeDasharray = 238.76; // 2 * PI * 38
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
      const vehicleType = params['vehicleType'];
      const passenger = params['passenger'];
      const notes = params['notes'];

      if (id && !isNaN(fareVal) && pickup && dropoff) {
        this.job = {
          id: id.toString(),
          fare: fareVal,
          pickup: decodeURIComponent(pickup),
          dropoff: decodeURIComponent(dropoff),
          paymentType: paymentType || 'Cash',
          vehicleType: vehicleType ? decodeURIComponent(vehicleType) : 'Standard Saloon',
          passenger: passenger ? decodeURIComponent(passenger) : 'Passenger',
          notes: notes ? decodeURIComponent(notes) : ''
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
          paymentType: item.paymentType || item.paymentMethod || 'Cash',
          vehicleType: item.vehicleType || 'Standard Saloon',
          passenger: item.passengerName || item.passenger || 'Passenger',
          notes: item.notes || item.comment || ''
        };
        this.cdr.detectChanges();
      } else {
        // Mock fallback if offline/no connection
        this.job = {
          id: 'sim-cash-booking',
          fare: 45.00,
          pickup: 'Heathrow Airport Terminal 5',
          dropoff: 'Red Taxi Office, London Central',
          paymentType: 'Cash',
          vehicleType: 'Standard Saloon',
          passenger: 'James Smith',
          notes: 'Flight BA441 arrived early. Meet at Costa Coffee.'
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
