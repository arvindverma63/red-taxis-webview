import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatTabsModule } from '@angular/material/tabs';
import { MatCardModule } from '@angular/material/card';
import { MatChipsModule } from '@angular/material/chips';
import { MatDividerModule } from '@angular/material/divider';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';

interface Booking {
  id: string;
  pickup: string;
  dropoff: string;
  time: string;
  date: string;
  fare: number;
  paymentType: 'Cash' | 'Card' | 'Account';
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
    MatTabsModule,
    MatCardModule,
    MatChipsModule,
    MatDividerModule,
    MatButtonModule,
    MatIconModule
  ],
  template: `
    <div class="material-container">
      <header class="header">
        <h1 class="mat-headline-medium">My Bookings</h1>
        <p class="mat-body-medium">Manage and review your ride schedule.</p>
      </header>

      <!-- Tabs -->
      <mat-tab-group (selectedTabChange)="onTabChange($event)" mat-stretch-tabs="false" class="full-width-tabs">
        <mat-tab *ngFor="let tab of tabs" [label]="tab">
          <!-- Bookings List Inside Tab -->
          <div class="bookings-list">
            <div *ngIf="filteredBookings.length === 0" class="empty-state">
              <mat-icon class="empty-icon">assignment_late</mat-icon>
              <p class="mat-body-medium">No {{ tab.toLowerCase() }} bookings found.</p>
            </div>

            <mat-card 
              *ngFor="let booking of filteredBookings" 
              class="booking-mat-card" 
              [class.expanded]="booking.expanded"
              (click)="toggleExpand(booking)"
            >
              <mat-card-header>
                <div mat-card-avatar class="time-avatar">
                  <mat-icon>schedule</mat-icon>
                </div>
                <mat-card-title class="card-title">
                  {{ booking.time }}
                  <span class="spacer"></span>
                  <span class="fare-amount">£{{ booking.fare.toFixed(2) }}</span>
                </mat-card-title>
                <mat-card-subtitle class="card-subtitle">
                  {{ booking.date }}
                </mat-card-subtitle>
              </mat-card-header>

              <mat-card-content>
                <div class="route-info">
                  <div class="route-item">
                    <mat-icon class="route-icon green-icon">play_circle_filled</mat-icon>
                    <span class="route-text mat-body-medium">{{ booking.pickup }}</span>
                  </div>
                  <div class="route-item">
                    <mat-icon class="route-icon red-icon">location_on</mat-icon>
                    <span class="route-text mat-body-medium">{{ booking.dropoff }}</span>
                  </div>
                </div>

                <div class="badge-row">
                  <mat-chip-set>
                    <mat-chip class="status-chip" [ngClass]="booking.status.toLowerCase()">
                      {{ booking.status }}
                    </mat-chip>
                    <mat-chip class="type-chip">
                      {{ booking.paymentType }}
                    </mat-chip>
                  </mat-chip-set>
                </div>

                <!-- Expanded area -->
                <div class="expanded-details" *ngIf="booking.expanded">
                  <mat-divider></mat-divider>
                  <div class="details-grid">
                    <div class="detail-cell">
                      <span class="lbl mat-caption">Booking ID</span>
                      <span class="val mat-body-medium">{{ booking.id }}</span>
                    </div>
                    <div class="detail-cell">
                      <span class="lbl mat-caption">Passenger</span>
                      <span class="val mat-body-medium">{{ booking.passenger }}</span>
                    </div>
                    <div class="detail-cell">
                      <span class="lbl mat-caption">Vehicle</span>
                      <span class="val mat-body-medium">{{ booking.vehicleType }}</span>
                    </div>
                  </div>
                  <div class="detail-notes" *ngIf="booking.notes">
                    <span class="lbl mat-caption">Notes</span>
                    <p class="notes-txt mat-body-small">"{{ booking.notes }}"</p>
                  </div>
                </div>
              </mat-card-content>

              <mat-card-actions align="end" *ngIf="!booking.expanded">
                <button mat-button color="primary">View Details</button>
              </mat-card-actions>
            </mat-card>
          </div>
        </mat-tab>
      </mat-tab-group>
    </div>
  `,
  styles: [`
    .material-container {
      padding: 16px;
      background-color: var(--background-color);
      min-height: 100vh;
    }
    .header {
      margin-bottom: 16px;
    }
    .header h1 {
      margin: 0 0 4px 0;
      font-weight: 700;
      color: var(--text-primary);
    }
    .header p {
      margin: 0;
      color: var(--text-secondary);
    }
    
    .full-width-tabs {
      margin-top: 8px;
    }
    
    .bookings-list {
      padding-top: 16px;
      display: flex;
      flex-direction: column;
      gap: 16px;
    }
    
    .booking-mat-card {
      border: 1px solid var(--border-color);
      box-shadow: none !important;
      border-radius: 12px !important;
      cursor: pointer;
      transition: transform 0.2s ease, box-shadow 0.2s ease;
    }
    .booking-mat-card:hover {
      transform: translateY(-2px);
      box-shadow: 0 4px 8px rgba(0,0,0,0.05) !important;
    }
    
    .card-title {
      display: flex;
      align-items: center;
      width: 100%;
      font-size: 16px;
      font-weight: 700;
    }
    .spacer {
      flex: 1 1 auto;
    }
    .fare-amount {
      color: var(--primary-color);
      font-weight: 800;
      font-size: 18px;
    }
    .card-subtitle {
      color: var(--text-secondary);
      font-size: 12px;
    }

    .time-avatar {
      display: flex;
      align-items: center;
      justify-content: center;
      background-color: rgba(0,0,0,0.03);
      color: var(--text-secondary);
      border-radius: 50%;
    }

    .route-info {
      margin-top: 12px;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .route-item {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .route-icon {
      font-size: 18px;
      width: 18px;
      height: 18px;
    }
    .green-icon { color: #4CAF50; }
    .red-icon { color: var(--primary-color); }
    .route-text {
      color: var(--text-primary);
      font-size: 13px;
    }

    .badge-row {
      margin-top: 12px;
    }
    .status-chip.completed {
      background-color: rgba(76, 175, 80, 0.12) !important;
      color: #388E3C !important;
    }
    .status-chip.upcoming {
      background-color: rgba(33, 150, 243, 0.12) !important;
      color: #1976D2 !important;
    }
    .status-chip.cancelled {
      background-color: rgba(244, 67, 54, 0.12) !important;
      color: #D32F2F !important;
    }
    .type-chip {
      background-color: rgba(0,0,0,0.05) !important;
      color: var(--text-secondary) !important;
    }

    .expanded-details {
      margin-top: 16px;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .details-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 8px;
      margin-top: 8px;
    }
    .detail-cell {
      display: flex;
      flex-direction: column;
    }
    .lbl {
      color: var(--text-secondary);
      font-size: 10px;
    }
    .val {
      color: var(--text-primary);
      font-weight: 600;
      font-size: 12px;
    }
    .detail-notes {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .notes-txt {
      margin: 0;
      color: var(--text-secondary);
      font-style: italic;
      font-size: 12px;
    }

    .empty-state {
      text-align: center;
      padding: 32px;
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
export class BookingsComponent {
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

  get filteredBookings(): Booking[] {
    if (this.activeTab === 'All') {
      return this.bookings;
    }
    return this.bookings.filter(b => b.status === this.activeTab);
  }

  onTabChange(event: any): void {
    this.activeTab = this.tabs[event.index];
  }

  toggleExpand(booking: Booking): void {
    booking.expanded = !booking.expanded;
  }
}
