import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { DriverService } from '../services/driver.service';

export interface EarningItem {
  date: string;
  cashTotal: number;
  accTotal: number;
  rankTotal: number;
  commsTotal: number;
  grossTotal: number;
  netTotal: number;
  cashJobsCount: number;
  accJobsCount: number;
  rankJobsCount: number;
  rankMilesCount?: number;
}

export interface StatementItem {
  statementId: number;
  dateCreated: string;
  dateUpdated?: string;
  startDate: string;
  endDate: string;
  earningsCash: number;
  earningsAccount: number;
  earningsCard: number;
  earningsRank: number;
  commissionDue: number;
  subTotal: number;
  totalEarned: number;
  paymentDue: number;
  totalJobCount: number;
  accountJobsTotalCount: number;
  cashJobsTotalCount: number;
  rankJobsTotalCount: number;
  paidInFull: boolean;
  userId?: number;
  identifier?: string;
  colorCode?: string;
  jobs?: any[];
}

export interface DashTotals {
  earningsTotalToday: number;
  earningsTotalWeek: number;
  earningsTotalMonth: number;
  jobCountToday?: number;
  jobCountWeek?: number;
  jobCountMonth?: number;
}

@Component({
  selector: 'app-reports',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    MatCardModule,
    MatButtonModule,
    MatIconModule,
    MatSnackBarModule
  ],
  template: `
    <div 
      class="reports-container"
      (touchstart)="onTouchStart($event)"
      (touchmove)="onTouchMove($event)"
      (touchend)="onTouchEnd()"
    >
      <!-- Pull to Refresh Indicator -->
      <div 
        class="floating-refresh-spinner"
        [class.visible]="pullDistance > 0 || isRefreshing"
        [style.transform]="'translate(-50%, ' + (isRefreshing ? '20px' : (pullDistance - 45) + 'px)')"
        [style.opacity]="isRefreshing ? 1 : (pullDistance / 50)"
      >
        <span 
          class="material-symbols-outlined native-spin-icon"
          [class.spinning]="isRefreshing"
          [style.transform]="'rotate(' + (pullDistance * 4) + 'deg)'"
        >
          refresh
        </span>
      </div>

      <!-- Top Segmented Navigation Tabs -->
      <div class="view-segmented-bar">
        <button 
          class="segment-btn" 
          [class.active]="activeTab === 'overview'"
          (click)="setTab('overview')"
        >
          <span class="material-symbols-outlined seg-icon">analytics</span>
          <span>Overview</span>
        </button>
        <button 
          class="segment-btn" 
          [class.active]="activeTab === 'earnings'"
          (click)="setTab('earnings')"
        >
          <span class="material-symbols-outlined seg-icon">payments</span>
          <span>Earnings</span>
        </button>
        <button 
          class="segment-btn" 
          [class.active]="activeTab === 'statements'"
          (click)="setTab('statements')"
        >
          <span class="material-symbols-outlined seg-icon">receipt_long</span>
          <span>Statements</span>
        </button>
      </div>

      <!-- ================= TAB 1: OVERVIEW ================= -->
      <div *ngIf="activeTab === 'overview'" class="tab-content animate-fade-in">
        <!-- Earnings Bar Chart Card -->
        <div class="overview-chart-card">
          <div class="chart-header">
            <h2 class="chart-title">Earnings Performance</h2>
            <span class="chart-subtitle">Today vs Weekly vs Monthly</span>
          </div>

          <div *ngIf="isLoadingDash" class="chart-loader">
            <div class="spinner-ring"></div>
            <span>Loading earnings telemetry...</span>
          </div>

          <div *ngIf="!isLoadingDash" class="chart-body">
            <div class="bar-columns-wrapper">
              <!-- Today Bar -->
              <div class="bar-col">
                <span class="bar-value">£{{ dashTotals.earningsTotalToday.toFixed(0) }}</span>
                <div class="bar-track">
                  <div 
                    class="bar-fill bar-today" 
                    [style.height.%]="getBarHeight(dashTotals.earningsTotalToday)"
                  ></div>
                </div>
                <span class="bar-label">Today</span>
              </div>

              <!-- This Week Bar -->
              <div class="bar-col">
                <span class="bar-value">£{{ dashTotals.earningsTotalWeek.toFixed(0) }}</span>
                <div class="bar-track">
                  <div 
                    class="bar-fill bar-week" 
                    [style.height.%]="getBarHeight(dashTotals.earningsTotalWeek)"
                  ></div>
                </div>
                <span class="bar-label">This Week</span>
              </div>

              <!-- This Month Bar -->
              <div class="bar-col">
                <span class="bar-value">£{{ dashTotals.earningsTotalMonth.toFixed(0) }}</span>
                <div class="bar-track">
                  <div 
                    class="bar-fill bar-month" 
                    [style.height.%]="getBarHeight(dashTotals.earningsTotalMonth)"
                  ></div>
                </div>
                <span class="bar-label">This Month</span>
              </div>
            </div>
          </div>
        </div>

        <!-- Quick Jump Action Cards -->
        <div class="quick-jump-grid">
          <div class="jump-card jump-earnings" (click)="setTab('earnings')">
            <div class="jump-icon-wrap">
              <span class="currency-symbol">£</span>
            </div>
            <div class="jump-text">
              <h3>Earning Report</h3>
              <p>Daily breakdowns & job counts</p>
            </div>
            <span class="material-symbols-outlined jump-arrow">arrow_forward</span>
          </div>

          <div class="jump-card jump-statements" (click)="setTab('statements')">
            <div class="jump-icon-wrap">
              <span class="material-symbols-outlined jump-icon">receipt_long</span>
            </div>
            <div class="jump-text">
              <h3>Your Statements</h3>
              <p>Invoices, commission & downloads</p>
            </div>
            <span class="material-symbols-outlined jump-arrow">arrow_forward</span>
          </div>
        </div>

        <!-- Metric Summary Cards -->
        <div class="summary-metrics-grid">
          <div class="metric-card">
            <div class="metric-icon-box bg-blue-light">
              <span class="material-symbols-outlined text-blue">today</span>
            </div>
            <div class="metric-data">
              <span class="metric-lbl">Today's Gross</span>
              <span class="metric-val">£{{ dashTotals.earningsTotalToday.toFixed(2) }}</span>
            </div>
          </div>

          <div class="metric-card">
            <div class="metric-icon-box bg-orange-light">
              <span class="material-symbols-outlined text-orange">date_range</span>
            </div>
            <div class="metric-data">
              <span class="metric-lbl">This Week</span>
              <span class="metric-val">£{{ dashTotals.earningsTotalWeek.toFixed(2) }}</span>
            </div>
          </div>

          <div class="metric-card">
            <div class="metric-icon-box bg-red-light">
              <span class="material-symbols-outlined text-red">calendar_month</span>
            </div>
            <div class="metric-data">
              <span class="metric-lbl">This Month</span>
              <span class="metric-val">£{{ dashTotals.earningsTotalMonth.toFixed(2) }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- ================= TAB 2: EARNING REPORT ================= -->
      <div *ngIf="activeTab === 'earnings'" class="tab-content animate-fade-in">
        <!-- Date Filter Control Card -->
        <div class="filter-header-card">
          <div class="date-selector-row" (click)="toggleDateModal()">
            <div class="date-display-info">
              <span class="material-symbols-outlined cal-icon">calendar_today</span>
              <span class="date-range-text">
                {{ formatDisplayDate(earningsFrom) }} &ndash; {{ formatDisplayDate(earningsTo) }}
              </span>
            </div>
            <span class="material-symbols-outlined edit-icon">edit_calendar</span>
          </div>

          <!-- Quick Date Range Preset Pills -->
          <div class="preset-pills-row">
            <button 
              class="preset-chip" 
              [class.active]="selectedEarningsPreset === 'today'"
              (click)="applyEarningsPreset('today')"
            >Today</button>
            <button 
              class="preset-chip" 
              [class.active]="selectedEarningsPreset === 'yesterday'"
              (click)="applyEarningsPreset('yesterday')"
            >Yesterday</button>
            <button 
              class="preset-chip" 
              [class.active]="selectedEarningsPreset === 'week'"
              (click)="applyEarningsPreset('week')"
            >This Week</button>
            <button 
              class="preset-chip" 
              [class.active]="selectedEarningsPreset === 'month'"
              (click)="applyEarningsPreset('month')"
            >This Month</button>
            <button 
              class="preset-chip" 
              [class.active]="selectedEarningsPreset === 'last30'"
              (click)="applyEarningsPreset('last30')"
            >Last 30 Days</button>
          </div>
        </div>

        <!-- Earnings List Content -->
        <div class="list-container">
          <div *ngIf="isLoadingEarnings" class="loading-state-box">
            <div class="spinner-ring"></div>
            <span>Fetching earnings records...</span>
          </div>

          <div *ngIf="!isLoadingEarnings && earningsList.length === 0" class="empty-state-box">
            <span class="material-symbols-outlined empty-icon">savings</span>
            <h3>No Earnings Found</h3>
            <p>No trip earnings recorded for the selected date window.</p>
          </div>

          <div *ngIf="!isLoadingEarnings && earningsList.length > 0" class="earnings-items-wrapper">
            <div 
              *ngFor="let item of earningsList; let i = index" 
              class="earning-item-card"
            >
              <div class="earning-index-badge">{{ i + 1 }}</div>
              <div class="earning-main-info">
                <div class="earning-date">{{ formatDisplayDate(item.date) }}</div>
                <div class="earning-totals-sub">
                  <span class="gross-tag">Gross: £{{ item.grossTotal.toFixed(2) }}</span>
                  <span class="net-tag">Net: £{{ item.netTotal.toFixed(2) }}</span>
                </div>
              </div>
              <button 
                class="view-breakdown-btn"
                (click)="openBreakdownModal(item)"
              >
                <span>View</span>
                <span class="material-symbols-outlined btn-arrow">chevron_right</span>
              </button>
            </div>
          </div>
        </div>

        <!-- Bottom Total Floating Bar -->
        <div *ngIf="earningsList.length > 0" class="floating-bottom-summary">
          <div class="summary-pill">
            <span class="summary-title">Total Net Earnings:</span>
            <span class="summary-amount">£{{ totalNetEarnings.toFixed(2) }}</span>
          </div>
        </div>
      </div>

      <!-- ================= TAB 3: STATEMENTS ================= -->
      <div *ngIf="activeTab === 'statements'" class="tab-content animate-fade-in">
        <!-- Statement Filter & Sort Bar -->
        <div class="filter-header-card">
          <div class="statements-controls-row">
            <div class="date-selector-row flex-1" (click)="toggleDateModal()">
              <div class="date-display-info">
                <span class="material-symbols-outlined cal-icon">date_range</span>
                <span class="date-range-text">
                  <ng-container *ngIf="statementsDateFilter">
                    Filtered by Date
                  </ng-container>
                  <ng-container *ngIf="!statementsDateFilter">
                    All Statements
                  </ng-container>
                </span>
              </div>
              <span class="material-symbols-outlined edit-icon">tune</span>
            </div>

            <!-- Sort Toggle Button -->
            <button class="sort-toggle-btn" (click)="toggleSort()">
              <span 
                class="material-symbols-outlined sort-icon"
                [class.flip]="!sortDescending"
              >
                arrow_downward
              </span>
              <span>{{ sortDescending ? 'Newest' : 'Oldest' }}</span>
            </button>
          </div>
        </div>

        <!-- Statements List Content -->
        <div class="list-container">
          <div *ngIf="isLoadingStatements" class="loading-state-box">
            <div class="spinner-ring"></div>
            <span>Loading statement documents...</span>
          </div>

          <div *ngIf="!isLoadingStatements && filteredStatements.length === 0" class="empty-state-box">
            <span class="material-symbols-outlined empty-icon">receipt_long</span>
            <h3>No Statements Available</h3>
            <p>You do not have any published financial statements in this period.</p>
          </div>

          <div *ngIf="!isLoadingStatements && filteredStatements.length > 0" class="statements-items-wrapper">
            <div 
              *ngFor="let s of filteredStatements" 
              class="statement-item-card"
            >
              <div class="statement-card-top">
                <div class="statement-id-row">
                  <span class="material-symbols-outlined stmt-badge-icon">description</span>
                  <span class="stmt-id">Statement #{{ s.statementId }}</span>
                </div>
                <span 
                  class="status-tag"
                  [class.paid]="s.paidInFull"
                  [class.pending]="!s.paidInFull"
                >
                  {{ s.paidInFull ? 'Paid In Full' : 'Payment Pending' }}
                </span>
              </div>

              <div class="statement-period">
                <span class="material-symbols-outlined mini-icon">calendar_today</span>
                <span>{{ formatDisplayDate(s.startDate) }} &ndash; {{ formatDisplayDate(s.endDate) }}</span>
              </div>

              <div class="statement-card-bottom">
                <div class="earned-amount-box">
                  <span class="earned-label">Total Earned</span>
                  <span class="earned-value">£{{ s.totalEarned.toFixed(2) }}</span>
                </div>

                <button 
                  class="view-statement-btn"
                  (click)="openStatementModal(s)"
                >
                  <span class="material-symbols-outlined">visibility</span>
                  <span>VIEW</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- ================= MODAL: EARNING BREAKDOWN ================= -->
      <div *ngIf="selectedBreakdownItem" class="modal-backdrop" (click)="closeBreakdownModal()">
        <div class="modal-card animate-slide-up" (click)="$event.stopPropagation()">
          <div class="modal-header">
            <div class="header-title-box">
              <span class="material-symbols-outlined modal-h-icon text-red">query_stats</span>
              <h3>Earning Breakdown</h3>
            </div>
            <button class="modal-close-btn" (click)="closeBreakdownModal()">
              <span class="material-symbols-outlined">close</span>
            </button>
          </div>

          <div class="modal-body">
            <div class="modal-date-chip">
              <span class="material-symbols-outlined mini-icon">event</span>
              <span>{{ formatDisplayDate(selectedBreakdownItem.date) }}</span>
            </div>

            <!-- Financial Totals Section -->
            <div class="breakdown-section">
              <h4 class="section-heading">Financial Totals</h4>
              <div class="data-grid">
                <div class="data-row">
                  <span class="data-label">Cash Total:</span>
                  <span class="data-val">£{{ selectedBreakdownItem.cashTotal.toFixed(2) }}</span>
                </div>
                <div class="data-row">
                  <span class="data-label">Account Total:</span>
                  <span class="data-val">£{{ selectedBreakdownItem.accTotal.toFixed(2) }}</span>
                </div>
                <div class="data-row">
                  <span class="data-label">Rank Total:</span>
                  <span class="data-val">£{{ selectedBreakdownItem.rankTotal.toFixed(2) }}</span>
                </div>
                <div class="data-row text-orange">
                  <span class="data-label">Commission:</span>
                  <span class="data-val">£{{ selectedBreakdownItem.commsTotal.toFixed(2) }}</span>
                </div>
                <div class="data-row border-top">
                  <span class="data-label font-bold">Gross Total:</span>
                  <span class="data-val font-bold">£{{ selectedBreakdownItem.grossTotal.toFixed(2) }}</span>
                </div>
                <div class="data-row highlight-net">
                  <span class="data-label font-bold text-red">Net Total:</span>
                  <span class="data-val font-bold text-red">£{{ selectedBreakdownItem.netTotal.toFixed(2) }}</span>
                </div>
              </div>
            </div>

            <!-- Job Counts Section -->
            <div class="breakdown-section">
              <h4 class="section-heading">Job Counts</h4>
              <div class="counts-grid">
                <div class="count-pill">
                  <span class="count-num">{{ selectedBreakdownItem.cashJobsCount }}</span>
                  <span class="count-name">Cash Jobs</span>
                </div>
                <div class="count-pill">
                  <span class="count-num">{{ selectedBreakdownItem.accJobsCount }}</span>
                  <span class="count-name">Account Jobs</span>
                </div>
                <div class="count-pill">
                  <span class="count-num">{{ selectedBreakdownItem.rankJobsCount }}</span>
                  <span class="count-name">Rank Jobs</span>
                </div>
                <div *ngIf="selectedBreakdownItem.rankMilesCount !== undefined" class="count-pill">
                  <span class="count-num">{{ selectedBreakdownItem.rankMilesCount.toFixed(1) }}</span>
                  <span class="count-name">Rank Miles</span>
                </div>
              </div>
            </div>
          </div>

          <div class="modal-footer">
            <button class="modal-action-btn btn-close" (click)="closeBreakdownModal()">Close</button>
          </div>
        </div>
      </div>

      <!-- ================= MODAL: STATEMENT DETAILS ================= -->
      <div *ngIf="selectedStatementItem" class="modal-backdrop" (click)="closeStatementModal()">
        <div class="modal-card animate-slide-up" (click)="$event.stopPropagation()">
          <div class="modal-header">
            <div class="header-title-box">
              <span class="material-symbols-outlined modal-h-icon text-red">receipt_long</span>
              <div>
                <h3>Statement Details</h3>
                <span class="sub-header-id">#{{ selectedStatementItem.statementId }}</span>
              </div>
            </div>
            <button class="modal-close-btn" (click)="closeStatementModal()">
              <span class="material-symbols-outlined">close</span>
            </button>
          </div>

          <div class="modal-body scrollable-body">
            <!-- Period & Creation -->
            <div class="modal-period-box">
              <div class="info-line">
                <span class="info-key">Created:</span>
                <span class="info-val">{{ formatDisplayDate(selectedStatementItem.dateCreated) }}</span>
              </div>
              <div class="info-line">
                <span class="info-key">Period:</span>
                <span class="info-val">{{ formatDisplayDate(selectedStatementItem.startDate) }} &ndash; {{ formatDisplayDate(selectedStatementItem.endDate) }}</span>
              </div>
            </div>

            <!-- Earnings Breakdown -->
            <div class="breakdown-section">
              <h4 class="section-heading">Earnings</h4>
              <div class="data-grid">
                <div class="data-row">
                  <span class="data-label">Cash:</span>
                  <span class="data-val">£{{ selectedStatementItem.earningsCash.toFixed(2) }}</span>
                </div>
                <div class="data-row">
                  <span class="data-label">Account:</span>
                  <span class="data-val">£{{ selectedStatementItem.earningsAccount.toFixed(2) }}</span>
                </div>
                <div class="data-row">
                  <span class="data-label">Card:</span>
                  <span class="data-val">£{{ selectedStatementItem.earningsCard.toFixed(2) }}</span>
                </div>
                <div class="data-row">
                  <span class="data-label">Rank:</span>
                  <span class="data-val">£{{ selectedStatementItem.earningsRank.toFixed(2) }}</span>
                </div>
              </div>
            </div>

            <!-- Summary Breakdown -->
            <div class="breakdown-section">
              <h4 class="section-heading">Summary</h4>
              <div class="data-grid">
                <div class="data-row">
                  <span class="data-label">Subtotal:</span>
                  <span class="data-val">£{{ selectedStatementItem.subTotal.toFixed(2) }}</span>
                </div>
                <div class="data-row text-orange">
                  <span class="data-label">Commission Due:</span>
                  <span class="data-val">£{{ selectedStatementItem.commissionDue.toFixed(2) }}</span>
                </div>
                <div class="data-row highlight-net">
                  <span class="data-label font-bold text-red">Total Earned:</span>
                  <span class="data-val font-bold text-red">£{{ selectedStatementItem.totalEarned.toFixed(2) }}</span>
                </div>
                <div class="data-row">
                  <span class="data-label font-bold">Payment Due:</span>
                  <span class="data-val font-bold">£{{ selectedStatementItem.paymentDue.toFixed(2) }}</span>
                </div>
              </div>
            </div>

            <!-- Jobs Counts -->
            <div class="breakdown-section">
              <h4 class="section-heading">Jobs Breakdown</h4>
              <div class="counts-grid">
                <div class="count-pill">
                  <span class="count-num">{{ selectedStatementItem.totalJobCount }}</span>
                  <span class="count-name">Total Jobs</span>
                </div>
                <div class="count-pill">
                  <span class="count-num">{{ selectedStatementItem.accountJobsTotalCount }}</span>
                  <span class="count-name">Account</span>
                </div>
                <div class="count-pill">
                  <span class="count-num">{{ selectedStatementItem.cashJobsTotalCount }}</span>
                  <span class="count-name">Cash</span>
                </div>
                <div class="count-pill">
                  <span class="count-num">{{ selectedStatementItem.rankJobsTotalCount }}</span>
                  <span class="count-name">Rank</span>
                </div>
              </div>
            </div>

            <!-- Status Check -->
            <div class="statement-status-banner" [class.paid]="selectedStatementItem.paidInFull">
              <span class="material-symbols-outlined">
                {{ selectedStatementItem.paidInFull ? 'verified' : 'pending' }}
              </span>
              <span>{{ selectedStatementItem.paidInFull ? 'Paid In Full' : 'Payment Outstanding' }}</span>
            </div>
          </div>

          <div class="modal-footer footer-dual">
            <button class="modal-action-btn btn-close flex-1" (click)="closeStatementModal()">Close</button>
            <button 
              class="modal-action-btn btn-download flex-2" 
              [disabled]="isDownloading"
              (click)="triggerStatementDownload(selectedStatementItem.statementId)"
            >
              <span class="material-symbols-outlined">download</span>
              <span>{{ isDownloading ? 'Downloading...' : 'DOWNLOAD STATEMENT' }}</span>
            </button>
          </div>
        </div>
      </div>

      <!-- ================= MODAL: DATE RANGE PICKER ================= -->
      <div *ngIf="showDateModal" class="modal-backdrop" (click)="toggleDateModal()">
        <div class="modal-card animate-slide-up" (click)="$event.stopPropagation()">
          <div class="modal-header">
            <div class="header-title-box">
              <span class="material-symbols-outlined modal-h-icon text-red">date_range</span>
              <h3>Select Date Range</h3>
            </div>
            <button class="modal-close-btn" (click)="toggleDateModal()">
              <span class="material-symbols-outlined">close</span>
            </button>
          </div>

          <div class="modal-body">
            <div class="custom-date-inputs">
              <div class="date-input-group">
                <label>From Date</label>
                <input 
                  type="date" 
                  class="native-date-input" 
                  [(ngModel)]="customFromDate"
                />
              </div>

              <div class="date-input-group">
                <label>To Date</label>
                <input 
                  type="date" 
                  class="native-date-input" 
                  [(ngModel)]="customToDate"
                />
              </div>
            </div>
          </div>

          <div class="modal-footer footer-dual">
            <button class="modal-action-btn btn-close flex-1" (click)="toggleDateModal()">Cancel</button>
            <button class="modal-action-btn btn-apply flex-1" (click)="applyCustomDateRange()">Apply</button>
          </div>
        </div>
      </div>

    </div>
  `,
  styles: [`
    /* Dark Theme Support via :host-context */
    :host-context(.dark-theme) .reports-container {
      background-color: #121214 !important;
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .view-segmented-bar {
      background-color: #2D2D35 !important;
    }
    :host-context(.dark-theme) .segment-btn:not(.active) {
      color: #90A4AE !important;
    }
    :host-context(.dark-theme) .segment-btn.active {
      background-color: #1E1E24 !important;
      color: #E53935 !important;
      box-shadow: 0 3px 8px rgba(0, 0, 0, 0.3) !important;
    }
    :host-context(.dark-theme) .overview-chart-card,
    :host-context(.dark-theme) .metric-card,
    :host-context(.dark-theme) .filter-header-card,
    :host-context(.dark-theme) .earning-item-card,
    :host-context(.dark-theme) .statement-item-card,
    :host-context(.dark-theme) .modal-card {
      background-color: #1E1E24 !important;
      border-color: #2D2D35 !important;
      color: #ECEFF1 !important;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.25) !important;
    }
    :host-context(.dark-theme) .date-selector-row,
    :host-context(.dark-theme) .modal-period-box,
    :host-context(.dark-theme) .modal-date-chip,
    :host-context(.dark-theme) .data-grid,
    :host-context(.dark-theme) .count-pill {
      background-color: #121214 !important;
      border-color: #2D2D35 !important;
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .modal-header,
    :host-context(.dark-theme) .modal-footer {
      background-color: #1E1E24 !important;
      border-color: #2D2D35 !important;
    }
    :host-context(.dark-theme) .preset-chip {
      background-color: #121214 !important;
      color: #90A4AE !important;
    }
    :host-context(.dark-theme) .preset-chip.active {
      background-color: #E53935 !important;
      color: #FFFFFF !important;
    }
    :host-context(.dark-theme) .btn-close,
    :host-context(.dark-theme) .modal-close-btn {
      background-color: #2D2D35 !important;
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .chart-title,
    :host-context(.dark-theme) .bar-value,
    :host-context(.dark-theme) .metric-val,
    :host-context(.dark-theme) .date-range-text,
    :host-context(.dark-theme) .earning-date,
    :host-context(.dark-theme) .stmt-id,
    :host-context(.dark-theme) .earned-value,
    :host-context(.dark-theme) .header-title-box h3,
    :host-context(.dark-theme) .info-val,
    :host-context(.dark-theme) .data-val {
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .chart-subtitle,
    :host-context(.dark-theme) .bar-label,
    :host-context(.dark-theme) .metric-lbl,
    :host-context(.dark-theme) .gross-tag,
    :host-context(.dark-theme) .statement-period,
    :host-context(.dark-theme) .earned-label,
    :host-context(.dark-theme) .sub-header-id,
    :host-context(.dark-theme) .info-key,
    :host-context(.dark-theme) .data-label,
    :host-context(.dark-theme) .count-name {
      color: #90A4AE !important;
    }
    :host-context(.dark-theme) .bar-track {
      background-color: #2D2D35 !important;
    }
    :host-context(.dark-theme) .statement-card-bottom {
      border-top-color: #2D2D35 !important;
    }
    :host-context(.dark-theme) .data-row {
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .data-row.highlight-net {
      background-color: rgba(229, 57, 53, 0.15) !important;
    }
    :host-context(.dark-theme) .info-line {
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .earning-index-badge {
      background-color: rgba(229, 57, 53, 0.15) !important;
      color: #E53935 !important;
    }

    .reports-container {
      min-height: 100vh;
      background-color: #F8F9FA;
      padding: 16px 16px 80px 16px;
      font-family: 'Roboto', -apple-system, sans-serif;
      box-sizing: border-box;
      position: relative;
    }

    /* Pull to Refresh Spinner */
    .floating-refresh-spinner {
      position: fixed;
      top: 0;
      left: 50%;
      width: 40px;
      height: 40px;
      background: #FFFFFF;
      border-radius: 50%;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 1000;
      pointer-events: none;
      transition: opacity 0.2s ease;
    }
    .native-spin-icon {
      color: #E53935;
      font-size: 24px;
    }
    .native-spin-icon.spinning {
      animation: spin 0.8s linear infinite;
    }
    @keyframes spin {
      100% { transform: rotate(360deg); }
    }

    /* View Segmented Navigation */
    .view-segmented-bar {
      display: flex;
      background: #EFEFEF;
      border-radius: 30px;
      padding: 4px;
      margin-bottom: 16px;
      gap: 4px;
    }
    .segment-btn {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      padding: 10px 4px;
      border: none;
      background: transparent;
      border-radius: 24px;
      font-size: 13px;
      font-weight: 600;
      color: #616161;
      cursor: pointer;
      transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
    }
    .segment-btn.active {
      background: #E53935;
      color: #FFFFFF;
      box-shadow: 0 3px 8px rgba(229, 57, 53, 0.3);
    }
    .seg-icon {
      font-size: 18px;
    }

    /* Overview Chart Card */
    .overview-chart-card {
      background: #FFFFFF;
      border-radius: 20px;
      padding: 20px 16px;
      box-shadow: 0 4px 16px rgba(0,0,0,0.05);
      border: 1px solid #ECEFF1;
      margin-bottom: 16px;
    }
    .chart-header {
      margin-bottom: 24px;
    }
    .chart-title {
      font-size: 20px;
      font-weight: 800;
      color: #212121;
      margin: 0 0 4px 0;
    }
    .chart-subtitle {
      font-size: 12px;
      color: #78909C;
      font-weight: 500;
    }
    .chart-body {
      height: 200px;
      display: flex;
      align-items: flex-end;
      padding-bottom: 10px;
    }
    .bar-columns-wrapper {
      width: 100%;
      display: flex;
      justify-content: space-around;
      align-items: flex-end;
      height: 100%;
    }
    .bar-col {
      display: flex;
      flex-direction: column;
      align-items: center;
      width: 60px;
      height: 100%;
      justify-content: flex-end;
    }
    .bar-value {
      font-size: 13px;
      font-weight: 800;
      color: #263238;
      margin-bottom: 8px;
    }
    .bar-track {
      width: 44px;
      height: 130px;
      background: #F1F3F4;
      border-radius: 12px;
      display: flex;
      align-items: flex-end;
      overflow: hidden;
    }
    .bar-fill {
      width: 100%;
      border-radius: 12px;
      transition: height 0.6s cubic-bezier(0.4, 0, 0.2, 1);
      min-height: 8px;
    }
    .bar-today {
      background: linear-gradient(180deg, #42A5F5, #1E88E5);
    }
    .bar-week {
      background: linear-gradient(180deg, #FF7043, #E64A19);
    }
    .bar-month {
      background: linear-gradient(180deg, #EF5350, #C62828);
    }
    .bar-label {
      font-size: 12px;
      font-weight: 700;
      color: #546E7A;
      margin-top: 8px;
      white-space: nowrap;
    }

    /* Quick Jump Grid */
    .quick-jump-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
      margin-bottom: 16px;
    }
    .jump-card {
      background: linear-gradient(135deg, #E53935, #B71C1C);
      color: #FFFFFF;
      border-radius: 18px;
      padding: 16px 14px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      height: 100px;
      cursor: pointer;
      box-shadow: 0 4px 12px rgba(229, 57, 53, 0.25);
      transition: transform 0.15s ease;
      position: relative;
    }
    .jump-card:active {
      transform: scale(0.97);
    }
    .jump-icon-wrap {
      width: 32px;
      height: 32px;
      background: rgba(255,255,255,0.2);
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .currency-symbol {
      font-size: 20px;
      font-weight: 900;
      color: #FFFFFF;
    }
    .jump-icon {
      font-size: 20px;
      color: #FFFFFF;
    }
    .jump-text h3 {
      font-size: 14px;
      font-weight: 800;
      margin: 6px 0 2px 0;
    }
    .jump-text p {
      font-size: 10px;
      opacity: 0.85;
      margin: 0;
    }
    .jump-arrow {
      position: absolute;
      top: 14px;
      right: 12px;
      font-size: 18px;
      opacity: 0.7;
    }

    /* Metric Summary Grid */
    .summary-metrics-grid {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .metric-card {
      background: #FFFFFF;
      border-radius: 16px;
      padding: 12px 16px;
      display: flex;
      align-items: center;
      gap: 14px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.04);
      border: 1px solid #ECEFF1;
    }
    .metric-icon-box {
      width: 42px;
      height: 42px;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .bg-blue-light { background: #E3F2FD; }
    .bg-orange-light { background: #FBE9E7; }
    .bg-red-light { background: #FFEBEE; }
    .text-blue { color: #1E88E5; }
    .text-orange { color: #E64A19; }
    .text-red { color: #E53935; }
    .metric-data {
      display: flex;
      flex-direction: column;
    }
    .metric-lbl {
      font-size: 12px;
      color: #78909C;
      font-weight: 500;
    }
    .metric-val {
      font-size: 16px;
      font-weight: 800;
      color: #263238;
    }

    /* Filter Header Card */
    .filter-header-card {
      background: #FFFFFF;
      border-radius: 18px;
      padding: 12px 14px;
      box-shadow: 0 3px 12px rgba(0,0,0,0.04);
      border: 1px solid #ECEFF1;
      margin-bottom: 14px;
    }
    .date-selector-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      background: #F8F9FA;
      border: 1px solid #CFD8DC;
      border-radius: 14px;
      padding: 10px 14px;
      cursor: pointer;
    }
    .date-display-info {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .cal-icon {
      font-size: 18px;
      color: #E53935;
    }
    .date-range-text {
      font-size: 13px;
      font-weight: 700;
      color: #37474F;
    }
    .edit-icon {
      font-size: 18px;
      color: #78909C;
    }

    .preset-pills-row {
      display: flex;
      gap: 6px;
      overflow-x: auto;
      margin-top: 10px;
      padding-bottom: 4px;
      scrollbar-width: none;
    }
    .preset-pills-row::-webkit-scrollbar {
      display: none;
    }
    .preset-chip {
      background: #F1F3F4;
      border: none;
      border-radius: 20px;
      padding: 6px 12px;
      font-size: 11px;
      font-weight: 600;
      color: #546E7A;
      white-space: nowrap;
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .preset-chip.active {
      background: #E53935;
      color: #FFFFFF;
    }

    .statements-controls-row {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .flex-1 { flex: 1; }
    .flex-2 { flex: 2; }
    .sort-toggle-btn {
      display: flex;
      align-items: center;
      gap: 4px;
      background: #FFEBEE;
      border: 1px solid #FFCDD2;
      border-radius: 14px;
      padding: 10px 12px;
      color: #C62828;
      font-size: 12px;
      font-weight: 700;
      cursor: pointer;
    }
    .sort-icon {
      font-size: 16px;
      transition: transform 0.25s ease;
    }
    .sort-icon.flip {
      transform: rotate(180deg);
    }

    /* Earnings Item Card */
    .earning-item-card {
      background: #FFFFFF;
      border-radius: 16px;
      padding: 12px 14px;
      display: flex;
      align-items: center;
      gap: 12px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.04);
      border: 1px solid #ECEFF1;
      margin-bottom: 10px;
    }
    .earning-index-badge {
      width: 32px;
      height: 32px;
      border-radius: 50%;
      background: #FFEBEE;
      color: #E53935;
      font-weight: 800;
      font-size: 13px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .earning-main-info {
      flex: 1;
    }
    .earning-date {
      font-size: 14px;
      font-weight: 800;
      color: #263238;
      margin-bottom: 3px;
    }
    .earning-totals-sub {
      display: flex;
      gap: 8px;
    }
    .gross-tag {
      font-size: 11px;
      color: #546E7A;
      font-weight: 600;
    }
    .net-tag {
      font-size: 11px;
      color: #2E7D32;
      font-weight: 700;
    }
    .view-breakdown-btn {
      background: #E53935;
      color: #FFFFFF;
      border: none;
      border-radius: 10px;
      padding: 8px 12px;
      font-size: 12px;
      font-weight: 700;
      display: flex;
      align-items: center;
      gap: 2px;
      cursor: pointer;
    }
    .btn-arrow {
      font-size: 16px;
    }

    /* Statements Item Card */
    .statement-item-card {
      background: #FFFFFF;
      border-radius: 18px;
      padding: 14px 16px;
      box-shadow: 0 3px 10px rgba(0,0,0,0.04);
      border: 1px solid #ECEFF1;
      margin-bottom: 12px;
    }
    .statement-card-top {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 8px;
    }
    .statement-id-row {
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .stmt-badge-icon {
      font-size: 18px;
      color: #E53935;
    }
    .stmt-id {
      font-size: 15px;
      font-weight: 800;
      color: #263238;
    }
    .status-tag {
      font-size: 11px;
      font-weight: 700;
      padding: 4px 10px;
      border-radius: 20px;
    }
    .status-tag.paid {
      background: #E8F5E9;
      color: #2E7D32;
    }
    .status-tag.pending {
      background: #FFF3E0;
      color: #EF6C00;
    }
    .statement-period {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 12px;
      color: #546E7A;
      font-weight: 600;
      margin-bottom: 12px;
    }
    .mini-icon {
      font-size: 14px;
    }
    .statement-card-bottom {
      display: flex;
      align-items: center;
      justify-content: space-between;
      border-top: 1px solid #F1F3F4;
      padding-top: 10px;
    }
    .earned-amount-box {
      display: flex;
      flex-direction: column;
    }
    .earned-label {
      font-size: 10px;
      color: #78909C;
      font-weight: 600;
      text-transform: uppercase;
    }
    .earned-value {
      font-size: 17px;
      font-weight: 900;
      color: #1B5E20;
    }
    .view-statement-btn {
      background: #E53935;
      color: #FFFFFF;
      border: none;
      border-radius: 20px;
      padding: 8px 16px;
      font-size: 12px;
      font-weight: 800;
      display: flex;
      align-items: center;
      gap: 4px;
      cursor: pointer;
    }

    /* Floating Bottom Summary */
    .floating-bottom-summary {
      position: fixed;
      bottom: 20px;
      left: 0;
      right: 0;
      display: flex;
      justify-content: center;
      pointer-events: none;
      z-index: 100;
    }
    .summary-pill {
      background: #263238;
      color: #FFFFFF;
      padding: 10px 22px;
      border-radius: 30px;
      box-shadow: 0 6px 20px rgba(0,0,0,0.25);
      display: flex;
      align-items: center;
      gap: 8px;
      pointer-events: auto;
    }
    .summary-title {
      font-size: 13px;
      font-weight: 500;
      color: #CFD8DC;
    }
    .summary-amount {
      font-size: 16px;
      font-weight: 900;
      color: #FFD54F;
    }

    /* Modals */
    .modal-backdrop {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: rgba(0,0,0,0.55);
      backdrop-filter: blur(4px);
      z-index: 2000;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .modal-card {
      background: #FFFFFF;
      border-radius: 24px;
      width: 100%;
      max-width: 400px;
      max-height: 85vh;
      display: flex;
      flex-direction: column;
      box-shadow: 0 10px 30px rgba(0,0,0,0.25);
      overflow: hidden;
    }
    .modal-header {
      padding: 16px 20px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      border-bottom: 1px solid #ECEFF1;
    }
    .header-title-box {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .modal-h-icon {
      font-size: 24px;
    }
    .header-title-box h3 {
      font-size: 17px;
      font-weight: 800;
      color: #212121;
      margin: 0;
    }
    .sub-header-id {
      font-size: 11px;
      color: #78909C;
      font-weight: 600;
    }
    .modal-close-btn {
      background: #F5F5F5;
      border: none;
      width: 32px;
      height: 32px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      color: #546E7A;
    }

    .modal-body {
      padding: 16px 20px;
      overflow-y: auto;
    }
    .scrollable-body {
      max-height: 60vh;
    }
    .modal-date-chip, .modal-period-box {
      background: #F8F9FA;
      border-radius: 12px;
      padding: 10px 14px;
      margin-bottom: 14px;
      font-size: 13px;
      font-weight: 700;
      color: #37474F;
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .modal-period-box {
      flex-direction: column;
      align-items: flex-start;
      gap: 4px;
    }
    .info-line {
      display: flex;
      justify-content: space-between;
      width: 100%;
      font-size: 12px;
    }
    .info-key { color: #78909C; }
    .info-val { font-weight: 700; color: #263238; }

    .breakdown-section {
      margin-bottom: 16px;
    }
    .section-heading {
      font-size: 12px;
      font-weight: 800;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      color: #E53935;
      margin: 0 0 8px 0;
    }
    .data-grid {
      background: #FAFAFA;
      border-radius: 12px;
      padding: 10px 14px;
      border: 1px solid #ECEFF1;
    }
    .data-row {
      display: flex;
      justify-content: space-between;
      padding: 4px 0;
      font-size: 13px;
      color: #455A64;
    }
    .data-row.border-top {
      border-top: 1px dashed #CFD8DC;
      margin-top: 4px;
      padding-top: 6px;
    }
    .data-row.highlight-net {
      background: #FFEBEE;
      margin: 4px -14px -10px -14px;
      padding: 8px 14px;
      border-radius: 0 0 12px 12px;
    }
    .font-bold { font-weight: 800; }

    .counts-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 8px;
    }
    .count-pill {
      background: #F1F3F4;
      border-radius: 12px;
      padding: 10px;
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    .count-num {
      font-size: 18px;
      font-weight: 900;
      color: #E53935;
    }
    .count-name {
      font-size: 11px;
      font-weight: 600;
      color: #546E7A;
      margin-top: 2px;
    }

    .statement-status-banner {
      background: #FFF3E0;
      color: #EF6C00;
      border-radius: 12px;
      padding: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      font-weight: 700;
      font-size: 13px;
      margin-top: 8px;
    }
    .statement-status-banner.paid {
      background: #E8F5E9;
      color: #2E7D32;
    }

    .modal-footer {
      padding: 14px 20px;
      border-top: 1px solid #ECEFF1;
      display: flex;
      gap: 10px;
    }
    .modal-action-btn {
      padding: 12px;
      border: none;
      border-radius: 14px;
      font-size: 13px;
      font-weight: 800;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
    }
    .btn-close {
      background: #ECEFF1;
      color: #455A64;
    }
    .btn-apply {
      background: #E53935;
      color: #FFFFFF;
    }
    .btn-download {
      background: #E53935;
      color: #FFFFFF;
    }
    .btn-download:disabled {
      opacity: 0.6;
    }

    .custom-date-inputs {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .date-input-group {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .date-input-group label {
      font-size: 12px;
      font-weight: 700;
      color: #546E7A;
    }
    .native-date-input {
      padding: 10px 14px;
      border-radius: 12px;
      border: 1px solid #CFD8DC;
      font-size: 14px;
      font-weight: 600;
      color: #263238;
      outline: none;
    }

    /* Loaders & Empty states */
    .loading-state-box, .chart-loader {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 30px;
      gap: 12px;
      color: #78909C;
      font-size: 13px;
      font-weight: 600;
    }
    .spinner-ring {
      width: 28px;
      height: 28px;
      border: 3px solid #FFCDD2;
      border-top-color: #E53935;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
    }
    .empty-state-box {
      text-align: center;
      padding: 40px 20px;
      color: #78909C;
    }
    .empty-icon {
      font-size: 48px;
      color: #B0BEC5;
      margin-bottom: 8px;
    }
    .empty-state-box h3 {
      font-size: 16px;
      font-weight: 800;
      color: #37474F;
      margin: 0 0 4px 0;
    }
    .empty-state-box p {
      font-size: 12px;
      margin: 0;
    }

    /* Animations */
    .animate-fade-in {
      animation: fadeIn 0.25s ease-out;
    }
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(4px); }
      to { opacity: 1; transform: translateY(0); }
    }
    .animate-slide-up {
      animation: slideUp 0.3s cubic-bezier(0.16, 1, 0.3, 1);
    }
    @keyframes slideUp {
      from { opacity: 0; transform: translateY(30px) scale(0.96); }
      to { opacity: 1; transform: translateY(0) scale(1); }
    }
  `]
})
export class ReportsComponent implements OnInit {
  activeTab: 'overview' | 'earnings' | 'statements' = 'overview';

