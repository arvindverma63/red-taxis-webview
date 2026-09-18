import { Component, OnInit, OnDestroy, ChangeDetectorRef, ViewChild, ElementRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router } from '@angular/router';
import { DriverService } from '../services/driver.service';
import { Subscription, interval } from 'rxjs';
import { takeWhile } from 'rxjs/operators';
import { MatSnackBar } from '@angular/material/snack-bar';

interface ViaStop {
  address: string;
  postCode?: string;
}

interface JobDetails {
  id: string;
  fare: number;
  pickup: string;
  dropoff: string;
  vias?: ViaStop[];
  paymentType: string;
  vehicleType: string;
  passenger: string;
  notes: string;
}

@Component({
  selector: 'app-job-offer',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="job-offer-container">
      <!-- Full screen status pages for Cancelled, Unallocated, and Amended bookings -->
      <div class="status-overlay-card animated-fade-in" *ngIf="jobStatus && jobStatus !== 'active'">
        <div class="status-header">
          <span class="material-symbols-outlined status-icon" [ngClass]="jobStatus">
            {{ getStatusIconName() }}
          </span>
          <h2 class="status-title">{{ getStatusTitleText() }}</h2>
          <p class="status-body">{{ getStatusBodyText() }}</p>
        </div>

        <div class="status-details-box" *ngIf="job">
          <div class="status-row">
            <span class="status-lbl">Booking Reference:</span>
            <span class="status-val font-mono">#{{ job.id }}</span>
          </div>
          <div class="status-row" *ngIf="job.passenger">
            <span class="status-lbl">Passenger:</span>
            <span class="status-val font-bold">{{ job.passenger }}</span>
          </div>
          <div class="status-row">
            <span class="status-lbl">Route:</span>
            <span class="status-val route-compact">{{ job.pickup }} ➔ {{ job.dropoff }}</span>
          </div>
          <div class="status-row" *ngIf="job.vias && job.vias.length > 0">
            <span class="status-lbl">Via Stops ({{ job.vias.length }}):</span>
            <span class="status-val route-compact">
              <span *ngFor="let via of job.vias; let i = index">
                {{ i + 1 }}. {{ via.address }}<br *ngIf="i < job.vias.length - 1"/>
              </span>
            </span>
          </div>
        </div>

        <button class="status-ok-btn" (click)="dismissStatusScreen()">
          <span>Acknowledge & Close</span>
        </button>
      </div>

      <!-- Executive Job Offer Bottom Sheet / Modal -->
      <div class="offer-sheet animated-slide-up" *ngIf="job && (!jobStatus || jobStatus === 'active')">
        <!-- Sheet Top Grabber -->
        <div class="sheet-grabber-bar">
          <div class="sheet-grabber"></div>
        </div>

        <!-- Hero Dispatch Header Card -->
        <div class="offer-hero-card">
          <!-- Ambient Glow Background -->
          <div class="hero-glow-bg"></div>

          <div class="hero-content">
            <!-- Top Live Header Pill -->
            <div class="incoming-pill-row">
              <div class="incoming-badge">
                <span class="live-beacon-dot"></span>
                <span>INCOMING DISPATCH OFFER</span>
              </div>
              <span class="ref-tag">#{{ job.id }}</span>
            </div>

            <!-- Fare & Countdown Row -->
            <div class="fare-timer-row">
              <div class="fare-block">
                <span class="fare-label">ESTIMATED FARE</span>
                <div class="fare-amount">
                  <span class="cur-sign">£</span>
                  <span class="fare-number">{{ job.fare.toFixed(2) }}</span>
                </div>
              </div>

              <!-- High-Precision SVG Countdown Ring -->
              <div class="countdown-dial-wrapper">
                <svg class="countdown-svg" width="60" height="60" viewBox="0 0 60 60">
                  <circle
                    class="countdown-track"
                    stroke="rgba(255, 255, 255, 0.15)"
                    stroke-width="4"
                    fill="transparent"
                    r="25"
                    cx="30"
                    cy="30"
                  />
                  <circle
                    class="countdown-progress"
                    [attr.stroke]="secondsRemaining <= 5 ? '#EF4444' : '#10B981'"
                    stroke-width="4"
                    stroke-linecap="round"
                    fill="transparent"
                    r="25"
                    cx="30"
                    cy="30"
                    [style.strokeDashoffset]="strokeDashoffset"
                  />
                </svg>
                <div class="countdown-inner-text">
                  <span class="countdown-sec" [class.urgent]="secondsRemaining <= 5">{{ secondsRemaining }}</span>
                  <span class="countdown-unit">SEC</span>
                </div>
              </div>
            </div>

            <!-- Telemetry Badges -->
            <div class="hero-badges-row">
              <span class="hero-badge payment" [ngClass]="job.paymentType.toLowerCase()">
                <span class="material-symbols-outlined badge-ico">payments</span>
                <span>{{ job.paymentType }}</span>
              </span>
              <span class="hero-badge vehicle">
                <span class="material-symbols-outlined badge-ico">local_taxi</span>
                <span>{{ job.vehicleType }}</span>
              </span>
              <span class="hero-badge passenger" *ngIf="job.passenger">
                <span class="material-symbols-outlined badge-ico">person</span>
                <span>{{ job.passenger }}</span>
              </span>
            </div>
          </div>
        </div>

        <!-- Scrollable Route Details Card -->
        <div class="offer-body-card">
          <!-- Driver Notes Alert (if present) -->
          <div class="notes-banner" *ngIf="job.notes && job.notes.trim().length > 0">
            <span class="material-symbols-outlined notes-ico">speaker_notes</span>
            <div class="notes-body">
              <span class="notes-head">Driver Instructions:</span>
              <p class="notes-txt">{{ job.notes }}</p>
            </div>
          </div>

          <!-- Connected Route Stepper -->
          <div class="route-stepper">
            <!-- Pickup Stop -->
            <div class="stepper-row">
              <div class="node-col">
                <div class="node-circle pickup">
                  <span class="material-symbols-outlined">my_location</span>
                </div>
                <div class="node-connector"></div>
              </div>
              <div class="node-content">
                <span class="node-lbl pickup-lbl">PICKUP LOCATION</span>
                <span class="node-address">{{ job.pickup }}</span>
              </div>
            </div>

            <!-- Via Stops (if any) -->
            <div class="stepper-row via-step" *ngFor="let via of job.vias; let i = index">
              <div class="node-col">
                <div class="node-circle via">
                  <span class="material-symbols-outlined">pin_drop</span>
                </div>
                <div class="node-connector"></div>
              </div>
              <div class="node-content">
                <div class="via-header">
                  <span class="node-lbl via-lbl">VIA STOP {{ i + 1 }}</span>
                  <span class="via-postcode-chip" *ngIf="via.postCode">{{ via.postCode }}</span>
                </div>
                <span class="node-address">{{ via.address }}</span>
              </div>
            </div>

            <!-- Dropoff Stop -->
            <div class="stepper-row">
              <div class="node-col">
                <div class="node-circle dropoff">
                  <span class="material-symbols-outlined">location_on</span>
                </div>
              </div>
              <div class="node-content">
                <span class="node-lbl dropoff-lbl">DESTINATION</span>
                <span class="node-address">{{ job.dropoff }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- Action Footer with Smooth Slide to Accept -->
        <div class="offer-footer">
          <!-- Buttery Smooth Slide to Accept Widget -->
          <div 
            class="smooth-slider-container"
            #slider
            [class.dragging]="isDragging"
            [class.accepted]="isAccepted"
          >
            <!-- Background Track with Dynamic Fill -->
            <div 
              class="slider-fill-track"
              [style.width.px]="sliderPosition + 52"
            ></div>

            <!-- Centered Track Text -->
            <div class="slider-center-label">
              <span *ngIf="isAccepted">ACCEPTED! REDIRECTING...</span>
              <span *ngIf="isSubmitting && !isAccepted">SECURING ALLOCATION...</span>
              <span *ngIf="!isAccepted && !isSubmitting">{{ isDragging ? 'Release to Accept' : 'SLIDE TO ACCEPT OFFER' }}</span>
            </div>

            <!-- Smooth Thumb Handle -->
            <div 
              class="smooth-slider-thumb"
              [style.transform]="'translate3d(' + sliderPosition + 'px, 0, 0)'"
              (mousedown)="onDragStart($event)"
              (touchstart)="onDragStart($event)"
              (click)="onSliderClick($event)"
            >
              <span class="material-symbols-outlined thumb-icon" *ngIf="!isAccepted && !isSubmitting">keyboard_double_arrow_right</span>
              <span class="material-symbols-outlined check-icon" *ngIf="isAccepted">check</span>
              <span class="material-symbols-outlined spinning-icon" *ngIf="isSubmitting && !isAccepted">refresh</span>
            </div>
          </div>

          <!-- Decline Offer Button -->
          <button 
            class="btn-decline-offer"
            [disabled]="isSubmitting || isAccepted"
            (click)="decline()"
          >
            <span class="material-symbols-outlined">close</span>
            <span>Decline Offer</span>
          </button>
        </div>

      </div>
    </div>
  `,
  styles: [`
    :host {
      display: block;
      min-height: 100vh;
      font-family: 'Roboto', -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }

    .job-offer-container {
      position: relative;
      background: #0F172A url('/map_bg.png') no-repeat center center;
      background-size: cover;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      justify-content: flex-end;
      align-items: center;
      box-sizing: border-box;
      overflow: hidden;
    }

    /* Ambient Overlay */
    .job-offer-container::before {
      content: '';
      position: absolute;
      top: 0; left: 0; right: 0; bottom: 0;
      background: radial-gradient(circle at center, rgba(15, 23, 42, 0.4) 0%, rgba(15, 23, 42, 0.85) 100%);
      backdrop-filter: blur(4px);
      z-index: 1;
    }

    /* Offer Bottom Sheet */
    .offer-sheet {
      position: relative;
      z-index: 2;
      background: #FFFFFF;
      border-top-left-radius: 24px;
      border-top-right-radius: 24px;
      padding: 8px 14px 20px 14px;
      box-shadow: 0 -12px 36px rgba(0, 0, 0, 0.35);
      display: flex;
      flex-direction: column;
      gap: 10px;
      max-height: 92vh;
      overflow-y: auto;
      width: 100%;
      max-width: 520px;
      box-sizing: border-box;
      margin: 0 auto;
    }

    @media (min-width: 600px) {
      .offer-sheet {
        border-radius: 24px;
        margin-bottom: 16px;
        width: 94%;
      }
    }

    .sheet-grabber-bar {
      display: flex;
      justify-content: center;
      padding: 4px 0 2px 0;
    }
    .sheet-grabber {
      width: 40px;
      height: 4px;
      background: #CBD5E1;
      border-radius: 2px;
    }

    /* 1. Hero Dispatch Card */
    .offer-hero-card {
      position: relative;
      background: linear-gradient(135deg, #1E293B 0%, #0F172A 100%);
      color: #FFFFFF;
      border-radius: 18px;
      padding: 14px 16px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.2);
      border: 1px solid rgba(255, 255, 255, 0.1);
      overflow: hidden;
    }
    .hero-glow-bg {
      position: absolute;
      top: -30px;
      right: -30px;
      width: 140px;
      height: 140px;
      border-radius: 50%;
      background: radial-gradient(circle, #CD1A21 0%, transparent 70%);
      opacity: 0.35;
      filter: blur(30px);
      pointer-events: none;
    }
    .hero-content {
      position: relative;
      z-index: 2;
      display: flex;
      flex-direction: column;
      gap: 10px;
    }

    .incoming-pill-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .incoming-badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: rgba(205, 26, 33, 0.2);
      border: 1px solid rgba(205, 26, 33, 0.45);
      padding: 3px 8px;
      border-radius: 6px;
      font-size: 10px;
      font-weight: 800;
      letter-spacing: 0.4px;
      color: #FCA5A5;
    }
    .live-beacon-dot {
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background: #EF4444;
      animation: beaconPulse 1.4s infinite ease-in-out;
    }
    @keyframes beaconPulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.4; transform: scale(1.4); }
    }
    .ref-tag {
      font-size: 11px;
      font-weight: 700;
      font-family: monospace;
      color: #CBD5E1;
      background: rgba(255, 255, 255, 0.08);
      padding: 2px 6px;
      border-radius: 4px;
    }

    .fare-timer-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .fare-block {
      display: flex;
      flex-direction: column;
    }
    .fare-label {
      font-size: 10px;
      font-weight: 700;
      color: #94A3B8;
      letter-spacing: 0.4px;
      text-transform: uppercase;
    }
    .fare-amount {
      display: flex;
      align-items: baseline;
      gap: 2px;
    }
    .cur-sign {
      font-size: 20px;
      font-weight: 800;
      color: #EF4444;
    }
    .fare-number {
      font-size: 32px;
      font-weight: 900;
      letter-spacing: -0.5px;
      color: #FFFFFF;
    }

    /* SVG Countdown Dial */
    .countdown-dial-wrapper {
      position: relative;
      width: 58px;
      height: 58px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .countdown-svg {
      transform: rotate(-90deg);
    }
    .countdown-progress {
      transition: stroke-dashoffset 0.8s linear, stroke 0.3s ease;
    }
    .countdown-inner-text {
      position: absolute;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      line-height: 1;
    }
    .countdown-sec {
      font-size: 16px;
      font-weight: 900;
      color: #FFFFFF;
    }
    .countdown-sec.urgent {
      color: #EF4444;
      animation: urgentPulse 0.6s infinite alternate;
    }
    @keyframes urgentPulse {
      from { transform: scale(1); }
      to { transform: scale(1.18); }
    }
    .countdown-unit {
      font-size: 8px;
      font-weight: 700;
      color: #94A3B8;
      margin-top: 1px;
    }

    /* Hero Badges */
    .hero-badges-row {
      display: flex;
      align-items: center;
      flex-wrap: wrap;
      gap: 6px;
      padding-top: 4px;
      border-top: 1px solid rgba(255, 255, 255, 0.08);
    }
    .hero-badge {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      padding: 3px 8px;
      border-radius: 6px;
      font-size: 11px;
      font-weight: 700;
      background: rgba(255, 255, 255, 0.1);
      color: #E2E8F0;
    }
    .badge-ico { font-size: 14px; }
    .hero-badge.payment.cash { background: #064E3B; color: #6EE7B7; border: 1px solid rgba(16, 185, 129, 0.4); }
    .hero-badge.payment.card { background: #1E1B4B; color: #A5B4FC; border: 1px solid rgba(99, 102, 241, 0.4); }
    .hero-badge.payment.account { background: #581C87; color: #E9D5FF; border: 1px solid rgba(168, 85, 247, 0.4); }

    /* 2. Body Card & Route */
    .offer-body-card {
      background: #F8FAFC;
      border: 1px solid #E2E8F0;
      border-radius: 16px;
      padding: 12px 14px;
      display: flex;
      flex-direction: column;
      gap: 10px;
    }

    .notes-banner {
      background: #FFFBEB;
      border: 1px solid #FDE68A;
      border-radius: 10px;
      padding: 8px 10px;
      display: flex;
      align-items: flex-start;
      gap: 8px;
    }
    .notes-ico {
      font-size: 18px;
      color: #D97706;
      flex-shrink: 0;
      margin-top: 1px;
    }
    .notes-body {
      display: flex;
      flex-direction: column;
      gap: 1px;
    }
    .notes-head {
      font-size: 10px;
      font-weight: 700;
      color: #B45309;
      text-transform: uppercase;
      letter-spacing: 0.3px;
    }
    .notes-txt {
      margin: 0;
      font-size: 12px;
      font-weight: 600;
      color: #92400E;
      line-height: 1.35;
    }

    .route-stepper {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .stepper-row {
      display: flex;
      align-items: flex-start;
      gap: 10px;
    }
    .node-col {
      display: flex;
      flex-direction: column;
      align-items: center;
      width: 26px;
      flex-shrink: 0;
    }
    .node-circle {
      width: 26px;
      height: 26px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .node-circle .material-symbols-outlined { font-size: 14px; }
    .node-circle.pickup { background: #DCFCE7; color: #16A34A; }
    .node-circle.via { background: #FEF3C7; color: #D97706; }
    .node-circle.dropoff { background: #FEE2E2; color: #DC2626; }
    .node-connector {
      width: 2px;
      height: 18px;
      background: #CBD5E1;
      margin: 3px 0;
    }

    .node-content {
      flex: 1;
      min-width: 0;
      display: flex;
      flex-direction: column;
      gap: 1px;
    }
    .node-lbl {
      font-size: 9px;
      font-weight: 700;
      letter-spacing: 0.3px;
    }
    .pickup-lbl { color: #15803D; }
    .via-lbl { color: #B45309; }
    .dropoff-lbl { color: #B91C1C; }
    .node-address {
      font-size: 13px;
      font-weight: 700;
      color: #0F172A;
      line-height: 1.35;
    }
    .via-header {
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .via-postcode-chip {
      font-size: 9px;
      font-weight: 800;
      font-family: monospace;
      background: #FEF08A;
      color: #000000;
      padding: 1px 4px;
      border-radius: 3px;
    }

    /* 3. Smooth Slider Footer */
    .offer-footer {
      display: flex;
      flex-direction: column;
      gap: 8px;
      margin-top: 2px;
    }

    .smooth-slider-container {
      position: relative;
      height: 52px;
      background: #0F172A;
      border-radius: 26px;
      overflow: hidden;
      display: flex;
      align-items: center;
      justify-content: center;
      user-select: none;
      box-shadow: 0 4px 14px rgba(15, 23, 42, 0.25);
    }
    .slider-fill-track {
      position: absolute;
      left: 0;
      top: 0;
      bottom: 0;
      background: linear-gradient(90deg, #10B981, #059669);
      border-radius: 26px;
      pointer-events: none;
      transition: width 0.05s ease;
    }
    .smooth-slider-container.accepted .slider-fill-track {
      width: 100% !important;
      background: #10B981 !important;
    }
    .slider-center-label {
      position: relative;
      z-index: 2;
      font-size: 12.5px;
      font-weight: 800;
      color: #FFFFFF;
      letter-spacing: 0.6px;
      pointer-events: none;
      text-transform: uppercase;
    }
    .smooth-slider-thumb {
      position: absolute;
      left: 4px;
      width: 44px;
      height: 44px;
      border-radius: 50%;
      background: #FFFFFF;
      color: #0F172A;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: grab;
      z-index: 3;
      box-shadow: 0 3px 10px rgba(0, 0, 0, 0.35);
      touch-action: none;
      will-change: transform;
      transition: transform 0.25s cubic-bezier(0.2, 0.9, 0.3, 1);
    }
    .smooth-slider-container.dragging .smooth-slider-thumb {
      cursor: grabbing;
      transition: none;
    }
    .thumb-icon { font-size: 22px; }
    .check-icon { font-size: 22px; color: #10B981; }
    .spinning-icon { font-size: 22px; animation: spin 0.8s linear infinite; }

    .btn-decline-offer {
      background: transparent;
      border: 1px solid #CBD5E1;
      padding: 9px;
      border-radius: 12px;
      font-size: 12px;
      font-weight: 700;
      color: #64748B;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 4px;
      cursor: pointer;
      transition: background 0.15s ease;
    }
    .btn-decline-offer:hover {
      background: #F1F5F9;
      color: #0F172A;
    }
    .btn-decline-offer .material-symbols-outlined { font-size: 16px; }

    /* Status Overlay */
    .status-overlay-card {
      position: relative;
      z-index: 10;
      background: #FFFFFF;
      border-radius: 20px;
      padding: 24px 20px;
      max-width: 440px;
      width: 90%;
      margin: auto;
      box-shadow: 0 16px 40px rgba(0, 0, 0, 0.3);
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
      gap: 14px;
    }
    .status-icon {
      font-size: 48px;
    }
    .status-icon.cancelled { color: #EF4444; }
    .status-icon.unallocated { color: #F59E0B; }
    .status-icon.amended { color: #3B82F6; }
    .status-title {
      margin: 0;
      font-size: 18px;
      font-weight: 800;
      color: #0F172A;
    }
    .status-body {
      margin: 0;
      font-size: 12px;
      color: #64748B;
      line-height: 1.4;
    }
    .status-details-box {
      width: 100%;
      background: #F8FAFC;
      border-radius: 10px;
      padding: 10px 12px;
      border: 1px solid #E2E8F0;
      display: flex;
      flex-direction: column;
      gap: 6px;
      text-align: left;
    }
    .status-row {
      display: flex;
      justify-content: space-between;
      font-size: 11px;
    }
    .status-lbl { color: #64748B; font-weight: 500; }
    .status-val { color: #0F172A; font-weight: 600; }
    .status-ok-btn {
      width: 100%;
      background: #CD1A21;
      color: #FFFFFF;
      border: none;
      padding: 12px;
      border-radius: 12px;
      font-size: 13px;
      font-weight: 700;
      cursor: pointer;
    }

    /* Animations */
    .animated-slide-up {
      animation: slideUp 0.28s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    }
    @keyframes slideUp {
      from { transform: translateY(100%); }
      to { transform: translateY(0); }
    }
    .animated-fade-in {
      animation: fadeIn 0.2s ease-in-out;
    }
    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }

    /* Dark Mode Overrides */
    :host-context(.dark-theme) .offer-sheet {
      background: #1E1E24;
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .offer-body-card {
      background: #16161A;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .node-address {
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .node-connector {
      background: #2D2D35;
    }
    :host-context(.dark-theme) .btn-decline-offer {
      border-color: #3E3E48;
      color: #94A3B8;
    }
    :host-context(.dark-theme) .status-overlay-card {
      background: #1E1E24;
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .status-title {
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .status-details-box {
      background: #16161A;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .status-val {
      color: #ECEFF1;
    }
  `]
})
export class JobOfferComponent implements OnInit, OnDestroy {
  @ViewChild('slider') sliderEl?: ElementRef<HTMLDivElement>;

  job: JobDetails | null = null;
  jobStatus: string | null = null;
  jobIdFromUrl: string | null = null;
  guid: string | null = null;

  secondsRemaining = 15;
  private readonly strokeDasharray = 2 * Math.PI * 25; // ~157.08
  private timerSub?: Subscription;

  isDragging = false;
  sliderPosition = 0;
  maxDragRange = 0;
  startX = 0;
  isSubmitting = false;
  isAccepted = false;

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private driverService: DriverService,
    private snackBar: MatSnackBar,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.route.queryParams.subscribe(params => {
      this.jobIdFromUrl = params['jobId'] || params['id'] || params['jobno'] || null;
      this.guid = params['guid'] || null;
      this.jobStatus = params['status'] || 'active';

      if (this.guid && typeof localStorage !== 'undefined') {
        localStorage.setItem('last_guid', this.guid);
      }

      const fareVal = parseFloat(params['fare'] || '0.00');
      let vias: ViaStop[] = [];
      if (params['vias']) {
        try {
          const parsed = JSON.parse(params['vias']);
          if (Array.isArray(parsed)) {
            vias = parsed.map((v: any) => ({
              address: typeof v === 'string' ? v : (v.address || v.stopAddress || 'Via Stop'),
              postCode: typeof v === 'object' ? (v.postCode || v.postcode || '') : ''
            }));
          }
        } catch (_) {}
      }

      this.job = {
        id: this.jobIdFromUrl || '84920',
        fare: isNaN(fareVal) ? 0.00 : fareVal,
        pickup: params['pickup'] || 'Pickup Location',
        dropoff: params['dropoff'] || 'Destination',
        vias: vias.length > 0 ? vias : undefined,
        paymentType: params['paymentType'] || 'Cash',
        vehicleType: params['vehicleType'] || 'Standard Saloon',
        passenger: params['passenger'] || 'Passenger',
        notes: params['notes'] || ''
      };

      this.startTimer();
      this.cdr.detectChanges();
    });
  }

  startTimer(): void {
    if (this.jobStatus && this.jobStatus !== 'active') return;
    this.timerSub?.unsubscribe();
    this.timerSub = interval(1000)
      .pipe(takeWhile(() => this.secondsRemaining > 0 && (!this.jobStatus || this.jobStatus === 'active')))
      .subscribe({
        next: () => {
          this.secondsRemaining--;
          this.cdr.detectChanges();
          if (this.secondsRemaining === 0) {
            this.autoReject();
          }
        }
      });
  }

  get strokeDashoffset(): number {
    return this.strokeDasharray * (1 - this.secondsRemaining / 15);
  }

  // --- Smooth Touch & Mouse Gesture Physics ---
  onDragStart(event: MouseEvent | TouchEvent): void {
    if (this.isSubmitting || this.isAccepted) return;
    this.isDragging = true;
    this.startX = this.getEventX(event) - this.sliderPosition;

    if (this.sliderEl) {
      const containerWidth = this.sliderEl.nativeElement.clientWidth;
      const thumbWidth = 44;
      this.maxDragRange = Math.max(0, containerWidth - thumbWidth - 8);
    }

    if (event instanceof MouseEvent) {
      document.addEventListener('mousemove', this.onDragMove);
      document.addEventListener('mouseup', this.onDragEnd);
    } else {
      document.addEventListener('touchmove', this.onDragMove, { passive: false });
      document.addEventListener('touchend', this.onDragEnd);
    }
  }

  onDragMove = (event: MouseEvent | TouchEvent): void => {
    if (!this.isDragging || this.isSubmitting || this.isAccepted) return;
    event.preventDefault();

    const currentX = this.getEventX(event);
    let position = currentX - this.startX;

    if (position < 0) position = 0;
    if (position > this.maxDragRange) position = this.maxDragRange;

    this.sliderPosition = position;
    this.cdr.detectChanges();

    if (this.maxDragRange > 0 && this.sliderPosition >= this.maxDragRange * 0.82) {
      this.onDragEnd(event);
      this.sliderPosition = this.maxDragRange;
      this.accept();
    }
  };

  onDragEnd = (event: MouseEvent | TouchEvent): void => {
    this.isDragging = false;
    document.removeEventListener('mousemove', this.onDragMove);
    document.removeEventListener('mouseup', this.onDragEnd);
    document.removeEventListener('touchmove', this.onDragMove);
    document.removeEventListener('touchend', this.onDragEnd);

    if (!this.isSubmitting && !this.isAccepted) {
      this.sliderPosition = 0;
      this.cdr.detectChanges();
    }
  };

  onSliderClick(event: MouseEvent): void {
    if (this.isDragging || this.isSubmitting || this.isAccepted) return;
    if (this.sliderEl) {
      const containerWidth = this.sliderEl.nativeElement.clientWidth;
      const thumbWidth = 44;
      this.maxDragRange = Math.max(0, containerWidth - thumbWidth - 8);
      this.sliderPosition = this.maxDragRange;
      this.cdr.detectChanges();
    }
    this.accept();
  }

  private getEventX(event: MouseEvent | TouchEvent): number {
    return event instanceof MouseEvent ? event.clientX : event.touches[0].clientX;
  }

  // --- Actions ---
  accept(): void {
    if (this.isSubmitting || this.isAccepted) return;
    this.isSubmitting = true;
    this.isAccepted = true;
    this.timerSub?.unsubscribe();
    this.cdr.detectChanges();

    const jobId = this.job?.id || this.jobIdFromUrl || '';
    const numericJobId = parseInt(jobId) || 0;
    const effectiveGuid = this.guid || (typeof localStorage !== 'undefined' ? localStorage.getItem('last_guid') || '' : '');
    
    const doDismiss = () => {
      setTimeout(() => {
        this.notifyNativeApp('job_accepted');
      }, 400);
    };

    if (jobId && !jobId.startsWith('sim-')) {
      this.driverService.replyJobOffer(numericJobId, 2000, effectiveGuid).subscribe({
        next: () => {
          this.snackBar.open(`Job #${jobId} Accepted!`, 'OK', { duration: 3000 });
          doDismiss();
        },
        error: () => {
          this.driverService.setActiveJob(numericJobId).subscribe({
            next: () => {
              this.snackBar.open(`Job #${jobId} Accepted!`, 'OK', { duration: 3000 });
              doDismiss();
            },
            error: () => {
              this.snackBar.open(`Job #${jobId} Accepted!`, 'OK', { duration: 3000 });
              doDismiss();
            }
          });
        }
      });
    } else {
      doDismiss();
    }
  }

  decline(): void {
    if (this.isSubmitting || this.isAccepted) return;
    this.isSubmitting = true;
    this.timerSub?.unsubscribe();
    this.cdr.detectChanges();

    const jobId = this.job?.id || this.jobIdFromUrl || '';
    const numericJobId = parseInt(jobId) || 0;
    const effectiveGuid = this.guid || (typeof localStorage !== 'undefined' ? localStorage.getItem('last_guid') || '' : '');

    if (jobId && !jobId.startsWith('sim-')) {
      this.driverService.replyJobOffer(numericJobId, 2001, effectiveGuid).subscribe({
        next: () => {
          this.notifyNativeApp('job_rejected');
        },
        error: () => {
          this.notifyNativeApp('job_rejected');
        }
      });
    } else {
      this.notifyNativeApp('job_rejected');
    }
  }

  private autoReject(): void {
    if (this.isSubmitting || this.isAccepted) return;
    this.isSubmitting = true;
    const jobId = this.job?.id || this.jobIdFromUrl || '';
    const numericJobId = parseInt(jobId) || 0;
    const effectiveGuid = this.guid || (typeof localStorage !== 'undefined' ? localStorage.getItem('last_guid') || '' : '');

    if (jobId && !jobId.startsWith('sim-')) {
      this.driverService.replyJobOffer(numericJobId, 2001, effectiveGuid).subscribe({
        next: () => this.notifyNativeApp('job_rejected'),
        error: () => this.notifyNativeApp('job_rejected')
      });
    } else {
      this.notifyNativeApp('job_rejected');
    }
  }

  private notifyNativeApp(message: string): void {
    try {
      const channel = (window as any).FlutterChannel;
      if (channel) {
        channel.postMessage(message);
      }
    } catch (err) {
      console.warn('Native notification error:', err);
    }
  }

  getStatusIconName(): string {
    switch (this.jobStatus) {
      case 'cancelled': return 'cancel';
      case 'unallocated': return 'info';
      case 'amended': return 'edit';
      default: return 'info';
    }
  }

  getStatusTitleText(): string {
    switch (this.jobStatus) {
      case 'cancelled': return 'Job Cancelled';
      case 'unallocated': return 'Job Unallocated';
      case 'amended': return 'Job Amended';
      default: return 'Job Notification';
    }
  }

  getStatusBodyText(): string {
    switch (this.jobStatus) {
      case 'cancelled': return 'This booking was cancelled by dispatch.';
      case 'unallocated': return 'This booking was unallocated from your dispatch queue.';
      case 'amended': return 'The operator has amended the details of this trip.';
      default: return 'Booking status updated.';
    }
  }

  dismissStatusScreen(): void {
    this.notifyNativeApp('close_custom_webview');
    this.notifyNativeApp('job_rejected');
    this.router.navigate(['/bookings']);
  }

  ngOnDestroy(): void {
    this.timerSub?.unsubscribe();
  }
}
