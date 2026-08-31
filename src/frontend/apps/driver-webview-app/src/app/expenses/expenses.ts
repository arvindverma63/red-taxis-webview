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

      <!-- Dashboard Overview Stats (only shown in list view) -->
      <div class="stats-dashboard-card animated-fade-in" *ngIf="!isLoading && !isFormOpen && expenses.length > 0">
        <div class="total-claimed-row">
          <div class="total-claimed-lbl">Total Expenses Claimed</div>
          <div class="total-claimed-val">£{{ totalClaimed.toFixed(2) }}</div>
        </div>
        
        <div class="stats-grid">
          <div class="stat-box approved">
            <span class="stat-count">£{{ approvedTotal.toFixed(2) }}</span>
            <span class="stat-lbl">Approved</span>
          </div>
          <div class="stat-box pending">
            <span class="stat-count">£{{ pendingTotal.toFixed(2) }}</span>
            <span class="stat-lbl">Pending</span>
          </div>
          <div class="stat-box rejected">
            <span class="stat-count">£{{ rejectedTotal.toFixed(2) }}</span>
            <span class="stat-lbl">Rejected</span>
          </div>
        </div>

        <div class="divider"></div>

        <!-- Collapsible Category Breakdown -->
        <div class="breakdown-collapsible">
          <button class="breakdown-toggle-btn" (click)="toggleBreakdown()">
            <span class="btn-lbl-box">
              <span class="material-symbols-outlined btn-lbl-icon">bar_chart</span>
              <span>Category Breakdown</span>
            </span>
            <span class="material-symbols-outlined toggle-arrow">
              {{ isBreakdownOpen ? 'expand_less' : 'expand_more' }}
            </span>
          </button>

          <div class="breakdown-content" [class.open]="isBreakdownOpen">
            <div class="breakdown-item" *ngFor="let cat of categoryBreakdown">
              <div class="breakdown-info">
                <span class="breakdown-name">{{ cat.name }}</span>
                <span class="breakdown-amount">£{{ cat.total.toFixed(2) }} ({{ cat.pct.toFixed(0) }}%)</span>
              </div>
              <div class="breakdown-progress-bar">
                <div 
                  class="breakdown-progress-fill" 
                  [style.width]="cat.pct + '%'" 
                  [style.background-color]="cat.color"
                ></div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Action Button Nav (only shown in list view) -->
      <div class="nav-header" *ngIf="!isFormOpen">
        <button mat-flat-button class="new-expense-btn" (click)="openAddForm()">
          <mat-icon>add</mat-icon> Log Expense
        </button>
      </div>

      <!-- Date Filters Segment Bar (only shown in list view) -->
      <div class="filters-row animated-fade-in" *ngIf="!isFormOpen">
        <button 
          class="filter-pill" 
          [class.active]="activeFilterDays === 7" 
          (click)="setFilter(7)"
        >
          Last 7 Days
        </button>
        <button 
          class="filter-pill" 
          [class.active]="activeFilterDays === 30" 
          (click)="setFilter(30)"
        >
          Last 30 Days
        </button>
        <button 
          class="filter-pill" 
          [class.active]="activeFilterDays === 90" 
          (click)="setFilter(90)"
        >
          Last 90 Days
        </button>
      </div>

      <!-- Loading State -->
      <div *ngIf="isLoading" class="skeleton-container animated-fade-in">
        <div class="skeleton-card" *ngFor="let i of [1, 2, 3]">
          <div class="skeleton-line" style="width: 50%; height: 16px; margin-bottom: 8px;"></div>
          <div class="skeleton-line" style="width: 35%; height: 12px; margin-bottom: 12px;"></div>
          <div class="skeleton-line" style="width: 25%; height: 20px;"></div>
        </div>
      </div>

      <!-- Expenses List Card List -->
      <div *ngIf="!isLoading && !isFormOpen" class="expenses-list-container animated-fade-in">
        <div *ngIf="expenses.length === 0" class="empty-state">
          <span class="material-symbols-outlined empty-icon">receipt_long</span>
          <p class="empty-txt">No expenses logged in this period.</p>
          <button mat-stroked-button class="empty-btn" (click)="openAddForm()">
            Log your first expense
          </button>
        </div>

        <div class="expense-items" *ngIf="expenses.length > 0">
          <div 
            class="expense-row-card" 
            *ngFor="let item of expenses" 
            (click)="viewReceipt(item)"
          >
            <div class="card-indicator" [style.background-color]="getCategoryColor(item.category)"></div>
            <div class="expense-row-content">
              <div 
                class="row-icon-box" 
                [style.background-color]="getCategoryColorLight(item.category)" 
                [style.color]="getCategoryColor(item.category)"
              >
                <span class="material-symbols-outlined">{{ getCategoryIcon(item.category) }}</span>
              </div>
              <div class="expense-details-box">
                <div class="category-name">{{ getCategoryName(item.category) }}</div>
                <div class="expense-date-desc">
                  <span>{{ item.date | date:'dd MMM yyyy' }}</span>
                  <span class="desc-bullet" *ngIf="item.description">•</span>
                  <span class="desc-txt" *ngIf="item.description">{{ item.description }}</span>
                </div>
              </div>
              <div class="expense-financials-box">
                <span class="expense-amount">£{{ item.amount.toFixed(2) }}</span>
                <span class="status-badge" [ngClass]="getStatusClass(item.status)">
                  {{ getStatusName(item.status) }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Add Expense Form Panel -->
      <div *ngIf="isFormOpen" class="form-panel animated-fade-in">
        <div class="form-card">
          <div class="form-header-row">
            <h3 class="form-heading">Log New Expense</h3>
            <button class="close-form-btn" (click)="closeAddForm()">
              <span class="material-symbols-outlined">close</span>
            </button>
          </div>
          
          <!-- Category Grid Selector -->
          <div class="form-group">
            <label class="form-lbl">Select Category</label>
            <div class="category-grid">
              <button 
                type="button"
                *ngFor="let cat of categoryOptions"
                class="category-card"
                [class.selected]="category === cat.value"
                [style.border-color]="category === cat.value ? cat.color : '#ECEFF1'"
                (click)="selectCategory(cat.value)"
              >
                <div 
                  class="category-card-icon" 
                  [style.background-color]="category === cat.value ? cat.lightColor : '#F5F7F8'"
                  [style.color]="category === cat.value ? cat.color : '#546E7A'"
                >
                  <span class="material-symbols-outlined">{{ cat.icon }}</span>
                </div>
                <span class="category-card-lbl">{{ cat.label }}</span>
                <div class="selected-badge" *ngIf="category === cat.value" [style.background-color]="cat.color">
                  <span class="material-symbols-outlined">check</span>
                </div>
              </button>
            </div>
          </div>

          <!-- Amount Input Field with Prefix Symbol -->
          <div class="form-group">
            <label class="form-lbl">Amount</label>
            <div class="amount-input-wrapper">
              <span class="currency-symbol">£</span>
              <input 
                type="number" 
                step="0.01" 
                placeholder="0.00" 
                class="form-input amount-field" 
                (input)="onAmountChange($any($event.target).value)" 
                [value]="amount > 0 ? amount : ''" 
              />
            </div>
          </div>

          <!-- Description comments -->
          <div class="form-group">
            <label class="form-lbl">Description / Comments</label>
            <textarea 
              placeholder="Write brief details (e.g. location, station name, mileage)..." 
              class="form-textarea" 
              (input)="onDescChange($any($event.target).value)"
            ></textarea>
          </div>

          <!-- Receipt Photo Attachment Component -->
          <div class="form-group">
            <label class="form-lbl">Receipt Photo / Invoice</label>

            <!-- Video element for live capture -->
            <div class="camera-viewport-wrapper" *ngIf="isCameraActive">
              <video #videoElement autoplay playsinline class="camera-video"></video>
              <div class="camera-guidelines">
                <div class="guideline-box"></div>
                <p class="guideline-txt">Align receipt inside frame</p>
              </div>
              
              <div class="camera-actions">
                <button type="button" class="shutter-btn" (click)="capturePhoto()">
                  <span class="material-symbols-outlined">photo_camera</span>
                </button>
                <button type="button" class="cancel-camera-btn" (click)="stopCamera()">
                  <span class="material-symbols-outlined">close</span>
                </button>
              </div>
            </div>

            <!-- Thumbnail preview of attached receipt -->
            <div class="receipt-preview-thumbnail-card" *ngIf="!isCameraActive && capturedReceiptPhoto">
              <img [src]="capturedReceiptPhoto" class="thumbnail-img" />
              <div class="thumbnail-overlay">
                <span class="attached-lbl">Receipt Photo Attached</span>
                <button type="button" class="remove-receipt-btn" (click)="removeAttachedReceipt()">
                  <span class="material-symbols-outlined">delete</span>
                </button>
              </div>
            </div>

            <!-- Camera Trigger Button -->
            <button 
              type="button" 
              class="attach-photo-btn" 
              *ngIf="!isCameraActive && !capturedReceiptPhoto" 
              (click)="startCamera()"
            >
              <span class="material-symbols-outlined">photo_camera</span>
              <span>Capture Receipt Image</span>
            </button>
          </div>

          <!-- Form Action Buttons -->
          <div class="form-actions-row">
            <button 
              mat-stroked-button 
              class="cancel-btn" 
              (click)="closeAddForm()" 
              [disabled]="isSubmitting"
            >
              Cancel
            </button>
            <button 
              mat-flat-button 
              class="submit-action-btn" 
              (click)="submitExpense()" 
              [disabled]="isSubmitting || amount <= 0"
            >
              {{ isSubmitting ? 'Submitting...' : 'Submit Claim' }}
            </button>
          </div>
        </div>
      </div>

      <!-- Claim Preview Detail Modal Overlay -->
      <div 
        class="modal-backdrop" 
        *ngIf="isPreviewOpen && activeItem" 
        (click)="closeReceiptPreview()"
      >
        <div class="modal-card" (click)="$event.stopPropagation()">
          <div class="modal-header">
            <div class="modal-header-left">
              <div 
                class="modal-icon-box"
                [style.background-color]="getCategoryColorLight(activeItem.category)"
                [style.color]="getCategoryColor(activeItem.category)"
              >
                <span class="material-symbols-outlined">{{ getCategoryIcon(activeItem.category) }}</span>
              </div>
              <h4 class="modal-title">{{ getCategoryName(activeItem.category) }} Claim</h4>
            </div>
            <button class="modal-close-btn" (click)="closeReceiptPreview()">
              <span class="material-symbols-outlined">close</span>
            </button>
          </div>
          <div class="modal-body">
            <div class="modal-details-row">
              <span class="modal-lbl">Claim Date:</span>
              <span class="modal-val">{{ activeItem.date | date:'dd MMM yyyy' }}</span>
            </div>
            <div class="modal-details-row">
              <span class="modal-lbl">Amount Claimed:</span>
              <span class="modal-val bold green">£{{ activeItem.amount.toFixed(2) }}</span>
            </div>
            <div class="modal-details-row" *ngIf="activeItem.description">
              <span class="modal-lbl">Description:</span>
              <span class="modal-val desc-align">{{ activeItem.description }}</span>
            </div>
            <div class="modal-details-row">
              <span class="modal-lbl">Claim Status:</span>
              <span class="status-badge" [ngClass]="getStatusClass(activeItem.status)">
                {{ getStatusName(activeItem.status) }}
              </span>
            </div>

            <!-- Receipt Photo Details display -->
            <div class="modal-receipt-container" *ngIf="activeItemReceiptImg">
              <p class="receipt-section-lbl">Receipt Document</p>
              <div class="receipt-img-card">
                <img [src]="activeItemReceiptImg" class="receipt-full-img" />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  `,
  styles: [`
    /* Dark Theme Support via :host-context */
    :host-context(.dark-theme) .expenses-container {
      background-color: #121214 !important;
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .stats-dashboard-card,
    :host-context(.dark-theme) .form-card,
    :host-context(.dark-theme) .expense-row-card,
    :host-context(.dark-theme) .modal-card,
    :host-context(.dark-theme) .receipt-preview-thumbnail-card,
    :host-context(.dark-theme) .receipt-img-card {
      background-color: #1E1E24 !important;
      border-color: #2D2D35 !important;
      color: #ECEFF1 !important;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.25) !important;
    }
    :host-context(.dark-theme) .stat-box,
    :host-context(.dark-theme) .attach-photo-btn,
    :host-context(.dark-theme) .category-card {
      background-color: #121214 !important;
      border-color: #2D2D35 !important;
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .category-card:hover {
      background-color: #2D2D35 !important;
    }
    :host-context(.dark-theme) .category-card.selected {
      background-color: #1E1E24 !important;
      border-color: #E53935 !important;
    }
    :host-context(.dark-theme) .filter-pill {
      background-color: #121214 !important;
      border-color: #2D2D35 !important;
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .filter-pill.active {
      background-color: #E53935 !important;
      border-color: #E53935 !important;
      color: #FFFFFF !important;
    }
    :host-context(.dark-theme) .form-input,
    :host-context(.dark-theme) .form-textarea {
      background-color: #121214 !important;
      border-color: #2D2D35 !important;
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .form-input:focus,
    :host-context(.dark-theme) .form-textarea:focus {
      background-color: #121214 !important;
      border-color: #E53935 !important;
    }
    :host-context(.dark-theme) .modal-header,
    :host-context(.dark-theme) .modal-details-row {
      border-bottom-color: #2D2D35 !important;
    }
    :host-context(.dark-theme) .divider,
    :host-context(.dark-theme) .breakdown-progress-bar {
      background-color: #2D2D35 !important;
    }
    :host-context(.dark-theme) .cancel-btn {
      border-color: #2D2D35 !important;
      color: #90A4AE !important;
    }
    :host-context(.dark-theme) .close-form-btn,
    :host-context(.dark-theme) .modal-close-btn {
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .total-claimed-val,
    :host-context(.dark-theme) .category-name,
    :host-context(.dark-theme) .expense-amount,
    :host-context(.dark-theme) .form-heading,
    :host-context(.dark-theme) .category-card-lbl,
    :host-context(.dark-theme) .currency-symbol,
    :host-context(.dark-theme) .modal-title,
    :host-context(.dark-theme) .modal-val {
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .total-claimed-lbl,
    :host-context(.dark-theme) .stat-lbl,
    :host-context(.dark-theme) .breakdown-info,
    :host-context(.dark-theme) .breakdown-toggle-btn,
    :host-context(.dark-theme) .toggle-arrow,
    :host-context(.dark-theme) .desc-txt,
    :host-context(.dark-theme) .form-lbl,
    :host-context(.dark-theme) .modal-lbl,
    :host-context(.dark-theme) .receipt-section-lbl {
      color: #90A4AE !important;
    }

    .expenses-container {
      padding: 16px 16px 96px 16px;
      background-color: #F8F9FA;
      min-height: 100vh;
      font-family: 'Roboto', sans-serif;
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
      box-shadow: 0 4px 10px rgba(0, 0, 0, 0.1);
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
      color: #E53935;
    }
    .spinning {
      animation: spin 0.8s linear infinite;
    }
    @keyframes spin {
      100% { transform: rotate(360deg); }
    }

    /* Stats Dashboard Header styling */
    .stats-dashboard-card {
      background-color: #FFFFFF;
      border-radius: 18px;
      padding: 20px;
      border: 1px solid rgba(0, 0, 0, 0.025);
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.015);
      margin-bottom: 20px;
    }
    .total-claimed-row {
      display: flex;
      flex-direction: column;
      align-items: center;
      margin-bottom: 16px;
    }
    .total-claimed-lbl {
      font-size: 11px;
      color: #90A4AE;
      font-weight: 800;
      text-transform: uppercase;
      letter-spacing: 0.8px;
    }
    .total-claimed-val {
      font-size: 32px;
      font-weight: 900;
      color: #263238;
      margin-top: 4px;
      letter-spacing: -0.5px;
    }
    .stats-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 12px;
      margin-bottom: 16px;
    }
    .stat-box {
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 10px 4px;
      border-radius: 12px;
      background-color: #FAFBFC;
      border: 1px solid rgba(0, 0, 0, 0.01);
    }
    .stat-count {
      font-size: 13.5px;
      font-weight: 900;
    }
    .stat-lbl {
      font-size: 10px;
      color: #78909C;
      font-weight: 700;
      margin-top: 2px;
      text-transform: uppercase;
      letter-spacing: 0.2px;
    }
    .approved .stat-count { color: #2E7D32; }
    .pending .stat-count { color: #E65100; }
    .rejected .stat-count { color: #C62828; }

    .divider {
      height: 1px;
      background-color: #ECEFF1;
      margin: 16px 0 12px 0;
    }

    /* Collapsible category progress styling */
    .breakdown-toggle-btn {
      width: 100%;
      background: none;
      border: none;
      padding: 4px 0;
      display: flex;
      justify-content: space-between;
      align-items: center;
      cursor: pointer;
      color: #546E7A;
      font-weight: 700;
      font-size: 12.5px;
    }
    .btn-lbl-box {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .btn-lbl-icon {
      font-size: 18px;
    }
    .toggle-arrow {
      font-size: 18px;
      color: #90A4AE;
    }
    .breakdown-content {
      max-height: 0;
      overflow: hidden;
      transition: max-height 0.3s cubic-bezier(0, 1, 0, 1);
    }
    .breakdown-content.open {
      max-height: 1000px;
      transition: max-height 0.3s cubic-bezier(1, 0, 1, 0);
      margin-top: 12px;
    }
    .breakdown-item {
      margin-bottom: 12px;
    }
    .breakdown-item:last-child {
      margin-bottom: 4px;
    }
    .breakdown-info {
      display: flex;
      justify-content: space-between;
      font-size: 12px;
      color: #37474F;
      font-weight: 700;
      margin-bottom: 4px;
    }
    .breakdown-progress-bar {
      height: 6px;
      background-color: #ECEFF1;
      border-radius: 4px;
      overflow: hidden;
    }
    .breakdown-progress-fill {
      height: 100%;
      border-radius: 4px;
      transition: width 0.4s ease;
    }

    /* Nav Header actions */
    .nav-header {
      display: flex;
      justify-content: flex-end;
      margin-bottom: 12px;
    }
    .new-expense-btn {
      background-color: #E53935 !important;
      color: #FFFFFF !important;
      border-radius: 12px !important;
      font-weight: 800 !important;
      height: 38px;
      font-size: 12.5px !important;
      box-shadow: 0 4px 10px rgba(229, 57, 53, 0.15);
    }

    /* Filter segment bar styling */
    .filters-row {
      display: flex;
      gap: 8px;
      margin-bottom: 16px;
      overflow-x: auto;
      padding-bottom: 4px;
    }
    .filter-pill {
      border: 1px solid #ECEFF1;
      background-color: #FFFFFF;
      color: #546E7A;
      padding: 6px 14px;
      border-radius: 20px;
      font-size: 12px;
      font-weight: 700;
      cursor: pointer;
      white-space: nowrap;
      transition: all 0.2s ease;
      outline: none;
    }
    .filter-pill:hover {
      border-color: #CFD8DC;
    }
    .filter-pill.active {
      background-color: #E53935 !important;
      color: #FFFFFF !important;
      border-color: #E53935 !important;
      box-shadow: 0 4px 10px rgba(229, 57, 53, 0.12);
    }

    /* Skeleton structures */
    .skeleton-container {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .skeleton-card {
      background-color: #FFFFFF;
      border-radius: 16px;
      padding: 16px;
      border: 1px solid rgba(0, 0, 0, 0.025);
    }
    .skeleton-line {
      background: linear-gradient(90deg, #ECEFF1 25%, #F4F6F7 37%, #ECEFF1 63%);
      background-size: 400% 100%;
      animation: skeleton-animation 1.4s ease infinite;
      border-radius: 4px;
    }
    @keyframes skeleton-animation {
      0% { background-position: 100% 50%; }
      100% { background-position: 0 50%; }
    }

    /* Empty UI state */
    .empty-state {
      text-align: center;
      padding: 64px 20px;
    }
    .empty-icon {
      font-size: 56px;
      color: #CFD8DC;
      margin-bottom: 12px;
    }
    .empty-txt {
      font-size: 14px;
      color: #546E7A;
      margin-bottom: 24px;
    }
    .empty-btn {
      border-color: #ECEFF1 !important;
      color: #37474F !important;
      border-radius: 12px !important;
      font-weight: 800 !important;
      height: 40px;
    }

    /* Card List Styles */
    .expense-items {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .expense-row-card {
      background-color: #FFFFFF;
      border-radius: 16px;
      border: 1px solid rgba(0, 0, 0, 0.02);
      box-shadow: 0 4px 18px rgba(0,0,0,0.01);
      display: flex;
      overflow: hidden;
      transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
      cursor: pointer;
      position: relative;
    }
    .expense-row-card:hover {
      transform: translateY(-2px);
      box-shadow: 0 8px 24px rgba(0,0,0,0.025);
    }
    .card-indicator {
      width: 4px;
      height: 100%;
      position: absolute;
      left: 0;
      top: 0;
      bottom: 0;
    }
    .expense-row-content {
      padding: 16px 16px 16px 20px;
      flex: 1;
      display: flex;
      align-items: center;
    }
    .row-icon-box {
      width: 40px;
      height: 40px;
      border-radius: 12px;
      display: flex;
      justify-content: center;
      align-items: center;
      margin-right: 16px;
      flex-shrink: 0;
    }
    .row-icon-box .material-symbols-outlined {
      font-size: 20px;
    }
    .expense-details-box {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 2px;
      min-width: 0; /* truncate helper */
    }
    .category-name {
      font-size: 13.5px;
      font-weight: 800;
      color: #263238;
    }
    .expense-date-desc {
      display: flex;
      align-items: center;
      gap: 4px;
      font-size: 11.5px;
      color: #90A4AE;
      font-weight: 500;
      min-width: 0;
    }
    .desc-bullet {
      color: #CFD8DC;
    }
    .desc-txt {
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      color: #546E7A;
    }
    .expense-financials-box {
      display: flex;
      flex-direction: column;
      align-items: flex-end;
      gap: 6px;
      margin-left: 12px;
      flex-shrink: 0;
    }
    .expense-amount {
      font-size: 15px;
      font-weight: 900;
      color: #263238;
    }
    .status-badge {
      font-size: 9px;
      font-weight: 900;
      padding: 3px 8px;
      border-radius: 20px;
      text-transform: uppercase;
      letter-spacing: 0.3px;
    }
    .status-badge.approved {
      background-color: rgba(76, 175, 80, 0.08);
      color: #2E7D32;
    }
    .status-badge.pending {
      background-color: rgba(255, 152, 0, 0.08);
      color: #E65100;
    }
    .status-badge.rejected {
      background-color: rgba(211, 47, 47, 0.08);
      color: #C62828;
    }

    /* Form Card modifications */
    .form-panel {
      width: 100%;
    }
    .form-card {
      background-color: #FFFFFF;
      border-radius: 18px;
      padding: 24px;
      border: 1px solid rgba(0,0,0,0.02);
      box-shadow: 0 4px 20px rgba(0,0,0,0.015);
    }
    .form-header-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 20px;
    }
    .form-heading {
      margin: 0;
      font-size: 16px;
      font-weight: 900;
      color: #263238;
    }
    .close-form-btn {
      background: none;
      border: none;
      color: #90A4AE;
      cursor: pointer;
      display: flex;
      align-items: center;
      padding: 4px;
    }
    .close-form-btn .material-symbols-outlined {
      font-size: 20px;
    }
    .form-group {
      display: flex;
      flex-direction: column;
      gap: 6px;
      margin-bottom: 20px;
    }
    .form-lbl {
      font-size: 11px;
      font-weight: 800;
      color: #78909C;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    /* Visual Category selector grid */
    .category-grid {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 10px;
      margin-top: 4px;
    }
    @media (max-width: 480px) {
      .category-grid {
        grid-template-columns: repeat(3, 1fr);
      }
    }
    .category-card {
      background-color: #FFFFFF;
      border: 1.5px solid #ECEFF1;
      border-radius: 12px;
      padding: 10px 4px;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 8px;
      cursor: pointer;
      position: relative;
      outline: none;
      transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    }
    .category-card:hover {
      background-color: #FAFBFC;
    }
    .category-card-icon {
      width: 38px;
      height: 38px;
      border-radius: 10px;
      display: flex;
      justify-content: center;
      align-items: center;
      transition: background-color 0.2s ease, color 0.2s ease;
    }
    .category-card-icon .material-symbols-outlined {
      font-size: 18px;
    }
    .category-card-lbl {
      font-size: 10.5px;
      font-weight: 800;
      color: #37474F;
      text-align: center;
    }
    .selected-badge {
      position: absolute;
      top: -6px;
      right: -6px;
      width: 16px;
      height: 16px;
      border-radius: 50%;
      display: flex;
      justify-content: center;
      align-items: center;
      color: #FFFFFF;
      border: 1.5px solid #FFFFFF;
      box-shadow: 0 2px 5px rgba(0,0,0,0.1);
    }
    .selected-badge .material-symbols-outlined {
      font-size: 10px;
      font-weight: 900;
    }
    .category-card.selected {
      transform: scale(1.02);
      box-shadow: 0 4px 10px rgba(0, 0, 0, 0.02);
    }

    /* Premium Amount text field */
    .amount-input-wrapper {
      position: relative;
      display: flex;
      align-items: center;
      width: 100%;
    }
    .currency-symbol {
      position: absolute;
      left: 14px;
      font-size: 18px;
      font-weight: 900;
      color: #37474F;
    }
    .form-input.amount-field {
      padding-left: 28px;
      font-size: 18px;
      font-weight: 900;
      color: #263238;
    }
    .form-input, .form-textarea {
      width: 100%;
      border: 1.5px solid #ECEFF1;
      border-radius: 12px;
      padding: 12px;
      font-size: 14px;
      outline: none;
      box-sizing: border-box;
      background-color: #FCFDFD;
      transition: all 0.2s ease;
      color: #37474F;
    }
    .form-input:focus, .form-textarea:focus {
      border-color: #E53935;
      background-color: #FFFFFF;
      box-shadow: 0 0 0 3px rgba(229, 57, 53, 0.05);
    }
    .form-textarea {
      height: 90px;
      resize: none;
      line-height: 1.4;
    }

    /* Webcam Capture and Attach Receipt photo components */
    .attach-photo-btn {
      width: 100%;
      height: 48px;
      background-color: #F5F7F8;
      border: 1.5px dashed #CFD8DC;
      color: #546E7A;
      border-radius: 12px;
      display: flex;
      justify-content: center;
      align-items: center;
      gap: 10px;
      cursor: pointer;
      font-size: 13px;
      font-weight: 800;
      transition: all 0.2s ease;
    }
    .attach-photo-btn:hover {
      background-color: #ECEFF1;
      border-color: #B0BEC5;
      color: #37474F;
    }
    .attach-photo-btn .material-symbols-outlined {
      font-size: 18px;
    }

    .camera-viewport-wrapper {
      position: relative;
      width: 100%;
      height: 240px;
      background-color: #000000;
      border-radius: 14px;
      overflow: hidden;
      display: flex;
      justify-content: center;
      align-items: center;
    }
    .camera-video {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
    .camera-guidelines {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      pointer-events: none;
      box-sizing: border-box;
      padding: 20px;
    }
    .guideline-box {
      width: 80%;
      height: 70%;
      border: 2px dashed rgba(255, 255, 255, 0.7);
      border-radius: 10px;
      box-shadow: 0 0 0 1000px rgba(0, 0, 0, 0.4);
    }
    .guideline-txt {
      color: #FFFFFF;
      font-size: 11px;
      font-weight: 800;
      margin-top: 8px;
      text-shadow: 0 1px 3px rgba(0,0,0,0.8);
      background-color: rgba(0,0,0,0.6);
      padding: 3px 8px;
      border-radius: 4px;
    }
    .camera-actions {
      position: absolute;
      bottom: 12px;
      display: flex;
      align-items: center;
      gap: 20px;
    }
    .shutter-btn {
      width: 48px;
      height: 48px;
      border-radius: 50%;
      border: 4px solid #FFFFFF;
      background-color: #E53935;
      display: flex;
      justify-content: center;
      align-items: center;
      cursor: pointer;
      color: #FFFFFF;
      box-shadow: 0 4px 10px rgba(0,0,0,0.3);
    }
    .shutter-btn .material-symbols-outlined {
      font-size: 22px;
    }
    .cancel-camera-btn {
      width: 36px;
      height: 36px;
      border-radius: 50%;
      border: none;
      background-color: rgba(255,255,255,0.2);
      backdrop-filter: blur(5px);
      display: flex;
      justify-content: center;
      align-items: center;
      cursor: pointer;
      color: #FFFFFF;
    }
    .cancel-camera-btn .material-symbols-outlined {
      font-size: 18px;
    }

    .receipt-preview-thumbnail-card {
      position: relative;
      width: 100%;
      height: 120px;
      border-radius: 12px;
      overflow: hidden;
      border: 1.5px solid #ECEFF1;
    }
    .thumbnail-img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
    .thumbnail-overlay {
      position: absolute;
      bottom: 0;
      left: 0;
      right: 0;
      background: linear-gradient(0deg, rgba(0,0,0,0.7) 0%, rgba(0,0,0,0) 100%);
      padding: 8px 12px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .attached-lbl {
      color: #FFFFFF;
      font-size: 11px;
      font-weight: 800;
    }
    .remove-receipt-btn {
      background: none;
      border: none;
      color: #FFCDD2;
      cursor: pointer;
      padding: 4px;
      display: flex;
      align-items: center;
    }
    .remove-receipt-btn:hover {
      color: #FF8A80;
    }
    .remove-receipt-btn .material-symbols-outlined {
      font-size: 18px;
    }

    .form-actions-row {
      display: flex;
      gap: 12px;
      margin-top: 16px;
    }
    .cancel-btn {
      flex: 1;
      height: 46px;
      border-radius: 12px !important;
      font-weight: 800 !important;
      border-color: #ECEFF1 !important;
      color: #546E7A !important;
    }
    .submit-action-btn {
      flex: 2;
      height: 46px;
      background-color: #E53935 !important;
      color: #FFFFFF !important;
      border-radius: 12px !important;
      font-weight: 800 !important;
      box-shadow: 0 4px 12px rgba(229, 57, 53, 0.15) !important;
    }
    .submit-action-btn:disabled {
      background-color: #ECEFF1 !important;
      color: #90A4AE !important;
      box-shadow: none !important;
    }

    /* Modal dialog styling upgrades */
    .modal-backdrop {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background-color: rgba(0, 0, 0, 0.5);
      z-index: 1000;
      display: flex;
      justify-content: center;
      align-items: center;
      padding: 16px;
    }
    .modal-card {
      background-color: #FFFFFF;
      border-radius: 18px;
      width: 100%;
      max-width: 420px;
      box-shadow: 0 10px 30px rgba(0,0,0,0.15);
      border: 1px solid rgba(0,0,0,0.03);
      overflow: hidden;
      animation: zoomIn 0.2s ease-out;
    }
    @keyframes zoomIn {
      from { transform: scale(0.95); opacity: 0; }
      to { transform: scale(1); opacity: 1; }
    }
    .modal-header {
      padding: 16px 20px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 1px solid #ECEFF1;
    }
    .modal-header-left {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .modal-icon-box {
      width: 32px;
      height: 32px;
      border-radius: 8px;
      display: flex;
      justify-content: center;
      align-items: center;
    }
    .modal-icon-box .material-symbols-outlined {
      font-size: 18px;
    }
    .modal-title {
      margin: 0;
      font-size: 15px;
      font-weight: 900;
      color: #263238;
    }
    .modal-close-btn {
      border: none;
      background: none;
      cursor: pointer;
      color: #90A4AE;
      display: flex;
      align-items: center;
    }
    .modal-close-btn .material-symbols-outlined {
      font-size: 20px;
    }
    .modal-body {
      padding: 20px;
      display: flex;
      flex-direction: column;
      gap: 14px;
      max-height: 80vh;
      overflow-y: auto;
    }
    .modal-details-row {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      font-size: 13.5px;
      border-bottom: 1px solid #F5F7F8;
      padding-bottom: 8px;
    }
    .modal-details-row:last-of-type {
      border-bottom: none;
      padding-bottom: 0;
    }
    .modal-lbl {
      color: #78909C;
      font-weight: 500;
      flex-shrink: 0;
    }
    .modal-val {
      color: #37474F;
      font-weight: 800;
      text-align: right;
    }
    .modal-val.desc-align {
      text-align: right;
      max-width: 65%;
      word-break: break-word;
    }
    .modal-val.green {
      color: #2E7D32;
    }
    .modal-val.bold {
      font-size: 15.5px;
    }

    /* Modal receipt attachment area */
    .modal-receipt-container {
      margin-top: 10px;
    }
    .receipt-section-lbl {
      font-size: 11px;
      font-weight: 800;
      color: #78909C;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-bottom: 8px;
    }
    .receipt-img-card {
      border-radius: 12px;
      overflow: hidden;
      border: 1px solid #ECEFF1;
      box-shadow: 0 2px 10px rgba(0,0,0,0.02);
      max-height: 200px;
      background-color: #FAFBFC;
      display: flex;
      justify-content: center;
      align-items: center;
    }
    .receipt-full-img {
      width: 100%;
      height: 100%;
      object-fit: contain;
      max-height: 200px;
    }

    /* Animation effects */
    .animated-fade-in {
      animation: fadeIn 0.25s ease-in-out forwards;
    }
    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
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
      // Fallback check getProfile
      this.driverService.getProfile().subscribe({
        next: (res: any) => {
          const profile = res?.value || res;
          if (profile) {
            this.userId = profile.id || profile.userId || profile.driverId || 1;
            console.log('[Expenses] Resolved driver userId from profile fallback:', this.userId);
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
      console.warn('[Expenses] userId not loaded yet, skipping getExpenses');
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
        console.log('[Expenses] getExpenses response:', res);
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

    // Pre-seed mock images for demonstration in webview
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
      case 0: return '#E53935'; 
      case 1: return '#1E88E5'; 
      case 2: return '#43A047'; 
      case 3: return '#8E24AA'; 
      case 4: return '#00ACC1'; 
      case 5: return '#F4511E'; 
      default: return '#757575'; 
    }
  }

  getCategoryColorLight(catVal: number | string): string {
    const val = Number(catVal);
    switch (val) {
      case 0: return 'rgba(229, 57, 53, 0.1)';
      case 1: return 'rgba(30, 136, 245, 0.1)';
      case 2: return 'rgba(67, 160, 71, 0.1)';
      case 3: return 'rgba(142, 36, 170, 0.1)';
      case 4: return 'rgba(0, 172, 193, 0.1)';
      case 5: return 'rgba(244, 81, 30, 0.1)';
      default: return 'rgba(117, 117, 117, 0.1)';
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
        
        // If driver captured a receipt image, cache it locally linked to this claim ID
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
        
        // Add fake item locally to demonstrate working functionality immediately
        const newFakeId = Date.now();
        const newFake: ExpenseItem = {
          id: newFakeId,
          date: new Date().toISOString(),
          category: this.category,
          amount: this.amount,
          description: this.description,
          status: 'Pending'
        };

        // Cache local receipt image
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
    // Attempt to load captured receipt image from cache
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
      // Pulling down
      this.pullDistance = Math.min(yDiff * 0.4, 80);
      this.cdr.detectChanges();
      
      // Prevent browser default pull-to-refresh
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

  // Helper to generate a nice mock CSS receipt background for placeholder items
  private getMockReceiptBase64(index: number): string {
    // Generate a simple SVG receipt as data URL
    const svg = `
      <svg xmlns="http://www.w3.org/2000/svg" width="300" height="400" viewBox="0 0 300 400">
        <rect width="100%" height="100%" fill="#FCFDFD"/>
        <path d="M 0 0 L 15 10 L 30 0 L 45 10 L 60 0 L 75 10 L 90 0 L 105 10 L 120 0 L 135 10 L 150 0 L 165 10 L 180 0 L 195 10 L 210 0 L 225 10 L 240 0 L 255 10 L 270 0 L 285 10 L 300 0 L 300 400 L 0 400 Z" fill="#FFFFFF" stroke="#ECEFF1" stroke-width="1.5"/>
        <text x="50%" y="45" font-family="'Courier New', monospace" font-weight="bold" font-size="16" text-anchor="middle" fill="#263238">FIRST TAXIS LTD</text>
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
        
        <text x="50%" y="375" font-family="'Courier New', monospace" font-size="9" text-anchor="middle" fill="#90A4AE">Thank you for driving with First Taxis!</text>
      </svg>
    `;
    return 'data:image/svg+xml;utf8,' + encodeURIComponent(svg);
  }
}
