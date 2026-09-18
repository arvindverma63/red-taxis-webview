import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { MatCardModule } from '@angular/material/card';
import { MatIconModule } from '@angular/material/icon';
import { MatDividerModule } from '@angular/material/divider';
import { MatButtonModule } from '@angular/material/button';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { DriverService } from '../services/driver.service';
import { catchError } from 'rxjs/operators';
import { of } from 'rxjs';

export interface DriverDoc {
  type: number;
  name: string;
  status: 'Valid' | 'Expiring Soon' | 'Expired' | 'Missing' | 'Pending Verification';
  expiry: string;
  url?: string | null;
}

@Component({
  selector: 'app-profile',
  standalone: true,
  imports: [
    CommonModule,
    MatCardModule,
    MatIconModule,
    MatDividerModule,
    MatButtonModule,
    MatSnackBarModule
  ],
  template: `
    <div 
      class="profile-container"
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

      <!-- Diagnostics Alert Banner (if staging link fails) -->
      <div class="error-banner" *ngIf="apiError">
        <span class="material-symbols-outlined">error</span>
        <span>{{ apiError }}</span>
      </div>

      <!-- Loading Skeleton Loader -->
      <div *ngIf="isLoading" class="skeleton-container animated-fade-in">
        <div class="skeleton-hero-card">
          <div class="skeleton-avatar"></div>
          <div class="skeleton-hero-lines">
            <div class="skeleton-line title"></div>
            <div class="skeleton-line subtitle"></div>
          </div>
        </div>

        <div class="skeleton-card" *ngFor="let i of [1, 2]">
          <div class="skeleton-line section-head"></div>
          <div class="skeleton-row" *ngFor="let j of [1, 2, 3]"></div>
        </div>
      </div>

      <!-- Loaded Profile Content -->
      <div *ngIf="!isLoading" class="profile-content animated-fade-in">
        
        <!-- 1. Real Driver Identity Hero Card -->
        <div class="hero-profile-card">
          <div class="hero-inner">
            <div class="hero-top-row">
              <!-- Driver Avatar Circle -->
              <div class="avatar-wrapper">
                <div class="avatar-circle" [style.background-color]="colorCode ? (colorCode.startsWith('#') ? colorCode : '#' + colorCode) : '#CD1A21'">
                  <span class="avatar-initials">{{ getInitials() }}</span>
                </div>
              </div>

              <!-- Driver Real Identity Info -->
              <div class="driver-identity-info">
                <h1 class="driver-name">{{ driverName }}</h1>
                <div class="role-and-id-row">
                  <span class="badge-pill id-badge" *ngIf="driverId">
                    <span>ID: #DRV-{{ driverId }}</span>
                  </span>
                  <span class="badge-pill active-badge">
                    <span class="pulse-dot-inline"></span>
                    <span>Driver Account</span>
                  </span>
                </div>
              </div>
            </div>

            <!-- Last Login Timestamp (if available from API) -->
            <div class="hero-meta-bar" *ngIf="lastLogin">
              <div class="meta-item">
                <span class="material-symbols-outlined meta-icon">schedule</span>
                <span class="meta-text">Last Login: {{ lastLogin | date:'d MMM y, HH:mm' }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- 2. Driver Contact & Account Information Card -->
        <div class="section-card">
          <div class="section-card-header">
            <div class="section-title-wrapper">
              <div class="section-icon-box red">
                <span class="material-symbols-outlined">person</span>
              </div>
              <h2 class="section-title">Driver Details</h2>
            </div>
          </div>

          <div class="section-card-body">
            <div class="info-tiles-grid">
              <!-- Full Name -->
              <div class="info-tile">
                <div class="tile-icon-box">
                  <span class="material-symbols-outlined">account_circle</span>
                </div>
                <div class="tile-text">
                  <span class="tile-label">Full Name</span>
                  <span class="tile-value">{{ driverName }}</span>
                </div>
              </div>

              <!-- Driver ID -->
              <div class="info-tile" *ngIf="driverId">
                <div class="tile-icon-box">
                  <span class="material-symbols-outlined">badge</span>
                </div>
                <div class="tile-text">
                  <span class="tile-label">Driver ID</span>
                  <span class="tile-value font-mono">#DRV-{{ driverId }}</span>
                </div>
              </div>

              <!-- Email Address -->
              <div class="info-tile clickable" (click)="copyToClipboard(driverEmail, 'Email copied to clipboard')">
                <div class="tile-icon-box">
                  <span class="material-symbols-outlined">mail</span>
                </div>
                <div class="tile-text">
                  <span class="tile-label">Email Address</span>
                  <span class="tile-value text-ellipsis">{{ driverEmail }}</span>
                </div>
                <button class="tile-action-btn" title="Copy Email">
                  <span class="material-symbols-outlined">content_copy</span>
                </button>
              </div>

              <!-- Phone Number -->
              <div class="info-tile clickable" (click)="copyToClipboard(driverPhone, 'Phone number copied to clipboard')">
                <div class="tile-icon-box">
                  <span class="material-symbols-outlined">call</span>
                </div>
                <div class="tile-text">
                  <span class="tile-label">Phone Number</span>
                  <span class="tile-value font-mono">{{ driverPhone }}</span>
                </div>
                <button class="tile-action-btn" title="Copy Phone">
                  <span class="material-symbols-outlined">content_copy</span>
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- 3. Vehicle Details Card -->
        <div class="section-card">
          <div class="section-card-header">
            <div class="section-title-wrapper">
              <div class="section-icon-box blue">
                <span class="material-symbols-outlined">local_taxi</span>
              </div>
              <h2 class="section-title">Vehicle Details</h2>
            </div>
          </div>

          <div class="section-card-body">
            <!-- Authentic UK License Plate Showcase (if plate is assigned) -->
            <div class="plate-container" *ngIf="plateNumber && plateNumber !== 'No Plate'; else noPlateBox">
              <div class="uk-number-plate">
                <div class="uk-plate-euro">
                  <span class="plate-uk-txt">UK</span>
                </div>
                <span class="uk-plate-num">{{ plateNumber }}</span>
              </div>
            </div>
            
            <ng-template #noPlateBox>
              <div class="no-vehicle-notice">
                <span class="material-symbols-outlined">info</span>
                <span>No vehicle registration plate linked</span>
              </div>
            </ng-template>

            <!-- Vehicle Attribute Grid -->
            <div class="info-tiles-grid" style="margin-top: 10px;">
              <!-- Make & Model -->
              <div class="info-tile">
                <div class="tile-icon-box">
                  <span class="material-symbols-outlined">directions_car</span>
                </div>
                <div class="tile-text">
                  <span class="tile-label">Assigned Vehicle</span>
                  <span class="tile-value" [class.empty-text]="vehicleModel === 'No Vehicle Registered'">{{ vehicleModel }}</span>
                </div>
              </div>

              <!-- System Theme / Color (if set) -->
              <div class="info-tile" *ngIf="colorCode">
                <div class="tile-icon-box">
                  <span class="material-symbols-outlined">palette</span>
                </div>
                <div class="tile-text">
                  <span class="tile-label">Theme Color</span>
                  <div class="color-swatch-row">
                    <span class="color-dot" [style.background-color]="colorCode.startsWith('#') ? colorCode : '#' + colorCode"></span>
                    <span class="tile-value font-mono">{{ colorCode }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- 4. High-Density Compact Compliance Documents Hub -->
        <div class="section-card compliance-section">
          <!-- Compact Header with Stats & Actions -->
          <div class="section-card-header compact-head">
            <div class="section-title-wrapper">
              <div class="section-icon-box green">
                <span class="material-symbols-outlined">verified_user</span>
              </div>
              <div class="title-and-count">
                <h2 class="section-title">Compliance Documents</h2>
                <span class="compact-score-badge" [ngClass]="getComplianceStatusClass()">
                  {{ getVerifiedCount() }}/{{ documents.length }} Verified
                </span>
              </div>
            </div>
          </div>

          <!-- Slim Progress Track -->
          <div class="slim-progress-track">
            <div 
              class="slim-progress-fill"
              [ngClass]="getComplianceStatusClass()"
              [style.width.%]="getCompliancePercentage()"
            ></div>
          </div>

          <!-- Compact Filter Chips -->
          <div class="compact-filter-bar">
            <button 
              class="compact-chip"
              [class.active]="selectedDocFilter === 'all'"
              (click)="selectedDocFilter = 'all'"
            >
              All ({{ documents.length }})
            </button>
            <button 
              class="compact-chip"
              [class.active]="selectedDocFilter === 'action'"
              (click)="selectedDocFilter = 'action'"
            >
              Action Needed ({{ getActionNeededCount() }})
            </button>
            <button 
              class="compact-chip"
              [class.active]="selectedDocFilter === 'verified'"
              (click)="selectedDocFilter = 'verified'"
            >
              Verified ({{ getVerifiedCount() }})
            </button>
          </div>

          <!-- Tightened High-Density Document Listing -->
          <div class="compact-doc-list">
            <div 
              *ngFor="let doc of getFilteredDocuments()" 
              (click)="onDocClick(doc)" 
              class="compact-doc-row"
              [ngClass]="getDocStatusClass(doc.status)"
            >
              <!-- Left Color Indicator Bar -->
              <div class="doc-color-bar" [ngClass]="getDocStatusClass(doc.status)"></div>

              <!-- Document Icon -->
              <div class="compact-doc-icon" [ngClass]="getDocStatusClass(doc.status)">
                <span class="material-symbols-outlined">{{ getDocIcon(doc.status) }}</span>
              </div>

              <!-- Title & Expiry -->
              <div class="compact-doc-info">
                <span class="compact-doc-name">{{ doc.name }}</span>
                <span class="compact-doc-sub" [ngClass]="getDocStatusClass(doc.status)">
                  {{ getDocExpiryFormatted(doc) }}
                </span>
              </div>

              <!-- Status Tag & Action -->
              <div class="compact-doc-right">
                <span class="compact-status-tag" [ngClass]="getDocStatusClass(doc.status)">
                  {{ doc.status }}
                </span>
                <span class="material-symbols-outlined row-chevron">chevron_right</span>
              </div>
            </div>

            <!-- Empty Filter Message -->
            <div class="compact-empty-state" *ngIf="getFilteredDocuments().length === 0">
              <span class="material-symbols-outlined">check_circle</span>
              <span>No documents require attention in this view.</span>
            </div>
          </div>
        </div>

      </div>

      <!-- 5. Document Preview Modal -->
      <div class="preview-backdrop" *ngIf="isPreviewOpen && previewDoc" (click)="closePreview()">
        <div class="preview-modal-card" (click)="$event.stopPropagation()">
          <header class="preview-header">
            <div class="preview-header-titles">
              <h3 class="preview-title">{{ previewDoc.name }}</h3>
              <span class="preview-subtitle">Document Inspection</span>
            </div>
            <button class="close-modal-btn" (click)="closePreview()">
              <span class="material-symbols-outlined">close</span>
            </button>
          </header>
          
          <main class="preview-body">
            <!-- Status Badge Row -->
            <div class="preview-status-strip" [ngClass]="getDocStatusClass(previewDoc.status)">
              <span class="material-symbols-outlined status-strip-icon">
                {{ getDocIcon(previewDoc.status) }}
              </span>
              <div class="status-strip-text">
                <span class="status-main-label">{{ previewDoc.status }}</span>
                <span class="status-expiry-label">{{ getDocExpiryFormatted(previewDoc) }}</span>
              </div>
            </div>

            <!-- Image Viewport -->
            <div class="preview-image-container">
              <ng-container *ngIf="previewDoc.url; else noPreview">
                <img 
                  [src]="previewDoc.url" 
                  alt="Document Preview" 
                  class="preview-image" 
                  (load)="onPreviewImageLoaded()"
                  (error)="onPreviewImageError()"
                />
                <div class="preview-shimmer" *ngIf="isPreviewLoading"></div>
              </ng-container>
              <ng-template #noPreview>
                <div class="no-preview-placeholder">
                  <span class="material-symbols-outlined placeholder-icon">description</span>
                  <span class="placeholder-title">Document Under Review</span>
                  <span class="placeholder-text">Uploaded certificate is pending dispatch verification.</span>
                </div>
              </ng-template>
            </div>
          </main>
          
          <footer class="preview-footer">
            <button class="btn-cancel" (click)="closePreview()">Close</button>
            <button class="btn-primary" (click)="reuploadFromPreview()">
              <span class="material-symbols-outlined">cloud_upload</span>
              <span>Update Document</span>
            </button>
          </footer>
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

    .profile-container {
      padding: 12px 12px 40px 12px;
      max-width: 640px;
      margin: 0 auto;
      box-sizing: border-box;
      position: relative;
    }

    /* Pull-to-Refresh Floating Spinner */
    .floating-refresh-spinner {
      position: fixed;
      top: 0;
      left: 50%;
      width: 36px;
      height: 36px;
      border-radius: 50%;
      background: #FFFFFF;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 999;
      pointer-events: none;
      transition: opacity 0.2s ease;
      color: #CD1A21;
    }
    .native-spin-icon {
      font-size: 22px;
      transition: transform 0.1s linear;
    }
    .native-spin-icon.spinning {
      animation: spin 0.8s linear infinite;
    }
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }

    /* Diagnostics Banner */
    .error-banner {
      background-color: #FEE2E2;
      color: #991B1B;
      padding: 10px 12px;
      margin-bottom: 12px;
      border-radius: 10px;
      font-size: 12px;
      font-weight: 500;
      display: flex;
      align-items: center;
      gap: 8px;
      border: 1px solid rgba(185, 28, 28, 0.2);
    }

    /* Skeleton Loading State */
    .skeleton-hero-card {
      background: #FFFFFF;
      border-radius: 16px;
      padding: 16px;
      margin-bottom: 12px;
      display: flex;
      align-items: center;
      gap: 14px;
      border: 1px solid #E0E0E0;
    }
    .skeleton-avatar {
      width: 56px;
      height: 56px;
      border-radius: 50%;
      background: linear-gradient(90deg, #F0F2F5 25%, #E4E6EB 50%, #F0F2F5 75%);
      background-size: 200% 100%;
      animation: shimmer 1.5s infinite linear;
    }
    .skeleton-hero-lines {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .skeleton-line {
      background: linear-gradient(90deg, #F0F2F5 25%, #E4E6EB 50%, #F0F2F5 75%);
      background-size: 200% 100%;
      animation: shimmer 1.5s infinite linear;
      border-radius: 4px;
    }
    .skeleton-line.title { width: 55%; height: 16px; }
    .skeleton-line.subtitle { width: 35%; height: 12px; }
    .skeleton-card {
      background: #FFFFFF;
      border-radius: 14px;
      padding: 14px;
      margin-bottom: 12px;
      border: 1px solid #E0E0E0;
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .skeleton-line.section-head { width: 30%; height: 14px; }
    .skeleton-row {
      height: 40px;
      border-radius: 8px;
      background: linear-gradient(90deg, #F0F2F5 25%, #E4E6EB 50%, #F0F2F5 75%);
      background-size: 200% 100%;
      animation: shimmer 1.5s infinite linear;
    }
    @keyframes shimmer {
      0% { background-position: 200% 0; }
      100% { background-position: -200% 0; }
    }

    /* 1. Real Driver Hero Card */
    .hero-profile-card {
      position: relative;
      background: linear-gradient(135deg, #1E293B 0%, #0F172A 100%);
      color: #FFFFFF;
      border-radius: 16px;
      padding: 16px;
      margin-bottom: 12px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12);
      border: 1px solid rgba(255, 255, 255, 0.08);
    }
    .hero-inner {
      position: relative;
      z-index: 2;
    }
    .hero-top-row {
      display: flex;
      align-items: center;
      gap: 14px;
    }
    .avatar-wrapper {
      position: relative;
      flex-shrink: 0;
    }
    .avatar-circle {
      width: 52px;
      height: 52px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 18px;
      font-weight: 700;
      color: #FFFFFF;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.25);
    }
    .driver-identity-info {
      flex: 1;
      min-width: 0;
    }
    .driver-name {
      margin: 0 0 4px 0;
      font-size: 18px;
      font-weight: 700;
      color: #FFFFFF;
      letter-spacing: -0.2px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .role-and-id-row {
      display: flex;
      align-items: center;
      flex-wrap: wrap;
      gap: 6px;
    }
    .badge-pill {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      padding: 2px 6px;
      border-radius: 5px;
      font-size: 11px;
      font-weight: 600;
    }
    .id-badge {
      background: rgba(255, 255, 255, 0.12);
      color: #E2E8F0;
      font-family: monospace;
    }
    .active-badge {
      background: rgba(16, 185, 129, 0.2);
      color: #6EE7B7;
    }
    .pulse-dot-inline {
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background: #10B981;
    }
    .hero-meta-bar {
      margin-top: 10px;
      padding-top: 10px;
      border-top: 1px solid rgba(255, 255, 255, 0.1);
      font-size: 11px;
      color: #94A3B8;
    }
    .meta-item {
      display: flex;
      align-items: center;
      gap: 5px;
    }
    .meta-icon {
      font-size: 14px;
    }

    /* 2 & 3. Section Cards */
    .section-card {
      background: #FFFFFF;
      border-radius: 14px;
      border: 1px solid rgba(0, 0, 0, 0.07);
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.02);
      margin-bottom: 12px;
      overflow: hidden;
    }
    .section-card-header {
      padding: 10px 14px;
      border-bottom: 1px solid #F1F5F9;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .section-title-wrapper {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .section-icon-box {
      width: 28px;
      height: 28px;
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .section-icon-box .material-symbols-outlined {
      font-size: 16px;
    }
    .section-icon-box.red { background: #FEE2E2; color: #DC2626; }
    .section-icon-box.blue { background: #E0F2FE; color: #0284C7; }
    .section-icon-box.green { background: #DCFCE7; color: #16A34A; }

    .section-title {
      margin: 0;
      font-size: 13px;
      font-weight: 700;
      color: #0F172A;
      letter-spacing: -0.1px;
    }
    .section-card-body {
      padding: 10px 12px 12px 12px;
    }

    /* Info Tiles Grid */
    .info-tiles-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 8px;
    }
    @media (max-width: 440px) {
      .info-tiles-grid {
        grid-template-columns: 1fr;
      }
    }
    .info-tile {
      background: #F8FAFC;
      border: 1px solid #E2E8F0;
      border-radius: 10px;
      padding: 8px 10px;
      display: flex;
      align-items: center;
      gap: 8px;
      position: relative;
    }
    .info-tile.clickable {
      cursor: pointer;
    }
    .info-tile.clickable:active {
      background: #F1F5F9;
    }
    .tile-icon-box {
      color: #64748B;
      display: flex;
      align-items: center;
    }
    .tile-icon-box .material-symbols-outlined {
      font-size: 17px;
    }
    .tile-text {
      flex: 1;
      display: flex;
      flex-direction: column;
      min-width: 0;
    }
    .tile-label {
      font-size: 9px;
      font-weight: 600;
      color: #64748B;
      text-transform: uppercase;
      letter-spacing: 0.3px;
    }
    .tile-value {
      font-size: 12px;
      font-weight: 600;
      color: #1E293B;
    }
    .tile-value.empty-text {
      color: #94A3B8;
      font-style: italic;
    }
    .font-mono {
      font-family: monospace;
    }
    .text-ellipsis {
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .tile-action-btn {
      background: transparent;
      border: none;
      color: #94A3B8;
      padding: 2px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .tile-action-btn .material-symbols-outlined {
      font-size: 15px;
    }

    .color-swatch-row {
      display: flex;
      align-items: center;
      gap: 5px;
      margin-top: 1px;
    }
    .color-dot {
      width: 10px;
      height: 10px;
      border-radius: 50%;
      border: 1px solid rgba(0,0,0,0.15);
      flex-shrink: 0;
    }

    /* UK License Plate */
    .plate-container {
      display: flex;
      justify-content: center;
      padding: 6px 0;
    }
    .uk-number-plate {
      display: inline-flex;
      align-items: center;
      background: #FFD500;
      color: #000000;
      border: 2px solid #000000;
      border-radius: 6px;
      box-shadow: 0 2px 6px rgba(0, 0, 0, 0.1);
      overflow: hidden;
      font-family: 'Impact', 'Arial Black', sans-serif;
      font-weight: 900;
      letter-spacing: 2px;
    }
    .uk-plate-euro {
      background: #003399;
      color: #FFFFFF;
      padding: 5px 7px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .plate-uk-txt {
      font-size: 9px;
      font-weight: 900;
    }
    .uk-plate-num {
      font-size: 16px;
      padding: 4px 12px;
      text-transform: uppercase;
    }
    .no-vehicle-notice {
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 8px 10px;
      border-radius: 8px;
      background: #F1F5F9;
      color: #64748B;
      font-size: 11px;
    }
    .no-vehicle-notice .material-symbols-outlined {
      font-size: 16px;
    }

    /* 4. Tightened Compact Compliance Hub */
    .compact-head {
      padding: 10px 14px;
    }
    .title-and-count {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .compact-score-badge {
      padding: 2px 6px;
      border-radius: 8px;
      font-size: 10px;
      font-weight: 700;
    }
    .compact-score-badge.green { background: #DCFCE7; color: #15803D; }
    .compact-score-badge.amber { background: #FEF3C7; color: #B45309; }
    .compact-score-badge.red { background: #FEE2E2; color: #B91C1C; }

    .slim-progress-track {
      width: 100%;
      height: 3px;
      background: #E2E8F0;
    }
    .slim-progress-fill {
      height: 100%;
      transition: width 0.3s ease;
    }
    .slim-progress-fill.green { background: #10B981; }
    .slim-progress-fill.amber { background: #F59E0B; }
    .slim-progress-fill.red { background: #EF4444; }

    .compact-filter-bar {
      display: flex;
      gap: 4px;
      padding: 8px 12px 4px 12px;
      background: #FAFAFA;
      border-bottom: 1px solid #F1F5F9;
    }
    .compact-chip {
      background: #F1F5F9;
      border: 1px solid #E2E8F0;
      padding: 4px 8px;
      border-radius: 14px;
      font-size: 10px;
      font-weight: 600;
      color: #64748B;
      cursor: pointer;
      white-space: nowrap;
    }
    .compact-chip.active {
      background: #0F172A;
      color: #FFFFFF;
      border-color: #0F172A;
    }

    .compact-doc-list {
      padding: 8px 10px;
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .compact-doc-row {
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 10px;
      padding: 8px 10px;
      display: flex;
      align-items: center;
      gap: 10px;
      position: relative;
      overflow: hidden;
      cursor: pointer;
      transition: background 0.12s ease;
    }
    .compact-doc-row:active {
      background: #F8FAFC;
    }
    .doc-color-bar {
      position: absolute;
      left: 0;
      top: 0;
      bottom: 0;
      width: 3px;
    }
    .doc-color-bar.valid { background: #10B981; }
    .doc-color-bar.expiring-soon { background: #F59E0B; }
    .doc-color-bar.expired { background: #EF4444; }
    .doc-color-bar.pending-verification { background: #6366F1; }
    .doc-color-bar.missing { background: #94A3B8; }

    .compact-doc-icon {
      width: 28px;
      height: 28px;
      border-radius: 6px;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }
    .compact-doc-icon .material-symbols-outlined {
      font-size: 16px;
    }
    .compact-doc-icon.valid { background: #DCFCE7; color: #15803D; }
    .compact-doc-icon.expiring-soon { background: #FEF3C7; color: #B45309; }
    .compact-doc-icon.expired { background: #FEE2E2; color: #B91C1C; }
    .compact-doc-icon.pending-verification { background: #EEF2FF; color: #4F46E5; }
    .compact-doc-icon.missing { background: #F1F5F9; color: #64748B; }

    .compact-doc-info {
      flex: 1;
      min-width: 0;
      display: flex;
      flex-direction: column;
      gap: 1px;
    }
    .compact-doc-name {
      font-size: 12px;
      font-weight: 600;
      color: #0F172A;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .compact-doc-sub {
      font-size: 10px;
      color: #64748B;
    }
    .compact-doc-sub.missing { color: #DC2626; font-weight: 500; }
    .compact-doc-sub.expiring-soon { color: #D97706; font-weight: 500; }
    .compact-doc-sub.expired { color: #DC2626; font-weight: 500; }

    .compact-doc-right {
      display: flex;
      align-items: center;
      gap: 4px;
      flex-shrink: 0;
    }
    .compact-status-tag {
      font-size: 9px;
      font-weight: 700;
      padding: 2px 6px;
      border-radius: 6px;
      letter-spacing: 0.2px;
      text-transform: uppercase;
    }
    .compact-status-tag.valid { background: #DCFCE7; color: #166534; }
    .compact-status-tag.expiring-soon { background: #FEF3C7; color: #92400E; }
    .compact-status-tag.expired { background: #FEE2E2; color: #991B1B; }
    .compact-status-tag.pending-verification { background: #EEF2FF; color: #3730A3; }
    .compact-status-tag.missing { background: #E2E8F0; color: #334155; }

    .row-chevron {
      font-size: 16px;
      color: #94A3B8;
    }
    .compact-empty-state {
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 16px 10px;
      color: #16A34A;
      font-size: 11px;
      font-weight: 500;
      justify-content: center;
    }
    .compact-empty-state .material-symbols-outlined {
      font-size: 16px;
    }

    /* 5. Document Preview Modal */
    .preview-backdrop {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(15, 23, 42, 0.6);
      backdrop-filter: blur(4px);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 1000;
      padding: 14px;
    }
    .preview-modal-card {
      background: #FFFFFF;
      border-radius: 16px;
      max-width: 480px;
      width: 100%;
      box-shadow: 0 16px 36px rgba(0, 0, 0, 0.22);
      overflow: hidden;
      display: flex;
      flex-direction: column;
    }
    .preview-header {
      padding: 12px 16px;
      border-bottom: 1px solid #E2E8F0;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .preview-title {
      margin: 0;
      font-size: 14px;
      font-weight: 700;
      color: #0F172A;
    }
    .preview-subtitle {
      font-size: 10px;
      color: #64748B;
    }
    .close-modal-btn {
      background: #F1F5F9;
      border: none;
      width: 28px;
      height: 28px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      color: #64748B;
    }
    .preview-body {
      padding: 12px 16px;
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .preview-status-strip {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 8px 10px;
      border-radius: 8px;
    }
    .preview-status-strip.valid { background: #DCFCE7; color: #166534; }
    .preview-status-strip.expiring-soon { background: #FEF3C7; color: #92400E; }
    .preview-status-strip.expired { background: #FEE2E2; color: #991B1B; }
    .preview-status-strip.pending-verification { background: #EEF2FF; color: #3730A3; }
    .preview-status-strip.missing { background: #F1F5F9; color: #475569; }

    .status-strip-icon {
      font-size: 18px;
    }
    .status-strip-text {
      display: flex;
      flex-direction: column;
    }
    .status-main-label {
      font-size: 11px;
      font-weight: 700;
    }
    .status-expiry-label {
      font-size: 10px;
      opacity: 0.85;
    }

    .preview-image-container {
      position: relative;
      min-height: 200px;
      max-height: 320px;
      background: #F8FAFC;
      border: 1px solid #E2E8F0;
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      overflow: hidden;
    }
    .preview-image {
      max-width: 100%;
      max-height: 320px;
      object-fit: contain;
    }
    .preview-shimmer {
      position: absolute;
      top: 0; left: 0; right: 0; bottom: 0;
      background: linear-gradient(90deg, #F0F2F5 25%, #E4E6EB 50%, #F0F2F5 75%);
      background-size: 200% 100%;
      animation: shimmer 1.5s infinite linear;
    }
    .no-preview-placeholder {
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
      padding: 20px 12px;
      gap: 4px;
    }
    .placeholder-icon {
      font-size: 36px;
      color: #94A3B8;
    }
    .placeholder-title {
      font-size: 12px;
      font-weight: 600;
      color: #0F172A;
    }
    .placeholder-text {
      font-size: 10px;
      color: #64748B;
      line-height: 1.3;
      max-width: 240px;
    }

    .preview-footer {
      padding: 10px 16px;
      border-top: 1px solid #E2E8F0;
      display: flex;
      justify-content: flex-end;
      gap: 8px;
    }
    .btn-cancel {
      background: #F1F5F9;
      border: 1px solid #CBD5E1;
      padding: 7px 14px;
      border-radius: 8px;
      font-size: 12px;
      font-weight: 600;
      color: #475569;
      cursor: pointer;
    }
    .btn-primary {
      background: #CD1A21;
      color: #FFFFFF;
      border: none;
      padding: 7px 14px;
      border-radius: 8px;
      font-size: 12px;
      font-weight: 600;
      display: flex;
      align-items: center;
      gap: 5px;
      cursor: pointer;
    }
    .btn-primary .material-symbols-outlined {
      font-size: 16px;
    }

    /* Animations */
    .animated-fade-in {
      animation: fadeIn 0.25s ease-in-out;
    }
    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }

    /* ================= DARK THEME OVERRIDES ================= */
    :host-context(.dark-theme) {
      background-color: #121214 !important;
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .floating-refresh-spinner {
      background: #1E1E24;
      color: #F87171;
    }
    :host-context(.dark-theme) .section-card {
      background: #1E1E24;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .section-card-header {
      border-bottom-color: #2D2D35;
    }
    :host-context(.dark-theme) .section-title {
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .info-tile {
      background: #16161A;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .tile-value {
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .compact-filter-bar {
      background: #16161A;
      border-bottom-color: #2D2D35;
    }
    :host-context(.dark-theme) .compact-chip {
      background: #1E1E24;
      border-color: #2D2D35;
      color: #94A3B8;
    }
    :host-context(.dark-theme) .compact-chip.active {
      background: #ECEFF1;
      color: #121214;
      border-color: #ECEFF1;
    }
    :host-context(.dark-theme) .compact-doc-row {
      background: #16161A;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .compact-doc-name {
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .preview-modal-card {
      background: #1E1E24;
      color: #ECEFF1;
      border: 1px solid #2D2D35;
    }
    :host-context(.dark-theme) .preview-header {
      border-bottom-color: #2D2D35;
    }
    :host-context(.dark-theme) .preview-title {
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .preview-image-container {
      background: #16161A;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .preview-footer {
      border-top-color: #2D2D35;
    }
    :host-context(.dark-theme) .btn-cancel {
      background: #2D2D35;
      border-color: #3E3E48;
      color: #ECEFF1;
    }
  `]
})
export class ProfileComponent implements OnInit {
  isLoading = true;
  apiError = '';
  driverName = '';
  driverEmail = '';
  driverPhone = '';
  vehicleModel = '';
  plateNumber = '';
  colorCode = '';
  lastLogin: string | null = null;
  driverId: number | null = null;

