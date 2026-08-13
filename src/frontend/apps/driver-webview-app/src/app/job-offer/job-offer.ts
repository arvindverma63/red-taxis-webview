import { Component, OnInit, OnDestroy, ChangeDetectorRef, ViewChild, ElementRef } from '@angular/core';
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
      <!-- Ambient map backdrop overlay handled by container CSS -->
      
      <!-- Bottom Sheet Drawer -->
      <div class="bottom-sheet" *ngIf="job">
        <!-- Header Grabber Bar -->
        <div class="sheet-grabber"></div>

        <!-- Ticket Card -->
        <div class="details-card">
          <!-- Ticket Header with Embedded Timer -->
          <div class="ticket-header">
            <div class="fare-info">
              <span class="fare-label">ESTIMATED FARE</span>
              <span class="fare-val">£{{ job.fare.toFixed(2) }}</span>
            </div>

            <!-- Timer embedded within the card -->
            <div class="circle-timer">
              <svg class="progress-ring" width="64" height="64">
                <circle
                  class="progress-ring-track"
                  stroke="#ECEFF1"
                  stroke-width="3.5"
                  fill="transparent"
                  r="27.5"
                  cx="32"
                  cy="32"
                />
                <circle
                  class="progress-ring-circle"
                  stroke="#D32F2F"
                  stroke-width="3.5"
                  fill="transparent"
                  r="27.5"
                  cx="32"
                  cy="32"
                  [style.strokeDashoffset]="strokeDashoffset"
                />
              </svg>
              <div class="timer-text-container">
                <span class="seconds-num">{{ secondsRemaining }}</span>
                <span class="seconds-lbl">SEC</span>
              </div>
            </div>
          </div>

          <!-- Badges panel -->
          <div class="badge-row">
            <span class="payment-badge" [ngClass]="job.paymentType.toLowerCase()">
              {{ job.paymentType }}
            </span>
            <span class="vehicle-badge">
              {{ job.vehicleType }}
            </span>
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

            <!-- Route timeline -->
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

        <!-- Slider and Action Buttons at the very bottom -->
        <div class="action-footer">
          <!-- Slide to Accept widget -->
          <div class="slider-container" #slider>
            <div class="slider-bg-text">SLIDE TO ACCEPT</div>
            <div 
              class="slider-thumb"
              [style.transform]="'translateX(' + sliderPosition + 'px)'"
              (mousedown)="onDragStart($event)"
              (touchstart)="onDragStart($event)"
            >
              <div class="thumb-arrow"></div>
            </div>
          </div>

          <button class="decline-btn" (click)="decline()">
            Decline Job Offer
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
      justify-content: flex-end; /* Aligns sheet to the very bottom */
      font-family: 'Roboto', sans-serif;
      box-sizing: border-box;
      overflow: hidden;
    }

    /* Ambient glassmorphism overlay on top of map background */
    .light-container::before {
      content: '';
      position: absolute;
      top: 0; left: 0; right: 0; bottom: 0;
      background-color: rgba(240, 244, 248, 0.4);
      backdrop-filter: blur(2px);
      z-index: 1;
    }

    /* Bottom Sheet Container */
    .bottom-sheet {
      position: relative;
      z-index: 2;
      background-color: #FFFFFF;
      border-radius: 28px 28px 0 0;
      box-shadow: 0 -12px 36px rgba(0,0,0,0.12);
      padding: 16px 20px 32px 20px; /* Safe padding for system nav */
      display: flex;
      flex-direction: column;
      gap: 16px;
      animation: slideUp 0.35s cubic-bezier(0.16, 1, 0.3, 1);
    }

    @keyframes slideUp {
      from { transform: translateY(100%); }
      to { transform: translateY(0); }
    }

    .sheet-grabber {
      width: 44px;
      height: 5px;
      background-color: #CFD8DC;
      border-radius: 3px;
      align-self: center;
      margin-bottom: 4px;
    }

    /* Ticket Card layout */
    .details-card {
      background-color: #FFFFFF;
      border-radius: 20px;
      border: 1px solid #ECEFF1;
      display: flex;
      flex-direction: column;
    }

    .ticket-header {
      padding: 16px 20px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    .fare-info {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }

    .fare-label {
      font-size: 9px;
      font-weight: 800;
      color: #90A4AE;
      letter-spacing: 1px;
    }

    .fare-val {
      font-size: 34px;
      font-weight: 900;
      color: #2E7D32;
      line-height: 1.1;
    }

    /* Professional embedded circular timer */
    .circle-timer {
      position: relative;
      width: 64px;
      height: 64px;
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
      stroke-dasharray: 172.78; /* 2 * PI * r (r=27.5) */
      transition: stroke-dashoffset 0.1s linear;
    }

    .timer-text-container {
      display: flex;
      flex-direction: column;
      align-items: center;
    }

    .seconds-num {
      font-size: 20px;
      font-weight: 900;
      line-height: 1;
      color: #263238;
    }

    .seconds-lbl {
      font-size: 7px;
      font-weight: 700;
      color: #90A4AE;
      letter-spacing: 0.5px;
      margin-top: 1px;
    }

    .badge-row {
      display: flex;
      gap: 8px;
      padding: 0 20px 14px 20px;
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
      background-color: #FFFFFF;
      border: 1px solid #ECEFF1;
      border-radius: 50%;
    }

    .stub-notch.left {
      margin-left: -8px;
      border-left-color: transparent;
      border-bottom-color: transparent;
      transform: rotate(45deg);
    }

    .stub-notch.right {
      margin-right: -8px;
      border-right-color: transparent;
      border-top-color: transparent;
      transform: rotate(45deg);
    }

    .stub-dash {
      flex: 1;
      border-top: 1.5px dashed #ECEFF1;
      margin: 0 4px;
      height: 1px;
    }

    /* Ticket Body */
    .ticket-body {
      padding: 14px 20px 16px 20px;
      display: flex;
      flex-direction: column;
      gap: 12px;
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
      margin-top: 4px;
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

    /* Action Footer & Slider Accept layout */
    .action-footer {
      display: flex;
      flex-direction: column;
      gap: 12px;
      width: 100%;
      align-items: center;
    }

    /* Premium Slide to Accept Container */
    .slider-container {
      position: relative;
      width: 100%;
      height: 56px;
      background-color: rgba(76, 175, 80, 0.06);
      border-radius: 28px;
      border: 1.5px solid rgba(76, 175, 80, 0.2);
      display: flex;
      align-items: center;
      padding: 0 4px;
      box-sizing: border-box;
      overflow: hidden;
      user-select: none;
    }

    .slider-bg-text {
      position: absolute;
      width: 100%;
      text-align: center;
      font-size: 14px;
      font-weight: 800;
      color: #2E7D32;
      letter-spacing: 1px;
      pointer-events: none;
      z-index: 1;
      animation: pulseText 2s infinite ease-in-out;
    }

    @keyframes pulseText {
      0%, 100% { opacity: 0.6; }
      50% { opacity: 1; }
    }

    .slider-thumb {
      position: relative;
      width: 48px;
      height: 48px;
      background-color: #2E7D32;
      border-radius: 50%;
      display: flex;
      justify-content: center;
      align-items: center;
      cursor: grab;
      z-index: 2;
      box-shadow: 0 3px 8px rgba(46, 125, 50, 0.35);
      transition: transform 0.05s ease-out;
    }

    .slider-thumb:active {
      cursor: grabbing;
      background-color: #1B5E20;
    }

    /* Arrow visual using CSS border instead of font files to prevent rendering flicker */
    .thumb-arrow {
      width: 0; 
      height: 0; 
      border-top: 6px solid transparent;
      border-bottom: 6px solid transparent;
      border-left: 8px solid #FFFFFF;
      margin-left: 2px;
    }

    .decline-btn {
      background-color: transparent;
      border: none;
      color: #E53935;
      font-size: 14px;
      font-weight: 800;
      cursor: pointer;
      padding: 6px 16px;
      letter-spacing: 0.5px;
      transition: color 0.2s ease;
    }

    .decline-btn:active {
      color: #B71C1C;
    }
  `]
})
export class JobOfferComponent implements OnInit, OnDestroy {
  secondsRemaining = 15;
  strokeDasharray = 172.78; // 2 * PI * 27.5
  job: JobDetails | null = null;
  
  // Custom slide variables
  sliderPosition = 0;
  isDragging = false;
  private startX = 0;
  private maxDragRange = 0;

  private timerSub: Subscription | null = null;

  @ViewChild('slider', { static: false }) sliderEl!: ElementRef;

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

  // --- Slide / Drag to Accept Custom Mechanics ---
  onDragStart(event: MouseEvent | TouchEvent): void {
    this.isDragging = true;
    this.startX = this.getEventX(event) - this.sliderPosition;
    
    const containerWidth = this.sliderEl.nativeElement.clientWidth;
    const thumbWidth = 48; // width of thumb
    this.maxDragRange = containerWidth - thumbWidth - 8; // padding margin

    if (event instanceof MouseEvent) {
      document.addEventListener('mousemove', this.onDragMove);
      document.addEventListener('mouseup', this.onDragEnd);
    } else {
      document.addEventListener('touchmove', this.onDragMove, { passive: false });
      document.addEventListener('touchend', this.onDragEnd);
    }
  }

  onDragMove = (event: MouseEvent | TouchEvent): void => {
    if (!this.isDragging) return;
    event.preventDefault();
    
    const currentX = this.getEventX(event);
    let position = currentX - this.startX;
    
    if (position < 0) position = 0;
    if (position > this.maxDragRange) position = this.maxDragRange;
    
    this.sliderPosition = position;
    this.cdr.detectChanges();
    
    // Check if slider is dragged all the way to accept (98% threshold)
    if (this.sliderPosition >= this.maxDragRange - 4) {
      this.onDragEnd(event);
      this.accept();
    }
  }

  onDragEnd = (event: MouseEvent | TouchEvent): void => {
    this.isDragging = false;
    document.removeEventListener('mousemove', this.onDragMove);
    document.removeEventListener('mouseup', this.onDragEnd);
    document.removeEventListener('touchmove', this.onDragMove);
    document.removeEventListener('touchend', this.onDragEnd);

    if (this.sliderPosition < this.maxDragRange - 4) {
      this.animateSnapBack();
    }
  }

  private getEventX(event: MouseEvent | TouchEvent): number {
    return event instanceof MouseEvent ? event.clientX : event.touches[0].clientX;
  }

  private animateSnapBack(): void {
    const step = this.sliderPosition / 8;
    const intervalId = setInterval(() => {
      if (this.sliderPosition > 0) {
        this.sliderPosition -= step;
        if (this.sliderPosition < 0) this.sliderPosition = 0;
        this.cdr.detectChanges();
      } else {
        clearInterval(intervalId);
      }
    }, 16);
  }

  // --- Action Replies ---
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