  // Dash totals
  isLoadingDash = false;
  dashTotals: DashTotals = {
    earningsTotalToday: 0,
    earningsTotalWeek: 0,
    earningsTotalMonth: 0
  };

  // Earnings report
  isLoadingEarnings = false;
  selectedEarningsPreset: 'today' | 'yesterday' | 'week' | 'month' | 'last30' | 'custom' = 'month';
  earningsFrom: string = '';
  earningsTo: string = '';
  earningsList: EarningItem[] = [];
  selectedBreakdownItem: EarningItem | null = null;

  // Statements
  isLoadingStatements = false;
  statementsList: StatementItem[] = [];
  sortDescending = true;
  statementsDateFilter: boolean = false;
  selectedStatementItem: StatementItem | null = null;
  isDownloading = false;

  // Date Modal
  showDateModal = false;
  customFromDate = '';
  customToDate = '';

  // Pull to refresh
  startY = 0;
  pullDistance = 0;
  isRefreshing = false;

  constructor(
    private driverService: DriverService,
    private cdr: ChangeDetectorRef,
    private snackBar: MatSnackBar
  ) {}

  ngOnInit(): void {
    this.initDefaultDates();
    this.loadDashTotals();
    this.loadEarnings();
    this.loadStatements();
  }

  setTab(tab: 'overview' | 'earnings' | 'statements'): void {
    this.activeTab = tab;
    if (tab === 'overview' && this.dashTotals.earningsTotalToday === 0) {
      this.loadDashTotals();
    } else if (tab === 'earnings' && this.earningsList.length === 0) {
      this.loadEarnings();
    } else if (tab === 'statements' && this.statementsList.length === 0) {
      this.loadStatements();
    }
    this.cdr.detectChanges();
  }

