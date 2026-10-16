import { Component, OnInit, OnDestroy, ChangeDetectorRef, ViewChild, ElementRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
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
  status: 'Valid' | 'Approved' | 'Expiring Soon' | 'Expired' | 'Missing' | 'Pending Verification' | 'Rejected';
  rawStatus?: number; // 0 = Pending, 1 = Approved, 2 = Rejected
  expiry: string;
  url?: string | null;
  id?: number | null;
  userId?: number | null;
  originalFileName?: string | null;
  uploadedAt?: string | null;
  reviewedByUserId?: number | null;
  reviewedAt?: string | null;
  rejectionReason?: string | null;
}

export interface ColourChoice { name: string; hex: string; light?: boolean; }

/** Vehicle colours offered in the picker (the name is what the API receives). */
const BASE_COLOURS: ColourChoice[] = [
  { name: 'Black', hex: '#111827' },
  { name: 'White', hex: '#F8FAFC', light: true },
  { name: 'Silver', hex: '#C0C7D0', light: true },
  { name: 'Grey', hex: '#6B7280' },
  { name: 'Blue', hex: '#2563EB' },
  { name: 'Red', hex: '#DC2626' },
  { name: 'Green', hex: '#16A34A' },
  { name: 'Yellow', hex: '#FACC15', light: true },
  { name: 'Orange', hex: '#F97316' },
  { name: 'Brown', hex: '#92400E' },
  { name: 'Beige', hex: '#D6C4A5', light: true },
  { name: 'Gold', hex: '#CA8A04' }
];