  selectedDocFilter: 'all' | 'action' | 'verified' = 'all';

  // Pull to refresh
  touchStartY = 0;
  pullDistance = 0;
  isRefreshing = false;

  // Document Inspection Modal
  isPreviewOpen = false;
  previewDoc: DriverDoc | null = null;
  isPreviewLoading = true;

  documents: DriverDoc[] = [
    { type: 0, name: 'Private Hire Motor Insurance', status: 'Missing', expiry: 'Not Uploaded' },
    { type: 1, name: 'Vehicle MOT Test Certificate', status: 'Missing', expiry: 'Not Uploaded' },
    { type: 2, name: 'DBS Certificate / Check', status: 'Missing', expiry: 'Not Uploaded' },
    { type: 3, name: 'Vehicle Badge / License', status: 'Missing', expiry: 'Not Uploaded' },
    { type: 4, name: 'Driver Licence (Front & Back)', status: 'Missing', expiry: 'Not Uploaded' },
    { type: 5, name: 'Safe Guarding Certificate', status: 'Missing', expiry: 'Not Uploaded' },
    { type: 6, name: 'First Aid Certificate', status: 'Missing', expiry: 'Not Uploaded' },
    { type: 7, name: 'Driver Profile Photo', status: 'Missing', expiry: 'Not Uploaded' },
    { type: 8, name: 'Hackney Carriage / PHV Driver Badge', status: 'Missing', expiry: 'Not Uploaded' }
  ];

