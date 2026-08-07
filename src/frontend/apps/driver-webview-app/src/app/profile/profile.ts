import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';

interface DriverDoc {
  name: string;
  status: 'Valid' | 'Expiring Soon' | 'Expired';
  expiry: string;
}

@Component({
  selector: 'app-profile',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="webview-container">
      <!-- Profile Header -->
      <header class="profile-header-card">
        <div class="avatar-container">
          <div class="avatar-initials">PP</div>
        </div>
        <div class="profile-identity">
          <h2>Peter Parker</h2>
          <span class="badge-pill role-badge">Red Taxi Driver</span>
          <div class="stats-row">
            <span class="stat"><span class="star-icon">★</span> 4.95 Rating</span>
            <span class="divider">•</span>
            <span class="stat">2,410 Trips</span>
          </div>
        </div>
      </header>

      <!-- Details List -->
      <main class="profile-content">
        <!-- Personal and Vehicle Details -->
        <section class="info-section">
          <h3>Account & Vehicle Details</h3>
          <div class="info-grid">
            <div class="info-item">
              <span class="info-label">Email</span>
              <span class="info-value">peter.parker&#64;redtaxis.com</span>
            </div>
            <div class="info-item">
              <span class="info-label">Phone</span>
              <span class="info-value">+44 7911 123456</span>
            </div>
            <div class="info-item">
              <span class="info-label">Vehicle Model</span>
              <span class="info-value">Toyota Prius (Hybrid)</span>
            </div>
            <div class="info-item">
              <span class="info-label">Plate / Registration</span>
              <span class="info-value highlight-plate">LK17 WXY</span>
            </div>
            <div class="info-item">
              <span class="info-label">Driver Badge</span>
              <span class="info-value">TX-9981 (London Central)</span>
            </div>
            <div class="info-item">
              <span class="info-label">Base Rate Commission</span>
              <span class="info-value">12.5%</span>
            </div>
          </div>
        </section>

        <!-- Document Verification -->
        <section class="info-section">
          <h3>Compliance Documents</h3>
          <div class="docs-list">
            <div *ngFor="let doc of documents" class="doc-card">
              <div class="doc-info">
                <span class="doc-name">{{ doc.name }}</span>
                <span class="doc-expiry">Expires {{ doc.expiry }}</span>
              </div>
              <span class="doc-status" [ngClass]="doc.status.toLowerCase().replace(' ', '-')">
                {{ doc.status }}
              </span>
            </div>
          </div>
        </section>

        <!-- Preferences -->
        <section class="info-section">
          <h3>Preferences</h3>
          <div class="preferences-list">
            <div class="preference-item">
              <div class="pref-text">
                <span class="pref-title">Auto-Accept Job Offers</span>
                <span class="pref-desc">Automatically accept incoming matching bookings.</span>
              </div>
              <label class="switch">
                <input type="checkbox" [checked]="autoAccept" (change)="toggleAutoAccept()">
                <span class="slider"></span>
              </label>
            </div>
            <div class="preference-item">
              <div class="pref-text">
                <span class="pref-title">Accept Night Shifts</span>
                <span class="pref-desc">Receive notifications for trips between 22:00 and 06:00.</span>
              </div>
              <label class="switch">
                <input type="checkbox" [checked]="nightShifts" (change)="toggleNightShifts()">
                <span class="slider"></span>
              </label>
            </div>
          </div>
        </section>
      </main>
    </div>
  `,
  styles: [`
    .webview-container {
      padding: 16px;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    }

    /* Header Profile Card */
    .profile-header-card {
      background: linear-gradient(135deg, var(--primary-color) 0%, var(--primary-dark) 100%);
      border-radius: 20px;
      padding: 20px;
      display: flex;
      align-items: center;
      gap: 20px;
      color: #FFFFFF;
      margin-bottom: 24px;
      box-shadow: 0 8px 16px rgba(229, 57, 85, 0.15);
    }
    .avatar-container {
      width: 72px;
      height: 72px;
      background-color: rgba(255,255,255,0.2);
      border: 3px solid rgba(255,255,255,0.4);
      border-radius: 50%;
      display: flex;
      justify-content: center;
      align-items: center;
      flex-shrink: 0;
    }
    .avatar-initials {
      font-size: 28px;
      font-weight: 800;
      color: #FFFFFF;
    }
    .profile-identity h2 {
      margin: 0 0 6px 0;
      font-size: 22px;
      font-weight: 800;
      letter-spacing: -0.5px;
    }
    .badge-pill {
      font-size: 11px;
      font-weight: bold;
      padding: 3px 8px;
      border-radius: 12px;
      text-transform: uppercase;
    }
    .role-badge {
      background-color: rgba(255,255,255,0.15);
      border: 1px solid rgba(255,255,255,0.3);
      color: #FFFFFF;
    }
    .stats-row {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-top: 8px;
      font-size: 13px;
      opacity: 0.9;
    }
    .star-icon {
      color: #FFD700;
    }
    .divider {
      opacity: 0.5;
    }

    /* Profile Content Sections */
    .profile-content {
      display: flex;
      flex-direction: column;
      gap: 20px;
    }
    .info-section h3 {
      font-size: 15px;
      font-weight: 700;
      margin: 0 0 12px 0;
      color: var(--text-secondary);
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .info-grid {
      background-color: var(--surface-color);
      border: 1px solid var(--border-color);
      border-radius: 16px;
      padding: 16px;
      display: flex;
      flex-direction: column;
      gap: 14px;
    }
    .info-item {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .info-label {
      font-size: 11px;
      color: var(--text-secondary);
      font-weight: 500;
    }
    .info-value {
      font-size: 14px;
      font-weight: 600;
      color: var(--text-primary);
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
      width: fit-content;
    }
    @media(prefers-color-scheme: dark) {
      .highlight-plate {
        background-color: #FFE082;
        color: #111;
      }
    }

    /* Docs List */
    .docs-list {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .doc-card {
      background-color: var(--surface-color);
      border: 1px solid var(--border-color);
      border-radius: 12px;
      padding: 12px 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      transition: all 0.2s ease;
    }
    .doc-info {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .doc-name {
      font-size: 13px;
      font-weight: 600;
      color: var(--text-primary);
    }
    .doc-expiry {
      font-size: 11px;
      color: var(--text-secondary);
    }
    .doc-status {
      font-size: 11px;
      font-weight: 700;
      padding: 4px 8px;
      border-radius: 6px;
    }
    .doc-status.valid {
      background-color: rgba(76, 175, 80, 0.1);
      color: #4CAF50;
    }
    .doc-status.expiring-soon {
      background-color: rgba(255, 152, 0, 0.1);
      color: #FF9800;
    }
    .doc-status.expired {
      background-color: rgba(244, 67, 54, 0.1);
      color: #F44336;
    }

    /* Preferences Switches */
    .preferences-list {
      background-color: var(--surface-color);
      border: 1px solid var(--border-color);
      border-radius: 16px;
      padding: 8px 16px;
      display: flex;
      flex-direction: column;
    }
    .preference-item {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 14px 0;
      border-bottom: 1px solid var(--border-color);
    }
    .preference-item:last-child {
      border-bottom: none;
    }
    .pref-text {
      display: flex;
      flex-direction: column;
      gap: 2px;
      padding-right: 16px;
    }
    .pref-title {
      font-size: 14px;
      font-weight: 600;
      color: var(--text-primary);
    }
    .pref-desc {
      font-size: 11px;
      color: var(--text-secondary);
      line-height: 1.4;
    }

    /* Switch Slider Style */
    .switch {
      position: relative;
      display: inline-block;
      width: 48px;
      height: 26px;
      flex-shrink: 0;
    }
    .switch input {
      opacity: 0;
      width: 0;
      height: 0;
    }
    .slider {
      position: absolute;
      cursor: pointer;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background-color: var(--border-color);
      transition: .3s;
      border-radius: 34px;
    }
    .slider:before {
      position: absolute;
      content: "";
      height: 18px;
      width: 18px;
      left: 4px;
      bottom: 4px;
      background-color: white;
      transition: .3s;
      border-radius: 50%;
    }
    input:checked + .slider {
      background-color: var(--primary-color);
    }
    input:checked + .slider:before {
      transform: translateX(22px);
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
