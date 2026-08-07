import { Component, OnInit } from '@angular/core';
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
  name: string;
  status: 'Valid' | 'Expiring Soon' | 'Expired';
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
      <!-- Profile Header -->
      <mat-card class="profile-header-card">
        <mat-card-content class="header-content">
          <div class="avatar-container">
            <div class="avatar-circle">
              <span class="material-symbols-outlined person-avatar-icon">person</span>
            </div>
          </div>
          <div class="profile-identity">
            <h2 class="mat-headline-small name-title">{{ driverName }}</h2>
            <span class="badge-pill role-badge">Red Taxis Driver</span>
            <div class="stats-row">
              <span class="stat"><mat-icon class="star-icon">star</mat-icon> {{ rating }} Rating</span>
              <span class="divider-dot">•</span>
              <span class="stat">{{ tripsCount | number }} Trips</span>
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
                <span matListItemTitle class="item-lbl">Vehicle Model</span>
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
              <mat-divider></mat-divider>
              <mat-list-item class="profile-list-item">
                <span class="material-symbols-outlined item-icon" matListItemIcon>badge</span>
                <span matListItemTitle class="item-lbl">Driver Badge</span>
                <span matListItemLine class="item-val font-semibold">{{ badgeNumber }}</span>
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
            <mat-list class="compact-list">
              <mat-list-item *ngFor="let doc of documents" class="profile-list-item" (click)="navigateToUpload(doc.name)" style="cursor: pointer;">
                <span 
                  class="material-symbols-outlined item-icon" 
                  matListItemIcon 
                  [ngClass]="doc.status.toLowerCase().replace(' ', '-')"
                >
                  {{ doc.status === 'Valid' ? 'check_circle' : doc.status === 'Expiring Soon' ? 'warning' : 'cancel' }}
                </span>
                <span matListItemTitle class="doc-title">{{ doc.name }}</span>
                <span matListItemLine class="doc-subtitle">Expires {{ doc.expiry }}</span>
                <span matListItemMeta class="status-lbl" [ngClass]="doc.status.toLowerCase().replace(' ', '-')">
                  {{ doc.status }}
                </span>
              </mat-list-item>
            </mat-list>
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
  `]
})
export class ProfileComponent implements OnInit {
  driverName = 'Peter Parker';
  driverEmail = 'peter.parker@redtaxis.com';
  driverPhone = '+44 7911 123456';
  vehicleModel = 'Toyota Prius (Hybrid)';
  plateNumber = 'LK17 WXY';
  badgeNumber = 'TX-9981 (London Central)';
  rating = 4.95;
  tripsCount = 2410;

  autoAccept = true;
  nightShifts = false;

  documents: DriverDoc[] = [
    {
      name: 'Hackney Carriage / PHV License',
      status: 'Valid',
      expiry: '12 Dec 2027'
    },
    {
      name: 'Private Hire Motor Insurance',
      status: 'Expiring Soon',
      expiry: '15 Sep 2026'
    },
    {
      name: 'Vehicle MOT Test Certificate',
      status: 'Valid',
      expiry: '04 Jun 2027'
    }
  ];

  constructor(private router: Router, private driverService: DriverService) {}

  ngOnInit(): void {
    this.driverService.getProfile().pipe(
      catchError(err => {
        console.warn('Staging API GetProfile failed, using mock data:', err);
        return of(null);
      })
    ).subscribe(profile => {
      if (profile) {
        this.driverName = profile.fullName || profile.name || this.driverName;
        this.driverEmail = profile.email || this.driverEmail;
        this.driverPhone = profile.phone || profile.phoneNumber || this.driverPhone;
        this.vehicleModel = profile.vehicleModel || profile.carModel || this.vehicleModel;
        this.plateNumber = profile.plateNumber || profile.registration || this.plateNumber;
        this.badgeNumber = profile.badgeNumber || profile.driverBadge || this.badgeNumber;
        this.rating = profile.rating || this.rating;
        this.tripsCount = profile.tripsCount || profile.trips || this.tripsCount;
        if (profile.documents && Array.isArray(profile.documents)) {
          this.documents = profile.documents.map((d: any) => ({
            name: d.name || d.title,
            status: d.status || 'Valid',
            expiry: d.expiry || d.expiryDate
          }));
        }
      }
    });
  }

  navigateToUpload(docName: string): void {
    this.router.navigate(['/upload'], { queryParams: { doc: docName } });
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