  constructor(
    private router: Router, 
    private driverService: DriverService,
    private cdr: ChangeDetectorRef,
    private snackBar: MatSnackBar
  ) {}

  ngOnInit(): void {
    this.loadProfile();
  }

  loadProfile(): void {
    this.isLoading = true;
    const userId = this.getUserIdFromToken();
    this.driverId = userId;
    console.log('[Profile] Decoded current driver userId from JWT:', userId);

    this.driverService.getProfile().pipe(
      catchError(err => {
        const token = localStorage.getItem('auth_token');
        const tokenSnippet = token ? `(...${token.slice(-5)})` : 'None';
        this.apiError = `Staging Link Failed (${err.status}): Token: ${tokenSnippet}. Fallback to offline developer data enabled.`;
        console.warn('Staging API GetProfile failed, using mock data:', err);
        return of(null);
      })
    ).subscribe(profileResponse => {
      if (profileResponse) {
        const profile = profileResponse.value || profileResponse;
        
        this.driverName = profile.fullname || profile.fullName || profile.name || 'Driver';
        this.driverEmail = profile.email || 'Not Registered';
        this.driverPhone = profile.telephone || profile.phone || profile.phoneNumber || 'Not Registered';
        this.colorCode = profile.colorCode || '';
        this.lastLogin = profile.lastLogin || null;
        
        const vehicleMake = profile.vehicleMake || profile.make || '';
        const vehicleModel = profile.vehicleModel || profile.model || profile.carModel || '';
        const vehicleColour = profile.vehicleColour || profile.colour || profile.color || '';

        if (vehicleMake || vehicleModel) {
          this.vehicleModel = `${vehicleMake} ${vehicleModel}`.trim();
          if (vehicleColour) {
            this.vehicleModel += ` (${vehicleColour})`;
          }
        } else {
          this.vehicleModel = 'No Vehicle Registered';
        }

        this.plateNumber = profile.vehicleReg || profile.regNo || profile.plateNumber || profile.registration || 'No Plate';
      }

      // Fetch dynamic compliance expiries if userId is resolved
      if (userId) {
        this.driverService.getDriverExpirys().pipe(
          catchError(err => {
            console.warn('[Profile] Failed to fetch document expiries from staging:', err);
            return of(null);
          })
        ).subscribe({
          next: (expirysResponse) => {
            if (expirysResponse && expirysResponse.success && Array.isArray(expirysResponse.value)) {
              const myExpirys = expirysResponse.value.filter((e: any) => e.userId === userId);
              console.log(`[Profile] Found ${myExpirys.length} document expiry database entries for userId ${userId}`);
              
              myExpirys.forEach((exp: any) => {
                const docType = exp.documentType;
                const docItem = this.documents.find(d => d.type === docType);
                if (docItem) {
                  docItem.expiry = this.formatExpiryDate(exp.expiryDate);
                  docItem.status = this.getDocumentStatus(exp.expiryDate);
                  docItem.url = exp.documentUrl || exp.fileUrl || exp.url || exp.documentPath || exp.path || exp.filePath || exp.file || exp.document || localStorage.getItem('pending_upload_url_' + docType) || null;
                  localStorage.removeItem('pending_upload_' + docType);
                }
              });
            }
          },
          complete: () => {
            this.applyPendingUploads();
            this.isLoading = false;
            this.isRefreshing = false;
            this.cdr.detectChanges();
          }
        });
      } else {
        this.applyPendingUploads();
        this.isLoading = false;
        this.isRefreshing = false;
        this.cdr.detectChanges();
      }
    });
  }

