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
          <!-- Slide / Tap to Accept widget -->
          <div class="slider-container" #slider (click)="onSliderClick($event)" [class.accepted]="isAccepted">
            <div class="slider-bg-text">{{ isAccepted ? 'ACCEPTED! RETURNING...' : isSubmitting ? 'ACCEPTING BOOKING...' : 'SLIDE TO ACCEPT' }}</div>
            <div 
              class="slider-thumb"
              [style.transform]="'translateX(' + sliderPosition + 'px)'"
              (mousedown)="onDragStart($event)"
              (touchstart)="onDragStart($event)"
            >
              <div class="thumb-arrow" *ngIf="!isAccepted"></div>
              <span class="material-symbols-outlined check-icon" *ngIf="isAccepted">check</span>
            </div>
          </div>

          <button class="decline-btn" [disabled]="isSubmitting || isAccepted" (click)="decline()">
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
      justify-content: flex-end;
      font-family: 'Roboto', sans-serif;
      box-sizing: border-box;
      overflow: hidden;
    }

    .light-container::before {
      content: '';
      position: absolute;
      top: 0; left: 0; right: 0; bottom: 0;
      background-color: rgba(240, 244, 248, 0.4);
      backdrop-filter: blur(2px);
      z-index: 1;
    }

    .bottom-sheet {
      position: relative;
      z-index: 2;
      background-color: #FFFFFF;
      border-radius: 28px 28px 0 0;
      box-shadow: 0 -12px 36px rgba(0,0,0,0.12);
      padding: 16px 20px 48px 20px;
      display: flex;
      flex-direction: column;
      gap: 14px;
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
      margin-bottom: 2px;
    }

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
      stroke-dasharray: 172.78;
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
    .payment-badge.account,
    .payment-badge.rank {
      background-color: rgba(33, 150, 243, 0.08);
      color: #1565C0;
      border: 1px solid rgba(33, 150, 243, 0.15);
    }

    .vehicle-badge {
      background-color: #F5F7FA;
      color: #455A64;
      border: 1px solid #E4E7EB;
    }

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

    .ticket-body {
      padding: 14px 20px 16px 20px;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }

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

    .action-footer {
      display: flex;
      flex-direction: column;
      gap: 10px;
      width: 100%;
      align-items: center;
    }

    .slider-container {
      position: relative;
      width: 100%;
      height: 56px;
      background-color: rgba(76, 175, 80, 0.08);
      border-radius: 28px;
      border: 1.5px solid rgba(76, 175, 80, 0.25);
      display: flex;
      align-items: center;
      padding: 0 4px;
      box-sizing: border-box;
      overflow: hidden;
      user-select: none;
      cursor: pointer;
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

    .slider-container.accepted {
      background-color: #2E7D32 !important;
      border-color: #2E7D32 !important;
    }
    .slider-container.accepted .slider-bg-text {
      color: #FFFFFF !important;
      font-weight: 900 !important;
      animation: none !important;
    }
    .check-icon {
      color: #FFFFFF;
      font-size: 24px;
      font-weight: bold;
    }

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
      margin-bottom: 12px;
      letter-spacing: 0.5px;
      transition: color 0.2s ease;
    }

    .decline-btn:active {
      color: #B71C1C;
    }

    .decline-btn:disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }
  `]
})
export class JobOfferComponent implements OnInit, OnDestroy {
  secondsRemaining = 15;
  strokeDasharray = 172.78;
  job: JobDetails | null = null;
  jobIdFromUrl: string = '';
  guid: string = '';
  isSubmitting = false;
  isAccepted = false;
  
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
    this.route.queryParams.subscribe(params => {
      const id = params['jobId'] || '';
      this.jobIdFromUrl = id.toString();
      this.guid = (params['guid'] || params['Guid'] || params['notificationId'] || params['notification_id'] || '').toString();
      const fareVal = parseFloat(params['fare'] || '0');
      const pickup = params['pickup'] ? decodeURIComponent(params['pickup']) : '';
      const dropoff = params['dropoff'] ? decodeURIComponent(params['dropoff']) : '';
      const paymentType = params['paymentType'];
      const vehicleType = params['vehicleType'];
      const passenger = params['passenger'];
      const notes = params['notes'];

      const isPlaceholder = !pickup || pickup === 'Pickup address' || pickup === 'Pickup location' || fareVal === 0;

      if (id && !isNaN(fareVal) && pickup && dropoff && !isPlaceholder) {
        this.job = {
          id: id.toString(),
          fare: fareVal,
          pickup: pickup,
          dropoff: dropoff,
          paymentType: paymentType || 'Cash',
          vehicleType: vehicleType ? decodeURIComponent(vehicleType) : 'Standard Saloon',
          passenger: passenger ? decodeURIComponent(passenger) : 'Passenger',
          notes: notes ? decodeURIComponent(notes) : ''
        };
        this.cdr.detectChanges();
      } else {
        this.fetchJobFromApi();
      }
    });

    this.startTimer();
  }

  private mapApiJobToJobDetails(item: any): JobDetails {
    let paymentType = item.paymentType || item.PaymentType || item.paymentMethod || item.PaymentMethod || '';
    if (!paymentType && (item.scope !== undefined && item.scope !== null || item.Scope !== undefined && item.Scope !== null)) {
      const scope = parseInt((item.scope ?? item.Scope).toString()) || 0;
      switch (scope) {
        case 0: paymentType = 'Cash'; break;
        case 1: paymentType = 'Account'; break;
        case 2: paymentType = 'Rank'; break;
        case 4: paymentType = 'Card'; break;
        default: paymentType = 'Cash'; break;
      }
    }
    if (!paymentType) paymentType = 'Cash';

    return {
      id: (item.bookingId || item.BookingId || item.bookingNo || item.BookingNo || item.id || item.Id || this.jobIdFromUrl || '').toString(),
      fare: parseFloat((item.price || item.Price || item.fare || item.Fare || item.amount || item.Amount || item.driverPrice || item.DriverPrice || '0.00').toString()),
      pickup: item.pickupAddress || item.PickupAddress || item.pickup || item.Pickup || item.from || item.From || 'Pickup location',
      dropoff: item.destinationAddress || item.DestinationAddress || item.dropoff || item.Dropoff || item.dropoffAddress || item.DropoffAddress || item.to || item.To || 'Dropoff destination',
      paymentType: paymentType,
      vehicleType: item.vehicleType || item.VehicleType || item.vehicle || item.Vehicle || 'Standard Saloon',
      passenger: item.passengerName || item.PassengerName || item.passenger || item.Passenger || item.customerName || item.CustomerName || 'Passenger',
      notes: item.details || item.Details || item.notes || item.Notes || item.comment || item.Comment || item.specialRequirements || item.SpecialRequirements || ''
    };
  }

  fetchJobFromApi(): void {
    // 1. Try FindById?bookingId=
    if (this.jobIdFromUrl) {
      this.driverService.getJobById(this.jobIdFromUrl).subscribe({
        next: (data) => {
          if (data && (data.bookingId || data.BookingId || data.pickupAddress || data.Price || data.price)) {
            this.job = this.mapApiJobToJobDetails(data);
            const guid = data.guid || data.Guid || data.notificationId || data.notification_id || data.NotificationId;
            if (guid && !this.guid) this.guid = guid;
            this.cdr.detectChanges();
          } else {
            this.fetchViaRetrieveJobOfferOrOffers();
          }
        },
        error: () => this.fetchViaRetrieveJobOfferOrOffers()
      });
    } else {
      this.fetchViaRetrieveJobOfferOrOffers();
    }
  }

  private fetchViaRetrieveJobOfferOrOffers(): void {
    // 2. Try RetrieveJobOffer?guid=
    if (this.guid) {
      this.driverService.retrieveJobOffer(this.guid).subscribe({
        next: (data) => {
          if (data && (data.bookingId || data.pickupAddress || data.price)) {
            this.job = this.mapApiJobToJobDetails(data);
            this.cdr.detectChanges();
          } else {
            this.fetchViaGetJobOffers();
          }
        },
        error: () => this.fetchViaGetJobOffers()
      });
    } else {
      this.fetchViaGetJobOffers();
    }
  }

  private fetchViaGetJobOffers(): void {
    // 3. Try GetJobOffers
    this.driverService.getJobOffers().subscribe({
      next: (offers) => {
        const data = offers?.value || offers?.data || (Array.isArray(offers) ? offers : []);
        if (Array.isArray(data) && data.length > 0) {
          const matching = data.find((j: any) => (j.bookingNo || j.BookingNo || j.bookingId || j.BookingId || j.id || j.Id || '').toString() === this.jobIdFromUrl) || data[0];
          this.job = this.mapApiJobToJobDetails(matching);
          const guid = matching.guid || matching.Guid || matching.notificationId || matching.notification_id || matching.NotificationId;
          if (guid && !this.guid) this.guid = guid;
          this.cdr.detectChanges();
        } else if (this.jobIdFromUrl) {
          if (!this.job) {
            this.job = {
              id: this.jobIdFromUrl,
              fare: 0.00,
              pickup: 'Pickup location',
              dropoff: 'Dropoff destination',
              paymentType: 'Cash',
              vehicleType: 'Standard Saloon',
              passenger: 'Passenger',
              notes: ''
            };
            this.cdr.detectChanges();
          }
        }
      },
      error: (err) => {
        console.error('fetchViaGetJobOffers error:', err);
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
    if (this.isSubmitting) return;
    this.isDragging = true;
    this.startX = this.getEventX(event) - this.sliderPosition;
    
    if (this.sliderEl) {
      const containerWidth = this.sliderEl.nativeElement.clientWidth;
      const thumbWidth = 48;
      this.maxDragRange = containerWidth - thumbWidth - 8;
    }

    if (event instanceof MouseEvent) {
      document.addEventListener('mousemove', this.onDragMove);
      document.addEventListener('mouseup', this.onDragEnd);
    } else {
      document.addEventListener('touchmove', this.onDragMove, { passive: false });
      document.addEventListener('touchend', this.onDragEnd);
    }
  }

  onDragMove = (event: MouseEvent | TouchEvent): void => {
    if (!this.isDragging || this.isSubmitting) return;
    event.preventDefault();
    
    const currentX = this.getEventX(event);
    let position = currentX - this.startX;
    
    if (position < 0) position = 0;
    if (position > this.maxDragRange) position = this.maxDragRange;
    
    this.sliderPosition = position;
    this.cdr.detectChanges();
    
    if (this.maxDragRange > 0 && this.sliderPosition >= this.maxDragRange * 0.85) {
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

    if (!this.isSubmitting && this.maxDragRange > 0 && this.sliderPosition < this.maxDragRange * 0.85) {
      this.animateSnapBack();
    }
  }

  onSliderClick(event: MouseEvent): void {
    if (this.isDragging || this.isSubmitting) return;
    if (this.sliderEl) {
      const containerWidth = this.sliderEl.nativeElement.clientWidth;
      const thumbWidth = 48;
      this.maxDragRange = containerWidth - thumbWidth - 8;
      this.sliderPosition = this.maxDragRange;
      this.cdr.detectChanges();
    }
    this.accept();
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
    if (this.isSubmitting) return;
    this.isSubmitting = true;
    this.isAccepted = true;
    this.timerSub?.unsubscribe();
    this.cdr.detectChanges();

    const jobId = this.job?.id || this.jobIdFromUrl || '';
    const doDismiss = () => {
      setTimeout(() => {
        this.notifyNativeApp('job_accepted');
      }, 500);
    };

    if (jobId && !jobId.startsWith('sim-')) {
      console.log(`replyJobOffer accept action started for jobId=${jobId}, guid=${this.guid}`);
      this.driverService.replyJobOffer(parseInt(jobId) || 0, 2000, this.guid).subscribe({
        next: (res) => {
          console.log(`replyJobOffer accept success for jobId=${jobId}. Response text: "${res}"`);
          doDismiss();
        },
        error: (err) => {
          console.error(`replyJobOffer accept failed for jobId=${jobId}. Error details:`, err);
          try {
            console.error(`replyJobOffer accept error serialized: ${JSON.stringify(err)}`);
          } catch (e) {}
          doDismiss();
        }
      });
    } else {
      doDismiss();
    }
  }

  decline(): void {
    if (this.isSubmitting) return;
    this.isSubmitting = true;
    this.timerSub?.unsubscribe();
    this.cdr.detectChanges();

    const jobId = this.job?.id || this.jobIdFromUrl || '';
    if (jobId && !jobId.startsWith('sim-')) {
      console.log(`replyJobOffer decline action started for jobId=${jobId}, guid=${this.guid}`);
      this.driverService.replyJobOffer(parseInt(jobId) || 0, 2001, this.guid).subscribe({
        next: (res) => {
          console.log(`replyJobOffer decline success for jobId=${jobId}. Response text: "${res}"`);
          this.notifyNativeApp('job_rejected');
        },
        error: (err) => {
          console.error(`replyJobOffer decline failed for jobId=${jobId}. Error details:`, err);
          try {
            console.error(`replyJobOffer decline error serialized: ${JSON.stringify(err)}`);
          } catch (e) {}
          this.notifyNativeApp('job_rejected');
        }
      });
    } else {
      this.notifyNativeApp('job_rejected');
    }
  }

  private autoReject(): void {
    if (this.isSubmitting) return;
    this.isSubmitting = true;
    const jobId = this.job?.id || this.jobIdFromUrl || '';
    if (jobId && !jobId.startsWith('sim-')) {
      console.log(`replyJobOffer autoReject action started for jobId=${jobId}, guid=${this.guid}`);
      this.driverService.replyJobOffer(parseInt(jobId) || 0, 2001, this.guid).subscribe({
        next: (res) => {
          console.log(`replyJobOffer autoReject success for jobId=${jobId}. Response text: "${res}"`);
          this.notifyNativeApp('job_rejected');
        },
        error: (err) => {
          console.error(`replyJobOffer autoReject failed for jobId=${jobId}. Error details:`, err);
          try {
            console.error(`replyJobOffer autoReject error serialized: ${JSON.stringify(err)}`);
          } catch (e) {}
          this.notifyNativeApp('job_rejected');
        }
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
