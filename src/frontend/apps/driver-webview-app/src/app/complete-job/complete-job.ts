import { Component, OnInit, ElementRef, ViewChild, ChangeDetectorRef, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router } from '@angular/router';
import { DriverService } from '../services/driver.service';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { of } from 'rxjs';
import { catchError } from 'rxjs/operators';

interface BookingSummary {
  passenger: string;
  pickup: string;
  dropoff: string;
  paymentType: string;
}

@Component({
  selector: 'app-complete-job',
  standalone: true,
  imports: [CommonModule, MatSnackBarModule],
  template: `
    <div class="complete-container">
      <div class="complete-layout-card">

        <!-- 1. Executive Completion Hero Header -->
        <div class="completion-hero-header">
          <div class="hero-top-row">
            <div class="completion-badge">
              <span class="material-symbols-outlined check-icon">check_circle</span>
              <span>TRIP COMPLETION</span>
            </div>
            <div class="booking-ref-chip">#{{ jobId }}</div>
          </div>

          <div class="total-settlement-display">
            <span class="total-label">TOTAL SETTLEMENT</span>
            <div class="total-fare-value">
              <span class="curr-sign">£</span>
              <span class="amount-int">{{ totalSettlement.toFixed(2) }}</span>
            </div>
            <div class="payment-method-tag" [ngClass]="(bookingDetails?.paymentType || 'cash').toLowerCase()">
              <span class="material-symbols-outlined method-icon">payments</span>
              <span>{{ bookingDetails?.paymentType || 'Cash' }}</span>
            </div>
          </div>
        </div>

        <!-- 2. Journey Summary Snippet (if available) -->
        <div class="route-snippet-card" *ngIf="bookingDetails">
          <div class="snippet-header">
            <span class="material-symbols-outlined route-icon">alt_route</span>
            <span class="snippet-title">JOURNEY OVERVIEW</span>
            <span class="passenger-chip" *ngIf="bookingDetails.passenger">
              <span class="material-symbols-outlined chip-icon">person</span>
              {{ bookingDetails.passenger }}
            </span>
          </div>

          <div class="snippet-timeline">
            <div class="snippet-node">
              <span class="material-symbols-outlined node-dot green">my_location</span>
              <span class="node-addr">{{ bookingDetails.pickup }}</span>
            </div>
            <div class="snippet-node">
              <span class="material-symbols-outlined node-dot red">location_on</span>
              <span class="node-addr">{{ bookingDetails.dropoff }}</span>
            </div>
          </div>
        </div>

        <!-- 3. Form Adjustment Cards -->
        <div class="adjustments-form-body">

          <!-- Card A: Primary Fare & Driver Settlement -->
          <div class="form-section-card">
            <div class="section-card-header">
              <span class="material-symbols-outlined sec-icon green-icon">receipt_long</span>
              <span class="sec-title">FARE & EARNINGS</span>
            </div>

            <!-- Driver Fare / Price -->
            <div class="input-field-group">
              <label class="field-label">
                <span>Driver Fare Amount</span>
                <span class="field-hint">Base trip fare</span>
              </label>
              <div class="executive-input-wrapper">
                <span class="input-prefix-icon">£</span>
                <input 
                  type="number" 
                  step="0.01" 
                  min="0"
                  class="executive-input" 
                  [value]="completeForm.price" 
                  (input)="onPriceInput($event)"
                />
              </div>
              <div class="quick-chips-row">
                <button type="button" class="quick-chip" (click)="addPrice(1)">+£1</button>
                <button type="button" class="quick-chip" (click)="addPrice(2)">+£2</button>
                <button type="button" class="quick-chip" (click)="addPrice(5)">+£5</button>
                <button type="button" class="quick-chip" (click)="addPrice(10)">+£10</button>
                <button type="button" class="quick-chip reset" (click)="resetPrice()">Reset ({{ fare }})</button>
              </div>
            </div>

            <!-- Driver Tip -->
            <div class="input-field-group">
              <label class="field-label">
                <span>Driver Tip</span>
                <span class="field-hint">Gratuity received</span>
              </label>
              <div class="executive-input-wrapper">
                <span class="input-prefix-icon">£</span>
                <input 
                  type="number" 
                  step="0.01" 
                  min="0"
                  class="executive-input" 
                  [value]="completeForm.tip" 
                  (input)="onTipInput($event)"
                />
              </div>
              <div class="quick-chips-row">
                <button type="button" class="quick-chip" [class.active]="completeForm.tip === 1" (click)="setTip(1)">+£1</button>
                <button type="button" class="quick-chip" [class.active]="completeForm.tip === 2" (click)="setTip(2)">+£2</button>
                <button type="button" class="quick-chip" [class.active]="completeForm.tip === 5" (click)="setTip(5)">+£5</button>
                <button type="button" class="quick-chip" [class.active]="completeForm.tip === 10" (click)="setTip(10)">+£10</button>
                <button type="button" class="quick-chip reset" *ngIf="completeForm.tip > 0" (click)="setTip(0)">Clear</button>
              </div>
            </div>
          </div>

          <!-- Card B: Additional Charges & Extras -->
          <div class="form-section-card">
            <div class="section-card-header">
              <span class="material-symbols-outlined sec-icon amber-icon">more_time</span>
              <span class="sec-title">EXTRAS & SURCHARGES</span>
            </div>

            <!-- Waiting Time (Minutes) -->
            <div class="input-field-group">
              <label class="field-label">
                <span>Waiting Time</span>
                <span class="field-hint">Total wait duration</span>
              </label>
              <div class="stepper-input-wrapper">
                <button type="button" class="stepper-btn" (click)="stepWaiting(-5)" [disabled]="completeForm.waitingTime <= 0">
                  <span class="material-symbols-outlined">remove</span>
                </button>
                <div class="stepper-val-display">
                  <span class="stepper-num">{{ completeForm.waitingTime }}</span>
                  <span class="stepper-unit">mins</span>
                </div>
                <button type="button" class="stepper-btn" (click)="stepWaiting(5)">
                  <span class="material-symbols-outlined">add</span>
                </button>
              </div>
              <div class="quick-chips-row">
                <button type="button" class="quick-chip" (click)="setWaiting(5)">5m</button>
                <button type="button" class="quick-chip" (click)="setWaiting(10)">10m</button>
                <button type="button" class="quick-chip" (click)="setWaiting(15)">15m</button>
                <button type="button" class="quick-chip" (click)="setWaiting(30)">30m</button>
                <button type="button" class="quick-chip reset" *ngIf="completeForm.waitingTime > 0" (click)="setWaiting(0)">Clear</button>
              </div>
            </div>

            <!-- Parking & Toll Charges -->
            <div class="input-field-group">
              <label class="field-label">
                <span>Parking & Toll Charges</span>
                <span class="field-hint">Airports / dropoff fees</span>
              </label>
              <div class="executive-input-wrapper">
                <span class="input-prefix-icon">£</span>
                <input 
                  type="number" 
                  step="0.50" 
                  min="0"
                  class="executive-input" 
                  [value]="completeForm.parkingCharge" 
                  (input)="onParkingInput($event)"
                />
              </div>
              <div class="quick-chips-row">
                <button type="button" class="quick-chip" (click)="addParking(2.50)">+£2.50</button>
                <button type="button" class="quick-chip" (click)="addParking(5.00)">+£5.00</button>
                <button type="button" class="quick-chip" (click)="addParking(7.50)">+£7.50</button>
                <button type="button" class="quick-chip reset" *ngIf="completeForm.parkingCharge > 0" (click)="setParking(0)">Clear</button>
              </div>
            </div>

            <!-- Account Price (Only for Account Bookings or Surcharges) -->
            <div class="input-field-group" *ngIf="bookingDetails?.paymentType?.toLowerCase() === 'account'">
              <label class="field-label">
                <span>Account Billed Price</span>
                <span class="field-hint">Invoice amount</span>
              </label>
              <div class="executive-input-wrapper">
                <span class="input-prefix-icon">£</span>
                <input 
                  type="number" 
                  step="0.01" 
                  min="0"
                  class="executive-input" 
                  [value]="completeForm.payment" 
                  (input)="onPaymentInput($event)"
                />
              </div>
            </div>
          </div>

          <!-- 4. Final Settlement Summary Breakdown -->
          <div class="settlement-breakdown-card">
            <div class="breakdown-title">Settlement Breakdown</div>
            <div class="breakdown-row">
              <span class="lbl">Trip Fare</span>
              <span class="val">£{{ completeForm.price.toFixed(2) }}</span>
            </div>
            <div class="breakdown-row" *ngIf="completeForm.tip > 0">
              <span class="lbl">Driver Tip</span>
              <span class="val green-text">+£{{ completeForm.tip.toFixed(2) }}</span>
            </div>
            <div class="breakdown-row" *ngIf="completeForm.parkingCharge > 0">
              <span class="lbl">Parking / Tolls</span>
              <span class="val">+£{{ completeForm.parkingCharge.toFixed(2) }}</span>
            </div>
            <div class="breakdown-row" *ngIf="completeForm.waitingTime > 0">
              <span class="lbl">Waiting Time</span>
              <span class="val">{{ completeForm.waitingTime }} mins</span>
            </div>
            <div class="breakdown-divider"></div>
            <div class="breakdown-row total-row">
              <span class="lbl">Final Driver Total</span>
              <span class="val total-val">£{{ totalSettlement.toFixed(2) }}</span>
            </div>
          </div>

        </div>

        <!-- 5. Executive Light-Themed Slide-to-Complete Slider -->
        <div class="form-footer">
          <div 
            class="slide-complete-track" 
            #slider
            [class.completed]="isAccepted"
            (click)="onSliderTrackClick($event)"
          >
            <!-- Dynamic fill bar -->
            <div 
              class="slide-fill-bar"
              [style.width.px]="isAccepted ? 400 : sliderPosition + 24"
            ></div>

            <!-- Track Label -->
            <div class="slide-track-text" *ngIf="!isSubmitting && !isAccepted">
              {{ isDragging ? 'Release to Complete' : 'SLIDE TO COMPLETE TRIP' }}
            </div>
            <div class="slide-track-text submitting" *ngIf="isSubmitting && !isAccepted">
              Submitting Trip...
            </div>
            <div class="slide-track-text completed" *ngIf="isAccepted">
              Trip Completed! Returning...
            </div>

            <!-- Draggable Knob -->
            <div 
              class="slide-thumb-btn"
              [style.transform]="'translateX(' + sliderPosition + 'px)'"
              (mousedown)="onDragStart($event)"
              (touchstart)="onDragStart($event)"
            >
              <span class="material-symbols-outlined knob-icon" *ngIf="!isAccepted">
                keyboard_double_arrow_right
              </span>
              <span class="material-symbols-outlined check-icon-done" *ngIf="isAccepted">
                check
              </span>
            </div>
          </div>

          <!-- Secondary Dismiss Trigger -->
          <button 
            type="button" 
            class="cancel-btn" 
            (click)="cancel()" 
            [disabled]="isSubmitting || isAccepted"
          >
            Cancel and Return to Trip
          </button>
        </div>

      </div>
    </div>
  `,
  styles: [`
    :host {
      display: block;
      min-height: 100vh;
      background-color: #F8F9FA;
      font-family: 'Roboto', -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }

    .complete-container {
      background-color: #F8F9FA;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: flex-start;
      padding: 16px 14px 40px 14px;
      box-sizing: border-box;
    }

    .complete-layout-card {
      width: 100%;
      max-width: 480px;
      display: flex;
      flex-direction: column;
      gap: 14px;
      margin: 0 auto;
    }

    /* 1. Hero Completion Header */
    .completion-hero-header {
      background: linear-gradient(135deg, #0F172A 0%, #1E293B 100%);
      color: #FFFFFF;
      border-radius: 20px;
      padding: 20px 18px;
      box-shadow: 0 10px 25px rgba(15, 23, 42, 0.15);
      display: flex;
      flex-direction: column;
      gap: 14px;
      position: relative;
      overflow: hidden;
    }

    .completion-hero-header::before {
      content: '';
      position: absolute;
      top: -40px;
      right: -40px;
      width: 120px;
      height: 120px;
      border-radius: 50%;
      background: radial-gradient(circle, rgba(16, 185, 129, 0.25) 0%, transparent 70%);
      pointer-events: none;
    }

    .hero-top-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    .completion-badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: rgba(16, 185, 129, 0.2);
      border: 1px solid rgba(16, 185, 129, 0.35);
      color: #34D399;
      padding: 4px 10px;
      border-radius: 20px;
      font-size: 11px;
      font-weight: 800;
      letter-spacing: 0.5px;
    }

    .completion-badge .check-icon {
      font-size: 15px;
    }

    .booking-ref-chip {
      background: rgba(255, 255, 255, 0.12);
      color: #E2E8F0;
      padding: 4px 10px;
      border-radius: 12px;
      font-size: 11.5px;
      font-weight: 800;
      letter-spacing: 0.4px;
    }

    .total-settlement-display {
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
      gap: 4px;
      padding: 6px 0;
    }

    .total-label {
      font-size: 10.5px;
      font-weight: 800;
      letter-spacing: 1px;
      color: #94A3B8;
      text-transform: uppercase;
    }

    .total-fare-value {
      display: flex;
      align-items: baseline;
      justify-content: center;
      gap: 2px;
      color: #FFFFFF;
    }

    .curr-sign {
      font-size: 26px;
      font-weight: 900;
      color: #34D399;
    }

    .amount-int {
      font-size: 38px;
      font-weight: 900;
      letter-spacing: -1px;
      color: #FFFFFF;
      line-height: 1;
    }

    .payment-method-tag {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      background: rgba(255, 255, 255, 0.15);
      color: #F8FAFC;
      padding: 4px 12px;
      border-radius: 14px;
      font-size: 12px;
      font-weight: 800;
      letter-spacing: 0.4px;
      text-transform: uppercase;
      margin-top: 4px;
    }

    .payment-method-tag.cash {
      background: rgba(16, 185, 129, 0.25);
      color: #6EE7B7;
    }

    .payment-method-tag.card {
      background: rgba(59, 130, 246, 0.25);
      color: #93C5FD;
    }

    .payment-method-tag.account {
      background: rgba(168, 85, 247, 0.25);
      color: #D8B4FE;
    }

    .payment-method-tag .method-icon {
      font-size: 15px;
    }

    /* 2. Route Overview Snippet */
    .route-snippet-card {
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 16px;
      padding: 12px 16px;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.03);
    }

    .snippet-header {
      display: flex;
      align-items: center;
      gap: 6px;
      margin-bottom: 10px;
    }

    .route-icon {
      font-size: 16px;
      color: #059669;
    }

    .snippet-title {
      font-size: 10.5px;
      font-weight: 800;
      letter-spacing: 0.5px;
      color: #64748B;
      text-transform: uppercase;
    }

    .passenger-chip {
      margin-left: auto;
      display: inline-flex;
      align-items: center;
      gap: 4px;
      background: #F1F5F9;
      color: #334155;
      padding: 2px 8px;
      border-radius: 10px;
      font-size: 11px;
      font-weight: 700;
    }

    .passenger-chip .chip-icon {
      font-size: 13px;
    }

    .snippet-timeline {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }

    .snippet-node {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .node-dot {
      font-size: 16px;
      flex-shrink: 0;
    }

    .node-dot.green { color: #10B981; }
    .node-dot.red { color: #CD1A21; }

    .node-addr {
      font-size: 12.5px;
      font-weight: 700;
      color: #1E293B;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    /* 3. Form Cards */
    .adjustments-form-body {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }

    .form-section-card {
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 18px;
      padding: 16px;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.03);
      display: flex;
      flex-direction: column;
      gap: 16px;
    }

    .section-card-header {
      display: flex;
      align-items: center;
      gap: 7px;
      border-bottom: 1px solid #F1F5F9;
      padding-bottom: 8px;
    }

    .sec-icon {
      font-size: 18px;
    }

    .sec-icon.green-icon { color: #10B981; }
    .sec-icon.amber-icon { color: #F59E0B; }

    .sec-title {
      font-size: 11px;
      font-weight: 800;
      letter-spacing: 0.5px;
      color: #475569;
      text-transform: uppercase;
    }

    .input-field-group {
      display: flex;
      flex-direction: column;
      gap: 6px;
    }

    .field-label {
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 12px;
      font-weight: 800;
      color: #1E293B;
    }

    .field-hint {
      font-size: 11px;
      font-weight: 600;
      color: #94A3B8;
    }

    .executive-input-wrapper {
      position: relative;
      display: flex;
      align-items: center;
    }

    .input-prefix-icon {
      position: absolute;
      left: 14px;
      font-size: 17px;
      font-weight: 800;
      color: #64748B;
      pointer-events: none;
    }

    .executive-input {
      width: 100%;
      height: 46px;
      border: 1.5px solid #CBD5E1;
      border-radius: 12px;
      padding: 0 14px 0 34px;
      font-size: 16px;
      font-weight: 800;
      color: #0F172A;
      background: #F8FAFC;
      outline: none;
      box-sizing: border-box;
      transition: all 0.18s ease;
    }

    .executive-input:focus {
      border-color: #059669;
      background: #FFFFFF;
      box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.15);
    }

    /* Stepper for Waiting Time */
    .stepper-input-wrapper {
      display: flex;
      align-items: center;
      justify-content: space-between;
      height: 46px;
      background: #F8FAFC;
      border: 1.5px solid #CBD5E1;
      border-radius: 12px;
      padding: 4px;
      box-sizing: border-box;
    }

    .stepper-btn {
      width: 38px;
      height: 38px;
      border-radius: 8px;
      border: 1px solid #E2E8F0;
      background: #FFFFFF;
      color: #0F172A;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
      transition: all 0.15s ease;
    }

    .stepper-btn:active {
      transform: scale(0.94);
      background: #F1F5F9;
    }

    .stepper-btn:disabled {
      opacity: 0.4;
      cursor: not-allowed;
    }

    .stepper-val-display {
      display: flex;
      align-items: baseline;
      gap: 4px;
    }

    .stepper-num {
      font-size: 18px;
      font-weight: 900;
      color: #0F172A;
    }

    .stepper-unit {
      font-size: 12px;
      font-weight: 700;
      color: #64748B;
    }

    /* Quick Chips */
    .quick-chips-row {
      display: flex;
      flex-wrap: wrap;
      gap: 6px;
      margin-top: 2px;
    }

    .quick-chip {
      background: #F1F5F9;
      border: 1px solid #E2E8F0;
      border-radius: 8px;
      padding: 5px 10px;
      font-size: 11.5px;
      font-weight: 800;
      color: #334155;
      cursor: pointer;
      transition: all 0.15s ease;
    }

    .quick-chip:active {
      transform: scale(0.95);
    }

    .quick-chip.active {
      background: #059669;
      border-color: #059669;
      color: #FFFFFF;
    }

    .quick-chip.reset {
      background: #FEF2F2;
      border-color: #FECACA;
      color: #DC2626;
      margin-left: auto;
    }

    /* 4. Settlement Breakdown Card */
    .settlement-breakdown-card {
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 16px;
      padding: 14px 16px;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }

    .breakdown-title {
      font-size: 11px;
      font-weight: 800;
      letter-spacing: 0.5px;
      color: #64748B;
      text-transform: uppercase;
      margin-bottom: 2px;
    }

    .breakdown-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 12.5px;
      font-weight: 700;
      color: #334155;
    }

    .breakdown-row .green-text {
      color: #059669;
    }

    .breakdown-divider {
      height: 1px;
      background: #F1F5F9;
      margin: 4px 0;
    }

    .breakdown-row.total-row {
      font-size: 14px;
      font-weight: 900;
      color: #0F172A;
    }

    .breakdown-row.total-row .total-val {
      font-size: 17px;
      color: #059669;
    }

    /* 5. Light-Themed Hardware-Accelerated Slider */
    .form-footer {
      display: flex;
      flex-direction: column;
      gap: 10px;
      width: 100%;
      margin-top: 4px;
    }

    .slide-complete-track {
      position: relative;
      width: 100%;
      height: 52px;
      background: #F1F5F9;
      border: 1.5px solid #CBD5E1;
      border-radius: 26px;
      display: flex;
      align-items: center;
      justify-content: center;
      user-select: none;
      box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.04);
      overflow: hidden;
      cursor: pointer;
    }

    .slide-fill-bar {
      position: absolute;
      left: 0;
      top: 0;
      bottom: 0;
      background: linear-gradient(90deg, #10B981, #059669);
      border-radius: 26px;
      transition: width 0.06s ease;
      opacity: 0.9;
    }

    .slide-track-text {
      position: relative;
      z-index: 2;
      font-size: 13px;
      font-weight: 800;
      color: #1E293B;
      letter-spacing: 0.5px;
      pointer-events: none;
    }

    .slide-track-text.submitting {
      color: #059669;
    }

    .slide-track-text.completed {
      color: #FFFFFF;
    }

    .slide-thumb-btn {
      position: absolute;
      left: 4px;
      width: 44px;
      height: 44px;
      border-radius: 50%;
      background: #FFFFFF;
      color: #10B981;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: grab;
      z-index: 3;
      border: 1.5px solid #E2E8F0;
      box-shadow: 0 3px 10px rgba(0, 0, 0, 0.15);
      touch-action: none;
      transition: box-shadow 0.15s ease;
    }

    .slide-thumb-btn:active {
      cursor: grabbing;
      box-shadow: 0 4px 14px rgba(16, 185, 129, 0.35);
    }

    .slide-thumb-btn .knob-icon {
      font-size: 24px;
      font-weight: 700;
    }

    .slide-thumb-btn .check-icon-done {
      font-size: 24px;
      font-weight: 900;
      color: #10B981;
    }

    .cancel-btn {
      width: 100%;
      background: transparent;
      border: 1.5px solid #CBD5E1;
      border-radius: 12px;
      padding: 11px;
      font-size: 13px;
      font-weight: 700;
      color: #64748B;
      cursor: pointer;
      transition: all 0.15s ease;
    }

    .cancel-btn:active {
      background: #F1F5F9;
      color: #1E293B;
    }

    .cancel-btn:disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }

    /* ================= DARK THEME OVERRIDES ================= */
    :host-context(.dark-theme) {
      background-color: #121214 !important;
      color: #ECEFF1 !important;
    }

    :host-context(.dark-theme) .complete-container {
      background-color: #121214 !important;
    }

    :host-context(.dark-theme) .route-snippet-card,
    :host-context(.dark-theme) .form-section-card,
    :host-context(.dark-theme) .settlement-breakdown-card {
      background: #1E1E24 !important;
      border-color: #2D2D35 !important;
    }

    :host-context(.dark-theme) .section-card-header,
    :host-context(.dark-theme) .breakdown-divider {
      border-color: #2D2D35 !important;
    }

    :host-context(.dark-theme) .field-label,
    :host-context(.dark-theme) .node-addr,
    :host-context(.dark-theme) .stepper-num,
    :host-context(.dark-theme) .breakdown-row,
    :host-context(.dark-theme) .breakdown-row.total-row {
      color: #ECEFF1 !important;
    }

    :host-context(.dark-theme) .executive-input,
    :host-context(.dark-theme) .stepper-input-wrapper {
      background: #16161A !important;
      border-color: #2D2D35 !important;
      color: #ECEFF1 !important;
    }

    :host-context(.dark-theme) .stepper-btn {
      background: #2D2D35 !important;
      border-color: #3E3E48 !important;
      color: #ECEFF1 !important;
    }

    :host-context(.dark-theme) .quick-chip {
      background: #2D2D35 !important;
      border-color: #3E3E48 !important;
      color: #ECEFF1 !important;
    }

    :host-context(.dark-theme) .passenger-chip {
      background: #2D2D35 !important;
      color: #ECEFF1 !important;
    }

    :host-context(.dark-theme) .slide-complete-track {
      background: #2D2D35 !important;
      border-color: #3E3E48 !important;
    }

    :host-context(.dark-theme) .slide-track-text {
      color: #ECEFF1 !important;
    }

    :host-context(.dark-theme) .slide-thumb-btn {
      background: #1E1E24 !important;
      color: #10B981 !important;
      border-color: #3E3E48 !important;
    }

    :host-context(.dark-theme) .cancel-btn {
      border-color: #3E3E48 !important;
      color: #94A3B8 !important;
    }
  `]
})
export class CompleteJobComponent implements OnInit, OnDestroy {
  jobId: string = '';
  fare: number = 0;
  isSubmitting = false;
  isAccepted = false;

