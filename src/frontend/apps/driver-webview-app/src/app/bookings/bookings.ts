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
      <!-- 1. Executive Fleet Summary Card -->
      <div class="overview-hero-card" *ngIf="!isLoading && bookings.length > 0">
        <div class="hero-metric-row">
          <div class="hero-metric-col">
            <span class="hero-metric-label">TOTAL BOOKINGS</span>
            <div class="hero-metric-val">
              <span class="metric-num">{{ bookings.length }}</span>
              <span class="metric-sub">Trips</span>
            </div>
          </div>
          <div class="hero-metric-divider"></div>
          <div class="hero-metric-col">
            <span class="hero-metric-label">UPCOMING PIPELINE</span>
            <div class="hero-metric-val green">
              <span class="metric-cur">£</span>
              <span class="metric-num">{{ totalUpcomingFare.toFixed(2) }}</span>
            </div>
          </div>
          <div class="hero-metric-divider"></div>
          <div class="hero-metric-col">
            <span class="hero-metric-label">COMPLETED FARE</span>
            <div class="hero-metric-val blue">
              <span class="metric-cur">£</span>
              <span class="metric-num">{{ totalCompletedFare.toFixed(2) }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- 2. Search & Filter Bar -->
      <div class="controls-bar">
        <div class="search-input-box">
          <span class="material-symbols-outlined search-icon">search</span>
          <input 
            type="text" 
            class="search-input" 
            placeholder="Search by ID, passenger, or address..."
            [value]="searchQuery"
            (input)="onSearchInput($event)"
          />
          <button class="clear-search-btn" *ngIf="searchQuery" (click)="clearSearch()">
            <span class="material-symbols-outlined">close</span>
          </button>
        </div>

        <!-- Segmented Tab Chips -->
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
      </div>

      <!-- 3. Loading Shimmer State -->
      <div *ngIf="isLoading" class="shimmer-loading-list">
        <div class="shimmer-card" *ngFor="let _ of [1,2,3]">
          <div class="shimmer-line header-line"></div>
          <div class="shimmer-line route-line-1"></div>
          <div class="shimmer-line route-line-2"></div>
          <div class="shimmer-line footer-line"></div>
        </div>
      </div>

      <!-- 4. Bookings List -->
      <div class="bookings-list animated-fade-in" *ngIf="!isLoading">
        <!-- Empty State -->
        <div *ngIf="filteredBookings.length === 0" class="empty-state">
          <div class="empty-icon-box">
            <span class="material-symbols-outlined">event_busy</span>
          </div>
          <p class="empty-title">No {{ activeTab.toLowerCase() }} bookings found</p>
          <p class="empty-subtitle">
            {{ searchQuery ? 'No bookings match your current search query.' : 'New dispatch allocations and scheduled trips will appear here.' }}
          </p>
          <button class="retry-btn" (click)="loadBookings()">
            <span class="material-symbols-outlined">refresh</span>
            <span>Refresh List</span>
          </button>
        </div>

        <!-- Booking Cards -->
        <div 
          *ngFor="let booking of filteredBookings" 
          class="booking-card" 
          [class.active-trip-card]="booking.id === activeBookingId"
          (click)="openDetails(booking)"
        >
          <!-- Active Job Ribbon Badge (if active) -->
          <div class="active-job-ribbon" *ngIf="booking.id === activeBookingId">
            <span class="active-pulse-beacon"></span>
            <span>CURRENT ACTIVE TRIP</span>
          </div>

          <!-- Card Header: ID, Status, Payment, Fare -->
          <div class="card-header-row">
            <div class="header-left">
              <span class="booking-ref-badge font-mono">#{{ booking.id }}</span>
              <span class="status-pill" [ngClass]="booking.status.toLowerCase()">
                <span class="status-dot" *ngIf="booking.status === 'Upcoming'"></span>
                <span>{{ booking.status }}</span>
              </span>
              <span class="payment-pill" [ngClass]="booking.paymentType.toLowerCase()">
                <span class="material-symbols-outlined payment-ico">payments</span>
                <span>{{ booking.paymentType }}</span>
              </span>
            </div>
            <div class="booking-fare-text">
              <span class="currency-symbol">£</span>
              <span class="fare-num">{{ booking.fare.toFixed(2) }}</span>
            </div>
          </div>

          <!-- Journey Route Stepper Visual -->
          <div class="journey-route-preview">
            <div class="route-tracker-col">
              <span class="route-node pickup-node"></span>
              <div class="route-stem"></div>
              <span class="route-node dropoff-node"></span>
            </div>

            <div class="route-addresses-col">
              <!-- Pickup Stop -->
              <div class="stop-entry pickup">
                <div class="stop-meta-header">
                  <span class="address-time-pill">{{ booking.time }}</span>
                  <span class="postcode-tag" *ngIf="booking.pickupPostCode">{{ booking.pickupPostCode }}</span>
                </div>
                <div class="address-text-full pickup" [title]="booking.pickup">{{ booking.pickup }}</div>
              </div>

              <!-- Via stops counter if any -->
              <div class="via-indicator-row" *ngIf="booking.vias && booking.vias.length > 0">
                <span class="material-symbols-outlined via-icon">alt_route</span>
                <span class="via-text">+{{ booking.vias.length }} Via {{ booking.vias.length === 1 ? 'Stop' : 'Stops' }}</span>
              </div>

              <!-- Dropoff Stop -->
              <div class="stop-entry dropoff">
                <div class="stop-meta-header">
                  <span class="address-time-pill dropoff-time">{{ booking.date }}</span>
                  <span class="postcode-tag" *ngIf="booking.destinationPostCode">{{ booking.destinationPostCode }}</span>
                </div>
                <div class="address-text-full dropoff" [title]="booking.dropoff">{{ booking.dropoff }}</div>
              </div>
            </div>
          </div>

          <!-- Card Footer Info -->
          <div class="card-footer-row">
            <div class="footer-left-meta">
              <div class="passenger-tag">
                <span class="material-symbols-outlined pass-icon">person</span>
                <span class="passenger-name">{{ booking.passenger }}</span>
              </div>
              <span class="vehicle-class-tag" *ngIf="booking.vehicleType">
                <span class="material-symbols-outlined vehicle-ico">local_taxi</span>
                <span>{{ booking.vehicleType }}</span>
              </span>
            </div>

            <div class="view-details-action">
              <span>View Details</span>
              <span class="material-symbols-outlined">chevron_right</span>
            </div>
          </div>
        </div>
      </div>

      <!-- ============================================================== -->
      <!-- 5. PROFESSIONAL BOOKING DETAILS MODAL / BOTTOM SHEET           -->
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
                  <span class="sheet-ref-chip font-mono" (click)="copyText(selectedBooking.id, 'Booking ID copied')">
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
              <span class="material-symbols-outlined action-btn-icon">{{ getStatusIcon(selectedBooking.id) }}</span>
              <span class="action-btn-text">{{ getStatusLabel(selectedBooking.id) }}</span>
            </button>

            <button 
              *ngIf="selectedBooking.status === 'Upcoming' && selectedBooking.id !== activeBookingId"
              class="action-pill start-trip-btn" 
              (click)="setActiveJob(selectedBooking)"
              [disabled]="isSettingActive"
            >
              <span class="material-symbols-outlined action-btn-icon">play_arrow</span>
              <span class="action-btn-text">{{ isSettingActive ? 'Starting...' : 'Start Active Trip' }}</span>
            </button>

            <!-- Passenger Direct Contact -->
            <a 
              *ngIf="selectedBooking.phoneNumber" 
              [href]="'tel:' + selectedBooking.phoneNumber" 
              class="action-pill call-btn"
            >
              <span class="material-symbols-outlined action-btn-icon">call</span>
              <span class="action-btn-text">Call</span>
            </a>

            <a 
              *ngIf="selectedBooking.phoneNumber" 
              [href]="'sms:' + selectedBooking.phoneNumber" 
              class="action-pill sms-btn"
            >
              <span class="material-symbols-outlined action-btn-icon">chat</span>
              <span class="action-btn-text">SMS</span>
            </a>

            <button 
              *ngIf="selectedBooking.phoneNumber" 
              class="action-pill copy-btn"
              (click)="copyText(selectedBooking.phoneNumber, 'Phone number copied')"
              title="Copy Phone"
            >
              <span class="material-symbols-outlined action-btn-icon">content_copy</span>
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
            <!-- 2. Financial Summary & Journey Telemetry -->
            <div class="detail-block-card">
              <div class="block-header">
                <span class="material-symbols-outlined header-icon red-icon">payments</span>
                <span class="block-title">FARE & METRICS</span>
              </div>

              <div class="fare-metrics-stack">
                <!-- Row 1: Total Fare Hero Banner -->
                <div class="metric-fare-banner">
                  <div class="fare-banner-left">
                    <span class="metric-sec-label">TOTAL FARE</span>
                    <div class="tile-main-fare">
                      <span class="cur">£</span>
                      <span class="amt">{{ selectedBooking.fare.toFixed(2) }}</span>
                    </div>
                  </div>
                  <div class="fare-banner-right">
                    <span class="payment-badge-pill" [ngClass]="selectedBooking.paymentType.toLowerCase()">
                      <span class="material-symbols-outlined badge-ico">payments</span>
                      <span>{{ selectedBooking.paymentType }}</span>
                    </span>
                  </div>
                </div>

                <!-- Row 2: Telemetry Metrics Row (Duration & Distance) -->
                <div class="telemetry-row" *ngIf="selectedBooking.durationMinutes || selectedBooking.mileageText">
                  <!-- Duration Tile -->
                  <div class="telemetry-tile" *ngIf="selectedBooking.durationMinutes">
                    <div class="telemetry-icon-box blue">
                      <span class="material-symbols-outlined">timer</span>
                    </div>
                    <div class="telemetry-body">
                      <span class="telemetry-lbl">EST. DURATION</span>
                      <span class="telemetry-val">{{ formatDuration(selectedBooking.durationMinutes) }}</span>
                    </div>
                  </div>

                  <!-- Distance Tile -->
                  <div class="telemetry-tile" *ngIf="selectedBooking.mileageText">
                    <div class="telemetry-icon-box green">
                      <span class="material-symbols-outlined">route</span>
                    </div>
                    <div class="telemetry-body">
                      <span class="telemetry-lbl">EST. DISTANCE</span>
                      <span class="telemetry-val">{{ getPrimaryDistance(selectedBooking.mileageText) }}</span>
                      <span class="telemetry-breakdown" *ngIf="getDistanceSubtext(selectedBooking.mileageText)">
                        {{ getDistanceSubtext(selectedBooking.mileageText) }}
                      </span>
                    </div>
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
      padding: 12px 14px 40px 14px;
      max-width: 640px;
      margin: 0 auto;
      box-sizing: border-box;
      position: relative;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }

    /* 1. Executive Fleet Overview Card */
    .overview-hero-card {
      background: #FFFFFF;
      border-radius: 16px;
      padding: 14px 16px;
      color: #0F172A;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
      border: 1px solid #E2E8F0;
    }
    .hero-metric-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .hero-metric-col {
      display: flex;
      flex-direction: column;
      gap: 2px;
      flex: 1;
      text-align: center;
    }
    .hero-metric-col:first-child { text-align: left; }
    .hero-metric-col:last-child { text-align: right; }
    .hero-metric-label {
      font-size: 9.5px;
      font-weight: 800;
      color: #64748B;
      letter-spacing: 0.4px;
      text-transform: uppercase;
    }
    .hero-metric-val {
      font-size: 18px;
      font-weight: 900;
      color: #0F172A;
      display: flex;
      align-items: baseline;
      justify-content: center;
      gap: 2px;
    }
    .hero-metric-col:first-child .hero-metric-val { justify-content: flex-start; }
    .hero-metric-col:last-child .hero-metric-val { justify-content: flex-end; }
    .hero-metric-val.green { color: #16A34A; }
    .hero-metric-val.blue { color: #2563EB; }
    .metric-cur { font-size: 12.5px; font-weight: 800; }
    .metric-num { font-size: 18px; font-weight: 900; }
    .metric-sub { font-size: 11px; font-weight: 600; color: #64748B; margin-left: 2px; }
    .hero-metric-divider {
      width: 1px;
      height: 28px;
      background: #E2E8F0;
      margin: 0 6px;
    }

    /* 2. Controls & Filter Bar */
    .controls-bar {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .search-input-box {
      display: flex;
      align-items: center;
      background: #FFFFFF;
      border: 1px solid #CBD5E1;
      border-radius: 12px;
      padding: 0 12px;
      height: 40px;
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.02);
    }
    .search-icon {
      font-size: 18px;
      color: #94A3B8;
      margin-right: 8px;
    }
    .search-input {
      flex: 1;
      border: none;
      outline: none;
      font-size: 12.5px;
      color: #0F172A;
      background: transparent;
      font-weight: 500;
    }
    .search-input::placeholder {
      color: #94A3B8;
    }
    .clear-search-btn {
      background: transparent;
      border: none;
      padding: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #94A3B8;
      cursor: pointer;
    }
    .clear-search-btn .material-symbols-outlined { font-size: 16px; }

    .filter-tab-bar {
      display: flex;
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 14px;
      padding: 3px;
      gap: 4px;
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.02);
    }
    .tab-btn {
      flex: 1;
      border: none;
      background: transparent;
      padding: 7px 4px;
      border-radius: 10px;
      font-size: 11.5px;
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

    /* 3. Shimmer Loading */
    .shimmer-loading-list {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .shimmer-card {
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 16px;
      padding: 14px 16px;
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .shimmer-line {
      background: linear-gradient(90deg, #F1F5F9 25%, #E2E8F0 50%, #F1F5F9 75%);
      background-size: 200% 100%;
      animation: shimmer 1.5s infinite;
      border-radius: 6px;
    }
    .shimmer-line.header-line { height: 20px; width: 60%; }
    .shimmer-line.route-line-1 { height: 14px; width: 90%; }
    .shimmer-line.route-line-2 { height: 14px; width: 75%; }
    .shimmer-line.footer-line { height: 16px; width: 45%; }
    @keyframes shimmer {
      0% { background-position: 200% 0; }
      100% { background-position: -200% 0; }
    }

    /* 4. Empty State */
    .empty-state {
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 16px;
      padding: 36px 16px;
      text-align: center;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 6px;
    }
    .empty-icon-box {
      width: 48px;
      height: 48px;
      border-radius: 50%;
      background: #F1F5F9;
      color: #94A3B8;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-bottom: 4px;
    }
    .empty-icon-box .material-symbols-outlined { font-size: 26px; }
    .empty-title {
      margin: 0;
      font-size: 14px;
      font-weight: 800;
      color: #0F172A;
    }
    .empty-subtitle {
      margin: 0 0 10px 0;
      font-size: 11.5px;
      color: #64748B;
      max-width: 320px;
      line-height: 1.4;
    }
    .retry-btn {
      background: #F1F5F9;
      border: 1.5px solid #CBD5E1;
      padding: 7px 16px;
      border-radius: 10px;
      font-size: 12px;
      font-weight: 700;
      color: #334155;
      display: flex;
      align-items: center;
      gap: 5px;
      cursor: pointer;
    }
    .retry-btn .material-symbols-outlined { font-size: 15px; }

    /* 5. Booking Cards */
    .bookings-list {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .booking-card {
      position: relative;
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 16px;
      padding: 13px 15px;
      cursor: pointer;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.02);
      transition: transform 0.12s ease, box-shadow 0.12s ease, border-color 0.12s ease;
      display: flex;
      flex-direction: column;
      gap: 8px;
      overflow: hidden;
    }
    .booking-card:hover {
      border-color: #CBD5E1;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.04);
    }
    .booking-card:active {
      transform: scale(0.99);
      background: #F8FAFC;
    }
    .booking-card.active-trip-card {
      border: 2px solid #10B981;
      box-shadow: 0 4px 16px rgba(16, 185, 129, 0.15);
    }

    .active-job-ribbon {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: #DCFCE7;
      border: 1px solid #86EFAC;
      padding: 3px 8px;
      border-radius: 6px;
      font-size: 10px;
      font-weight: 900;
      letter-spacing: 0.4px;
      color: #15803D;
      align-self: flex-start;
      margin-bottom: 2px;
    }
    .active-pulse-beacon {
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background: #16A34A;
      animation: pulse 1.4s infinite;
    }

    .card-header-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .header-left {
      display: flex;
      align-items: center;
      gap: 6px;
      flex-wrap: wrap;
    }
    .booking-ref-badge {
      font-size: 11.5px;
      font-weight: 800;
      color: #0F172A;
      background: #F1F5F9;
      padding: 2px 7px;
      border-radius: 6px;
    }
    .status-pill {
      font-size: 10px;
      font-weight: 800;
      text-transform: uppercase;
      letter-spacing: 0.3px;
      padding: 2px 7px;
      border-radius: 6px;
      display: inline-flex;
      align-items: center;
      gap: 4px;
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
      font-size: 10px;
      font-weight: 800;
      padding: 2px 7px;
      border-radius: 6px;
      background: #F1F5F9;
      color: #475569;
      text-transform: uppercase;
      display: inline-flex;
      align-items: center;
      gap: 3px;
    }
    .payment-ico { font-size: 12px; }
    .payment-pill.cash { background: #DCFCE7; color: #166534; }
    .payment-pill.account { background: #F3E8FF; color: #7E22CE; }
    .payment-pill.card { background: #E0E7FF; color: #3730A3; }
    .payment-pill.rank { background: #FEF3C7; color: #B45309; }

    .booking-fare-text {
      font-weight: 900;
      color: #0F172A;
      font-size: 17px;
      display: flex;
      align-items: baseline;
      gap: 1px;
    }
    .currency-symbol {
      font-size: 13px;
      font-weight: 800;
      color: #CD1A21;
    }

    /* Journey Route Visual */
    .journey-route-preview {
      display: flex;
      gap: 12px;
      padding: 4px 0 6px 0;
      align-items: stretch;
    }
    .route-tracker-col {
      display: flex;
      flex-direction: column;
      align-items: center;
      padding-top: 6px;
      padding-bottom: 6px;
      width: 12px;
      flex-shrink: 0;
    }
    .route-node {
      width: 10px;
      height: 10px;
      border-radius: 50%;
      flex-shrink: 0;
      box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.9);
    }
    .route-node.pickup-node { 
      background: #10B981; 
      border: 2px solid #059669;
    }
    .route-node.dropoff-node { 
      background: #EF4444; 
      border: 2px solid #DC2626;
    }
    .route-stem {
      width: 2px;
      flex: 1;
      min-height: 24px;
      background: #CBD5E1;
      margin: 4px 0;
      border-radius: 1px;
    }

    .route-addresses-col {
      flex: 1;
      min-width: 0;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    
    .stop-entry {
      display: flex;
      flex-direction: column;
      gap: 3px;
      min-width: 0;
    }

    .stop-meta-header {
      display: flex;
      align-items: center;
      gap: 6px;
      flex-wrap: wrap;
    }

    .address-time-pill {
      font-size: 10.5px;
      font-weight: 800;
      background: #F1F5F9;
      color: #334155;
      padding: 2px 7px;
      border-radius: 5px;
      white-space: nowrap;
      flex-shrink: 0;
      letter-spacing: 0.2px;
    }
    .address-time-pill.dropoff-time {
      background: #F8FAFC;
      border: 1px solid #E2E8F0;
    }

    .address-text-full {
      font-size: 14px;
      font-weight: 700;
      color: #0F172A;
      line-height: 1.38;
      word-break: break-word;
      letter-spacing: -0.1px;
    }

    .postcode-tag {
      font-size: 10px;
      font-weight: 800;
      font-family: monospace;
      background: #FEF08A;
      color: #000000;
      padding: 1.5px 6px;
      border-radius: 4px;
      flex-shrink: 0;
      letter-spacing: 0.4px;
      box-shadow: 0 1px 2px rgba(0,0,0,0.05);
    }
    .via-indicator-row {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      font-size: 11px;
      font-weight: 800;
      color: #B45309;
      background: #FEF3C7;
      border: 1px solid #FDE68A;
      padding: 2px 8px;
      border-radius: 6px;
      align-self: flex-start;
      margin: 1px 0 1px 0;
    }
    .via-icon { font-size: 14px; }

    .card-footer-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      border-top: 1px solid #F1F5F9;
      padding-top: 8px;
      font-size: 11px;
    }
    .footer-left-meta {
      display: flex;
      align-items: center;
      gap: 8px;
      flex-wrap: wrap;
    }
    .passenger-tag {
      display: flex;
      align-items: center;
      gap: 4px;
      color: #475569;
      font-weight: 600;
    }
    .pass-icon {
      font-size: 15px;
      color: #94A3B8;
    }
    .vehicle-class-tag {
      display: inline-flex;
      align-items: center;
      gap: 3px;
      font-size: 10.5px;
      font-weight: 600;
      color: #64748B;
      background: #F8FAFC;
      border: 1px solid #E2E8F0;
      padding: 1px 6px;
      border-radius: 4px;
    }
    .vehicle-ico { font-size: 13px; color: #94A3B8; }

    .view-details-action {
      display: flex;
      align-items: center;
      gap: 2px;
      color: #CD1A21;
      font-weight: 800;
      font-size: 11.5px;
      flex-shrink: 0;
    }
    .view-details-action .material-symbols-outlined { font-size: 16px; }

    /* ================= 5. MODAL / BOTTOM SHEET ================= */
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
      padding: 12px 16px;
      display: flex;
      align-items: center;
      gap: 10px;
      border-bottom: 1px solid #E2E8F0;
      background: #FAFAFC;
      overflow-x: auto;
      scrollbar-width: none;
    }
    .sheet-quick-actions::-webkit-scrollbar {
      display: none;
    }
    .action-pill {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 7px;
      height: 42px;
      padding: 0 16px;
      border-radius: 12px;
      font-size: 13px;
      font-weight: 700;
      letter-spacing: 0.2px;
      cursor: pointer;
      text-decoration: none;
      white-space: nowrap;
      border: 1.5px solid transparent;
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
      transition: all 0.18s cubic-bezier(0.16, 1, 0.3, 1);
      flex-shrink: 0;
    }
    .action-pill:active { 
      transform: scale(0.97); 
      opacity: 0.9;
    }
    .action-pill .material-symbols-outlined { 
      font-size: 18px; 
      line-height: 1;
    }

    .action-pill.start-trip-btn {
      background: linear-gradient(135deg, #CD1A21 0%, #E11D48 100%);
      color: #FFFFFF;
      box-shadow: 0 3px 10px rgba(205, 26, 33, 0.28);
    }
    .action-pill.status-toggle {
      background: linear-gradient(135deg, #059669 0%, #10B981 100%);
      color: #FFFFFF;
      box-shadow: 0 3px 10px rgba(16, 185, 129, 0.32);
    }
    .action-pill.status-toggle.pickedUp {
      background: linear-gradient(135deg, #2563EB 0%, #3B82F6 100%);
      box-shadow: 0 3px 10px rgba(37, 99, 235, 0.32);
    }
    .action-pill.call-btn {
      background: #ECFDF5;
      color: #047857;
      border-color: #6EE7B7;
      box-shadow: 0 1px 4px rgba(16, 185, 129, 0.12);
    }
    .action-pill.sms-btn {
      background: #EFF6FF;
      color: #1D4ED8;
      border-color: #93C5FD;
      box-shadow: 0 1px 4px rgba(59, 130, 246, 0.12);
    }
    .action-pill.copy-btn {
      background: #FFFFFF;
      color: #475569;
      border-color: #CBD5E1;
      width: 42px;
      padding: 0;
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
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
    .fare-metrics-stack {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }

    .metric-fare-banner {
      background: #FEF2F2;
      border: 1px solid #FECACA;
      border-radius: 12px;
      padding: 10px 14px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 10px;
    }

    .fare-banner-left {
      display: flex;
      flex-direction: column;
      gap: 1px;
    }

    .metric-sec-label {
      font-size: 9.5px;
      font-weight: 800;
      color: #991B1B;
      letter-spacing: 0.5px;
    }

    .tile-main-fare {
      font-size: 22px;
      font-weight: 900;
      color: #0F172A;
      display: flex;
      align-items: baseline;
      gap: 1px;
    }

    .tile-main-fare .cur { color: #CD1A21; font-size: 15px; font-weight: 900; }

    .payment-badge-pill {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      padding: 4px 10px;
      border-radius: 20px;
      font-size: 11px;
      font-weight: 800;
      letter-spacing: 0.4px;
      text-transform: uppercase;
      background: #DCFCE7;
      color: #15803D;
      border: 1px solid #BBF7D0;
    }

    .payment-badge-pill.card {
      background: #EFF6FF;
      color: #1D4ED8;
      border-color: #BFDBFE;
    }

    .payment-badge-pill.account {
      background: #FAF5FF;
      color: #7E22CE;
      border-color: #E9D5FF;
    }

    .payment-badge-pill .badge-ico {
      font-size: 14px;
    }

    .telemetry-row {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }

    .telemetry-tile {
      flex: 1 1 140px;
      min-width: 0;
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 12px;
      padding: 9px 12px;
      display: flex;
      align-items: flex-start;
      gap: 9px;
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.03);
    }

    .telemetry-icon-box {
      width: 32px;
      height: 32px;
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }

    .telemetry-icon-box .material-symbols-outlined {
      font-size: 18px;
    }

    .telemetry-icon-box.blue {
      background: #EFF6FF;
      color: #2563EB;
    }

    .telemetry-icon-box.green {
      background: #ECFDF5;
      color: #059669;
    }

    .telemetry-body {
      display: flex;
      flex-direction: column;
      gap: 1px;
      min-width: 0;
      flex: 1;
    }

    .telemetry-lbl {
      font-size: 9.5px;
      font-weight: 800;
      color: #64748B;
      letter-spacing: 0.4px;
      text-transform: uppercase;
    }

    .telemetry-val {
      font-size: 13.5px;
      font-weight: 800;
      color: #0F172A;
      line-height: 1.25;
      word-break: break-word;
    }

    .telemetry-breakdown {
      font-size: 10.5px;
      font-weight: 700;
      color: #059669;
      background: #F0FDF4;
      border: 1px solid #DCFCE7;
      padding: 1px 5px;
      border-radius: 4px;
      margin-top: 3px;
      display: inline-block;
      line-height: 1.3;
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
      height: 48px;
      background: #F1F5F9;
      border: 1.5px solid #CBD5E1;
      border-radius: 24px;
      overflow: hidden;
      display: flex;
      align-items: center;
      justify-content: center;
      user-select: none;
      box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.04);
    }
    .slide-fill-bar {
      position: absolute;
      left: 0;
      top: 0;
      bottom: 0;
      background: linear-gradient(90deg, #10B981, #059669);
      border-radius: 24px;
      transition: width 0.05s ease;
      opacity: 0.9;
    }
    .slide-track-text {
      position: relative;
      z-index: 2;
      font-size: 13px;
      font-weight: 700;
      color: #1E293B;
      letter-spacing: 0.3px;
      pointer-events: none;
    }
    .slide-track-text.submitting {
      color: #059669;
    }
    .slide-thumb-btn {
      position: absolute;
      left: 3px;
      width: 40px;
      height: 40px;
      border-radius: 50%;
      background: #FFFFFF;
      color: #10B981;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: grab;
      z-index: 3;
      border: 1.5px solid #E2E8F0;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
      touch-action: none;
      transition: box-shadow 0.15s ease;
    }
    .slide-thumb-btn:active { 
      cursor: grabbing; 
      box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
    }
    .slide-thumb-btn .material-symbols-outlined {
      font-size: 22px;
      font-weight: 700;
    }

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
    :host-context(.dark-theme) .overview-hero-card {
      background: #1E1E24;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .hero-metric-divider {
      background: #2D2D35;
    }
    :host-context(.dark-theme) .search-input-box {
      background: #1E1E24;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .search-input {
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .filter-tab-bar {
      background: #1E1E24;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .tab-btn:not(.active) {
      color: #94A3B8;
    }
    :host-context(.dark-theme) .booking-card,
    :host-context(.dark-theme) .empty-state,
    :host-context(.dark-theme) .shimmer-card {
      background: #1E1E24;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .booking-ref-badge,
    :host-context(.dark-theme) .address-time-pill,
    :host-context(.dark-theme) .sheet-ref-chip,
    :host-context(.dark-theme) .vehicle-class-tag {
      background: #2D2D35;
      border-color: #3E3E48;
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .booking-fare-text,
    :host-context(.dark-theme) .address-text-full,
    :host-context(.dark-theme) .address-text,
    :host-context(.dark-theme) .empty-title,
    :host-context(.dark-theme) .sheet-passenger-name,
    :host-context(.dark-theme) .stop-address-txt,
    :host-context(.dark-theme) .tile-main-fare,
    :host-context(.dark-theme) .tile-val,
    :host-context(.dark-theme) .spec-val {
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .route-stem {
      background: #3E3E48 !important;
    }
    :host-context(.dark-theme) .route-node {
      box-shadow: 0 0 0 2px #1E1E24 !important;
    }
    :host-context(.dark-theme) .card-footer-row,
    :host-context(.dark-theme) .sheet-header,
    :host-context(.dark-theme) .sheet-footer {
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .sheet-quick-actions {
      background: #16161A;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .action-pill.call-btn {
      background: #064E3B;
      border-color: #059669;
      color: #A7F3D0;
    }
    :host-context(.dark-theme) .action-pill.sms-btn {
      background: #1E3A8A;
      border-color: #2563EB;
      color: #BFDBFE;
    }
    :host-context(.dark-theme) .action-pill.copy-btn {
      background: #2D2D35;
      border-color: #3E3E48;
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .slide-complete-track {
      background: #2D2D35;
      border-color: #3E3E48;
    }
    :host-context(.dark-theme) .slide-track-text {
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .slide-thumb-btn {
      background: #1E1E24;
      color: #10B981;
      border-color: #3E3E48;
    }
    :host-context(.dark-theme) .modal-sheet {
      background: #1E1E24;
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .detail-block-card {
      background: #16161A;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .metric-fare-banner {
      background: #2A1719 !important;
      border-color: #4C1D24 !important;
    }
    :host-context(.dark-theme) .metric-sec-label {
      color: #F87171 !important;
    }
    :host-context(.dark-theme) .telemetry-tile {
      background: #1E1E24 !important;
      border-color: #2D2D35 !important;
    }
    :host-context(.dark-theme) .telemetry-val {
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .telemetry-lbl {
      color: #94A3B8 !important;
    }
    :host-context(.dark-theme) .telemetry-icon-box.blue {
      background: #1E3A8A !important;
      color: #93C5FD !important;
    }
    :host-context(.dark-theme) .telemetry-icon-box.green {
      background: #064E3B !important;
      color: #A7F3D0 !important;
    }
    :host-context(.dark-theme) .telemetry-breakdown {
      background: #064E3B !important;
      border-color: #059669 !important;
      color: #A7F3D0 !important;
    }
    :host-context(.dark-theme) .sheet-close-btn,
    :host-context(.dark-theme) .sheet-dismiss-btn,
    :host-context(.dark-theme) .retry-btn {
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
  searchQuery = '';
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

  onSearchInput(event: Event): void {
    const input = event.target as HTMLInputElement;
    this.searchQuery = input ? input.value : '';
    this.cdr.detectChanges();
  }

  clearSearch(): void {
    this.searchQuery = '';
    this.cdr.detectChanges();
  }

  get totalUpcomingFare(): number {
    return this.bookings
      .filter(b => b.status === 'Upcoming')
      .reduce((sum, b) => sum + (b.fare || 0), 0);
  }

  get totalCompletedFare(): number {
    return this.bookings
      .filter(b => b.status === 'Completed')
      .reduce((sum, b) => sum + (b.fare || 0), 0);
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

  formatDuration(minutes: number): string {
    if (!minutes || isNaN(minutes)) return '';
    if (minutes >= 60) {
      const h = Math.floor(minutes / 60);
      const m = minutes % 60;
      return `${h}h ${m > 0 ? m + 'm ' : ''}(${minutes} mins)`;
    }
    return `${minutes} mins`;
  }

  getPrimaryDistance(mileageText: string): string {
    if (!mileageText) return '';
    const text = mileageText.trim();
    if (text.includes('-') || text.includes('(')) {
      const parts = text.split(/[-–(]/);
      if (parts.length > 0 && parts[0].trim().length > 0) {
        return parts[0].trim();
      }
    }
    if (!isNaN(Number(text))) {
      return `${text} miles`;
    }
    return text;
  }

  getDistanceSubtext(mileageText: string): string {
    if (!mileageText) return '';
    const deadMatch = mileageText.match(/Dead\s*Miles?:\s*([0-9.]+)/i);
    const tripMatch = mileageText.match(/Trip\s*Miles?:\s*([0-9.]+)/i);
    if (deadMatch || tripMatch) {
      const parts: string[] = [];
      if (deadMatch) parts.push(`Dead: ${deadMatch[1]} mi`);
      if (tripMatch) parts.push(`Trip: ${tripMatch[1]} mi`);
      return parts.join(' • ');
    }
    return '';
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
    let list = this.activeTab === 'All' ? this.bookings : this.bookings.filter(b => b.status === this.activeTab);
    if (this.searchQuery.trim()) {
      const q = this.searchQuery.toLowerCase().trim();
      list = list.filter(b => 
        b.id.toLowerCase().includes(q) ||
        b.passenger.toLowerCase().includes(q) ||
        b.pickup.toLowerCase().includes(q) ||
        b.dropoff.toLowerCase().includes(q) ||
        (b.pickupPostCode && b.pickupPostCode.toLowerCase().includes(q)) ||
        (b.destinationPostCode && b.destinationPostCode.toLowerCase().includes(q))
      );
    }
    return list;
  }

  getTabCount(tab: string): number {
    if (tab === 'All') return this.bookings.length;
    return this.bookings.filter(b => b.status === tab).length;
  }
}