  private applyPendingUploads(): void {
    this.documents.forEach(doc => {
      const isPending = localStorage.getItem('pending_upload_' + doc.type) === 'true';
      if (isPending && (doc.status === 'Missing' || doc.expiry === 'Not Uploaded')) {
        doc.status = 'Pending Verification';
        doc.expiry = 'Under Review';
        doc.url = localStorage.getItem('pending_upload_url_' + doc.type) || null;
      }
    });
  }

  getInitials(): string {
    if (!this.driverName || this.driverName === 'Driver') return 'DR';
    const parts = this.driverName.trim().split(/\s+/);
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return this.driverName.substring(0, 2).toUpperCase();
  }

  getVerifiedCount(): number {
    return this.documents.filter(d => d.status === 'Valid').length;
  }

  getActionNeededCount(): number {
    return this.documents.filter(d => d.status === 'Missing' || d.status === 'Expired' || d.status === 'Expiring Soon').length;
  }

  getCompliancePercentage(): number {
    if (this.documents.length === 0) return 0;
    return Math.round((this.getVerifiedCount() / this.documents.length) * 100);
  }

  getComplianceStatusClass(): string {
    const p = this.getCompliancePercentage();
    if (p >= 80) return 'green';
    if (p >= 40) return 'amber';
    return 'red';
  }

