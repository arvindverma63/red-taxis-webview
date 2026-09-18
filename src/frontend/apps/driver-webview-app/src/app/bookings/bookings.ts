import { Component, OnInit, ChangeDetectorRef, ViewChild, ElementRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatDividerModule } from '@angular/material/divider';
import { DriverService } from '../services/driver.service';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { Router } from '@angular/router';

interface ViaStop {
  address: string;
  postCode?: string;
}

interface Booking {
  id: string;
  pickup: string;
  pickupPostCode?: string;
  dropoff: string;
  destinationPostCode?: string;
  vias?: ViaStop[];
  time: string;
  date: string;
  fullDateTimeStr?: string;
  fare: number;
  paymentType: string;
  status: 'Completed' | 'Upcoming' | 'Cancelled';
  passenger: string;
  phoneNumber?: string;
  email?: string;
  passengerCount?: number;
  notes?: string;
  vehicleType: string;
  durationMinutes?: number;
  mileageText?: string;
  bookedByName?: string;
  accountNumber?: string;
}

@Component({
  selector: 'app-bookings',
  standalone: true,
  imports: [
    CommonModule,
    MatCardModule,
    MatDividerModule,
    MatSnackBarModule
  ],
  template: `
    <div class="bookings-container">
      <!-- 1. Single-Row Segmented Tab Bar -->
      <div class="filter-tab-bar">
        <button 
          *ngFor="let tab of tabs" 
          class="tab-btn" 
          [class.active]="activeTab === tab"
          (click)="setTab(tab)"
        >
          <span class="tab-label">{{ tab }}</span>
          <span class="tab-count">({{ getTabCount(tab) }})</span>
        </button>
      </div>

      <!-- 2. Loading State -->
      <div *ngIf="isLoading" class="loading-state animated-fade-in">
        <div class="spinner"></div>
        <p class="loading-text">Loading bookings...</p>
      </div>

      <!-- 3. Bookings List -->
      <div class="bookings-list animated-fade-in" *ngIf="!isLoading">
        <!-- Empty State -->
        <div *ngIf="filteredBookings.length === 0" class="empty-state">
          <div class="empty-icon-box">
            <span class="material-symbols-outlined">assignment_late</span>
          </div>
          <p class="empty-title">No {{ activeTab.toLowerCase() }} bookings found</p>
          <p class="empty-subtitle">New allocations and scheduled trips will appear here.</p>
          <button class="retry-btn" (click)="loadBookings()">
            <span class="material-symbols-outlined">refresh</span>
            <span>Refresh</span>
          </button>
        </div>

        <!-- Booking Cards -->
        <div 
          *ngFor="let booking of filteredBookings" 
          class="booking-card" 
          (click)="openDetails(booking)"
        >
          <!-- Card Header: ID, Status, Fare -->
          <div class="card-header-row">
            <div class="header-left">
              <span class="booking-ref-badge">#{{ booking.id }}</span>
              <span class="status-pill" [ngClass]="booking.status.toLowerCase()">
                <span class="status-dot" *ngIf="booking.status === 'Upcoming'"></span>
                <span>{{ booking.status }}</span>
              </span>
              <span class="payment-pill" [ngClass]="booking.paymentType.toLowerCase()">
                {{ booking.paymentType }}
              </span>
            </div>
            <div class="booking-fare-text">
              <span class="currency-symbol">£</span>
              <span class="fare-num">{{ booking.fare.toFixed(2) }}</span>
            </div>
          </div>

          <!-- Journey Route Visual -->
          <div class="journey-route-preview">
            <div class="route-tracker-col">
              <span class="route-node pickup-node"></span>
              <div class="route-stem"></div>
              <span class="route-node dropoff-node"></span>
            </div>

            <div class="route-addresses-col">
              <!-- Pickup -->
              <div class="address-preview-row">
                <span class="address-time-pill">{{ booking.time }}</span>
                <span class="address-text pickup" [title]="booking.pickup">{{ booking.pickup }}</span>
              </div>

              <!-- Via stops counter if any -->
              <div class="via-indicator-row" *ngIf="booking.vias && booking.vias.length > 0">
                <span class="material-symbols-outlined via-icon">alt_route</span>
                <span class="via-text">+{{ booking.vias.length }} Via {{ booking.vias.length === 1 ? 'Stop' : 'Stops' }}</span>
              </div>

              <!-- Dropoff -->
              <div class="address-preview-row">
                <span class="address-time-pill dropoff-time">{{ booking.date }}</span>
                <span class="address-text dropoff" [title]="booking.dropoff">{{ booking.dropoff }}</span>
              </div>
            </div>
          </div>

          <!-- Card Footer Info -->
          <div class="card-footer-row">
            <div class="passenger-tag">
              <span class="material-symbols-outlined pass-icon">person</span>
              <span class="passenger-name">{{ booking.passenger }}</span>
            </div>
            <div class="view-details-action">
              <span>Details</span>
              <span class="material-symbols-outlined">chevron_right</span>
            </div>
          </div>
        </div>
      </div>

      <!-- ============================================================== -->
      <!-- 4. PROFESSIONAL BOOKING DETAILS MODAL / BOTTOM SHEET           -->
      <!-- ============================================================== -->
      <div class="modal-backdrop animated-fade-in" *ngIf="selectedBooking" (click)="closeDetails()">
        <div class="modal-sheet" (click)="$event.stopPropagation()">
          
          <!-- Sheet Grabber -->
          <div class="sheet-grabber-bar">
            <div class="sheet-grabber"></div>
          </div>

          <!-- Sheet Header: Passenger, ID & Status -->
          <div class="sheet-header">
            <div class="sheet-header-left">
              <div class="passenger-avatar-circle">
                <span class="material-symbols-outlined">person</span>
              </div>
              <div class="passenger-title-col">
                <div class="name-id-row">
                  <h3 class="sheet-passenger-name">{{ selectedBooking.passenger }}</h3>
                  <span class="sheet-ref-chip" (click)="copyText(selectedBooking.id, 'Booking ID copied')">
                    #{{ selectedBooking.id }}
                  </span>
                </div>
                <div class="sheet-schedule-row">
                  <span class="material-symbols-outlined schedule-icon">calendar_today</span>
                  <span>{{ selectedBooking.fullDateTimeStr || (selectedBooking.date + ' at ' + selectedBooking.time) }}</span>
                </div>
              </div>
            </div>

            <button class="sheet-close-btn" (click)="closeDetails()" title="Close Details">
              <span class="material-symbols-outlined">close</span>
            </button>
          </div>

          <!-- Quick Actions Bar (Call, SMS, Start Trip / Arrived) -->
          <div class="sheet-quick-actions">
            <!-- Active Job Switcher / Status Advance -->
            <button 
              *ngIf="selectedBooking.status === 'Upcoming' && selectedBooking.id === activeBookingId"
              class="action-pill status-toggle" 
              [ngClass]="getTripProgress(selectedBooking.id)"
              (click)="advanceTripStatus(selectedBooking)"
            >
              <span class="material-symbols-outlined">{{ getStatusIcon(selectedBooking.id) }}</span>
              <span>{{ getStatusLabel(selectedBooking.id) }}</span>
            </button>

            <button 
              *ngIf="selectedBooking.status === 'Upcoming' && selectedBooking.id !== activeBookingId"
              class="action-pill start-trip-btn" 
              (click)="setActiveJob(selectedBooking)"
              [disabled]="isSettingActive"
            >
              <span class="material-symbols-outlined">play_arrow</span>
              <span>{{ isSettingActive ? 'Starting...' : 'Start Active Trip' }}</span>
            </button>

            <!-- Passenger Direct Contact -->
            <a 
              *ngIf="selectedBooking.phoneNumber" 
              [href]="'tel:' + selectedBooking.phoneNumber" 
              class="action-pill call-btn"
            >
              <span class="material-symbols-outlined">call</span>
              <span>Call</span>
            </a>

            <a 
              *ngIf="selectedBooking.phoneNumber" 
              [href]="'sms:' + selectedBooking.phoneNumber" 
              class="action-pill sms-btn"
            >
              <span class="material-symbols-outlined">chat</span>
              <span>SMS</span>
            </a>

            <button 
              *ngIf="selectedBooking.phoneNumber" 
              class="action-pill copy-btn"
              (click)="copyText(selectedBooking.phoneNumber, 'Phone number copied')"
              title="Copy Phone"
            >
              <span class="material-symbols-outlined">content_copy</span>
            </button>
          </div>

          <!-- Scrollable Details Body -->
          <div class="sheet-body-scroll">

            <!-- 1. Executive Journey Route Card -->
            <div class="detail-block-card">
              <div class="block-header">
                <span class="material-symbols-outlined header-icon green-icon">alt_route</span>
                <span class="block-title">JOURNEY ROUTE</span>
              </div>

              <div class="route-stepper-container">
                <!-- Pickup Point -->
                <div class="stepper-stop pickup">
                  <div class="stop-node-indicator green">
                    <span class="material-symbols-outlined">my_location</span>
                  </div>
                  <div class="stop-content">
                    <div class="stop-meta-row">
                      <span class="stop-type-tag green">PICKUP POINT</span>
                      <span class="postcode-badge" *ngIf="selectedBooking.pickupPostCode">
                        {{ selectedBooking.pickupPostCode }}
                      </span>
                    </div>
                    <p class="stop-address-txt">{{ selectedBooking.pickup }}</p>
                  </div>
                </div>

                <!-- Via Stops (if any) -->
                <div class="stepper-stop via" *ngFor="let via of selectedBooking.vias; let i = index">
                  <div class="stop-node-indicator amber">
                    <span class="material-symbols-outlined">pin_drop</span>
                  </div>
                  <div class="stop-content">
                    <div class="stop-meta-row">
                      <span class="stop-type-tag amber">VIA STOP {{ i + 1 }}</span>
                      <span class="postcode-badge" *ngIf="via.postCode">{{ via.postCode }}</span>
                    </div>
                    <p class="stop-address-txt">{{ via.address }}</p>
                  </div>
                </div>

                <!-- Dropoff Point -->
                <div class="stepper-stop dropoff">
                  <div class="stop-node-indicator red">
                    <span class="material-symbols-outlined">location_on</span>
                  </div>
                  <div class="stop-content">
                    <div class="stop-meta-row">
                      <span class="stop-type-tag red">DESTINATION</span>
                      <span class="postcode-badge" *ngIf="selectedBooking.destinationPostCode">
                        {{ selectedBooking.destinationPostCode }}
                      </span>
                    </div>
                    <p class="stop-address-txt">{{ selectedBooking.dropoff }}</p>
                  </div>
                </div>
              </div>
            </div>

            <!-- 2. Financial Summary & Journey Telemetry -->
            <div class="detail-block-card">
              <div class="block-header">
                <span class="material-symbols-outlined header-icon red-icon">payments</span>
                <span class="block-title">FARE & METRICS</span>
              </div>

              <div class="fare-metrics-grid">
                <!-- Total Fare Hero -->
                <div class="metric-tile fare-tile">
                  <span class="tile-label">TOTAL FARE</span>
                  <div class="tile-main-fare">
                    <span class="cur">£</span>
                    <span class="amt">{{ selectedBooking.fare.toFixed(2) }}</span>
                  </div>
                  <span class="payment-type-tag" [ngClass]="selectedBooking.paymentType.toLowerCase()">
                    {{ selectedBooking.paymentType }}
                  </span>
                </div>

                <!-- Estimated Duration -->
                <div class="metric-tile" *ngIf="selectedBooking.durationMinutes">
                  <span class="tile-label">EST. DURATION</span>
                  <div class="tile-value-row">
                    <span class="material-symbols-outlined tile-ico">timer</span>
                    <span class="tile-val">{{ selectedBooking.durationMinutes }} mins</span>
                  </div>
                </div>

                <!-- Estimated Distance -->
                <div class="metric-tile" *ngIf="selectedBooking.mileageText">
                  <span class="tile-label">EST. DISTANCE</span>
                  <div class="tile-value-row">
                    <span class="material-symbols-outlined tile-ico">route</span>
                    <span class="tile-val">{{ selectedBooking.mileageText }}</span>
                  </div>
                </div>
              </div>
            </div>

            <!-- 3. Passenger & Booking Specifications -->
            <div class="detail-block-card">
              <div class="block-header">
                <span class="material-symbols-outlined header-icon blue-icon">info</span>
                <span class="block-title">BOOKING SPECIFICATIONS</span>
              </div>

              <div class="specs-grid">
                <div class="spec-row">
                  <span class="spec-label">Booking Status</span>
                  <span class="status-pill" [ngClass]="selectedBooking.status.toLowerCase()">
                    {{ selectedBooking.status }}
                  </span>
                </div>

                <div class="spec-row">
                  <span class="spec-label">Vehicle Class</span>
                  <span class="spec-val font-bold">{{ selectedBooking.vehicleType }}</span>
                </div>

                <div class="spec-row" *ngIf="selectedBooking.accountNumber">
                  <span class="spec-label">Account Code</span>
                  <span class="spec-val font-mono">{{ selectedBooking.accountNumber }}</span>
                </div>

                <div class="spec-row" *ngIf="selectedBooking.passengerCount">
                  <span class="spec-label">Passengers</span>
                  <span class="spec-val">{{ selectedBooking.passengerCount }} Passenger{{ selectedBooking.passengerCount > 1 ? 's' : '' }}</span>
                </div>

                <div class="spec-row" *ngIf="selectedBooking.bookedByName">
                  <span class="spec-label">Booked By</span>
                  <span class="spec-val">{{ selectedBooking.bookedByName }}</span>
                </div>

                <div class="spec-row" *ngIf="selectedBooking.phoneNumber">
                  <span class="spec-label">Contact Number</span>
                  <span class="spec-val font-mono">{{ selectedBooking.phoneNumber }}</span>
                </div>

                <div class="spec-row" *ngIf="selectedBooking.email">
                  <span class="spec-label">Email Address</span>
                  <span class="spec-val text-ellipsis">{{ selectedBooking.email }}</span>
                </div>
              </div>
            </div>

            <!-- 4. Driver Notes & Dispatch Instructions -->
            <div class="detail-block-card notes-block" *ngIf="selectedBooking.notes && selectedBooking.notes.trim().length > 0">
              <div class="block-header">
                <span class="material-symbols-outlined header-icon amber-icon">speaker_notes</span>
                <span class="block-title">DISPATCH NOTES & INSTRUCTIONS</span>
              </div>
              <div class="notes-box">
                <p class="notes-text">{{ selectedBooking.notes }}</p>
              </div>
            </div>

          </div>

          <!-- Sheet Footer (Slide to Complete / Dismiss) -->
          <div class="sheet-footer">
            <!-- Slide to Complete Widget -->
            <div class="slide-complete-container" *ngIf="selectedBooking.status === 'Upcoming' && selectedBooking.id === activeBookingId">
              <div 
                #sliderEl
                class="slide-complete-track"
                [class.submitting]="isSubmitting"
              >
                <div 
                  class="slide-fill-bar" 
                  [style.width.px]="sliderPosition + 24"
                ></div>
                <div class="slide-track-text" *ngIf="!isSubmitting">
                  {{ isDragging ? 'Release to Complete' : 'Slide to Complete Trip' }}
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
                  <span class="material-symbols-outlined select-none">keyboard_double_arrow_right</span>
                </div>
              </div>
            </div>

            <button class="sheet-dismiss-btn" (click)="closeDetails()">Close Details</button>
          </div>

        </div>
      </div>

    </div>
  `,
  styles: [`
    :host {
      display: block;
      min-height: 100vh;
      background-color: var(--background-color, #F8F9FA);
      color: var(--text-primary, #263238);
      font-family: 'Roboto', -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }

    .bookings-container {
      padding: 10px 12px 36px 12px;
      max-width: 640px;
      margin: 0 auto;
      box-sizing: border-box;
      position: relative;
    }

    /* 1. Filter Tab Bar */
    .filter-tab-bar {
      display: flex;
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 20px;
      padding: 3px;
      margin-bottom: 12px;
      gap: 4px;
      box-shadow: 0 1px 4px rgba(0, 0, 0, 0.03);
    }
    .tab-btn {
      flex: 1;
      border: none;
      background: transparent;
      padding: 7px 4px;
      border-radius: 16px;
      font-size: 11px;
      font-weight: 700;
      color: #64748B;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 3px;
      cursor: pointer;
      transition: all 0.15s ease;
      white-space: nowrap;
      user-select: none;
    }
    .tab-btn.active {
      background: #CD1A21;
      color: #FFFFFF;
      box-shadow: 0 2px 6px rgba(205, 26, 33, 0.25);
    }
    .tab-count {
      font-size: 10px;
      opacity: 0.85;
    }

    /* 2. Loading & Empty State */
    .loading-state {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 40px 16px;
      gap: 10px;
    }
    .spinner {
      width: 32px;
      height: 32px;
      border: 3px solid #E2E8F0;
      border-top-color: #CD1A21;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
    }
    .loading-text {
      font-size: 12px;
      color: #64748B;
      font-weight: 500;
      margin: 0;
    }

    .empty-state {
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 14px;
      padding: 32px 16px;
      text-align: center;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 6px;
    }
    .empty-icon-box {
      width: 44px;
      height: 44px;
      border-radius: 50%;
      background: #F1F5F9;
      color: #94A3B8;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-bottom: 4px;
    }
    .empty-icon-box .material-symbols-outlined {
      font-size: 24px;
    }
    .empty-title {
      margin: 0;
      font-size: 13px;
      font-weight: 700;
      color: #0F172A;
    }
    .empty-subtitle {
      margin: 0 0 8px 0;
      font-size: 11px;
      color: #64748B;
    }
    .retry-btn {
      background: #F1F5F9;
      border: 1px solid #CBD5E1;
      padding: 6px 14px;
      border-radius: 8px;
      font-size: 11px;
      font-weight: 600;
      color: #334155;
      display: flex;
      align-items: center;
      gap: 4px;
      cursor: pointer;
    }
    .retry-btn .material-symbols-outlined {
      font-size: 14px;
    }

    /* 3. Booking Summary Cards */
    .bookings-list {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .booking-card {
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 14px;
      padding: 12px 14px;
      cursor: pointer;
      box-shadow: 0 2px 6px rgba(0, 0, 0, 0.02);
      transition: transform 0.12s ease, box-shadow 0.12s ease;
    }
    .booking-card:active {
      transform: scale(0.99);
      background: #F8FAFC;
    }

    .card-header-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 10px;
    }
    .header-left {
      display: flex;
      align-items: center;
      gap: 6px;
      flex-wrap: wrap;
    }
    .booking-ref-badge {
      font-size: 11px;
      font-weight: 700;
      font-family: monospace;
      color: #0F172A;
      background: #F1F5F9;
      padding: 2px 6px;
      border-radius: 5px;
    }
    .status-pill {
      font-size: 9.5px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.2px;
      padding: 2px 6px;
      border-radius: 6px;
      display: inline-flex;
      align-items: center;
      gap: 3px;
    }
    .status-pill.upcoming { background: #DCFCE7; color: #15803D; }
    .status-pill.completed { background: #E0F2FE; color: #0369A1; }
    .status-pill.cancelled { background: #FEE2E2; color: #B91C1C; }
    .status-dot {
      width: 5px;
      height: 5px;
      border-radius: 50%;
      background: #16A34A;
      animation: pulse 1.8s infinite;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.5; transform: scale(1.3); }
    }
    .payment-pill {
      font-size: 9.5px;
      font-weight: 700;
      padding: 2px 6px;
      border-radius: 6px;
      background: #F1F5F9;
      color: #475569;
      text-transform: uppercase;
    }
    .payment-pill.cash { background: #DCFCE7; color: #166534; }
    .payment-pill.account { background: #F3E8FF; color: #7E22CE; }
    .payment-pill.card { background: #E0E7FF; color: #3730A3; }

    .booking-fare-text {
      font-weight: 800;
      color: #0F172A;
      font-size: 16px;
      display: flex;
      align-items: baseline;
      gap: 1px;
    }
    .currency-symbol {
      font-size: 13px;
      color: #CD1A21;
    }

    /* Journey Route Visual */
    .journey-route-preview {
      display: flex;
      gap: 10px;
      padding: 4px 0 8px 0;
    }
    .route-tracker-col {
      display: flex;
      flex-direction: column;
      align-items: center;
      padding-top: 5px;
      width: 10px;
    }
    .route-node {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      flex-shrink: 0;
    }
    .route-node.pickup-node { background: #10B981; }
    .route-node.dropoff-node { background: #EF4444; }
    .route-stem {
      width: 2px;
      flex: 1;
      min-height: 20px;
      background: #CBD5E1;
      margin: 2px 0;
    }

    .route-addresses-col {
      flex: 1;
      min-width: 0;
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .address-preview-row {
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .address-time-pill {
      font-size: 9.5px;
      font-weight: 700;
      background: #F1F5F9;
      color: #475569;
      padding: 1px 5px;
      border-radius: 4px;
      white-space: nowrap;
    }
    .address-text {
      font-size: 12px;
      font-weight: 600;
      color: #1E293B;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .via-indicator-row {
      display: flex;
      align-items: center;
      gap: 4px;
      font-size: 10px;
      font-weight: 600;
      color: #D97706;
      padding-left: 2px;
    }
    .via-icon {
      font-size: 13px;
    }

    .card-footer-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      border-top: 1px solid #F1F5F9;
      padding-top: 8px;
      margin-top: 2px;
      font-size: 11px;
    }
    .passenger-tag {
      display: flex;
      align-items: center;
      gap: 4px;
      color: #475569;
      font-weight: 500;
    }
    .pass-icon {
      font-size: 14px;
      color: #94A3B8;
    }
    .view-details-action {
      display: flex;
      align-items: center;
      gap: 1px;
      color: #CD1A21;
      font-weight: 700;
      font-size: 11px;
    }
    .view-details-action .material-symbols-outlined {
      font-size: 14px;
    }

    /* ================= 4. MODAL / BOTTOM SHEET ================= */
    .modal-backdrop {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(15, 23, 42, 0.65);
      backdrop-filter: blur(4px);
      z-index: 1000;
      display: flex;
      align-items: flex-end;
      justify-content: center;
    }
    .modal-sheet {
      background: #FFFFFF;
      border-top-left-radius: 20px;
      border-top-right-radius: 20px;
      max-width: 600px;
      width: 100%;
      max-height: 88vh;
      display: flex;
      flex-direction: column;
      box-shadow: 0 -10px 30px rgba(0, 0, 0, 0.2);
      animation: slideUp 0.22s cubic-bezier(0.16, 1, 0.3, 1);
    }
    @keyframes slideUp {
      from { transform: translateY(100%); }
      to { transform: translateY(0); }
    }

    .sheet-grabber-bar {
      padding: 8px 0 2px 0;
      display: flex;
      justify-content: center;
    }
    .sheet-grabber {
      width: 36px;
      height: 4px;
      border-radius: 2px;
      background: #CBD5E1;
    }

    .sheet-header {
      padding: 8px 16px 10px 16px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      border-bottom: 1px solid #F1F5F9;
    }
    .sheet-header-left {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .passenger-avatar-circle {
      width: 40px;
      height: 40px;
      border-radius: 50%;
      background: #FEE2E2;
      color: #DC2626;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .passenger-avatar-circle .material-symbols-outlined {
      font-size: 22px;
    }
    .passenger-title-col {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .name-id-row {
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .sheet-passenger-name {
      margin: 0;
      font-size: 15px;
      font-weight: 700;
      color: #0F172A;
    }
    .sheet-ref-chip {
      font-size: 10px;
      font-weight: 700;
      font-family: monospace;
      color: #0F172A;
      background: #F1F5F9;
      padding: 1px 5px;
      border-radius: 4px;
      cursor: pointer;
    }
    .sheet-schedule-row {
      display: flex;
      align-items: center;
      gap: 4px;
      font-size: 11px;
      color: #64748B;
    }
    .schedule-icon {
      font-size: 13px;
    }
    .sheet-close-btn {
      background: #F1F5F9;
      border: none;
      width: 30px;
      height: 30px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      color: #64748B;
    }

    /* Quick Actions */
    .sheet-quick-actions {
      padding: 10px 16px;
      display: flex;
      gap: 8px;
      border-bottom: 1px solid #F1F5F9;
      overflow-x: auto;
    }
    .action-pill {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      padding: 7px 12px;
      border-radius: 20px;
      font-size: 11.5px;
      font-weight: 700;
      cursor: pointer;
      text-decoration: none;
      white-space: nowrap;
      border: 1px solid transparent;
      transition: opacity 0.15s ease;
    }
    .action-pill:active { opacity: 0.8; }
    .action-pill .material-symbols-outlined { font-size: 16px; }

    .action-pill.start-trip-btn {
      background: #CD1A21;
      color: #FFFFFF;
    }
    .action-pill.status-toggle {
      background: #10B981;
      color: #FFFFFF;
    }
    .action-pill.call-btn {
      background: #DCFCE7;
      color: #15803D;
      border-color: #BBF7D0;
    }
    .action-pill.sms-btn {
      background: #E0F2FE;
      color: #0369A1;
      border-color: #BAE6FD;
    }
    .action-pill.copy-btn {
      background: #F1F5F9;
      color: #475569;
      border-color: #E2E8F0;
      padding: 7px 9px;
    }

    /* Sheet Scroll Area */
    .sheet-body-scroll {
      padding: 12px 16px;
      overflow-y: auto;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }

    .detail-block-card {
      background: #F8FAFC;
      border: 1px solid #E2E8F0;
      border-radius: 12px;
      padding: 10px 12px;
    }
    .block-header {
      display: flex;
      align-items: center;
      gap: 6px;
      margin-bottom: 8px;
    }
    .header-icon { font-size: 16px; }
    .header-icon.green-icon { color: #10B981; }
    .header-icon.red-icon { color: #CD1A21; }
    .header-icon.blue-icon { color: #0284C7; }
    .header-icon.amber-icon { color: #D97706; }
    .block-title {
      font-size: 10.5px;
      font-weight: 700;
      letter-spacing: 0.4px;
      color: #64748B;
      text-transform: uppercase;
    }

    /* Journey Route Stepper */
    .route-stepper-container {
      display: flex;
      flex-direction: column;
      gap: 10px;
      position: relative;
    }
    .stepper-stop {
      display: flex;
      gap: 10px;
      align-items: flex-start;
    }
    .stop-node-indicator {
      width: 28px;
      height: 28px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }
    .stop-node-indicator .material-symbols-outlined { font-size: 15px; }
    .stop-node-indicator.green { background: #DCFCE7; color: #16A34A; }
    .stop-node-indicator.amber { background: #FEF3C7; color: #D97706; }
    .stop-node-indicator.red { background: #FEE2E2; color: #DC2626; }

    .stop-content {
      flex: 1;
      min-width: 0;
      display: flex;
      flex-direction: column;
      gap: 1px;
    }
    .stop-meta-row {
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .stop-type-tag {
      font-size: 9px;
      font-weight: 700;
      letter-spacing: 0.3px;
    }
    .stop-type-tag.green { color: #15803D; }
    .stop-type-tag.amber { color: #B45309; }
    .stop-type-tag.red { color: #B91C1C; }
    .postcode-badge {
      font-size: 9.5px;
      font-weight: 800;
      font-family: monospace;
      background: #FEF08A;
      color: #000000;
      padding: 1px 5px;
      border-radius: 4px;
    }
    .stop-address-txt {
      margin: 2px 0 0 0;
      font-size: 12.5px;
      font-weight: 600;
      color: #0F172A;
      line-height: 1.35;
    }

    /* Fare & Metrics */
    .fare-metrics-grid {
      display: grid;
      grid-template-columns: 1.4fr 1fr 1fr;
      gap: 8px;
    }
    .metric-tile {
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 10px;
      padding: 8px 10px;
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .metric-tile.fare-tile {
      background: #FEF2F2;
      border-color: #FECACA;
    }
    .tile-label {
      font-size: 9px;
      font-weight: 700;
      color: #64748B;
      text-transform: uppercase;
      letter-spacing: 0.3px;
    }
    .tile-main-fare {
      font-size: 18px;
      font-weight: 900;
      color: #0F172A;
      display: flex;
      align-items: baseline;
    }
    .tile-main-fare .cur { color: #CD1A21; font-size: 13px; }
    .payment-type-tag {
      font-size: 9px;
      font-weight: 700;
      text-transform: uppercase;
      color: #15803D;
      margin-top: 1px;
    }
    .tile-value-row {
      display: flex;
      align-items: center;
      gap: 4px;
      margin-top: 2px;
    }
    .tile-ico { font-size: 14px; color: #64748B; }
    .tile-val {
      font-size: 12px;
      font-weight: 700;
      color: #1E293B;
    }

    /* Specs Grid */
    .specs-grid {
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .spec-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 11.5px;
      padding: 3px 0;
      border-bottom: 1px dashed #E2E8F0;
    }
    .spec-row:last-child { border-bottom: none; }
    .spec-label {
      color: #64748B;
      font-weight: 500;
    }
    .spec-val {
      color: #0F172A;
      font-weight: 600;
    }
    .font-bold { font-weight: 700; }
    .font-mono { font-family: monospace; }
    .text-ellipsis {
      max-width: 200px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    /* Notes Box */
    .notes-box {
      background: #FFFBEB;
      border: 1px solid #FDE68A;
      border-radius: 8px;
      padding: 8px 10px;
    }
    .notes-text {
      margin: 0;
      font-size: 11.5px;
      color: #92400E;
      line-height: 1.4;
      font-weight: 500;
    }

    /* Sheet Footer */
    .sheet-footer {
      padding: 10px 16px 14px 16px;
      border-top: 1px solid #F1F5F9;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .sheet-dismiss-btn {
      width: 100%;
      background: #F1F5F9;
      border: 1px solid #CBD5E1;
      padding: 9px;
      border-radius: 10px;
      font-size: 12px;
      font-weight: 700;
      color: #475569;
      cursor: pointer;
    }

    /* Slide to Complete */
    .slide-complete-container {
      width: 100%;
    }
    .slide-complete-track {
      position: relative;
      height: 46px;
      background: #111827;
      border-radius: 23px;
      overflow: hidden;
      display: flex;
      align-items: center;
      justify-content: center;
      user-select: none;
    }
    .slide-fill-bar {
      position: absolute;
      left: 0;
      top: 0;
      bottom: 0;
      background: linear-gradient(90deg, #10B981, #059669);
      border-radius: 23px;
      transition: width 0.05s ease;
    }
    .slide-track-text {
      position: relative;
      z-index: 2;
      font-size: 12px;
      font-weight: 700;
      color: #FFFFFF;
      letter-spacing: 0.3px;
      pointer-events: none;
    }
    .slide-thumb-btn {
      position: absolute;
      left: 3px;
      width: 40px;
      height: 40px;
      border-radius: 50%;
      background: #FFFFFF;
      color: #111827;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: grab;
      z-index: 3;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
      touch-action: none;
    }
    .slide-thumb-btn:active { cursor: grabbing; }

    .animated-fade-in {
      animation: fadeIn 0.2s ease-in-out;
    }
    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }

    /* ================= DARK THEME OVERRIDES ================= */
    :host-context(.dark-theme) {
      background-color: #121214 !important;
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .filter-tab-bar {
      background: #1E1E24;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .tab-btn:not(.active) {
      color: #94A3B8;
    }
    :host-context(.dark-theme) .booking-card,
    :host-context(.dark-theme) .empty-state {
      background: #1E1E24;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .booking-ref-badge,
    :host-context(.dark-theme) .address-time-pill,
    :host-context(.dark-theme) .sheet-ref-chip {
      background: #2D2D35;
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .booking-fare-text,
    :host-context(.dark-theme) .address-text,
    :host-context(.dark-theme) .empty-title,
    :host-context(.dark-theme) .sheet-passenger-name,
    :host-context(.dark-theme) .stop-address-txt,
    :host-context(.dark-theme) .tile-main-fare,
    :host-context(.dark-theme) .tile-val,
    :host-context(.dark-theme) .spec-val {
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .card-footer-row,
    :host-context(.dark-theme) .sheet-header,
    :host-context(.dark-theme) .sheet-quick-actions,
    :host-context(.dark-theme) .sheet-footer {
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .modal-sheet {
      background: #1E1E24;
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .detail-block-card {
      background: #16161A;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .metric-tile {
      background: #1E1E24;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .metric-tile.fare-tile {
      background: #2A1719;
      border-color: #4C1D24;
    }
    :host-context(.dark-theme) .sheet-close-btn,
    :host-context(.dark-theme) .sheet-dismiss-btn {
      background: #2D2D35;
      border-color: #3E3E48;
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .notes-box {
      background: #241A08;
      border-color: #452D08;
    }
  `]
})
export class BookingsComponent implements OnInit {
  @ViewChild('sliderEl') sliderEl?: ElementRef<HTMLDivElement>;