@Component({
  selector: 'app-profile',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
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
        
        <!-- 1. Driver Profile Hero Card -->
        <div class="hero-profile-card">
          <div class="hero-glow"></div>
          <div class="hero-inner">
            <div class="hero-top-row">
              <div class="avatar-wrapper">
                <div class="avatar-ring">
                  <div class="avatar-circle" [style.background-color]="colorCode ? (colorCode.startsWith('#') ? colorCode : '#' + colorCode) : '#CD1A21'">
                    <img *ngIf="profilePhotoUrl" class="avatar-photo" [src]="profilePhotoUrl" alt="Profile photo" (error)="profilePhotoUrl = ''" />
                    <span class="avatar-initials" *ngIf="!profilePhotoUrl">{{ getInitials() }}</span>
                  </div>
                </div>
                <button type="button" class="avatar-edit-badge" (click)="openEdit()" aria-label="Change profile photo">
                  <span class="material-symbols-outlined">photo_camera</span>
                </button>
              </div>

              <div class="driver-identity-info">
                <span class="hero-eyebrow">Driver profile</span>
                <h1 class="driver-name">{{ driverName || 'Driver' }}</h1>
                <div class="role-and-id-row">
                  <span class="badge-pill id-badge" *ngIf="driverId"><span>ID #DRV-{{ driverId }}</span></span>
                  <span class="badge-pill active-badge">
                    <span class="pulse-dot-inline"></span>
                    <span>Driver account</span>
                  </span>
                </div>
              </div>
            </div>

            <!-- Contact chips -->
            <div class="hero-chips" *ngIf="hasPhone || hasEmail">
              <a class="hero-chip" *ngIf="hasPhone" [href]="'tel:' + phoneDigits">
                <span class="material-symbols-outlined">call</span>
                <span class="hero-chip-text">{{ driverPhone }}</span>
              </a>
              <span class="hero-chip" *ngIf="hasEmail">
                <span class="material-symbols-outlined">mail</span>
                <span class="hero-chip-text">{{ driverEmail }}</span>
              </span>
            </div>

            <!-- Vehicle summary -->
            <div class="hero-vehicle" *ngIf="hasPlate || hasVehicle">
              <span class="hero-plate" *ngIf="hasPlate">{{ plateNumber }}</span>
              <span class="hero-vehicle-text" *ngIf="hasVehicle">
                <span class="hero-colour-dot" *ngIf="vehicleColourHex" [style.background-color]="vehicleColourHex"></span>
                <span>{{ vehicleModel }}</span>
              </span>
            </div>

            <!-- Profile completeness -->
            <div class="hero-complete" *ngIf="profileCompletion < 100">
              <div class="hero-complete-head">
                <span>Profile {{ profileCompletion }}% complete</span>
                <button type="button" class="hero-complete-link" (click)="openEdit()">Complete it</button>
              </div>
              <div class="hero-complete-track"><div class="hero-complete-fill" [style.width.%]="profileCompletion"></div></div>
            </div>

            <div class="hero-actions">
              <button type="button" class="hero-edit-btn" (click)="openEdit()">
                <span class="material-symbols-outlined">edit</span>
                <span>Edit profile</span>
              </button>
            </div>

            <!-- Last Login Timestamp (if available from API) -->
            <div class="hero-meta-bar" *ngIf="lastLogin">
              <div class="meta-item">
                <span class="material-symbols-outlined meta-icon">schedule</span>
                <span class="meta-text">Last login: {{ lastLogin | date:'d MMM y, HH:mm' }}</span>
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

              <!-- Title & Expiry / Rejection info -->
              <div class="compact-doc-info">
                <div class="compact-doc-name-row">
                  <span class="compact-doc-name">{{ doc.name }}</span>
                </div>
                <span class="compact-doc-sub" [ngClass]="getDocStatusClass(doc.status)">
                  {{ getDocExpiryFormatted(doc) }}
                </span>
              </div>

              <!-- Status Tag & Action -->
              <div class="compact-doc-right">
                <!-- Direct Re-upload button if Rejected -->
                <button 
                  *ngIf="doc.status === 'Rejected'" 
                  class="reupload-action-btn"
                  title="Re-upload Document"
                  (click)="$event.stopPropagation(); navigateToUpload(doc.type, doc.name)"
                >
                  <span class="material-symbols-outlined">cloud_upload</span>
                  <span>Re-upload</span>
                </button>

                <span class="compact-status-tag" [ngClass]="getDocStatusClass(doc.status)">
                  {{ getDisplayStatus(doc) }}
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
                <span class="status-main-label">{{ getDisplayStatus(previewDoc) }}</span>
                <span class="status-expiry-label">{{ getDocExpiryFormatted(previewDoc) }}</span>
              </div>
            </div>

            <!-- Rejection Alert Banner (shown when rejected by admin) -->
            <div class="rejection-alert-card" *ngIf="previewDoc.status === 'Rejected'">
              <div class="rejection-alert-header">
                <span class="material-symbols-outlined alert-icon">error</span>
                <div class="rejection-alert-titles">
                  <h4 class="rejection-alert-title">Document Rejected by Admin</h4>
                  <p class="rejection-alert-reason" *ngIf="previewDoc.rejectionReason">
                    <strong>Reason:</strong> "{{ previewDoc.rejectionReason }}"
                  </p>
                  <p class="rejection-alert-hint">
                    Please re-upload a clear, readable, and valid copy of this document to complete verification.
                  </p>
                </div>
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
                  <span class="material-symbols-outlined placeholder-icon">
                    {{ previewDoc.status === 'Rejected' ? 'cancel' : 'description' }}
                  </span>
                  <span class="placeholder-title">
                    {{ previewDoc.status === 'Rejected' ? 'Re-upload Required' : 'Document Under Review' }}
                  </span>
                  <span class="placeholder-text">
                    {{ previewDoc.status === 'Rejected' 
                      ? 'This document was rejected. Please upload a fresh document.' 
                      : 'Uploaded certificate is pending dispatch verification.' }}
                  </span>
                </div>
              </ng-template>
            </div>
          </main>
          
          <footer class="preview-footer">
            <button class="btn-cancel" (click)="closePreview()">Close</button>
            <button 
              class="btn-primary" 
              [class.btn-danger]="previewDoc.status === 'Rejected'"
              (click)="reuploadFromPreview()"
            >
              <span class="material-symbols-outlined">cloud_upload</span>
              <span>{{ previewDoc.status === 'Rejected' ? 'Re-upload Document' : 'Update Document' }}</span>
            </button>
          </footer>
        </div>
      </div>


      <!-- Edit Profile Sheet -->
      <div class="ep-backdrop" [class.closing]="isEditClosing" *ngIf="isEditOpen" (click)="closeEdit()">
        <div class="ep-sheet" [class.closing]="isEditClosing" (click)="$event.stopPropagation()" role="dialog" aria-label="Edit profile">
          <div class="ep-grabber"></div>
          <header class="ep-header">
            <h2>Edit profile</h2>
            <button type="button" class="ep-close" (click)="closeEdit()" aria-label="Close">
              <span class="material-symbols-outlined">close</span>
            </button>
          </header>

          <div class="ep-body" #epBody>
            <!-- Photo -->
            <div class="ep-photo-row">
              <div class="ep-photo">
                <img *ngIf="photoPreview || profilePhotoUrl" [src]="photoPreview || profilePhotoUrl" alt="Photo" />
                <span *ngIf="!photoPreview && !profilePhotoUrl" class="material-symbols-outlined">person</span>
              </div>
              <div class="ep-photo-actions">
                <div class="ep-photo-buttons">
                  <button type="button" class="ep-btn-outline" (click)="startSelfie()">
                    <span class="material-symbols-outlined">photo_camera</span>
                    <span>Take selfie</span>
                  </button>
                  <label class="ep-btn-outline">
                    <span class="material-symbols-outlined">image</span>
                    <span>Choose photo</span>
                    <input type="file" accept="image/jpeg,image/png,image/webp" (change)="onPhotoSelected($event)" hidden />
                  </label>
                </div>
                <button type="button" class="ep-link" *ngIf="photoPreview" (click)="clearPhoto()">Remove selected photo</button>
                <span class="ep-hint">Photos only: JPG, PNG or WebP, up to 5 MB</span>
                <span class="ep-error" *ngIf="editErrors['photo']">{{ editErrors['photo'] }}</span>
              </div>
            </div>
            <!-- Fallback input used when the live camera is unavailable -->
            <input #selfieFallback type="file" accept="image/*" capture="user" (change)="onPhotoSelected($event)" hidden />

            <h3 class="ep-section">Your details</h3>
            <label class="ep-field">
              <span>Full name *</span>
              <input type="text" [(ngModel)]="editForm.fullName" name="fullName" autocomplete="name" maxlength="80" (focus)="onFieldFocus($event)" />
              <small class="ep-error" *ngIf="editErrors['fullName']">{{ editErrors['fullName'] }}</small>
            </label>
            <label class="ep-field">
              <span>Phone number</span>
              <input type="tel" [(ngModel)]="editForm.phoneNumber" name="phoneNumber" placeholder="+44 7700 900123" autocomplete="tel" maxlength="20" (focus)="onFieldFocus($event)" />
              <small class="ep-error" *ngIf="editErrors['phoneNumber']">{{ editErrors['phoneNumber'] }}</small>
            </label>
            <label class="ep-field">
              <span>Email</span>
              <input type="email" [(ngModel)]="editForm.email" name="email" placeholder="you@example.com" autocomplete="email" maxlength="120" (focus)="onFieldFocus($event)" />
              <small class="ep-error" *ngIf="editErrors['email']">{{ editErrors['email'] }}</small>
            </label>

            <h3 class="ep-section">Your vehicle</h3>
            <label class="ep-field">
              <span>Number plate</span>
              <input type="text" [(ngModel)]="editForm.regNo" name="regNo" placeholder="AB12 CDE" autocapitalize="characters" maxlength="10" (focus)="onFieldFocus($event)" />
              <small class="ep-error" *ngIf="editErrors['regNo']">{{ editErrors['regNo'] }}</small>
            </label>
            <div class="ep-row">
              <label class="ep-field">
                <span>Make</span>
                <input type="text" [(ngModel)]="editForm.vehicleMake" name="vehicleMake" placeholder="Toyota" maxlength="40" (focus)="onFieldFocus($event)" />
              </label>
              <label class="ep-field">
                <span>Model</span>
                <input type="text" [(ngModel)]="editForm.vehicleModel" name="vehicleModel" placeholder="Prius" maxlength="40" (focus)="onFieldFocus($event)" />
              </label>
            </div>

            <div class="ep-field">
              <span>Vehicle colour <em class="ep-picked" *ngIf="editForm.vehicleColour">· {{ editForm.vehicleColour }}</em></span>
              <div class="ep-swatches" role="radiogroup" aria-label="Vehicle colour">
                <button
                  type="button"
                  *ngFor="let c of colourChoices"
                  class="ep-swatch"
                  [class.selected]="isColourSelected(c.name)"
                  [class.light]="c.light"
                  [style.background-color]="c.hex"
                  [attr.aria-label]="c.name"
                  [attr.aria-checked]="isColourSelected(c.name)"
                  role="radio"
                  (click)="selectColour(c.name)"
                >
                  <span class="material-symbols-outlined ep-swatch-check" *ngIf="isColourSelected(c.name)">check</span>
                </button>
              </div>
            </div>
            <p class="ep-note">Fields left blank keep their current value.</p>
          </div>

          <footer class="ep-footer">
            <button type="button" class="ep-btn-cancel" (click)="closeEdit()" [disabled]="isSaving">Cancel</button>
            <button type="button" class="ep-btn-save" [class.done]="saveDone" (click)="saveProfile()" [disabled]="isSaving || saveDone">
              <span class="ep-spinner" *ngIf="isSaving"></span>
              <span class="material-symbols-outlined" *ngIf="saveDone">check_circle</span>
              <span>{{ saveDone ? 'Saved' : (isSaving ? 'Saving…' : 'Save changes') }}</span>
            </button>
          </footer>
        </div>
      </div>

      <!-- Selfie camera -->
      <div class="ep-camera" *ngIf="isCameraOpen">
        <div class="ep-camera-top">
          <button type="button" class="ep-camera-close" (click)="stopSelfie()" aria-label="Close camera">
            <span class="material-symbols-outlined">close</span>
          </button>
          <span class="ep-camera-title">Take a selfie</span>
          <span class="ep-camera-spacer"></span>
        </div>
        <div class="ep-camera-stage">
          <video #selfieVideo class="ep-camera-video" autoplay playsinline muted [class.hidden]="capturedSelfie"></video>
          <img *ngIf="capturedSelfie" class="ep-camera-shot" [src]="capturedSelfie" alt="Selfie preview" />
          <div class="ep-camera-guide" *ngIf="!capturedSelfie"></div>
        </div>
        <p class="ep-camera-hint">{{ capturedSelfie ? 'Looking good? Use this photo or retake it.' : 'Centre your face in the circle with good light.' }}</p>
        <div class="ep-camera-actions">
          <ng-container *ngIf="!capturedSelfie; else reviewShot">
            <button type="button" class="ep-shutter" (click)="captureSelfie()" aria-label="Capture photo"><span></span></button>
          </ng-container>
          <ng-template #reviewShot>
            <button type="button" class="ep-btn-cancel ep-camera-btn" (click)="retakeSelfie()">Retake</button>
            <button type="button" class="ep-btn-save ep-camera-btn" (click)="useSelfie()">Use photo</button>
          </ng-template>
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
    .doc-color-bar.valid, .doc-color-bar.approved { background: #10B981; }
    .doc-color-bar.expiring-soon { background: #F59E0B; }
    .doc-color-bar.expired { background: #EF4444; }
    .doc-color-bar.pending-verification { background: #6366F1; }
    .doc-color-bar.rejected { background: #DC2626; }
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
    .compact-doc-icon.valid, .compact-doc-icon.approved { background: #DCFCE7; color: #15803D; }
    .compact-doc-icon.expiring-soon { background: #FEF3C7; color: #B45309; }
    .compact-doc-icon.expired { background: #FEE2E2; color: #B91C1C; }
    .compact-doc-icon.pending-verification { background: #EEF2FF; color: #4F46E5; }
    .compact-doc-icon.rejected { background: #FEE2E2; color: #DC2626; }
    .compact-doc-icon.missing { background: #F1F5F9; color: #64748B; }

    .compact-doc-info {
      flex: 1;
      min-width: 0;
      display: flex;
      flex-direction: column;
      gap: 1px;
    }
    .compact-doc-name-row {
      display: flex;
      align-items: center;
      gap: 6px;
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
      line-height: 1.3;
    }
    .compact-doc-sub.missing { color: #64748B; font-weight: 500; }
    .compact-doc-sub.pending-verification { color: #4F46E5; font-weight: 500; }
    .compact-doc-sub.expiring-soon { color: #D97706; font-weight: 500; }
    .compact-doc-sub.expired { color: #DC2626; font-weight: 500; }
    .compact-doc-sub.rejected { color: #DC2626; font-weight: 600; }

    .compact-doc-right {
      display: flex;
      align-items: center;
      gap: 6px;
      flex-shrink: 0;
    }
    .reupload-action-btn {
      background: #DC2626;
      color: #FFFFFF;
      border: none;
      border-radius: 6px;
      padding: 3px 8px;
      font-size: 10px;
      font-weight: 700;
      display: inline-flex;
      align-items: center;
      gap: 3px;
      cursor: pointer;
      box-shadow: 0 1px 4px rgba(220, 38, 38, 0.25);
      transition: transform 0.1s ease, background 0.12s ease;
    }
    .reupload-action-btn:active {
      transform: scale(0.95);
      background: #B91C1C;
    }
    .reupload-action-btn .material-symbols-outlined {
      font-size: 13px;
    }

    .compact-status-tag {
      font-size: 9px;
      font-weight: 700;
      padding: 2px 6px;
      border-radius: 6px;
      letter-spacing: 0.2px;
      text-transform: uppercase;
    }
    .compact-status-tag.valid, .compact-status-tag.approved { background: #DCFCE7; color: #166534; }
    .compact-status-tag.expiring-soon { background: #FEF3C7; color: #92400E; }
    .compact-status-tag.expired { background: #FEE2E2; color: #991B1B; }
    .compact-status-tag.pending-verification { background: #EEF2FF; color: #3730A3; }
    .compact-status-tag.rejected { background: #FEE2E2; color: #991B1B; }
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
    .preview-status-strip.valid, .preview-status-strip.approved { background: #DCFCE7; color: #166534; }
    .preview-status-strip.expiring-soon { background: #FEF3C7; color: #92400E; }
    .preview-status-strip.expired { background: #FEE2E2; color: #991B1B; }
    .preview-status-strip.pending-verification { background: #EEF2FF; color: #3730A3; }
    .preview-status-strip.rejected { background: #FEE2E2; color: #991B1B; border: 1px solid rgba(220, 38, 38, 0.25); }
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

    /* Rejection Alert Banner */
    .rejection-alert-card {
      background: #FEF2F2;
      border: 1px solid #FECACA;
      border-radius: 10px;
      padding: 10px 12px;
    }
    .rejection-alert-header {
      display: flex;
      align-items: flex-start;
      gap: 8px;
    }
    .rejection-alert-header .alert-icon {
      color: #DC2626;
      font-size: 20px;
      flex-shrink: 0;
      margin-top: 1px;
    }
    .rejection-alert-titles {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 3px;
    }
    .rejection-alert-title {
      margin: 0;
      font-size: 12px;
      font-weight: 700;
      color: #991B1B;
    }
    .rejection-alert-reason {
      margin: 0;
      font-size: 11px;
      color: #B91C1C;
      background: rgba(220, 38, 38, 0.08);
      padding: 4px 8px;
      border-radius: 6px;
      border-left: 3px solid #DC2626;
    }
    .rejection-alert-hint {
      margin: 0;
      font-size: 10px;
      color: #7F1D1D;
      opacity: 0.9;
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
    .btn-primary.btn-danger {
      background: #DC2626;
    }
    .btn-primary.btn-danger:hover {
      background: #B91C1C;
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
    /* ---- Hero card (professional) ---- */
    .hero-profile-card {
      background: linear-gradient(145deg, #1E293B 0%, #0B1220 100%);
      border-radius: 20px;
      padding: 18px 16px 16px;
      overflow: hidden;
      box-shadow: 0 10px 28px rgba(15, 23, 42, 0.28);
    }
    .hero-glow {
      position: absolute; top: -70px; right: -60px; width: 220px; height: 220px; border-radius: 50%;
      background: radial-gradient(circle, rgba(205, 26, 33, 0.38) 0%, rgba(205, 26, 33, 0) 70%);
      pointer-events: none;
    }
    .hero-top-row { gap: 16px; align-items: center; }
    .avatar-wrapper { position: relative; flex-shrink: 0; }
    .avatar-ring { padding: 3px; border-radius: 50%; background: linear-gradient(135deg, #F87171, #CD1A21 55%, #7F1D1D); }
    .avatar-circle { width: 74px; height: 74px; font-size: 26px; overflow: hidden; border: 3px solid #0F172A; box-shadow: none; }
    .avatar-photo { width: 100%; height: 100%; object-fit: cover; display: block; }
    .avatar-edit-badge {
      position: absolute; right: -2px; bottom: -2px; width: 28px; height: 28px; border-radius: 50%;
      border: 2px solid #0F172A; background: #FFFFFF; color: #CD1A21; cursor: pointer;
      display: grid; place-items: center; padding: 0; transition: transform 0.15s ease;
    }
    .avatar-edit-badge:active { transform: scale(0.9); }
    .avatar-edit-badge .material-symbols-outlined { font-size: 16px; }
    .hero-eyebrow { display: block; font-size: 10.5px; font-weight: 800; letter-spacing: 1.2px; text-transform: uppercase; color: #94A3B8; margin-bottom: 2px; }
    .driver-name { font-size: 22px; font-weight: 800; letter-spacing: -0.4px; margin: 0 0 6px 0; }
    .hero-chips { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 14px; }
    .hero-chip {
      display: inline-flex; align-items: center; gap: 6px; max-width: 100%; padding: 7px 11px; border-radius: 999px;
      background: rgba(255, 255, 255, 0.08); border: 1px solid rgba(255, 255, 255, 0.1);
      color: #E2E8F0; font-size: 12.5px; font-weight: 600; text-decoration: none;
    }
    .hero-chip .material-symbols-outlined { font-size: 16px; color: #FCA5A5; }
    .hero-chip-text { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .hero-vehicle { display: flex; align-items: center; gap: 10px; margin-top: 12px; padding: 10px 12px; border-radius: 12px; background: rgba(255, 255, 255, 0.05); }
    .hero-plate {
      padding: 3px 9px; border-radius: 6px; background: #F7D117; color: #000; border: 1.5px solid #000;
      font-weight: 800; font-size: 13px; letter-spacing: 1.2px; white-space: nowrap;
    }
    .hero-vehicle-text { display: inline-flex; align-items: center; gap: 7px; font-size: 13px; font-weight: 600; color: #E2E8F0; min-width: 0; }
    .hero-colour-dot { width: 12px; height: 12px; border-radius: 50%; border: 1.5px solid rgba(255, 255, 255, 0.55); flex-shrink: 0; }
    .hero-complete { margin-top: 14px; }
    .hero-complete-head { display: flex; justify-content: space-between; align-items: center; font-size: 12px; font-weight: 600; color: #CBD5E1; margin-bottom: 6px; }
    .hero-complete-link { border: 0; background: none; padding: 0; color: #FCA5A5; font-weight: 700; font-size: 12px; cursor: pointer; }
    .hero-complete-track { height: 6px; border-radius: 6px; background: rgba(255, 255, 255, 0.12); overflow: hidden; }
    .hero-complete-fill { height: 100%; border-radius: 6px; background: linear-gradient(90deg, #F87171, #CD1A21); transition: width 0.5s ease; }
    .hero-actions { margin-top: 14px; }
    .hero-edit-btn {
      width: 100%; height: 44px; border: 0; border-radius: 12px; cursor: pointer;
      display: inline-flex; align-items: center; justify-content: center; gap: 8px;
      background: #FFFFFF; color: #0F172A; font-weight: 800; font-size: 14.5px;
      transition: transform 0.12s ease, box-shadow 0.2s ease; box-shadow: 0 4px 14px rgba(0, 0, 0, 0.25);
    }
    .hero-edit-btn:active { transform: scale(0.98); }
    .hero-edit-btn .material-symbols-outlined { font-size: 18px; color: #CD1A21; }

    /* ---- Edit profile sheet ---- */
    .ep-backdrop {
      position: fixed; inset: 0; z-index: 1000; display: flex; align-items: flex-end; justify-content: center;
      background: rgba(15, 23, 42, 0.6); backdrop-filter: blur(3px); overscroll-behavior: contain; touch-action: none;
      animation: epFadeIn 0.2s ease-out both;
    }
    .ep-backdrop.closing { animation: epFadeOut 0.2s ease-in both; }
    .ep-sheet {
      width: 100%; max-width: 600px; max-height: 92vh; display: flex; flex-direction: column;
      background: #FFFFFF; border-radius: 22px 22px 0 0; box-shadow: 0 -12px 34px rgba(0, 0, 0, 0.22);
      animation: epSlideUp 0.32s cubic-bezier(0.16, 1, 0.3, 1) both; touch-action: auto;
    }
    .ep-sheet.closing { animation: epSlideDown 0.2s ease-in both; }
    @keyframes epSlideUp { from { transform: translateY(100%); } to { transform: translateY(0); } }
    @keyframes epSlideDown { from { transform: translateY(0); } to { transform: translateY(100%); } }
    @keyframes epFadeIn { from { opacity: 0; } to { opacity: 1; } }
    @keyframes epFadeOut { from { opacity: 1; } to { opacity: 0; } }
    .ep-grabber { width: 40px; height: 4px; border-radius: 4px; background: #CBD5E1; margin: 8px auto 0; }
    .ep-header { display: flex; align-items: center; justify-content: space-between; padding: 8px 16px 4px; }
    .ep-header h2 { margin: 0; font-size: 19px; font-weight: 800; color: #0F172A; }
    .ep-close { border: 0; background: #F1F5F9; width: 34px; height: 34px; border-radius: 50%; cursor: pointer; display: grid; place-items: center; color: #334155; transition: transform 0.12s ease; }
    .ep-close:active { transform: scale(0.9); }
    .ep-body { padding: 8px 16px 18px; overflow-y: auto; overscroll-behavior: contain; -webkit-overflow-scrolling: touch; touch-action: pan-y; scroll-behavior: smooth; }
    .ep-photo-row { display: flex; align-items: center; gap: 14px; margin: 8px 0 4px; }
    .ep-photo { width: 84px; height: 84px; border-radius: 50%; overflow: hidden; background: #F1F5F9; display: grid; place-items: center; color: #94A3B8; flex-shrink: 0; border: 3px solid #E2E8F0; transition: border-color 0.2s ease; }
    .ep-photo img { width: 100%; height: 100%; object-fit: cover; animation: epFadeIn 0.25s ease-out both; }
    .ep-photo .material-symbols-outlined { font-size: 40px; }
    .ep-photo-actions { display: flex; flex-direction: column; align-items: flex-start; gap: 6px; min-width: 0; }
    .ep-photo-buttons { display: flex; flex-wrap: wrap; gap: 8px; }
    .ep-btn-outline { display: inline-flex; align-items: center; gap: 6px; padding: 8px 12px; border: 1px solid #CBD5E1; border-radius: 10px; font-size: 13px; font-weight: 700; color: #0F172A; cursor: pointer; background: #fff; transition: transform 0.12s ease, background 0.2s ease; }
    .ep-btn-outline:active { transform: scale(0.96); background: #F8FAFC; }
    .ep-btn-outline .material-symbols-outlined { font-size: 18px; color: #CD1A21; }
    .ep-link { border: 0; background: none; color: #CD1A21; font-size: 12.5px; font-weight: 700; padding: 0; cursor: pointer; }
    .ep-hint { font-size: 11.5px; color: #64748B; }
    .ep-section { margin: 18px 0 8px; font-size: 12px; font-weight: 800; letter-spacing: 0.6px; text-transform: uppercase; color: #64748B; }
    .ep-field { display: flex; flex-direction: column; gap: 6px; margin-bottom: 12px; flex: 1; min-width: 0; }
    .ep-field > span { font-size: 12.5px; font-weight: 700; color: #334155; }
    .ep-picked { font-style: normal; font-weight: 600; color: #CD1A21; }
    .ep-field input { height: 46px; padding: 0 13px; border: 1.5px solid #CBD5E1; border-radius: 12px; font-size: 16px; background: #fff; color: #0F172A; outline: none; width: 100%; box-sizing: border-box; transition: border-color 0.18s ease, box-shadow 0.18s ease; }
    .ep-field input:focus { border-color: #CD1A21; box-shadow: 0 0 0 4px rgba(205, 26, 33, 0.12); }
    .ep-row { display: flex; gap: 10px; }
    .ep-error { color: #DC2626; font-size: 12px; font-weight: 600; animation: epFadeIn 0.2s ease-out both; }
    .ep-note { margin: 4px 0 0; font-size: 12px; color: #64748B; }
    .ep-swatches { display: grid; grid-template-columns: repeat(6, 1fr); gap: 10px; padding: 2px 0; }
    .ep-swatch {
      position: relative; aspect-ratio: 1 / 1; width: 100%; border-radius: 50%; padding: 0; cursor: pointer;
      border: 2px solid rgba(15, 23, 42, 0.12); display: grid; place-items: center;
      transition: transform 0.15s ease, box-shadow 0.2s ease, border-color 0.2s ease;
    }
    .ep-swatch.light { border-color: #CBD5E1; }
    .ep-swatch:active { transform: scale(0.9); }
    .ep-swatch.selected { transform: scale(1.08); border-color: #CD1A21; box-shadow: 0 0 0 3px #fff, 0 0 0 5px #CD1A21; }
    .ep-swatch-check { font-size: 18px; color: #fff; font-variation-settings: 'wght' 700; filter: drop-shadow(0 1px 1px rgba(0, 0, 0, 0.45)); animation: epPop 0.18s ease-out both; }
    .ep-swatch.light .ep-swatch-check { color: #0F172A; filter: none; }
    @keyframes epPop { from { transform: scale(0.4); opacity: 0; } to { transform: scale(1); opacity: 1; } }
    .ep-footer { display: flex; gap: 10px; padding: 12px 16px calc(12px + env(safe-area-inset-bottom, 0px)); border-top: 1px solid #E2E8F0; background: #fff; }
    .ep-btn-cancel { flex: 1; height: 48px; border: 1px solid #CBD5E1; border-radius: 12px; background: #fff; font-weight: 700; font-size: 15px; color: #334155; cursor: pointer; transition: transform 0.12s ease; }
    .ep-btn-save { flex: 2; height: 48px; border: 0; border-radius: 12px; background: linear-gradient(135deg, #CD1A21, #E11D48); color: #fff; font-weight: 800; font-size: 15px; cursor: pointer; display: inline-flex; align-items: center; justify-content: center; gap: 8px; transition: transform 0.12s ease, background 0.25s ease; }
    .ep-btn-save.done { background: linear-gradient(135deg, #059669, #10B981); }
    .ep-btn-save:active:not(:disabled), .ep-btn-cancel:active:not(:disabled) { transform: scale(0.98); }
    .ep-btn-save:disabled, .ep-btn-cancel:disabled { opacity: 0.65; cursor: default; }
    .ep-btn-save.done:disabled { opacity: 1; }
    .ep-spinner { width: 16px; height: 16px; border: 2px solid rgba(255, 255, 255, 0.5); border-top-color: #fff; border-radius: 50%; animation: epSpin 0.7s linear infinite; }
    @keyframes epSpin { to { transform: rotate(360deg); } }

    /* ---- Selfie camera ---- */
    .ep-camera { position: fixed; inset: 0; z-index: 1100; background: #000; display: flex; flex-direction: column; animation: epFadeIn 0.2s ease-out both; }
    .ep-camera-top { display: flex; align-items: center; justify-content: space-between; padding: calc(12px + env(safe-area-inset-top, 0px)) 14px 8px; color: #fff; }
    .ep-camera-title { font-weight: 800; font-size: 16px; }
    .ep-camera-close { width: 38px; height: 38px; border-radius: 50%; border: 0; background: rgba(255, 255, 255, 0.16); color: #fff; display: grid; place-items: center; cursor: pointer; }
    .ep-camera-spacer { width: 38px; }
    .ep-camera-stage { position: relative; flex: 1; min-height: 0; display: grid; place-items: center; overflow: hidden; }
    .ep-camera-video { width: 100%; height: 100%; object-fit: cover; transform: scaleX(-1); }
    .ep-camera-video.hidden { visibility: hidden; position: absolute; }
    .ep-camera-shot { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: contain; background: #000; animation: epFadeIn 0.2s ease-out both; }
    .ep-camera-guide { position: absolute; width: min(72vw, 320px); aspect-ratio: 1 / 1; border-radius: 50%; border: 3px dashed rgba(255, 255, 255, 0.75); box-shadow: 0 0 0 100vmax rgba(0, 0, 0, 0.45); pointer-events: none; }
    .ep-camera-hint { margin: 0; padding: 10px 16px 4px; text-align: center; color: #E2E8F0; font-size: 13px; }
    .ep-camera-actions { display: flex; justify-content: center; align-items: center; gap: 12px; padding: 10px 20px calc(22px + env(safe-area-inset-bottom, 0px)); }
    .ep-camera-btn { flex: 1; max-width: 170px; }
    .ep-camera-actions .ep-btn-cancel { background: rgba(255, 255, 255, 0.14); border-color: rgba(255, 255, 255, 0.25); color: #fff; }
    .ep-shutter { width: 72px; height: 72px; border-radius: 50%; border: 4px solid #fff; background: transparent; padding: 4px; cursor: pointer; transition: transform 0.12s ease; }
    .ep-shutter span { display: block; width: 100%; height: 100%; border-radius: 50%; background: #fff; }
    .ep-shutter:active { transform: scale(0.92); }

    @media (prefers-reduced-motion: reduce) {
      .ep-backdrop, .ep-sheet, .ep-camera, .ep-photo img, .ep-error, .ep-swatch-check { animation-duration: 0.01ms !important; }
      .ep-swatch, .ep-field input, .ep-btn-save, .hero-complete-fill { transition-duration: 0.01ms !important; }
    }

    :host-context(.dark-theme) .ep-sheet, :host-context(.dark-theme) .ep-footer { background: #1E1E24; }
    :host-context(.dark-theme) .ep-footer { border-top-color: #2D2D35; }
    :host-context(.dark-theme) .ep-header h2 { color: #F8FAFC; }
    :host-context(.dark-theme) .ep-close { background: #2D2D35; color: #E2E8F0; }
    :host-context(.dark-theme) .ep-field > span { color: #CBD5E1; }
    :host-context(.dark-theme) .ep-field input { background: #121214; border-color: #3A3A44; color: #F8FAFC; }
    :host-context(.dark-theme) .ep-btn-outline, :host-context(.dark-theme) .ep-btn-cancel { background: #2D2D35; border-color: #3A3A44; color: #F8FAFC; }
    :host-context(.dark-theme) .ep-photo { background: #2D2D35; border-color: #3A3A44; }
    :host-context(.dark-theme) .ep-swatch.selected { box-shadow: 0 0 0 3px #1E1E24, 0 0 0 5px #F87171; border-color: #F87171; }
    :host-context(.dark-theme) .hero-profile-card { border-color: rgba(255, 255, 255, 0.1); }

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
    :host-context(.dark-theme) .reupload-action-btn {
      background: #EF4444;
    }
    :host-context(.dark-theme) .reupload-action-btn:active {
      background: #DC2626;
    }
    :host-context(.dark-theme) .rejection-alert-card {
      background: rgba(239, 68, 68, 0.12);
      border-color: rgba(239, 68, 68, 0.3);
    }
    :host-context(.dark-theme) .rejection-alert-title {
      color: #FCA5A5;
    }
    :host-context(.dark-theme) .rejection-alert-reason {
      color: #FECACA;
      background: rgba(239, 68, 68, 0.2);
      border-left-color: #EF4444;
    }
    :host-context(.dark-theme) .rejection-alert-hint {
      color: #F87171;
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
export class ProfileComponent implements OnInit, OnDestroy {
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
  profilePhotoUrl = '';

  // Raw profile values (unformatted) used to pre-fill the edit form
  private rawProfile = { fullName: '', phoneNumber: '', email: '', regNo: '', vehicleMake: '', vehicleModel: '', vehicleColour: '' };

  // Edit profile sheet
  isEditOpen = false;
  isEditClosing = false;
  isSaving = false;
  saveDone = false;
  colourChoices: ColourChoice[] = [...BASE_COLOURS];

  // Selfie camera
  isCameraOpen = false;
  capturedSelfie: string | null = null;
  private selfieStream: MediaStream | null = null;
  private selfieBlob: Blob | null = null;
  @ViewChild('selfieVideo') selfieVideo?: ElementRef<HTMLVideoElement>;
  @ViewChild('selfieFallback') selfieFallback?: ElementRef<HTMLInputElement>;
  editForm = { fullName: '', phoneNumber: '', email: '', regNo: '', vehicleMake: '', vehicleModel: '', vehicleColour: '' };
  editErrors: Record<string, string> = {};
  selectedPhoto: File | null = null;
  photoPreview: string | null = null;

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
    // Clear any legacy pending upload flags from previous sessions
    try {
      for (let i = 0; i <= 20; i++) {
        localStorage.removeItem('pending_upload_' + i);
        localStorage.removeItem('pending_upload_url_' + i);
      }
    } catch (_) {}
    this.loadProfile();
  }

  // ---------- Hero helpers ----------

  get hasPhone(): boolean { return !!this.driverPhone && this.driverPhone !== 'Not Registered'; }
  get hasEmail(): boolean { return !!this.driverEmail && this.driverEmail !== 'Not Registered'; }
  get hasPlate(): boolean { return !!this.plateNumber && this.plateNumber !== 'No Plate'; }
  get hasVehicle(): boolean { return !!this.vehicleModel && this.vehicleModel !== 'No Vehicle Registered'; }
  get phoneDigits(): string { return this.driverPhone.replace(/[^0-9+]/g, ''); }

  /** Hex for the saved vehicle colour name, for the dot in the hero card. */
  get vehicleColourHex(): string {
    const name = this.rawProfile.vehicleColour.trim().toLowerCase();
    const hit = BASE_COLOURS.find(c => c.name.toLowerCase() === name);
    return hit ? hit.hex : (name ? '#9CA3AF' : '');
  }

  /** Share of the key profile fields that are filled in (real data only). */
  get profileCompletion(): number {
    const r = this.rawProfile;
    const checks = [r.fullName, r.phoneNumber, r.email, r.regNo, r.vehicleMake, r.vehicleModel, r.vehicleColour, this.profilePhotoUrl];
    const done = checks.filter(v => !!(v && String(v).trim())).length;
    return Math.round((done / checks.length) * 100);
  }

  // ---------- Edit profile ----------

  openEdit(): void {
    this.editForm = { ...this.rawProfile };
    this.editErrors = {};
    this.selectedPhoto = null;
    this.photoPreview = null;
    this.saveDone = false;
    this.isEditClosing = false;

    // Offer the driver's current colour even when it isn't one of the presets.
    const current = this.rawProfile.vehicleColour.trim();
    this.colourChoices = [...BASE_COLOURS];
    if (current && !BASE_COLOURS.some(c => c.name.toLowerCase() === current.toLowerCase())) {
      this.colourChoices.push({ name: current, hex: '#9CA3AF' });
    }
    const match = BASE_COLOURS.find(c => c.name.toLowerCase() === current.toLowerCase());
    if (match) this.editForm.vehicleColour = match.name;

    this.lockPageScroll(true);
    this.isEditOpen = true;
  }

  /** Slides the sheet down, then removes it. */
  closeEdit(): void {
    if (this.isSaving || !this.isEditOpen || this.isEditClosing) return;
    this.stopSelfie();
    this.isEditClosing = true;
    setTimeout(() => {
      this.isEditOpen = false;
      this.isEditClosing = false;
      this.selectedPhoto = null;
      this.photoPreview = null;
      this.lockPageScroll(false);
      this.cdr.detectChanges();
    }, 200);
  }

  private lockPageScroll(locked: boolean): void {
    try {
      document.documentElement.style.overflow = locked ? 'hidden' : '';
      document.body.style.overflow = locked ? 'hidden' : '';
    } catch (_) {}
  }

  ngOnDestroy(): void {
    this.stopSelfie();
    this.lockPageScroll(false);
  }

  // Colour picker
  isColourSelected(name: string): boolean {
    return this.editForm.vehicleColour.trim().toLowerCase() === name.toLowerCase();
  }

  selectColour(name: string): void {
    // Tapping the selected colour again clears it (the current value is kept on save).
    this.editForm.vehicleColour = this.isColourSelected(name) ? '' : name;
  }

  /** Keeps the focused field comfortably in view above the keyboard. */
  onFieldFocus(event: Event): void {
    const el = event.target as HTMLElement | null;
    if (!el) return;
    setTimeout(() => el.scrollIntoView({ block: 'center', behavior: 'smooth' }), 280);
  }

  // ---------- Photo: pick a file (images only) ----------

  private static readonly ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

  /** True when the file's first bytes are a real JPEG / PNG / WebP image. */
  private async looksLikeImage(file: Blob): Promise<boolean> {
    try {
      const buf = new Uint8Array(await file.slice(0, 12).arrayBuffer());
      const jpeg = buf[0] === 0xFF && buf[1] === 0xD8 && buf[2] === 0xFF;
      const png = buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4E && buf[3] === 0x47;
      const webp = buf[0] === 0x52 && buf[1] === 0x49 && buf[2] === 0x46 && buf[3] === 0x46 &&
                   buf[8] === 0x57 && buf[9] === 0x45 && buf[10] === 0x42 && buf[11] === 0x50;
      return jpeg || png || webp;
    } catch (_) {
      return false;
    }
  }

  /** Returns an error message, or null when the file is an acceptable photo. */
  private async photoProblem(file: File): Promise<string | null> {
    if (file.type.startsWith('video/')) return "Videos can't be used. Please choose a photo.";
    if (!ProfileComponent.ALLOWED_IMAGE_TYPES.includes(file.type)) {
      return 'Only JPG, PNG or WebP photos are allowed.';
    }
    if (file.size > 5 * 1024 * 1024) return 'That photo is too large. Please choose one under 5 MB.';
    if (!(await this.looksLikeImage(file))) return "That file isn't a valid photo. Please choose a JPG, PNG or WebP image.";
    return null;
  }

  async onPhotoSelected(event: Event): Promise<void> {
    const input = event.target as HTMLInputElement;
    const file = input.files && input.files.length ? input.files[0] : null;
    input.value = ''; // allow re-selecting the same file
    delete this.editErrors['photo'];
    if (!file) return;
    const problem = await this.photoProblem(file);
    if (problem) {
      this.editErrors['photo'] = problem;
      this.cdr.detectChanges();
      return;
    }
    this.setPhoto(file);
  }

  private setPhoto(file: File): void {
    this.selectedPhoto = file;
    const reader = new FileReader();
    reader.onload = () => {
      this.photoPreview = typeof reader.result === 'string' ? reader.result : null;
      this.cdr.detectChanges();
    };
    reader.readAsDataURL(file);
  }

  clearPhoto(): void {
    this.selectedPhoto = null;
    this.photoPreview = null;
    delete this.editErrors['photo'];
  }

  // ---------- Photo: take a selfie ----------

  async startSelfie(): Promise<void> {
    delete this.editErrors['photo'];
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      this.selfieFallback?.nativeElement.click();
      return;
    }
    try {
      this.selfieStream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'user', width: { ideal: 1080 }, height: { ideal: 1080 } },
        audio: false
      });
      this.capturedSelfie = null;
      this.selfieBlob = null;
      this.isCameraOpen = true;
      this.cdr.detectChanges();
      setTimeout(() => {
        const video = this.selfieVideo?.nativeElement;
        if (video && this.selfieStream) {
          video.srcObject = this.selfieStream;
          video.play().catch(() => {});
        }
      }, 50);
    } catch (err) {
      console.warn('[Profile] Camera unavailable, using the device camera picker:', err);
      this.releaseCamera();
      // Fall back to the phone's own camera app via a file input (front camera).
      this.selfieFallback?.nativeElement.click();
    }
  }

  captureSelfie(): void {
    const video = this.selfieVideo?.nativeElement;
    if (!video || !video.videoWidth) return;
    // Centre-crop to a square and cap the size, mirrored so it matches the preview.
    const side = Math.min(video.videoWidth, video.videoHeight);
    const out = Math.min(side, 900);
    const canvas = document.createElement('canvas');
    canvas.width = out;
    canvas.height = out;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    ctx.translate(out, 0);
    ctx.scale(-1, 1);
    ctx.drawImage(video, (video.videoWidth - side) / 2, (video.videoHeight - side) / 2, side, side, 0, 0, out, out);
    canvas.toBlob(blob => {
      if (!blob) return;
      this.selfieBlob = blob;
      this.capturedSelfie = canvas.toDataURL('image/jpeg', 0.9);
      this.cdr.detectChanges();
    }, 'image/jpeg', 0.9);
  }

  retakeSelfie(): void {
    this.capturedSelfie = null;
    this.selfieBlob = null;
    setTimeout(() => {
      const video = this.selfieVideo?.nativeElement;
      if (video && this.selfieStream) {
        video.srcObject = this.selfieStream;
        video.play().catch(() => {});
      }
    }, 50);
  }

  useSelfie(): void {
    if (!this.selfieBlob) return;
    const file = new File([this.selfieBlob], 'selfie.jpg', { type: 'image/jpeg' });
    this.stopSelfie();
    this.setPhoto(file);
  }

  stopSelfie(): void {
    this.releaseCamera();
    this.isCameraOpen = false;
    this.capturedSelfie = null;
    this.selfieBlob = null;
  }

  private releaseCamera(): void {
    if (this.selfieStream) {
      this.selfieStream.getTracks().forEach(t => t.stop());
      this.selfieStream = null;
    }
  }

  // ---------- Validate + save ----------

  private validateEdit(): boolean {
    const errors: Record<string, string> = {};
    const f = this.editForm;
    if (!f.fullName.trim() || f.fullName.trim().length < 2) {
      errors['fullName'] = 'Please enter your full name.';
    }
    if (f.email.trim() && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(f.email.trim())) {
      errors['email'] = 'Please enter a valid email address.';
    }
    if (f.phoneNumber.trim() && !/^\+?[0-9 ()-]{7,20}$/.test(f.phoneNumber.trim())) {
      errors['phoneNumber'] = 'Please enter a valid phone number, e.g. +44 7700 900123.';
    }
    if (f.regNo.trim() && !/^[A-Za-z0-9 ]{2,10}$/.test(f.regNo.trim())) {
      errors['regNo'] = 'Number plate can only contain letters and numbers.';
    }
    if (this.editErrors['photo']) {
      errors['photo'] = this.editErrors['photo'];
    }
    this.editErrors = errors;
    if (Object.keys(errors).length) {
      // Bring the first problem into view.
      setTimeout(() => document.querySelector('.ep-error')?.scrollIntoView({ block: 'center', behavior: 'smooth' }), 50);
    }
    return Object.keys(errors).length === 0;
  }

  saveProfile(): void {
    if (this.isSaving || this.saveDone || !this.validateEdit()) return;

    const f = this.editForm;
    const formData = new FormData();
    // Blank fields are not sent, so they keep their current value on the server.
    const add = (key: string, value: string) => {
      const v = value.trim();
      if (v) formData.append(key, v);
    };
    add('fullName', f.fullName);
    add('phoneNumber', f.phoneNumber);
    add('email', f.email);
    add('regNo', f.regNo.toUpperCase());
    add('vehicleMake', f.vehicleMake);
    add('vehicleModel', f.vehicleModel);
    add('vehicleColour', f.vehicleColour);
    if (this.selectedPhoto) {
      formData.append('photo', this.selectedPhoto, this.selectedPhoto.name);
    }

    this.isSaving = true;
    this.driverService.updateProfile(formData).subscribe({
      next: () => {
        this.isSaving = false;
        this.saveDone = true;
        this.cdr.detectChanges();
        // Show the "Saved" state briefly, then slide the sheet away.
        setTimeout(() => {
          this.saveDone = false;
          this.closeEdit();
          this.showToast('Profile updated');
          this.loadProfile();
        }, 650);
      },
      error: (err) => {
        this.isSaving = false;
        this.showToast(this.extractProfileError(err));
        this.cdr.detectChanges();
      }
    });
  }

  /** A short, user-safe message from an UpdateProfile failure (never a raw HTTP dump). */
  private extractProfileError(err: any): string {
    try {
      const raw = err?.error;
      const body = typeof raw === 'string' ? JSON.parse(raw) : raw;
      const msg = body?.errors?.[0]?.message || body?.message || body?.title;
      if (typeof msg === 'string' && msg.trim()) return msg.trim();
    } catch (_) { /* not JSON */ }
    if (err?.status === 0) return 'No connection. Check your internet and try again.';
    if (err?.status === 401) return 'Your session has expired. Please sign in again.';
    if (err?.status === 413) return 'That photo is too large. Please choose a smaller one.';
    return 'Could not update your profile. Please try again.';
  }

  loadProfile(): void {
    this.isLoading = true;
    const userId = this.getDriverUserId();
    this.driverId = userId;
    console.log('[Profile] Resolved driver userId for documents API:', userId);

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
        this.profilePhotoUrl = profile.photoUrl || profile.photo || profile.imageUrl || profile.profilePhoto || profile.avatar || '';

        const clean = (v: any) => (v === null || v === undefined) ? '' : String(v).trim();
        this.rawProfile = {
          fullName: clean(profile.fullname || profile.fullName || profile.name),
          phoneNumber: clean(profile.telephone || profile.phone || profile.phoneNumber),
          email: clean(profile.email),
          regNo: clean(profile.vehicleReg || profile.regNo || profile.plateNumber || profile.registration),
          vehicleMake: clean(vehicleMake),
          vehicleModel: clean(vehicleModel),
          vehicleColour: clean(vehicleColour)
        };
      }

      // Fetch live documents from /api/v2/drivers/{userId}/documents
      this.fetchDriverDocuments(userId);
    });
  }

  private fetchDriverDocuments(userId: number): void {
    console.log(`[Profile] Fetching live documents from /api/v2/drivers/${userId}/documents`);
    this.driverService.getDriverDocuments(userId).pipe(
      catchError(err => {
        console.warn(`[Profile] /api/v2/drivers/${userId}/documents returned error:`, err);
        if (userId !== 3) {
          console.log('[Profile] Retrying with staging driver ID 3 fallback...');
          return this.driverService.getDriverDocuments(3).pipe(catchError(() => of(null)));
        }
        return of(null);
      })
    ).subscribe({
      next: (docsResponse) => {
        if (docsResponse && (docsResponse.success || Array.isArray(docsResponse.data) || Array.isArray(docsResponse))) {
          const docList: any[] = Array.isArray(docsResponse) 
            ? docsResponse 
            : (docsResponse.data || docsResponse.value || []);
          
          console.log(`[Profile] Successfully loaded ${docList.length} documents from API:`, docList);

          // Reset all documents to default 'Missing' state before populating from API
          this.documents.forEach(doc => {
            doc.status = 'Missing';
            doc.expiry = 'Not Uploaded';
            doc.url = null;
            doc.rejectionReason = null;
            doc.uploadedAt = null;
            doc.reviewedAt = null;
            doc.rawStatus = undefined;
          });

          docList.forEach((item: any) => {
            const docType = Number(item.documentType ?? item.type);
            const doc = this.documents.find(d => d.type === docType);
            if (doc) {
              doc.id = item.id;
              doc.userId = item.userId;
              doc.rawStatus = item.status;
              doc.url = item.fileUrl || item.url || item.documentUrl || null;
              doc.originalFileName = item.originalFileName || null;
              doc.uploadedAt = item.uploadedAt || null;
              doc.reviewedAt = item.reviewedAt || null;
              doc.reviewedByUserId = item.reviewedByUserId || null;
              doc.rejectionReason = item.rejectionReason || null;

              // 0 = Pending, 1 = Approved, 2 = Rejected
              if (item.status === 1) {
                doc.status = 'Approved';
                doc.expiry = item.reviewedAt 
                  ? `Approved ${this.formatSimpleDate(item.reviewedAt)}` 
                  : 'Approved & Verified';
              } else if (item.status === 2) {
                doc.status = 'Rejected';
                doc.expiry = item.rejectionReason 
                  ? `Reason: ${item.rejectionReason}` 
                  : 'Rejected by Admin • Re-upload required';
              } else if (item.status === 0) {
                doc.status = 'Pending Verification';
                doc.expiry = item.uploadedAt 
                  ? `Uploaded ${this.formatSimpleDate(item.uploadedAt)} • Under Review` 
                  : 'Under review by dispatch';
              }
            }
          });
        }
      },
      complete: () => {
        this.enrichWithExpirys(userId);
      }
    });
  }

  private enrichWithExpirys(userId: number): void {
    this.driverService.getDriverExpirys().pipe(
      catchError(err => {
        console.warn('[Profile] Failed to fetch document expiries:', err);
        return of(null);
      })
    ).subscribe({
      next: (expirysResponse) => {
        if (expirysResponse && expirysResponse.success && Array.isArray(expirysResponse.value)) {
          const myExpirys = expirysResponse.value.filter((e: any) => e.userId === userId);
          console.log(`[Profile] Enriched ${myExpirys.length} expiries for userId ${userId}`);
          
          myExpirys.forEach((exp: any) => {
            const docType = exp.documentType;
            const docItem = this.documents.find(d => d.type === docType);
            if (docItem) {
              if (docItem.status === 'Approved' || docItem.status === 'Valid') {
                docItem.expiry = this.formatExpiryDate(exp.expiryDate);
                docItem.status = this.getDocumentStatus(exp.expiryDate);
              }
              if (!docItem.url) {
                docItem.url = exp.documentUrl || exp.fileUrl || exp.url || null;
              }
            }
          });
        }
      },
      complete: () => {
        this.isLoading = false;
        this.isRefreshing = false;
        this.cdr.detectChanges();
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
    return this.documents.filter(d => d.status === 'Valid' || d.status === 'Approved').length;
  }

  getActionNeededCount(): number {
    return this.documents.filter(d => d.status === 'Missing' || d.status === 'Rejected' || d.status === 'Expired' || d.status === 'Expiring Soon').length;
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

  getDisplayStatus(doc: DriverDoc | null): string {
    if (!doc) return '';
    if (doc.status === 'Approved' || doc.status === 'Valid') return 'Approved';
    if (doc.status === 'Pending Verification') return 'Pending';
    if (doc.status === 'Rejected') return 'Rejected';
    if (doc.status === 'Missing') return 'Missing';
    return doc.status;
  }

  getDocIcon(status: string): string {
    switch (status) {
      case 'Valid':
      case 'Approved':
        return 'check_circle';
      case 'Expiring Soon': 
        return 'warning';
      case 'Expired': 
        return 'cancel';
      case 'Pending Verification': 
        return 'hourglass_top';
      case 'Rejected':
        return 'error';
      default: 
        return 'upload_file';
    }
  }

  getDocExpiryFormatted(doc: DriverDoc): string {
    if (doc.status === 'Rejected') {
      return doc.rejectionReason ? `Reason: ${doc.rejectionReason}` : 'Rejected by Admin • Re-upload required';
    }
    if (doc.status === 'Missing' || doc.expiry === 'Not Uploaded') {
      return 'Upload required';
    }
    if (doc.status === 'Pending Verification' || doc.expiry === 'Under Review') {
      return doc.uploadedAt 
        ? `Uploaded ${this.formatSimpleDate(doc.uploadedAt)} • Under Review` 
        : 'Under review by dispatch';
    }
    if (doc.status === 'Approved') {
      return doc.reviewedAt 
        ? `Approved ${this.formatSimpleDate(doc.reviewedAt)}` 
        : (doc.expiry && doc.expiry !== 'Not Uploaded' ? `Expires: ${doc.expiry}` : 'Approved & Verified');
    }
    return `Expires: ${doc.expiry}`;
  }

  getFilteredDocuments(): DriverDoc[] {
    if (this.selectedDocFilter === 'action') {
      return this.documents.filter(d => 
        d.status === 'Missing' || 
        d.status === 'Rejected' || 
        d.status === 'Expired' || 
        d.status === 'Expiring Soon'
      );
    }
    if (this.selectedDocFilter === 'verified') {
      return this.documents.filter(d => d.status === 'Valid' || d.status === 'Approved');
    }
    return this.documents;
  }

  getDriverUserId(): number {
    // 1. Check URL query parameters (both search query and hash fragments)
    try {
      const searchParams = new URLSearchParams(window.location.search);
      let uidStr = searchParams.get('userId') || searchParams.get('driverId') || searchParams.get('driver_id') || searchParams.get('id');
      if (!uidStr && window.location.hash.includes('?')) {
        const hashQuery = window.location.hash.split('?')[1];
        const hashParams = new URLSearchParams(hashQuery);
        uidStr = hashParams.get('userId') || hashParams.get('driverId') || hashParams.get('driver_id') || hashParams.get('id');
      }
      if (uidStr && !isNaN(Number(uidStr)) && Number(uidStr) > 0) {
        return Number(uidStr);
      }
    } catch (_) {}

    // 2. Check localStorage
    try {
      const storedId = localStorage.getItem('driver_user_id') || localStorage.getItem('user_id') || localStorage.getItem('driver_id');
      if (storedId && !isNaN(Number(storedId)) && Number(storedId) > 0) {
        return Number(storedId);
      }
    } catch (_) {}

    // 3. Check JWT payload
    const token = localStorage.getItem('auth_token');
    if (token) {
      try {
        const parts = token.split('.');
        if (parts.length === 3) {
          let base64Url = parts[1];
          let base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
          while (base64.length % 4) {
            base64 += '=';
          }
          const payload = JSON.parse(atob(base64));
          const userId = payload.driverId || payload.driver_id || payload.DriverId || payload.userId || payload.id || payload.nameid;
          if (userId && !isNaN(Number(userId)) && Number(userId) > 0) {
            return Number(userId);
          }
        }
      } catch (e) {
        console.error('Failed to parse JWT token for userId:', e);
      }
    }

    // Default staging fallback
    return 3;
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

  formatSimpleDate(dateStr: string | null | undefined): string {
    if (!dateStr) return '';
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) return dateStr;
    const day = d.getDate();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const h = d.getHours().toString().padStart(2, '0');
    const m = d.getMinutes().toString().padStart(2, '0');
    return `${day} ${months[d.getMonth()]} ${d.getFullYear()}, ${h}:${m}`;
  }

  private showToast(message: string): void {
    this.snackBar.open(message, 'OK', {
      duration: 3000,
      horizontalPosition: 'center',
      verticalPosition: 'bottom'
    });
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
    if (this.isEditOpen) return;
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
    const userId = this.driverId || this.getDriverUserId();
    this.router.navigate(['/upload'], { queryParams: { type, name, userId } });
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
