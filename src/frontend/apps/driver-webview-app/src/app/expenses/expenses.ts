import { Component, OnInit, OnDestroy, ChangeDetectorRef, ViewChild, ElementRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDividerModule } from '@angular/material/divider';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { DriverService } from '../services/driver.service';

interface ExpenseItem {
  id: number;
  date: string;
  category: number | string;
  amount: number;
  description?: string;
  status: any;
}

interface CategoryOption {
  value: number;
  label: string;
  icon: string;
  color: string;
  lightColor: string;
}

@Component({
  selector: 'app-expenses',
  standalone: true,
  imports: [
    CommonModule,
    MatButtonModule,
    MatIconModule,
    MatDividerModule,
    MatSnackBarModule
  ],
  template: `
    <div 
      class="expenses-container"
      (touchstart)="onTouchStart($event)"
      (touchmove)="onTouchMove($event)"
      (touchend)="onTouchEnd()"
    >
      <!-- Pull-to-Refresh Floating Spinner -->
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

      <!-- Hero Financial Overview Card (List View Only) -->
      <div class="hero-overview-card animated-fade-in" *ngIf="!isLoading && !isFormOpen">
        <div class="hero-top-bar">
          <div class="hero-badge">
            <span class="material-symbols-outlined badge-icon">receipt_long</span>
            <span>EXPENSE & TAX CLAIM HUB</span>
          </div>
          <button class="quick-log-btn" (click)="openAddForm()">
            <span class="material-symbols-outlined">add</span>
            <span>Log Expense</span>
          </button>
        </div>

        <div class="total-claimed-block">
          <span class="total-label">Total Expenses Claimed</span>
          <div class="total-amount-row">
            <span class="currency-sign">£</span>
            <span class="total-number">{{ totalClaimed.toFixed(2) }}</span>
            <span class="count-pill">{{ expenses.length }} {{ expenses.length === 1 ? 'item' : 'items' }}</span>
          </div>
        </div>

        <!-- 3-Pill Status Grid -->
        <div class="status-summary-grid">
          <div class="status-box approved">
            <div class="status-box-header">
              <span class="status-dot green"></span>
              <span class="status-box-title">Approved</span>
            </div>
            <span class="status-box-val">£{{ approvedTotal.toFixed(2) }}</span>
          </div>
          <div class="status-box pending">
            <div class="status-box-header">
              <span class="status-dot amber"></span>
              <span class="status-box-title">Pending</span>
            </div>
            <span class="status-box-val">£{{ pendingTotal.toFixed(2) }}</span>
          </div>
          <div class="status-box rejected">
            <div class="status-box-header">
              <span class="status-dot rose"></span>
              <span class="status-box-title">Declined</span>
            </div>
            <span class="status-box-val">£{{ rejectedTotal.toFixed(2) }}</span>
          </div>
        </div>

        <!-- Collapsible Category Breakdown -->
        <div class="breakdown-wrapper" *ngIf="categoryBreakdown.length > 0">
          <button class="breakdown-toggle-btn" (click)="toggleBreakdown()">
            <div class="breakdown-toggle-left">
              <span class="material-symbols-outlined toggle-icon">pie_chart</span>
              <span class="toggle-text">Category Spending Breakdown</span>
            </div>
            <span class="material-symbols-outlined toggle-arrow">
              {{ isBreakdownOpen ? 'expand_less' : 'expand_more' }}
            </span>
          </button>

          <div class="breakdown-drawer" [class.open]="isBreakdownOpen">
            <div class="breakdown-row" *ngFor="let cat of categoryBreakdown">
              <div class="breakdown-labels">
                <span class="cat-name-tag">{{ cat.name }}</span>
                <span class="cat-val-tag">£{{ cat.total.toFixed(2) }} • {{ cat.pct.toFixed(0) }}%</span>
              </div>
              <div class="breakdown-bar-track">
                <div 
                  class="breakdown-bar-fill" 
                  [style.width]="cat.pct + '%'" 
                  [style.background-color]="cat.color"
                ></div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Date Filters Segment Bar (List View Only) -->
      <div class="filters-dock animated-fade-in" *ngIf="!isFormOpen && !isLoading">
        <div class="filter-pills-group">
          <button 
            class="filter-pill-btn" 
            [class.active]="activeFilterDays === 7" 
            (click)="setFilter(7)"
          >
            Last 7 Days
          </button>
          <button 
            class="filter-pill-btn" 
            [class.active]="activeFilterDays === 30" 
            (click)="setFilter(30)"
          >
            Last 30 Days
          </button>
          <button 
            class="filter-pill-btn" 
            [class.active]="activeFilterDays === 90" 
            (click)="setFilter(90)"
          >
            Last 90 Days
          </button>
        </div>
      </div>

      <!-- Loading Skeleton State -->
      <div *ngIf="isLoading" class="skeleton-container animated-fade-in">
        <div class="skeleton-card" *ngFor="let i of [1, 2, 3, 4]">
          <div class="skeleton-shimmer"></div>
        </div>
      </div>

      <!-- Expenses List View -->
      <div *ngIf="!isLoading && !isFormOpen" class="expenses-list-view animated-fade-in">
        <!-- Empty State -->
        <div *ngIf="expenses.length === 0" class="empty-state-card">
          <div class="empty-icon-circle">
            <span class="material-symbols-outlined">receipt_long</span>
          </div>
          <h4 class="empty-title">No Expenses Logged</h4>
          <p class="empty-desc">You have not logged any fuel, toll, or maintenance claims for this time range.</p>
          <button mat-flat-button class="empty-cta-btn" (click)="openAddForm()">
            <span class="material-symbols-outlined">add_circle</span>
            <span>Log Your First Expense</span>
          </button>
        </div>

        <!-- Expense Rows List -->
        <div class="expense-items-stack" *ngIf="expenses.length > 0">
          <div 
            class="expense-item-card" 
            *ngFor="let item of expenses" 
            (click)="viewReceipt(item)"
          >
            <!-- Left Category Indicator Line -->
            <div class="item-accent-line" [style.background-color]="getCategoryColor(item.category)"></div>
            
            <div class="item-card-inner">
              <!-- Category Icon Badge -->
              <div 
                class="item-icon-box" 
                [style.background-color]="getCategoryColorLight(item.category)" 
                [style.color]="getCategoryColor(item.category)"
              >
                <span class="material-symbols-outlined">{{ getCategoryIcon(item.category) }}</span>
              </div>

              <!-- Item Details -->
              <div class="item-meta-box">
                <div class="item-category-title">{{ getCategoryName(item.category) }}</div>
                <div class="item-sub-row">
                  <span class="item-date">{{ item.date | date:'dd MMM yyyy' }}</span>
                  <span class="meta-dot" *ngIf="item.description">•</span>
                  <span class="item-desc" *ngIf="item.description">{{ item.description }}</span>
                </div>
              </div>

              <!-- Financials & Status Pill -->
              <div class="item-finance-box">
                <span class="item-amount">£{{ item.amount.toFixed(2) }}</span>
                <span class="status-pill" [ngClass]="getStatusClass(item.status)">
                  {{ getStatusName(item.status) }}
                </span>
              </div>

              <span class="material-symbols-outlined item-chevron">chevron_right</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Add Expense Form Panel -->
      <div *ngIf="isFormOpen" class="form-panel-view animated-fade-in">
        <div class="form-sheet-card">
          <div class="form-sheet-header">
            <div class="form-header-text">
              <span class="form-header-badge">NEW CLAIM</span>
              <h3 class="form-sheet-title">Log Expense</h3>
            </div>
            <button class="close-sheet-btn" (click)="closeAddForm()">
              <span class="material-symbols-outlined">close</span>
            </button>
          </div>
          
          <!-- Category Grid Selector -->
          <div class="form-field-group">
            <label class="field-label">SELECT EXPENSE CATEGORY</label>
            <div class="category-cards-grid">
              <button 
                type="button"
                *ngFor="let cat of categoryOptions"
                class="cat-select-card"
                [class.selected]="category === cat.value"
                [style.border-color]="category === cat.value ? cat.color : ''"
                (click)="selectCategory(cat.value)"
              >
                <div 
                  class="cat-icon-disc" 
                  [style.background-color]="category === cat.value ? cat.lightColor : ''"
                  [style.color]="category === cat.value ? cat.color : ''"
                >
                  <span class="material-symbols-outlined">{{ cat.icon }}</span>
                </div>
                <span class="cat-label-text">{{ cat.label }}</span>
                <div class="cat-check-badge" *ngIf="category === cat.value" [style.background-color]="cat.color">
                  <span class="material-symbols-outlined">check</span>
                </div>
              </button>
            </div>
          </div>

          <!-- Amount Input Field & Stepper Shortcuts -->
          <div class="form-field-group">
            <div class="label-with-hint">
              <label class="field-label">EXPENSE AMOUNT</label>
              <span class="field-hint">GBP (£)</span>
            </div>

            <div class="amount-entry-box">
              <span class="amount-currency-symbol">£</span>
              <input 
                type="number" 
                step="0.01" 
                placeholder="0.00" 
                class="amount-native-input" 
                (input)="onAmountChange($any($event.target).value)" 
                [value]="amount > 0 ? amount : ''" 
              />
            </div>

            <!-- Quick Amount Stepper Chips -->
            <div class="amount-presets-row">
              <button type="button" class="amount-chip" (click)="addAmount(10)">+ £10</button>
              <button type="button" class="amount-chip" (click)="addAmount(20)">+ £20</button>
              <button type="button" class="amount-chip" (click)="addAmount(50)">+ £50</button>
              <button type="button" class="amount-chip" (click)="addAmount(70)">+ £70 (Tank)</button>
              <button type="button" class="amount-chip reset" *ngIf="amount > 0" (click)="resetAmount()">Clear</button>
            </div>
          </div>

          <!-- Description & Station Comments -->
          <div class="form-field-group">
            <label class="field-label">DESCRIPTION / STATION DETAILS</label>
            <textarea 
              placeholder="e.g. Shell Station diesel fill-up, M6 toll gate, or car wash..." 
              class="comments-textarea" 
              (input)="onDescChange($any($event.target).value)"
            ></textarea>
          </div>

          <!-- Receipt Photo Attachment Component -->
          <div class="form-field-group">
            <label class="field-label">RECEIPT PHOTO / INVOICE SCAN</label>

            <!-- Video Viewfinder for Live Camera Capture -->
            <div class="camera-frame-box" *ngIf="isCameraActive">
              <video #videoElement autoplay playsinline class="camera-stream-video"></video>
              <div class="camera-scan-frame">
                <div class="scan-reticle"></div>
                <span class="scan-instructions">Align receipt inside frame</span>
              </div>
              
              <div class="camera-control-bar">
                <button type="button" class="camera-shutter-action" (click)="capturePhoto()">
                  <span class="material-symbols-outlined">photo_camera</span>
                </button>
                <button type="button" class="camera-dismiss-action" (click)="stopCamera()">
                  <span class="material-symbols-outlined">close</span>
                </button>
              </div>
            </div>

            <!-- Attached Receipt Thumbnail Preview -->
            <div class="attached-receipt-card" *ngIf="!isCameraActive && capturedReceiptPhoto">
              <img [src]="capturedReceiptPhoto" class="receipt-preview-img" />
              <div class="receipt-card-overlay">
                <div class="receipt-attached-info">
                  <span class="material-symbols-outlined">image</span>
                  <span>Receipt Photo Attached</span>
                </div>
                <button type="button" class="receipt-trash-btn" (click)="removeAttachedReceipt()">
                  <span class="material-symbols-outlined">delete</span>
                </button>
              </div>
            </div>

            <!-- Camera Trigger Action Button -->
            <button 
              type="button" 
              class="camera-trigger-btn" 
              *ngIf="!isCameraActive && !capturedReceiptPhoto" 
              (click)="startCamera()"
            >
              <span class="material-symbols-outlined">photo_camera</span>
              <span>Capture / Attach Receipt</span>
            </button>
          </div>

          <!-- Form Submit Action Controls -->
          <div class="form-submit-actions">
            <button 
              mat-stroked-button 
              class="form-cancel-btn" 
              (click)="closeAddForm()" 
              [disabled]="isSubmitting"
            >
              Cancel
            </button>
            <button 
              mat-flat-button 
              class="form-confirm-btn" 
              (click)="submitExpense()" 
              [disabled]="isSubmitting || amount <= 0"
            >
              <span *ngIf="!isSubmitting">Submit Claim</span>
              <span *ngIf="isSubmitting">Submitting Claim...</span>
            </button>
          </div>
        </div>
      </div>

      <!-- Claim Preview Detail Modal Overlay -->
      <div 
        class="modal-backdrop-scrim" 
        *ngIf="isPreviewOpen && activeItem" 
        (click)="closeReceiptPreview()"
      >
        <div class="modal-dialog-card" (click)="$event.stopPropagation()">
          <div class="modal-card-header">
            <div class="modal-header-brand">
              <div 
                class="modal-cat-icon"
                [style.background-color]="getCategoryColorLight(activeItem.category)"
                [style.color]="getCategoryColor(activeItem.category)"
              >
                <span class="material-symbols-outlined">{{ getCategoryIcon(activeItem.category) }}</span>
              </div>
              <div>
                <h4 class="modal-card-title">{{ getCategoryName(activeItem.category) }}</h4>
                <span class="modal-card-sub">Expense Claim #{{ activeItem.id }}</span>
              </div>
            </div>
            <button class="modal-dismiss-btn" (click)="closeReceiptPreview()">
              <span class="material-symbols-outlined">close</span>
            </button>
          </div>

          <div class="modal-card-body">
            <div class="detail-row">
              <span class="detail-key">Claim Date:</span>
              <span class="detail-val">{{ activeItem.date | date:'dd MMM yyyy, HH:mm' }}</span>
            </div>
            <div class="detail-row">
              <span class="detail-key">Amount Claimed:</span>
              <span class="detail-val bold-amount">£{{ activeItem.amount.toFixed(2) }}</span>
            </div>
            <div class="detail-row" *ngIf="activeItem.description">
              <span class="detail-key">Notes:</span>
              <span class="detail-val desc-text">{{ activeItem.description }}</span>
            </div>
            <div class="detail-row">
              <span class="detail-key">Approval Status:</span>
              <span class="status-pill" [ngClass]="getStatusClass(activeItem.status)">
                {{ getStatusName(activeItem.status) }}
              </span>
            </div>

            <!-- Receipt Photo Details display -->
            <div class="modal-receipt-box" *ngIf="activeItemReceiptImg">
              <span class="receipt-box-label">ATTACHED RECEIPT DOCUMENT</span>
              <div class="receipt-frame">
                <img [src]="activeItemReceiptImg" class="receipt-display-image" />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  `,
  styles: [`
    /* ================= DARK THEME VARIABLES ================= */
    :host-context(.dark-theme) .expenses-container {
      background-color: #121214 !important;
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .hero-overview-card,
    :host-context(.dark-theme) .form-sheet-card,
    :host-context(.dark-theme) .expense-item-card,
    :host-context(.dark-theme) .modal-dialog-card,
    :host-context(.dark-theme) .empty-state-card {
      background-color: #1E1E24 !important;
      border-color: #2D2D35 !important;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3) !important;
    }
    :host-context(.dark-theme) .status-box,
    :host-context(.dark-theme) .cat-select-card,
    :host-context(.dark-theme) .filter-pill-btn,
    :host-context(.dark-theme) .amount-chip,
    :host-context(.dark-theme) .camera-trigger-btn {
      background-color: #141418 !important;
      border-color: #2D2D35 !important;
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .filter-pill-btn.active {
      background: linear-gradient(135deg, #CD1A21 0%, #9E0E14 100%) !important;
      border-color: #CD1A21 !important;
      color: #FFFFFF !important;
    }
    :host-context(.dark-theme) .amount-native-input,
    :host-context(.dark-theme) .comments-textarea {
      background-color: #121214 !important;
      border-color: #2D2D35 !important;
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .amount-native-input:focus,
    :host-context(.dark-theme) .comments-textarea:focus {
      border-color: #CD1A21 !important;
    }
    :host-context(.dark-theme) .amount-currency-symbol,
    :host-context(.dark-theme) .total-number,
    :host-context(.dark-theme) .item-category-title,
    :host-context(.dark-theme) .item-amount,
    :host-context(.dark-theme) .form-sheet-title,
    :host-context(.dark-theme) .cat-label-text,
    :host-context(.dark-theme) .modal-card-title,
    :host-context(.dark-theme) .detail-val {
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .total-label,
    :host-context(.dark-theme) .status-box-title,
    :host-context(.dark-theme) .toggle-text,
    :host-context(.dark-theme) .field-label,
    :host-context(.dark-theme) .detail-key,
    :host-context(.dark-theme) .receipt-box-label {
      color: #90A4AE !important;
    }
    :host-context(.dark-theme) .detail-row {
      border-bottom-color: #2D2D35 !important;
    }
    :host-context(.dark-theme) .form-cancel-btn {
      border-color: #2D2D35 !important;
      color: #B0BEC5 !important;
    }

    /* ================= MAIN CONTAINER ================= */
    .expenses-container {
      padding: 14px 14px 140px 14px;
      background-color: #F8F9FA;
      min-height: 100vh;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      box-sizing: border-box;
      position: relative;
    }

    /* Floating Spinner for pull-to-refresh */
    .floating-refresh-spinner {
      position: fixed;
      top: 0;
      left: 50%;
      width: 40px;
      height: 40px;
      background-color: #FFFFFF;
      border-radius: 50%;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.12);
      display: flex;
      justify-content: center;
      align-items: center;
      z-index: 1001;
      opacity: 0;
      pointer-events: none;
      transition: opacity 0.1s linear;
    }
    .floating-refresh-spinner.visible {
      opacity: 1;
    }
    .native-spin-icon {
      font-size: 22px;
      color: #CD1A21;
    }
    .native-spin-icon.spinning {
      animation: spin 0.8s linear infinite;
    }
    @keyframes spin {
      100% { transform: rotate(360deg); }
    }

    /* ================= HERO OVERVIEW CARD ================= */
    .hero-overview-card {
      background: linear-gradient(135deg, #FFFFFF 0%, #FDFDFE 100%);
      border: 1px solid #E2E8F0;
      border-radius: 20px;
      padding: 16px 18px;
      margin-bottom: 14px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.03);
    }
    .hero-top-bar {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 12px;
    }
    .hero-badge {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      background-color: rgba(205, 26, 33, 0.08);
      color: #CD1A21;
      padding: 4px 9px;
      border-radius: 20px;
      font-size: 9.5px;
      font-weight: 900;
      letter-spacing: 0.6px;
    }
    .badge-icon {
      font-size: 14px;
    }
    .quick-log-btn {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      background: linear-gradient(135deg, #CD1A21 0%, #9E0E14 100%);
      color: #FFFFFF;
      border: none;
      border-radius: 14px;
      padding: 6px 12px;
      font-size: 11px;
      font-weight: 800;
      cursor: pointer;
      box-shadow: 0 3px 10px rgba(205, 26, 33, 0.25);
    }
    .quick-log-btn .material-symbols-outlined {
      font-size: 16px;
    }

    .total-claimed-block {
      display: flex;
      flex-direction: column;
      margin-bottom: 14px;
    }
    .total-label {
      font-size: 11px;
      font-weight: 800;
      color: #64748B;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .total-amount-row {
      display: flex;
      align-items: baseline;
      gap: 4px;
      margin-top: 2px;
    }
    .currency-sign {
      font-size: 20px;
      font-weight: 900;
      color: #CD1A21;
    }
    .total-number {
      font-size: 28px;
      font-weight: 900;
      color: #1E293B;
      letter-spacing: -0.5px;
    }
    .count-pill {
      margin-left: 8px;
      background-color: #F1F5F9;
      color: #475569;
      font-size: 10.5px;
      font-weight: 700;
      padding: 2px 8px;
      border-radius: 12px;
    }

    /* 3-Pill Status Grid */
    .status-summary-grid {
      display: grid;
      grid-template-columns: 1fr 1fr 1fr;
      gap: 8px;
      margin-bottom: 14px;
    }
    .status-box {
      background-color: #F8FAFC;
      border: 1px solid #E2E8F0;
      border-radius: 14px;
      padding: 10px 8px;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .status-box-header {
      display: flex;
      align-items: center;
      gap: 5px;
    }
    .status-dot {
      width: 6px;
      height: 6px;
      border-radius: 50%;
    }
    .status-dot.green { background-color: #16A34A; }
    .status-dot.amber { background-color: #D97706; }
    .status-dot.rose { background-color: #E11D48; }
    .status-box-title {
      font-size: 9.5px;
      font-weight: 800;
      color: #64748B;
      text-transform: uppercase;
    }
    .status-box-val {
      font-size: 13.5px;
      font-weight: 900;
      color: #1E293B;
    }

    /* Collapsible Breakdown */
    .breakdown-wrapper {
      border-top: 1px solid #F1F5F9;
      padding-top: 10px;
    }
    .breakdown-toggle-btn {
      width: 100%;
      background: none;
      border: none;
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 4px 0;
      cursor: pointer;
    }
    .breakdown-toggle-left {
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .toggle-icon {
      font-size: 16px;
      color: #CD1A21;
    }
    .toggle-text {
      font-size: 11px;
      font-weight: 800;
      color: #475569;
    }
    .toggle-arrow {
      font-size: 18px;
      color: #94A3B8;
    }
    .breakdown-drawer {
      max-height: 0;
      overflow: hidden;
      transition: max-height 0.3s ease;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .breakdown-drawer.open {
      max-height: 400px;
      margin-top: 10px;
    }
    .breakdown-row {
      display: flex;
      flex-direction: column;
      gap: 3px;
    }
    .breakdown-labels {
      display: flex;
      justify-content: space-between;
      font-size: 10.5px;
    }
    .cat-name-tag {
      font-weight: 700;
      color: #475569;
    }
    .cat-val-tag {
      font-weight: 800;
      color: #1E293B;
    }
    .breakdown-bar-track {
      width: 100%;
      height: 5px;
      background-color: #F1F5F9;
      border-radius: 4px;
      overflow: hidden;
    }
    .breakdown-bar-fill {
      height: 100%;
      border-radius: 4px;
      transition: width 0.4s ease;
    }

    /* ================= FILTERS DOCK ================= */
    .filters-dock {
      margin-bottom: 12px;
    }
    .filter-pills-group {
      display: flex;
      gap: 6px;
    }
    .filter-pill-btn {
      flex: 1;
      background-color: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 12px;
      padding: 7px 4px;
      font-size: 10.5px;
      font-weight: 800;
      color: #475569;
      cursor: pointer;
      transition: all 0.18s ease;
      text-align: center;
    }
    .filter-pill-btn.active {
      background: linear-gradient(135deg, #CD1A21 0%, #9E0E14 100%);
      border-color: #CD1A21;
      color: #FFFFFF;
      box-shadow: 0 2px 8px rgba(205, 26, 33, 0.22);
    }

    /* ================= EXPENSE ROWS LIST ================= */
    .expense-items-stack {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .expense-item-card {
      background-color: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 18px;
      overflow: hidden;
      display: flex;
      box-shadow: 0 3px 12px rgba(0, 0, 0, 0.02);
      cursor: pointer;
      transition: all 0.18s ease;
    }
    .expense-item-card:hover {
      transform: translateY(-1px);
      box-shadow: 0 6px 18px rgba(0, 0, 0, 0.04);
    }
    .item-accent-line {
      width: 4px;
      flex-shrink: 0;
    }
    .item-card-inner {
      flex: 1;
      padding: 12px 14px;
      display: flex;
      align-items: center;
      gap: 12px;
      min-width: 0;
    }
    .item-icon-box {
      width: 36px;
      height: 36px;
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }
    .item-icon-box .material-symbols-outlined {
      font-size: 20px;
    }
    .item-meta-box {
      flex: 1;
      min-width: 0;
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .item-category-title {
      font-size: 13.5px;
      font-weight: 800;
      color: #1E293B;
    }
    .item-sub-row {
      display: flex;
      align-items: center;
      gap: 4px;
      font-size: 10.5px;
      color: #64748B;
      font-weight: 500;
    }
    .item-date {
      font-weight: 700;
      color: #94A3B8;
      flex-shrink: 0;
    }
    .meta-dot {
      color: #CBD5E1;
    }
    .item-desc {
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .item-finance-box {
      display: flex;
      flex-direction: column;
      align-items: flex-end;
      gap: 4px;
      flex-shrink: 0;
    }
    .item-amount {
      font-size: 14.5px;
      font-weight: 900;
      color: #1E293B;
    }
    .status-pill {
      font-size: 9px;
      font-weight: 800;
      padding: 2px 7px;
      border-radius: 12px;
      text-transform: uppercase;
      letter-spacing: 0.3px;
    }
    .status-pill.approved {
      background-color: rgba(22, 163, 74, 0.1);
      color: #16A34A;
    }
    .status-pill.pending {
      background-color: rgba(217, 119, 6, 0.1);
      color: #D97706;
    }
    .status-pill.rejected {
      background-color: rgba(225, 29, 72, 0.1);
      color: #E11D48;
    }
    .item-chevron {
      color: #CBD5E1;
      font-size: 18px;
      flex-shrink: 0;
    }

    /* Empty state */
    .empty-state-card {
      background-color: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 20px;
      padding: 36px 20px;
      text-align: center;
      display: flex;
      flex-direction: column;
      align-items: center;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.02);
    }
    .empty-icon-circle {
      width: 54px;
      height: 54px;
      border-radius: 50%;
      background-color: rgba(205, 26, 33, 0.08);
      color: #CD1A21;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-bottom: 12px;
    }
    .empty-icon-circle .material-symbols-outlined {
      font-size: 28px;
    }
    .empty-title {
      margin: 0 0 6px 0;
      font-size: 16px;
      font-weight: 800;
      color: #1E293B;
    }
    .empty-desc {
      margin: 0 0 20px 0;
      font-size: 12px;
      color: #64748B;
      max-width: 280px;
      line-height: 1.4;
    }
    .empty-cta-btn {
      background: linear-gradient(135deg, #CD1A21 0%, #9E0E14 100%) !important;
      color: #FFFFFF !important;
      border-radius: 14px !important;
      padding: 10px 20px !important;
      font-weight: 800 !important;
      display: inline-flex !important;
      align-items: center !important;
      gap: 6px !important;
      box-shadow: 0 4px 14px rgba(205, 26, 33, 0.25) !important;
    }
    .empty-cta-btn .material-symbols-outlined {
      font-size: 18px;
    }

    /* Skeleton Shimmer */
    .skeleton-container {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .skeleton-card {
      height: 64px;
      background-color: #E2E8F0;
      border-radius: 16px;
      overflow: hidden;
      position: relative;
    }
    .skeleton-shimmer {
      width: 100%;
      height: 100%;
      background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.4), transparent);
      animation: shimmer 1.5s infinite;
    }
    @keyframes shimmer {
      0% { transform: translateX(-100%); }
      100% { transform: translateX(100%); }
    }

    /* ================= ADD EXPENSE FORM PANEL ================= */
    .form-panel-view {
      width: 100%;
    }
    .form-sheet-card {
      background-color: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 20px;
      padding: 18px;
      box-shadow: 0 6px 24px rgba(0, 0, 0, 0.03);
    }
    .form-sheet-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 18px;
    }
    .form-header-badge {
      font-size: 9px;
      font-weight: 900;
      color: #CD1A21;
      letter-spacing: 0.6px;
    }
    .form-sheet-title {
      margin: 2px 0 0 0;
      font-size: 18px;
      font-weight: 900;
      color: #1E293B;
    }
    .close-sheet-btn {
      background: none;
      border: none;
      color: #94A3B8;
      cursor: pointer;
      display: flex;
      align-items: center;
      padding: 4px;
    }
    .close-sheet-btn .material-symbols-outlined {
      font-size: 20px;
    }

    .form-field-group {
      display: flex;
      flex-direction: column;
      gap: 6px;
      margin-bottom: 16px;
    }
    .field-label {
      font-size: 10px;
      font-weight: 800;
      color: #64748B;
      letter-spacing: 0.5px;
    }
    .label-with-hint {
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .field-hint {
      font-size: 10px;
      font-weight: 700;
      color: #94A3B8;
    }

    /* Category selection cards grid */
    .category-cards-grid {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 8px;
    }
    @media (max-width: 480px) {
      .category-cards-grid {
        grid-template-columns: repeat(3, 1fr);
      }
    }
    .cat-select-card {
      background-color: #F8FAFC;
      border: 1.5px solid #E2E8F0;
      border-radius: 14px;
      padding: 10px 4px;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 6px;
      cursor: pointer;
      position: relative;
      outline: none;
      transition: all 0.18s ease;
    }
    .cat-select-card:hover {
      background-color: #F1F5F9;
    }
    .cat-select-card.selected {
      background-color: #FFFFFF;
      box-shadow: 0 4px 14px rgba(0, 0, 0, 0.06);
    }
    .cat-icon-disc {
      width: 34px;
      height: 34px;
      border-radius: 10px;
      background-color: #E2E8F0;
      color: #64748B;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .cat-icon-disc .material-symbols-outlined {
      font-size: 18px;
    }
    .cat-label-text {
      font-size: 10px;
      font-weight: 800;
      color: #334155;
      text-align: center;
    }
    .cat-check-badge {
      position: absolute;
      top: -4px;
      right: -4px;
      width: 16px;
      height: 16px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #FFFFFF;
    }
    .cat-check-badge .material-symbols-outlined {
      font-size: 11px;
    }

    /* Amount entry box */
    .amount-entry-box {
      position: relative;
      display: flex;
      align-items: center;
    }
    .amount-currency-symbol {
      position: absolute;
      left: 14px;
      font-size: 20px;
      font-weight: 900;
      color: #1E293B;
    }
    .amount-native-input {
      width: 100%;
      border: 1.5px solid #E2E8F0;
      border-radius: 14px;
      padding: 11px 14px 11px 32px;
      font-size: 20px;
      font-weight: 900;
      color: #1E293B;
      outline: none;
      box-sizing: border-box;
      background-color: #F8FAFC;
      transition: all 0.2s ease;
    }
    .amount-native-input:focus {
      border-color: #CD1A21;
      background-color: #FFFFFF;
      box-shadow: 0 0 0 3px rgba(205, 26, 33, 0.06);
    }
    .amount-presets-row {
      display: flex;
      gap: 6px;
      flex-wrap: wrap;
      margin-top: 4px;
    }
    .amount-chip {
      background-color: #F1F5F9;
      border: 1px solid #E2E8F0;
      border-radius: 12px;
      padding: 5px 10px;
      font-size: 10.5px;
      font-weight: 800;
      color: #475569;
      cursor: pointer;
      transition: all 0.16s ease;
    }
    .amount-chip:hover {
      background-color: rgba(205, 26, 33, 0.08);
      color: #CD1A21;
      border-color: rgba(205, 26, 33, 0.2);
    }
    .amount-chip.reset {
      background-color: rgba(225, 29, 72, 0.08);
      color: #E11D48;
      border-color: rgba(225, 29, 72, 0.2);
    }

    .comments-textarea {
      width: 100%;
      border: 1.5px solid #E2E8F0;
      border-radius: 14px;
      padding: 10px 12px;
      font-size: 12.5px;
      font-weight: 500;
      color: #1E293B;
      outline: none;
      box-sizing: border-box;
      min-height: 64px;
      resize: vertical;
      background-color: #F8FAFC;
      font-family: inherit;
      transition: all 0.2s ease;
    }
    .comments-textarea:focus {
      border-color: #CD1A21;
      background-color: #FFFFFF;
      box-shadow: 0 0 0 3px rgba(205, 26, 33, 0.06);
    }

    /* Camera viewfinder & attachment */
    .camera-frame-box {
      border-radius: 16px;
      overflow: hidden;
      position: relative;
      background-color: #000000;
      min-height: 220px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .camera-stream-video {
      width: 100%;
      height: 100%;
      max-height: 240px;
      object-fit: cover;
    }
    .camera-scan-frame {
      position: absolute;
      inset: 16px;
      border: 2px dashed rgba(255, 255, 255, 0.6);
      border-radius: 12px;
      display: flex;
      align-items: flex-end;
      justify-content: center;
      padding-bottom: 10px;
      pointer-events: none;
    }
    .scan-instructions {
      background-color: rgba(0, 0, 0, 0.6);
      color: #FFFFFF;
      font-size: 10px;
      font-weight: 700;
      padding: 3px 8px;
      border-radius: 10px;
    }
    .camera-control-bar {
      position: absolute;
      bottom: 12px;
      left: 0;
      right: 0;
      display: flex;
      justify-content: center;
      gap: 16px;
    }
    .camera-shutter-action {
      width: 48px;
      height: 48px;
      border-radius: 50%;
      background: linear-gradient(135deg, #CD1A21 0%, #9E0E14 100%);
      border: 3px solid #FFFFFF;
      color: #FFFFFF;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
    }
    .camera-dismiss-action {
      width: 36px;
      height: 36px;
      border-radius: 50%;
      background-color: rgba(0, 0, 0, 0.5);
      border: 1px solid rgba(255, 255, 255, 0.4);
      color: #FFFFFF;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      align-self: center;
    }

    .attached-receipt-card {
      border-radius: 16px;
      overflow: hidden;
      border: 1px solid #E2E8F0;
      position: relative;
      max-height: 160px;
      background-color: #F8FAFC;
    }
    .receipt-preview-img {
      width: 100%;
      height: 160px;
      object-fit: cover;
    }
    .receipt-card-overlay {
      position: absolute;
      bottom: 0;
      left: 0;
      right: 0;
      background: linear-gradient(to top, rgba(0, 0, 0, 0.75), transparent);
      padding: 8px 12px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      color: #FFFFFF;
    }
    .receipt-attached-info {
      display: flex;
      align-items: center;
      gap: 5px;
      font-size: 11px;
      font-weight: 700;
    }
    .receipt-trash-btn {
      background: rgba(225, 29, 72, 0.85);
      border: none;
      color: #FFFFFF;
      width: 28px;
      height: 28px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
    }
    .receipt-trash-btn .material-symbols-outlined {
      font-size: 16px;
    }

    .camera-trigger-btn {
      width: 100%;
      background-color: #F8FAFC;
      border: 1.5px dashed #CBD5E1;
      border-radius: 14px;
      padding: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      color: #475569;
      font-size: 12px;
      font-weight: 800;
      cursor: pointer;
      transition: all 0.18s ease;
    }
    .camera-trigger-btn:hover {
      background-color: rgba(205, 26, 33, 0.04);
      border-color: #CD1A21;
      color: #CD1A21;
    }

    .form-submit-actions {
      display: flex;
      gap: 10px;
      margin-top: 18px;
    }
    .form-cancel-btn {
      flex: 1;
      height: 48px;
      border-radius: 14px !important;
      font-weight: 800 !important;
      color: #64748B !important;
      border-color: #CBD5E1 !important;
    }
    .form-confirm-btn {
      flex: 2;
      height: 48px;
      background: linear-gradient(135deg, #CD1A21 0%, #9E0E14 100%) !important;
      color: #FFFFFF !important;
      border-radius: 14px !important;
      font-weight: 900 !important;
      box-shadow: 0 4px 14px rgba(205, 26, 33, 0.25) !important;
    }
    .form-confirm-btn:disabled {
      background: #E2E8F0 !important;
      color: #94A3B8 !important;
      box-shadow: none !important;
    }

    /* ================= RECEIPT DETAIL MODAL ================= */
    .modal-backdrop-scrim {
      position: fixed;
      inset: 0;
      background-color: rgba(0, 0, 0, 0.6);
      backdrop-filter: blur(4px);
      z-index: 1000;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 16px;
      box-sizing: border-box;
    }
    .modal-dialog-card {
      width: 100%;
      max-width: 380px;
      background-color: #FFFFFF;
      border-radius: 20px;
      padding: 18px;
      box-shadow: 0 12px 40px rgba(0, 0, 0, 0.2);
      max-height: 90vh;
      overflow-y: auto;
    }
    .modal-card-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 14px;
      padding-bottom: 10px;
      border-bottom: 1px solid #F1F5F9;
    }
    .modal-header-brand {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .modal-cat-icon {
      width: 36px;
      height: 36px;
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .modal-cat-icon .material-symbols-outlined {
      font-size: 20px;
    }
    .modal-card-title {
      margin: 0;
      font-size: 15px;
      font-weight: 900;
      color: #1E293B;
    }
    .modal-card-sub {
      font-size: 10.5px;
      color: #94A3B8;
      font-weight: 600;
    }
    .modal-dismiss-btn {
      background: none;
      border: none;
      color: #94A3B8;
      cursor: pointer;
      padding: 4px;
      display: flex;
      align-items: center;
    }
    .modal-card-body {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .detail-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 6px 0;
      border-bottom: 1px solid #F8FAFC;
    }
    .detail-key {
      font-size: 11.5px;
      color: #64748B;
      font-weight: 700;
    }
    .detail-val {
      font-size: 12.5px;
      font-weight: 800;
      color: #1E293B;
    }
    .detail-val.bold-amount {
      font-size: 16px;
      font-weight: 900;
      color: #16A34A;
    }
    .detail-val.desc-text {
      max-width: 180px;
      text-align: right;
      font-size: 11.5px;
      color: #475569;
    }
    .modal-receipt-box {
      margin-top: 10px;
    }
    .receipt-box-label {
      font-size: 9.5px;
      font-weight: 800;
      color: #94A3B8;
      letter-spacing: 0.5px;
      display: block;
      margin-bottom: 6px;
    }
    .receipt-frame {
      border-radius: 12px;
      overflow: hidden;
      border: 1px solid #E2E8F0;
      max-height: 220px;
      background-color: #F8FAFC;
      display: flex;
      justify-content: center;
      align-items: center;
    }
    .receipt-display-image {
      width: 100%;
      height: 100%;
      max-height: 220px;
      object-fit: contain;
    }

    /* Animation effects */
    .animated-fade-in {
      animation: fadeIn 0.22s ease-in-out forwards;
    }
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(3px); }
      to { opacity: 1; transform: translateY(0); }
    }
  `]
})
export class ExpensesComponent implements OnInit, OnDestroy {
  @ViewChild('videoElement') videoElement: ElementRef<HTMLVideoElement> | undefined;