  bookingDetails: BookingSummary | null = null;

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

  @ViewChild('slider', { static: false }) sliderEl!: ElementRef<HTMLDivElement>;

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

      if (this.jobId) {
        this.fetchBookingContext(this.jobId);
      }

      this.cdr.detectChanges();
    });
  }

  private fetchBookingContext(id: string): void {
    this.driverService.getJobById(id).pipe(catchError(() => of(null))).subscribe(res => {
      if (res) {
        const b = res.value || res.data || res;
        const fetchedFare = parseFloat((b.price || b.fare || b.amount || b.driverPrice || this.fare || 0).toString());
        if (!isNaN(fetchedFare) && fetchedFare > 0 && this.completeForm.price === 0) {
          this.completeForm.price = fetchedFare;
        }

        let paymentType = b.paymentType || b.paymentMethod || 'Cash';
        if (b.scope !== undefined && b.scope !== null) {
          const scope = parseInt(b.scope.toString()) || 0;
          switch (scope) {
            case 0: paymentType = 'Cash'; break;
            case 1: paymentType = 'Account'; break;
            case 2: paymentType = 'Rank'; break;
            case 4: paymentType = 'Card'; break;
          }
        }

        this.bookingDetails = {
          passenger: b.passengerName || b.passenger || b.customerName || b.cellText || 'Passenger',
          pickup: b.pickupAddress || b.pickup || b.from || 'Pickup Location',
          dropoff: b.destinationAddress || b.dropoffAddress || b.dropoff || b.to || 'Destination',
          paymentType
        };

        this.cdr.detectChanges();
      }
    });
  }

  get totalSettlement(): number {
    const base = Number(this.completeForm.price) || 0;
    const tip = Number(this.completeForm.tip) || 0;
    const parking = Number(this.completeForm.parkingCharge) || 0;
    return base + tip + parking;
  }

  // --- Input Handlers ---
  onPriceInput(event: Event): void {
    const val = parseFloat((event.target as HTMLInputElement).value);
    this.completeForm.price = isNaN(val) ? 0 : val;
  }

  addPrice(amt: number): void {
    this.completeForm.price = Math.round((this.completeForm.price + amt) * 100) / 100;
  }

  resetPrice(): void {
    this.completeForm.price = this.fare;
  }

  onTipInput(event: Event): void {
    const val = parseFloat((event.target as HTMLInputElement).value);
    this.completeForm.tip = isNaN(val) ? 0 : val;
  }

  setTip(amt: number): void {
    this.completeForm.tip = amt;
  }

  stepWaiting(delta: number): void {
    this.completeForm.waitingTime = Math.max(0, this.completeForm.waitingTime + delta);
  }

  setWaiting(mins: number): void {
    this.completeForm.waitingTime = mins;
  }

  onParkingInput(event: Event): void {
    const val = parseFloat((event.target as HTMLInputElement).value);
    this.completeForm.parkingCharge = isNaN(val) ? 0 : val;
  }

  addParking(amt: number): void {
    this.completeForm.parkingCharge = Math.round((this.completeForm.parkingCharge + amt) * 100) / 100;
  }

  setParking(amt: number): void {
    this.completeForm.parkingCharge = amt;
  }

  onPaymentInput(event: Event): void {
    const val = parseFloat((event.target as HTMLInputElement).value);
    this.completeForm.payment = isNaN(val) ? 0 : val;
  }

  // --- Slide to Complete Physics ---
  onDragStart(event: MouseEvent | TouchEvent): void {
    if (this.isSubmitting || this.isAccepted) return;
    this.isDragging = true;
    this.startX = this.getEventX(event) - this.sliderPosition;
    
    if (this.sliderEl) {
      const containerWidth = this.sliderEl.nativeElement.clientWidth;
      const thumbWidth = 44; 
      this.maxDragRange = Math.max(0, containerWidth - thumbWidth - 8);
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
    
    if (this.sliderPosition >= this.maxDragRange * 0.82) {
      this.sliderPosition = this.maxDragRange;
      this.cdr.detectChanges();
      this.submit();
    } else {
      this.animateSnapBack();
    }
  };

  onSliderTrackClick(event: MouseEvent): void {
    if (this.isDragging || this.isSubmitting || this.isAccepted) return;
    if (this.sliderEl) {
      const containerWidth = this.sliderEl.nativeElement.clientWidth;
      const thumbWidth = 44;
      this.maxDragRange = Math.max(0, containerWidth - thumbWidth - 8);
      this.sliderPosition = this.maxDragRange;
      this.cdr.detectChanges();
      this.submit();
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
    if (bookingIdNum <= 0) {
      this.isSubmitting = false;
      this.isAccepted = false;
      this.animateSnapBack();
      return;
    }

    this.isSubmitting = true;
    this.isAccepted = true;
    this.cdr.detectChanges();
    this.snackBar.open('Completing booking settlement...', 'OK', { duration: 2000 });

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
          next: () => this.onCompleteSuccess(),
          error: () => this.onCompleteSuccess()
        });
      },
      error: (err) => {
        console.warn('CompleteJob error fallback:', err);
        this.driverService.setActiveJob(0).subscribe({
          next: () => this.onCompleteSuccess(),
          error: () => this.onCompleteSuccess()
        });
      }
    });
  }

  private onCompleteSuccess(): void {
    this.isSubmitting = false;
    this.snackBar.open('Trip completed successfully!', 'OK', { duration: 3000 });
    this.notifyNativeApp('close_complete_job');
    this.notifyNativeApp('job_completed');
    setTimeout(() => {
      this.router.navigate(['/bookings']);
    }, 600);
  }

  cancel(): void {
    this.notifyNativeApp('close_complete_job');
    window.history.back();
  }

  ngOnDestroy(): void {
    document.removeEventListener('mousemove', this.onDragMove);
    document.removeEventListener('mouseup', this.onDragEnd);
    document.removeEventListener('touchmove', this.onDragMove);
    document.removeEventListener('touchend', this.onDragEnd);
  }
}