  // ---------------- DATE LOGIC ----------------
  initDefaultDates(): void {
    const now = new Date();
    // Default to this month
    const firstDay = new Date(now.getFullYear(), now.getMonth(), 1);
    this.earningsFrom = this.formatDateIso(firstDay);
    this.earningsTo = this.formatDateIso(now);
    this.customFromDate = this.earningsFrom;
    this.customToDate = this.earningsTo;
  }

  formatDateIso(d: Date): string {
    const y = d.getFullYear();
    const m = (d.getMonth() + 1).toString().padStart(2, '0');
    const day = d.getDate().toString().padStart(2, '0');
    return `${y}-${m}-${day}`;
  }

  formatDisplayDate(val: string | Date | undefined): string {
    if (!val) return '';
    const d = typeof val === 'string' ? new Date(val) : val;
    if (isNaN(d.getTime())) return typeof val === 'string' ? val : '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return `${d.getDate()} ${months[d.getMonth()]} ${d.getFullYear()}`;
  }

  applyEarningsPreset(preset: 'today' | 'yesterday' | 'week' | 'month' | 'last30'): void {
    this.selectedEarningsPreset = preset;
    const now = new Date();

    switch (preset) {
      case 'today':
        this.earningsFrom = this.formatDateIso(now);
        this.earningsTo = this.formatDateIso(now);
        break;
      case 'yesterday':
        const yest = new Date(now);
        yest.setDate(yest.getDate() - 1);
        this.earningsFrom = this.formatDateIso(yest);
        this.earningsTo = this.formatDateIso(yest);
        break;
      case 'week':
        const dayOfWeek = now.getDay() || 7; // 1 = Monday
        const monday = new Date(now);
        monday.setDate(now.getDate() - (dayOfWeek - 1));
        this.earningsFrom = this.formatDateIso(monday);
        this.earningsTo = this.formatDateIso(now);
        break;
      case 'month':
        const firstOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
        this.earningsFrom = this.formatDateIso(firstOfMonth);
        this.earningsTo = this.formatDateIso(now);
        break;
      case 'last30':
        const prior30 = new Date(now);
        prior30.setDate(now.getDate() - 30);
        this.earningsFrom = this.formatDateIso(prior30);
        this.earningsTo = this.formatDateIso(now);
        break;
    }

    this.customFromDate = this.earningsFrom;
    this.customToDate = this.earningsTo;
    this.loadEarnings();
  }