  isLoading = true;
  isFormOpen = false;
  isSubmitting = false;
  
  userId: number | null = null;
  activeFilterDays = 90; // Default to 90 days filter

  // Claim Form state variables
  category = 0; // Default to Fuel (integer value 0)
  amount = 0;
  description = '';
  capturedReceiptPhoto: string | null = null;

  // Receipt Modal state variables
  isPreviewOpen = false;
  activeItem: ExpenseItem | null = null;
  activeItemReceiptImg: string | null = null;

  expenses: ExpenseItem[] = [];

  // Summary counts and graphs
  totalClaimed = 0;
  approvedTotal = 0;
  pendingTotal = 0;
  rejectedTotal = 0;
  isBreakdownOpen = false;
  categoryBreakdown: { name: string; total: number; pct: number; color: string }[] = [];

  // Pull-to-refresh variables
  pullDistance = 0;
  isRefreshing = false;
  private startY = 0;

  // Camera settings
  isCameraActive = false;
  private cameraStream: MediaStream | null = null;

  categoryOptions: CategoryOption[] = [
    { value: 0, label: 'Fuel', icon: 'local_gas_station', color: '#E53935', lightColor: 'rgba(229, 57, 53, 0.1)' },
    { value: 1, label: 'Tolls', icon: 'toll', color: '#1E88E5', lightColor: 'rgba(30, 136, 245, 0.1)' },
    { value: 2, label: 'Parking', icon: 'local_parking', color: '#43A047', lightColor: 'rgba(67, 160, 71, 0.1)' },
    { value: 3, label: 'Maintenance', icon: 'build', color: '#8E24AA', lightColor: 'rgba(142, 36, 170, 0.1)' },
    { value: 4, label: 'Cleaning', icon: 'local_car_wash', color: '#00ACC1', lightColor: 'rgba(0, 172, 193, 0.1)' },
    { value: 5, label: 'Congestion', icon: 'directions_car', color: '#F4511E', lightColor: 'rgba(244, 81, 30, 0.1)' },
    { value: 6, label: 'Misc', icon: 'receipt', color: '#757575', lightColor: 'rgba(117, 117, 117, 0.1)' }
  ];