  getDocStatusClass(status: string): string {
    return status.toLowerCase().replace(/\s+/g, '-');
  }

  getDocIcon(status: string): string {
    switch (status) {
      case 'Valid': return 'check_circle';
      case 'Expiring Soon': return 'warning';
      case 'Expired': return 'cancel';
      case 'Pending Verification': return 'hourglass_top';
      default: return 'upload_file';
    }
  }

  getDocExpiryFormatted(doc: DriverDoc): string {
    if (doc.status === 'Missing' || doc.expiry === 'Not Uploaded') return 'Upload required';
    if (doc.status === 'Pending Verification' || doc.expiry === 'Under Review') return 'Under review by dispatch';
    return `Expires: ${doc.expiry}`;
  }

  getFilteredDocuments(): DriverDoc[] {
    if (this.selectedDocFilter === 'action') {
      return this.documents.filter(d => d.status === 'Missing' || d.status === 'Expired' || d.status === 'Expiring Soon');
    }
    if (this.selectedDocFilter === 'verified') {
      return this.documents.filter(d => d.status === 'Valid');
    }
    return this.documents;
  }

  getUserIdFromToken(): number | null {
    const token = localStorage.getItem('auth_token');
    if (!token) return null;
    try {
      const parts = token.split('.');
      if (parts.length === 3) {
        let base64Url = parts[1];
        let base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
        while (base64.length % 4) {
          base64 += '=';
        }
        const payload = JSON.parse(atob(base64));
        const userId = payload.id || payload.nameid;
        return userId ? Number(userId) : null;
      }
    } catch (e) {
      console.error('Failed to parse JWT token for userId:', e);
    }
    return null;
  }

