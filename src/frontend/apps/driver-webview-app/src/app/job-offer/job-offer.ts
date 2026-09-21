import { Component, OnInit, OnDestroy, ChangeDetectorRef, ViewChild, ElementRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router } from '@angular/router';
import { DriverService } from '../services/driver.service';
import { Subscription, interval, of } from 'rxjs';
import { takeWhile, catchError } from 'rxjs/operators';
import { MatSnackBar } from '@angular/material/snack-bar';

interface ViaStop {
  address: string;
  postCode?: string;
}

interface JobDetails {
  id: string;
  fare: number;
  pickup: string;
  pickupPostCode?: string;
  dropoff: string;
  destinationPostCode?: string;
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
      <!-- Executive Status Screen for Cancelled, Unallocated, and Amended bookings -->
      <div class="status-overlay-card animated-fade-in" *ngIf="jobStatus && jobStatus !== 'active'">
        <!-- Status Header Banner -->
        <div class="status-banner" [ngClass]="jobStatus">
          <div class="status-icon-circle">
            <span class="material-symbols-outlined status-icon">
              {{ getStatusIconName() }}
            </span>
          </div>
          <div class="status-banner-text">
            <div class="status-badge-row">
              <span class="status-type-pill">{{ getStatusBadgeText() }}</span>
              <span class="status-ref-tag font-mono">#{{ job?.id || jobIdFromUrl }}</span>
            </div>
            <h2 class="status-title">{{ getStatusTitleText() }}</h2>
            <p class="status-body">{{ getStatusBodyText() }}</p>
          </div>
        </div>

        <!-- Comprehensive Booking Details Card -->
        <div class="status-details-card" *ngIf="job">
          <!-- Summary Metrics: Passenger, Fare, Payment -->
          <div class="status-meta-row">
            <div class="status-meta-item">
              <span class="meta-label">PASSENGER</span>
              <span class="meta-val font-bold">{{ job.passenger || 'Passenger' }}</span>
            </div>
            <div class="status-meta-item" *ngIf="job.fare > 0">
              <span class="meta-label">TOTAL FARE</span>
              <span class="meta-val fare-green">£{{ job.fare.toFixed(2) }}</span>
            </div>
            <div class="status-meta-item">
              <span class="meta-label">PAYMENT</span>
              <span class="meta-val payment-tag" [ngClass]="job.paymentType.toLowerCase()">{{ job.paymentType || 'Cash' }}</span>
            </div>
          </div>

          <!-- Complete Journey Route Stepper -->
          <div class="status-route-stepper">
            <!-- Pickup -->
            <div class="status-route-row clickable-step" (click)="openGoogleMap(job.pickupPostCode || job.pickup, $event)" title="Open in Google Maps">
              <div class="status-node-col">
                <span class="status-node-dot pickup"></span>
                <div class="status-node-line"></div>
              </div>
              <div class="status-node-info">
                <div class="status-node-header">
                  <span class="status-node-tag pickup">PICKUP LOCATION</span>
                  <span class="postcode-tag" *ngIf="job.pickupPostCode">{{ job.pickupPostCode }}</span>
                  <span class="map-tag"><span class="material-symbols-outlined">near_me</span> Map</span>
                </div>
                <span class="status-node-addr">{{ job.pickup }}</span>
              </div>
            </div>

            <!-- Via Stops (if any) -->
            <div class="status-route-row clickable-step" *ngFor="let via of job.vias; let i = index" (click)="openGoogleMap(via.postCode || via.address, $event)" title="Open in Google Maps">
              <div class="status-node-col">
                <span class="status-node-dot via"></span>
                <div class="status-node-line"></div>
              </div>
              <div class="status-node-info">
                <div class="status-node-header">
                  <span class="status-node-tag via">VIA STOP {{ i + 1 }}</span>
                  <span class="postcode-tag" *ngIf="via.postCode">{{ via.postCode }}</span>
                  <span class="map-tag"><span class="material-symbols-outlined">near_me</span> Map</span>
                </div>
                <span class="status-node-addr">{{ via.address }}</span>
              </div>
            </div>

