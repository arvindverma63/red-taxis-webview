import { Component, OnInit, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute } from '@angular/router';
import { DriverService } from '../services/driver.service';
import { Subscription } from 'rxjs';

interface CompletedJob {
  id: string;
  tripDescription: string;
  timeString: string;
  amount: number;
}

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="dashboard-container">
      <!-- Developer Simulation Deck Card (Only visible when Online) -->
      <div class="dash-card sim-card" *ngIf="isOnline">
        <div class="card-title-row">
          <span class="card-icon">🔬</span>
          <span class="card-title">Developer Simulation Deck</span>
        </div>
        <p class="sim-desc">Trigger a mock incoming booking request to test acceptance and routing components:</p>
        
        <div class="sim-button-row">
          <button class="sim-btn outlined" (click)="triggerSimulation('cash')">
            💵 Cash Booking
          </button>
          <button class="sim-btn outlined" (click)="triggerSimulation('card')">
            💳 Card Booking
          </button>
        </div>
      </div>

      <!-- Today's Summary Card -->
      <div class="dash-card summary-card">
        <h3 class="section-title">Today's Summary</h3>
        <div class="summary-columns" *ngIf="!isLoading; else shimmerSummary">
          <div class="summary-col">
            <div class="icon-circle green">
              <span class="circle-icon">💰</span>
            </div>
            <span class="summary-lbl">TODAY'S EARNINGS</span>
            <span class="summary-val green">£{{ todayEarnings.toFixed(2) }}</span>
          </div>
          
          <div class="col-divider"></div>

          <div class="summary-col">
            <div class="icon-circle red">
              <span class="circle-icon">🚕</span>
            </div>
            <span class="summary-lbl">COMPLETED TRIPS</span>
            <span class="summary-val">{{ completedTripsCount }}</span>
          </div>
        </div>
        <ng-template #shimmerSummary>
          <div class="shimmer-placeholder summary-shimmer"></div>
        </ng-template>
      </div>

      <!-- Recent Completed Trips List Card -->
      <div class="dash-card trips-list-card">
        <h3 class="section-title">Recent Completed Trips</h3>
        
        <div *ngIf="isLoading" class="shimmer-placeholder list-shimmer"></div>

        <div *ngIf="!isLoading && completedJobs.length === 0" class="empty-trips-view">
          <p class="empty-txt">No trips completed yet today.</p>
        </div>

        <div class="trips-list" *ngIf="!isLoading && completedJobs.length > 0">
          <div class="trip-item" *ngFor="let job of completedJobs">
            <div class="trip-status-icon">
              <span class="check-icon">✓</span>
            </div>
            
            <div class="trip-details">
              <span class="trip-desc">{{ job.tripDescription }}</span>
              <span class="trip-time">{{ job.timeString }}</span>
            </div>

            <span class="trip-fare">£{{ job.amount.toFixed(2) }}</span>
          </div>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .dashboard-container {
      background-color: #F8F9FA;
      min-height: 100vh;
      padding: 8px 16px 48px 16px;
      font-family: 'Roboto', sans-serif;
      display: flex;
      flex-direction: column;
      gap: 16px;
      box-sizing: border-box;
    }

    /* Common Card Styling */
    .dash-card {
      background-color: #FFFFFF;
      border-radius: 16px;
      padding: 20px;
      box-shadow: 0 4px 18px rgba(0,0,0,0.015);
      border: 1px solid rgba(0,0,0,0.025);
      box-sizing: border-box;
      display: flex;
      flex-direction: column;
      transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
    }

    .dash-card:hover {
      transform: translateY(-2px);
      box-shadow: 0 8px 24px rgba(0,0,0,0.035);
      border-color: rgba(211, 47, 47, 0.08);
    }

    .section-title {
      margin: 0 0 16px 0;
      font-size: 13px;
      font-weight: 900;
      color: #37474F;
      letter-spacing: 0.3px;
      text-transform: uppercase;
    }

    /* Simulation Deck card styling */
    .card-title-row {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 10px;
    }

    .card-icon {
      font-size: 16px;
    }

    .card-title {
      font-size: 14px;
      font-weight: 900;
      color: #37474F;
    }

    .sim-desc {
      margin: 0 0 14px 0;
      font-size: 12px;
      color: #78909C;
      line-height: 1.4;
    }

    .sim-button-row {
      display: flex;
      gap: 12px;
      width: 100%;
    }

    .sim-btn {
      flex: 1;
      padding: 11px;
      font-size: 12px;
      font-weight: 800;
      border-radius: 10px;
      cursor: pointer;
      display: flex;
      justify-content: center;
      align-items: center;
      gap: 6px;
      transition: all 0.2s ease;
    }

    .sim-btn.outlined {
      background-color: transparent;
      border: 1.5px solid #CFD8DC;
      color: #37474F;
    }

    .sim-btn.outlined:active {
      background-color: #F5F7FA;
      border-color: #90A4AE;
    }

    /* Summary Card Column Grid layout */
    .summary-columns {
      display: flex;
      align-items: center;
      width: 100%;
      padding: 8px 0;
    }

    .summary-col {
      flex: 1;
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
      gap: 4px;
    }

    .col-divider {
      width: 1px;
      height: 52px;
      background-color: #ECEFF1;
    }

    .icon-circle {
      width: 38px;
      height: 38px;
      border-radius: 50%;
      display: flex;
      justify-content: center;
      align-items: center;
      margin-bottom: 4px;
    }

    .icon-circle.green {
      background-color: rgba(76, 175, 80, 0.08);
    }

    .icon-circle.red {
      background-color: rgba(211, 47, 47, 0.08);
    }

    .circle-icon {
      font-size: 18px;
    }

    .summary-lbl {
      font-size: 9px;
      font-weight: 800;
      color: #90A4AE;
      letter-spacing: 0.5px;
    }

    .summary-val {
      font-size: 18px;
      font-weight: 900;
      color: #37474F;
    }

    .summary-val.green {
      color: #2E7D32;
    }

    /* Trips list card */
    .empty-trips-view {
      padding: 24px 0;
      text-align: center;
    }

    .empty-txt {
      margin: 0;
      font-size: 13px;
      color: #90A4AE;
    }

    .trips-list {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }

    .trip-item {
      display: flex;
      align-items: center;
      padding: 12px;
      background-color: #FAFBFD;
      border: 1px solid #ECEFF1;
      border-radius: 12px;
      gap: 12px;
    }

    .trip-status-icon {
      width: 28px;
      height: 28px;
      background-color: rgba(76, 175, 80, 0.08);
      border-radius: 50%;
      display: flex;
      justify-content: center;
      align-items: center;
    }

    .check-icon {
      font-size: 12px;
      color: #2E7D32;
      font-weight: bold;
    }

    .trip-details {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 2px;
      min-width: 0; /* Prevents text overflow */
    }

    .trip-desc {
      font-size: 12.5px;
      font-weight: 700;
      color: #37474F;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .trip-time {
      font-size: 11px;
      color: #90A4AE;
    }

    .trip-fare {
      font-size: 14.5px;
      font-weight: 900;
      color: #37474F;
    }

    /* Shimmer Loader Visual Placeholders */
    .shimmer-placeholder {
      background: linear-gradient(90deg, #F0F2F5 25%, #E1E4E8 50%, #F0F2F5 75%);
      background-size: 200% 100%;
      animation: shimmerLoading 1.5s infinite;
      border-radius: 12px;
    }

    @keyframes shimmerLoading {
      0% { background-position: 200% 0; }
      100% { background-position: -200% 0; }
    }

    .summary-shimmer {
      height: 98px;
      width: 100%;
    }

    .list-shimmer {
      height: 120px;
      width: 100%;
    }
  `]
})
export class DashboardComponent implements OnInit, OnDestroy {
  isOnline = false;
  isLoading = true;
  
  todayEarnings = 0;
  completedTripsCount = 0;
  completedJobs: CompletedJob[] = [];
  
  private routeSub: Subscription | null = null;

  constructor(
    private route: ActivatedRoute,
    private driverService: DriverService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    // Monitor query parameters for token changes and active shift state
    this.routeSub = this.route.queryParams.subscribe(params => {
      let shiftStatusParam = params['shiftStatus'];
      if (!shiftStatusParam) {
        const urlParams = new URLSearchParams(window.location.search);
        shiftStatusParam = urlParams.get('shiftStatus');
        
        if (!shiftStatusParam) {
          const hash = window.location.hash;
          if (hash.includes('?')) {
            const queryParams = new URLSearchParams(hash.split('?')[1]);
            shiftStatusParam = queryParams.get('shiftStatus');
          }
        }
      }
      this.isOnline = shiftStatusParam === 'online';
      this.cdr.detectChanges();
    });

    this.loadCompletedJobsStats();
  }

  loadCompletedJobsStats(): void {
    this.isLoading = true;
    this.driverService.getCompletedJobs().subscribe({
      next: (jobs) => {
        const list = jobs?.value || jobs || [];
        if (Array.isArray(list)) {
          let earningsSum = 0;
          this.completedJobs = list.map((item: any) => {
            const fareAmount = parseFloat(item.fare || item.amount || item.price || '0.00');
            earningsSum += fareAmount;
            
            // Format time string
            let timeStr = 'Completed today';
            if (item.completedAt || item.date) {
              const d = new Date(item.completedAt || item.date);
              timeStr = `${d.getHours()}:${d.getMinutes().toString().padStart(2, '0')}`;
            }

            return {
              id: (item.bookingNo || item.id || '').toString(),
              tripDescription: `Pickup: ${item.pickupAddress || item.pickup || 'Unknown'}, Dropoff: ${item.destinationAddress || item.dropoff || 'Unknown'}`,
              timeString: timeStr,
              amount: fareAmount
            };
          });
          
          this.todayEarnings = earningsSum;
          this.completedTripsCount = this.completedJobs.length;
        }
        this.isLoading = false;
        this.cdr.detectChanges();
      },
      error: () => {
        // Fallback mockup stats if offline/api error
        this.todayEarnings = 0;
        this.completedTripsCount = 0;
        this.completedJobs = [];
        this.isLoading = false;
        this.cdr.detectChanges();
      }
    });
  }

  toggleShift(): void {
    if (this.isOnline) {
      this.notifyNativeApp('go_offline');
    } else {
      this.notifyNativeApp('go_online');
    }
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
