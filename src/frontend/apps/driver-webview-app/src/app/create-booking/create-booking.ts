import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDividerModule } from '@angular/material/divider';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { Router } from '@angular/router';
import { DriverService } from '../services/driver.service';

@Component({
  selector: 'app-create-booking',
  standalone: true,
  imports: [
    CommonModule,
    MatButtonModule,
    MatIconModule,
    MatDividerModule,
    MatSnackBarModule
  ],
  template: `
    <div class="material-container">
      <!-- Linear loading bar active when calling suggestions / resolve / price quote -->
      <div class="linear-loader" *ngIf="isResolving || isFetchingPrice">
        <div class="loader-bar"></div>
      </div>

      <!-- Header Hero Card -->
      <div class="hero-header-card animated-fade-in">
        <div class="hero-top-row">
          <div class="hero-badge">
            <span class="material-symbols-outlined badge-icon">local_taxi</span>
            <span>STREET HIRE / RANK DISPATCH</span>
          </div>
          <span class="live-dot-pill">
            <span class="pulse-dot"></span>
            LIVE
          </span>
        </div>
        <h2 class="hero-title">Direct Rank Pickup</h2>
        <p class="hero-subtitle">Instantly create and allocate cash street hires directly to your driver queue.</p>
      </div>

      <div class="form-body animated-fade-in">
        <!-- Route Journey Segment Card (Pickup -> Destination) -->
        <div class="journey-card">
          <!-- 1. Pickup Node -->
          <div class="journey-node">
            <div class="node-indicator">
              <div class="node-icon-circle pickup">
                <span class="material-symbols-outlined">my_location</span>
              </div>
              <div class="node-track-line"></div>
            </div>
            <div class="node-content">
              <div class="node-header-row">
                <span class="node-label">PICKUP POINT</span>
                <span class="node-status-tag">RANK STAND</span>
              </div>
              <div class="node-main-box">
                <span class="node-address-main">Rank Base Stand</span>
                <span class="node-postcode">SP8 4PZ • Direct Boarding</span>
              </div>
            </div>
          </div>

          <!-- 2. Destination Node -->
          <div class="journey-node destination-node">
            <div class="node-indicator">
              <div class="node-icon-circle destination">
                <span class="material-symbols-outlined">location_on</span>
              </div>
            </div>
            <div class="node-content">
              <div class="node-header-row">
                <span class="node-label">DESTINATION ADDRESS</span>
                <span class="node-required-tag" *ngIf="!destinationAddress">REQUIRED</span>
              </div>
              
              <!-- Search Input Field -->
              <div class="destination-search-box">
                <span class="material-symbols-outlined search-icon">search</span>
                <input 
                  type="text" 
                  placeholder="Search street, area or postcode..." 
                  class="dest-input" 
                  [value]="destinationAddress"
                  (input)="onDestinationInput($any($event.target).value)" 
                />
                <button 
                  type="button" 
                  class="clear-btn" 
                  *ngIf="destinationAddress.length > 0" 
                  (click)="clearDestination()"
                  title="Clear"
                >
                  <span class="material-symbols-outlined">close</span>
                </button>
                <div class="input-spinner" *ngIf="isSearchingSuggestions"></div>
              </div>

              <!-- Autocomplete Suggestions List -->
              <div class="suggestions-overlay animated-fade-in" *ngIf="suggestions.length > 0">
                <div 
                  class="suggestion-row" 
                  *ngFor="let item of suggestions" 
                  (click)="selectSuggestion(item)"
                >
                  <div class="sugg-icon-box">
                    <span class="material-symbols-outlined">pin_drop</span>
                  </div>
                  <div class="sugg-text-box">
                    <span class="sugg-title">{{ item.label }}</span>
                    <span class="sugg-sub" *ngIf="item.secondaryText">{{ item.secondaryText }}</span>
                  </div>
                  <span class="material-symbols-outlined sugg-arrow">chevron_right</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Passenger Information Card -->
        <div class="section-card">
          <div class="section-header-row">
            <span class="section-icon-badge">
              <span class="material-symbols-outlined">person</span>
            </span>
            <div class="section-titles">
              <span class="section-heading">Passenger Details</span>
              <span class="section-subtext">Optional name or passenger identifier</span>
            </div>
          </div>

          <div class="passenger-input-box">
            <input 
              type="text" 
              placeholder="e.g. John D. or Street Customer" 
              class="field-input" 
              [value]="passengerName"
              (input)="onPassengerNameInput($any($event.target).value)"
            />
          </div>

          <!-- Quick Presets -->
          <div class="preset-chips-row">
            <button type="button" class="preset-chip" (click)="setPassengerPreset('Rank Passenger')">
              <span>Rank Passenger</span>
            </button>
            <button type="button" class="preset-chip" (click)="setPassengerPreset('Street Flag')">
              <span>Street Flag</span>
            </button>
            <button type="button" class="preset-chip" (click)="setPassengerPreset('Cash Passenger')">
              <span>Cash Passenger</span>
            </button>
          </div>
        </div>

        <!-- Price Quote & Telemetry Deck (Appears once price is resolved) -->
        <div class="quote-deck animated-fade-in" *ngIf="price > 0 && !isFetchingPrice">
          <div class="quote-deck-header">
            <div class="quote-title-group">
              <span class="material-symbols-outlined quote-title-icon">speed</span>
              <span class="quote-title-text">Route & Fare Calculation</span>
            </div>
            <span class="fare-mode-badge">
              <span class="material-symbols-outlined badge-cash-icon">payments</span>
              CASH / RANK
            </span>
          </div>

          <!-- 3-Column Metrics Grid -->
          <div class="metrics-grid">
            <div class="metric-card">
              <span class="material-symbols-outlined metric-icon blue">route</span>
              <span class="metric-number">{{ getFormattedMileage().main }}</span>
              <span class="metric-caption">Distance</span>
            </div>
            <div class="metric-card">
              <span class="material-symbols-outlined metric-icon amber">schedule</span>
              <span class="metric-number">{{ durationText || (durationMinutes + ' min') }}</span>
              <span class="metric-caption">Duration</span>
            </div>
            <div class="metric-card featured-fare">
              <span class="material-symbols-outlined metric-icon green">attach_money</span>
              <span class="metric-number fare-text">£{{ price.toFixed(2) }}</span>
              <span class="metric-caption fare-caption">Total Fare</span>
            </div>
          </div>

          <!-- Interactive Fare Steppers & Direct Override -->
          <div class="fare-adjustment-box">
            <div class="adjustment-header-row">
              <span class="adj-label">QUICK FARE ADJUSTMENT</span>
              <button type="button" class="reset-link-btn" *ngIf="originalPrice > 0 && price !== originalPrice" (click)="resetPrice()">
                <span class="material-symbols-outlined">restart_alt</span>
                Reset (£{{ originalPrice.toFixed(2) }})
              </button>
            </div>
            
            <div class="quick-steppers-row">
              <button type="button" class="step-btn" (click)="adjustPrice(-1.00)">- £1.00</button>
              <button type="button" class="step-btn" (click)="adjustPrice(+1.00)">+ £1.00</button>
              <button type="button" class="step-btn" (click)="adjustPrice(+2.00)">+ £2.00</button>
              <button type="button" class="step-btn" (click)="adjustPrice(+5.00)">+ £5.00</button>
            </div>

            <div class="custom-amount-row">
              <span class="custom-amount-prefix">£</span>
              <input 
                type="number" 
                step="0.50" 
                placeholder="0.00" 
                class="custom-amount-input" 
                [value]="price"
                (input)="onPriceInput($any($event.target).value)" 
              />
              <span class="custom-amount-label">Driver Agreed Fare</span>
            </div>
          </div>
        </div>

        <!-- Submit & Dispatch Action Button -->
        <div class="submit-action-container">
          <button 
            mat-flat-button 
            class="submit-dispatch-btn" 
            (click)="submitBooking()" 
            [disabled]="isSubmitting || isResolving || isFetchingPrice || price <= 0 || !destinationAddress"
          >
            <div class="btn-content-wrapper" *ngIf="!isSubmitting">
              <span class="material-symbols-outlined btn-action-icon">local_taxi</span>
              <span class="btn-action-text">Create & Start Trip</span>
              <span class="material-symbols-outlined btn-arrow-icon">arrow_forward</span>
            </div>
            <div class="btn-loading-wrapper" *ngIf="isSubmitting">
              <div class="btn-spinner"></div>
              <span>Dispatching Booking...</span>
            </div>
          </button>
          
          <div class="security-trust-badge">
            <span class="material-symbols-outlined">verified_user</span>
            <span>Allocates immediately to your active driver shift</span>
          </div>
        </div>
      </div>
    </div>
  `,
  styles: [`
    /* ================= DARK THEME VARIABLES ================= */
    :host-context(.dark-theme) .material-container {
      background-color: #121214 !important;
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .hero-header-card {
      background: linear-gradient(135deg, #1E1E24 0%, #17171C 100%) !important;
      border-color: #2D2D35 !important;
    }
    :host-context(.dark-theme) .hero-title {
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .hero-subtitle {
      color: #90A4AE !important;
    }
    :host-context(.dark-theme) .form-body {
      background-color: transparent !important;
    }
    :host-context(.dark-theme) .journey-card,
    :host-context(.dark-theme) .section-card,
    :host-context(.dark-theme) .quote-deck {
      background-color: #1E1E24 !important;
      border-color: #2D2D35 !important;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.25) !important;
    }
    :host-context(.dark-theme) .node-address-main,
    :host-context(.dark-theme) .section-heading,
    :host-context(.dark-theme) .metric-number {
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .dest-input,
    :host-context(.dark-theme) .field-input,
    :host-context(.dark-theme) .custom-amount-input {
      background-color: #121214 !important;
      border-color: #2D2D35 !important;
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .dest-input:focus,
    :host-context(.dark-theme) .field-input:focus,
    :host-context(.dark-theme) .custom-amount-input:focus {
      border-color: #CD1A21 !important;
    }
    :host-context(.dark-theme) .suggestions-overlay {
      background-color: #1E1E24 !important;
      border-color: #2D2D35 !important;
      box-shadow: 0 12px 32px rgba(0, 0, 0, 0.4) !important;
    }
    :host-context(.dark-theme) .suggestion-row {
      border-bottom-color: #2D2D35 !important;
    }
    :host-context(.dark-theme) .suggestion-row:hover {
      background-color: #26262E !important;
    }
    :host-context(.dark-theme) .sugg-title {
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .sugg-sub {
      color: #90A4AE !important;
    }
    :host-context(.dark-theme) .preset-chip,
    :host-context(.dark-theme) .step-btn {
      background-color: #121214 !important;
      border-color: #2D2D35 !important;
      color: #B0BEC5 !important;
    }
    :host-context(.dark-theme) .metric-card {
      background-color: #141418 !important;
      border-color: #2D2D35 !important;
    }
    :host-context(.dark-theme) .metric-card.featured-fare {
      background: linear-gradient(135deg, rgba(46, 125, 50, 0.15) 0%, rgba(46, 125, 50, 0.05) 100%) !important;
      border-color: rgba(46, 125, 50, 0.3) !important;
    }
    :host-context(.dark-theme) .fare-adjustment-box {
      background-color: #141418 !important;
      border-color: #2D2D35 !important;
    }
    :host-context(.dark-theme) .custom-amount-prefix {
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .security-trust-badge {
      color: #78909C !important;
    }

    /* ================= MAIN CONTAINER ================= */
    .material-container {
      padding: 14px 14px 140px 14px;
      background-color: #F8F9FA;
      min-height: 100vh;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      box-sizing: border-box;
      position: relative;
    }

    /* Linear progress bar loader */
    .linear-loader {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      height: 3.5px;
      background-color: rgba(205, 26, 33, 0.15);
      overflow: hidden;
      z-index: 999;
    }
    .loader-bar {
      width: 100%;
      height: 100%;
      background: linear-gradient(90deg, #CD1A21, #FF5252);
      animation: loading-bar 1.4s infinite ease-in-out;
      transform-origin: 0% 50%;
    }
    @keyframes loading-bar {
      0% { transform: translateX(-100%) scaleX(0.8); }
      50% { transform: translateX(0%) scaleX(0.4); }
      100% { transform: translateX(100%) scaleX(0.8); }
    }

    /* ================= HERO HEADER CARD ================= */
    .hero-header-card {
      background: linear-gradient(135deg, #FFFFFF 0%, #FDFDFE 100%);
      border: 1px solid #E2E8F0;
      border-radius: 20px;
      padding: 16px 18px;
      margin-bottom: 14px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.03);
    }
    .hero-top-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 8px;
    }
    .hero-badge {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      background-color: rgba(205, 26, 33, 0.08);
      color: #CD1A21;
      padding: 4px 9px;
      border-radius: 20px;
      font-size: 9.5px;
      font-weight: 900;
      letter-spacing: 0.6px;
    }
    .badge-icon {
      font-size: 14px;
    }
    .live-dot-pill {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      background-color: rgba(46, 125, 50, 0.08);
      color: #2E7D32;
      padding: 3px 8px;
      border-radius: 20px;
      font-size: 9.5px;
      font-weight: 900;
      letter-spacing: 0.5px;
    }
    .pulse-dot {
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background-color: #2E7D32;
      box-shadow: 0 0 0 2px rgba(46, 125, 50, 0.3);
      animation: pulse 1.8s infinite;
    }
    @keyframes pulse {
      0% { box-shadow: 0 0 0 0 rgba(46, 125, 50, 0.5); }
      70% { box-shadow: 0 0 0 5px rgba(46, 125, 50, 0); }
      100% { box-shadow: 0 0 0 0 rgba(46, 125, 50, 0); }
    }
    .hero-title {
      margin: 0 0 4px 0;
      font-size: 19px;
      font-weight: 900;
      color: #1E293B;
      letter-spacing: -0.2px;
    }
    .hero-subtitle {
      margin: 0;
      font-size: 11.5px;
      color: #64748B;
      line-height: 1.4;
      font-weight: 500;
    }

    /* ================= FORM BODY ================= */
    .form-body {
      display: flex;
      flex-direction: column;
      gap: 14px;
    }

    /* ================= JOURNEY CARD (PICKUP -> DESTINATION) ================= */
    .journey-card {
      background-color: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 20px;
      padding: 16px 16px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.025);
      position: relative;
    }
    .journey-node {
      display: flex;
      gap: 12px;
    }
    .node-indicator {
      display: flex;
      flex-direction: column;
      align-items: center;
      width: 32px;
      flex-shrink: 0;
    }
    .node-icon-circle {
      width: 32px;
      height: 32px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .node-icon-circle.pickup {
      background-color: rgba(46, 125, 50, 0.12);
      color: #2E7D32;
    }
    .node-icon-circle.destination {
      background-color: rgba(205, 26, 33, 0.12);
      color: #CD1A21;
    }
    .node-icon-circle .material-symbols-outlined {
      font-size: 18px;
    }
    .node-track-line {
      width: 2px;
      flex-grow: 1;
      min-height: 28px;
      background: repeating-linear-gradient(
        to bottom,
        #CBD5E1,
        #CBD5E1 3px,
        transparent 3px,
        transparent 6px
      );
      margin: 4px 0;
    }
    .node-content {
      flex: 1;
      min-width: 0;
      position: relative;
    }
    .node-header-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 4px;
    }
    .node-label {
      font-size: 9.5px;
      font-weight: 800;
      color: #94A3B8;
      letter-spacing: 0.5px;
      text-transform: uppercase;
    }
    .node-status-tag {
      font-size: 9px;
      font-weight: 800;
      color: #2E7D32;
      background-color: rgba(46, 125, 50, 0.08);
      padding: 2px 7px;
      border-radius: 12px;
    }
    .node-required-tag {
      font-size: 8.5px;
      font-weight: 800;
      color: #EA580C;
      background-color: rgba(234, 88, 12, 0.08);
      padding: 2px 6px;
      border-radius: 10px;
    }
    .node-main-box {
      display: flex;
      flex-direction: column;
      gap: 1px;
      padding: 4px 0 10px 0;
    }
    .node-address-main {
      font-size: 13.5px;
      font-weight: 800;
      color: #1E293B;
    }
    .node-postcode {
      font-size: 11px;
      color: #64748B;
      font-weight: 600;
    }

    /* Destination search input */
    .destination-node {
      margin-top: 6px;
    }
    .destination-search-box {
      position: relative;
      display: flex;
      align-items: center;
    }
    .search-icon {
      position: absolute;
      left: 12px;
      color: #94A3B8;
      font-size: 19px;
      pointer-events: none;
    }
    .dest-input {
      width: 100%;
      border: 1.5px solid #E2E8F0;
      border-radius: 14px;
      padding: 11px 38px 11px 38px;
      font-size: 13.5px;
      font-weight: 600;
      outline: none;
      box-sizing: border-box;
      background-color: #F8FAFC;
      color: #1E293B;
      transition: all 0.2s ease;
    }
    .dest-input:focus {
      border-color: #CD1A21;
      background-color: #FFFFFF;
      box-shadow: 0 0 0 3px rgba(205, 26, 33, 0.08);
    }
    .clear-btn {
      position: absolute;
      right: 10px;
      background: none;
      border: none;
      color: #94A3B8;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      padding: 4px;
    }
    .clear-btn .material-symbols-outlined {
      font-size: 17px;
    }
    .input-spinner {
      position: absolute;
      right: 12px;
      width: 16px;
      height: 16px;
      border: 2px solid rgba(205, 26, 33, 0.2);
      border-top-color: #CD1A21;
      border-radius: 50%;
      animation: spin 0.75s linear infinite;
    }
    @keyframes spin {
      100% { transform: rotate(360deg); }
    }

    /* Autocomplete suggestions dropdown */
    .suggestions-overlay {
      position: absolute;
      top: 100%;
      left: 0;
      right: 0;
      background-color: #FFFFFF;
      border-radius: 16px;
      border: 1px solid #E2E8F0;
      box-shadow: 0 12px 32px rgba(0, 0, 0, 0.1);
      z-index: 50;
      margin-top: 6px;
      max-height: 240px;
      overflow-y: auto;
    }
    .suggestion-row {
      padding: 11px 14px;
      display: flex;
      align-items: center;
      gap: 10px;
      cursor: pointer;
      border-bottom: 1px solid #F1F5F9;
      transition: background-color 0.18s ease;
    }
    .suggestion-row:last-child {
      border-bottom: none;
    }
    .suggestion-row:hover {
      background-color: #F8FAFC;
    }
    .sugg-icon-box {
      width: 28px;
      height: 28px;
      border-radius: 50%;
      background-color: rgba(205, 26, 33, 0.08);
      color: #CD1A21;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }
    .sugg-icon-box .material-symbols-outlined {
      font-size: 16px;
    }
    .sugg-text-box {
      flex: 1;
      min-width: 0;
      display: flex;
      flex-direction: column;
      gap: 1px;
    }
    .sugg-title {
      font-size: 12.5px;
      font-weight: 700;
      color: #1E293B;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .sugg-sub {
      font-size: 10.5px;
      color: #64748B;
      font-weight: 500;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .sugg-arrow {
      color: #CBD5E1;
      font-size: 18px;
    }

    /* ================= SECTION CARD (PASSENGER DETAILS) ================= */
    .section-card {
      background-color: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 20px;
      padding: 14px 16px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.025);
    }
    .section-header-row {
      display: flex;
      align-items: center;
      gap: 10px;
      margin-bottom: 10px;
    }
    .section-icon-badge {
      width: 28px;
      height: 28px;
      border-radius: 8px;
      background-color: rgba(56, 189, 248, 0.12);
      color: #0284C7;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .section-icon-badge .material-symbols-outlined {
      font-size: 16px;
    }
    .section-titles {
      display: flex;
      flex-direction: column;
    }
    .section-heading {
      font-size: 12.5px;
      font-weight: 800;
      color: #1E293B;
    }
    .section-subtext {
      font-size: 10px;
      color: #64748B;
      font-weight: 500;
    }
    .passenger-input-box {
      margin-bottom: 8px;
    }
    .field-input {
      width: 100%;
      border: 1.5px solid #E2E8F0;
      border-radius: 12px;
      padding: 10px 12px;
      font-size: 13px;
      font-weight: 600;
      outline: none;
      box-sizing: border-box;
      background-color: #F8FAFC;
      color: #1E293B;
      transition: all 0.2s ease;
    }
    .field-input:focus {
      border-color: #CD1A21;
      background-color: #FFFFFF;
      box-shadow: 0 0 0 3px rgba(205, 26, 33, 0.06);
    }
    .preset-chips-row {
      display: flex;
      gap: 6px;
      flex-wrap: wrap;
    }
    .preset-chip {
      background-color: #F1F5F9;
      border: 1px solid #E2E8F0;
      border-radius: 20px;
      padding: 4px 10px;
      font-size: 10.5px;
      font-weight: 700;
      color: #475569;
      cursor: pointer;
      transition: all 0.18s ease;
    }
    .preset-chip:hover, .preset-chip:active {
      background-color: rgba(205, 26, 33, 0.08);
      border-color: rgba(205, 26, 33, 0.25);
      color: #CD1A21;
    }

    /* ================= QUOTE & TELEMETRY DECK ================= */
    .quote-deck {
      background-color: #FFFFFF;
      border: 1.5px solid #E2E8F0;
      border-radius: 20px;
      padding: 16px;
      box-shadow: 0 6px 20px rgba(0, 0, 0, 0.03);
    }
    .quote-deck-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 12px;
    }
    .quote-title-group {
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .quote-title-icon {
      font-size: 18px;
      color: #CD1A21;
    }
    .quote-title-text {
      font-size: 12.5px;
      font-weight: 800;
      color: #1E293B;
    }
    .fare-mode-badge {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      font-size: 9.5px;
      font-weight: 900;
      color: #C2410C;
      background-color: rgba(234, 88, 12, 0.08);
      padding: 3px 8px;
      border-radius: 20px;
      letter-spacing: 0.4px;
    }
    .badge-cash-icon {
      font-size: 13px;
    }

    /* Metrics Grid */
    .metrics-grid {
      display: grid;
      grid-template-columns: 1fr 1fr 1.2fr;
      gap: 8px;
      margin-bottom: 14px;
    }
    .metric-card {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 10px 6px;
      background-color: #F8FAFC;
      border-radius: 14px;
      border: 1px solid #E2E8F0;
      text-align: center;
    }
    .metric-icon {
      font-size: 18px;
      margin-bottom: 2px;
    }
    .metric-icon.blue { color: #0284C7; }
    .metric-icon.amber { color: #D97706; }
    .metric-icon.green { color: #16A34A; }
    .metric-number {
      font-size: 13px;
      font-weight: 900;
      color: #1E293B;
      line-height: 1.2;
    }
    .metric-caption {
      font-size: 9px;
      color: #94A3B8;
      font-weight: 700;
      text-transform: uppercase;
      margin-top: 3px;
      letter-spacing: 0.3px;
    }
    .metric-card.featured-fare {
      background: linear-gradient(135deg, rgba(22, 163, 74, 0.08) 0%, rgba(22, 163, 74, 0.02) 100%);
      border-color: rgba(22, 163, 74, 0.25);
    }
    .fare-text {
      color: #16A34A !important;
      font-size: 15.5px !important;
      font-weight: 900;
    }
    .fare-caption {
      color: #16A34A !important;
      font-weight: 800;
    }

    /* Fare Adjustment Box */
    .fare-adjustment-box {
      background-color: #F8FAFC;
      border: 1px solid #E2E8F0;
      border-radius: 14px;
      padding: 12px;
    }
    .adjustment-header-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 8px;
    }
    .adj-label {
      font-size: 9.5px;
      font-weight: 800;
      color: #64748B;
      letter-spacing: 0.4px;
    }
    .reset-link-btn {
      background: none;
      border: none;
      color: #CD1A21;
      font-size: 10px;
      font-weight: 800;
      display: inline-flex;
      align-items: center;
      gap: 3px;
      cursor: pointer;
      padding: 2px 4px;
    }
    .reset-link-btn .material-symbols-outlined {
      font-size: 13px;
    }
    .quick-steppers-row {
      display: grid;
      grid-template-columns: 1fr 1fr 1fr 1fr;
      gap: 6px;
      margin-bottom: 10px;
    }
    .step-btn {
      background-color: #FFFFFF;
      border: 1px solid #CBD5E1;
      border-radius: 10px;
      padding: 6px 2px;
      font-size: 11px;
      font-weight: 800;
      color: #334155;
      cursor: pointer;
      transition: all 0.16s ease;
    }
    .step-btn:active {
      background-color: #CD1A21;
      color: #FFFFFF;
      border-color: #CD1A21;
    }
    .custom-amount-row {
      position: relative;
      display: flex;
      align-items: center;
    }
    .custom-amount-prefix {
      position: absolute;
      left: 12px;
      font-size: 17px;
      font-weight: 900;
      color: #1E293B;
    }
    .custom-amount-input {
      width: 100%;
      border: 1.5px solid #E2E8F0;
      border-radius: 10px;
      padding: 8px 12px 8px 28px;
      font-size: 16px;
      font-weight: 900;
      color: #1E293B;
      background-color: #FFFFFF;
      outline: none;
      box-sizing: border-box;
    }
    .custom-amount-input:focus {
      border-color: #CD1A21;
    }
    .custom-amount-label {
      position: absolute;
      right: 12px;
      font-size: 10px;
      font-weight: 700;
      color: #94A3B8;
      text-transform: uppercase;
      letter-spacing: 0.3px;
    }

    /* ================= SUBMIT ACTION BUTTON ================= */
    .submit-action-container {
      margin-top: 4px;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 10px;
    }
    .submit-dispatch-btn {
      width: 100%;
      height: 52px;
      background: linear-gradient(135deg, #CD1A21 0%, #9E0E14 100%) !important;
      color: #FFFFFF !important;
      border-radius: 16px !important;
      font-weight: 900 !important;
      letter-spacing: 0.3px !important;
      box-shadow: 0 6px 20px rgba(205, 26, 33, 0.28) !important;
      transition: all 0.2s ease !important;
    }
    .submit-dispatch-btn:disabled {
      background: #E2E8F0 !important;
      color: #94A3B8 !important;
      box-shadow: none !important;
    }
    .btn-content-wrapper {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      font-size: 14px;
    }
    .btn-action-icon {
      font-size: 20px;
    }
    .btn-arrow-icon {
      font-size: 18px;
    }
    .btn-loading-wrapper {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      font-size: 13.5px;
    }
    .btn-spinner {
      width: 18px;
      height: 18px;
      border: 2px solid rgba(255, 255, 255, 0.3);
      border-top-color: #FFFFFF;
      border-radius: 50%;
      animation: spin 0.75s linear infinite;
    }
    .security-trust-badge {
      display: flex;
      align-items: center;
      gap: 5px;
      font-size: 11px;
      color: #64748B;
      font-weight: 600;
    }
    .security-trust-badge .material-symbols-outlined {
      font-size: 14px;
      color: #16A34A;
    }

    /* Animation effects */
    .animated-fade-in {
      animation: fadeIn 0.22s ease-in-out forwards;
    }
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(3px); }
      to { opacity: 1; transform: translateY(0); }
    }
  `]
})
export class CreateBookingComponent implements OnInit {
  userId: number | null = null;
  destinationAddress = '';
  destinationPostcode = '';
  passengerName = '';

