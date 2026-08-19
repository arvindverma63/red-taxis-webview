import { Component, OnInit, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute } from '@angular/router';
import { DriverService } from '../services/driver.service';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { Subscription, forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs/operators';

interface CompletedJob {
  id: string;
  tripDescription: string;
  timeString: string;
  amount: number;
}

interface ActiveJob {
  id: string;
  passenger: string;
  fare: number;
  pickup: string;
  dropoff: string;
  pickupPostCode?: string;
  destinationPostCode?: string;
  time: string;
  date: string;
  status: string;
  paymentType: string;
}

interface DashTotals {
  earningsTotalToday: number;
  totalJobCountToday: number;
  earningsTotalWeek: number;
  totalJobCountWeek: number;
  earningsTotalMonth: number;
  totalJobCountMonth: number;
}

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, MatSnackBarModule],
  template: `
    <div 
      class="dashboard-container"
      (touchstart)="onTouchStart($event)"
      (touchmove)="onTouchMove($event)"
      (touchend)="onTouchEnd()"
    >
      <!-- Floating Native Pull-to-Refresh Circular Spinner -->
      <div 
        class="floating-refresh-spinner"
        [class.visible]="pullDistance > 0 || isRefreshing"
        [style.transform]="'translate(-50%, ' + (isRefreshing ? '20px' : (pullDistance - 45) + 'px)')"
        [style.opacity]="isRefreshing ? 1 : (pullDistance / 50)"
      >
        <span 
          class="material-symbols-outlined native-spin-icon"
          [class.spinning]="isRefreshing"
          [style.transform]="'rotate(' + (pullDistance * 5) + 'deg)'"
        >
          refresh
        </span>
      </div>

      <!-- 1. Active Booking Card (If there is an active/upcoming booking) -->
      <div class="dash-card active-booking-card" *ngIf="activeBooking">
        <div class="active-badge-row">
          <div class="pulsing-badge">
            <span class="pulse-dot"></span>
            <span class="badge-text">ACTIVE ALLOCATION</span>
          </div>
          <span class="active-fare">£{{ activeBooking.fare.toFixed(2) }}</span>
        </div>

        <div class="active-passenger-row">
          <div class="passenger-avatar">
            <span class="material-symbols-outlined">person</span>
          </div>
          <div class="passenger-info">
            <span class="passenger-name">{{ activeBooking.passenger }}</span>
            <span class="booking-id-txt">#{{ activeBooking.id }} &bull; {{ activeBooking.time }} ({{ activeBooking.date }})</span>
          </div>
        </div>

        <!-- Route timeline -->
        <div class="active-route">
          <div class="route-node">
            <span class="material-symbols-outlined node-icon green">my_location</span>
            <div class="node-text">
              <span class="node-lbl green">PICKUP</span>
              <p class="node-addr">{{ activeBooking.pickup }}</p>
            </div>
            <a 
              [href]="getMapUrl(activeBooking.pickupPostCode || activeBooking.pickup)" 
              target="_blank" 
              class="map-btn" 
              title="Navigate with Google Maps"
            >
              <span class="material-symbols-outlined">navigation</span>
            </a>
          </div>

          <div class="route-node">
            <span class="material-symbols-outlined node-icon red">location_on</span>
            <div class="node-text">
              <span class="node-lbl red">DROPOFF</span>
              <p class="node-addr">{{ activeBooking.dropoff }}</p>
            </div>
            <a 
              [href]="getMapUrl(activeBooking.destinationPostCode || activeBooking.dropoff)" 
              target="_blank" 
              class="map-btn" 
              title="Navigate with Google Maps"
            >
              <span class="material-symbols-outlined">navigation</span>
            </a>
          </div>
        </div>

        <!-- Active Actions -->
        <div class="active-actions-row">
          <button 
            class="dash-status-btn" 
            [ngClass]="activeTripProgress"
            (click)="advanceActiveTrip()"
          >
            <span class="material-symbols-outlined">{{ getActiveStatusIcon() }}</span>
            <span>{{ getActiveStatusLabel() }}</span>
          </button>
          <button class="dash-complete-btn" (click)="completeActiveBooking()">
            <span class="material-symbols-outlined">check_circle</span>
            <span>Complete</span>
          </button>
        </div>
      </div>

      <!-- 2. Earnings Stats Card with Time Filter (Daily / Weekly / Monthly) -->
      <div class="dash-card earnings-card">
        <!-- Time Filter Tabs -->
        <div class="time-filter-row">
          <button 
            *ngFor="let filter of ['Daily', 'Weekly', 'Monthly']" 
            class="filter-pill"
            [class.active]="selectedFilter === filter"
            (click)="setFilter(filter)"
          >
            {{ filter }}
          </button>
        </div>

        <!-- Circular Arc Gauge -->
        <div class="gauge-container">
          <svg class="gauge-svg" width="180" height="180" viewBox="0 0 180 180">
            <circle
              class="gauge-bg"
              cx="90"
              cy="90"
              r="75"
              fill="none"
              stroke="#ECEFF1"
              stroke-width="12"
              stroke-dasharray="353.43"
              stroke-dashoffset="0"
              transform="rotate(135 90 90)"
            />
            <circle
              class="gauge-progress"
              cx="90"
              cy="90"
              r="75"
              fill="none"
              stroke="#CD1A21"
              stroke-width="12"
              stroke-linecap="round"
              stroke-dasharray="353.43"
              [style.strokeDashoffset]="gaugeDashOffset"
              transform="rotate(135 90 90)"
            />
          </svg>
          <div class="gauge-center-content">
            <span class="gauge-filter-label">{{ selectedFilter }} Earnings</span>
            <span class="gauge-earnings-value">£{{ currentEarnings.toFixed(2) }}</span>
            <span class="gauge-jobs-count">Total Jobs: {{ currentJobCount }}</span>
          </div>
        </div>
      </div>

      <!-- 3. Quick Booking Counter Grid -->
      <div class="counts-grid">
        <div class="count-card">
          <span class="count-num green">{{ todaysCount }}</span>
          <span class="count-lbl">TODAY'S JOBS</span>
        </div>
        <div class="count-card">
          <span class="count-num blue">{{ futureCount }}</span>
          <span class="count-lbl">FUTURE JOBS</span>
        </div>
        <div class="count-card">
          <span class="count-num red">{{ completedTripsCount }}</span>
          <span class="count-lbl">COMPLETED</span>
        </div>
      </div>

      <!-- 4. Developer Simulation Deck (When Online) -->
      <div class="dash-card sim-card" *ngIf="isOnline">
        <div class="card-title-row">
          <span class="material-symbols-outlined card-title-icon">science</span>
          <span class="card-title">Developer Simulation Deck</span>
        </div>
        <p class="sim-desc">Trigger a test booking offer to verify push overlays & acceptance:</p>
        <div class="sim-button-row">
          <button class="sim-btn outlined" (click)="triggerSimulation('cash')">
            <span class="material-symbols-outlined btn-inline-icon">payments</span>
            <span>Cash Booking</span>
          </button>
          <button class="sim-btn outlined" (click)="triggerSimulation('card')">
            <span class="material-symbols-outlined btn-inline-icon">credit_card</span>
            <span>Card Booking</span>
          </button>
        </div>
      </div>

      <!-- 5. Recent Completed Trips List Card -->
      <div class="dash-card trips-list-card">
        <h3 class="section-title">Recent Completed Trips</h3>
        
        <div *ngIf="isLoading && !isRefreshing" class="shimmer-placeholder list-shimmer"></div>

        <div *ngIf="!isLoading && completedJobs.length === 0" class="empty-trips-view">
          <span class="material-symbols-outlined empty-trips-icon">history</span>
          <p class="empty-txt">No completed trips recorded yet.</p>
        </div>

        <div class="trips-list" *ngIf="!isLoading && completedJobs.length > 0">
          <div class="trip-item" *ngFor="let job of completedJobs">
            <div class="trip-status-icon">
              <span class="material-symbols-outlined check-icon">check</span>
            </div>
            
            <div class="trip-details">
              <span class="trip-desc">{{ job.tripDescription }}</span>
              <span class="trip-time">{{ job.timeString }}</span>
            </div>

            <span class="trip-fare">£{{ job.amount.toFixed(2) }}</span>
          </div>
        </div>
      </div>

      <!-- Complete Job Form Modal Dialog -->
      <div class="modal-backdrop" *ngIf="showCompleteModal" (click)="showCompleteModal = false">
        <div class="complete-modal-card" (click)="$event.stopPropagation()">
          <div class="modal-header-centered">
            <span class="material-symbols-outlined success-icon-amber">check_circle</span>
            <h3 class="modal-title-centered">Complete Job</h3>
            <p class="modal-subtitle-centered">Enter final trip parameters to submit</p>
          </div>

          <div class="modal-body-form">
            <!-- Payment Field -->
            <div class="modal-form-group">
              <label class="modal-form-lbl">Payment (Account Price)</label>
              <div class="modal-input-wrapper">
                <span class="modal-currency-symbol">£</span>
                <input 
                  type="number" 
                  step="0.01" 
                  class="modal-form-input" 
                  [value]="completeForm.payment" 
                  (input)="completeForm.payment = +$any($event.target).value"
                />
              </div>
            </div>

            <!-- Price Field -->
            <div class="modal-form-group">
              <label class="modal-form-lbl">Price (Driver Price)</label>
              <div class="modal-input-wrapper">
                <span class="modal-currency-symbol">£</span>
                <input 
                  type="number" 
                  step="0.01" 
                  class="modal-form-input" 
                  [value]="completeForm.price" 
                  (input)="completeForm.price = +$any($event.target).value"
                />
              </div>
            </div>

            <!-- Tip Field -->
            <div class="modal-form-group">
              <label class="modal-form-lbl">Tip</label>
              <div class="modal-input-wrapper">
                <span class="modal-currency-symbol">£</span>
                <input 
                  type="number" 
                  step="0.01" 
                  class="modal-form-input" 
                  [value]="completeForm.tip" 
                  (input)="completeForm.tip = +$any($event.target).value"
                />
              </div>
            </div>

            <!-- Waiting Time Field -->
            <div class="modal-form-group">
              <label class="modal-form-lbl">Waiting Time (Minutes)</label>
              <div class="modal-input-wrapper no-symbol">
                <input 
                  type="number" 
                  step="1" 
                  class="modal-form-input" 
                  [value]="completeForm.waitingTime" 
                  (input)="completeForm.waitingTime = +$any($event.target).value"
                />
              </div>
            </div>

            <!-- Parking Charge Field -->
            <div class="modal-form-group">
              <label class="modal-form-lbl">Parking Charge</label>
              <div class="modal-input-wrapper no-symbol">
                <input 
                  type="number" 
                  step="1" 
                  class="modal-form-input" 
                  [value]="completeForm.parkingCharge" 
                  (input)="completeForm.parkingCharge = +$any($event.target).value"
                />
              </div>
            </div>
          </div>

          <div class="modal-footer-buttons">
            <button class="modal-btn submit-btn" (click)="submitCompleteJob()" [disabled]="isSubmitting">
              {{ isSubmitting ? 'Submitting...' : 'Submit' }}
            </button>
            <button class="modal-btn close-btn" (click)="showCompleteModal = false" [disabled]="isSubmitting">
              Cancel
            </button>
          </div>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .dashboard-container {
      background-color: #F8F9FA;
      min-height: 100vh;
      padding: 10px 14px 48px 14px;
      font-family: 'Roboto', sans-serif;
      display: flex;
      flex-direction: column;
      gap: 14px;
      box-sizing: border-box;
      position: relative;
    }

    /* Floating Native Material Pull-to-Refresh Circular Spinner */
    .floating-refresh-spinner {
      position: fixed;
      top: 0;
      left: 50%;
      width: 42px;
      height: 42px;
      border-radius: 50%;
      background-color: #FFFFFF;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.18);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 9999;
      pointer-events: none;
      transition: transform 0.2s cubic-bezier(0.175, 0.885, 0.32, 1.275), opacity 0.2s ease;
    }
    .native-spin-icon {
      font-size: 24px;
      color: #CD1A21;
      display: inline-block;
      transition: transform 0.05s linear;
    }
    .native-spin-icon.spinning {
      animation: nativeSpin 0.75s linear infinite;
    }
    @keyframes nativeSpin {
      from { transform: rotate(0deg); }
      to { transform: rotate(360deg); }
    }

    /* Common Card Styling */
    .dash-card {
      background-color: #FFFFFF;
      border-radius: 18px;
      padding: 16px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.03);
      border: 1px solid #E0E2EC;
      box-sizing: border-box;
      display: flex;
      flex-direction: column;
      transition: all 0.2s ease-in-out;
    }

    /* Active Booking Card */
    .active-booking-card {
      border: 1.5px solid #CD1A21;
      background-color: #FFFFFF;
      box-shadow: 0 4px 16px rgba(205, 26, 33, 0.08);
      gap: 12px;
    }
    .active-badge-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .pulsing-badge {
      display: flex;
      align-items: center;
      gap: 6px;
      background-color: rgba(205, 26, 33, 0.1);
      padding: 4px 10px;
      border-radius: 20px;
    }
    .pulse-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background-color: #CD1A21;
      animation: pulse 1.5s infinite;
    }
    @keyframes pulse {
      0% { transform: scale(0.9); opacity: 1; }
      50% { transform: scale(1.3); opacity: 0.5; }
      100% { transform: scale(0.9); opacity: 1; }
    }
    .badge-text {
      font-size: 10px;
      font-weight: 800;
      color: #CD1A21;
      letter-spacing: 0.5px;
    }
    .active-fare {
      font-size: 20px;
      font-weight: 900;
      color: #2E7D32;
    }

    .active-passenger-row {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .passenger-avatar {
      width: 38px;
      height: 38px;
      border-radius: 50%;
      background-color: rgba(205, 26, 33, 0.1);
      color: #CD1A21;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .passenger-info {
      display: flex;
      flex-direction: column;
      gap: 1px;
    }
    .passenger-name {
      font-size: 15px;
      font-weight: 800;
      color: #1A1C1E;
    }
    .booking-id-txt {
      font-size: 11px;
      color: #74777F;
      font-weight: 600;
    }

    /* Active Route */
    .active-route {
      display: flex;
      flex-direction: column;
      gap: 10px;
      background-color: #F8F9FA;
      padding: 10px 12px;
      border-radius: 14px;
    }
    .route-node {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .node-icon {
      font-size: 20px;
    }
    .node-icon.green { color: #2E7D32; }
    .node-icon.red { color: #CD1A21; }
    .node-text {
      flex: 1;
      min-width: 0;
    }
    .node-lbl {
      font-size: 9px;
      font-weight: 800;
      letter-spacing: 0.5px;
    }
    .node-lbl.green { color: #2E7D32; }
    .node-lbl.red { color: #CD1A21; }
    .node-addr {
      margin: 0;
      font-size: 12px;
      font-weight: 700;
      color: #1A1C1E;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .map-btn {
      width: 32px;
      height: 32px;
      border-radius: 50%;
      background-color: #FFFFFF;
      border: 1px solid #E0E2EC;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #1565C0;
      text-decoration: none;
      box-shadow: 0 2px 4px rgba(0,0,0,0.04);
    }

    .active-actions-row {
      display: flex;
      gap: 8px;
    }
    .dash-status-btn {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      padding: 10px 12px;
      border-radius: 24px;
      border: 1px solid #BBDEFB;
      background-color: #E3F2FD;
      color: #1565C0;
      font-size: 12px;
      font-weight: 700;
      cursor: pointer;
    }
    .dash-status-btn.arrived {
      background-color: #FFF8E1;
      color: #E65100;
      border-color: #FFE082;
    }
    .dash-status-btn.pickedUp {
      background-color: #E8F5E9;
      color: #2E7D32;
      border-color: #A5D6A7;
    }
    .dash-complete-btn {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      padding: 10px 12px;
      border-radius: 24px;
      border: none;
      background-color: #CD1A21;
      color: #FFFFFF;
      font-size: 12px;
      font-weight: 800;
      cursor: pointer;
      box-shadow: 0 2px 8px rgba(205, 26, 33, 0.25);
    }

    /* Earnings Card */
    .earnings-card {
      align-items: center;
      padding: 18px 16px;
    }
    .time-filter-row {
      display: flex;
      background-color: #F1F3F9;
      border-radius: 20px;
      padding: 3px;
      gap: 4px;
      margin-bottom: 12px;
    }
    .filter-pill {
      border: none;
      background: transparent;
      padding: 6px 14px;
      border-radius: 16px;
      font-size: 12px;
      font-weight: 700;
      color: #546E7A;
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .filter-pill.active {
      background-color: #CD1A21;
      color: #FFFFFF;
      box-shadow: 0 2px 6px rgba(205, 26, 33, 0.2);
    }

    .gauge-container {
      position: relative;
      width: 180px;
      height: 180px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .gauge-svg {
      position: absolute;
      top: 0; left: 0;
    }
    .gauge-center-content {
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
      z-index: 2;
    }
    .gauge-filter-label {
      font-size: 12px;
      font-weight: 700;
      color: #74777F;
    }
    .gauge-earnings-value {
      font-size: 26px;
      font-weight: 900;
      color: #1A1C1E;
      margin: 2px 0;
    }
    .gauge-jobs-count {
      font-size: 12px;
      font-weight: 700;
      color: #CD1A21;
    }

    /* Booking Counts Grid */
    .counts-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 10px;
    }
    .count-card {
      background-color: #FFFFFF;
      border: 1px solid #E0E2EC;
      border-radius: 16px;
      padding: 12px 10px;
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
      box-shadow: 0 2px 6px rgba(0,0,0,0.02);
    }
    .count-num {
      font-size: 20px;
      font-weight: 900;
      margin-bottom: 2px;
    }
    .count-num.green { color: #2E7D32; }
    .count-num.blue { color: #1565C0; }
    .count-num.red { color: #CD1A21; }
    .count-lbl {
      font-size: 9px;
      font-weight: 800;
      color: #90A4AE;
      letter-spacing: 0.3px;
    }

    .card-header-with-action {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 12px;
    }
    .section-title {
      margin: 0;
      font-size: 12px;
      font-weight: 900;
      color: #546E7A;
      letter-spacing: 0.5px;
      text-transform: uppercase;
    }
    .refresh-icon-btn {
      background: transparent;
      border: none;
      color: #546E7A;
      cursor: pointer;
      padding: 4px;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 50%;
    }
    .refresh-icon-btn:active {
      background-color: #ECEFF1;
    }

    /* Simulation Deck card styling */
    .card-title-row {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 6px;
    }
    .card-icon {
      font-size: 16px;
    }
    .card-title {
      font-size: 13px;
      font-weight: 900;
      color: #37474F;
    }
    .sim-desc {
      margin: 0 0 12px 0;
      font-size: 11px;
      color: #78909C;
      line-height: 1.4;
    }
    .sim-button-row {
      display: flex;
      gap: 10px;
      width: 100%;
    }
    .sim-btn {
      flex: 1;
      padding: 8px 10px;
      border-radius: 10px;
      font-size: 12px;
      font-weight: 700;
      cursor: pointer;
      border: 1px solid #CFD8DC;
      background: #FAFAFA;
      color: #37474F;
      transition: all 0.2s ease;
    }
    .sim-btn:active {
      transform: scale(0.97);
    }

    /* Completed Trips List */
    .trips-list {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .trip-item {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 8px 0;
      border-bottom: 1px solid #F1F3F9;
    }
    .trip-item:last-child {
      border-bottom: none;
    }
    .trip-status-icon {
      width: 24px;
      height: 24px;
      border-radius: 50%;
      background-color: rgba(76, 175, 80, 0.12);
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .check-icon {
      color: #2E7D32;
      font-size: 16px;
      font-weight: bold;
    }
    .trip-details {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 1px;
      min-width: 0;
    }
    .trip-desc {
      font-size: 12px;
      font-weight: 700;
      color: #1A1C1E;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .trip-time {
      font-size: 10px;
      color: #74777F;
    }
    .trip-fare {
      font-size: 14px;
      font-weight: 800;
      color: #2E7D32;
    }
    .empty-trips-view {
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 24px 10px;
      color: #90A4AE;
    }
    .empty-trips-icon {
      font-size: 32px;
      margin-bottom: 4px;
    }
    .empty-txt {
      font-size: 12px;
      margin: 0;
    }
    .shimmer-placeholder {
      background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%);
      background-size: 200% 100%;
      animation: shimmer 1.5s infinite;
      border-radius: 8px;
    }
    .list-shimmer {
      height: 60px;
    }
    @keyframes shimmer {
      0% { background-position: 200% 0; }
      100% { background-position: -200% 0; }
    }

    /* Complete Job Modal CSS */
    .success-icon-amber {
      font-size: 72px;
      color: #FFB300;
      margin-bottom: 12px;
    }
    .complete-modal-card {
      background-color: #FFFFFF;
      border-radius: 20px;
      width: 90%;
      max-width: 380px;
      padding: 24px;
      box-sizing: border-box;
      box-shadow: 0 12px 40px rgba(0, 0, 0, 0.25);
      animation: zoomIn 0.25s cubic-bezier(0.175, 0.885, 0.32, 1.275);
      z-index: 1000;
      display: flex;
      flex-direction: column;
      max-height: 90vh;
      overflow-y: auto;
    }
    @keyframes zoomIn {
      from { transform: scale(0.9); opacity: 0; }
      to { transform: scale(1); opacity: 1; }
    }
    .modal-header-centered {
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
      margin-bottom: 20px;
    }
    .modal-title-centered {
      margin: 0;
      font-size: 20px;
      font-weight: 900;
      color: #1A1C1E;
    }
    .modal-subtitle-centered {
      margin: 4px 0 0 0;
      font-size: 12px;
      color: #74777F;
      font-weight: 500;
    }
    .modal-body-form {
      display: flex;
      flex-direction: column;
      gap: 14px;
      margin-bottom: 24px;
    }
    .modal-form-group {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .modal-form-lbl {
      font-size: 11px;
      font-weight: 700;
      color: #74777F;
      text-transform: uppercase;
      letter-spacing: 0.3px;
    }
    .modal-input-wrapper {
      position: relative;
      display: flex;
      align-items: center;
    }
    .modal-currency-symbol {
      position: absolute;
      left: 12px;
      font-size: 14px;
      font-weight: 700;
      color: #44474E;
    }
    .modal-form-input {
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
    .modal-input-wrapper.no-symbol .modal-form-input {
      padding-left: 12px;
    }
    .modal-form-input:focus {
      border-color: #CD1A21;
      background-color: #FFFFFF;
      box-shadow: 0 0 0 3px rgba(205, 26, 33, 0.1);
    }
    .modal-footer-buttons {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .modal-btn {
      width: 100%;
      height: 44px;
      border-radius: 22px;
      font-size: 14px;
      font-weight: 700;
      cursor: pointer;
      border: none;
      transition: all 0.2s ease;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .modal-btn.submit-btn {
      background-color: #CD1A21;
      color: #FFFFFF;
      box-shadow: 0 3px 8px rgba(205, 26, 33, 0.3);
    }
    .modal-btn.submit-btn:disabled {
      background-color: #ECEFF1;
      color: #90A4AE;
      box-shadow: none;
      cursor: not-allowed;
    }
    .modal-btn.close-btn {
      background-color: transparent;
      color: #CD1A21;
      border: 1px solid #CD1A21;
    }
    .modal-btn.close-btn:disabled {
      border-color: #ECEFF1;
      color: #90A4AE;
      cursor: not-allowed;
    }
  `]
})
export class DashboardComponent implements OnInit, OnDestroy {
  isOnline = false;
  isLoading = false;
  isRefreshing = false;
  selectedFilter: 'Daily' | 'Weekly' | 'Monthly' = 'Daily';

