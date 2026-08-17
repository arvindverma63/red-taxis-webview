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
      <!-- Header Row with Title and Refresh -->
      <div class="header-row">
        <div>
          <h2 class="page-title">My Bookings</h2>
          <p class="page-subtitle">Track today's, upcoming and completed trips</p>
        </div>
        <button class="refresh-icon-btn" (click)="loadBookings()" [disabled]="isLoading" title="Refresh Bookings">
          <span class="material-symbols-outlined" [class.spinning]="isLoading">refresh</span>
        </button>
      </div>

      <!-- Tabs as Pills -->
      <mat-chip-listbox class="full-width-pills" [hideSingleSelectionIndicator]="true" aria-label="Select booking filter">
        <mat-chip-option 
          *ngFor="let tab of tabs" 
          [selected]="activeTab === tab"
          (selectable)="true"
          (selectionChange)="onChipSelectionChange(tab, $event.selected)"
          class="pill-chip"
        >
          {{ tab }} ({{ getTabCount(tab) }})
        </mat-chip-option>
      </mat-chip-listbox>

      <!-- Loading State -->
      <div *ngIf="isLoading" class="loading-state">
        <div class="spinner"></div>
        <p class="loading-text">Fetching latest bookings...</p>
      </div>

      <!-- Bookings List -->
      <div class="bookings-list" *ngIf="!isLoading">
        <div *ngIf="filteredBookings.length === 0" class="empty-state">
          <span class="material-symbols-outlined empty-icon">assignment_late</span>
          <p class="empty-title">No {{ activeTab.toLowerCase() }} bookings found</p>
          <p class="empty-subtitle">New allocations and scheduled trips will appear here.</p>
          <button class="retry-btn" (click)="loadBookings()">Check Again</button>
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

          <!-- Card Bottom Details & Toggles -->
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
                <span class="detail-lbl">Scheduled Date</span>
                <span class="detail-val">{{ booking.date }} {{ booking.time }}</span>
              </div>
            </div>
            <div class="detail-notes" *ngIf="booking.notes && booking.notes.trim().length > 0">
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
      padding: 16px 16px 40px 16px;
      background-color: #F8F9FA;
      min-height: 100vh;
      font-family: 'Roboto', sans-serif;
      box-sizing: border-box;
    }

    .header-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 16px;
    }
    .page-title {
      margin: 0;
      font-size: 22px;
      font-weight: 800;
      color: #1A1C1E;
      letter-spacing: -0.5px;
    }
    .page-subtitle {
      margin: 2px 0 0 0;
      font-size: 13px;
      color: #74777F;
    }
    .refresh-icon-btn {
      background-color: #FFFFFF;
      border: 1px solid #E0E2EC;
      border-radius: 50%;
      width: 40px;
      height: 40px;
      display: flex;
      justify-content: center;
      align-items: center;
      cursor: pointer;
      color: #1A1C1E;
      box-shadow: 0 2px 6px rgba(0,0,0,0.04);
      transition: all 0.2s ease;
    }
    .refresh-icon-btn:active {
      transform: scale(0.95);
      background-color: #F2F3FA;
    }
    .spinning {
      animation: spin 1s infinite linear;
    }
    @keyframes spin {
      from { transform: rotate(0deg); }
      to { transform: rotate(360deg); }
    }
    
    /* Pills Layout Override */
    .full-width-pills {
      margin-bottom: 16px;
      display: flex;
      width: 100%;
    }
    ::ng-deep .full-width-pills .mat-mdc-chip-listbox-wrapper {
      display: flex;
      width: 100%;
      gap: 6px;
      overflow-x: auto;
      padding-bottom: 4px;
    }
    ::ng-deep .pill-chip {
      flex: 1;
      border-radius: 20px !important;
      min-height: 36px !important;
      border: 1px solid #E0E2EC !important;
      background-color: #FFFFFF !important;
      box-shadow: none !important;
      white-space: nowrap;
    }
    ::ng-deep .pill-chip .mat-mdc-chip-checkmark {
      display: none !important;
    }
    ::ng-deep .pill-chip .mdc-evolution-chip__cell--primary,
    ::ng-deep .pill-chip .mdc-evolution-chip__action {
      justify-content: center;
      width: 100%;
      padding: 0 8px !important;
    }
    ::ng-deep .pill-chip.mat-mdc-chip-selected {
      background-color: #D32F2F !important;
      border-color: #D32F2F !important;
    }
    ::ng-deep .pill-chip.mat-mdc-chip-selected .mdc-evolution-chip__text-label {
      color: #FFFFFF !important;
      font-weight: 700 !important;
    }
    ::ng-deep .pill-chip .mdc-evolution-chip__text-label {
      color: #44474E;
      font-size: 12px;
      font-weight: 600;
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
      width: 36px;
      height: 36px;
      border: 3.5px solid #E0E2EC;
      border-top-color: #D32F2F;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
    }
    .loading-text {
      margin-top: 16px;
      font-size: 14px;
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
      font-size: 20px;
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
    .expand-chevron {
      color: #74777F;
      transition: transform 0.2s ease-in-out;
    }
    .expand-chevron.rotated {
      transform: rotate(180deg);
    }

    /* Expanded Content */
    .expanded-details {
      background-color: #FFFFFF;
      display: flex;
      flex-direction: column;
    }
    .details-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 8px;
      padding: 12px 16px;
    }
    .detail-cell {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .detail-lbl {
      font-size: 8px;
      font-weight: 800;
      color: #90A4AE;
      letter-spacing: 0.5px;
      text-transform: uppercase;
    }
    .detail-val {
      font-size: 12px;
      font-weight: 700;
      color: #1A1C1E;
    }
    .detail-notes {
      padding: 0 16px 14px 16px;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .notes-txt {
      margin: 0;
      font-size: 12px;
      color: #546E7A;
      font-style: italic;
      line-height: 1.4;
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
      padding: 8px 18px;
      font-size: 12px;
      font-weight: 700;
      border-radius: 20px;
      cursor: pointer;
    }
  `]
})
export class BookingsComponent implements OnInit {
  tabs = ['All', 'Upcoming', 'Completed', 'Cancelled'];
  activeTab = 'All';
  isLoading = false;

  bookings: Booking[] = [];

  constructor(private driverService: DriverService, private cdr: ChangeDetectorRef) {}

  ngOnInit(): void {
    this.loadBookings();
  }

  loadBookings(): void {
    this.isLoading = true;
    this.cdr.detectChanges();

    forkJoin({
      todays: this.driverService.getTodaysJobs().pipe(catchError(() => of([]))),
      future: this.driverService.getFutureJobs().pipe(catchError(() => of([]))),
      completed: this.driverService.getCompletedJobs().pipe(catchError(() => of([])))
    }).subscribe({
      next: (results) => {
        const allJobs: Booking[] = [];
        
        const processJob = (job: any, defaultStatus: 'Upcoming' | 'Completed' | 'Cancelled'): Booking => {
          // Resolve fare
          const fare = parseFloat((job.price || job.fare || job.amount || job.driverPrice || '0.00').toString());
          
          // Resolve addresses
          const pickup = job.pickupAddress || job.pickup || job.from || 'Unknown Pickup';
          const dropoff = job.destinationAddress || job.dropoffAddress || job.dropoff || job.to || 'Unknown Dropoff';

          // Resolve dates & times
          const dtStr = job.pickupDateTime || job.bookingDateTime || job.dateCreated || '';
          let time = job.bookingTime || job.time || '';
          let date = job.bookingDate || job.date || '';

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
          if (job.cancelled === true) {
            status = 'Cancelled';
          } else if (job.status === 4 || job.status === 5 || job.status === 6) {
            status = 'Completed';
          }

          return {
            id: (job.bookingId || job.bookingNo || job.id || Math.floor(Math.random() * 100000)).toString(),
            pickup: pickup,
            dropoff: dropoff,
            time: time,
            date: date,
            fare: isNaN(fare) ? 0.00 : fare,
            paymentType: paymentType,
            status: status,
            passenger: job.passengerName || job.passenger || job.customerName || 'Passenger',
            notes: job.details || job.notes || job.comment || '',
            vehicleType: job.vehicleType || job.vehicle || 'Standard Saloon',
            expanded: false
          };
        };

        const extractList = (res: any): any[] => {
          if (!res) return [];
          if (Array.isArray(res)) return res;
          if (Array.isArray(res.value)) return res.value;
          if (Array.isArray(res.data)) return res.data;
          return [];
        };

        const todaysList = extractList(results.todays);
        const futureList = extractList(results.future);
        const completedList = extractList(results.completed);

        todaysList.forEach((job: any) => allJobs.push(processJob(job, 'Upcoming')));
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

  onChipSelectionChange(tab: string, selected: boolean): void {
    if (selected) {
      this.activeTab = tab;
    }
  }

  toggleExpand(booking: Booking): void {
    booking.expanded = !booking.expanded;
  }
}
