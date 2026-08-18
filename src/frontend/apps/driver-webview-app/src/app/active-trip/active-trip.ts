import { Component, OnInit, ChangeDetectorRef, ViewChild } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute } from '@angular/router';

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
  selector: 'app-active-trip',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="light-container">
      <!-- Ambient map backdrop overlay -->
      
      <!-- Bottom Sheet Drawer -->
      <div class="bottom-sheet" *ngIf="job">
        <!-- Header Grabber Bar -->
        <div class="sheet-grabber"></div>

        <!-- Active Status Card Banner -->
        <div class="status-banner" [ngClass]="statusClass">
          <span class="status-title">{{ getStatusTitle().toUpperCase() }}</span>
        </div>

        <!-- Ticket Card -->
        <div class="details-card">
          <div class="ticket-header">
            <div class="fare-info">
              <span class="fare-label">ESTIMATED FARE</span>
              <span class="fare-val">£{{ job.fare.toFixed(2) }}</span>
            </div>
            
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

        <!-- Utilities Row: Call & Navigate -->
        <div class="utilities-row">
          <button class="util-btn outlined" (click)="callCustomer()">
            <span class="btn-icon">📞</span> Call Customer
          </button>
          <button class="util-btn outlined" (click)="navigateRoute()">
            <span class="btn-icon">🧭</span> Navigate
          </button>
        </div>

        <!-- Main State Action Button -->
        <div class="action-footer">
          <!-- Slide to Complete Widget when status is onTrip -->
          <div class="slide-complete-container" *ngIf="status === 'onTrip'">
            <div 
              #sliderEl
              class="slide-complete-track"
              [class.submitting]="isSubmitting"
            >
              <div 
                class="slide-fill-bar" 
                [style.width.px]="sliderPosition + 22"
              ></div>
              <div class="slide-track-text" *ngIf="!isSubmitting">
                {{ isDragging ? 'Release to Complete' : 'Slide to Complete' }}
              </div>
              <div class="slide-track-text submitting" *ngIf="isSubmitting">
                Completing Trip...
              </div>
              <div 
                class="slide-thumb-btn"
                [style.transform]="'translateX(' + sliderPosition + 'px)'"
                (mousedown)="onDragStart($event)"
                (touchstart)="onDragStart($event)"
              >
                <span class="material-symbols-outlined select-none" style="user-select:none;">keyboard_double_arrow_right</span>
              </div>
            </div>
          </div>

          <!-- Default button for other states -->
          <button *ngIf="status !== 'onTrip'" class="action-btn" [ngClass]="statusClass" (click)="onMainAction()">
            {{ getMainActionLabel() }}
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

    /* Ambient glassmorphism overlay */
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
      padding: 16px 20px 64px 20px; /* Safe padding for system nav */
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

    /* Status Banner Card styles */
    .status-banner {
      width: 100%;
      padding: 12px;
      border-radius: 12px;
      text-align: center;
      box-sizing: border-box;
    }

    .status-banner.en-route {
      background-color: rgba(255, 152, 0, 0.08);
      color: #E65100;
      border: 1px solid rgba(255, 152, 0, 0.2);
    }

    .status-banner.arrived {
      background-color: rgba(33, 150, 243, 0.08);
      color: #0D47A1;
      border: 1px solid rgba(33, 150, 243, 0.2);
    }

    .status-banner.on-trip {
      background-color: rgba(76, 175, 80, 0.08);
      color: #1B5E20;
      border: 1px solid rgba(76, 175, 80, 0.2);
    }

    .status-title {
      font-size: 13px;
      font-weight: 900;
      letter-spacing: 0.5px;
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
      font-size: 30px;
      font-weight: 900;
      color: #2E7D32;
      line-height: 1.1;
    }

    .badge-row {
      display: flex;
      gap: 8px;
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

    /* Utilities calling row */
    .utilities-row {
      display: flex;
      gap: 12px;
      width: 100%;
    }

    .util-btn {
      flex: 1;
      padding: 12px;
      border-radius: 14px;
      font-size: 13px;
      font-weight: 800;
      cursor: pointer;
      display: flex;
      justify-content: center;
      align-items: center;
      gap: 6px;
      transition: all 0.2s ease;
    }

    .util-btn.outlined {
      background-color: transparent;
      border: 1.5px solid #CFD8DC;
      color: #37474F;
    }

    .util-btn.outlined:active {
      background-color: #F5F7FA;
      border-color: #90A4AE;
    }

    /* Action Footer buttons */
    .action-footer {
      width: 100%;
    }

    .action-btn {
      width: 100%;
      color: #FFFFFF;
      font-weight: 800;
      font-size: 16px;
      padding: 14px;
      border: none;
      border-radius: 14px;
      cursor: pointer;
      box-shadow: 0 4px 10px rgba(0,0,0,0.1);
      transition: all 0.2s ease;
      letter-spacing: 0.5px;
      margin-bottom: 24px; /* Space from virtual bottom bar */
    }

    .action-btn.en-route {
      background-color: #FF9800;
      box-shadow: 0 4px 12px rgba(255, 152, 0, 0.2);
    }
    
    .action-btn.en-route:active {
      background-color: #E65100;
    }

    .action-btn.arrived {
      background-color: #2196F3;
      box-shadow: 0 4px 12px rgba(33, 150, 243, 0.2);
    }
    
    .action-btn.arrived:active {
      background-color: #0D47A1;
    }

    .action-btn.on-trip {
      background-color: #D32F2F;
      box-shadow: 0 4px 12px rgba(211, 47, 47, 0.2);
    }
    
    .action-btn.on-trip:active {
      background-color: #B71C1C;
    }

    .slide-complete-container {
      width: 100%;
      margin: 8px 0 24px 0;
      box-sizing: border-box;
    }
    .slide-complete-track {
      position: relative;
      height: 52px;
      background-color: #F1F3F9;
      border: 1px solid #CFD8DC;
      border-radius: 26px;
      overflow: hidden;
      display: flex;
      align-items: center;
      justify-content: center;
      user-select: none;
      box-shadow: inset 0 2px 4px rgba(0,0,0,0.06);
    }
    .slide-complete-track.submitting {
      opacity: 0.8;
      pointer-events: none;
    }
    .slide-fill-bar {
      position: absolute;
      left: 0;
      top: 0;
      bottom: 0;
      background: linear-gradient(90deg, #CD1A21 0%, #E53935 100%);
      border-radius: 26px 0 0 26px;
      z-index: 1;
      transition: width 0.05s ease;
    }
    .slide-track-text {
      position: absolute;
      font-size: 13px;
      font-weight: 800;
      color: #37474F;
      z-index: 2;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      pointer-events: none;
    }
    .slide-track-text.submitting {
      color: #CD1A21;
    }
    .slide-thumb-btn {
      position: absolute;
      left: 4px;
      width: 44px;
      height: 44px;
      background-color: #CD1A21;
      color: #FFFFFF;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: grab;
      z-index: 3;
      box-shadow: 0 3px 8px rgba(205, 26, 33, 0.45);
      transition: transform 0.05s ease, background-color 0.2s;
    }
    .slide-thumb-btn:active {
      cursor: grabbing;
      background-color: #B71C1C;
    }
  `]
})
export class ActiveTripComponent implements OnInit {
  job: JobDetails | null = null;
  status = 'enRouteToPickup'; // default

  @ViewChild('sliderEl') sliderEl!: any;
  sliderPosition = 0;
  isDragging = false;
  isSubmitting = false;
  maxDragRange = 0;
  startX = 0;

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
      const vehicleType = params['vehicleType'];
      const passenger = params['passenger'];
      const notes = params['notes'];
      const statusParam = params['status'];

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
        this.status = statusParam || 'enRouteToPickup';
        this.sliderPosition = 0;
        this.isSubmitting = false;
        this.cdr.detectChanges();
      }
    });
  }

  onDragStart(event: MouseEvent | TouchEvent): void {
    if (this.isSubmitting) return;
    this.isDragging = true;
    this.startX = this.getEventX(event) - this.sliderPosition;
    
    if (this.sliderEl) {
      const containerWidth = this.sliderEl.nativeElement.clientWidth;
      const thumbWidth = 44;
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
      this.completeTrip();
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

  completeTrip(): void {
    if (this.isSubmitting) return;
    this.isSubmitting = true;
    this.cdr.detectChanges();
    this.notifyNativeApp('complete_trip');
  }

  get statusClass(): string {
    if (this.status === 'arrived') return 'arrived';
    if (this.status === 'onTrip') return 'on-trip';
    return 'en-route';
  }

  getStatusTitle(): string {
    if (this.status === 'arrived') return 'Arrived at Pickup';
    if (this.status === 'onTrip') return 'Passenger Onboard (On Trip)';
    return 'En Route to Pickup';
  }

  getMainActionLabel(): string {
    if (this.status === 'arrived') return 'Start Trip';
    if (this.status === 'onTrip') return 'Complete Trip';
    return 'Arrived at Pickup';
  }

  onMainAction(): void {
    if (this.status === 'arrived') {
      this.notifyNativeApp('start_trip');
    } else if (this.status === 'onTrip') {
      this.completeTrip();
    } else {
      this.notifyNativeApp('arrived_at_pickup');
    }
  }

  callCustomer(): void {
    this.notifyNativeApp('call_customer');
  }

  navigateRoute(): void {
    this.notifyNativeApp('navigate');
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