  // Pull-to-refresh touch tracker
  pullStartY = 0;
  pullDistance = 0;

  dashTotals: DashTotals = {
    earningsTotalToday: 0,
    totalJobCountToday: 0,
    earningsTotalWeek: 0,
    totalJobCountWeek: 0,
    earningsTotalMonth: 0,
    totalJobCountMonth: 0
  };

  activeBooking: ActiveJob | null = null;
  activeTripProgress: 'assigned' | 'arrived' | 'pickedUp' = 'assigned';
  showCompleteModal = false;
  isSubmitting = false;
  completeForm = {
    payment: 0,
    price: 0,
    tip: 0,
    waitingTime: 0,
    parkingCharge: 0
  };

  todaysCount = 0;
  futureCount = 0;
  completedTripsCount = 0;
  completedJobs: CompletedJob[] = [];

  private routeSub: Subscription | null = null;

  constructor(
    private route: ActivatedRoute,
    private driverService: DriverService,
    private cdr: ChangeDetectorRef,
    private snackBar: MatSnackBar
  ) {}

  ngOnInit(): void {
    this.routeSub = this.route.queryParams.subscribe(params => {
      const shiftParam = params['shiftStatus'];
      this.isOnline = shiftParam === 'online';
      this.cdr.detectChanges();
    });

    this.loadDashboardData();
  }

