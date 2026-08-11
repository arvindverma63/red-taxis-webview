import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatChipsModule } from '@angular/material/chips';
import { MatDividerModule } from '@angular/material/divider';
import { MatButtonModule } from '@angular/material/button';
import { DriverService } from '../services/driver.service';
import { forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs/operators';

interface Booking {
  id: string;
  pickup: string;
  dropoff: string;
  time: string;
  date: string;
  fare: number;
  paymentType: string;
  status: 'Completed' | 'Upcoming' | 'Cancelled';
  passenger: string;
  notes?: string;
  vehicleType: string;
  expanded?: boolean;
}

@Component({
  selector: 'app-bookings',
  standalone: true,
  imports: [
    CommonModule,
    MatCardModule,
    MatChipsModule,
    MatDividerModule,
    MatButtonModule
  ],
  template: `
    <div class="material-container">
      <!-- Tabs as Pills -->
      <mat-chip-listbox class="full-width-pills" [hideSingleSelectionIndicator]="true" aria-label="Select booking filter">
        <mat-chip-option 
          *ngFor="let tab of tabs" 
          [selected]="activeTab === tab"
          (selectable)="true"
          (selectionChange)="onChipSelectionChange(tab, $event.selected)"
          class="pill-chip"
        >
          {{ tab }}
        </mat-chip-option>
      </mat-chip-listbox>

      <!-- Bookings List -->
      <div class="bookings-list">
        <div *ngIf="filteredBookings.length === 0" class="empty-state">
          <span class="material-symbols-outlined empty-icon">assignment_late</span>
          <p class="mat-body-medium">No {{ activeTab.toLowerCase() }} bookings found.</p>
        </div>

        <mat-card 
          *ngFor="let booking of filteredBookings" 
          class="booking-mat-card" 
          [class.expanded]="booking.expanded"
          (click)="toggleExpand(booking)"
        >
          <!-- Card Top Header -->
          <div class="card-top">
            <div class="booking-ref">
              <span class="ref-label">BOOKING ID</span>
              <span class="ref-val">{{ booking.id }}</span>
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
                    <span class="node-address">{{ booking.pickup }}</span>
                  </div>
                </div>
              </div>

              <div class="timeline-node">
                <span class="material-symbols-outlined node-icon red-icon">location_on</span>
                <div class="node-content">
                  <div class="time-address">
                    <span class="node-time-placeholder"></span>
                    <span class="node-address">{{ booking.dropoff }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <mat-divider></mat-divider>

          <!-- Card Bottom Details & Toggles -->
          <div class="card-bottom">
            <span class="status-badge" [ngClass]="booking.status.toLowerCase()">
              {{ booking.status }}
            </span>
            <span class="payment-badge">
              {{ booking.paymentType }}
            </span>
            <span class="spacer"></span>
            <span class="material-symbols-outlined expand-chevron" [class.rotated]="booking.expanded">
              expand_more
            </span>
          </div>

          <!-- Expanded Details Section -->
          <div class="expanded-details" *ngIf="booking.expanded" (click)="$event.stopPropagation()">
            <mat-divider></mat-divider>
            <div class="details-grid">
              <div class="detail-cell">
                <span class="detail-lbl">Passenger</span>
                <span class="detail-val">{{ booking.passenger }}</span>
              </div>
              <div class="detail-cell">
                <span class="detail-lbl">Vehicle Class</span>
                <span class="detail-val">{{ booking.vehicleType }}</span>
              </div>
              <div class="detail-cell">
                <span class="detail-lbl">Date</span>
                <span class="detail-val">{{ booking.date }}</span>
              </div>
            </div>
            <div class="detail-notes" *ngIf="booking.notes">
              <span class="detail-lbl">Driver Notes</span>
              <p class="notes-txt">"{{ booking.notes }}"</p>
            </div>
          </div>
        </mat-card>
      </div>
    </div>
  `,
  styles: [`
    .material-container {
      padding: 16px;
      background-color: var(--background-color);
      min-height: 100vh;
      font-family: 'Roboto', sans-serif;
    }
    
    /* Pills Layout Override */
    .full-width-pills {
      margin-bottom: 12px;
      display: flex;
      width: 100%;
    }
    ::ng-deep .full-width-pills .mat-mdc-chip-listbox-wrapper {
      display: flex;
      width: 100%;
      gap: 8px;
    }
    ::ng-deep .pill-chip {
      flex: 1;
      border-radius: 20px !important;
      min-height: 36px !important;
      border: 1px solid var(--border-color) !important;
      background-color: var(--surface-color) !important;
      box-shadow: none !important;
    }
    ::ng-deep .pill-chip .mat-mdc-chip-checkmark {
      display: none !important;
    }
    ::ng-deep .pill-chip .mdc-evolution-chip__cell--primary,
    ::ng-deep .pill-chip .mdc-evolution-chip__action {
      justify-content: center;
      width: 100%;
      padding: 0 4px !important;
    }
    ::ng-deep .pill-chip.mat-mdc-chip-selected {
      background-color: var(--primary-color) !important;
      border-color: var(--primary-color) !important;
    }
    ::ng-deep .pill-chip.mat-mdc-chip-selected .mdc-evolution-chip__text-label {
      color: #FFFFFF !important;
      font-weight: 700 !important;
    }
    ::ng-deep .pill-chip .mdc-evolution-chip__text-label {
      color: var(--text-secondary);
      font-size: 13px;
      font-weight: 600;
    }
    
    .bookings-list {
      padding-top: 8px;
      display: flex;
      flex-direction: column;
      gap: 14px;
    }
    
    /* Premium Booking Card Layout */
    .booking-mat-card {
      border: 1px solid var(--border-color);
      box-shadow: 0 1px 3px rgba(0,0,0,0.02) !important;
      border-radius: 12px !important;
      cursor: pointer;
      background-color: var(--surface-color);
      transition: all 0.2s ease-in-out;
    }
    .booking-mat-card:hover {
      transform: translateY(-2px);
      box-shadow: 0 6px 12px rgba(0,0,0,0.04) !important;
      border-color: #CFD8DC;
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
      font-weight: 700;
      color: var(--text-secondary);
      letter-spacing: 1px;
    }
    .ref-val {
      font-size: 13px;
      font-weight: 700;
      color: var(--text-primary);
    }
    .booking-price {
      font-size: 18px;
      font-weight: 800;
      color: var(--primary-color);
    }

    /* Route Timeline layout */
    .card-middle {
      padding: 16px;
    }
    .timeline-container {
      position: relative;
      display: flex;
      flex-direction: column;
      gap: 16px;
    }
    .timeline-line {
      position: absolute;
      left: 11px;
      top: 20px;
      bottom: 20px;
      width: 2px;
      background-color: var(--border-color);
      z-index: 1;
    }
    .timeline-node {
      position: relative;
      display: flex;
      align-items: flex-start;
      gap: 14px;
      z-index: 2;
    }
    .node-icon {
      font-size: 24px;
      width: 24px;
      height: 24px;
      border-radius: 50%;
      background-color: var(--surface-color);
      display: flex;
      justify-content: center;
      align-items: center;
    }
    .green-icon {
      color: #4CAF50;
    }
    .red-icon {
      color: var(--primary-color);
    }
    .node-content {
      flex: 1;
    }
    .time-address {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .node-time {
      font-size: 13px;
      font-weight: 700;
      color: var(--text-primary);
      width: 40px;
      flex-shrink: 0;
    }
    .node-time-placeholder {
      width: 40px;
      flex-shrink: 0;
    }
    .node-address {
      font-size: 13px;
      font-weight: 500;
      color: var(--text-primary);
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    /* Card Bottom */
    .card-bottom {
      padding: 10px 16px;
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .status-badge {
      font-size: 10px;
      font-weight: 700;
      padding: 3px 8px;
      border-radius: 20px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .status-badge.completed {
      background-color: rgba(76, 175, 80, 0.08);
      color: #388E3C;
    }
    .status-badge.upcoming {
      background-color: rgba(33, 150, 243, 0.08);
      color: #1976D2;
    }
    .status-badge.cancelled {
      background-color: rgba(244, 67, 54, 0.08);
      color: #D32F2F;
    }
    .payment-badge {
      font-size: 10px;
      font-weight: 700;
      padding: 3px 8px;
      border-radius: 6px;
      border: 1px solid var(--border-color);
      color: var(--text-secondary);
      background-color: #F8F9FA;
    }
    .spacer {
      flex: 1;
    }
    .expand-chevron {
      color: var(--text-secondary);
      transition: transform 0.2s ease-in-out;
    }
    .expand-chevron.rotated {
      transform: rotate(180deg);
    }

    /* Expanded Content */
    .expanded-details {
      background-color: rgba(0, 0, 0, 0.01);
      display: flex;
      flex-direction: column;
    }
    .details-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 12px;
      padding: 14px 16px;
    }
    .detail-cell {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .detail-lbl {
      font-size: 9px;
      font-weight: 700;
      color: var(--text-secondary);
      letter-spacing: 0.5px;
      text-transform: uppercase;
    }
    .detail-val {
      font-size: 12px;
      font-weight: 600;
      color: var(--text-primary);
    }
    .detail-notes {
      padding: 0 16px 14px 16px;
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .notes-txt {
      margin: 0;
      font-size: 12px;
      color: var(--text-secondary);
      font-style: italic;
    }

    .empty-state {
      text-align: center;
      padding: 40px 16px;
      color: var(--text-secondary);
    }
    .empty-icon {
      font-size: 48px;
      width: 48px;
      height: 48px;
      margin-bottom: 8px;
    }
  `]
})
export class BookingsComponent implements OnInit {
  tabs = ['All', 'Upcoming', 'Completed', 'Cancelled'];
  activeTab = 'All';

  bookings: Booking[] = [
    {
      id: 'BKG-78129',
      pickup: 'Heathrow Airport Terminal 5',
      dropoff: 'Red Taxi Office, London Central',
      time: '15:30',
      date: 'Today, 07 Aug',
      fare: 45.00,
      paymentType: 'Cash',
      status: 'Upcoming',
      passenger: 'James Smith',
      notes: 'Flight BA441 arrived early. Meet at Costa Coffee.',
      vehicleType: 'Standard Saloon'
    },
    {
      id: 'BKG-78112',
      pickup: 'Wembley Stadium Gate A',
      dropoff: 'Hilton London Metropole',
      time: '12:15',
      date: 'Today, 07 Aug',
      fare: 28.50,
      paymentType: 'Card',
      status: 'Completed',
      passenger: 'Sarah Jenkins',
      vehicleType: 'Executive MPV'
    },
    {
      id: 'BKG-78099',
      pickup: 'Kings Cross Station',
      dropoff: 'Sherlock Holmes Museum, Baker St',
      time: '09:45',
      date: 'Yesterday, 06 Aug',
      fare: 15.20,
      paymentType: 'Account',
      status: 'Completed',
      passenger: 'Acme Corp (John Doe)',
      notes: 'Corporate booking. Account code: ACME-88',
      vehicleType: 'Standard Saloon'
    },
    {
      id: 'BKG-78051',
      pickup: 'Gatwick Airport South Terminal',
      dropoff: 'Apex Hotel Temple Court',
      time: '18:00',
      date: '04 Aug 2026',
      fare: 68.00,
      paymentType: 'Card',
      status: 'Cancelled',
      passenger: 'David Miller',
      notes: 'Passenger cancelled due to flight cancellation.',
      vehicleType: 'Executive MPV'
    }
  ];

  constructor(private driverService: DriverService, private cdr: ChangeDetectorRef) {}

  ngOnInit(): void {
    forkJoin({
      todays: this.driverService.getTodaysJobs().pipe(catchError(() => of(null))),
      future: this.driverService.getFutureJobs().pipe(catchError(() => of(null))),
      completed: this.driverService.getCompletedJobs().pipe(catchError(() => of(null)))
    }).subscribe(results => {
      // If ALL APIs failed (returned null), keep using the static fallback bookings
      if (results.todays === null && results.future === null && results.completed === null) {
        return;
      }

      const allJobs: Booking[] = [];
      
      const processJob = (jobResponse: any, defaultStatus: 'Upcoming' | 'Completed' | 'Cancelled'): Booking => {
        const job = jobResponse.value || jobResponse;
        return {
          id: job.bookingNo || job.id || `BKG-${Math.floor(Math.random() * 100000)}`,
          pickup: job.pickupAddress || job.pickup || 'Unknown Pickup',
          dropoff: job.dropoffAddress || job.dropoff || 'Unknown Dropoff',
          time: job.bookingTime || job.time || '00:00',
          date: job.bookingDate || job.date || 'Today',
          fare: job.fare || job.amount || job.price || 0.00,
          paymentType: job.paymentType || job.paymentMethod || 'Cash',
          status: job.status || defaultStatus,
          passenger: job.passengerName || job.passenger || 'Passenger',
          notes: job.notes || job.comment || '',
          vehicleType: job.vehicleType || 'Standard Saloon',
          expanded: false
        };
      };

      const todaysList = results.todays?.value || results.todays || [];
      const futureList = results.future?.value || results.future || [];
      const completedList = results.completed?.value || results.completed || [];

      if (Array.isArray(todaysList) && todaysList.length > 0) {
        todaysList.forEach((job: any) => allJobs.push(processJob(job, 'Upcoming')));
      }
      if (Array.isArray(futureList) && futureList.length > 0) {
        futureList.forEach((job: any) => allJobs.push(processJob(job, 'Upcoming')));
      }
      if (Array.isArray(completedList) && completedList.length > 0) {
        completedList.forEach((job: any) => allJobs.push(processJob(job, 'Completed')));
      }

      this.bookings = allJobs;
      this.cdr.detectChanges();
    });
  }

  get filteredBookings(): Booking[] {
    if (this.activeTab === 'All') {
      return this.bookings;
    }
    return this.bookings.filter(b => b.status === this.activeTab);
  }

  onChipSelectionChange(tab: string, selected: boolean): void {
    if (selected) {
      this.activeTab = tab;
    }
  }

  toggleExpand(booking: Booking): void {
    booking.expanded = !booking.expanded;
  }
}