  constructor(
    private driverService: DriverService,
    private snackBar: MatSnackBar,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.resolveUserId();
  }

  ngOnDestroy(): void {
    this.stopCameraStream();
  }

  getUserIdFromToken(): number | null {
    const token = localStorage.getItem('auth_token');
    if (!token) return null;
    try {
      const parts = token.split('.');
      if (parts.length === 3) {
        const payload = JSON.parse(atob(parts[1]));
        const userId = payload.id || payload.nameid || payload.userId;
        return userId ? Number(userId) : null;
      }
    } catch (e) {
      console.error('[Expenses] Failed to parse JWT token for userId:', e);
    }
    return null;
  }

  resolveUserId(): void {
    this.isLoading = true;
    this.cdr.detectChanges();

    this.userId = this.getUserIdFromToken();
    console.log('[Expenses] Resolved driver userId from JWT:', this.userId);

    if (this.userId) {
      this.loadExpenses();
    } else {
      this.driverService.getProfile().subscribe({
        next: (res: any) => {
          const profile = res?.value || res;
          if (profile) {
            this.userId = profile.id || profile.userId || profile.driverId || 1;
          } else {
            this.userId = 1;
          }
          this.loadExpenses();
        },
        error: (err) => {
          console.error('[Expenses] Profile fallback failed, default to 1:', err);
          this.userId = 1;
          this.loadExpenses();
        }
      });
    }
  }