  // --- Pull to Refresh Handlers ---
  onTouchStart(e: TouchEvent): void {
    if (window.scrollY === 0) {
      this.pullStartY = e.touches[0].clientY;
    }
  }

  onTouchMove(e: TouchEvent): void {
    if (this.isRefreshing) return;
    if (window.scrollY === 0 && this.pullStartY > 0) {
      const currentY = e.touches[0].clientY;
      const diff = currentY - this.pullStartY;
      if (diff > 0) {
        this.pullDistance = Math.min(75, diff * 0.45);
        this.cdr.detectChanges();
      }
    }
  }

  onTouchEnd(): void {
    if (this.pullDistance > 55 && !this.isRefreshing) {
      this.triggerRefresh();
    } else {
      this.pullDistance = 0;
      this.cdr.detectChanges();
    }
    this.pullStartY = 0;
  }

  triggerRefresh(): void {
    this.isRefreshing = true;
    this.pullDistance = 48;
    this.notifyNativeApp('pull_refresh');
    this.cdr.detectChanges();
    this.loadDashboardData();
  }

  setFilter(filter: string): void {
    this.selectedFilter = filter as 'Daily' | 'Weekly' | 'Monthly';
  }

  get currentEarnings(): number {
    switch (this.selectedFilter) {
      case 'Daily': return this.dashTotals.earningsTotalToday || 0;
      case 'Weekly': return this.dashTotals.earningsTotalWeek || 0;
      case 'Monthly': return this.dashTotals.earningsTotalMonth || 0;
    }
  }

