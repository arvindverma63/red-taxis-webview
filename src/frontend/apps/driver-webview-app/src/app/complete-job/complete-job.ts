import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
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
        <div class="form-header">
          <span class="material-symbols-outlined success-icon">check_circle</span>
          <h2 class="form-title">Complete Job</h2>
          <p class="form-subtitle">Verify and submit final trip parameters for Booking #{{ jobId }}</p>
        </div>

        <div class="form-body">
          <!-- Payment (Account Price) -->
          <div class="form-group">
            <label class="form-lbl">Payment (Account Price)</label>
            <div class="input-wrapper">
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
          <button class="action-btn submit-btn" (click)="submit()" [disabled]="isSubmitting">
            {{ isSubmitting ? 'Submitting...' : 'Submit Completion' }}
          </button>
          <button class="action-btn cancel-btn" (click)="cancel()" [disabled]="isSubmitting">
            Cancel
          </button>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .complete-container {
      background-color: #F8F9FA;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 20px 14px 120px 14px;
      box-sizing: border-box;
      font-family: 'Roboto', sans-serif;
    }
    .form-card {
      background-color: #FFFFFF;
      border-radius: 20px;
      width: 100%;
      max-width: 480px;
      padding: 24px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.04);
      border: 1px solid #ECEFF1;
      display: flex;
      flex-direction: column;
    }
    .form-header {
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
      margin-bottom: 24px;
    }
    .success-icon {
      font-size: 64px;
      color: #CD1A21;
      margin-bottom: 8px;
    }
    .form-title {
      margin: 0;
      font-size: 20px;
      font-weight: 900;
      color: #1A1C1E;
    }
    .form-subtitle {
      margin: 4px 0 0 0;
      font-size: 12px;
      color: #74777F;
      font-weight: 500;
    }
    .form-body {
      display: flex;
      flex-direction: column;
      gap: 16px;
      margin-bottom: 32px;
    }
    .form-group {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .form-lbl {
      font-size: 11px;
      font-weight: 700;
      color: #74777F;
      text-transform: uppercase;
      letter-spacing: 0.3px;
    }
    .input-wrapper {
      position: relative;
      display: flex;
      align-items: center;
    }
    .currency-symbol {
      position: absolute;
      left: 12px;
      font-size: 14px;
      font-weight: 700;
      color: #44474E;
    }
    .form-input {
      width: 100%;
      border: 1px solid #C4C6CF;
      border-radius: 8px;
      padding: 10px 10px 10px 28px;
      font-size: 14px;
      outline: none;
      box-sizing: border-box;
      color: #1A1C1E;
      background-color: #FAFBFD;
      transition: all 0.2s ease;
    }
    .input-wrapper.no-symbol .form-input {
      padding-left: 12px;
    }
    .form-input:focus {
      border-color: #CD1A21;
      background-color: #FFFFFF;
      box-shadow: 0 0 0 3px rgba(205, 26, 33, 0.1);
    }
    .form-footer {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .action-btn {
      width: 100%;
      height: 48px;
      border-radius: 24px;
      font-size: 14px;
      font-weight: 700;
      cursor: pointer;
      border: none;
      transition: all 0.2s ease;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .action-btn.submit-btn {
      background-color: #CD1A21;
      color: #FFFFFF;
      box-shadow: 0 4px 12px rgba(205, 26, 33, 0.25);
    }
    .action-btn.submit-btn:disabled {
      background-color: #ECEFF1;
      color: #90A4AE;
      box-shadow: none;
      cursor: not-allowed;
    }
    .action-btn.cancel-btn {
      background-color: transparent;
      color: #CD1A21;
      border: 1px solid #CD1A21;
    }
    .action-btn.cancel-btn:disabled {
      border-color: #ECEFF1;
      color: #90A4AE;
      cursor: not-allowed;
    }
  `]
})
export class CompleteJobComponent implements OnInit {
  jobId: string = '';
  fare: number = 0;
  isSubmitting = false;

  completeForm = {
    payment: 0,
    price: 0,
    tip: 0,
    waitingTime: 0,
    parkingCharge: 0
  };

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

  submit(): void {
    const bookingIdNum = parseInt(this.jobId) || 0;
    if (bookingIdNum <= 0) return;

    this.isSubmitting = true;
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
            this.router.navigate(['/bookings']);
          },
          error: () => {
            this.isSubmitting = false;
            this.snackBar.open('Booking completed successfully!', 'Dismiss', { duration: 3000 });
            this.router.navigate(['/bookings']);
          }
        });
      },
      error: (err) => {
        console.error('CompleteJob error:', err);
        this.driverService.setActiveJob(0).subscribe({
          next: () => {
            this.isSubmitting = false;
            this.snackBar.open('Failed to complete booking.', 'Dismiss', { duration: 3000 });
            this.router.navigate(['/bookings']);
          },
          error: () => {
            this.isSubmitting = false;
            this.snackBar.open('Failed to complete booking.', 'Dismiss', { duration: 3000 });
            this.router.navigate(['/bookings']);
          }
        });
      }
    });
  }

  cancel(): void {
    window.history.back();
  }
}