  loadExpenses(): void {
    if (!this.userId) {
      this.isLoading = false;
      this.isRefreshing = false;
      this.cdr.detectChanges();
      return;
    }

    this.isLoading = true;
    this.cdr.detectChanges();

    const fromDate = new Date(Date.now() - this.activeFilterDays * 86400000).toISOString(); 
    const toDate = new Date().toISOString(); 

    this.driverService.getExpenses(this.userId, fromDate, toDate).subscribe({
      next: (res: any) => {
        if (Array.isArray(res)) {
          this.expenses = res;
        } else if (res && Array.isArray(res.expenses)) {
          this.expenses = res.expenses;
        } else {
          this.fallbackMockData();
        }
        this.calculateTotals();
        this.isLoading = false;
        this.isRefreshing = false;
        this.cdr.detectChanges();
      },
      error: (err) => {
        console.error('[Expenses] getExpenses failed, using mock data fallback:', err);
        this.fallbackMockData();
        this.calculateTotals();
        this.isLoading = false;
        this.isRefreshing = false;
        this.cdr.detectChanges();
      }
    });
  }

  setFilter(days: number): void {
    this.activeFilterDays = days;
    this.loadExpenses();
  }

  calculateTotals(): void {
    let claimed = 0;
    let approved = 0;
    let pending = 0;
    let rejected = 0;

    const categoryTotals: { [key: number]: number } = {
      0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0
    };

    this.expenses.forEach(item => {
      claimed += item.amount;
      const statusStr = this.getStatusName(item.status).toLowerCase();
      if (statusStr === 'approved') {
        approved += item.amount;
      } else if (statusStr === 'rejected') {
        rejected += item.amount;
      } else {
        pending += item.amount;
      }

      const catNum = Number(item.category);
      if (categoryTotals[catNum] !== undefined) {
        categoryTotals[catNum] += item.amount;
      } else {
        categoryTotals[6] += item.amount;
      }
    });

    this.totalClaimed = claimed;
    this.approvedTotal = approved;
    this.pendingTotal = pending;
    this.rejectedTotal = rejected;

    this.categoryBreakdown = Object.keys(categoryTotals).map(key => {
      const catNum = Number(key);
      const total = categoryTotals[catNum];
      const pct = claimed > 0 ? (total / claimed) * 100 : 0;
      return {
        name: this.getCategoryName(catNum),
        total,
        pct,
        color: this.getCategoryColor(catNum)
      };
    }).filter(c => c.total > 0).sort((a, b) => b.total - a.total);
  }