  get currentJobCount(): number {
    switch (this.selectedFilter) {
      case 'Daily': return this.dashTotals.totalJobCountToday || 0;
      case 'Weekly': return this.dashTotals.totalJobCountWeek || 0;
      case 'Monthly': return this.dashTotals.totalJobCountMonth || 0;
    }
  }

  get gaugeDashOffset(): number {
    const maxTarget = 500;
    const progress = Math.min(1, Math.max(0, this.currentEarnings / maxTarget));
    return 353.43 * (1 - progress);
  }

  getMapUrl(addressOrPostcode: string): string {
    return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(addressOrPostcode || '')}`;
  }

  getActiveStatusIcon(): string {
    switch (this.activeTripProgress) {
      case 'assigned': return 'flag';
      case 'arrived': return 'hail';
      case 'pickedUp': return 'navigation';
    }
  }

  getActiveStatusLabel(): string {
    switch (this.activeTripProgress) {
      case 'assigned': return 'Mark Arrived';
      case 'arrived': return 'Mark Picked Up';
      case 'pickedUp': return 'On Trip (POB)';
    }
  }

  advanceActiveTrip(): void {
    if (!this.activeBooking) return;
    const bookingIdNum = parseInt(this.activeBooking.id) || 0;

    if (this.activeTripProgress === 'assigned') {
      this.snackBar.open('Marking arrived at pickup...', 'Dismiss', { duration: 2000 });
      this.activeTripProgress = 'arrived';
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
    } else if (this.activeTripProgress === 'arrived') {
      this.snackBar.open('Starting trip (POB)...', 'Dismiss', { duration: 2000 });
      this.activeTripProgress = 'pickedUp';
      this.snackBar.open('Passenger onboard, trip started!', 'Dismiss', { duration: 2500 });
    }
    this.cdr.detectChanges();
  }

  openCompleteModal(): void {
    if (!this.activeBooking) return;
    const fare = this.activeBooking.fare || 0;
    this.completeForm = {
      payment: 0,
      price: fare,
      tip: 0,
      waitingTime: 0,
      parkingCharge: 0
    };
    this.showCompleteModal = true;
    this.cdr.detectChanges();
  }

  completeActiveBooking(): void {
    this.openCompleteModal();
  }

  submitCompleteJob(): void {
    if (!this.activeBooking) return;
    const bookingIdNum = parseInt(this.activeBooking.id) || 0;

    if (bookingIdNum > 0) {
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
              this.showCompleteModal = false;
              this.activeBooking = null;
              this.loadDashboardData();
              this.snackBar.open('Booking completed successfully!', 'Dismiss', { duration: 3000 });
            },
            error: () => {
              this.isSubmitting = false;
              this.showCompleteModal = false;
              this.activeBooking = null;
              this.loadDashboardData();
              this.snackBar.open('Booking completed successfully!', 'Dismiss', { duration: 3000 });
            }
          });
        },
        error: (err) => {
          console.error('CompleteJob error:', err);
          this.driverService.setActiveJob(0).subscribe({
            next: () => {
              this.isSubmitting = false;
              this.showCompleteModal = false;
              this.activeBooking = null;
              this.loadDashboardData();
              this.snackBar.open('Failed to complete booking.', 'Dismiss', { duration: 3000 });
            },
            error: () => {
              this.isSubmitting = false;
              this.showCompleteModal = false;
              this.activeBooking = null;
              this.loadDashboardData();
              this.snackBar.open('Failed to complete booking.', 'Dismiss', { duration: 3000 });
            }
          });
        }
      });
    } else {
      this.activeBooking = null;
      this.showCompleteModal = false;
      this.loadDashboardData();
      this.snackBar.open('Simulation booking completed.', 'Dismiss', { duration: 2500 });
    }
  }

  loadDashboardData(): void {
    if (!this.isRefreshing) {
      this.isLoading = true;
    }
    this.cdr.detectChanges();

    forkJoin({
      dashTotals: this.driverService.getDashTotals().pipe(catchError(() => of(null))),
      activeJob: this.driverService.getActiveJob().pipe(catchError(() => of(null))),
      bookingsToday: this.driverService.getBookingsToday().pipe(catchError(() => of([]))),
      todaysJobs: this.driverService.getTodaysJobs().pipe(catchError(() => of([]))),
      futureJobs: this.driverService.getFutureJobs().pipe(catchError(() => of([]))),
      completedJobs: this.driverService.getCompletedJobs().pipe(catchError(() => of([])))
    }).subscribe({
      next: (results) => {
        // 1. Dash totals
        if (results.dashTotals) {
          const d = results.dashTotals.value || results.dashTotals;
          this.dashTotals = {
            earningsTotalToday: parseFloat(d.earningsTotalToday || d.todayEarnings || '0') || 0,
            totalJobCountToday: parseInt(d.totalJobCountToday || d.todayJobs || '0') || 0,
            earningsTotalWeek: parseFloat(d.earningsTotalWeek || d.weekEarnings || '0') || 0,
            totalJobCountWeek: parseInt(d.totalJobCountWeek || d.weekJobs || '0') || 0,
            earningsTotalMonth: parseFloat(d.earningsTotalMonth || d.monthEarnings || '0') || 0,
            totalJobCountMonth: parseInt(d.totalJobCountMonth || d.monthJobs || '0') || 0
          };
        }

        const extractList = (res: any): any[] => {
          if (!res) return [];
          if (Array.isArray(res)) return res;
          if (Array.isArray(res.bookings)) return res.bookings;
          if (Array.isArray(res.value)) return res.value;
          if (Array.isArray(res.data)) return res.data;
          return [];
        };

        const todayList = [
          ...extractList(results.bookingsToday),
          ...extractList(results.todaysJobs)
        ];
        const futureList = extractList(results.futureJobs);
        const completedList = extractList(results.completedJobs);

        this.todaysCount = todayList.length;
        this.futureCount = futureList.length;
        this.completedTripsCount = completedList.length;

        // 2. Active Job (From getActiveJob or first upcoming today job)
        let activeRaw = results.activeJob?.value || results.activeJob;
        if (activeRaw && (activeRaw.cancelled || activeRaw.cancelledOnArrival || activeRaw.status === 4 || activeRaw.status === 5 || activeRaw.status === 6)) {
          activeRaw = null;
        }
        if (!activeRaw && todayList.length > 0) {
          activeRaw = todayList.find((j: any) => !j.cancelled && !j.cancelledOnArrival && j.status !== 4 && j.status !== 5 && j.status !== 6);
        }

        if (activeRaw && (activeRaw.bookingId || activeRaw.id || activeRaw.bookingNo)) {
          const fare = parseFloat((activeRaw.price || activeRaw.fare || activeRaw.amount || '0.00').toString());
          this.activeBooking = {
            id: (activeRaw.bookingId || activeRaw.bookingNo || activeRaw.id).toString(),
            passenger: activeRaw.passengerName || activeRaw.cellText || activeRaw.passenger || 'Passenger',
            fare: isNaN(fare) ? 0.00 : fare,
            pickup: activeRaw.pickupAddress || activeRaw.pickup || 'Pickup location',
            dropoff: activeRaw.destinationAddress || activeRaw.dropoffAddress || activeRaw.dropoff || 'Dropoff destination',
            pickupPostCode: activeRaw.pickupPostCode || activeRaw.pickupPostcode || '',
            destinationPostCode: activeRaw.destinationPostCode || activeRaw.destinationPostcode || '',
            time: activeRaw.bookingTime || activeRaw.time || 'Today',
            date: activeRaw.bookingDate || activeRaw.date || 'Today',
            status: activeRaw.status?.toString() || 'Upcoming',
            paymentType: activeRaw.paymentType || 'Cash'
          };
        } else {
          this.activeBooking = null;
        }

        // 3. Completed trips list
        this.completedJobs = completedList.slice(0, 5).map((item: any) => {
          const fare = parseFloat(item.price || item.fare || item.amount || '0.00');
          let timeStr = 'Completed';
          if (item.pickupDateTime || item.completedAt || item.date) {
            const dt = new Date(item.pickupDateTime || item.completedAt || item.date);
            if (!isNaN(dt.getTime())) {
              timeStr = dt.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
            }
          }
          return {
            id: (item.bookingId || item.bookingNo || item.id || '').toString(),
            tripDescription: `${item.pickupAddress || item.pickup || 'Pickup'} ➔ ${item.destinationAddress || item.dropoff || 'Dropoff'}`,
            timeString: timeStr,
            amount: isNaN(fare) ? 0.00 : fare
          };
        });

        this.isLoading = false;
        this.isRefreshing = false;
        this.pullDistance = 0;
        this.cdr.detectChanges();
      },
      error: (err) => {
        console.error('Error loading dashboard data:', err);
        this.isLoading = false;
        this.isRefreshing = false;
        this.pullDistance = 0;
        this.cdr.detectChanges();
      }
    });
  }

  triggerSimulation(type: 'cash' | 'card'): void {
    if (type === 'cash') {
      this.notifyNativeApp('simulate_cash_booking');
    } else {
      this.notifyNativeApp('simulate_card_booking');
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
    this.routeSub?.unsubscribe();
  }
}