  tabs = ['All', 'Upcoming', 'Completed', 'Cancelled'];
  activeTab = 'All';
  isLoading = true;
  bookings: Booking[] = [];
  selectedBooking: Booking | null = null;
  activeBookingId = '';
  isSettingActive = false;
  isSubmitting = false;

  // Driver trip status
  driverTripStatus: { [bookingId: string]: 'upcoming' | 'arrived' | 'pickedUp' } = {};

  // Slider controls
  isDragging = false;
  sliderPosition = 0;
  maxSlide = 0;
  startX = 0;

  constructor(
    private driverService: DriverService,
    private snackBar: MatSnackBar,
    private cdr: ChangeDetectorRef,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.loadBookings();
  }

  setTab(tab: string): void {
    this.activeTab = tab;
    this.cdr.detectChanges();
  }

  openDetails(booking: Booking): void {
    this.selectedBooking = booking;
    this.sliderPosition = 0;
    this.isDragging = false;
    this.cdr.detectChanges();
  }

  closeDetails(): void {
    this.selectedBooking = null;
    this.sliderPosition = 0;
    this.isDragging = false;
    this.cdr.detectChanges();
  }

  copyText(text: string, message: string): void {
    if (!text) return;
    navigator.clipboard.writeText(text).then(() => {
      this.snackBar.open(message, 'OK', {
        duration: 2000,
        horizontalPosition: 'center',
        verticalPosition: 'bottom'
      });
    }).catch(err => {
      console.warn('Clipboard write failed:', err);
    });
  }

