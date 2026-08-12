import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { MatCardModule } from '@angular/material/card';
import { MatListModule } from '@angular/material/list';
import { MatIconModule } from '@angular/material/icon';
import { MatSlideToggleModule } from '@angular/material/slide-toggle';
import { MatDividerModule } from '@angular/material/divider';
import { MatButtonModule } from '@angular/material/button';
import { DriverService } from '../services/driver.service';
import { catchError } from 'rxjs/operators';
import { of } from 'rxjs';

interface DriverDoc {
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
    MatListModule,
    MatIconModule,
    MatSlideToggleModule,
    MatDividerModule,
    MatButtonModule
  ],
  template: `
    <div class="material-container">
      <!-- Staging Diagnostics Alert Banner -->
      <div class="error-banner" *ngIf="apiError" style="background-color: #ffebee; color: #c62828; padding: 12px; margin: 0 0 16px 0; border-radius: 12px; font-size: 13px; font-weight: 500; display: flex; align-items: center; gap: 8px; border: 1px solid rgba(198, 40, 40, 0.15);">
        <span class="material-symbols-outlined" style="font-size: 20px;">error</span>
        <span>{{ apiError }}</span>
      </div>

      <!-- Loading Skeleton Loader -->
      <div *ngIf="isLoading" class="skeleton-container animated-fade-in">
        <!-- Skeleton Header Card -->
        <mat-card class="section-card" style="padding: 16px; margin-bottom: 20px; display: flex; align-items: center; gap: 16px; background-color: #FFFFFF; border: 1px solid var(--border-color); border-radius: 12px;">
          <div class="skeleton skeleton-avatar"></div>
          <div style="display: flex; flex-direction: column; gap: 8px;">
            <div class="skeleton skeleton-text title"></div>
            <div class="skeleton skeleton-text subtitle" style="width: 90px; height: 12px;"></div>
          </div>
        </mat-card>

        <!-- Skeleton Details Card -->
        <mat-card class="section-card" style="padding: 16px; margin-bottom: 20px; border: 1px solid var(--border-color); border-radius: 12px; background-color: #FFFFFF;">
          <div style="margin-bottom: 16px;" *ngFor="let i of [1, 2, 3, 4]">
            <div class="skeleton skeleton-text lbl" style="margin-bottom: 4px;"></div>
            <div class="skeleton skeleton-text val"></div>
          </div>
        </mat-card>

        <!-- Skeleton Compliance Card -->
        <mat-card class="section-card" style="padding: 16px; border: 1px solid var(--border-color); border-radius: 12px; background-color: #FFFFFF;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;" *ngFor="let i of [1, 2, 3]">
            <div style="display: flex; align-items: center; gap: 12px;">
              <div class="skeleton" style="width: 24px; height: 24px; border-radius: 50%;"></div>
              <div>
                <div class="skeleton" style="width: 140px; height: 12px; margin-bottom: 4px;"></div>
                <div class="skeleton" style="width: 80px; height: 10px;"></div>
              </div>
            </div>
            <div class="skeleton" style="width: 60px; height: 20px; border-radius: 10px;"></div>
          </div>
        </mat-card>
      </div>

      <!-- Loaded Content -->
      <div *ngIf="!isLoading" class="profile-loaded-content animated-fade-in">
        <!-- Profile Header -->
        <mat-card class="profile-header-card" [style.background]="getBackgroundStyle()">
          <mat-card-content class="header-content">
            <div class="avatar-container">
              <div class="avatar-circle" [style.background-color]="colorCode ? (colorCode.startsWith('#') ? colorCode : '#' + colorCode) : 'rgba(255, 255, 255, 0.15)'">
                <span class="material-symbols-outlined person-avatar-icon">person</span>
              </div>
            </div>
            <div class="profile-identity">
              <h2 class="mat-headline-small name-title">{{ driverName }}</h2>
              <span class="badge-pill role-badge">Red Taxis Driver</span>
              <div class="stats-row" *ngIf="lastLogin">
                <span class="stat"><mat-icon class="star-icon">schedule</mat-icon> Last Login: {{ lastLogin | date:'d MMM y, HH:mm' }}</span>
              </div>
            </div>
          </mat-card-content>
        </mat-card>

        <!-- Details List -->
        <main class="profile-content">
          <!-- Account & Vehicle Details Redesign -->
          <div class="details-dashboard-grid">
            <!-- Left Info Block: Account Profile -->
            <mat-card class="details-block-card">
              <mat-card-header class="block-header">
                <span class="material-symbols-outlined block-header-icon">account_circle</span>
                <mat-card-title class="block-title">Driver Profile</mat-card-title>
              </mat-card-header>
              <mat-card-content class="block-content">
                <div class="info-row">
                  <div class="info-icon-wrapper">
                    <span class="material-symbols-outlined info-icon">mail</span>
                  </div>
                  <div class="info-text">
                    <span class="info-label">Email Address</span>
                    <span class="info-value">{{ driverEmail }}</span>
                  </div>
                </div>
                <div class="info-divider"></div>
                <div class="info-row">
                  <div class="info-icon-wrapper">
                    <span class="material-symbols-outlined info-icon">call</span>
                  </div>
                  <div class="info-text">
                    <span class="info-label">Contact Number</span>
                    <span class="info-value">{{ driverPhone }}</span>
                  </div>
                </div>
              </mat-card-content>
            </mat-card>

            <!-- Right Info Block: Vehicle Information -->
            <mat-card class="details-block-card">
              <mat-card-header class="block-header">
                <span class="material-symbols-outlined block-header-icon">local_taxi</span>
                <mat-card-title class="block-title">Vehicle Details</mat-card-title>
              </mat-card-header>
              <mat-card-content class="block-content">
                <!-- Vehicle Model -->
                <div class="info-row">
                  <div class="info-icon-wrapper">
                    <span class="material-symbols-outlined info-icon font-taxi">airport_shuttle</span>
                  </div>
                  <div class="info-text">
                    <span class="info-label">Assigned Vehicle</span>
                    <span class="info-value" [ngClass]="{'empty-state-text': vehicleModel === 'No Vehicle Registered'}">
                      {{ vehicleModel }}
                    </span>
                  </div>
                </div>
                
                <div class="info-divider"></div>
                
                <!-- Plate & Theme color grid -->
                <div class="vehicle-sub-grid">
                  <!-- Plate -->
                  <div class="sub-info-block">
                    <span class="info-label">License Plate</span>
                    <div class="uk-license-plate" *ngIf="plateNumber && plateNumber !== 'No Plate'; else noPlateBadge">
                      <div class="plate-eu-strip">
                        <span class="plate-eu-text">UK</span>
                      </div>
                      <span class="plate-number-text">{{ plateNumber }}</span>
                    </div>
                    <ng-template #noPlateBadge>
                      <span class="empty-badge">Unassigned</span>
                    </ng-template>
                  </div>
                  
                  <!-- Theme Color -->
                  <div class="sub-info-block" *ngIf="colorCode">
                    <span class="info-label">System Theme</span>
                    <div class="color-palette-tag">
                      <span class="color-tag-dot" [style.background-color]="colorCode.startsWith('#') ? colorCode : '#' + colorCode"></span>
                      <span class="color-tag-hex">{{ colorCode }}</span>
                    </div>
                  </div>
                </div>
              </mat-card-content>
            </mat-card>
          </div>

          <!-- Document Verification -->
          <mat-card class="section-card">
            <mat-card-header class="section-header" style="flex-direction: column; align-items: stretch; gap: 10px; padding: 16px 16px 8px 16px !important;">
              <div style="display: flex; justify-content: space-between; align-items: center; width: 100%;">
                <mat-card-title class="section-title" style="margin: 0 !important;">Compliance Documents</mat-card-title>
                <span class="progress-badge">{{ getVerifiedCount() }} of {{ documents.length }} Verified</span>
              </div>
              <div class="compliance-progress-bar">
                <div class="compliance-progress-fill" [style.width.%]="(getVerifiedCount() / documents.length) * 100"></div>
              </div>
            </mat-card-header>
            <mat-card-content class="section-body" style="padding: 8px 16px 16px 16px !important;">
              <div class="document-grid">
                <div 
                  *ngFor="let doc of documents" 
                  (click)="onDocClick(doc)" 
                  class="doc-row-card clickable-item"
                  [ngClass]="doc.status.toLowerCase().replace(' ', '-')"
                >
                  <div class="doc-row-left-accent" [ngClass]="doc.status.toLowerCase().replace(' ', '-')"></div>
                  
                  <div class="doc-row-content">
                    <div style="display: flex; align-items: center; gap: 12px; overflow: hidden; flex: 1;">
                      <span 
                        class="material-symbols-outlined doc-row-icon"
                        [ngClass]="doc.status.toLowerCase().replace(' ', '-')"
                      >
                        {{ doc.status === 'Valid' ? 'check_circle' : doc.status === 'Expiring Soon' ? 'warning' : doc.status === 'Expired' ? 'cancel' : doc.status === 'Pending Verification' ? 'hourglass_top' : 'help_clinic' }}
                      </span>
                      <div class="doc-meta-info" style="display: flex; flex-direction: column; overflow: hidden;">
                        <span class="doc-row-title">{{ doc.name }}</span>
                        <span class="doc-row-subtitle">
                          {{ doc.expiry === 'Not Uploaded' ? 'Not Uploaded yet' : doc.expiry === 'Under Review' ? 'Under Review' : 'Expires ' + doc.expiry }}
                        </span>
                      </div>
                    </div>
                    
                    <div style="display: flex; align-items: center; gap: 8px; flex-shrink: 0;">
                      <span class="status-chip-badge" [ngClass]="doc.status.toLowerCase().replace(' ', '-')">
                        {{ doc.status }}
                      </span>
                      <span class="material-symbols-outlined doc-chevron">chevron_right</span>
                    </div>
                  </div>
                </div>
              </div>
            </mat-card-content>
          </mat-card>

          <!-- Preferences -->
          <mat-card class="section-card">
            <mat-card-header class="section-header">
              <mat-card-title class="section-title">Preferences</mat-card-title>
            </mat-card-header>
            <mat-card-content class="pref-content">
              <div class="preference-row">
                <div class="pref-text">
                  <span class="pref-title">Auto-Accept Job Offers</span>
                  <span class="pref-desc">Automatically accept incoming matching bookings.</span>
                </div>
                <mat-slide-toggle [checked]="autoAccept" (change)="toggleAutoAccept()" color="primary" class="custom-toggle"></mat-slide-toggle>
              </div>
              <mat-divider></mat-divider>
              <div class="preference-row">
                <div class="pref-text">
                  <span class="pref-title">Accept Night Shifts</span>
                  <span class="pref-desc">Receive notifications for trips between 22:00 and 06:00.</span>
                </div>
                <mat-slide-toggle [checked]="nightShifts" (change)="toggleNightShifts()" color="primary" class="custom-toggle"></mat-slide-toggle>
              </div>
            </mat-card-content>
          </mat-card>

          <!-- Logout Button -->
          <button mat-flat-button color="warn" class="logout-btn" (click)="logout()">
            <span class="material-symbols-outlined btn-icon">logout</span>
            Sign Out / Clear Session
          </button>
        </main>
      </div>

      <!-- Premium Glassmorphism Preview Modal -->
      <div class="preview-backdrop" *ngIf="isPreviewOpen && previewDoc" (click)="closePreview()">
        <div class="preview-modal-card" (click)="$event.stopPropagation()">
          <header class="preview-header">
            <h3 class="preview-title">{{ previewDoc.name }}</h3>
            <button class="close-modal-btn" (click)="closePreview()">
              <span class="material-symbols-outlined">close</span>
            </button>
          </header>
          
          <main class="preview-body">
            <!-- Status Badge Row -->
            <div class="preview-status-row" [ngClass]="previewDoc.status.toLowerCase().replace(' ', '-')">
              <span class="material-symbols-outlined status-icon">
                {{ previewDoc.status === 'Valid' ? 'check_circle' : previewDoc.status === 'Expiring Soon' ? 'warning' : previewDoc.status === 'Expired' ? 'cancel' : 'hourglass_top' }}
              </span>
              <div class="status-details">
                <span class="status-title">Status: {{ previewDoc.status }}</span>
                <span class="status-subtitle">
                  {{ previewDoc.expiry === 'Under Review' ? 'Under Review' : 'Expires ' + previewDoc.expiry }}
                </span>
              </div>
            </div>

            <!-- Image View -->
            <div class="preview-image-container">
              <ng-container *ngIf="previewDoc.url; else noPreview">
                <img [src]="previewDoc.url" alt="Document Preview" class="preview-image" (load)="onPreviewImageLoaded()" />
                <div class="preview-shimmer" *ngIf="isPreviewLoading"></div>
              </ng-container>
              <ng-template #noPreview>
                <div class="no-preview-placeholder">
                  <span class="material-symbols-outlined placeholder-icon">description</span>
                  <span class="placeholder-text">Document submitted. Preview will be available once verification completes.</span>
                </div>
              </ng-template>
            </div>
          </main>
          
          <footer class="preview-footer">
            <button mat-stroked-button class="close-btn" (click)="closePreview()">Close</button>
            <button mat-flat-button color="primary" class="reupload-btn" (click)="reuploadFromPreview()">
              <span class="material-symbols-outlined">cloud_upload</span> Update Document
            </button>
          </footer>
        </div>
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

    /* Profile Header Card */
    .profile-header-card {
      background: linear-gradient(135deg, var(--primary-color) 0%, var(--primary-dark) 100%);
      color: #FFFFFF;
      border-radius: 16px !important;
      margin-bottom: 20px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05) !important;
    }
    .header-content {
      display: flex;
      align-items: center;
      gap: 16px;
      padding: 16px !important;
    }
    .avatar-container {
      flex-shrink: 0;
    }
    .avatar-circle {
      width: 56px;
      height: 56px;
      background-color: rgba(255, 255, 255, 0.15);
      border: 1.5px solid rgba(255, 255, 255, 0.35);
      border-radius: 50%;
      display: flex;
      justify-content: center;
      align-items: center;
    }
    .person-avatar-icon {
      font-size: 32px;
      color: #FFFFFF;
    }
    .name-title {
      margin: 0 0 4px 0;
      color: #FFFFFF;
      font-weight: 700;
      font-size: 20px;
    }
    .badge-pill {
      font-size: 9px;
      font-weight: 700;
      padding: 2px 8px;
      border-radius: 12px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .role-badge {
      background-color: rgba(255, 255, 255, 0.12);
      border: 1px solid rgba(255, 255, 255, 0.2);
    }
    .stats-row {
      display: flex;
      align-items: center;
      gap: 6px;
      margin-top: 6px;
      font-size: 11px;
      opacity: 0.9;
    }
    .star-icon {
      color: #FFD700;
      font-size: 13px;
      width: 13px;
      height: 13px;
      vertical-align: middle;
    }
    .divider-dot {
      opacity: 0.5;
    }

    /* Section Cards */
    .profile-content {
      display: flex;
      flex-direction: column;
      gap: 16px;
    }
    .section-card {
      border: 1px solid var(--border-color);
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.02) !important;
      border-radius: 12px !important;
      background-color: var(--surface-color);
    }
    .section-header {
      padding: 14px 16px 8px 16px !important;
    }
    .section-title {
      font-size: 11px !important;
      font-weight: 800 !important;
      color: var(--text-secondary);
      text-transform: uppercase;
      letter-spacing: 0.8px;
    }
    .section-body {
      padding: 0 !important;
    }
    
    .compact-list {
      padding: 0 !important;
    }
    .profile-list-item {
      height: auto !important;
      padding: 10px 16px !important;
    }
    .item-icon {
      font-size: 20px;
      color: var(--text-secondary);
    }
    .item-icon.valid {
      color: #4CAF50;
    }
    .item-icon.expiring-soon {
      color: #FF9800;
    }
     .item-icon.expired {
      color: #F44336;
    }
    .item-icon.missing {
      color: #90A4AE;
    }

    .item-lbl {
      color: var(--text-secondary);
      font-size: 10px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-bottom: 2px;
    }
    .item-val {
      color: var(--text-primary);
      font-weight: 500;
      font-size: 13px;
    }
    .font-semibold {
      font-weight: 600 !important;
    }
    .highlight-plate {
      background-color: #FFEB3B;
      color: #212121;
      padding: 2px 8px;
      border-radius: 4px;
      display: inline-block;
      font-family: monospace;
      font-weight: 800;
      font-size: 12px;
      border: 1px solid #FBC02D;
      letter-spacing: 0.5px;
    }

    /* Documents Grid & Cards Styling */
    .progress-badge {
      font-size: 11px;
      font-weight: 700;
      color: var(--primary-color);
      background-color: rgba(33, 150, 243, 0.08);
      padding: 2px 8px;
      border-radius: 8px;
      letter-spacing: 0.2px;
    }
    .compliance-progress-bar {
      width: 100%;
      height: 6px;
      background-color: #ECEFF1;
      border-radius: 3px;
      overflow: hidden;
      margin-top: 4px;
    }
    .compliance-progress-fill {
      height: 100%;
      background: linear-gradient(90deg, #4CAF50, #81C784);
      transition: width 0.3s ease;
      border-radius: 3px;
    }
    .document-grid {
      display: flex;
      flex-direction: column;
      gap: 10px;
      width: 100%;
    }
    .doc-row-card {
      position: relative;
      overflow: hidden;
      background-color: #FFFFFF;
      border: 1px solid var(--border-color);
      border-radius: 12px;
      transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
      cursor: pointer;
      display: flex;
      box-shadow: 0 1px 2px rgba(0, 0, 0, 0.02);
    }
    .doc-row-card:hover {
      transform: translateY(-1px);
      box-shadow: 0 4px 8px rgba(0, 0, 0, 0.04);
      border-color: rgba(33, 150, 243, 0.3);
    }
    .doc-row-left-accent {
      position: absolute;
      top: 0;
      left: 0;
      bottom: 0;
      width: 4px;
    }
    .doc-row-left-accent.valid {
      background-color: #388E3C;
    }
    .doc-row-left-accent.expiring-soon {
      background-color: #F57C00;
    }
    .doc-row-left-accent.expired {
      background-color: #D32F2F;
    }
    .doc-row-left-accent.pending-verification {
      background-color: #1976D2;
    }
    .doc-row-left-accent.missing {
      background-color: #CFD8DC;
    }

    .doc-row-content {
      display: flex;
      justify-content: space-between;
      align-items: center;
      width: 100%;
      padding: 12px 14px 12px 18px;
    }
    .doc-row-icon {
      font-size: 22px;
      flex-shrink: 0;
    }
    .doc-row-icon.valid {
      color: #388E3C;
    }
    .doc-row-icon.expiring-soon {
      color: #F57C00;
    }
    .doc-row-icon.expired {
      color: #D32F2F;
    }
    .doc-row-icon.pending-verification {
      color: #1976D2;
    }
    .doc-row-icon.missing {
      color: #90A4AE;
    }

    .doc-row-title {
      font-size: 13px;
      font-weight: 700;
      color: var(--text-primary);
      line-height: 1.3;
      white-space: nowrap;
      text-overflow: ellipsis;
      overflow: hidden;
    }
    .doc-row-subtitle {
      font-size: 11px;
      color: var(--text-secondary);
      margin-top: 2px;
    }
    .status-chip-badge {
      font-size: 9px;
      font-weight: 700;
      padding: 3px 8px;
      border-radius: 6px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      white-space: nowrap;
    }
    .status-chip-badge.valid {
      background-color: rgba(76, 175, 80, 0.08);
      color: #388E3C;
    }
    .status-chip-badge.expiring-soon {
      background-color: rgba(255, 152, 0, 0.08);
      color: #F57C00;
    }
    .status-chip-badge.expired {
      background-color: rgba(244, 67, 54, 0.08);
      color: #D32F2F;
    }
    .status-chip-badge.pending-verification {
      background-color: rgba(33, 150, 243, 0.08);
      color: #1976D2;
    }
    .status-chip-badge.missing {
      background-color: rgba(144, 164, 174, 0.08);
      color: #546E7A;
    }
    .doc-chevron {
      color: #B0BEC5;
      font-size: 20px;
    }

    /* Preferences */
    .pref-content {
      padding: 0px 16px 14px 16px !important;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .preference-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 10px 0;
    }
    .pref-text {
      display: flex;
      flex-direction: column;
      gap: 2px;
      padding-right: 16px;
    }
    .pref-title {
      font-weight: 600;
      color: var(--text-primary);
      font-size: 13px;
    }
    .pref-desc {
      color: var(--text-secondary);
      font-size: 11px;
      line-height: 1.4;
    }
    .custom-toggle {
      transform: scale(0.9);
    }
    .logout-btn {
      width: 100%;
      height: 48px;
      border-radius: 12px !important;
      font-weight: 700 !important;
      margin-top: 16px;
      display: flex;
      justify-content: center;
      align-items: center;
      gap: 8px;
    }
    .btn-icon {
      font-size: 20px;
    }

    /* Skeleton Loading & Interactive Styles */
    @keyframes shimmer {
      0% {
        background-position: -200% 0;
      }
      100% {
        background-position: 200% 0;
      }
    }

    .skeleton {
      background: linear-gradient(90deg, #F0F2F5 25%, #E4E6EB 50%, #F0F2F5 75%);
      background-size: 200% 100%;
      animation: shimmer 1.5s infinite linear;
      border-radius: 4px;
      display: inline-block;
    }

    .skeleton-avatar {
      width: 56px;
      height: 56px;
      border-radius: 50%;
    }

    .skeleton-text {
      height: 14px;
      margin-bottom: 8px;
    }
    .skeleton-text.title {
      height: 20px;
      width: 150px;
    }
    .skeleton-text.subtitle {
      width: 100px;
    }
    .skeleton-text.lbl {
      height: 10px;
      width: 60px;
    }
    .skeleton-text.val {
      height: 14px;
      width: 180px;
    }

    .clickable-item {
      transition: background-color 0.15s ease-in-out;
    }
    .clickable-item:hover, .clickable-item:active {
      background-color: rgba(0, 0, 0, 0.03) !important;
    }

    /* Account & Vehicle Details Redesign */
    .details-dashboard-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 16px;
      margin-bottom: 20px;
    }
    .details-block-card {
      border: 1px solid var(--border-color);
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.02) !important;
      border-radius: 16px !important;
      background-color: var(--surface-color);
      overflow: hidden;
    }
    .block-header {
      padding: 16px 16px 8px 16px !important;
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .block-header-icon {
      font-size: 20px;
      color: var(--primary-color);
    }
    .block-title {
      font-size: 13px !important;
      font-weight: 800 !important;
      color: var(--text-primary);
      text-transform: uppercase;
      letter-spacing: 0.8px;
      margin: 0 !important;
    }
    .block-content {
      padding: 8px 16px 16px 16px !important;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .info-row {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .info-icon-wrapper {
      width: 36px;
      height: 36px;
      border-radius: 10px;
      background-color: rgba(33, 150, 243, 0.06);
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }
    .info-icon {
      font-size: 18px;
      color: var(--primary-color);
    }
    .info-icon.font-taxi {
      color: #FFB300;
    }
    .info-text {
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }
    .info-label {
      font-size: 9px;
      font-weight: 700;
      color: var(--text-secondary);
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .info-value {
      font-size: 13px;
      font-weight: 600;
      color: var(--text-primary);
      white-space: nowrap;
      text-overflow: ellipsis;
      overflow: hidden;
      margin-top: 1px;
    }
    .info-value.empty-state-text {
      color: #90A4AE;
      font-weight: 500;
      font-style: italic;
    }
    .info-divider {
      height: 1px;
      background-color: #ECEFF1;
      width: 100%;
    }
    
    /* Vehicle Details Grid */
    .vehicle-sub-grid {
      display: flex;
      align-items: center;
      gap: 16px;
      width: 100%;
      margin-top: 4px;
    }
    .sub-info-block {
      display: flex;
      flex-direction: column;
      gap: 6px;
      flex: 1;
    }
    
    /* UK License Plate */
    .uk-license-plate {
      display: inline-flex;
      align-items: center;
      background-color: #FFCC00;
      border: 1.5px solid #1A1A1A;
      border-radius: 6px;
      padding: 4px 10px 4px 18px;
      position: relative;
      overflow: hidden;
      box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
      height: 28px;
      align-self: flex-start;
    }
    .plate-eu-strip {
      position: absolute;
      top: 0;
      left: 0;
      bottom: 0;
      width: 12px;
      background-color: #003399;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .plate-eu-text {
      font-size: 6px;
      color: #FFFFFF;
      font-weight: 800;
      font-family: 'Outfit', sans-serif;
      transform: scale(0.85);
    }
    .plate-number-text {
      font-family: 'Courier New', monospace;
      font-weight: 900;
      font-size: 12px;
      color: #1A1A1A;
      letter-spacing: 1px;
      white-space: nowrap;
    }
    .empty-badge {
      background-color: #ECEFF1;
      color: #78909C;
      font-size: 10px;
      font-weight: 700;
      padding: 4px 8px;
      border-radius: 6px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      align-self: flex-start;
    }
    
    /* Color tag */
    .color-palette-tag {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background-color: #F8F9FA;
      border: 1px solid #ECEFF1;
      border-radius: 8px;
      padding: 4px 10px;
      height: 28px;
      align-self: flex-start;
      box-shadow: 0 1px 2px rgba(0,0,0,0.02);
    }
    .color-tag-dot {
      display: inline-block;
      width: 12px;
      height: 12px;
      border-radius: 50%;
      border: 1px solid #ECEFF1;
      box-shadow: inset 0 1px 2px rgba(0,0,0,0.1);
    }
    .color-tag-hex {
      font-size: 11px;
      font-weight: 700;
      color: #455A64;
      font-family: monospace;
    }

    /* Preview Modal Styles */
    .preview-backdrop {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background-color: rgba(0, 0, 0, 0.4);
      backdrop-filter: blur(8px);
      -webkit-backdrop-filter: blur(8px);
      z-index: 1000;
      display: flex;
      justify-content: center;
      align-items: center;
      padding: 20px;
      animation: fadeIn 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    }
    .preview-modal-card {
      background-color: #FFFFFF;
      border-radius: 16px;
      width: 100%;
      max-width: 420px;
      max-height: 90vh;
      display: flex;
      flex-direction: column;
      box-shadow: 0 10px 25px rgba(0, 0, 0, 0.15);
      border: 1px solid rgba(0, 0, 0, 0.05);
      animation: scaleUp 0.25s cubic-bezier(0.34, 1.56, 0.64, 1);
      overflow: hidden;
    }
    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }
    @keyframes scaleUp {
      from { transform: scale(0.95); opacity: 0; }
      to { transform: scale(1); opacity: 1; }
    }
    .preview-header {
      padding: 16px 20px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 1px solid #ECEFF1;
    }
    .preview-title {
      margin: 0;
      font-size: 15px;
      font-weight: 700;
      color: var(--text-primary);
    }
    .close-modal-btn {
      background: none;
      border: none;
      color: #90A4AE;
      cursor: pointer;
      padding: 4px;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 50%;
      transition: background-color 0.2s;
    }
    .close-modal-btn:hover {
      background-color: #F5F7F8;
      color: #455A64;
    }
    .preview-body {
      padding: 20px;
      overflow-y: auto;
      display: flex;
      flex-direction: column;
      gap: 16px;
    }
    .preview-status-row {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 12px;
      border-radius: 12px;
    }
    .preview-status-row.valid {
      background-color: rgba(76, 175, 80, 0.06);
      border: 1px solid rgba(76, 175, 80, 0.15);
    }
    .preview-status-row.valid .status-icon { color: #388E3C; }
    .preview-status-row.valid .status-title { color: #2E7D32; }
    
    .preview-status-row.expiring-soon {
      background-color: rgba(255, 152, 0, 0.06);
      border: 1px solid rgba(255, 152, 0, 0.15);
    }
    .preview-status-row.expiring-soon .status-icon { color: #F57C00; }
    .preview-status-row.expiring-soon .status-title { color: #EF6C00; }
    
    .preview-status-row.expired {
      background-color: rgba(244, 67, 54, 0.06);
      border: 1px solid rgba(244, 67, 54, 0.15);
    }
    .preview-status-row.expired .status-icon { color: #D32F2F; }
    .preview-status-row.expired .status-title { color: #C62828; }
    
    .preview-status-row.pending-verification {
      background-color: rgba(33, 150, 243, 0.06);
      border: 1px solid rgba(33, 150, 243, 0.15);
    }
    .preview-status-row.pending-verification .status-icon { color: #1976D2; }
    .preview-status-row.pending-verification .status-title { color: #1565C0; }

    .status-icon {
      font-size: 24px;
    }
    .status-details {
      display: flex;
      flex-direction: column;
    }
    .status-title {
      font-size: 13px;
      font-weight: 700;
    }
    .status-subtitle {
      font-size: 11px;
      color: var(--text-secondary);
      margin-top: 1px;
    }
    .preview-image-container {
      width: 100%;
      height: 240px;
      background-color: #F8F9FA;
      border-radius: 12px;
      border: 1px solid #ECEFF1;
      overflow: hidden;
      position: relative;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .preview-image {
      max-width: 100%;
      max-height: 100%;
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
      padding: 24px;
      gap: 12px;
    }
    .placeholder-icon {
      font-size: 48px;
      color: #B0BEC5;
    }
    .placeholder-text {
      font-size: 12px;
      color: #78909C;
      line-height: 1.5;
    }
    .preview-footer {
      padding: 16px 20px;
      border-top: 1px solid #ECEFF1;
      display: flex;
      justify-content: flex-end;
      gap: 10px;
    }
    .preview-footer button {
      border-radius: 8px !important;
      font-weight: 600 !important;
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

  autoAccept = true;
  nightShifts = false;

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
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.isLoading = true;
    const userId = this.getUserIdFromToken();
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
                  // Expiry loaded successfully, so clear any client-side pending flag
                  localStorage.removeItem('pending_upload_' + docType);
                }
              });
            }
          },
          complete: () => {
            // Apply temporary local pending verification flags for newly uploaded files
            this.documents.forEach(doc => {
              const isPending = localStorage.getItem('pending_upload_' + doc.type) === 'true';
              if (isPending && (doc.status === 'Missing' || doc.expiry === 'Not Uploaded')) {
                doc.status = 'Pending Verification';
                doc.expiry = 'Under Review';
                doc.url = localStorage.getItem('pending_upload_url_' + doc.type) || null;
              }
            });
            this.isLoading = false;
            this.cdr.detectChanges();
          }
        });
      } else {
        // Fallback checks even if userId is not resolved
        this.documents.forEach(doc => {
          const isPending = localStorage.getItem('pending_upload_' + doc.type) === 'true';
          if (isPending && (doc.status === 'Missing' || doc.expiry === 'Not Uploaded')) {
            doc.status = 'Pending Verification';
            doc.expiry = 'Under Review';
            doc.url = localStorage.getItem('pending_upload_url_' + doc.type) || null;
          }
        });
        this.isLoading = false;
        this.cdr.detectChanges();
      }
    });
  }

  getVerifiedCount(): number {
    return this.documents.filter(d => d.status === 'Valid').length;
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

  getBackgroundStyle(): string {
    if (!this.colorCode) {
      return 'linear-gradient(135deg, var(--primary-color) 0%, var(--primary-dark) 100%)';
    }
    const color = this.colorCode.startsWith('#') ? this.colorCode : `#${this.colorCode}`;
    return `linear-gradient(135deg, ${color} 0%, #1A237E 100%)`;
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

  reuploadFromPreview(): void {
    if (this.previewDoc) {
      const type = this.previewDoc.type;
      const name = this.previewDoc.name;
      this.closePreview();
      this.navigateToUpload(type, name);
    }
  }

  toggleAutoAccept(): void {
    this.autoAccept = !this.autoAccept;
  }

  toggleNightShifts(): void {
    this.nightShifts = !this.nightShifts;
  }

  logout(): void {
    localStorage.removeItem('auth_token');
    this.router.navigate(['/login']);
  }
}