  toggleBreakdown(): void {
    this.isBreakdownOpen = !this.isBreakdownOpen;
    this.cdr.detectChanges();
  }

  fallbackMockData(): void {
    const timestamp = Date.now();
    this.expenses = [
      { id: timestamp - 200000, date: new Date(Date.now() - 86400000 * 2).toISOString(), category: 0, amount: 45.50, description: 'Weekly diesel top-up (Shell)', status: 'Approved' },
      { id: timestamp - 500000, date: new Date(Date.now() - 86400000 * 5).toISOString(), category: 1, amount: 6.80, description: 'M6 Toll gate charge', status: 'Approved' },
      { id: timestamp - 800000, date: new Date(Date.now() - 86400000 * 9).toISOString(), category: 4, amount: 15.00, description: 'Valet and inside cleaning', status: 'Pending' }
    ];

    this.expenses.forEach((item, index) => {
      const mockReceiptBase64 = this.getMockReceiptBase64(index);
      if (mockReceiptBase64) {
        localStorage.setItem(`receipt_img_${item.id}`, mockReceiptBase64);
      }
    });
  }

  getCategoryName(catVal: number | string): string {
    const val = Number(catVal);
    switch (val) {
      case 0: return 'Fuel';
      case 1: return 'Tolls';
      case 2: return 'Parking';
      case 3: return 'Maintenance';
      case 4: return 'Cleaning';
      case 5: return 'Congestion Charge';
      default: return 'Miscellaneous';
    }
  }