  getTripProgress(bookingId: string): string {
    return this.driverTripStatus[bookingId] || 'upcoming';
  }

  getStatusIcon(bookingId: string): string {
    const s = this.getTripProgress(bookingId);
    if (s === 'upcoming') return 'pin_drop';
    if (s === 'arrived') return 'airline_seat_recline_normal';
    return 'navigation';
  }

  getStatusLabel(bookingId: string): string {
    const s = this.getTripProgress(bookingId);
    if (s === 'upcoming') return 'I Have Arrived';
    if (s === 'arrived') return 'POB (Passenger On Board)';
    return 'In Transit';
  }

  advanceTripStatus(booking: Booking): void {
    const current = this.getTripProgress(booking.id);
    const bookingIdNum = parseInt(booking.id) || 0;

    if (current === 'upcoming') {
      this.driverTripStatus[booking.id] = 'arrived';
      this.snackBar.open('Status updated: Arrived at pickup!', 'OK', { duration: 2500 });
      if (bookingIdNum > 0) {
        this.driverService.markArrived(bookingIdNum).subscribe({
          next: () => {},
          error: (err: any) => console.warn('Arrived API warning:', err)
        });
      }
    } else if (current === 'arrived') {
      this.driverTripStatus[booking.id] = 'pickedUp';
      this.snackBar.open('Status updated: Passenger on board (POB)!', 'OK', { duration: 2500 });
    }
    this.cdr.detectChanges();
  }