  toggleDateModal(): void {
    this.showDateModal = !this.showDateModal;
  }

  applyCustomDateRange(): void {
    if (this.customFromDate && this.customToDate) {
      this.earningsFrom = this.customFromDate;
      this.earningsTo = this.customToDate;
      this.selectedEarningsPreset = 'custom';
      this.showDateModal = false;
      if (this.activeTab === 'earnings') {
        this.loadEarnings();
      } else if (this.activeTab === 'statements') {
        this.statementsDateFilter = true;
      }
    }
  }

  // ---------------- API: DASH TOTALS ----------------
  loadDashTotals(): void {
    this.isLoadingDash = true;
    this.driverService.getDashTotals().subscribe({
      next: (res: any) => {
        this.isLoadingDash = false;
        if (res) {
          const raw = res.data || res.value || res;
          this.dashTotals = {
            earningsTotalToday: Number(raw.earningsTotalToday ?? raw.EarningsTotalToday ?? 0),
            earningsTotalWeek: Number(raw.earningsTotalWeek ?? raw.EarningsTotalWeek ?? 0),
            earningsTotalMonth: Number(raw.earningsTotalMonth ?? raw.EarningsTotalMonth ?? 0),
            jobCountToday: raw.jobCountToday ?? raw.JobCountToday,
            jobCountWeek: raw.jobCountWeek ?? raw.JobCountWeek,
            jobCountMonth: raw.jobCountMonth ?? raw.JobCountMonth
          };
        }
        this.cdr.detectChanges();
      },
      error: (err) => {
        this.isLoadingDash = false;
        console.error('[Reports] Error loading dash totals:', err);
        this.cdr.detectChanges();
      }
    });
  }

