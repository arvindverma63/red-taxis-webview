import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatListModule } from '@angular/material/list';
import { MatIconModule } from '@angular/material/icon';
import { MatSlideToggleModule } from '@angular/material/slide-toggle';
import { MatDividerModule } from '@angular/material/divider';
import { MatButtonModule } from '@angular/material/button';

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
            <div class="avatar-initials">PP</div>
          </div>
          <div class="profile-identity">
            <h2 class="mat-headline-small">Peter Parker</h2>
            <span class="badge-pill role-badge">Red Taxi Driver</span>
            <div class="stats-row">
              <span class="stat"><mat-icon class="star-icon">star</mat-icon> 4.95 Rating</span>
              <span class="divider">•</span>
              <span class="stat">2,410 Trips</span>
            </div>
          </div>
        </mat-card-content>
      </mat-card>

      <!-- Details List -->
      <main class="profile-content">
        <!-- Personal and Vehicle Details -->
        <mat-card class="section-card">
          <mat-card-header>
            <mat-card-title>Account & Vehicle Details</mat-card-title>
          </mat-card-header>
          <mat-card-content>
            <mat-list>
              <mat-list-item>
                <mat-icon matListItemIcon>email</mat-icon>
                <span matListItemTitle class="item-lbl">Email</span>
                <span matListItemLine class="item-val">peter.parker&#64;redtaxis.com</span>
              </mat-list-item>
              <mat-divider></mat-divider>
              <mat-list-item>
                <mat-icon matListItemIcon>phone</mat-icon>
                <span matListItemTitle class="item-lbl">Phone</span>
                <span matListItemLine class="item-val">+44 7911 123456</span>
              </mat-list-item>
              <mat-divider></mat-divider>
              <mat-list-item>
                <mat-icon matListItemIcon>directions_car</mat-icon>
                <span matListItemTitle class="item-lbl">Vehicle Model</span>
                <span matListItemLine class="item-val">Toyota Prius (Hybrid)</span>
              </mat-list-item>
              <mat-divider></mat-divider>
              <mat-list-item>
                <mat-icon matListItemIcon>pin</mat-icon>
                <span matListItemTitle class="item-lbl">Plate / Registration</span>
                <span matListItemLine class="item-val">
                  <span class="highlight-plate">LK17 WXY</span>
                </span>
              </mat-list-item>
              <mat-divider></mat-divider>
              <mat-list-item>
                <mat-icon matListItemIcon>badge</mat-icon>
                <span matListItemTitle class="item-lbl">Driver Badge</span>
                <span matListItemLine class="item-val">TX-9981 (London Central)</span>
              </mat-list-item>
            </mat-list>
          </mat-card-content>
        </mat-card>

        <!-- Document Verification -->
        <mat-card class="section-card">
          <mat-card-header>
            <mat-card-title>Compliance Documents</mat-card-title>
          </mat-card-header>
          <mat-card-content>
            <mat-list>
              <mat-list-item *ngFor="let doc of documents">
                <mat-icon matListItemIcon [ngClass]="doc.status.toLowerCase().replace(' ', '-')">
                  {{ doc.status === 'Valid' ? 'check_circle' : doc.status === 'Expiring Soon' ? 'warning' : 'cancel' }}
                </mat-icon>
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
          <mat-card-header>
            <mat-card-title>Preferences</mat-card-title>
          </mat-card-header>
          <mat-card-content class="pref-content">
            <div class="preference-row">
              <div class="pref-text">
                <span class="pref-title mat-subtitle-2">Auto-Accept Job Offers</span>
                <span class="pref-desc mat-body-small">Automatically accept incoming matching bookings.</span>
              </div>
              <mat-slide-toggle [checked]="autoAccept" (change)="toggleAutoAccept()" color="primary"></mat-slide-toggle>
            </div>
            <mat-divider></mat-divider>
            <div class="preference-row">
              <div class="pref-text">
                <span class="pref-title mat-subtitle-2">Accept Night Shifts</span>
                <span class="pref-desc mat-body-small">Receive notifications for trips between 22:00 and 06:00.</span>
              </div>
              <mat-slide-toggle [checked]="nightShifts" (change)="toggleNightShifts()" color="primary"></mat-slide-toggle>
            </div>
          </mat-card-content>
        </mat-card>
      </main>
    </div>
  `,
  styles: [`
    .material-container {
      padding: 16px;
      background-color: var(--background-color);
      min-height: 100vh;
    }

    /* Profile Header Card */
    .profile-header-card {
      background: linear-gradient(135deg, var(--primary-color) 0%, var(--primary-dark) 100%);
      color: #FFFFFF;
      border-radius: 16px !important;
      margin-bottom: 20px;
      box-shadow: 0 4px 12px rgba(229, 57, 85, 0.15) !important;
    }
    .header-content {
      display: flex;
      align-items: center;
      gap: 16px;
      padding: 16px !important;
    }
    .avatar-container {
      width: 64px;
      height: 64px;
      background-color: rgba(255,255,255,0.2);
      border: 2px solid rgba(255,255,255,0.4);
      border-radius: 50%;
      display: flex;
      justify-content: center;
      align-items: center;
      flex-shrink: 0;
    }
    .avatar-initials {
      font-size: 24px;
      font-weight: 800;
    }
    .profile-identity h2 {
      margin: 0 0 4px 0;
      color: #FFFFFF;
      font-weight: 700;
    }
    .badge-pill {
      font-size: 10px;
      font-weight: bold;
      padding: 2px 8px;
      border-radius: 12px;
      text-transform: uppercase;
    }
    .role-badge {
      background-color: rgba(255,255,255,0.15);
      border: 1px solid rgba(255,255,255,0.3);
    }
    .stats-row {
      display: flex;
      align-items: center;
      gap: 6px;
      margin-top: 6px;
      font-size: 12px;
      opacity: 0.9;
    }
    .star-icon {
      color: #FFD700;
      font-size: 14px;
      width: 14px;
      height: 14px;
      vertical-align: middle;
    }
    .divider {
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
      box-shadow: none !important;
      border-radius: 12px !important;
    }
    .section-card mat-card-title {
      font-size: 15px;
      font-weight: 700;
      color: var(--text-secondary);
      text-transform: uppercase;
      letter-spacing: 0.5px;
      padding: 16px 16px 0 16px;
    }
    .section-card mat-card-content {
      padding: 8px 0 !important;
    }

    .item-lbl {
      color: var(--text-secondary);
      font-size: 11px;
      font-weight: 500;
    }
    .item-val {
      color: var(--text-primary);
      font-weight: 600;
      font-size: 13px;
    }
    .highlight-plate {
      background-color: #FFD54F;
      color: #111;
      padding: 2px 6px;
      border-radius: 4px;
      display: inline-block;
      font-family: monospace;
      font-weight: bold;
      border: 1px solid #FFC107;
    }

    /* Documents Styling */
    .doc-title {
      font-size: 13px;
      font-weight: 600;
      color: var(--text-primary);
    }
    .doc-subtitle {
      font-size: 11px;
      color: var(--text-secondary);
    }
    .status-lbl {
      font-size: 11px;
      font-weight: 700;
    }
    mat-icon.valid, .status-lbl.valid {
      color: #4CAF50;
    }
    mat-icon.expiring-soon, .status-lbl.expiring-soon {
      color: #FF9800;
    }
    mat-icon.expired, .status-lbl.expired {
      color: #F44336;
    }

    /* Preferences */
    .pref-content {
      padding: 8px 16px !important;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .preference-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 8px 0;
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
    }
    .pref-desc {
      color: var(--text-secondary);
    }
  `]
})
export class ProfileComponent {
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

  toggleAutoAccept(): void {
    this.autoAccept = !this.autoAccept;
  }

  toggleNightShifts(): void {
    this.nightShifts = !this.nightShifts;
  }
}