            <!-- Destination -->
            <div class="status-route-row clickable-step" (click)="openGoogleMap(job.destinationPostCode || job.dropoff, $event)" title="Open in Google Maps">
              <div class="status-node-col">
                <span class="status-node-dot dropoff"></span>
              </div>
              <div class="status-node-info">
                <div class="status-node-header">
                  <span class="status-node-tag dropoff">DESTINATION</span>
                  <span class="postcode-tag" *ngIf="job.destinationPostCode">{{ job.destinationPostCode }}</span>
                  <span class="map-tag"><span class="material-symbols-outlined">near_me</span> Map</span>
                </div>
                <span class="status-node-addr">{{ job.dropoff }}</span>
              </div>
            </div>
          </div>

          <!-- Driver Notes Box (if any) -->
          <div class="status-notes-box" *ngIf="job.notes && job.notes.trim().length > 0">
            <span class="material-symbols-outlined notes-icon">speaker_notes</span>
            <div class="notes-content">
              <span class="notes-title">Instructions & Notes:</span>
              <p class="notes-text">{{ job.notes }}</p>
            </div>
          </div>
        </div>

        <!-- Action Button -->
        <button class="status-ok-btn" [ngClass]="jobStatus" (click)="dismissStatusScreen()">
          <span class="material-symbols-outlined">check_circle</span>
          <span>Acknowledge & View Bookings</span>
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
            <div class="stepper-row clickable-step" (click)="openGoogleMap(job.pickupPostCode || job.pickup, $event)" title="Open in Google Maps">
              <div class="node-col">
                <div class="node-circle pickup">
                  <span class="material-symbols-outlined">my_location</span>
                </div>
                <div class="node-connector"></div>
              </div>
              <div class="node-content">
                <div class="via-header">
                  <span class="node-lbl pickup-lbl">PICKUP LOCATION</span>
                  <span class="postcode-tag" *ngIf="job.pickupPostCode">{{ job.pickupPostCode }}</span>
                  <span class="map-tag"><span class="material-symbols-outlined">near_me</span> Map</span>
                </div>
                <span class="node-address">{{ job.pickup }}</span>
              </div>
            </div>

            <!-- Via Stops (if any) -->
            <div class="stepper-row via-step clickable-step" *ngFor="let via of job.vias; let i = index" (click)="openGoogleMap(via.postCode || via.address, $event)" title="Open in Google Maps">
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
                  <span class="map-tag"><span class="material-symbols-outlined">near_me</span> Map</span>
                </div>
                <span class="node-address">{{ via.address }}</span>
              </div>
            </div>