  setActiveJob(booking: Booking): void {
    const bookingIdNum = parseInt(booking.id) || 0;
    if (bookingIdNum <= 0) return;

    this.isSettingActive = true;
    this.cdr.detectChanges();

    this.driverService.setActiveJob(bookingIdNum).subscribe({
      next: () => {
        this.isSettingActive = false;
        this.activeBookingId = booking.id;
        this.snackBar.open('Trip set as Active!', 'OK', { duration: 2500 });
        this.loadBookings();
      },
      error: () => {
        this.isSettingActive = false;
        this.activeBookingId = booking.id;
        this.snackBar.open('Trip set as Active!', 'OK', { duration: 2500 });
        this.loadBookings();
      }
    });
  }

  completeBooking(booking: Booking): void {
    const bookingIdNum = parseInt(booking.id) || 0;
    if (bookingIdNum <= 0) return;
    this.closeDetails();

    const channel = (window as any).FlutterChannel;
    if (channel) {
      channel.postMessage(`open_complete_job:${booking.id}:${booking.fare}`);
    } else {
      this.router.navigate(['/complete-job'], { queryParams: { jobId: booking.id, fare: booking.fare } });
    }
  }

  // --- Slide to Complete Drag Handlers ---
  onDragStart(event: MouseEvent | TouchEvent): void {
    event.preventDefault();
    if (!this.sliderEl) return;
    this.isDragging = true;
    this.startX = 'touches' in event ? event.touches[0].clientX : event.clientX;
    const trackWidth = this.sliderEl.nativeElement.clientWidth;
    this.maxSlide = Math.max(0, trackWidth - 46);

    const moveListener = (moveEvent: MouseEvent | TouchEvent) => {
      if (!this.isDragging) return;
      const currentX = 'touches' in moveEvent ? moveEvent.touches[0].clientX : moveEvent.clientX;
      const diff = currentX - this.startX;
      this.sliderPosition = Math.max(0, Math.min(this.maxSlide, diff));
      this.cdr.detectChanges();
    };

    const upListener = () => {
      if (!this.isDragging) return;
      this.isDragging = false;
      window.removeEventListener('mousemove', moveListener);
      window.removeEventListener('mouseup', upListener);
      window.removeEventListener('touchmove', moveListener);
      window.removeEventListener('touchend', upListener);

      if (this.sliderPosition >= this.maxSlide * 0.85 && this.selectedBooking) {
        this.sliderPosition = this.maxSlide;
        this.isSubmitting = true;
        this.cdr.detectChanges();
        setTimeout(() => {
          this.completeBooking(this.selectedBooking!);
        }, 300);
      } else {
        this.sliderPosition = 0;
        this.cdr.detectChanges();
      }
    };

    window.addEventListener('mousemove', moveListener);
    window.addEventListener('mouseup', upListener);
    window.addEventListener('touchmove', moveListener);
    window.addEventListener('touchend', upListener);
  }

