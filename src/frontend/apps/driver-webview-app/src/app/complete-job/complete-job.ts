import { Component, OnInit, ElementRef, ViewChild, ChangeDetectorRef, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router } from '@angular/router';
import { DriverService } from '../services/driver.service';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';

@Component({
  selector: 'app-complete-job',
  standalone: true,
  imports: [CommonModule, MatSnackBarModule],
  template: `
    <div class="complete-container">
      <div class="form-card">
        <!-- Ticket Notch decoration -->
        <div class="card-notches">
          <div class="notch left"></div>
          <div class="notch right"></div>
        </div>

        <div class="form-header">
          <div class="success-ring">
            <span class="material-symbols-outlined success-icon">sports_score</span>
          </div>
          <h2 class="form-title">Complete Job</h2>
          <div class="booking-tag">BOOKING #{{ jobId }}</div>
        </div>

        <div class="form-body">
          <!-- Payment (Account Price) -->
          <div class="form-group">
            <label class="form-lbl">Payment (Account Price)</label>
            <div class="input-wrapper">
              <span class="material-symbols-outlined prefix-icon">account_balance_wallet</span>
              <span class="currency-symbol">£</span>
              <input 
                type="number" 
                step="0.01" 
                class="form-input" 
                [value]="completeForm.payment" 
                (input)="completeForm.payment = +$any($event.target).value"
              />
            </div>
          </div>

          <!-- Price (Driver Price) -->
          <div class="form-group">
            <label class="form-lbl">Price (Driver Price)</label>
            <div class="input-wrapper">
              <span class="material-symbols-outlined prefix-icon">payments</span>
              <span class="currency-symbol">£</span>
              <input 
                type="number" 
                step="0.01" 
                class="form-input" 
                [value]="completeForm.price" 
                (input)="completeForm.price = +$any($event.target).value"
              />
            </div>
          </div>

          <!-- Tip -->
          <div class="form-group">
            <label class="form-lbl">Tip</label>
            <div class="input-wrapper">
              <span class="material-symbols-outlined prefix-icon">volunteer_activism</span>
              <span class="currency-symbol">£</span>
              <input 
                type="number" 
                step="0.01" 
                class="form-input" 
                [value]="completeForm.tip" 
                (input)="completeForm.tip = +$any($event.target).value"
              />
            </div>
          </div>

          <!-- Waiting Time -->
          <div class="form-group">
            <label class="form-lbl">Waiting Time (Minutes)</label>
            <div class="input-wrapper no-symbol">
              <span class="material-symbols-outlined prefix-icon">schedule</span>
              <input 
                type="number" 
                step="1" 
                class="form-input" 
                [value]="completeForm.waitingTime" 
                (input)="completeForm.waitingTime = +$any($event.target).value"
              />
            </div>
          </div>

          <!-- Parking Charge -->
          <div class="form-group">
            <label class="form-lbl">Parking Charge</label>
            <div class="input-wrapper no-symbol">
              <span class="material-symbols-outlined prefix-icon">local_parking</span>
              <input 
                type="number" 
                step="1" 
                class="form-input" 
                [value]="completeForm.parkingCharge" 
                (input)="completeForm.parkingCharge = +$any($event.target).value"
              />
            </div>
          </div>
        </div>

        <div class="form-footer">
          <!-- Slide / Tap to Complete widget -->
          <div class="slider-container" #slider [class.accepted]="isAccepted">
            <div class="slider-bg-text">
              {{ isAccepted ? 'COMPLETED! RETURNING...' : isSubmitting ? 'SUBMITTING TRIP...' : 'SLIDE TO COMPLETE' }}
            </div>
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

          <button class="cancel-text-btn" (click)="cancel()" [disabled]="isSubmitting || isAccepted">
            Cancel and Return
          </button>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .complete-container {
      background: radial-gradient(circle at top, #1a1f2c, #0d1017);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 32px 16px 120px 16px;
      box-sizing: border-box;
      font-family: 'Roboto', sans-serif;
    }
    .form-card {
      position: relative;
      background-color: #FFFFFF;
      border-radius: 28px;
      width: 100%;
      max-width: 400px;
      padding: 32px 24px;
      box-shadow: 0 24px 64px rgba(0, 0, 0, 0.4);
      box-sizing: border-box;
      display: flex;
      flex-direction: column;
    }
    .card-notches {
      position: absolute;
      top: 130px;
      left: 0;
      right: 0;
      display: flex;
      justify-content: space-between;
      pointer-events: none;
      z-index: 5;
    }
    .notch {
      width: 16px;
      height: 24px;
      background: radial-gradient(circle, transparent 50%, #0d1017 50%);
      background-size: 32px 32px;
    }
    .notch.left {
      background-position: -16px 0;
      border-radius: 0 12px 12px 0;
    }
    .notch.right {
      background-position: 16px 0;
      border-radius: 12px 0 0 12px;
    }
    .form-header {
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
      margin-bottom: 28px;
    }
    .success-ring {
      width: 72px;
      height: 72px;
      border-radius: 50%;
      background-color: rgba(205, 26, 33, 0.08);
      display: flex;
      align-items: center;
      justify-content: center;
      margin-bottom: 12px;
      box-shadow: 0 8px 24px rgba(205, 26, 33, 0.1);
    }
    .success-icon {
      font-size: 36px;
      color: #CD1A21;
    }
    .form-title {
      margin: 0 0 6px 0;
      font-size: 22px;
      font-weight: 900;
      color: #1A1C1E;
      letter-spacing: -0.5px;
    }
    .booking-tag {
      background-color: #FAFBFD;
      border: 1px solid #E0E2EC;
      color: #44474E;
      font-size: 11px;
      font-weight: 700;
      padding: 4px 10px;
      border-radius: 12px;
      letter-spacing: 0.5px;
    }
    .form-body {
      display: flex;
      flex-direction: column;
      gap: 18px;
      margin-bottom: 32px;
    }
    .form-group {
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .form-lbl {
      font-size: 11px;
      font-weight: 700;
      color: #74777F;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .input-wrapper {
      position: relative;
      display: flex;
      align-items: center;
    }
    .prefix-icon {
      position: absolute;
      left: 12px;
      font-size: 20px;
      color: #74777F;
    }
    .currency-symbol {
      position: absolute;
      left: 38px;
      font-size: 14px;
      font-weight: 700;
      color: #1A1C1E;
    }
    .form-input {
      width: 100%;
      border: 1.5px solid #C4C6CF;
      border-radius: 12px;
      padding: 12px 12px 12px 50px;
      font-size: 14px;
      font-weight: 700;
      outline: none;
      box-sizing: border-box;
      color: #1A1C1E;
      background-color: #FAFBFD;
      transition: all 0.2s ease;
    }
    .input-wrapper.no-symbol .form-input {
      padding-left: 42px;
    }
    .form-input:focus {
      border-color: #CD1A21;
      background-color: #FFFFFF;
      box-shadow: 0 0 0 4px rgba(205, 26, 33, 0.12);
    }
    .form-footer {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 16px;
      width: 100%;
    }
    .cancel-text-btn {
      background: none;
      border: none;
      color: #CD1A21;
      font-size: 13px;
      font-weight: 700;
      cursor: pointer;
      padding: 6px 12px;
      transition: all 0.2s;
    }
    .cancel-text-btn:active {
      opacity: 0.65;
    }
    .cancel-text-btn:disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }

    /* Slider Accept/Complete CSS rules */
    .slider-container {
      position: relative;
      width: 100%;
      height: 54px;
      background-color: rgba(205, 26, 33, 0.06);
      border: 2px solid rgba(205, 26, 33, 0.15);
      border-radius: 27px;
      display: flex;
      align-items: center;
      padding: 2px;
      box-shadow: none;
      overflow: hidden;
      user-select: none;
    }
    .slider-bg-text {
      position: absolute;
      width: 100%;
      text-align: center;
      font-size: 13px;
      font-weight: 800;
      color: #CD1A21;
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
      width: 46px;
      height: 46px;
      background-color: #CD1A21;
      border-radius: 50%;
      display: flex;
      justify-content: center;
      align-items: center;
      cursor: grab;
      z-index: 2;
      box-shadow: 0 4px 12px rgba(205, 26, 33, 0.3);
      transition: transform 0.05s ease-out;
    }
    .slider-thumb:active {
      cursor: grabbing;
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
    .slider-container.accepted .slider-thumb {
      background-color: #FFFFFF !important;
    }
    .slider-container.accepted .check-icon {
      color: #2E7D32 !important;
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
  `]
})
export class CompleteJobComponent implements OnInit, OnDestroy {
  jobId: string = '';
  fare: number = 0;
  isSubmitting = false;
  isAccepted = false;