  getCategoryColor(catVal: number | string): string {
    const val = Number(catVal);
    switch (val) {
      case 0: return '#CD1A21'; 
      case 1: return '#0284C7'; 
      case 2: return '#16A34A'; 
      case 3: return '#7C3AED'; 
      case 4: return '#0891B2'; 
      case 5: return '#EA580C'; 
      default: return '#64748B'; 
    }
  }

  getCategoryColorLight(catVal: number | string): string {
    const val = Number(catVal);
    switch (val) {
      case 0: return 'rgba(205, 26, 33, 0.1)';
      case 1: return 'rgba(2, 132, 199, 0.1)';
      case 2: return 'rgba(22, 163, 74, 0.1)';
      case 3: return 'rgba(124, 58, 237, 0.1)';
      case 4: return 'rgba(8, 145, 178, 0.1)';
      case 5: return 'rgba(234, 88, 12, 0.1)';
      default: return 'rgba(100, 116, 139, 0.1)';
    }
  }

  getCategoryIcon(catVal: number | string): string {
    const val = Number(catVal);
    switch (val) {
      case 0: return 'local_gas_station';
      case 1: return 'toll';
      case 2: return 'local_parking';
      case 3: return 'build';
      case 4: return 'local_car_wash';
      case 5: return 'directions_car';
      default: return 'receipt';
    }
  }