  loadBookings(): void {
    this.isLoading = true;
    this.cdr.detectChanges();

    forkJoin({
      bookingsToday: this.driverService.getBookingsToday().pipe(catchError(() => of([]))),
      todaysJobs: this.driverService.getTodaysJobs().pipe(catchError(() => of([]))),
      futureJobs: this.driverService.getFutureJobs().pipe(catchError(() => of([]))),
      completedJobs: this.driverService.getCompletedJobs().pipe(catchError(() => of([]))),
      activeJob: this.driverService.getActiveJob().pipe(catchError(() => of(null)))
    }).subscribe({
      next: (results) => {
        let activeId = '';
        if (results.activeJob) {
          const activeRaw = results.activeJob.value || results.activeJob.data || results.activeJob;
          if (activeRaw) {
            let activeObj = Array.isArray(activeRaw) ? activeRaw[0] : activeRaw;
            if (activeObj) {
              const parsedId = (typeof activeObj === 'object' ? (activeObj.bookingId || activeObj.id || activeObj.bookingNo || '') : activeObj).toString().trim();
              if (parsedId && parsedId !== '0') {
                activeId = parsedId;
              }
            }
          }
        }
        this.activeBookingId = activeId;

        const allJobs: Booking[] = [];
        
        const processJob = (job: any, defaultStatus: 'Upcoming' | 'Completed' | 'Cancelled'): Booking => {
          const fare = parseFloat((job.price || job.fare || job.amount || job.driverPrice || '0.00').toString());
          const pickup = job.pickupAddress || job.pickup || job.from || 'Pickup location';
          const pickupPostCode = job.pickupPostCode || job.pickupPostcode || job.postcode || '';
          const dropoff = job.destinationAddress || job.dropoffAddress || job.dropoff || job.to || 'Dropoff destination';
          const destinationPostCode = job.destinationPostCode || job.destinationPostcode || '';

          const vias: ViaStop[] = [];
          if (Array.isArray(job.vias) && job.vias.length > 0) {
            for (const v of job.vias) {
              if (typeof v === 'string') {
                vias.push({ address: v });
              } else if (v && typeof v === 'object') {
                vias.push({
                  address: v.address || v.stopAddress || 'Via Stop',
                  postCode: v.postCode || v.postcode || ''
                });
              }
            }
          }

          const dtStr = job.pickupDateTime || job.bookingDateTime || job.dateCreated || job.endTime || '';
          let time = job.bookingTime || job.time || '';
          let date = job.bookingDate || job.date || '';
          let fullDateTimeStr = '';

          if (dtStr) {
            const parsed = new Date(dtStr);
            if (!isNaN(parsed.getTime())) {
              if (!time) {
                time = parsed.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false });
              }
              if (!date) {
                const isToday = new Date().toDateString() === parsed.toDateString();
                date = isToday ? 'Today' : parsed.toLocaleDateString([], { day: '2-digit', month: 'short' });
              }
              fullDateTimeStr = parsed.toLocaleDateString([], { weekday: 'long', day: '2-digit', month: 'short', year: 'numeric' }) + ' – ' + time;
            }
          }
          if (!time) time = '00:00';
          if (!date) date = 'Today';

          let paymentType = job.paymentType || job.paymentMethod || '';
          if (!paymentType && job.scope !== undefined && job.scope !== null) {
            const scope = parseInt(job.scope.toString()) || 0;
            switch (scope) {
              case 0: paymentType = 'Cash'; break;
              case 1: paymentType = 'Account'; break;
              case 2: paymentType = 'Rank'; break;
              case 4: paymentType = 'Card'; break;
              default: paymentType = 'Cash'; break;
            }
          }
          if (!paymentType) paymentType = 'Cash';

          let status: 'Upcoming' | 'Completed' | 'Cancelled' = defaultStatus;
          const rawStatus = job.status?.toString().toLowerCase() || '';
          if (job.cancelled === true || job.cancelledOnArrival === true || rawStatus.includes('cancel') || rawStatus === '2') {
            status = 'Cancelled';
          } else if (rawStatus.includes('complete') || rawStatus === '3' || rawStatus === '4' || rawStatus === '5' || rawStatus === '6') {
            status = 'Completed';
          }

          return {
            id: (job.bookingId || job.bookingNo || job.id || Math.floor(Math.random() * 100000)).toString(),
            pickup,
            pickupPostCode,
            dropoff,
            destinationPostCode,
            vias: vias.length > 0 ? vias : undefined,
            time,
            date,
            fullDateTimeStr,
            fare: isNaN(fare) ? 0.00 : fare,
            paymentType,
            status,
            passenger: job.passengerName || job.cellText || job.passenger || job.customerName || 'Passenger',
            phoneNumber: job.phoneNumber || job.phone || job.mobile || '',
            email: job.email || '',
            passengerCount: job.passengers ? parseInt(job.passengers.toString()) : undefined,
            notes: job.details || job.notes || job.comment || '',
            vehicleType: job.vehicleType || job.vehicle || 'Standard Saloon',
            durationMinutes: job.durationMinutes ? parseInt(job.durationMinutes.toString()) : undefined,
            mileageText: job.mileageText || (job.mileage ? `${job.mileage} miles` : undefined),
            bookedByName: job.bookedByName || '',
            accountNumber: job.accountNumber ? job.accountNumber.toString() : undefined
          };
        };

        const extractList = (res: any): any[] => {
          if (!res) return [];
          if (Array.isArray(res)) return res;
          if (Array.isArray(res.bookings)) return res.bookings;
          if (Array.isArray(res.value)) return res.value;
          if (Array.isArray(res.data)) return res.data;
          return [];
        };

        const bookingsTodayList = extractList(results.bookingsToday);
        const todaysJobsList = extractList(results.todaysJobs);
        const futureList = extractList(results.futureJobs);
        const completedList = extractList(results.completedJobs);

        completedList.forEach((job: any) => allJobs.push(processJob(job, 'Completed')));
        bookingsTodayList.forEach((job: any) => allJobs.push(processJob(job, 'Upcoming')));
        todaysJobsList.forEach((job: any) => allJobs.push(processJob(job, 'Upcoming')));
        futureList.forEach((job: any) => allJobs.push(processJob(job, 'Upcoming')));

        const seenIds = new Set<string>();
        const uniqueJobs: Booking[] = [];
        for (const j of allJobs) {
          if (!seenIds.has(j.id)) {
            seenIds.add(j.id);
            uniqueJobs.push(j);
          }
        }

        this.bookings = uniqueJobs;
        this.isLoading = false;
        this.cdr.detectChanges();
      },
      error: (err) => {
        console.error('Failed to load bookings:', err);
        this.isLoading = false;
        this.cdr.detectChanges();
      }
    });
  }

  get filteredBookings(): Booking[] {
    if (this.activeTab === 'All') {
      return this.bookings;
    }
    return this.bookings.filter(b => b.status === this.activeTab);
  }

  getTabCount(tab: string): number {
    if (tab === 'All') return this.bookings.length;
    return this.bookings.filter(b => b.status === tab).length;
  }
}