  sliderPosition = 0;
  isDragging = false;
  private startX = 0;
  private maxDragRange = 0;

  completeForm = {
    payment: 0,
    price: 0,
    tip: 0,
    waitingTime: 0,
    parkingCharge: 0
  };

  @ViewChild('slider', { static: false }) sliderEl!: ElementRef;

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private driverService: DriverService,
    private cdr: ChangeDetectorRef,
    private snackBar: MatSnackBar
  ) {}

  ngOnInit(): void {
    this.route.queryParams.subscribe(params => {
      this.jobId = (params['jobId'] || '').toString();
      this.fare = parseFloat(params['fare'] || '0') || 0;

      this.completeForm = {
        payment: 0,
        price: this.fare,
        tip: 0,
        waitingTime: 0,
        parkingCharge: 0
      };
      this.cdr.detectChanges();
    });
  }

  onDragStart(event: MouseEvent | TouchEvent): void {
    if (this.isSubmitting || this.isAccepted) return;
    this.isDragging = true;
    this.startX = this.getEventX(event);
    
    const containerWidth = this.sliderEl.nativeElement.clientWidth;
    const thumbWidth = 46; 
    this.maxDragRange = containerWidth - thumbWidth - 8; 
    
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
    
    if (event instanceof TouchEvent) {
      event.preventDefault(); 
    }

    const currentX = this.getEventX(event);
    let diff = currentX - this.startX;
    
    if (diff < 0) diff = 0;
    if (diff > this.maxDragRange) diff = this.maxDragRange;
    
    this.sliderPosition = diff;
    this.cdr.detectChanges();
  };

  onDragEnd = (event: MouseEvent | TouchEvent): void => {
    if (!this.isDragging) return;
    this.isDragging = false;
    
    if (event instanceof MouseEvent) {
      document.removeEventListener('mousemove', this.onDragMove);
      document.removeEventListener('mouseup', this.onDragEnd);
    } else {
      document.removeEventListener('touchmove', this.onDragMove);
      document.removeEventListener('touchend', this.onDragEnd);
    }
    
    if (this.sliderPosition >= this.maxDragRange * 0.85) {
      this.sliderPosition = this.maxDragRange;
      this.cdr.detectChanges();
      this.submit();
    } else {
      this.animateSnapBack();
    }
  };

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

  notifyNativeApp(message: string): void {
    try {
      const channel = (window as any).FlutterChannel;
      if (channel) {
        channel.postMessage(message);
      } else {
        console.log(`Native notification bypassed: ${message}`);
      }
    } catch (err) {
      console.error('Failed to notify native app:', err);
    }
  }

  submit(): void {
    const bookingIdNum = parseInt(this.jobId) || 0;
    if (bookingIdNum <= 0) return;

    this.isSubmitting = true;
    this.isAccepted = true;
    this.cdr.detectChanges();
    this.snackBar.open('Completing booking...', 'Dismiss', { duration: 2000 });

    this.driverService.completeJob({
      bookingId: bookingIdNum,
      driverPrice: this.completeForm.price,
      waitingTime: this.completeForm.waitingTime,
      parkingCharge: this.completeForm.parkingCharge,
      accountPrice: this.completeForm.payment,
      tip: this.completeForm.tip
    }).subscribe({
      next: () => {
        this.driverService.setActiveJob(0).subscribe({
          next: () => {
            this.isSubmitting = false;
            this.snackBar.open('Booking completed successfully!', 'Dismiss', { duration: 3000 });
            this.notifyNativeApp('close_complete_job');
            setTimeout(() => {
              this.router.navigate(['/bookings']);
            }, 600);
          },
          error: () => {
            this.isSubmitting = false;
            this.snackBar.open('Booking completed successfully!', 'Dismiss', { duration: 3000 });
            this.notifyNativeApp('close_complete_job');
            setTimeout(() => {
              this.router.navigate(['/bookings']);
            }, 600);
          }
        });
      },
      error: (err) => {
        console.error('CompleteJob error:', err);
        this.driverService.setActiveJob(0).subscribe({
          next: () => {
            this.isSubmitting = false;
            this.snackBar.open('Failed to complete booking.', 'Dismiss', { duration: 3000 });
            this.notifyNativeApp('close_complete_job');
            setTimeout(() => {
              this.router.navigate(['/bookings']);
            }, 600);
          },
          error: () => {
            this.isSubmitting = false;
            this.snackBar.open('Failed to complete booking.', 'Dismiss', { duration: 3000 });
            this.notifyNativeApp('close_complete_job');
            setTimeout(() => {
              this.router.navigate(['/bookings']);
            }, 600);
          }
        });
      }
    });
  }

  cancel(): void {
    this.notifyNativeApp('close_complete_job');
    window.history.back();
  }

  ngOnDestroy(): void {
    // Make sure event listeners are cleaned up
    document.removeEventListener('mousemove', this.onDragMove);
    document.removeEventListener('mouseup', this.onDragEnd);
    document.removeEventListener('touchmove', this.onDragMove);
    document.removeEventListener('touchend', this.onDragEnd);
  }
}
