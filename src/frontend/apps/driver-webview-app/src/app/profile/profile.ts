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
            <div class="skeleton-line pill"></div>
          </div>
        </div>

        <div class="skeleton-metrics-row">
          <div class="skeleton-metric-card" *ngFor="let i of [1, 2, 3]"></div>
        </div>

        <div class="skeleton-card" *ngFor="let i of [1, 2]">
          <div class="skeleton-line section-head"></div>
          <div class="skeleton-row" *ngFor="let j of [1, 2, 3]"></div>
        </div>
      </div>

      <!-- Loaded Profile Content -->
      <div *ngIf="!isLoading" class="profile-content animated-fade-in">
        
        <!-- 1. Executive Driver Identity Hero Card -->
        <div class="hero-profile-card">
          <!-- Subtle dynamic ambient glow -->
          <div class="hero-ambient-glow" [style.background]="getAmbientGlowStyle()"></div>
          
          <div class="hero-inner">
            <div class="hero-top-row">
              <!-- Driver Avatar with Verified Ring -->
              <div class="avatar-wrapper">
                <div class="avatar-ring" [style.border-color]="getAccentColor()">
                  <div class="avatar-circle" [style.background-color]="colorCode ? (colorCode.startsWith('#') ? colorCode : '#' + colorCode) : '#CD1A21'">
                    <span class="avatar-initials">{{ getInitials() }}</span>
                  </div>
                </div>
                <div class="online-status-badge" title="Active on Fleet">
                  <span class="pulse-dot"></span>
                </div>
              </div>

              <!-- Driver Name & Official Status -->
              <div class="driver-identity-info">
                <div class="name-with-badge">
                  <h1 class="driver-name">{{ driverName }}</h1>
                  <span class="verified-icon-badge" title="Verified Driver Partner">
                    <span class="material-symbols-outlined">verified</span>
                  </span>
                </div>

                <div class="role-and-id-row">
                  <span class="badge-pill role-badge">
                    <span class="material-symbols-outlined pill-icon">local_taxi</span>
                    <span>Official Partner Driver</span>
                  </span>
                  <span class="badge-pill id-badge">
                    <span>ID: {{ getFormattedDriverId() }}</span>
                  </span>
                </div>
              </div>
            </div>

            <!-- Hero Meta Bar: Rating, Trips, and Last Login -->
            <div class="hero-meta-bar">
              <div class="meta-item rating">
                <span class="material-symbols-outlined star-icon">star</span>
                <span class="meta-bold">4.98</span>
                <span class="meta-sub">(1,420+ trips)</span>
              </div>
              <div class="meta-divider"></div>
              <div class="meta-item fleet">
                <span class="material-symbols-outlined meta-icon">hub</span>
                <span class="meta-text">Red Taxis Network</span>
              </div>
              <div class="meta-divider" *ngIf="lastLogin"></div>
              <div class="meta-item login-time" *ngIf="lastLogin">
                <span class="material-symbols-outlined meta-icon">schedule</span>
                <span class="meta-text">Active {{ lastLogin | date:'d MMM, HH:mm' }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- 2. Executive 3-Column Telemetry Metrics Grid -->
        <div class="telemetry-grid">
          <!-- Compliance Status -->
          <div class="telemetry-card" (click)="scrollToCompliance()">
            <div class="telemetry-icon-wrapper" [ngClass]="getComplianceStatusClass()">
              <span class="material-symbols-outlined">{{ getComplianceIcon() }}</span>
            </div>
            <div class="telemetry-info">
              <span class="telemetry-label">Compliance</span>
              <span class="telemetry-value">{{ getVerifiedCount() }}/{{ documents.length }} Verified</span>
              <div class="telemetry-progress-track">
                <div 
                  class="telemetry-progress-fill" 
                  [ngClass]="getComplianceStatusClass()"
                  [style.width.%]="getCompliancePercentage()"
                ></div>
              </div>
            </div>
          </div>

          <!-- Assigned Vehicle -->
          <div class="telemetry-card">
            <div class="telemetry-icon-wrapper blue">
              <span class="material-symbols-outlined">directions_car</span>
            </div>
            <div class="telemetry-info">
              <span class="telemetry-label">Assigned Vehicle</span>
              <span class="telemetry-value text-ellipsis">{{ vehicleModel === 'No Vehicle Registered' ? 'Unassigned' : vehicleModel }}</span>
              <span class="telemetry-sub-badge" *ngIf="plateNumber && plateNumber !== 'No Plate'">{{ plateNumber }}</span>
            </div>
          </div>

          <!-- Standing & Tier -->
          <div class="telemetry-card">
            <div class="telemetry-icon-wrapper amber">
              <span class="material-symbols-outlined">military_tech</span>
            </div>
            <div class="telemetry-info">
              <span class="telemetry-label">Driver Standing</span>
              <span class="telemetry-value">Gold • Tier 1</span>
              <span class="standing-status-pill">Active Good Standing</span>
            </div>
          </div>
        </div>

        <!-- 3. Driver Contact & Account Profile Card -->
        <div class="section-card">
          <div class="section-card-header">
            <div class="section-title-wrapper">
              <div class="section-icon-box red">
                <span class="material-symbols-outlined">badge</span>
              </div>
              <div class="section-title-col">
                <h2 class="section-title">Driver Profile & Credentials</h2>
                <span class="section-subtitle">Account details registered with dispatch</span>
              </div>
            </div>
          </div>

          <div class="section-card-body">
            <div class="info-tiles-grid">
              <!-- Full Name -->
              <div class="info-tile">
                <div class="tile-icon-box">
                  <span class="material-symbols-outlined">person</span>
                </div>
                <div class="tile-text">
                  <span class="tile-label">Full Name</span>
                  <span class="tile-value">{{ driverName }}</span>
                </div>
              </div>

              <!-- Driver ID -->
              <div class="info-tile">
                <div class="tile-icon-box">
                  <span class="material-symbols-outlined">pin</span>
                </div>
                <div class="tile-text">
                  <span class="tile-label">Driver Reference</span>
                  <span class="tile-value font-mono">{{ getFormattedDriverId() }}</span>
                </div>
              </div>

              <!-- Email Address (with copy) -->
              <div class="info-tile clickable" (click)="copyToClipboard(driverEmail, 'Email copied')">
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

              <!-- Phone Number (with copy & call) -->
              <div class="info-tile clickable" (click)="copyToClipboard(driverPhone, 'Phone number copied')">
                <div class="tile-icon-box">
                  <span class="material-symbols-outlined">call</span>
                </div>
                <div class="tile-text">
                  <span class="tile-label">Contact Number</span>
                  <span class="tile-value font-mono">{{ driverPhone }}</span>
                </div>
                <button class="tile-action-btn" title="Copy Phone">
                  <span class="material-symbols-outlined">content_copy</span>
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- 4. Assigned Vehicle Specifications Card -->
        <div class="section-card">
          <div class="section-card-header">
            <div class="section-title-wrapper">
              <div class="section-icon-box purple">
                <span class="material-symbols-outlined">local_taxi</span>
              </div>
              <div class="section-title-col">
                <h2 class="section-title">Vehicle Specifications</h2>
                <span class="section-subtitle">Licensing and physical vehicle attributes</span>
              </div>
            </div>
          </div>

          <div class="section-card-body">
            <!-- Authentic UK License Plate Showcase -->
            <div class="license-plate-showcase" *ngIf="plateNumber && plateNumber !== 'No Plate'; else noPlateBox">
              <div class="uk-number-plate-large">
                <div class="uk-plate-flag-strip">
                  <span class="plate-uk-text">UK</span>
                </div>
                <span class="uk-plate-digits">{{ plateNumber }}</span>
              </div>
              <div class="plate-registered-label">
                <span class="material-symbols-outlined">check_circle</span>
                <span>Active Registered Vehicle</span>
              </div>
            </div>
            
            <ng-template #noPlateBox>
              <div class="no-vehicle-banner">
                <span class="material-symbols-outlined">no_crash</span>
                <span>No vehicle registration plate linked to this account</span>
              </div>
            </ng-template>

            <!-- Vehicle Attribute Grid -->
            <div class="info-tiles-grid" style="margin-top: 14px;">
              <!-- Make & Model -->
              <div class="info-tile">
                <div class="tile-icon-box">
                  <span class="material-symbols-outlined">commute</span>
                </div>
                <div class="tile-text">
                  <span class="tile-label">Make & Model</span>
                  <span class="tile-value" [class.empty-text]="vehicleModel === 'No Vehicle Registered'">{{ vehicleModel }}</span>
                </div>
              </div>

              <!-- Body Color Swatch -->
              <div class="info-tile" *ngIf="colorCode">
                <div class="tile-icon-box">
                  <span class="material-symbols-outlined">palette</span>
                </div>
                <div class="tile-text">
                  <span class="tile-label">Theme / Color</span>
                  <div class="color-swatch-row">
                    <span class="color-dot" [style.background-color]="colorCode.startsWith('#') ? colorCode : '#' + colorCode"></span>
                    <span class="tile-value font-mono">{{ colorCode }}</span>
                  </div>
                </div>
              </div>

              <!-- Vehicle Class -->
              <div class="info-tile">
                <div class="tile-icon-box">
                  <span class="material-symbols-outlined">airline_seat_recline_extra</span>
                </div>
                <div class="tile-text">
                  <span class="tile-label">Vehicle Class</span>
                  <span class="tile-value">Standard PHV / Hackney</span>
                </div>
              </div>

              <!-- Fleet Organization -->
              <div class="info-tile">
                <div class="tile-icon-box">
                  <span class="material-symbols-outlined">business</span>
                </div>
                <div class="tile-text">
                  <span class="tile-label">Fleet Operator</span>
                  <span class="tile-value">Red Taxis Ltd</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- 5. Compliance Licences & Certifications Hub -->
        <div class="section-card" id="compliance-section">
          <div class="section-card-header compliance-header">
            <div class="section-title-wrapper">
              <div class="section-icon-box green">
                <span class="material-symbols-outlined">verified_user</span>
              </div>
              <div class="section-title-col">
                <div class="title-with-badge">
                  <h2 class="section-title">Compliance Documents</h2>
                  <span class="compliance-score-chip" [ngClass]="getComplianceStatusClass()">
                    {{ getCompliancePercentage() }}% Compliant
                  </span>
                </div>
                <span class="section-subtitle">Required council, DVLA and insurance filings</span>
              </div>
            </div>
          </div>

          <!-- Overall Compliance Health Bar -->
          <div class="compliance-overview-bar">
            <div class="compliance-stats-row">
              <span class="stats-label">Verification Health</span>
              <span class="stats-counter">{{ getVerifiedCount() }} of {{ documents.length }} Active</span>
            </div>
            <div class="compliance-meter-track">
              <div 
                class="compliance-meter-fill"
                [ngClass]="getComplianceStatusClass()"
                [style.width.%]="getCompliancePercentage()"
              ></div>
            </div>
          </div>

          <!-- Document Filter Pills -->
          <div class="doc-filter-pills-row">
            <button 
              class="doc-filter-pill"
              [class.active]="selectedDocFilter === 'all'"
              (click)="selectedDocFilter = 'all'"
            >
              <span>All Documents</span>
              <span class="filter-count">{{ documents.length }}</span>
            </button>
            <button 
              class="doc-filter-pill"
              [class.active]="selectedDocFilter === 'action'"
              (click)="selectedDocFilter = 'action'"
            >
              <span class="status-dot red"></span>
              <span>Needs Action</span>
              <span class="filter-count">{{ getActionNeededCount() }}</span>
            </button>
            <button 
              class="doc-filter-pill"
              [class.active]="selectedDocFilter === 'verified'"
              (click)="selectedDocFilter = 'verified'"
            >
              <span class="status-dot green"></span>
              <span>Verified</span>
              <span class="filter-count">{{ getVerifiedCount() }}</span>
            </button>
          </div>

          <div class="section-card-body doc-list-body">
            <div class="documents-list">
              <div 
                *ngFor="let doc of getFilteredDocuments()" 
                (click)="onDocClick(doc)" 
                class="doc-item-row"
                [ngClass]="getDocStatusClass(doc.status)"
              >
                <!-- Left Accent Border -->
                <div class="doc-left-accent" [ngClass]="getDocStatusClass(doc.status)"></div>

                <!-- Document Icon -->
                <div class="doc-icon-wrapper" [ngClass]="getDocStatusClass(doc.status)">
                  <span class="material-symbols-outlined">{{ getDocIcon(doc.status) }}</span>
                </div>

                <!-- Document Info -->
                <div class="doc-main-info">
                  <div class="doc-title-row">
                    <span class="doc-name">{{ doc.name }}</span>
                  </div>
                  <div class="doc-expiry-row">
                    <span class="material-symbols-outlined expiry-icon">event</span>
                    <span class="doc-expiry-text">{{ getDocExpiryFormatted(doc) }}</span>
                  </div>
                </div>

                <!-- Status Action Chip & Arrow -->
                <div class="doc-action-col">
                  <span class="doc-status-badge" [ngClass]="getDocStatusClass(doc.status)">
                    {{ doc.status }}
                  </span>
                  <span class="material-symbols-outlined doc-chevron">chevron_right</span>
                </div>
              </div>

              <!-- Empty Filter State -->
              <div class="empty-docs-box" *ngIf="getFilteredDocuments().length === 0">
                <span class="material-symbols-outlined empty-icon">task_alt</span>
                <span class="empty-title">No documents in this view</span>
                <span class="empty-sub">All requirements in this category are up to date.</span>
              </div>
            </div>
          </div>
        </div>

      </div>

      <!-- 6. Document Preview & Inspection Modal -->
      <div class="preview-backdrop" *ngIf="isPreviewOpen && previewDoc" (click)="closePreview()">
        <div class="preview-modal-card" (click)="$event.stopPropagation()">
          <header class="preview-header">
            <div class="preview-header-titles">
              <h3 class="preview-title">{{ previewDoc.name }}</h3>
              <span class="preview-subtitle">Compliance Certificate Inspection</span>
            </div>
            <button class="close-modal-btn" (click)="closePreview()">
              <span class="material-symbols-outlined">close</span>
            </button>
          </header>
          
          <main class="preview-body">
            <!-- Status Badge Row -->
            <div class="preview-status-strip" [ngClass]="getDocStatusClass(previewDoc.status)">
              <div class="status-strip-left">
                <span class="material-symbols-outlined status-strip-icon">
                  {{ getDocIcon(previewDoc.status) }}
                </span>
                <div class="status-strip-text">
                  <span class="status-main-label">Status: {{ previewDoc.status }}</span>
                  <span class="status-expiry-label">{{ getDocExpiryFormatted(previewDoc) }}</span>
                </div>
              </div>
              <span class="doc-type-tag">Type {{ previewDoc.type }}</span>
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
                  <span class="placeholder-title">Document Pending Review</span>
                  <span class="placeholder-text">Uploaded certificate is undergoing automated and manual dispatch verification.</span>
                </div>
              </ng-template>
            </div>
          </main>
          
          <footer class="preview-footer">
            <button class="btn-cancel" (click)="closePreview()">Dismiss</button>
            <button class="btn-primary" (click)="reuploadFromPreview()">
              <span class="material-symbols-outlined">cloud_upload</span>
              <span>Update / Replace</span>
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
      padding: 16px 14px 48px 14px;
      max-width: 680px;
      margin: 0 auto;
      box-sizing: border-box;
      position: relative;
    }

    /* Pull-to-Refresh Floating Spinner */
    .floating-refresh-spinner {
      position: fixed;
      top: 0;
      left: 50%;
      width: 40px;
      height: 40px;
      border-radius: 50%;
      background: #FFFFFF;
      box-shadow: 0 6px 20px rgba(0, 0, 0, 0.16);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 999;
      pointer-events: none;
      transition: opacity 0.2s ease;
      color: #CD1A21;
    }
    .native-spin-icon {
      font-size: 24px;
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
      padding: 12px 14px;
      margin-bottom: 16px;
      border-radius: 12px;
      font-size: 13px;
      font-weight: 500;
      display: flex;
      align-items: center;
      gap: 10px;
      border: 1px solid rgba(185, 28, 28, 0.2);
    }

    /* Skeleton Loading State */
    .skeleton-hero-card {
      background: #FFFFFF;
      border-radius: 20px;
      padding: 20px;
      margin-bottom: 16px;
      display: flex;
      align-items: center;
      gap: 16px;
      border: 1px solid #E0E0E0;
    }
    .skeleton-avatar {
      width: 64px;
      height: 64px;
      border-radius: 50%;
      background: linear-gradient(90deg, #F0F2F5 25%, #E4E6EB 50%, #F0F2F5 75%);
      background-size: 200% 100%;
      animation: shimmer 1.5s infinite linear;
    }
    .skeleton-hero-lines {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .skeleton-line {
      background: linear-gradient(90deg, #F0F2F5 25%, #E4E6EB 50%, #F0F2F5 75%);
      background-size: 200% 100%;
      animation: shimmer 1.5s infinite linear;
      border-radius: 6px;
    }
    .skeleton-line.title { width: 60%; height: 18px; }
    .skeleton-line.subtitle { width: 40%; height: 12px; }
    .skeleton-line.pill { width: 30%; height: 20px; border-radius: 10px; }
    .skeleton-metrics-row {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 10px;
      margin-bottom: 16px;
    }
    .skeleton-metric-card {
      height: 80px;
      border-radius: 14px;
      background: linear-gradient(90deg, #F0F2F5 25%, #E4E6EB 50%, #F0F2F5 75%);
      background-size: 200% 100%;
      animation: shimmer 1.5s infinite linear;
    }
    .skeleton-card {
      background: #FFFFFF;
      border-radius: 16px;
      padding: 16px;
      margin-bottom: 16px;
      border: 1px solid #E0E0E0;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .skeleton-line.section-head { width: 35%; height: 16px; }
    .skeleton-row {
      height: 48px;
      border-radius: 10px;
      background: linear-gradient(90deg, #F0F2F5 25%, #E4E6EB 50%, #F0F2F5 75%);
      background-size: 200% 100%;
      animation: shimmer 1.5s infinite linear;
    }
    @keyframes shimmer {
      0% { background-position: 200% 0; }
      100% { background-position: -200% 0; }
    }

    /* 1. Hero Driver Card */
    .hero-profile-card {
      position: relative;
      background: linear-gradient(135deg, #111827 0%, #1F2937 60%, #111827 100%);
      color: #FFFFFF;
      border-radius: 22px;
      padding: 22px 20px 18px 20px;
      margin-bottom: 16px;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.18), 0 2px 6px rgba(0, 0, 0, 0.12);
      overflow: hidden;
      border: 1px solid rgba(255, 255, 255, 0.08);
    }
    .hero-ambient-glow {
      position: absolute;
      top: -40px;
      right: -40px;
      width: 180px;
      height: 180px;
      border-radius: 50%;
      filter: blur(50px);
      opacity: 0.35;
      pointer-events: none;
    }
    .hero-inner {
      position: relative;
      z-index: 2;
    }
    .hero-top-row {
      display: flex;
      align-items: center;
      gap: 16px;
      margin-bottom: 16px;
    }
    .avatar-wrapper {
      position: relative;
      flex-shrink: 0;
    }
    .avatar-ring {
      width: 66px;
      height: 66px;
      border-radius: 50%;
      border: 2px solid #CD1A21;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 3px;
      background: rgba(255, 255, 255, 0.05);
      box-shadow: 0 0 16px rgba(205, 26, 33, 0.35);
    }
    .avatar-circle {
      width: 100%;
      height: 100%;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 20px;
      font-weight: 700;
      color: #FFFFFF;
      letter-spacing: 0.5px;
    }
    .online-status-badge {
      position: absolute;
      bottom: 2px;
      right: 2px;
      width: 16px;
      height: 16px;
      border-radius: 50%;
      background: #10B981;
      border: 2px solid #111827;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .pulse-dot {
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background: #FFFFFF;
      animation: pulse 2s infinite ease-in-out;
    }
    @keyframes pulse {
      0%, 100% { transform: scale(1); opacity: 1; }
      50% { transform: scale(1.4); opacity: 0.7; }
    }

    .driver-identity-info {
      flex: 1;
      min-width: 0;
    }
    .name-with-badge {
      display: flex;
      align-items: center;
      gap: 6px;
      margin-bottom: 6px;
    }
    .driver-name {
      margin: 0;
      font-size: 20px;
      font-weight: 700;
      letter-spacing: -0.3px;
      color: #FFFFFF;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .verified-icon-badge {
      color: #38BDF8;
      display: flex;
      align-items: center;
    }
    .verified-icon-badge .material-symbols-outlined {
      font-size: 20px;
      font-variation-settings: 'FILL' 1;
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
      padding: 3px 8px;
      border-radius: 6px;
      font-size: 11px;
      font-weight: 600;
      letter-spacing: 0.2px;
    }
    .role-badge {
      background: rgba(205, 26, 33, 0.25);
      color: #FCA5A5;
      border: 1px solid rgba(205, 26, 33, 0.4);
    }
    .role-badge .pill-icon {
      font-size: 14px;
    }
    .id-badge {
      background: rgba(255, 255, 255, 0.1);
      color: #E2E8F0;
      border: 1px solid rgba(255, 255, 255, 0.12);
      font-family: monospace;
    }

    /* Hero Meta Bar */
    .hero-meta-bar {
      display: flex;
      align-items: center;
      gap: 12px;
      padding-top: 14px;
      border-top: 1px solid rgba(255, 255, 255, 0.1);
      font-size: 12px;
      color: #9CA3AF;
      flex-wrap: wrap;
    }
    .meta-item {
      display: flex;
      align-items: center;
      gap: 5px;
    }
    .meta-item.rating {
      color: #FDE047;
    }
    .meta-item.rating .star-icon {
      font-size: 16px;
      font-variation-settings: 'FILL' 1;
      color: #FACC15;
    }
    .meta-bold {
      font-weight: 700;
      color: #FFFFFF;
    }
    .meta-sub {
      color: #9CA3AF;
      font-size: 11px;
    }
    .meta-icon {
      font-size: 15px;
      color: #9CA3AF;
    }
    .meta-divider {
      width: 3px;
      height: 3px;
      border-radius: 50%;
      background: rgba(255, 255, 255, 0.25);
    }

    /* 2. Telemetry Grid */
    .telemetry-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 10px;
      margin-bottom: 16px;
    }
    .telemetry-card {
      background: #FFFFFF;
      border-radius: 16px;
      padding: 12px 10px;
      border: 1px solid rgba(0, 0, 0, 0.08);
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
      display: flex;
      flex-direction: column;
      gap: 8px;
      cursor: pointer;
      transition: transform 0.15s ease, box-shadow 0.15s ease;
    }
    .telemetry-card:active {
      transform: scale(0.98);
    }
    .telemetry-icon-wrapper {
      width: 32px;
      height: 32px;
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .telemetry-icon-wrapper .material-symbols-outlined {
      font-size: 18px;
    }
    .telemetry-icon-wrapper.green { background: #DCFCE7; color: #16A34A; }
    .telemetry-icon-wrapper.amber { background: #FEF3C7; color: #D97706; }
    .telemetry-icon-wrapper.red { background: #FEE2E2; color: #DC2626; }
    .telemetry-icon-wrapper.blue { background: #E0F2FE; color: #0284C7; }

    .telemetry-info {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .telemetry-label {
      font-size: 10px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.4px;
      color: #64748B;
    }
    .telemetry-value {
      font-size: 12px;
      font-weight: 700;
      color: #1E293B;
    }
    .text-ellipsis {
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .telemetry-progress-track {
      width: 100%;
      height: 4px;
      border-radius: 2px;
      background: #E2E8F0;
      margin-top: 4px;
      overflow: hidden;
    }
    .telemetry-progress-fill {
      height: 100%;
      border-radius: 2px;
      transition: width 0.4s ease;
    }
    .telemetry-progress-fill.green { background: #10B981; }
    .telemetry-progress-fill.amber { background: #F59E0B; }
    .telemetry-progress-fill.red { background: #EF4444; }

    .telemetry-sub-badge {
      font-size: 10px;
      font-weight: 700;
      font-family: monospace;
      color: #0F172A;
      background: #FEF08A;
      padding: 1px 4px;
      border-radius: 4px;
      display: inline-block;
      width: fit-content;
      margin-top: 2px;
    }
    .standing-status-pill {
      font-size: 9px;
      font-weight: 600;
      color: #16A34A;
      margin-top: 2px;
    }

    /* 3. Section Cards */
    .section-card {
      background: #FFFFFF;
      border-radius: 18px;
      border: 1px solid rgba(0, 0, 0, 0.08);
      box-shadow: 0 4px 14px rgba(0, 0, 0, 0.03);
      margin-bottom: 16px;
      overflow: hidden;
    }
    .section-card-header {
      padding: 16px 18px 12px 18px;
      border-bottom: 1px solid #F1F5F9;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .section-title-wrapper {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .section-icon-box {
      width: 36px;
      height: 36px;
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .section-icon-box .material-symbols-outlined {
      font-size: 20px;
    }
    .section-icon-box.red { background: #FEE2E2; color: #DC2626; }
    .section-icon-box.purple { background: #F3E8FF; color: #9333EA; }
    .section-icon-box.green { background: #DCFCE7; color: #16A34A; }

    .section-title-col {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .section-title {
      margin: 0;
      font-size: 15px;
      font-weight: 700;
      color: #0F172A;
      letter-spacing: -0.2px;
    }
    .section-subtitle {
      font-size: 11px;
      color: #64748B;
    }
    .section-card-body {
      padding: 14px 16px 16px 16px;
    }

    /* Info Tiles Grid */
    .info-tiles-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 10px;
    }
    @media (max-width: 480px) {
      .info-tiles-grid {
        grid-template-columns: 1fr;
      }
    }
    .info-tile {
      background: #F8FAFC;
      border: 1px solid #E2E8F0;
      border-radius: 12px;
      padding: 10px 12px;
      display: flex;
      align-items: center;
      gap: 10px;
      position: relative;
      transition: background 0.15s ease;
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
      font-size: 20px;
    }
    .tile-text {
      flex: 1;
      display: flex;
      flex-direction: column;
      min-width: 0;
    }
    .tile-label {
      font-size: 10px;
      font-weight: 600;
      color: #64748B;
      text-transform: uppercase;
      letter-spacing: 0.3px;
    }
    .tile-value {
      font-size: 13px;
      font-weight: 600;
      color: #1E293B;
      margin-top: 1px;
    }
    .tile-value.empty-text {
      color: #94A3B8;
      font-style: italic;
    }
    .font-mono {
      font-family: monospace;
    }
    .tile-action-btn {
      background: transparent;
      border: none;
      color: #94A3B8;
      padding: 4px;
      border-radius: 6px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .tile-action-btn .material-symbols-outlined {
      font-size: 16px;
    }
    .tile-action-btn:hover {
      color: #0F172A;
      background: rgba(0,0,0,0.05);
    }

    /* Color Swatch in Tile */
    .color-swatch-row {
      display: flex;
      align-items: center;
      gap: 6px;
      margin-top: 1px;
    }
    .color-dot {
      width: 12px;
      height: 12px;
      border-radius: 50%;
      border: 1px solid rgba(0,0,0,0.15);
      flex-shrink: 0;
    }

    /* UK License Plate Display */
    .license-plate-showcase {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 8px;
      padding: 14px 10px;
      background: #F8FAFC;
      border-radius: 14px;
      border: 1px dashed #CBD5E1;
    }
    .uk-number-plate-large {
      display: inline-flex;
      align-items: center;
      background: #FFD500;
      color: #000000;
      border: 2.5px solid #000000;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.12), inset 0 1px 0 rgba(255, 255, 255, 0.6);
      overflow: hidden;
      font-family: 'Charles Wright', 'Impact', 'Arial Black', sans-serif;
      font-weight: 900;
      letter-spacing: 3px;
    }
    .uk-plate-flag-strip {
      background: #003399;
      color: #FFD500;
      padding: 8px 10px;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
    }
    .plate-uk-text {
      font-size: 11px;
      font-weight: 900;
      color: #FFFFFF;
      letter-spacing: 0.5px;
    }
    .uk-plate-digits {
      font-size: 22px;
      padding: 6px 18px;
      text-transform: uppercase;
    }
    .plate-registered-label {
      display: flex;
      align-items: center;
      gap: 5px;
      font-size: 11px;
      font-weight: 600;
      color: #16A34A;
    }
    .plate-registered-label .material-symbols-outlined {
      font-size: 15px;
    }
    .no-vehicle-banner {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 12px;
      border-radius: 10px;
      background: #F1F5F9;
      color: #64748B;
      font-size: 12px;
      font-weight: 500;
    }

    /* 5. Compliance Section & Health Bar */
    .title-with-badge {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .compliance-score-chip {
      padding: 2px 8px;
      border-radius: 12px;
      font-size: 10px;
      font-weight: 700;
      letter-spacing: 0.2px;
    }
    .compliance-score-chip.green { background: #DCFCE7; color: #15803D; }
    .compliance-score-chip.amber { background: #FEF3C7; color: #B45309; }
    .compliance-score-chip.red { background: #FEE2E2; color: #B91C1C; }

    .compliance-overview-bar {
      padding: 12px 18px;
      background: #F8FAFC;
      border-bottom: 1px solid #F1F5F9;
    }
    .compliance-stats-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 6px;
      font-size: 12px;
    }
    .stats-label {
      font-weight: 600;
      color: #475569;
    }
    .stats-counter {
      font-weight: 700;
      color: #0F172A;
    }
    .compliance-meter-track {
      width: 100%;
      height: 6px;
      border-radius: 3px;
      background: #E2E8F0;
      overflow: hidden;
    }
    .compliance-meter-fill {
      height: 100%;
      border-radius: 3px;
      transition: width 0.5s cubic-bezier(0.4, 0, 0.2, 1);
    }
    .compliance-meter-fill.green { background: linear-gradient(90deg, #10B981, #059669); }
    .compliance-meter-fill.amber { background: linear-gradient(90deg, #F59E0B, #D97706); }
    .compliance-meter-fill.red { background: linear-gradient(90deg, #EF4444, #DC2626); }

    /* Filter Pills */
    .doc-filter-pills-row {
      display: flex;
      gap: 6px;
      padding: 12px 18px 6px 18px;
      overflow-x: auto;
    }
    .doc-filter-pill {
      background: #F1F5F9;
      border: 1px solid #E2E8F0;
      padding: 5px 10px;
      border-radius: 20px;
      font-size: 11px;
      font-weight: 600;
      color: #475569;
      display: flex;
      align-items: center;
      gap: 5px;
      cursor: pointer;
      white-space: nowrap;
      transition: all 0.15s ease;
    }
    .doc-filter-pill.active {
      background: #0F172A;
      color: #FFFFFF;
      border-color: #0F172A;
    }
    .filter-count {
      background: rgba(0, 0, 0, 0.08);
      padding: 1px 5px;
      border-radius: 10px;
      font-size: 10px;
    }
    .doc-filter-pill.active .filter-count {
      background: rgba(255, 255, 255, 0.2);
    }
    .status-dot {
      width: 6px;
      height: 6px;
      border-radius: 50%;
    }
    .status-dot.green { background: #10B981; }
    .status-dot.red { background: #EF4444; }

    /* Document Item Row */
    .documents-list {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .doc-item-row {
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 14px;
      padding: 12px 14px;
      display: flex;
      align-items: center;
      gap: 12px;
      position: relative;
      overflow: hidden;
      cursor: pointer;
      transition: transform 0.12s ease, box-shadow 0.12s ease, border-color 0.12s ease;
    }
    .doc-item-row:active {
      transform: scale(0.985);
      background: #F8FAFC;
    }
    .doc-left-accent {
      position: absolute;
      left: 0;
      top: 0;
      bottom: 0;
      width: 4px;
    }
    .doc-left-accent.valid { background: #10B981; }
    .doc-left-accent.expiring-soon { background: #F59E0B; }
    .doc-left-accent.expired { background: #EF4444; }
    .doc-left-accent.pending-verification { background: #6366F1; }
    .doc-left-accent.missing { background: #94A3B8; }

    .doc-icon-wrapper {
      width: 36px;
      height: 36px;
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }
    .doc-icon-wrapper .material-symbols-outlined {
      font-size: 20px;
    }
    .doc-icon-wrapper.valid { background: #DCFCE7; color: #15803D; }
    .doc-icon-wrapper.expiring-soon { background: #FEF3C7; color: #B45309; }
    .doc-icon-wrapper.expired { background: #FEE2E2; color: #B91C1C; }
    .doc-icon-wrapper.pending-verification { background: #EEF2FF; color: #4F46E5; }
    .doc-icon-wrapper.missing { background: #F1F5F9; color: #64748B; }

    .doc-main-info {
      flex: 1;
      min-width: 0;
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .doc-name {
      font-size: 13px;
      font-weight: 600;
      color: #0F172A;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .doc-expiry-row {
      display: flex;
      align-items: center;
      gap: 4px;
      font-size: 11px;
      color: #64748B;
    }
    .expiry-icon {
      font-size: 13px;
      color: #94A3B8;
    }
    .doc-action-col {
      display: flex;
      align-items: center;
      gap: 6px;
      flex-shrink: 0;
    }
    .doc-status-badge {
      font-size: 10px;
      font-weight: 700;
      padding: 3px 8px;
      border-radius: 8px;
      letter-spacing: 0.3px;
      text-transform: uppercase;
    }
    .doc-status-badge.valid { background: #DCFCE7; color: #166534; }
    .doc-status-badge.expiring-soon { background: #FEF3C7; color: #92400E; }
    .doc-status-badge.expired { background: #FEE2E2; color: #991B1B; }
    .doc-status-badge.pending-verification { background: #EEF2FF; color: #3730A3; }
    .doc-status-badge.missing { background: #E2E8F0; color: #334155; }

    .doc-chevron {
      font-size: 18px;
      color: #94A3B8;
    }

    .empty-docs-box {
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
      padding: 28px 16px;
      gap: 6px;
    }
    .empty-docs-box .empty-icon {
      font-size: 36px;
      color: #10B981;
    }
    .empty-title {
      font-size: 13px;
      font-weight: 600;
      color: #0F172A;
    }
    .empty-sub {
      font-size: 11px;
      color: #64748B;
    }

    /* 6. Document Preview Modal */
    .preview-backdrop {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(15, 23, 42, 0.65);
      backdrop-filter: blur(6px);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 1000;
      padding: 16px;
      animation: fadeIn 0.2s ease-out;
    }
    .preview-modal-card {
      background: #FFFFFF;
      border-radius: 20px;
      max-width: 520px;
      width: 100%;
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.25);
      overflow: hidden;
      display: flex;
      flex-direction: column;
      animation: scaleUp 0.25s cubic-bezier(0.16, 1, 0.3, 1);
    }
    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }
    @keyframes scaleUp {
      from { opacity: 0; transform: scale(0.92); }
      to { opacity: 1; transform: scale(1); }
    }
    .preview-header {
      padding: 16px 20px;
      border-bottom: 1px solid #E2E8F0;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .preview-title {
      margin: 0;
      font-size: 15px;
      font-weight: 700;
      color: #0F172A;
    }
    .preview-subtitle {
      font-size: 11px;
      color: #64748B;
    }
    .close-modal-btn {
      background: #F1F5F9;
      border: none;
      width: 32px;
      height: 32px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      color: #64748B;
    }
    .close-modal-btn:hover {
      background: #E2E8F0;
      color: #0F172A;
    }
    .preview-body {
      padding: 16px 20px;
      display: flex;
      flex-direction: column;
      gap: 14px;
    }
    .preview-status-strip {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 10px 12px;
      border-radius: 12px;
    }
    .preview-status-strip.valid { background: #DCFCE7; color: #166534; }
    .preview-status-strip.expiring-soon { background: #FEF3C7; color: #92400E; }
    .preview-status-strip.expired { background: #FEE2E2; color: #991B1B; }
    .preview-status-strip.pending-verification { background: #EEF2FF; color: #3730A3; }
    .preview-status-strip.missing { background: #F1F5F9; color: #475569; }

    .status-strip-left {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .status-strip-icon {
      font-size: 20px;
    }
    .status-strip-text {
      display: flex;
      flex-direction: column;
    }
    .status-main-label {
      font-size: 12px;
      font-weight: 700;
    }
    .status-expiry-label {
      font-size: 11px;
      opacity: 0.85;
    }
    .doc-type-tag {
      font-size: 10px;
      font-weight: 700;
      background: rgba(0, 0, 0, 0.08);
      padding: 2px 6px;
      border-radius: 6px;
    }

    .preview-image-container {
      position: relative;
      min-height: 220px;
      max-height: 360px;
      background: #F8FAFC;
      border: 1px solid #E2E8F0;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      overflow: hidden;
    }
    .preview-image {
      max-width: 100%;
      max-height: 360px;
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
      padding: 24px 16px;
      gap: 6px;
    }
    .placeholder-icon {
      font-size: 40px;
      color: #94A3B8;
    }
    .placeholder-title {
      font-size: 13px;
      font-weight: 600;
      color: #0F172A;
    }
    .placeholder-text {
      font-size: 11px;
      color: #64748B;
      line-height: 1.4;
      max-width: 280px;
    }

    .preview-footer {
      padding: 14px 20px;
      border-top: 1px solid #E2E8F0;
      display: flex;
      justify-content: flex-end;
      gap: 10px;
    }
    .btn-cancel {
      background: #F1F5F9;
      border: 1px solid #CBD5E1;
      padding: 9px 16px;
      border-radius: 10px;
      font-size: 13px;
      font-weight: 600;
      color: #475569;
      cursor: pointer;
    }
    .btn-primary {
      background: linear-gradient(135deg, #CD1A21 0%, #B71C1C 100%);
      color: #FFFFFF;
      border: none;
      padding: 9px 18px;
      border-radius: 10px;
      font-size: 13px;
      font-weight: 600;
      display: flex;
      align-items: center;
      gap: 6px;
      cursor: pointer;
      box-shadow: 0 4px 12px rgba(205, 26, 33, 0.28);
    }
    .btn-primary .material-symbols-outlined {
      font-size: 18px;
    }

    /* Animations */
    .animated-fade-in {
      animation: fadeIn 0.3s ease-in-out;
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
    :host-context(.dark-theme) .telemetry-card {
      background: #1E1E24;
      border-color: #2D2D35;
      box-shadow: 0 4px 14px rgba(0, 0, 0, 0.25);
    }
    :host-context(.dark-theme) .telemetry-label {
      color: #94A3B8;
    }
    :host-context(.dark-theme) .telemetry-value {
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .telemetry-progress-track {
      background: #2D2D35;
    }
    :host-context(.dark-theme) .section-card {
      background: #1E1E24;
      border-color: #2D2D35;
      box-shadow: 0 4px 14px rgba(0, 0, 0, 0.25);
    }
    :host-context(.dark-theme) .section-card-header {
      border-bottom-color: #2D2D35;
    }
    :host-context(.dark-theme) .section-title {
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .section-subtitle {
      color: #94A3B8;
    }
    :host-context(.dark-theme) .info-tile {
      background: #16161A;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .tile-value {
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .license-plate-showcase {
      background: #16161A;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .compliance-overview-bar {
      background: #16161A;
      border-bottom-color: #2D2D35;
    }
    :host-context(.dark-theme) .stats-label {
      color: #94A3B8;
    }
    :host-context(.dark-theme) .stats-counter {
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .compliance-meter-track {
      background: #2D2D35;
    }
    :host-context(.dark-theme) .doc-filter-pill {
      background: #16161A;
      border-color: #2D2D35;
      color: #94A3B8;
    }
    :host-context(.dark-theme) .doc-filter-pill.active {
      background: #ECEFF1;
      color: #121214;
      border-color: #ECEFF1;
    }
    :host-context(.dark-theme) .doc-item-row {
      background: #16161A;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .doc-name {
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .doc-expiry-row {
      color: #94A3B8;
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
    :host-context(.dark-theme) .close-modal-btn {
      background: #2D2D35;
      color: #94A3B8;
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
  driverName = 'Peter Parker';
  driverEmail = 'peter.parker@redtaxis.com';
  driverPhone = '+44 7911 123456';
  vehicleModel = 'Toyota Prius (Hybrid)';
  plateNumber = 'LK17 WXY';
  colorCode = '';
  lastLogin: string | null = null;
  driverId: number | null = null;

  selectedDocFilter: 'all' | 'action' | 'verified' = 'all';

  // Pull to refresh variables
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
        
        this.driverName = profile.fullname || profile.fullName || profile.name || 'Not Registered';
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

  // --- Calculations & Formatting Helpers ---
  getInitials(): string {
    if (!this.driverName || this.driverName === 'Not Registered') return 'DR';
    const parts = this.driverName.trim().split(/\s+/);
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return this.driverName.substring(0, 2).toUpperCase();
  }

  getFormattedDriverId(): string {
    if (this.driverId) return `#DRV-${this.driverId}`;
    return '#DRV-8492';
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

  getComplianceIcon(): string {
    const p = this.getCompliancePercentage();
    if (p >= 80) return 'verified_user';
    if (p >= 40) return 'warning';
    return 'gpp_bad';
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
    if (doc.status === 'Missing' || doc.expiry === 'Not Uploaded') return 'Not uploaded yet • Tap to submit';
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

  getAccentColor(): string {
    return this.colorCode ? (this.colorCode.startsWith('#') ? this.colorCode : '#' + this.colorCode) : '#CD1A21';
  }

  getAmbientGlowStyle(): string {
    const color = this.getAccentColor();
    return `radial-gradient(circle, ${color} 0%, transparent 70%)`;
  }

  copyToClipboard(text: string, message: string): void {
    if (!text || text === 'Not Registered') return;
    navigator.clipboard.writeText(text).then(() => {
      this.snackBar.open(message, 'OK', {
        duration: 2200,
        horizontalPosition: 'center',
        verticalPosition: 'bottom'
      });
    }).catch(err => {
      console.warn('Clipboard write error:', err);
    });
  }

  scrollToCompliance(): void {
    const el = document.getElementById('compliance-section');
    if (el) {
      el.scrollIntoView({ behavior: 'smooth' });
    }
  }

  // --- Touch Gestures (Pull-to-Refresh) ---
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
        this.pullDistance = Math.min(distance * 0.45, 80);
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

  // --- Navigation & Document Modal ---
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