  getBarHeight(val: number): number {
    const max = Math.max(
      this.dashTotals.earningsTotalToday,
      this.dashTotals.earningsTotalWeek,
      this.dashTotals.earningsTotalMonth,
      1
    );
    return Math.max(10, Math.round((val / max) * 100));
  }

  // ---------------- API: EARNINGS ----------------
  loadEarnings(): void {
    this.isLoadingEarnings = true;
    this.driverService.getEarnings(this.earningsFrom, this.earningsTo).subscribe({
      next: (res: any) => {
        this.isLoadingEarnings = false;
        this.isRefreshing = false;
        let list: any[] = [];
        if (Array.isArray(res)) {
          list = res;
        } else if (res && Array.isArray(res.data)) {
          list = res.data;
        } else if (res && Array.isArray(res.value)) {
          list = res.value;
        } else if (res && Array.isArray(res.earnings)) {
          list = res.earnings;
        }

        console.log('[Reports] Loaded earnings list:', list.length, list);

        this.earningsList = list.map((item: any) => ({
          date: item.date || item.Date || new Date().toISOString(),
          cashTotal: Number(item.cashTotal ?? item.CashTotal ?? 0),
          accTotal: Number(item.accTotal ?? item.AccTotal ?? 0),
          rankTotal: Number(item.rankTotal ?? item.RankTotal ?? 0),
          commsTotal: Number(item.commsTotal ?? item.CommsTotal ?? 0),
          grossTotal: Number(item.grossTotal ?? item.GrossTotal ?? 0),
          netTotal: Number(item.netTotal ?? item.NetTotal ?? 0),
          cashJobsCount: Number(item.cashJobsCount ?? item.CashJobsCount ?? 0),
          accJobsCount: Number(item.accJobsCount ?? item.AccJobsCount ?? 0),
          rankJobsCount: Number(item.rankJobsCount ?? item.RankJobsCount ?? 0),
          rankMilesCount: item.rankMilesCount !== undefined ? Number(item.rankMilesCount) : undefined
        }));

        this.cdr.detectChanges();
      },
      error: (err) => {
        this.isLoadingEarnings = false;
        this.isRefreshing = false;
        console.error('[Reports] Error loading earnings:', err);
        this.cdr.detectChanges();
      }
    });
  }