  getDocumentStatus(expiryDateStr: string): 'Valid' | 'Expiring Soon' | 'Expired' | 'Missing' {
    if (!expiryDateStr) return 'Missing';
    const expiry = new Date(expiryDateStr);
    if (isNaN(expiry.getTime())) return 'Missing';
    
    const today = new Date();
    today.setHours(0,0,0,0);
    expiry.setHours(0,0,0,0);
    
    if (expiry < today) {
      return 'Expired';
    }
    
    const diffTime = expiry.getTime() - today.getTime();
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    
    if (diffDays <= 30) {
      return 'Expiring Soon';
    }
    
    return 'Valid';
  }

  formatExpiryDate(dateStr: string): string {
    if (!dateStr) return 'Not Uploaded';
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) return 'Not Uploaded';
    const day = d.getDate();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return `${day} ${months[d.getMonth()]} ${d.getFullYear()}`;
  }

  copyToClipboard(text: string, message: string): void {
    if (!text || text === 'Not Registered') return;
    navigator.clipboard.writeText(text).then(() => {
      this.snackBar.open(message, 'OK', {
        duration: 2000,
        horizontalPosition: 'center',
        verticalPosition: 'bottom'
      });
    }).catch(err => {
      console.warn('Clipboard write error:', err);
    });
  }

  // Touch Gestures
  onTouchStart(event: TouchEvent): void {
    if (window.scrollY === 0) {
      this.touchStartY = event.touches[0].clientY;
    }
  }

  onTouchMove(event: TouchEvent): void {
    if (this.touchStartY > 0 && window.scrollY === 0 && !this.isRefreshing) {
      const currentY = event.touches[0].clientY;
      const distance = currentY - this.touchStartY;
      if (distance > 0) {
        this.pullDistance = Math.min(distance * 0.45, 70);
      }
    }
  }

  onTouchEnd(): void {
    if (this.pullDistance >= 50 && !this.isRefreshing) {
      this.isRefreshing = true;
      this.loadProfile();
    }
    this.touchStartY = 0;
    this.pullDistance = 0;
  }

  navigateToUpload(type: number, name: string): void {
    this.router.navigate(['/upload'], { queryParams: { type, name } });
  }

  onDocClick(doc: DriverDoc): void {
    if (doc.status === 'Missing') {
      this.navigateToUpload(doc.type, doc.name);
    } else {
      this.openPreview(doc);
    }
  }

  openPreview(doc: DriverDoc): void {
    this.previewDoc = doc;
    this.isPreviewLoading = true;
    this.isPreviewOpen = true;
    this.cdr.detectChanges();
  }

  closePreview(): void {
    this.isPreviewOpen = false;
    this.previewDoc = null;
    this.cdr.detectChanges();
  }

  onPreviewImageLoaded(): void {
    this.isPreviewLoading = false;
    this.cdr.detectChanges();
  }

  onPreviewImageError(): void {
    this.isPreviewLoading = false;
    this.cdr.detectChanges();
  }

  reuploadFromPreview(): void {
    if (this.previewDoc) {
      const type = this.previewDoc.type;
      const name = this.previewDoc.name;
      this.closePreview();
      this.navigateToUpload(type, name);
    }
  }
}