            <!-- Dropoff Stop -->
            <div class="stepper-row clickable-step" (click)="openGoogleMap(job.destinationPostCode || job.dropoff, $event)" title="Open in Google Maps">
              <div class="node-col">
                <div class="node-circle dropoff">
                  <span class="material-symbols-outlined">location_on</span>
                </div>
              </div>
              <div class="node-content">
                <div class="via-header">
                  <span class="node-lbl dropoff-lbl">DESTINATION</span>
                  <span class="postcode-tag" *ngIf="job.destinationPostCode">{{ job.destinationPostCode }}</span>
                  <span class="map-tag"><span class="material-symbols-outlined">near_me</span> Map</span>
                </div>
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
      height: 100vh;
      min-height: 100vh;
      max-height: 100vh;
      display: flex;
      flex-direction: column;
      justify-content: flex-end;
      align-items: center;
      box-sizing: border-box;
      overflow: hidden;
      padding: 0;
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
      padding: 6px 14px 0 14px;
      box-shadow: 0 -12px 36px rgba(0, 0, 0, 0.35);
      display: flex;
      flex-direction: column;
      gap: 8px;
      max-height: 100vh;
      width: 100%;
      max-width: 520px;
      box-sizing: border-box;
      margin: 0 auto;
      overflow: hidden;
    }

    @media (min-width: 600px) {
      .offer-sheet {
        border-radius: 24px;
        margin-bottom: 16px;
        width: 94%;
        padding-bottom: 16px;
      }
    }

    .sheet-grabber-bar {
      display: flex;
      justify-content: center;
      padding: 4px 0 2px 0;
      flex-shrink: 0;
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
      padding: 12px 14px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.2);
      border: 1px solid rgba(255, 255, 255, 0.1);
      overflow: hidden;
      flex-shrink: 0;
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
      gap: 8px;
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
      font-size: 30px;
      font-weight: 900;
      letter-spacing: -0.5px;
      color: #FFFFFF;
    }

    /* SVG Countdown Dial */
    .countdown-dial-wrapper {
      position: relative;
      width: 54px;
      height: 54px;
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
      font-size: 15px;
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
    .hero-badge.payment.cash { background: #064E3B; color: #6EE7B7; border: 1px solid rgba(160, 235, 200, 0.3); }
    .hero-badge.payment.card { background: #1E1B4B; color: #A5B4FC; border: 1px solid rgba(165, 180, 252, 0.3); }
    .hero-badge.payment.account { background: #581C87; color: #E9D5FF; border: 1px solid rgba(233, 213, 255, 0.3); }

    /* 2. Body Card & Route */
    .offer-body-card {
      background: #F8FAFC;
      border: 1px solid #E2E8F0;
      border-radius: 16px;
      padding: 10px 12px;
      display: flex;
      flex-direction: column;
      gap: 8px;
      flex: 1 1 auto;
      min-height: 0;
      max-height: 35vh;
      overflow-y: auto;
      -webkit-overflow-scrolling: touch;
    }

    .notes-banner {
      background: #FFFBEB;
      border: 1px solid #FDE68A;
      border-radius: 10px;
      padding: 6px 10px;
      display: flex;
      align-items: flex-start;
      gap: 8px;
      flex-shrink: 0;
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
      font-size: 11.5px;
      font-weight: 600;
      color: #92400E;
      line-height: 1.35;
    }

    .route-stepper {
      display: flex;
      flex-direction: column;
      gap: 6px;
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
      width: 24px;
      flex-shrink: 0;
    }
    .node-circle {
      width: 24px;
      height: 24px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .node-circle .material-symbols-outlined { font-size: 13px; }
    .node-circle.pickup { background: #DCFCE7; color: #16A34A; }
    .node-circle.via { background: #FEF3C7; color: #D97706; }
    .node-circle.dropoff { background: #FEE2E2; color: #DC2626; }
    .node-connector {
      width: 2px;
      height: 14px;
      background: #CBD5E1;
      margin: 2px 0;
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
      font-size: 12.5px;
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

    .clickable-step {
      cursor: pointer;
      border-radius: 10px;
      padding: 4px 6px;
      margin: -4px -6px;
      transition: background-color 0.15s ease;
    }
    .clickable-step:hover {
      background-color: rgba(2, 132, 199, 0.08);
    }
    .clickable-step:active {
      background-color: rgba(2, 132, 199, 0.16);
      transform: scale(0.99);
    }

    .map-tag {
      margin-left: auto;
      display: inline-flex;
      align-items: center;
      gap: 2px;
      font-size: 9px;
      font-weight: 800;
      color: #0284C7;
      background: rgba(2, 132, 199, 0.1);
      padding: 1px 5px;
      border-radius: 4px;
    }
    .map-tag .material-symbols-outlined {
      font-size: 11px;
    }

    /* 3. Smooth Slider Footer (Light Track Theme & Guaranteed Visible Action) */
    .offer-footer {
      display: flex;
      flex-direction: column;
      gap: 8px;
      margin-top: auto;
      flex-shrink: 0;
      padding-top: 2px;
      padding-bottom: max(18px, env(safe-area-inset-bottom, 18px));
    }

    .smooth-slider-container {
      position: relative;
      height: 50px;
      background: #F1F5F9;
      border: 1.5px solid #CBD5E1;
      border-radius: 25px;
      overflow: hidden;
      display: flex;
      align-items: center;
      justify-content: center;
      user-select: none;
      box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.04), 0 2px 6px rgba(0, 0, 0, 0.04);
    }
    .slider-fill-track {
      position: absolute;
      left: 0;
      top: 0;
      bottom: 0;
      background: linear-gradient(90deg, #10B981, #059669);
      border-radius: 25px;
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
      color: #1E293B;
      letter-spacing: 0.5px;
      pointer-events: none;
      text-transform: uppercase;
    }
    .smooth-slider-container.accepted .slider-center-label {
      color: #FFFFFF;
    }
    .smooth-slider-thumb {
      position: absolute;
      left: 3px;
      width: 42px;
      height: 42px;
      border-radius: 50%;
      background: #FFFFFF;
      color: #059669;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: grab;
      z-index: 3;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.18), 0 0 0 1px rgba(0, 0, 0, 0.06);
      touch-action: none;
      will-change: transform;
      transition: transform 0.25s cubic-bezier(0.2, 0.9, 0.3, 1);
    }
    .smooth-slider-container.dragging .smooth-slider-thumb {
      cursor: grabbing;
      transition: none;
      box-shadow: 0 4px 12px rgba(16, 185, 129, 0.35);
    }
    .thumb-icon { font-size: 22px; color: #059669; font-weight: bold; }
    .check-icon { font-size: 22px; color: #10B981; font-weight: bold; }
    .spinning-icon { font-size: 22px; color: #059669; animation: spin 0.8s linear infinite; }

    .btn-decline-offer {
      background: #FEF2F2;
      border: 1.5px solid #FECACA;
      padding: 8px 14px;
      min-height: 38px;
      border-radius: 19px;
      font-size: 12.5px;
      font-weight: 800;
      color: #DC2626;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 5px;
      cursor: pointer;
      transition: all 0.15s ease;
      box-sizing: border-box;
    }
    .btn-decline-offer:active {
      background: #FEE2E2;
      transform: scale(0.98);
    }
    .btn-decline-offer .material-symbols-outlined { font-size: 16px; color: #DC2626; }

    /* Status Overlay & Professional Notification Sheets */
    .status-overlay-card {
      position: relative;
      z-index: 10;
      background: #FFFFFF;
      border-radius: 24px;
      padding: 0;
      max-width: 480px;
      width: 94%;
      margin: auto;
      box-shadow: 0 20px 48px rgba(0, 0, 0, 0.35);
      display: flex;
      flex-direction: column;
      overflow: hidden;
      max-height: 90vh;
    }

    .status-banner {
      padding: 16px 18px;
      color: #FFFFFF;
      display: flex;
      align-items: flex-start;
      gap: 12px;
      position: relative;
    }
    .status-banner.amended {
      background: linear-gradient(135deg, #1D4ED8 0%, #0F172A 100%);
    }
    .status-banner.cancelled {
      background: linear-gradient(135deg, #B91C1C 0%, #0F172A 100%);
    }
    .status-banner.unallocated {
      background: linear-gradient(135deg, #B45309 0%, #0F172A 100%);
    }

    .status-icon-circle {
      width: 44px;
      height: 44px;
      border-radius: 12px;
      background: rgba(255, 255, 255, 0.15);
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
      box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.2);
    }
    .status-icon-circle .status-icon {
      font-size: 26px;
      color: #FFFFFF;
    }

    .status-banner-text {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .status-badge-row {
      display: flex;
      align-items: center;
      gap: 6px;
      margin-bottom: 2px;
    }
    .status-type-pill {
      font-size: 9.5px;
      font-weight: 900;
      letter-spacing: 0.5px;
      padding: 2px 6px;
      border-radius: 4px;
      background: rgba(255, 255, 255, 0.2);
      color: #FFFFFF;
      text-transform: uppercase;
    }
    .status-ref-tag {
      font-size: 11px;
      font-weight: 700;
      color: rgba(255, 255, 255, 0.85);
    }
    .status-title {
      margin: 0;
      font-size: 16px;
      font-weight: 800;
      color: #FFFFFF;
      letter-spacing: -0.2px;
    }
    .status-body {
      margin: 0;
      font-size: 11.5px;
      color: rgba(255, 255, 255, 0.8);
      line-height: 1.35;
    }

    .status-details-card {
      padding: 14px 18px;
      display: flex;
      flex-direction: column;
      gap: 12px;
      overflow-y: auto;
      max-height: 52vh;
      background: #FFFFFF;
    }

    .status-meta-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      background: #F8FAFC;
      border: 1px solid #E2E8F0;
      border-radius: 12px;
      padding: 8px 12px;
      gap: 8px;
    }
    .status-meta-item {
      display: flex;
      flex-direction: column;
      gap: 1px;
    }
    .status-meta-item .meta-label {
      font-size: 9px;
      font-weight: 700;
      color: #64748B;
      letter-spacing: 0.3px;
    }
    .status-meta-item .meta-val {
      font-size: 12.5px;
      color: #0F172A;
    }
    .status-meta-item .fare-green {
      font-weight: 900;
      color: #15803D;
      font-size: 14px;
    }
    .status-meta-item .payment-tag {
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      color: #475569;
    }

    .status-route-stepper {
      display: flex;
      flex-direction: column;
      gap: 8px;
      background: #F8FAFC;
      border: 1px solid #E2E8F0;
      border-radius: 14px;
      padding: 12px 14px;
    }
    .status-route-row {
      display: flex;
      align-items: flex-start;
      gap: 10px;
    }
    .status-node-col {
      display: flex;
      flex-direction: column;
      align-items: center;
      width: 14px;
      flex-shrink: 0;
      padding-top: 3px;
    }
    .status-node-dot {
      width: 10px;
      height: 10px;
      border-radius: 50%;
    }
    .status-node-dot.pickup { background: #10B981; }
    .status-node-dot.via { background: #F59E0B; }
    .status-node-dot.dropoff { background: #EF4444; }
    .status-node-line {
      width: 2px;
      height: 18px;
      background: #CBD5E1;
      margin: 2px 0;
    }

    .status-node-info {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 1px;
    }
    .status-node-header {
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .status-node-tag {
      font-size: 9px;
      font-weight: 800;
      letter-spacing: 0.3px;
    }
    .status-node-tag.pickup { color: #15803D; }
    .status-node-tag.via { color: #B45309; }
    .status-node-tag.dropoff { color: #B91C1C; }
    .status-node-addr {
      font-size: 12.5px;
      font-weight: 700;
      color: #0F172A;
      line-height: 1.35;
    }

    .status-notes-box {
      background: #FFFBEB;
      border: 1px solid #FDE68A;
      border-radius: 10px;
      padding: 8px 10px;
      display: flex;
      align-items: flex-start;
      gap: 8px;
    }
    .status-notes-box .notes-icon {
      font-size: 18px;
      color: #D97706;
      flex-shrink: 0;
    }
    .status-notes-box .notes-content {
      display: flex;
      flex-direction: column;
      gap: 1px;
    }
    .status-notes-box .notes-title {
      font-size: 10px;
      font-weight: 700;
      color: #B45309;
      text-transform: uppercase;
    }
    .status-notes-box .notes-text {
      margin: 0;
      font-size: 11.5px;
      font-weight: 600;
      color: #92400E;
    }

    .status-ok-btn {
      width: calc(100% - 36px);
      margin: 0 18px 18px 18px;
      color: #FFFFFF;
      border: none;
      padding: 12px;
      border-radius: 14px;
      font-size: 13px;
      font-weight: 800;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
      transition: opacity 0.15s ease, transform 0.1s ease;
    }
    .status-ok-btn:active {
      transform: scale(0.98);
    }
    .status-ok-btn.amended { background: #2563EB; }
    .status-ok-btn.cancelled { background: #DC2626; }
    .status-ok-btn.unallocated { background: #D97706; }

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
    :host-context(.dark-theme) .smooth-slider-container {
      background: #272730;
      border-color: #3E3E48;
    }
    :host-context(.dark-theme) .slider-center-label {
      color: #F1F5F9;
    }
    :host-context(.dark-theme) .btn-decline-offer {
      background: rgba(239, 68, 68, 0.12);
      border-color: rgba(239, 68, 68, 0.35);
      color: #FCA5A5;
    }
    :host-context(.dark-theme) .status-overlay-card {
      background: #1E1E24;
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .status-details-card {
      background: #1E1E24;
    }
    :host-context(.dark-theme) .status-meta-row,
    :host-context(.dark-theme) .status-route-stepper {
      background: #16161A;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .status-meta-item .meta-val,
    :host-context(.dark-theme) .status-node-addr {
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .status-notes-box {
      background: #241A08;
      border-color: #452D08;
    }
    :host-context(.dark-theme) .map-tag {
      background: rgba(56, 189, 248, 0.15);
      color: #38BDF8;
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

      const pickupParam = params['pickup'];
      const dropoffParam = params['dropoff'];
      const isPlaceholder = !pickupParam || pickupParam === 'Pickup Location' || !dropoffParam || dropoffParam === 'Destination';

      this.job = {
        id: this.jobIdFromUrl || '84920',
        fare: isNaN(fareVal) ? 0.00 : fareVal,
        pickup: pickupParam || 'Pickup Location',
        pickupPostCode: params['pickupPostCode'] || params['pickupPostcode'] || '',
        dropoff: dropoffParam || 'Destination',
        destinationPostCode: params['destinationPostCode'] || params['destinationPostcode'] || '',
        vias: vias.length > 0 ? vias : undefined,
        paymentType: params['paymentType'] || 'Cash',
        vehicleType: params['vehicleType'] || 'Standard Saloon',
        passenger: params['passenger'] || 'Passenger',
        notes: params['notes'] || ''
      };

      // Fetch live full booking data when a booking ID or GUID is present, or if values are placeholders/status alerts
      if (this.jobIdFromUrl || this.guid || isPlaceholder || this.jobStatus !== 'active') {
        this.fetchFullBookingDetails();
      }

      this.startTimer();
      this.cdr.detectChanges();
    });
  }

  fetchFullBookingDetails(): void {
    const bookingId = this.jobIdFromUrl || this.job?.id;
    if (bookingId && !bookingId.startsWith('sim-')) {
      this.driverService.getJobById(bookingId).subscribe({
        next: (res: any) => {
          const data = res?.value || res?.data || res;
          if (data && (data.pickupAddress || data.pickup || data.bookingId)) {
            this.applyFetchedBooking(data);
          } else {
            this.fetchFromGeneralJobs(bookingId);
          }
        },
        error: () => {
          this.fetchFromGeneralJobs(bookingId);
        }
      });
    } else if (this.guid) {
      this.driverService.retrieveJobOffer(this.guid).subscribe({
        next: (res: any) => {
          const data = res?.value || res?.data || res;
          if (data) {
            this.applyFetchedBooking(data);
          }
        },
        error: () => {}
      });
    }
  }

  private fetchFromGeneralJobs(bookingId: string): void {
    this.driverService.getTodaysJobs().subscribe({
      next: (res: any) => {
        const list = Array.isArray(res) ? res : (res?.value || res?.bookings || res?.data || []);
        const match = list.find((j: any) => (j.bookingId || j.id || j.bookingNo || '').toString() === bookingId.toString());
        if (match) {
          this.applyFetchedBooking(match);
        } else {
          this.driverService.getFutureJobs().subscribe({
            next: (fRes: any) => {
              const fList = Array.isArray(fRes) ? fRes : (fRes?.value || fRes?.bookings || fRes?.data || []);
              const fMatch = fList.find((j: any) => (j.bookingId || j.id || j.bookingNo || '').toString() === bookingId.toString());
              if (fMatch) {
                this.applyFetchedBooking(fMatch);
              }
            }
          });
        }
      }
    });
  }

  private applyFetchedBooking(b: any): void {
    const fareVal = parseFloat((b.price || b.fare || b.amount || b.driverPrice || this.job?.fare || 0).toString());
    const vias: ViaStop[] = [];
    if (Array.isArray(b.vias) && b.vias.length > 0) {
      for (const v of b.vias) {
        if (typeof v === 'string') {
          vias.push({ address: v });
        } else if (v && typeof v === 'object') {
          vias.push({
            address: v.address || v.stopAddress || 'Via Stop',
            postCode: v.postCode || v.postcode || ''
          });
        }
      }
    }

    let paymentType = b.paymentType || b.paymentMethod || this.job?.paymentType || 'Cash';
    if (b.scope !== undefined && b.scope !== null) {
      const scope = parseInt(b.scope.toString()) || 0;
      switch (scope) {
        case 0: paymentType = 'Cash'; break;
        case 1: paymentType = 'Account'; break;
        case 2: paymentType = 'Rank'; break;
        case 4: paymentType = 'Card'; break;
      }
    }

    this.job = {
      id: (b.bookingId || b.id || b.bookingNo || this.job?.id || '').toString(),
      fare: isNaN(fareVal) ? (this.job?.fare || 0) : fareVal,
      pickup: b.pickupAddress || b.pickup || b.from || this.job?.pickup || 'Pickup Location',
      pickupPostCode: b.pickupPostCode || b.pickupPostcode || b.postcode || this.job?.pickupPostCode || '',
      dropoff: b.destinationAddress || b.dropoffAddress || b.dropoff || b.to || this.job?.dropoff || 'Destination',
      destinationPostCode: b.destinationPostCode || b.destinationPostcode || this.job?.destinationPostCode || '',
      vias: vias.length > 0 ? vias : this.job?.vias,
      paymentType,
      vehicleType: b.vehicleType || b.vehicle || this.job?.vehicleType || 'Standard Saloon',
      passenger: b.passengerName || b.cellText || b.passenger || b.customerName || this.job?.passenger || 'Passenger',
      notes: b.details || b.notes || b.comment || this.job?.notes || ''
    };

    this.cdr.detectChanges();
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
        error: (err: any) => {
          console.warn('Initial JobOfferReply expired/invalid. Running fresh GUID lookup & SetActiveJob fallback...', err);
          this.driverService.getJobOffers().pipe(catchError(() => of([]))).subscribe((offersRes: any) => {
            const list = Array.isArray(offersRes) ? offersRes : (offersRes?.value || offersRes?.data || offersRes?.jobs || []);
            const matching = list.find((item: any) => {
              const bId = (item.bookingId || item.bookingNo || item.id || item.data?.bookingId || '').toString();
              return bId === jobId;
            });
            const freshGuid = (matching?.guid || matching?.Guid || matching?.notificationId || matching?.data?.guid || '').toString();

            if (freshGuid && freshGuid !== effectiveGuid) {
              this.driverService.replyJobOffer(numericJobId, 2000, freshGuid).subscribe({
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

  getStatusBadgeText(): string {
    switch (this.jobStatus) {
      case 'amended': return 'AMENDED DETAILS';
      case 'cancelled': return 'DISPATCH CANCELLED';
      case 'unallocated': return 'TRIP RECALLED';
      default: return 'DISPATCH UPDATE';
    }
  }

  getStatusIconName(): string {
    switch (this.jobStatus) {
      case 'cancelled': return 'cancel';
      case 'unallocated': return 'history_toggle_off';
      case 'amended': return 'edit_document';
      default: return 'notifications_active';
    }
  }

  getStatusTitleText(): string {
    switch (this.jobStatus) {
      case 'cancelled': return 'Booking Cancelled by Dispatch';
      case 'unallocated': return 'Booking Unallocated';
      case 'amended': return 'Booking Details Amended';
      default: return 'Booking Status Updated';
    }
  }

  getStatusBodyText(): string {
    switch (this.jobStatus) {
      case 'cancelled': return 'This trip has been cancelled by the operator. Please do not proceed to pickup.';
      case 'unallocated': return 'This booking has been recalled or reassigned from your dispatch queue.';
      case 'amended': return 'The operator has amended the route, schedule, or passenger instructions for this trip. Please review below.';
      default: return 'The details for this dispatch booking have been updated.';
    }
  }

  openGoogleMap(addressOrPostcode: string, event?: MouseEvent): void {
    if (event) {
      event.stopPropagation();
      event.preventDefault();
    }
    if (!addressOrPostcode || !addressOrPostcode.trim()) return;
    const cleanAddr = addressOrPostcode.trim();
    const channel = (window as any).FlutterChannel;
    if (channel) {
      channel.postMessage(`open_map:${cleanAddr}`);
    } else {
      const url = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(cleanAddr)}`;
      window.open(url, '_blank');
    }
  }

  getMapUrl(addressOrPostcode: string): string {
    return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(addressOrPostcode || '')}`;
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