  get totalNetEarnings(): number {
    return this.earningsList.reduce((acc, curr) => acc + (curr.netTotal || 0), 0);
  }

  openBreakdownModal(item: EarningItem): void {
    this.selectedBreakdownItem = item;
  }

  closeBreakdownModal(): void {
    this.selectedBreakdownItem = null;
  }

  // ---------------- API: STATEMENTS ----------------
  loadStatements(): void {
    this.isLoadingStatements = true;
    this.driverService.getStatements().subscribe({
      next: (res: any) => {
        this.isLoadingStatements = false;
        this.isRefreshing = false;
        let list: any[] = [];
        if (Array.isArray(res)) {
          list = res;
        } else if (res && Array.isArray(res.data)) {
          list = res.data;
        } else if (res && Array.isArray(res.value)) {
          list = res.value;
        } else if (res && Array.isArray(res.statements)) {
          list = res.statements;
        }

        console.log('[Reports] Loaded statements list:', list.length, list);

        this.statementsList = list.map((item: any) => ({
          statementId: item.statementId ?? item.StatementId ?? item.id ?? 0,
          dateCreated: item.dateCreated ?? item.DateCreated ?? new Date().toISOString(),
          dateUpdated: item.dateUpdated ?? item.DateUpdated,
          startDate: item.startDate ?? item.StartDate ?? new Date().toISOString(),
          endDate: item.endDate ?? item.EndDate ?? new Date().toISOString(),
          earningsCash: Number(item.earningsCash ?? item.EarningsCash ?? 0),
          earningsAccount: Number(item.earningsAccount ?? item.EarningsAccount ?? 0),
          earningsCard: Number(item.earningsCard ?? item.EarningsCard ?? 0),
          earningsRank: Number(item.earningsRank ?? item.EarningsRank ?? 0),
          commissionDue: Number(item.commissionDue ?? item.CommissionDue ?? 0),
          subTotal: Number(item.subTotal ?? item.SubTotal ?? 0),
          totalEarned: Number(item.totalEarned ?? item.TotalEarned ?? 0),
          paymentDue: Number(item.paymentDue ?? item.PaymentDue ?? 0),
          totalJobCount: Number(item.totalJobCount ?? item.TotalJobCount ?? 0),
          accountJobsTotalCount: Number(item.accountJobsTotalCount ?? item.AccountJobsTotalCount ?? 0),
          cashJobsTotalCount: Number(item.cashJobsTotalCount ?? item.CashJobsTotalCount ?? 0),
          rankJobsTotalCount: Number(item.rankJobsTotalCount ?? item.RankJobsTotalCount ?? 0),
          paidInFull: !!(item.paidInFull ?? item.PaidInFull),
          userId: item.userId ?? item.UserId,
          identifier: item.identifier ?? item.Identifier,
          colorCode: item.colorCode ?? item.ColorCode,
          jobs: item.jobs ?? item.Jobs ?? []
        }));

        this.cdr.detectChanges();
      },
      error: (err) => {
        this.isLoadingStatements = false;
        this.isRefreshing = false;
        console.error('[Reports] Error loading statements:', err);
        this.cdr.detectChanges();
      }
    });
  }

