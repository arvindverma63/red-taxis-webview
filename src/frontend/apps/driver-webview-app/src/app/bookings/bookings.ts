import { Component, OnInit, ChangeDetectorRef, ViewChild } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatDividerModule } from '@angular/material/divider';
import { DriverService } from '../services/driver.service';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs/operators';

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
    <div class="material-container">
      <!-- 4 Segmented Tabs (All on a single row) -->
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

      <!-- Loading State -->
      <div *ngIf="isLoading" class="loading-state">
        <div class="spinner"></div>
        <p class="loading-text">Loading bookings...</p>
      </div>

      <!-- Bookings List -->
      <div class="bookings-list" *ngIf="!isLoading">
        <div *ngIf="filteredBookings.length === 0" class="empty-state">
          <span class="material-symbols-outlined empty-icon">assignment_late</span>
          <p class="empty-title">No {{ activeTab.toLowerCase() }} bookings found</p>
          <p class="empty-subtitle">New allocations and scheduled trips will appear here.</p>
          <button class="retry-btn" (click)="loadBookings()">Refresh</button>
        </div>

        <mat-card 
          *ngFor="let booking of filteredBookings" 
          class="booking-mat-card" 
          (click)="openDetails(booking)"
        >
          <!-- Card Top Header -->
          <div class="card-top">
            <div class="booking-ref">
              <span class="ref-label">BOOKING ID</span>
              <span class="ref-val">#{{ booking.id }}</span>
            </div>
            <div class="booking-price">
              £{{ booking.fare.toFixed(2) }}
            </div>
          </div>

          <mat-divider></mat-divider>

          <!-- Card Middle Route Timeline -->
          <div class="card-middle">
            <div class="timeline-container">
              <div class="timeline-line"></div>
              
              <div class="timeline-node">
                <span class="material-symbols-outlined node-icon green-icon">
                  {{ booking.pickup.toLowerCase().includes('airport') ? 'flight_takeoff' : 'my_location' }}
                </span>
                <div class="node-content">
                  <div class="time-address">
                    <span class="node-time">{{ booking.time }}</span>
                    <span class="node-address" [title]="booking.pickup">{{ booking.pickup }}</span>
                  </div>
                </div>
              </div>

              <!-- Via Stops Preview in Card -->
              <div class="timeline-node via-node" *ngFor="let via of booking.vias; let i = index">
                <span class="material-symbols-outlined node-icon via-icon">alt_route</span>
                <div class="node-content">
                  <div class="time-address">
                    <span class="node-time-placeholder">Via {{ i + 1 }}</span>
                    <span class="node-address" [title]="via.address">{{ via.address }}</span>
                  </div>
                </div>
              </div>

              <div class="timeline-node">
                <span class="material-symbols-outlined node-icon red-icon">location_on</span>
                <div class="node-content">
                  <div class="time-address">
                    <span class="node-time-placeholder"></span>
                    <span class="node-address" [title]="booking.dropoff">{{ booking.dropoff }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <mat-divider></mat-divider>

          <!-- Card Bottom Details & Clickable Prompt -->
          <div class="card-bottom">
            <span class="status-badge" [ngClass]="booking.status.toLowerCase()">
              {{ booking.status }}
            </span>
            <span class="payment-badge" [ngClass]="booking.paymentType.toLowerCase()">
              {{ booking.paymentType }}
            </span>
            <span class="date-badge">
              {{ booking.date }}
            </span>
            <span class="spacer"></span>
            <span class="view-details-txt">View Details &rarr;</span>
          </div>
        </mat-card>
      </div>

      <!-- ============================================================== -->
      <!-- FULL BOOKING DETAILS MODAL / BOTTOM SHEET                      -->
      <!-- ============================================================== -->
      <div class="modal-backdrop" *ngIf="selectedBooking" (click)="closeDetails()">
        <div class="modal-sheet" (click)="$event.stopPropagation()">
          <!-- Sheet Header -->
          <div class="sheet-header">
            <div class="sheet-grabber"></div>
            <div class="sheet-title-row">
              <div>
                <h3 class="sheet-passenger-title">{{ selectedBooking.passenger }}</h3>
                <span class="sheet-booking-id">Booking ID: #{{ selectedBooking.id }}</span>
              </div>
              <button class="sheet-close-btn" (click)="closeDetails()">
                <span class="material-symbols-outlined">close</span>
              </button>
            </div>
            <div class="sheet-datetime-sub">
              <span class="material-symbols-outlined sub-icon">schedule</span>
              <span>{{ selectedBooking.fullDateTimeStr || (selectedBooking.date + ' at ' + selectedBooking.time) }}</span>
            </div>
          </div>

          <!-- Quick Action Buttons: Status Toggle, Call, SMS -->
          <div class="sheet-quick-actions">
            <!-- Arrived / Picked Up Status Toggle -->
            <button 
              *ngIf="selectedBooking.status === 'Upcoming' && selectedBooking.id === activeBookingId"
              class="action-pill-btn status-btn" 
              [ngClass]="getTripProgress(selectedBooking.id)"
              (click)="advanceTripStatus(selectedBooking)"
            >
              <span class="material-symbols-outlined">{{ getStatusIcon(selectedBooking.id) }}</span>
              <span>{{ getStatusLabel(selectedBooking.id) }}</span>
            </button>

            <!-- Call & SMS -->
            <a *ngIf="selectedBooking.phoneNumber" [href]="'tel:' + selectedBooking.phoneNumber" class="action-pill-btn call">
              <span class="material-symbols-outlined">call</span>
              <span>Call</span>
            </a>
            <a *ngIf="selectedBooking.phoneNumber" [href]="'sms:' + selectedBooking.phoneNumber" class="action-pill-btn sms">
              <span class="material-symbols-outlined">chat</span>
              <span>SMS</span>
            </a>
          </div>

          <!-- Modal Scrollable Content -->
          <div class="sheet-body-scroll">
            <!-- Route Cards -->
            <div class="detail-section">
              <span class="section-label">JOURNEY ROUTE</span>
              
              <!-- Pickup -->
              <div class="location-detail-card pickup">
                <div class="loc-badge-icon green">
                  <span class="material-symbols-outlined">my_location</span>
                </div>
                <div class="loc-info">
                  <span class="loc-type green-txt">PICKUP LOCATION</span>
                  <p class="loc-address">{{ selectedBooking.pickup }}</p>
                  <span class="loc-postcode" *ngIf="selectedBooking.pickupPostCode">{{ selectedBooking.pickupPostCode }}</span>
                </div>
              </div>

              <!-- Vias -->
              <div class="location-detail-card via" *ngFor="let via of selectedBooking.vias; let i = index">
                <div class="loc-badge-icon yellow">
                  <span class="material-symbols-outlined">alt_route</span>
                </div>
                <div class="loc-info">
                  <span class="loc-type yellow-txt">VIA STOP {{ i + 1 }}</span>
                  <p class="loc-address">{{ via.address }}</p>
                  <span class="loc-postcode" *ngIf="via.postCode">{{ via.postCode }}</span>
                </div>
              </div>

              <!-- Dropoff -->
              <div class="location-detail-card dropoff">
                <div class="loc-badge-icon red">
                  <span class="material-symbols-outlined">location_on</span>
                </div>
                <div class="loc-info">
                  <span class="loc-type red-txt">DESTINATION</span>
                  <p class="loc-address">{{ selectedBooking.dropoff }}</p>
                  <span class="loc-postcode" *ngIf="selectedBooking.destinationPostCode">{{ selectedBooking.destinationPostCode }}</span>
                </div>
              </div>
            </div>

            <!-- Total Fare & Journey Metrics -->
            <div class="detail-section">
              <span class="section-label">FARE & METRICS</span>
              <div class="metrics-grid">
                <div class="metric-card">
                  <span class="metric-lbl">TOTAL FARE</span>
                  <span class="metric-val fare-val">£{{ selectedBooking.fare.toFixed(2) }}</span>
                </div>
                <div class="metric-card" *ngIf="selectedBooking.durationMinutes">
                  <span class="metric-lbl">EST. DURATION</span>
                  <span class="metric-val">{{ selectedBooking.durationMinutes }} mins</span>
                </div>
                <div class="metric-card" *ngIf="selectedBooking.mileageText">
                  <span class="metric-lbl">EST. DISTANCE</span>
                  <span class="metric-val">{{ selectedBooking.mileageText }}</span>
                </div>
              </div>
            </div>

            <!-- Booking Specifications Grid -->
            <div class="detail-section">
              <span class="section-label">BOOKING DETAILS</span>
              <div class="info-list-card">
                <div class="info-row">
                  <span class="info-k">Payment Mode</span>
                  <span class="info-v highlight-v">{{ selectedBooking.paymentType }}</span>
                </div>
                <div class="info-row" *ngIf="selectedBooking.accountNumber">
                  <span class="info-k">Account Number</span>
                  <span class="info-v">{{ selectedBooking.accountNumber }}</span>
                </div>
                <div class="info-row">
                  <span class="info-k">Booking Status</span>
                  <span class="status-badge" [ngClass]="selectedBooking.status.toLowerCase()">{{ selectedBooking.status }}</span>
                </div>
                <div class="info-row">
                  <span class="info-k">Vehicle Class</span>
                  <span class="info-v">{{ selectedBooking.vehicleType }}</span>
                </div>
                <div class="info-row" *ngIf="selectedBooking.passengerCount">
                  <span class="info-k">Passenger Count</span>
                  <span class="info-v">{{ selectedBooking.passengerCount }}</span>
                </div>
                <div class="info-row" *ngIf="selectedBooking.bookedByName">
                  <span class="info-k">Booked By</span>
                  <span class="info-v">{{ selectedBooking.bookedByName }}</span>
                </div>
                <div class="info-row" *ngIf="selectedBooking.email">
                  <span class="info-k">Email</span>
                  <span class="info-v">{{ selectedBooking.email }}</span>
                </div>
              </div>
            </div>

            <!-- Driver Notes / Instructions -->
            <div class="detail-section" *ngIf="selectedBooking.notes && selectedBooking.notes.trim().length > 0">
              <span class="section-label">DRIVER NOTES & INSTRUCTIONS</span>
              <div class="notes-card">
                <span class="material-symbols-outlined notes-icon">info</span>
                <p class="notes-content">{{ selectedBooking.notes }}</p>
              </div>
            </div>
          </div>

          <!-- Bottom Actions (Complete Booking & Close) -->
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
                  [style.width.px]="sliderPosition + 22"
                ></div>
                <div class="slide-track-text" *ngIf="!isSubmitting">
                  {{ isDragging ? 'Release to Complete' : 'Slide to Complete' }}
                </div>
                <div class="slide-track-text submitting" *ngIf="isSubmitting">
                  Completing Booking...
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
            <button class="sheet-dismiss-btn" (click)="closeDetails()">Close Details</button>
          </div>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .material-container {
      padding: 12px 14px 40px 14px;
      background-color: #F8F9FA;
      min-height: 100vh;
      font-family: 'Roboto', sans-serif;
      box-sizing: border-box;
      position: relative;
    }

    /* Single-Row Segmented Tab Bar */
    .filter-tab-bar {
      display: flex;
      background-color: #FFFFFF;
      border: 1px solid #E0E2EC;
      border-radius: 24px;
      padding: 4px;
      margin-bottom: 14px;
      gap: 4px;
      box-sizing: border-box;
      width: 100%;
      box-shadow: 0 1px 4px rgba(0,0,0,0.03);
    }
    .tab-btn {
      flex: 1;
      border: none;
      background: transparent;
      padding: 8px 2px;
      border-radius: 20px;
      font-size: 11px;
      font-weight: 700;
      color: #546E7A;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 3px;
      cursor: pointer;
      transition: all 0.2s ease;
      white-space: nowrap;
      user-select: none;
    }
    .tab-btn:active {
      transform: scale(0.97);
    }
    .tab-btn.active {
      background-color: #D32F2F;
      color: #FFFFFF;
      box-shadow: 0 2px 6px rgba(211, 47, 47, 0.25);
    }
    .tab-count {
      font-size: 10px;
      font-weight: 800;
      opacity: 0.9;
    }

    /* Loading State */
    .loading-state {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 60px 20px;
    }
    .spinner {
      width: 32px;
      height: 32px;
      border: 3px solid #E0E2EC;
      border-top-color: #D32F2F;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
    }
    @keyframes spin {
      from { transform: rotate(0deg); }
      to { transform: rotate(360deg); }
    }
    .loading-text {
      margin-top: 14px;
      font-size: 13px;
      font-weight: 600;
      color: #74777F;
    }
    
    .bookings-list {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    
    /* Premium Booking Card Layout */
    .booking-mat-card {
      border: 1px solid #E0E2EC;
      box-shadow: 0 2px 8px rgba(0,0,0,0.03) !important;
      border-radius: 16px !important;
      cursor: pointer;
      background-color: #FFFFFF;
      transition: all 0.2s ease-in-out;
      overflow: hidden;
    }
    .booking-mat-card:hover {
      transform: translateY(-2px);
      box-shadow: 0 6px 16px rgba(0,0,0,0.06) !important;
      border-color: #C4C6D0;
    }

    /* Card Top Header */
    .card-top {
      padding: 14px 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .booking-ref {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .ref-label {
      font-size: 9px;
      font-weight: 800;
      color: #90A4AE;
      letter-spacing: 0.5px;
    }
    .ref-val {
      font-size: 14px;
      font-weight: 800;
      color: #1A1C1E;
    }
    .booking-price {
      font-size: 19px;
      font-weight: 900;
      color: #2E7D32;
    }

    /* Route Timeline layout */
    .card-middle {
      padding: 14px 16px;
    }
    .timeline-container {
      position: relative;
      display: flex;
      flex-direction: column;
      gap: 14px;
    }
    .timeline-line {
      position: absolute;
      left: 11px;
      top: 16px;
      bottom: 16px;
      width: 2px;
      background-color: #E0E2EC;
      z-index: 1;
    }
    .timeline-node {
      position: relative;
      display: flex;
      align-items: center;
      gap: 12px;
      z-index: 2;
    }
    .node-icon {
      font-size: 20px;
      width: 24px;
      height: 24px;
      border-radius: 50%;
      background-color: #FFFFFF;
      display: flex;
      justify-content: center;
      align-items: center;
    }
    .green-icon {
      color: #2E7D32;
    }
    .yellow-icon, .via-icon {
      color: #F57F17;
    }
    .red-icon {
      color: #D32F2F;
    }
    .node-content {
      flex: 1;
      min-width: 0;
    }
    .time-address {
      display: flex;
      align-items: center;
      gap: 8px;
      min-width: 0;
    }
    .node-time {
      font-size: 12px;
      font-weight: 800;
      color: #1A1C1E;
      width: 44px;
      flex-shrink: 0;
    }
    .node-time-placeholder {
      width: 44px;
      flex-shrink: 0;
      font-size: 11px;
      font-weight: 700;
      color: #74777F;
    }
    .node-address {
      font-size: 13px;
      font-weight: 600;
      color: #263238;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    /* Card Bottom */
    .card-bottom {
      padding: 10px 16px;
      display: flex;
      align-items: center;
      gap: 8px;
      background-color: #FAFBFD;
    }
    .status-badge {
      font-size: 9px;
      font-weight: 800;
      padding: 3px 8px;
      border-radius: 20px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .status-badge.completed {
      background-color: rgba(76, 175, 80, 0.1);
      color: #2E7D32;
      border: 1px solid rgba(76, 175, 80, 0.2);
    }
    .status-badge.upcoming {
      background-color: rgba(33, 150, 243, 0.1);
      color: #1565C0;
      border: 1px solid rgba(33, 150, 243, 0.2);
    }
    .status-badge.cancelled {
      background-color: rgba(244, 67, 54, 0.1);
      color: #C62828;
      border: 1px solid rgba(244, 67, 54, 0.2);
    }
    .payment-badge {
      font-size: 9px;
      font-weight: 800;
      padding: 3px 8px;
      border-radius: 6px;
      border: 1px solid #E0E2EC;
      color: #44474E;
      background-color: #FFFFFF;
      text-transform: uppercase;
    }
    .date-badge {
      font-size: 11px;
      font-weight: 600;
      color: #74777F;
    }
    .spacer {
      flex: 1;
    }
    .view-details-txt {
      font-size: 11px;
      font-weight: 700;
      color: #D32F2F;
    }

    .empty-state {
      text-align: center;
      padding: 48px 20px;
      background-color: #FFFFFF;
      border-radius: 16px;
      border: 1px dashed #C4C6D0;
    }
    .empty-icon {
      font-size: 44px;
      width: 44px;
      height: 44px;
      color: #90A4AE;
      margin-bottom: 8px;
    }
    .empty-title {
      font-size: 15px;
      font-weight: 700;
      color: #1A1C1E;
      margin: 0 0 4px 0;
    }
    .empty-subtitle {
      font-size: 12px;
      color: #74777F;
      margin: 0 0 16px 0;
    }
    .retry-btn {
      background-color: #D32F2F;
      color: #FFFFFF;
      border: none;
      padding: 8px 20px;
      font-size: 12px;
      font-weight: 700;
      border-radius: 20px;
      cursor: pointer;
    }

    /* ============================================================== */
    /* MODAL BOTTOM SHEET STYLES                                      */
    /* ============================================================== */
    .modal-backdrop {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background-color: rgba(0, 0, 0, 0.45);
      backdrop-filter: blur(3px);
      z-index: 1000;
      display: flex;
      flex-direction: column;
      justify-content: flex-end;
      animation: fadeIn 0.25s ease-out;
    }
    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }

    .modal-sheet {
      background-color: #F8F9FA;
      border-radius: 24px 24px 0 0;
      max-height: 90vh;
      display: flex;
      flex-direction: column;
      box-shadow: 0 -8px 32px rgba(0,0,0,0.15);
      animation: slideUp 0.3s cubic-bezier(0.16, 1, 0.3, 1);
      overflow: hidden;
    }
    @keyframes slideUp {
      from { transform: translateY(100%); }
      to { transform: translateY(0); }
    }

    .sheet-header {
      padding: 12px 18px 12px 18px;
      background-color: #FFFFFF;
      border-bottom: 1px solid #E0E2EC;
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .sheet-grabber {
      width: 36px;
      height: 4px;
      background-color: #CFD8DC;
      border-radius: 2px;
      align-self: center;
      margin-bottom: 4px;
    }
    .sheet-title-row {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
    }
    .sheet-passenger-title {
      margin: 0;
      font-size: 18px;
      font-weight: 800;
      color: #1A1C1E;
    }
    .sheet-booking-id {
      font-size: 12px;
      font-weight: 700;
      color: #D32F2F;
    }
    .sheet-close-btn {
      background: #F1F3F9;
      border: none;
      border-radius: 50%;
      width: 32px;
      height: 32px;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      color: #546E7A;
    }
    .sheet-datetime-sub {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 12px;
      font-weight: 600;
      color: #74777F;
    }
    .sub-icon {
      font-size: 16px;
    }

    .sheet-quick-actions {
      display: flex;
      gap: 8px;
      padding: 10px 18px;
      background-color: #FFFFFF;
      border-bottom: 1px solid #E0E2EC;
    }
    .action-pill-btn {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      padding: 9px 10px;
      border-radius: 24px;
      font-size: 12px;
      font-weight: 700;
      text-decoration: none;
      border: none;
      transition: all 0.2s ease;
      cursor: pointer;
    }
    .action-pill-btn.status-btn {
      background-color: #E3F2FD;
      color: #1565C0;
      border: 1px solid #BBDEFB;
    }
    .action-pill-btn.status-btn.arrived {
      background-color: #FFF8E1;
      color: #E65100;
      border-color: #FFE082;
    }
    .action-pill-btn.status-btn.pickedUp {
      background-color: #E8F5E9;
      color: #2E7D32;
      border-color: #A5D6A7;
    }
    .action-pill-btn.call {
      background-color: rgba(76, 175, 80, 0.12);
      color: #2E7D32;
      border: 1px solid rgba(76, 175, 80, 0.25);
    }
    .action-pill-btn.sms {
      background-color: rgba(33, 150, 243, 0.12);
      color: #1565C0;
      border: 1px solid rgba(33, 150, 243, 0.25);
    }

    .sheet-body-scroll {
      padding: 14px 18px;
      overflow-y: auto;
      display: flex;
      flex-direction: column;
      gap: 16px;
    }
    .detail-section {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .section-label {
      font-size: 10px;
      font-weight: 800;
      color: #90A4AE;
      letter-spacing: 0.5px;
    }

    /* Location Cards */
    .location-detail-card {
      background-color: #FFFFFF;
      border: 1px solid #E0E2EC;
      border-radius: 14px;
      padding: 12px 14px;
      display: flex;
      gap: 12px;
      align-items: flex-start;
    }
    .loc-badge-icon {
      width: 32px;
      height: 32px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }
    .loc-badge-icon.green { background-color: rgba(76, 175, 80, 0.12); color: #2E7D32; }
    .loc-badge-icon.yellow { background-color: rgba(245, 127, 23, 0.12); color: #F57F17; }
    .loc-badge-icon.red { background-color: rgba(211, 47, 47, 0.12); color: #D32F2F; }

    .loc-info {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .loc-type {
      font-size: 9px;
      font-weight: 800;
      letter-spacing: 0.5px;
    }
    .green-txt { color: #2E7D32; }
    .yellow-txt { color: #F57F17; }
    .red-txt { color: #D32F2F; }

    .loc-address {
      margin: 0;
      font-size: 13px;
      font-weight: 700;
      color: #1A1C1E;
      line-height: 1.35;
    }
    .loc-postcode {
      font-size: 11px;
      font-weight: 600;
      color: #74777F;
    }

    /* Metrics Grid */
    .metrics-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 8px;
    }
    .metric-card {
      background-color: #FFFFFF;
      border: 1px solid #E0E2EC;
      border-radius: 12px;
      padding: 10px 12px;
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .metric-lbl {
      font-size: 8px;
      font-weight: 800;
      color: #90A4AE;
      letter-spacing: 0.5px;
    }
    .metric-val {
      font-size: 14px;
      font-weight: 800;
      color: #1A1C1E;
    }
    .fare-val {
      color: #2E7D32;
      font-size: 16px;
      font-weight: 900;
    }

    /* Specs List Card */
    .info-list-card {
      background-color: #FFFFFF;
      border: 1px solid #E0E2EC;
      border-radius: 14px;
      padding: 6px 14px;
      display: flex;
      flex-direction: column;
    }
    .info-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 10px 0;
      border-bottom: 1px solid #F1F3F9;
    }
    .info-row:last-child {
      border-bottom: none;
    }
    .info-k {
      font-size: 12px;
      font-weight: 600;
      color: #74777F;
    }
    .info-v {
      font-size: 13px;
      font-weight: 700;
      color: #1A1C1E;
    }
    .highlight-v {
      color: #1565C0;
    }

    /* Notes Card */
    .notes-card {
      background-color: #FAFBFD;
      border: 1px solid #E0E2EC;
      border-radius: 12px;
      padding: 12px 14px;
      display: flex;
      gap: 10px;
      align-items: flex-start;
    }
    .notes-icon {
      color: #1565C0;
      font-size: 20px;
    }
    .notes-content {
      margin: 0;
      font-size: 12px;
      font-style: italic;
      color: #44474E;
      line-height: 1.4;
    }

    .sheet-footer {
      padding: 12px 18px 24px 18px;
      background-color: #FFFFFF;
      border-top: 1px solid #E0E2EC;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .slide-complete-container {
      width: 100%;
      margin: 8px 0 4px 0;
      box-sizing: border-box;
    }
    .slide-complete-track {
      position: relative;
      height: 48px;
      background-color: #F1F3F9;
      border: 1px solid #CFD8DC;
      border-radius: 24px;
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
      border-radius: 24px 0 0 24px;
      z-index: 1;
      transition: width 0.05s ease;
    }
    .slide-track-text {
      position: absolute;
      font-size: 12px;
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
      width: 40px;
      height: 40px;
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
    .sheet-dismiss-btn {
      width: 100%;
      padding: 11px;
      border-radius: 24px;
      background-color: #ECEFF1;
      color: #37474F;
      border: none;
      font-size: 13px;
      font-weight: 700;
      cursor: pointer;
    }
  `]
})
export class BookingsComponent implements OnInit {
  tabs = ['All', 'Upcoming', 'Completed', 'Cancelled'];
  activeTab = 'All';
  isLoading = false;

  bookings: Booking[] = [];
  selectedBooking: Booking | null = null;
  @ViewChild('sliderEl') sliderEl!: any;
  sliderPosition = 0;
  isDragging = false;
  isSubmitting = false;
  maxDragRange = 0;
  startX = 0;
  activeBookingId = '';
  driverTripStatus: { [bookingId: string]: 'assigned' | 'arrived' | 'pickedUp' | 'completed' } = {};

  constructor(
    private driverService: DriverService,
    private cdr: ChangeDetectorRef,
    private snackBar: MatSnackBar
  ) {}

  ngOnInit(): void {
    this.loadBookings();
  }

  setTab(tab: string): void {
    this.activeTab = tab;
  }

  openDetails(booking: Booking): void {
    this.selectedBooking = booking;
    this.sliderPosition = 0;
    this.isSubmitting = false;
  }

  closeDetails(): void {
    this.selectedBooking = null;
  }

  onDragStart(event: MouseEvent | TouchEvent): void {
    if (this.isSubmitting) return;
    this.isDragging = true;
    this.startX = this.getEventX(event) - this.sliderPosition;
    
    if (this.sliderEl) {
      const containerWidth = this.sliderEl.nativeElement.clientWidth;
      const thumbWidth = 40;
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
      if (this.selectedBooking) {
        this.completeBooking(this.selectedBooking);
      }
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

  getTripProgress(bookingId: string): 'assigned' | 'arrived' | 'pickedUp' | 'completed' {
    return this.driverTripStatus[bookingId] || 'assigned';
  }

  getStatusIcon(bookingId: string): string {
    const progress = this.getTripProgress(bookingId);
    switch (progress) {
      case 'assigned': return 'flag';
      case 'arrived': return 'hail';
      case 'pickedUp': return 'navigation';
      default: return 'check_circle';
    }
  }

  getStatusLabel(bookingId: string): string {
    const progress = this.getTripProgress(bookingId);
    switch (progress) {
      case 'assigned': return 'Mark Arrived';
      case 'arrived': return 'Mark Picked Up';
      case 'pickedUp': return 'On Trip (POB)';
      default: return 'Completed';
    }
  }

  advanceTripStatus(booking: Booking): void {
    const current = this.getTripProgress(booking.id);
    const bookingIdNum = parseInt(booking.id) || 0;
    if (current === 'assigned') {
      this.snackBar.open('Marking arrived at pickup...', 'Dismiss', { duration: 2000 });
      this.driverTripStatus[booking.id] = 'arrived';
      if (bookingIdNum > 0) {
        this.driverService.markArrived(bookingIdNum).subscribe({
          next: (res) => {
            console.log('Arrived API success:', res);
            this.snackBar.open('Status updated to Arrived successfully!', 'Dismiss', { duration: 2500 });
          },
          error: (err) => {
            console.error('Arrived API error:', err);
            this.snackBar.open('Failed to update status to Arrived.', 'Dismiss', { duration: 2500 });
          }
        });
      }
    } else if (current === 'arrived') {
      this.snackBar.open('Starting trip (POB)...', 'Dismiss', { duration: 2000 });
      this.driverTripStatus[booking.id] = 'pickedUp';
      this.snackBar.open('Passenger onboard, trip started!', 'Dismiss', { duration: 2500 });
    }
    this.cdr.detectChanges();
  }

  completeBooking(booking: Booking): void {
    const bookingIdNum = parseInt(booking.id) || 0;
    if (bookingIdNum > 0) {
      this.isSubmitting = true;
      this.cdr.detectChanges();
      this.snackBar.open('Completing booking...', 'Dismiss', { duration: 2000 });
      this.driverService.completeJob({
        bookingId: bookingIdNum,
        driverPrice: booking.fare,
        waitingTime: 0,
        parkingCharge: 0,
        accountPrice: 0,
        tip: 0
      }).subscribe({
        next: (res) => {
          console.log('CompleteJob API success:', res);
          this.driverService.setActiveJob(0).subscribe({
            next: () => {
              this.isSubmitting = false;
              booking.status = 'Completed';
              this.driverTripStatus[booking.id] = 'completed';
              this.loadBookings();
              this.cdr.detectChanges();
              this.snackBar.open('Booking completed successfully!', 'Dismiss', { duration: 3000 });
              setTimeout(() => this.closeDetails(), 400);
            },
            error: () => {
              this.isSubmitting = false;
              booking.status = 'Completed';
              this.driverTripStatus[booking.id] = 'completed';
              this.loadBookings();
              this.cdr.detectChanges();
              this.snackBar.open('Booking completed successfully!', 'Dismiss', { duration: 3000 });
              setTimeout(() => this.closeDetails(), 400);
            }
          });
        },
        error: (err) => {
          console.error('CompleteJob API error:', err);
          this.driverService.setActiveJob(0).subscribe({
            next: () => {
              this.isSubmitting = false;
              booking.status = 'Completed';
              this.driverTripStatus[booking.id] = 'completed';
              this.loadBookings();
              this.cdr.detectChanges();
              this.snackBar.open('Failed to complete booking.', 'Dismiss', { duration: 3000 });
              setTimeout(() => this.closeDetails(), 400);
            },
            error: () => {
              this.isSubmitting = false;
              booking.status = 'Completed';
              this.driverTripStatus[booking.id] = 'completed';
              this.loadBookings();
              this.cdr.detectChanges();
              this.snackBar.open('Failed to complete booking.', 'Dismiss', { duration: 3000 });
              setTimeout(() => this.closeDetails(), 400);
            }
          });
        }
      });
    } else {
      this.isSubmitting = false;
      booking.status = 'Completed';
      this.driverTripStatus[booking.id] = 'completed';
      this.cdr.detectChanges();
      setTimeout(() => this.closeDetails(), 400);
    }
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
          const activeRaw = results.activeJob.value || results.activeJob;
          if (activeRaw) {
            activeId = (typeof activeRaw === 'object' ? (activeRaw.bookingId || activeRaw.id || activeRaw.bookingNo) : activeRaw).toString();
          }
        }
        this.activeBookingId = activeId;

        const allJobs: Booking[] = [];
        
        const processJob = (job: any, defaultStatus: 'Upcoming' | 'Completed' | 'Cancelled'): Booking => {
          // Resolve fare
          const fare = parseFloat((job.price || job.fare || job.amount || job.driverPrice || '0.00').toString());
          
          // Resolve addresses & postcodes
          const pickup = job.pickupAddress || job.pickup || job.from || 'Pickup location';
          const pickupPostCode = job.pickupPostCode || job.pickupPostcode || job.postcode || '';
          const dropoff = job.destinationAddress || job.dropoffAddress || job.dropoff || job.to || 'Dropoff destination';
          const destinationPostCode = job.destinationPostCode || job.destinationPostcode || '';

          // Parse vias
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

          // Resolve dates & times
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

          // Resolve payment mode from scope
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

          // Resolve status
          let status: 'Upcoming' | 'Completed' | 'Cancelled' = defaultStatus;
          if (job.cancelled === true || job.cancelledOnArrival === true) {
            status = 'Cancelled';
          } else if (job.status === 4 || job.status === 5 || job.status === 6) {
            status = 'Completed';
          }

          return {
            id: (job.bookingId || job.bookingNo || job.id || Math.floor(Math.random() * 100000)).toString(),
            pickup: pickup,
            pickupPostCode: pickupPostCode,
            dropoff: dropoff,
            destinationPostCode: destinationPostCode,
            vias: vias.length > 0 ? vias : undefined,
            time: time,
            date: date,
            fullDateTimeStr: fullDateTimeStr,
            fare: isNaN(fare) ? 0.00 : fare,
            paymentType: paymentType,
            status: status,
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

        bookingsTodayList.forEach((job: any) => allJobs.push(processJob(job, 'Upcoming')));
        todaysJobsList.forEach((job: any) => allJobs.push(processJob(job, 'Upcoming')));
        futureList.forEach((job: any) => allJobs.push(processJob(job, 'Upcoming')));
        completedList.forEach((job: any) => allJobs.push(processJob(job, 'Completed')));

        // Deduplicate bookings by ID
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