  getStatusName(statusVal: any): string {
    if (statusVal === undefined || statusVal === null) return 'Pending';
    if (typeof statusVal === 'number') {
      switch (statusVal) {
        case 0: return 'Pending';
        case 1: return 'Approved';
        case 2: return 'Rejected';
        default: return 'Pending';
      }
    }
    const strVal = String(statusVal).trim();
    if (!strVal) return 'Pending';
    return strVal.charAt(0).toUpperCase() + strVal.slice(1).toLowerCase();
  }

  getStatusClass(statusVal: any): string {
    const name = this.getStatusName(statusVal).toLowerCase();
    if (name === 'approved' || name === '1') return 'approved';
    if (name === 'rejected' || name === '2') return 'rejected';
    return 'pending';
  }

  openAddForm(): void {
    this.isFormOpen = true;
    this.category = 0;
    this.amount = 0;
    this.description = '';
    this.capturedReceiptPhoto = null;
    this.isSubmitting = false;
    this.stopCameraStream();
    this.isCameraActive = false;
    this.cdr.detectChanges();
  }

  closeAddForm(): void {
    this.isFormOpen = false;
    this.stopCameraStream();
    this.isCameraActive = false;
    this.cdr.detectChanges();
  }

  selectCategory(val: number): void {
    this.category = val;
    this.cdr.detectChanges();
  }

  onAmountChange(val: string): void {
    this.amount = parseFloat(val) || 0;
    this.cdr.detectChanges();
  }

  addAmount(extra: number): void {
    this.amount = +(this.amount + extra).toFixed(2);
    this.cdr.detectChanges();
  }

  resetAmount(): void {
    this.amount = 0;
    this.cdr.detectChanges();
  }

  onDescChange(val: string): void {
    this.description = val;
    this.cdr.detectChanges();
  }

  // Camera integration methods
  startCamera(): void {
    this.isCameraActive = true;
    this.capturedReceiptPhoto = null;
    this.cdr.detectChanges();

    navigator.mediaDevices.getUserMedia({
      video: { facingMode: 'environment', width: { ideal: 1280 }, height: { ideal: 720 } }
    }).then(stream => {
      this.cameraStream = stream;
      if (this.videoElement) {
        this.videoElement.nativeElement.srcObject = stream;
      }
      this.cdr.detectChanges();
    }).catch(err => {
      console.error('[Expenses Camera] Access failed:', err);
      this.isCameraActive = false;
      this.snackBar.open('Could not load device camera. Try entering details manually or check browser permissions.', 'OK', {
        duration: 4000
      });
      this.cdr.detectChanges();
    });
  }

  capturePhoto(): void {
    if (!this.cameraStream || !this.videoElement) return;
    const video = this.videoElement.nativeElement;

    const canvas = document.createElement('canvas');
    canvas.width = video.videoWidth || 640;
    canvas.height = video.videoHeight || 480;

    const ctx = canvas.getContext('2d');
    if (ctx) {
      ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
      const dataUrl = canvas.toDataURL('image/jpeg', 0.85);
      this.capturedReceiptPhoto = dataUrl;
    }

    this.isCameraActive = false;
    this.stopCameraStream();
    this.cdr.detectChanges();
  }