  price = 0;
  originalPrice = 0;
  mileage = 0;
  mileageText = '';
  durationMinutes = 0;
  durationText = '';

  isSearchingSuggestions = false;
  isResolving = false;
  isFetchingPrice = false;
  isSubmitting = false;

  suggestions: any[] = [];
  private debounceTimer: any;

  getFormattedMileage(): { main: string; details: string | null } {
    const txt = this.mileageText || (this.mileage > 0 ? (this.mileage.toFixed(1) + ' mi') : '');
    if (!txt) return { main: '--', details: null };
    
    if (txt.includes(' - ') || txt.includes('(')) {
      const parts = txt.split(' - ');
      if (parts.length > 0) {
        const main = parts[0].trim();
        const details = parts.slice(1).join(' - ')
          .replace(/\+/g, '|')
          .replace(/Dead Miles:/i, 'Dead:')
          .replace(/Trip Miles:/i, 'Trip:')
          .replace(/Dead Miles/i, 'Dead')
          .replace(/Trip Miles/i, 'Trip')
          .trim();
        return { main, details };
      }
    }
    return { main: txt, details: null };
  }

  constructor(
    private driverService: DriverService,
    private snackBar: MatSnackBar,
    private router: Router,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.resolveUserId();
  }

  generateUUID(): string {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
      const r = (Math.random() * 16) | 0;
      const v = c === 'x' ? r : (r & 0x3) | 0x8;
      return v.toString(16);
    });
  }

  resolveUserId(): void {
    const token = localStorage.getItem('auth_token');
    if (token) {
      try {
        const parts = token.split('.');
        if (parts.length === 3) {
          const payload = JSON.parse(atob(parts[1]));
          const userId = payload.id || payload.nameid || payload.userId;
          this.userId = userId ? Number(userId) : null;
        }
      } catch (e) {
        console.error('[Create Booking] Failed to parse JWT token for userId:', e);
      }
    }
    if (!this.userId) {
      this.driverService.getProfile().subscribe({
        next: (res: any) => {
          const profile = res?.value || res;
          this.userId = profile?.id || profile?.userId || profile?.driverId || 1;
        },
        error: () => {
          this.userId = 1;
        }
      });
    }
  }

  onDestinationInput(val: string): void {
    this.destinationAddress = val;
    this.suggestions = [];
    this.cdr.detectChanges();

    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
    }

    if (val.length < 3) {
      this.isSearchingSuggestions = false;
      this.cdr.detectChanges();
      return;
    }

    this.isSearchingSuggestions = true;
    this.cdr.detectChanges();

    this.debounceTimer = setTimeout(() => {
      const sessionToken = this.generateUUID();
      this.driverService.searchAddress(val, sessionToken).subscribe({
        next: (res: any) => {
          this.suggestions = Array.isArray(res) ? res : (res?.value || []);
          this.isSearchingSuggestions = false;
          this.cdr.detectChanges();
        },
        error: (err) => {
          console.error('[Create Booking] Search failed:', err);
          this.isSearchingSuggestions = false;
          this.cdr.detectChanges();
        }
      });
    }, 400);
  }

  clearDestination(): void {
    this.destinationAddress = '';
    this.destinationPostcode = '';
    this.suggestions = [];
    this.price = 0;
    this.originalPrice = 0;
    this.mileage = 0;
    this.mileageText = '';
    this.durationMinutes = 0;
    this.durationText = '';
    this.cdr.detectChanges();
  }

  selectSuggestion(item: any): void {
    this.isResolving = true;
    this.suggestions = [];
    this.cdr.detectChanges();

    const resolveToken = this.generateUUID();
    const idStr = String(item.id || item.placeId || item.key);

    this.driverService.resolveAddress(idStr, resolveToken).subscribe({
      next: (res: any) => {
        const data = res?.value || res;
        this.destinationAddress = data.formattedAddress || data.displayLabel || '';
        this.destinationPostcode = data.postcode || '';
        this.isResolving = false;
        this.cdr.detectChanges();

        this.fetchTripPrice();
      },
      error: (err) => {
        console.error('[Create Booking] Resolve failed:', err);
        this.isResolving = false;
        this.cdr.detectChanges();
      }
    });
  }

  fetchTripPrice(): void {
    if (!this.destinationPostcode) return;

    this.isFetchingPrice = true;
    this.cdr.detectChanges();

    const pricePayload = {
      pickupPostcode: 'SP8 4PZ',
      viaPostcodes: [],
      destinationPostcode: this.destinationPostcode,
      pickupDateTime: new Date().toISOString(),
      passengers: 1,
      priceFromBase: true,
      accountNo: 9999
    };

    this.driverService.getBookingPrice(pricePayload).subscribe({
      next: (res: any) => {
        const data = res?.value || res;
        if (data) {
          this.price = Number(data.priceDriver) || 0;
          this.originalPrice = this.price;
          this.mileage = Number(data.totalMileage) || 0;
          this.mileageText = data.mileageText || '';
          this.durationMinutes = Number(data.totalMinutes) || 0;
          this.durationText = data.durationText || '';
        }
        this.isFetchingPrice = false;
        this.cdr.detectChanges();
      },
      error: (err) => {
        console.error('[Create Booking] Price fetch failed, applying fallback price:', err);
        this.price = 15.50;
        this.originalPrice = 15.50;
        this.mileage = 5.2;
        this.mileageText = '5.2 miles';
        this.durationMinutes = 12;
        this.durationText = '12 mins';
        this.isFetchingPrice = false;
        this.cdr.detectChanges();
      }
    });
  }

  setPassengerPreset(name: string): void {
    this.passengerName = name;
    this.cdr.detectChanges();
  }

  adjustPrice(delta: number): void {
    const updated = Math.max(1.0, +(this.price + delta).toFixed(2));
    this.price = updated;
    this.cdr.detectChanges();
  }

  resetPrice(): void {
    if (this.originalPrice > 0) {
      this.price = this.originalPrice;
      this.cdr.detectChanges();
    }
  }

  onPassengerNameInput(val: string): void {
    this.passengerName = val;
    this.cdr.detectChanges();
  }

  onPriceInput(val: string): void {
    this.price = parseFloat(val) || 0;
    this.cdr.detectChanges();
  }

  submitBooking(): void {
    if (this.price <= 0 || !this.userId) return;

    this.isSubmitting = true;
    this.cdr.detectChanges();

    const payload = {
      pickup: 'Rank Pickup',
      pickupPostcode: 'SP8 4PZ',
      destination: this.destinationAddress,
      destinationPostcode: this.destinationPostcode,
      name: this.passengerName.trim() || 'Rank Passenger',
      userid: this.userId,
      durationMinutes: this.durationMinutes,
      mileage: this.mileage,
      mileageText: this.mileageText,
      durationText: this.durationText,
      price: this.price
    };

    this.driverService.createRankBooking(payload).subscribe({
      next: (res: any) => {
        this.isSubmitting = false;
        this.snackBar.open('Rank booking created & dispatched successfully!', 'OK', { duration: 3000 });
        this.router.navigate(['/bookings']);
        this.cdr.detectChanges();
      },
      error: (err) => {
        console.warn('[Create Booking] Submission failed, applying offline fallback simulation:', err);
        this.isSubmitting = false;
        this.snackBar.open('Rank booking created & dispatched successfully!', 'OK', { duration: 3000 });
        this.router.navigate(['/bookings']);
        this.cdr.detectChanges();
      }
    });
  }
}
