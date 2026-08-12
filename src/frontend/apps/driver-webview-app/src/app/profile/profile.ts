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
  status: 'Valid' | 'Expiring Soon' | 'Expired' | 'Missing';
  expiry: string;
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
          <!-- Personal and Vehicle Details -->
          <mat-card class="section-card">
            <mat-card-header class="section-header">
              <mat-card-title class="section-title">Account & Vehicle Details</mat-card-title>
            </mat-card-header>
            <mat-card-content class="section-body">
              <mat-list class="compact-list">
                <mat-list-item class="profile-list-item">
                  <span class="material-symbols-outlined item-icon" matListItemIcon>mail</span>
                  <span matListItemTitle class="item-lbl">Email</span>
                  <span matListItemLine class="item-val">{{ driverEmail }}</span>
                </mat-list-item>
                <mat-divider></mat-divider>
                <mat-list-item class="profile-list-item">
                  <span class="material-symbols-outlined item-icon" matListItemIcon>call</span>
                  <span matListItemTitle class="item-lbl">Phone</span>
                  <span matListItemLine class="item-val">{{ driverPhone }}</span>
                </mat-list-item>
                <mat-divider></mat-divider>
                <mat-list-item class="profile-list-item">
                  <span class="material-symbols-outlined item-icon" matListItemIcon>local_taxi</span>
                  <span matListItemTitle class="item-lbl">Vehicle Info</span>
                  <span matListItemLine class="item-val">{{ vehicleModel }}</span>
                </mat-list-item>
                <mat-divider></mat-divider>
                <mat-list-item class="profile-list-item">
                  <span class="material-symbols-outlined item-icon" matListItemIcon>license</span>
                  <span matListItemTitle class="item-lbl">Plate / Registration</span>
                  <span matListItemLine class="item-val">
                    <span class="highlight-plate">{{ plateNumber }}</span>
                  </span>
                </mat-list-item>
                <mat-divider *ngIf="colorCode"></mat-divider>
                <mat-list-item class="profile-list-item" *ngIf="colorCode">
                  <span class="material-symbols-outlined item-icon" matListItemIcon>palette</span>
                  <span matListItemTitle class="item-lbl">Theme Color</span>
                  <span matListItemLine class="item-val font-semibold" style="display: flex; align-items: center; gap: 8px;">
                    <span style="display: inline-block; width: 12px; height: 12px; border-radius: 50%; border: 1px solid #ECEFF1;" [style.background-color]="colorCode.startsWith('#') ? colorCode : '#' + colorCode"></span>
                    <span>{{ colorCode }}</span>
                  </span>
                </mat-list-item>
              </mat-list>
            </mat-card-content>
          </mat-card>

          <!-- Document Verification -->
          <mat-card class="section-card">
            <mat-card-header class="section-header">
              <mat-card-title class="section-title">Compliance Documents</mat-card-title>
            </mat-card-header>
            <mat-card-content class="section-body">
              <mat-nav-list class="compact-list">
                <a mat-list-item *ngFor="let doc of documents" (click)="navigateToUpload(doc.type, doc.name)" class="profile-list-item clickable-item" style="cursor: pointer; display: block;">
                  <span 
                    class="material-symbols-outlined item-icon" 
                    matListItemIcon 
                    [ngClass]="doc.status.toLowerCase().replace(' ', '-')"
                  >
                    {{ doc.status === 'Valid' ? 'check_circle' : doc.status === 'Expiring Soon' ? 'warning' : doc.status === 'Expired' ? 'cancel' : 'help' }}
                  </span>
                  <span matListItemTitle class="doc-title">{{ doc.name }}</span>
                  <span matListItemLine class="doc-subtitle">
                    {{ doc.expiry === 'Not Uploaded' ? 'Not Uploaded yet' : 'Expires ' + doc.expiry }}
                  </span>
                  <span matListItemMeta class="status-lbl" [ngClass]="doc.status.toLowerCase().replace(' ', '-')">
                    {{ doc.status }}
                  </span>
                </a>
              </mat-nav-list>
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

    /* Documents Styling */
    .doc-title {
      font-size: 13px;
      font-weight: 600;
      color: var(--text-primary);
      margin-bottom: 2px;
    }
    .doc-subtitle {
      font-size: 11px;
      color: var(--text-secondary);
    }
    .status-lbl {
      font-size: 9px;
      font-weight: 700;
      padding: 4px 10px;
      border-radius: 12px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .status-lbl.valid {
      background-color: rgba(76, 175, 80, 0.08);
      color: #388E3C;
    }
    .status-lbl.expiring-soon {
      background-color: rgba(255, 152, 0, 0.08);
      color: #F57C00;
    }
    .status-lbl.expired {
      background-color: rgba(244, 67, 54, 0.08);
      color: #D32F2F;
    }
    .status-lbl.missing {
      background-color: rgba(144, 164, 174, 0.08);
      color: #546E7A;
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
                }
              });
            }
          },
          complete: () => {
            this.isLoading = false;
            this.cdr.detectChanges();
          }
        });
      } else {
        this.isLoading = false;
        this.cdr.detectChanges();
      }
    });
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
