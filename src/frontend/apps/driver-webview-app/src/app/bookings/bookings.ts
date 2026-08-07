import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';

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
  imports: [CommonModule],
  template: `
    <div class="webview-container">
      <header class="header">
        <h1>My Bookings</h1>
        <p>Manage and review your ride schedule.</p>
      </header>

      <!-- Tabs -->
      <div class="tabs-container">
        <button 
          *ngFor="let tab of tabs" 
          [class.active]="activeTab === tab"
          (click)="setActiveTab(tab)"
          class="tab-btn"
        >
          {{ tab }}
        </button>
      </div>

      <!-- Bookings List -->
      <main class="bookings-list">
        <div *ngIf="filteredBookings.length === 0" class="empty-state">
          <p>No {{ activeTab.toLowerCase() }} bookings found.</p>
        </div>

        <div 
          *ngFor="let booking of filteredBookings" 
          class="booking-card" 
          [class.expanded]="booking.expanded"
          (click)="toggleExpand(booking)"
        >
          <div class="booking-summary">
            <div class="booking-time-status">
              <span class="booking-time">{{ booking.time }}</span>
              <span class="status-badge" [ngClass]="booking.status.toLowerCase()">
                {{ booking.status }}
              </span>
            </div>
            
            <div class="route-details">
              <div class="address pickup">
                <span class="dot green"></span>
                <span class="address-text">{{ booking.pickup }}</span>
              </div>
              <div class="address dropoff">
                <span class="dot red"></span>
                <span class="address-text">{{ booking.dropoff }}</span>
              </div>
            </div>

            <div class="fare-payment">
              <span class="fare">£{{ booking.fare.toFixed(2) }}</span>
              <span class="payment-method badge-outline">{{ booking.paymentType }}</span>
            </div>
          </div>

          <!-- Expanded details with nice CSS animations -->
          <div class="booking-details" *ngIf="booking.expanded">
            <div class="details-grid">
              <div class="detail-item">
                <span class="detail-label">Booking ID</span>
                <span class="detail-value">{{ booking.id }}</span>
              </div>
              <div class="detail-item">
                <span class="detail-label">Passenger</span>
                <span class="detail-value">{{ booking.passenger }}</span>
              </div>
              <div class="detail-item">
                <span class="detail-label">Vehicle Type</span>
                <span class="detail-value">{{ booking.vehicleType }}</span>
              </div>
              <div class="detail-item">
                <span class="detail-label">Date</span>
                <span class="detail-value">{{ booking.date }}</span>
              </div>
            </div>
            <div class="detail-notes" *ngIf="booking.notes">
              <span class="detail-label">Driver Notes</span>
              <p class="notes-text">"{{ booking.notes }}"</p>
            </div>
          </div>
        </div>
      </main>
    </div>
  `,
  styles: [`
    .webview-container {
      padding: 16px;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    }
    .header {
      margin-bottom: 20px;
    }
    .header h1 {
      font-size: 24px;
      margin: 0 0 6px 0;
      color: var(--text-primary);
    }
    .header p {
      font-size: 14px;
      margin: 0;
      color: var(--text-secondary);
    }
    
    /* Tabs styling */
    .tabs-container {
      display: flex;
      background-color: var(--border-color);
      padding: 4px;
      border-radius: 12px;
    }
    .tab-btn {
      flex: 1;
      border: none;
      background: none;
      padding: 8px 12px;
      border-radius: 8px;
      font-size: 13px;
      font-weight: 600;
      color: var(--text-secondary);
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .tab-btn.active {
      background-color: var(--surface-color);
      color: var(--text-primary);
      box-shadow: 0 2px 4px rgba(0,0,0,0.08);
    }

    /* Bookings List */
    .bookings-list {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .booking-card {
      background-color: var(--surface-color);
      border: 1px solid var(--border-color);
      border-radius: 16px;
      overflow: hidden;
      cursor: pointer;
      transition: transform 0.2s ease, box-shadow 0.2s ease, border-color 0.2s ease;
    }
    .booking-card:hover {
      transform: translateY(-2px);
      box-shadow: 0 6px 12px rgba(0,0,0,0.05);
      border-color: var(--text-secondary);
    }
    .booking-summary {
      padding: 16px;
    }
    .booking-time-status {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 12px;
    }
    .booking-time {
      font-weight: bold;
      font-size: 16px;
      color: var(--text-primary);
    }
    
    /* Status badges */
    .status-badge {
      font-size: 11px;
      font-weight: bold;
      padding: 4px 8px;
      border-radius: 20px;
      text-transform: uppercase;
    }
    .status-badge.completed {
      background-color: rgba(76, 175, 80, 0.1);
      color: #4CAF50;
    }
    .status-badge.upcoming {
      background-color: rgba(33, 150, 243, 0.1);
      color: #2196F3;
    }
    .status-badge.cancelled {
      background-color: rgba(244, 67, 54, 0.1);
      color: #F44336;
    }

    /* Route details */
    .route-details {
      display: flex;
      flex-direction: column;
      gap: 8px;
      margin-bottom: 12px;
    }
    .address {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      flex-shrink: 0;
    }
    .dot.green { background-color: #4CAF50; }
    .dot.red { background-color: var(--primary-color); }
    
    .address-text {
      font-size: 13px;
      color: var(--text-primary);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .fare-payment {
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-top: 1px solid var(--border-color);
      padding-top: 12px;
      margin-top: 8px;
    }
    .fare {
      font-size: 18px;
      font-weight: 800;
      color: var(--text-primary);
    }
    .badge-outline {
      font-size: 11px;
      font-weight: 600;
      border: 1px solid var(--border-color);
      padding: 2px 8px;
      border-radius: 6px;
      color: var(--text-secondary);
    }

    /* Expanded Details */
    .booking-details {
      padding: 16px;
      border-top: 1px dashed var(--border-color);
      background-color: rgba(0,0,0,0.01);
      display: flex;
      flex-direction: column;
      gap: 12px;
      animation: slideDown 0.25s ease-out;
    }
    .details-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
    }
    .detail-item {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .detail-label {
      font-size: 11px;
      color: var(--text-secondary);
      font-weight: 500;
    }
    .detail-value {
      font-size: 13px;
      font-weight: 600;
      color: var(--text-primary);
    }
    .detail-notes {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .notes-text {
      font-size: 13px;
      margin: 0;
      color: var(--text-secondary);
      font-style: italic;
    }

    .empty-state {
      text-align: center;
      padding: 32px;
      color: var(--text-secondary);
      font-size: 14px;
    }

    @keyframes slideDown {
      from {
        opacity: 0;
        transform: translateY(-8px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
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

  setActiveTab(tab: string): void {
    this.activeTab = tab;
  }

  toggleExpand(booking: Booking): void {
    booking.expanded = !booking.expanded;
  }
}