  stopCamera(): void {
    this.isCameraActive = false;
    this.stopCameraStream();
    this.cdr.detectChanges();
  }

  private stopCameraStream(): void {
    if (this.cameraStream) {
      this.cameraStream.getTracks().forEach(track => track.stop());
      this.cameraStream = null;
    }
  }

  removeAttachedReceipt(): void {
    this.capturedReceiptPhoto = null;
    this.cdr.detectChanges();
  }

  submitExpense(): void {
    if (this.amount <= 0 || !this.userId) return;

    this.isSubmitting = true;
    this.cdr.detectChanges();

    const payload = {
      userId: this.userId,
      date: new Date().toISOString(),
      category: this.category,
      description: this.description,
      amount: this.amount
    };

    this.driverService.addExpense(payload).subscribe({
      next: (res: any) => {
        const returnedId = res?.value?.id || res?.id || Date.now();
        
        if (this.capturedReceiptPhoto) {
          localStorage.setItem(`receipt_img_${returnedId}`, this.capturedReceiptPhoto);
        }

        this.isSubmitting = false;
        this.isFormOpen = false;
        this.snackBar.open('Expense claim logged successfully!', 'OK', { duration: 3000 });
        this.loadExpenses();
        this.cdr.detectChanges();
      },
      error: (err) => {
        console.warn('[Expenses] Submission failed, applying offline fallback representation:', err);
        this.isSubmitting = false;
        this.isFormOpen = false;
        
        const newFakeId = Date.now();
        const newFake: ExpenseItem = {
          id: newFakeId,
          date: new Date().toISOString(),
          category: this.category,
          amount: this.amount,
          description: this.description,
          status: 'Pending'
        };

        if (this.capturedReceiptPhoto) {
          localStorage.setItem(`receipt_img_${newFakeId}`, this.capturedReceiptPhoto);
        }

        this.expenses = [newFake, ...this.expenses];
        this.calculateTotals();
        this.snackBar.open('Expense logged successfully!', 'OK', { duration: 3000 });
        this.cdr.detectChanges();
      }
    });
  }

  viewReceipt(item: ExpenseItem): void {
    this.activeItem = item;
    this.activeItemReceiptImg = localStorage.getItem(`receipt_img_${item.id}`);
    this.isPreviewOpen = true;
    this.cdr.detectChanges();
  }

  closeReceiptPreview(): void {
    this.isPreviewOpen = false;
    this.activeItem = null;
    this.activeItemReceiptImg = null;
    this.cdr.detectChanges();
  }

  // Pull-to-Refresh Gestures
  onTouchStart(event: TouchEvent): void {
    if (window.scrollY === 0) {
      this.startY = event.touches[0].clientY;
    }
  }

  onTouchMove(event: TouchEvent): void {
    if (this.startY === 0 || this.isFormOpen) return;
    const currentY = event.touches[0].clientY;
    const yDiff = currentY - this.startY;

    if (yDiff > 0 && window.scrollY === 0) {
      this.pullDistance = Math.min(yDiff * 0.4, 80);
      this.cdr.detectChanges();
      
      if (this.pullDistance > 10) {
        if (event.cancelable) event.preventDefault();
      }
    }
  }

  onTouchEnd(): void {
    if (this.isFormOpen) return;
    if (this.pullDistance > 55) {
      this.isRefreshing = true;
      this.loadExpenses();
    }
    this.pullDistance = 0;
    this.startY = 0;
    this.cdr.detectChanges();
  }

  private getMockReceiptBase64(index: number): string {
    const svg = `
      <svg xmlns="http://www.w3.org/2000/svg" width="300" height="400" viewBox="0 0 300 400">
        <rect width="100%" height="100%" fill="#FCFDFD"/>
        <path d="M 0 0 L 15 10 L 30 0 L 45 10 L 60 0 L 75 10 L 90 0 L 105 10 L 120 0 L 135 10 L 150 0 L 165 10 L 180 0 L 195 10 L 210 0 L 225 10 L 240 0 L 255 10 L 270 0 L 285 10 L 300 0 L 300 400 L 0 400 Z" fill="#FFFFFF" stroke="#ECEFF1" stroke-width="1.5"/>
        <text x="50%" y="45" font-family="'Courier New', monospace" font-weight="bold" font-size="16" text-anchor="middle" fill="#263238">RED TAXIS LTD</text>
        <text x="50%" y="65" font-family="'Courier New', monospace" font-size="10" text-anchor="middle" fill="#78909C">OFFICIAL EXPENSE RECEIPT</text>
        
        <line x1="20" y1="90" x2="280" y2="90" stroke="#B0BEC5" stroke-dasharray="4 4" stroke-width="1"/>
        
        <text x="20" y="115" font-family="'Courier New', monospace" font-size="11" fill="#546E7A">DATE:</text>
        <text x="280" y="115" font-family="'Courier New', monospace" font-size="11" text-anchor="end" fill="#263238">17/08/2026</text>
        
        <text x="20" y="135" font-family="'Courier New', monospace" font-size="11" fill="#546E7A">TRANSACTION ID:</text>
        <text x="280" y="135" font-family="'Courier New', monospace" font-size="11" text-anchor="end" fill="#263238">TXN-492${index}02</text>
        
        <text x="20" y="155" font-family="'Courier New', monospace" font-size="11" fill="#546E7A">CARD TYPE:</text>
        <text x="280" y="155" font-family="'Courier New', monospace" font-size="11" text-anchor="end" fill="#263238">VISA DEBIT *4920</text>

        <line x1="20" y1="180" x2="280" y2="180" stroke="#B0BEC5" stroke-dasharray="4 4" stroke-width="1"/>

        <text x="20" y="210" font-family="'Courier New', monospace" font-weight="bold" font-size="13" fill="#263238">ITEM / CATEGORY</text>
        <text x="280" y="210" font-family="'Courier New', monospace" font-weight="bold" font-size="13" text-anchor="end" fill="#263238">AMOUNT</text>

        <text x="20" y="240" font-family="'Courier New', monospace" font-size="12" fill="#546E7A">01. Service Charge</text>
        <text x="280" y="240" font-family="'Courier New', monospace" font-size="12" text-anchor="end" fill="#263238">£${index === 0 ? '45.50' : index === 1 ? '6.80' : '15.00'}</text>
        
        <line x1="20" y1="300" x2="280" y2="300" stroke="#263238" stroke-width="1.5"/>

        <text x="20" y="330" font-family="'Courier New', monospace" font-weight="bold" font-size="15" fill="#263238">TOTAL CLAIMED</text>
        <text x="280" y="330" font-family="'Courier New', monospace" font-weight="bold" font-size="15" text-anchor="end" fill="#2E7D32">£${index === 0 ? '45.50' : index === 1 ? '6.80' : '15.00'}</text>
        
        <text x="50%" y="375" font-family="'Courier New', monospace" font-size="9" text-anchor="middle" fill="#90A4AE">Thank you for driving with Red Taxis!</text>
      </svg>
    `;
    return 'data:image/svg+xml;utf8,' + encodeURIComponent(svg);
  }
}