  get filteredStatements(): StatementItem[] {
    let list = [...this.statementsList];
    if (this.statementsDateFilter && this.customFromDate && this.customToDate) {
      const fromD = new Date(this.customFromDate);
      const toD = new Date(this.customToDate);
      toD.setHours(23, 59, 59);
      list = list.filter(s => {
        const created = new Date(s.dateCreated);
        return created >= fromD && created <= toD;
      });
    }

    list.sort((a, b) => {
      const timeA = new Date(a.dateCreated).getTime();
      const timeB = new Date(b.dateCreated).getTime();
      return this.sortDescending ? timeB - timeA : timeA - timeB;
    });

    return list;
  }

  toggleSort(): void {
    this.sortDescending = !this.sortDescending;
  }

  openStatementModal(s: StatementItem): void {
    this.selectedStatementItem = s;
  }

  closeStatementModal(): void {
    this.selectedStatementItem = null;
  }

  triggerStatementDownload(statementId: number): void {
    this.isDownloading = true;
    this.driverService.downloadStatement(statementId).subscribe({
      next: (blob: Blob) => {
        this.isDownloading = false;
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `statement_${statementId}.pdf`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        window.URL.revokeObjectURL(url);
        this.snackBar.open('Statement downloaded successfully 📄', 'Close', { duration: 3000 });
      },
      error: (err) => {
        this.isDownloading = false;
        console.warn('Download statement blob note:', err);
        // Direct browser navigation fallback
        window.open(`/api/Accounts/DownloadStatement?statementId=${statementId}`, '_blank');
        this.snackBar.open('Initiating statement download...', 'Close', { duration: 3000 });
      }
    });
  }

  // ---------------- PULL TO REFRESH ----------------
  onTouchStart(e: TouchEvent): void {
    if (window.scrollY === 0) {
      this.startY = e.touches[0].clientY;
    }
  }

  onTouchMove(e: TouchEvent): void {
    if (this.startY > 0 && window.scrollY === 0) {
      const currentY = e.touches[0].clientY;
      const dist = currentY - this.startY;
      if (dist > 0) {
        this.pullDistance = Math.min(dist * 0.4, 70);
      }
    }
  }

  onTouchEnd(): void {
    if (this.pullDistance >= 50 && !this.isRefreshing) {
      this.isRefreshing = true;
      this.pullDistance = 50;
      if (this.activeTab === 'overview') {
        this.loadDashTotals();
      } else if (this.activeTab === 'earnings') {
        this.loadEarnings();
      } else if (this.activeTab === 'statements') {
        this.loadStatements();
      }
      setTimeout(() => {
        this.isRefreshing = false;
        this.pullDistance = 0;
        this.cdr.detectChanges();
      }, 1200);
    } else {
      this.pullDistance = 0;
    }
    this.startY = 0;
  }
}
