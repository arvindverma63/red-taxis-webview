import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { DriverService } from '../services/driver.service';

export interface AvailabilitySlot {
  id: number;
  userId?: number;
  date: string; // ISO date string
  from: string; // '08:00'
  to: string;   // '17:00'
  giveOrTake: boolean;
  type: number; // 0: NotSet, 1: Available, 2: Unavailable
  note: string;
  allocated?: boolean;
}

export interface DriverFleetAvailability {
  fullName: string;
  vehicleType: number | string;
  date: string;
  availableHours: Array<{ from: string; to: string; note?: string }>;
  unAvailableHours: Array<{ from: string; to: string; note?: string }>;
  allocatedHours: Array<{ from: string; to: string; note?: string }>;
}

@Component({
  selector: 'app-availability',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    MatCardModule,
    MatButtonModule,
    MatIconModule,
    MatSnackBarModule
  ],
  template: `
    <div 
      class="availability-container"
      (touchstart)="onTouchStart($event)"
      (touchmove)="onTouchMove($event)"
      (touchend)="onTouchEnd()"
    >
      <!-- Pull-to-Refresh Floating Indicator -->
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

      <!-- 1. Top Mode Switch (My Availability vs All Drivers) -->
      <div class="mode-switch-wrapper">
        <div class="mode-segmented-control">
          <button 
            type="button" 
            class="mode-btn" 
            [class.active]="activeMode === 'my'"
            (click)="setMode('my')"
          >
            <span class="material-symbols-outlined mode-icon">person</span>
            <span>My Availability</span>
          </button>
          <button 
            type="button" 
            class="mode-btn" 
            [class.active]="activeMode === 'fleet'"
            (click)="setMode('fleet')"
          >
            <span class="material-symbols-outlined mode-icon">group</span>
            <span>All Drivers</span>
          </button>
        </div>
      </div>

      <!-- 2. Week Range Navigator Card -->
      <div class="week-nav-card">
        <div class="week-header-row">
          <button class="nav-arrow-btn" (click)="navigateWeek(-1)" [disabled]="isLoading">
            <span class="material-symbols-outlined">chevron_left</span>
          </button>
          
          <div class="week-label-box">
            <span class="material-symbols-outlined calendar-icon">calendar_month</span>
            <span class="week-date-range">{{ formatWeekRange() }}</span>
          </div>

          <button class="nav-arrow-btn" (click)="navigateWeek(1)" [disabled]="isLoading">
            <span class="material-symbols-outlined">chevron_right</span>
          </button>
        </div>

        <!-- 7-Day Pill Bar -->
        <div class="days-pill-bar">
          <button 
            *ngFor="let day of currentWeekDays; let i = index" 
            class="day-pill-btn"
            [class.selected]="selectedDayIndex === i"
            [class.has-slots]="hasSlotsForDay(day.date)"
            (click)="selectDay(i)"
          >
            <span class="day-letter">{{ day.dayLetter }}</span>
            <span class="day-number">{{ day.date.getDate() }}</span>
            <span class="slot-dot" *ngIf="hasSlotsForDay(day.date)"></span>
          </button>
        </div>
      </div>

      <!-- ================= MY AVAILABILITY VIEW ================= -->
      <ng-container *ngIf="activeMode === 'my'">
        
        <!-- Quick Preset Actions Card -->
        <div class="preset-section-card">
          <div class="card-title-row">
            <span class="material-symbols-outlined card-title-icon">bolt</span>
            <span class="card-title-text">Quick Presets ({{ formatSelectedDate() }})</span>
          </div>

          <div class="presets-grid">
            <button 
              type="button" 
              class="preset-chip-btn" 
              (click)="applyPreset('am-school')"
              [class.active]="selectedPresetKey === 'am-school'"
            >
              <span class="material-symbols-outlined preset-icon icon-am">wb_twilight</span>
              <div class="preset-texts">
                <span class="preset-title">AM School</span>
                <span class="preset-time">07:30 – 09:30</span>
              </div>
            </button>

            <button 
              type="button" 
              class="preset-chip-btn" 
              (click)="applyPreset('pm-school')"
              [class.active]="selectedPresetKey === 'pm-school'"
            >
              <span class="material-symbols-outlined preset-icon icon-pm">backpack</span>
              <div class="preset-texts">
                <span class="preset-title">PM School</span>
                <span class="preset-time">14:30 – 16:30</span>
              </div>
            </button>

            <button 
              type="button" 
              class="preset-chip-btn" 
              (click)="applyPreset('am-pm-school')"
              [class.active]="selectedPresetKey === 'am-pm-school'"
            >
              <span class="material-symbols-outlined preset-icon icon-full">school</span>
              <div class="preset-texts">
                <span class="preset-title">Full School</span>
                <span class="preset-time">07:30 – 16:30</span>
              </div>
            </button>

            <button 
              type="button" 
              class="preset-chip-btn unavail" 
              (click)="applyPreset('unavailable')"
              [class.active]="selectedPresetKey === 'unavailable'"
            >
              <span class="material-symbols-outlined preset-icon icon-off">block</span>
              <div class="preset-texts">
                <span class="preset-title">Day Off</span>
                <span class="preset-time">00:00 – 23:59</span>
              </div>
            </button>
          </div>
        </div>

        <!-- Custom Slot Configuration Form Card -->
        <div class="custom-slot-card">
          <div class="card-title-row">
            <span class="material-symbols-outlined card-title-icon">schedule</span>
            <span class="card-title-text">Custom Slot & Shift Settings</span>
          </div>

          <!-- Time Inputs Row -->
          <div class="time-inputs-row">
            <div class="time-input-box">
              <label class="time-lbl">Start Time (From)</label>
              <div class="select-time-wrapper">
                <select [(ngModel)]="fromHour" class="time-dropdown">
                  <option *ngFor="let h of hours" [value]="h">{{ h }}</option>
                </select>
                <span class="time-colon">:</span>
                <select [(ngModel)]="fromMinute" class="time-dropdown">
                  <option *ngFor="let m of minutes" [value]="m">{{ m }}</option>
                </select>
              </div>
            </div>

            <div class="time-arrow-divider">
              <span class="material-symbols-outlined">arrow_forward</span>
            </div>

            <div class="time-input-box">
              <label class="time-lbl">End Time (To)</label>
              <div class="select-time-wrapper">
                <select [(ngModel)]="toHour" class="time-dropdown">
                  <option *ngFor="let h of hours" [value]="h">{{ h }}</option>
                </select>
                <span class="time-colon">:</span>
                <select [(ngModel)]="toMinute" class="time-dropdown">
                  <option *ngFor="let m of minutes" [value]="m">{{ m }}</option>
                </select>
              </div>
            </div>
          </div>

          <!-- Give or Take Checkbox Option -->
          <div class="option-toggle-row">
            <label class="checkbox-container">
              <input type="checkbox" [(ngModel)]="giveOrTake">
              <span class="checkmark"></span>
              <span class="checkbox-label-text">Give or Take (+/- 15 mins flex)</span>
            </label>
          </div>

          <!-- Driver Note Input -->
          <div class="note-input-group">
            <label class="note-lbl">Driver Shift Note (Optional)</label>
            <input 
              type="text" 
              [(ngModel)]="customNote" 
              placeholder="e.g. Morning school run, airport transfers only..." 
              class="note-text-input"
            />
          </div>

          <!-- Dual Action Buttons -->
          <div class="action-buttons-row">
            <button 
              type="button" 
              class="btn-save available-btn" 
              [disabled]="isSaving"
              (click)="saveAvailability(1)"
            >
              <span class="material-symbols-outlined btn-icon" *ngIf="!isSaving">check_circle</span>
              <span class="material-symbols-outlined btn-icon spinning" *ngIf="isSaving">refresh</span>
              <span>Mark Available</span>
            </button>

            <button 
              type="button" 
              class="btn-save unavailable-btn" 
              [disabled]="isSaving"
              (click)="saveAvailability(2)"
            >
              <span class="material-symbols-outlined btn-icon">cancel</span>
              <span>Mark Unavailable</span>
            </button>
          </div>
        </div>

        <!-- Active Slots for Selected Day -->
        <div class="slots-list-section">
          <div class="section-title-row">
            <h3 class="section-title">Active Shifts on {{ formatSelectedDate() }}</h3>
            <span class="slots-count-badge">{{ selectedDaySlots.length }} configured</span>
          </div>

          <!-- Shimmer Placeholder -->
          <div *ngIf="isLoading" class="shimmer-placeholder list-shimmer"></div>

          <!-- Empty State -->
          <div *ngIf="!isLoading && selectedDaySlots.length === 0" class="empty-slots-card">
            <span class="material-symbols-outlined empty-icon">event_busy</span>
            <p class="empty-title">No shifts configured for this day</p>
            <p class="empty-subtitle">Choose a quick preset above or set your custom working hours to let dispatch know your schedule.</p>
          </div>

          <!-- Slots List -->
          <div class="slots-cards-list" *ngIf="!isLoading && selectedDaySlots.length > 0">
            <div 
              *ngFor="let slot of selectedDaySlots" 
              class="slot-card"
              [class.available]="slot.type === 1"
              [class.unavailable]="slot.type === 2"
            >
              <div class="slot-status-indicator"></div>
              
              <div class="slot-main-content">
                <div class="slot-badges-row">
                  <span class="status-badge" [class.avail]="slot.type === 1" [class.unavail]="slot.type === 2">
                    {{ slot.type === 1 ? 'AVAILABLE' : 'UNAVAILABLE' }}
                  </span>
                  <span class="flex-badge" *ngIf="slot.giveOrTake">
                    +/- 15m Flex
                  </span>
                </div>

                <div class="slot-time-range">
                  <span class="material-symbols-outlined time-icon">schedule</span>
                  <span class="time-text">{{ slot.from }} – {{ slot.to }}</span>
                </div>

                <div class="slot-note-text" *ngIf="slot.note">
                  <span class="material-symbols-outlined note-icon">sticky_note_2</span>
                  <span>{{ slot.note }}</span>
                </div>
              </div>

              <!-- Delete Action -->
              <button 
                type="button" 
                class="slot-delete-btn" 
                (click)="deleteSlot(slot)"
                title="Delete this shift"
              >
                <span class="material-symbols-outlined delete-icon">delete</span>
              </button>
            </div>
          </div>
        </div>

      </ng-container>

      <!-- ================= ALL DRIVERS (FLEET VIEW) ================= -->
      <ng-container *ngIf="activeMode === 'fleet'">
        <div class="fleet-section">
          
          <!-- Fleet Header & Vehicle Filter -->
          <div class="fleet-filter-card">
            <div class="fleet-search-wrapper">
              <span class="material-symbols-outlined search-icon">search</span>
              <input 
                type="text" 
                [(ngModel)]="fleetSearchQuery" 
                placeholder="Search driver by name..." 
                class="fleet-search-input"
              />
            </div>

            <!-- Vehicle Type Filters -->
            <div class="vehicle-chips-bar">
              <button 
                *ngFor="let vType of vehicleFilterOptions" 
                class="vehicle-chip-btn"
                [class.active]="selectedVehicleFilter === vType"
                (click)="selectedVehicleFilter = vType"
              >
                {{ vType }}
              </button>
            </div>
          </div>

          <!-- Loading State -->
          <div *ngIf="isLoadingFleet" class="shimmer-placeholder list-shimmer"></div>

          <!-- Empty Fleet State -->
          <div *ngIf="!isLoadingFleet && filteredFleetDrivers.length === 0" class="empty-slots-card">
            <span class="material-symbols-outlined empty-icon">group_off</span>
            <p class="empty-title">No fleet records found</p>
            <p class="empty-subtitle">No driver availability data reported for {{ formatSelectedDate() }}.</p>
          </div>

          <!-- Fleet Drivers List -->
          <div class="fleet-list" *ngIf="!isLoadingFleet && filteredFleetDrivers.length > 0">
            <div *ngFor="let driver of filteredFleetDrivers" class="fleet-driver-card">
              <div class="driver-header-row">
                <div class="driver-avatar-circle">
                  {{ getDriverInitials(driver.fullName) }}
                </div>
                <div class="driver-meta">
                  <span class="driver-name">{{ driver.fullName }}</span>
                  <span class="driver-vehicle-badge">{{ getVehicleName(driver.vehicleType) }}</span>
                </div>
              </div>

              <!-- Available Hours -->
              <div class="hours-section" *ngIf="driver.availableHours.length > 0">
                <span class="hours-lbl green">Available Slots</span>
                <div class="hours-tags">
                  <span *ngFor="let h of driver.availableHours" class="hour-tag avail">
                    {{ h.from }} – {{ h.to }} {{ h.note ? '(' + h.note + ')' : '' }}
                  </span>
                </div>
              </div>

              <!-- Unavailable Hours -->
              <div class="hours-section" *ngIf="driver.unAvailableHours.length > 0">
                <span class="hours-lbl red">Unavailable Slots</span>
                <div class="hours-tags">
                  <span *ngFor="let h of driver.unAvailableHours" class="hour-tag unavail">
                    {{ h.from }} – {{ h.to }} {{ h.note ? '(' + h.note + ')' : '' }}
                  </span>
                </div>
              </div>

              <!-- Allocated Hours -->
              <div class="hours-section" *ngIf="driver.allocatedHours && driver.allocatedHours.length > 0">
                <span class="hours-lbl blue">Allocated Trips</span>
                <div class="hours-tags">
                  <span *ngFor="let h of driver.allocatedHours" class="hour-tag allocated">
                    {{ h.from }} – {{ h.to }}
                  </span>
                </div>
              </div>

            </div>
          </div>

        </div>
      </ng-container>

    </div>
  `,
  styles: [`
    /* Dark Theme Support via :host-context */
    :host-context(.dark-theme) .availability-container {
      background-color: #121214 !important;
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .mode-segmented-control {
      background-color: #2D2D35 !important;
    }
    :host-context(.dark-theme) .mode-btn:not(.active) {
      color: #90A4AE !important;
    }
    :host-context(.dark-theme) .mode-btn.active {
      background-color: #1E1E24 !important;
      color: #CD1A21 !important;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3) !important;
    }
    :host-context(.dark-theme) .week-nav-card,
    :host-context(.dark-theme) .preset-section-card,
    :host-context(.dark-theme) .custom-slot-card,
    :host-context(.dark-theme) .empty-slots-card,
    :host-context(.dark-theme) .slot-card,
    :host-context(.dark-theme) .fleet-filter-card,
    :host-context(.dark-theme) .fleet-driver-card {
      background-color: #1E1E24 !important;
      border-color: #2D2D35 !important;
      color: #ECEFF1 !important;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.25) !important;
    }
    :host-context(.dark-theme) .nav-arrow-btn {
      background-color: #2D2D35 !important;
      color: #ECEFF1 !important;
      border-color: #2D2D35 !important;
    }
    :host-context(.dark-theme) .day-pill-btn {
      background-color: #121214 !important;
      border-color: #2D2D35 !important;
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .day-pill-btn:not(.selected) .day-letter {
      color: #90A4AE !important;
    }
    :host-context(.dark-theme) .day-pill-btn:not(.selected) .day-number {
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .day-pill-btn.selected {
      background-color: #CD1A21 !important;
      border-color: #CD1A21 !important;
    }
    :host-context(.dark-theme) .preset-chip-btn {
      background-color: #121214 !important;
      border-color: #2D2D35 !important;
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .preset-chip-btn.active {
      background-color: #CD1A21 !important;
      border-color: #CD1A21 !important;
      color: #FFFFFF !important;
    }
    :host-context(.dark-theme) .preset-chip-btn.active .preset-title,
    :host-context(.dark-theme) .preset-chip-btn.active .preset-time {
      color: #FFFFFF !important;
    }
    :host-context(.dark-theme) .preset-title,
    :host-context(.dark-theme) .week-date-range,
    :host-context(.dark-theme) .card-title-text,
    :host-context(.dark-theme) .time-colon,
    :host-context(.dark-theme) .time-dropdown,
    :host-context(.dark-theme) .note-text-input,
    :host-context(.dark-theme) .section-title,
    :host-context(.dark-theme) .slot-time,
    :host-context(.dark-theme) .empty-title,
    :host-context(.dark-theme) .time-text,
    :host-context(.dark-theme) .fleet-search-input,
    :host-context(.dark-theme) .driver-name {
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .preset-time,
    :host-context(.dark-theme) .time-lbl,
    :host-context(.dark-theme) .time-arrow-divider,
    :host-context(.dark-theme) .checkbox-container,
    :host-context(.dark-theme) .note-lbl,
    :host-context(.dark-theme) .slot-note,
    :host-context(.dark-theme) .empty-subtitle,
    :host-context(.dark-theme) .driver-vehicle-badge,
    :host-context(.dark-theme) .slot-note-text,
    :host-context(.dark-theme) .slot-note-text span {
      color: #90A4AE !important;
    }
    :host-context(.dark-theme) .select-time-wrapper,
    :host-context(.dark-theme) .note-text-input,
    :host-context(.dark-theme) .fleet-search-wrapper {
      background-color: #121214 !important;
      border-color: #2D2D35 !important;
    }
    :host-context(.dark-theme) .note-text-input:focus {
      border-color: #CD1A21 !important;
      background-color: #121214 !important;
    }
    :host-context(.dark-theme) .slots-count-badge {
      background-color: #2D2D35 !important;
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .time-dropdown option {
      background-color: #1E1E24 !important;
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .vehicle-chip-btn {
      background-color: #121214 !important;
      border-color: #2D2D35 !important;
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .vehicle-chip-btn.active {
      background-color: #CD1A21 !important;
      border-color: #CD1A21 !important;
      color: #FFFFFF !important;
    }

    * {
      -webkit-tap-highlight-color: transparent !important;
      outline: none !important;
    }
    .availability-container {
      background-color: #F8F9FA;
      min-height: 100vh;
      padding: 12px 14px 60px 14px;
      font-family: 'Roboto', sans-serif;
      display: flex;
      flex-direction: column;
      gap: 14px;
      box-sizing: border-box;
      position: relative;
    }

    /* Floating Native Material Pull-to-Refresh Spinner */
    .floating-refresh-spinner {
      position: fixed;
      top: 0;
      left: 50%;
      width: 42px;
      height: 42px;
      border-radius: 50%;
      background-color: #FFFFFF;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.18);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 9999;
      pointer-events: none;
      transition: transform 0.2s cubic-bezier(0.175, 0.885, 0.32, 1.275), opacity 0.2s ease;
    }
    .native-spin-icon {
      font-size: 24px;
      color: #CD1A21;
      display: inline-block;
      transition: transform 0.05s linear;
    }
    .native-spin-icon.spinning {
      animation: nativeSpin 0.75s linear infinite;
    }
    @keyframes nativeSpin {
      from { transform: rotate(0deg); }
      to { transform: rotate(360deg); }
    }

    /* Top Segmented Mode Switch */
    .mode-switch-wrapper {
      display: flex;
      justify-content: center;
    }
    .mode-segmented-control {
      display: flex;
      background-color: #E2E4EB;
      padding: 3px;
      border-radius: 24px;
      width: 100%;
      max-width: 420px;
    }
    .mode-btn {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      border: none;
      background: transparent;
      padding: 9px 12px;
      border-radius: 20px;
      font-size: 13px;
      font-weight: 700;
      color: #5A606E;
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .mode-btn.active {
      background-color: #FFFFFF;
      color: #CD1A21;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    }
    .mode-icon {
      font-size: 18px;
    }

    /* Week Navigator Card */
    .week-nav-card {
      background-color: #FFFFFF;
      border-radius: 16px;
      padding: 14px 12px;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.03);
      border: 1px solid #E0E2EC;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .week-header-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .nav-arrow-btn {
      background-color: #F1F3F9;
      border: 1px solid #E0E2EC;
      border-radius: 50%;
      width: 36px;
      height: 36px;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #191C1E;
      cursor: pointer;
      transition: all 0.15s ease;
    }
    .nav-arrow-btn:active {
      background-color: #E2E4EB;
      transform: scale(0.95);
    }
    .week-label-box {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .calendar-icon {
      font-size: 19px;
      color: #CD1A21;
    }
    .week-date-range {
      font-size: 14px;
      font-weight: 700;
      color: #191C1E;
    }

    /* 7-Day Pill Bar */
    .days-pill-bar {
      display: flex;
      justify-content: space-between;
      gap: 6px;
    }
    .day-pill-btn {
      flex: 1;
      background-color: #F8F9FA;
      border: 1px solid #E0E2EC;
      border-radius: 12px;
      padding: 8px 4px;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 3px;
      cursor: pointer;
      position: relative;
      transition: all 0.15s ease;
    }
    .day-letter {
      font-size: 11px;
      font-weight: 700;
      color: #727782;
    }
    .day-number {
      font-size: 14px;
      font-weight: 800;
      color: #191C1E;
    }
    .day-pill-btn.selected {
      background-color: #CD1A21;
      border-color: #CD1A21;
    }
    .day-pill-btn.selected .day-letter,
    .day-pill-btn.selected .day-number {
      color: #FFFFFF;
    }
    .slot-dot {
      width: 5px;
      height: 5px;
      border-radius: 50%;
      background-color: #00875A;
      position: absolute;
      bottom: 4px;
    }
    .day-pill-btn.selected .slot-dot {
      background-color: #FFFFFF;
    }

    /* Presets Section Card */
    .preset-section-card,
    .custom-slot-card {
      background-color: #FFFFFF;
      border-radius: 16px;
      padding: 16px;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.03);
      border: 1px solid #E0E2EC;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .card-title-row {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .card-title-icon {
      font-size: 20px;
      color: #CD1A21;
    }
    .card-title-text {
      font-size: 14px;
      font-weight: 800;
      color: #191C1E;
    }

    /* Presets Grid */
    .presets-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 8px;
    }
    .preset-chip-btn {
      background-color: #F8F9FA;
      border: 1px solid #E0E2EC;
      border-radius: 12px;
      padding: 10px 10px;
      display: flex;
      align-items: center;
      gap: 8px;
      text-align: left;
      cursor: pointer;
      transition: all 0.15s ease;
    }
    .preset-chip-btn:active,
    .preset-chip-btn.active {
      border-color: #CD1A21;
      background-color: #FFF2F2;
    }
    .preset-icon {
      font-size: 22px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .preset-icon.icon-am { color: #E65100; }
    .preset-icon.icon-pm { color: #00838F; }
    .preset-icon.icon-full { color: #1565C0; }
    .preset-icon.icon-off { color: #C62828; }
    .preset-texts {
      display: flex;
      flex-direction: column;
    }
    .preset-title {
      font-size: 12px;
      font-weight: 700;
      color: #191C1E;
    }
    .preset-time {
      font-size: 10px;
      font-weight: 500;
      color: #727782;
    }

    /* Custom Slot Form */
    .time-inputs-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 8px;
    }
    .time-input-box {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .time-lbl {
      font-size: 11px;
      font-weight: 700;
      color: #5A606E;
    }
    .select-time-wrapper {
      display: flex;
      align-items: center;
      gap: 4px;
      background-color: #F8F9FA;
      border: 1px solid #E0E2EC;
      border-radius: 10px;
      padding: 6px 8px;
    }
    .time-dropdown {
      border: none;
      background: transparent;
      font-size: 14px;
      font-weight: 700;
      color: #191C1E;
      outline: none;
      cursor: pointer;
    }
    .time-colon {
      font-weight: 800;
      color: #191C1E;
    }
    .time-arrow-divider {
      display: flex;
      align-items: center;
      justify-content: center;
      color: #727782;
      padding-top: 14px;
    }

    /* Checkbox Container */
    .option-toggle-row {
      display: flex;
      align-items: center;
    }
    .checkbox-container {
      display: flex;
      align-items: center;
      gap: 8px;
      cursor: pointer;
      font-size: 12px;
      font-weight: 600;
      color: #455A64;
    }
    .checkbox-container input {
      accent-color: #CD1A21;
      width: 16px;
      height: 16px;
    }

    /* Note Input */
    .note-input-group {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .note-lbl {
      font-size: 11px;
      font-weight: 700;
      color: #5A606E;
    }
    .note-text-input {
      width: 100%;
      box-sizing: border-box;
      background-color: #F8F9FA;
      border: 1px solid #E0E2EC;
      border-radius: 10px;
      padding: 10px 12px;
      font-size: 13px;
      color: #191C1E;
      outline: none;
    }
    .note-text-input:focus {
      border-color: #CD1A21;
      background-color: #FFFFFF;
    }

    /* Action Buttons Row */
    .action-buttons-row {
      display: flex;
      gap: 10px;
      margin-top: 4px;
    }
    .btn-save {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      border: none;
      border-radius: 12px;
      padding: 12px 14px;
      font-size: 13px;
      font-weight: 800;
      cursor: pointer;
      transition: all 0.15s ease;
    }
    .btn-save:active {
      transform: scale(0.98);
    }
    .btn-save.available-btn {
      background-color: #00875A;
      color: #FFFFFF;
    }
    .btn-save.unavailable-btn {
      background-color: #DE350B;
      color: #FFFFFF;
    }
    .btn-icon {
      font-size: 18px;
    }
    .btn-icon.spinning {
      animation: nativeSpin 0.8s linear infinite;
    }

    /* Slots List Section */
    .slots-list-section {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .section-title-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .section-title {
      font-size: 15px;
      font-weight: 800;
      color: #191C1E;
      margin: 0;
    }
    .slots-count-badge {
      background-color: #E2E4EB;
      color: #455A64;
      font-size: 11px;
      font-weight: 700;
      padding: 3px 8px;
      border-radius: 12px;
    }

    /* Empty State Card */
    .empty-slots-card {
      background-color: #FFFFFF;
      border-radius: 16px;
      padding: 28px 20px;
      text-align: center;
      border: 1px dashed #C4C7D0;
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    .empty-icon {
      font-size: 42px;
      color: #9AA0A6;
      margin-bottom: 8px;
    }
    .empty-title {
      font-size: 14px;
      font-weight: 800;
      color: #191C1E;
      margin: 0 0 4px 0;
    }
    .empty-subtitle {
      font-size: 12px;
      color: #727782;
      margin: 0;
      line-height: 1.4;
      max-width: 320px;
    }

    /* Slot Card */
    .slots-cards-list {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .slot-card {
      background-color: #FFFFFF;
      border-radius: 14px;
      padding: 12px 14px;
      box-shadow: 0 2px 6px rgba(0, 0, 0, 0.03);
      border: 1px solid #E0E2EC;
      display: flex;
      align-items: center;
      gap: 12px;
      position: relative;
    }
    .slot-status-indicator {
      width: 4px;
      height: 40px;
      border-radius: 4px;
      background-color: #00875A;
    }
    .slot-card.unavailable .slot-status-indicator {
      background-color: #DE350B;
    }
    .slot-main-content {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .slot-badges-row {
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .status-badge {
      font-size: 10px;
      font-weight: 800;
      padding: 2px 6px;
      border-radius: 6px;
      letter-spacing: 0.5px;
    }
    .status-badge.avail {
      background-color: #E3FCEF;
      color: #006644;
    }
    .status-badge.unavail {
      background-color: #FFEBE6;
      color: #BF2600;
    }
    .flex-badge {
      font-size: 10px;
      font-weight: 700;
      background-color: #EAE6FF;
      color: #403294;
      padding: 2px 6px;
      border-radius: 6px;
    }
    .slot-time-range {
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .time-icon {
      font-size: 16px;
      color: #727782;
    }
    .time-text {
      font-size: 14px;
      font-weight: 800;
      color: #191C1E;
    }
    .slot-note-text {
      display: flex;
      align-items: center;
      gap: 4px;
      font-size: 11px;
      color: #5A606E;
    }
    .note-icon {
      font-size: 14px;
      color: #9AA0A6;
    }
    .slot-delete-btn {
      background: transparent;
      border: none;
      color: #DE350B;
      cursor: pointer;
      padding: 6px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: background 0.15s ease;
    }
    .slot-delete-btn:active {
      background-color: #FFEBE6;
    }
    .delete-icon {
      font-size: 20px;
    }

    /* Fleet View Styles */
    .fleet-section {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .fleet-filter-card {
      background-color: #FFFFFF;
      border-radius: 16px;
      padding: 12px;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.03);
      border: 1px solid #E0E2EC;
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .fleet-search-wrapper {
      display: flex;
      align-items: center;
      gap: 8px;
      background-color: #F8F9FA;
      border: 1px solid #E0E2EC;
      border-radius: 10px;
      padding: 8px 12px;
    }
    .search-icon {
      font-size: 20px;
      color: #727782;
    }
    .fleet-search-input {
      border: none;
      background: transparent;
      width: 100%;
      font-size: 13px;
      color: #191C1E;
      outline: none;
    }
    .vehicle-chips-bar {
      display: flex;
      gap: 6px;
      overflow-x: auto;
      padding-bottom: 2px;
    }
    .vehicle-chip-btn {
      background-color: #F1F3F9;
      border: 1px solid #E0E2EC;
      border-radius: 14px;
      padding: 5px 12px;
      font-size: 11px;
      font-weight: 700;
      color: #5A606E;
      white-space: nowrap;
      cursor: pointer;
    }
    .vehicle-chip-btn.active {
      background-color: #CD1A21;
      border-color: #CD1A21;
      color: #FFFFFF;
    }

    .fleet-list {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .fleet-driver-card {
      background-color: #FFFFFF;
      border-radius: 14px;
      padding: 14px;
      box-shadow: 0 2px 6px rgba(0, 0, 0, 0.03);
      border: 1px solid #E0E2EC;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .driver-header-row {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .driver-avatar-circle {
      width: 36px;
      height: 36px;
      border-radius: 50%;
      background-color: #CD1A21;
      color: #FFFFFF;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 13px;
      font-weight: 800;
    }
    .driver-meta {
      display: flex;
      flex-direction: column;
    }
    .driver-name {
      font-size: 14px;
      font-weight: 800;
      color: #191C1E;
    }
    .driver-vehicle-badge {
      font-size: 11px;
      font-weight: 600;
      color: #727782;
    }
    .hours-section {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .hours-lbl {
      font-size: 10px;
      font-weight: 800;
      letter-spacing: 0.5px;
      text-transform: uppercase;
    }
    .hours-lbl.green { color: #00875A; }
    .hours-lbl.red { color: #DE350B; }
    .hours-lbl.blue { color: #0052CC; }

    .hours-tags {
      display: flex;
      flex-wrap: wrap;
      gap: 6px;
    }
    .hour-tag {
      font-size: 11px;
      font-weight: 700;
      padding: 3px 8px;
      border-radius: 6px;
    }
    .hour-tag.avail {
      background-color: #E3FCEF;
      color: #006644;
    }
    .hour-tag.unavail {
      background-color: #FFEBE6;
      color: #BF2600;
    }
    .hour-tag.allocated {
      background-color: #DEEBFF;
      color: #0747A6;
    }

    /* Shimmer Placeholder */
    .shimmer-placeholder {
      background: linear-gradient(90deg, #E0E2EC 25%, #F0F2FA 50%, #E0E2EC 75%);
      background-size: 200% 100%;
      animation: shimmerAnim 1.5s infinite;
      border-radius: 12px;
      height: 80px;
    }
    @keyframes shimmerAnim {
      0% { background-position: 200% 0; }
      100% { background-position: -200% 0; }
    }
  `]
})
export class AvailabilityComponent implements OnInit {
  activeMode: 'my' | 'fleet' = 'my';
  
  // Date State
  currentWeekOffset: number = 0;
  selectedDayIndex: number = 0;
  currentWeekStartDate: Date = new Date();
  currentWeekDays: Array<{ dayLetter: string; date: Date }> = [];
  
  // Availabilities Data
  allMySlots: AvailabilitySlot[] = [];
  selectedDaySlots: AvailabilitySlot[] = [];
  fleetDrivers: DriverFleetAvailability[] = [];
  
  // Custom Slot Form Fields
  fromHour: string = '08';
  fromMinute: string = '00';
  toHour: string = '17';
  toMinute: string = '00';
  giveOrTake: boolean = false;
  customNote: string = '';
  selectedPresetKey: string = '';

  // Fleet View Filters
  fleetSearchQuery: string = '';
  selectedVehicleFilter: string = 'All';
  vehicleFilterOptions: string[] = ['All', 'Saloon', 'Estate', 'MPV', 'MPVPlus', 'SUV'];

  // Status flags
  isLoading: boolean = false;
  isLoadingFleet: boolean = false;
  isSaving: boolean = false;
  isRefreshing: boolean = false;

  // Touch pull to refresh
  pullStartY = 0;
  pullDistance = 0;

  hours: string[] = Array.from({ length: 24 }, (_, i) => i.toString().padStart(2, '0'));
  minutes: string[] = ['00', '15', '30', '45'];

  constructor(
    private driverService: DriverService,
    private snackBar: MatSnackBar,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.initWeek(0);
    this.loadMyAvailabilities();
  }

  setMode(mode: 'my' | 'fleet'): void {
    this.activeMode = mode;
    if (mode === 'fleet') {
      this.loadFleetAvailabilities();
    }
  }

  initWeek(offset: number): void {
    this.currentWeekOffset += offset;
    const now = new Date();
    // Start of week (Monday)
    const dayOfWeek = now.getDay();
    const diffToMon = (dayOfWeek === 0 ? -6 : 1) - dayOfWeek;
    const mon = new Date(now);
    mon.setDate(now.getDate() + diffToMon + (this.currentWeekOffset * 7));
    mon.setHours(0, 0, 0, 0);

    this.currentWeekStartDate = mon;
    this.currentWeekDays = [];

    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    for (let i = 0; i < 7; i++) {
      const d = new Date(mon);
      d.setDate(mon.getDate() + i);
      this.currentWeekDays.push({
        dayLetter: letters[i],
        date: d
      });
    }

    if (offset !== 0) {
      this.selectedDayIndex = 0;
    }
    this.filterSlotsForSelectedDay();
  }

  navigateWeek(direction: number): void {
    this.initWeek(direction);
    if (this.activeMode === 'fleet') {
      this.loadFleetAvailabilities();
    }
  }

  selectDay(index: number): void {
    this.selectedDayIndex = index;
    this.filterSlotsForSelectedDay();
    if (this.activeMode === 'fleet') {
      this.loadFleetAvailabilities();
    }
  }

  getSelectedDate(): Date {
    if (this.currentWeekDays.length > this.selectedDayIndex) {
      return this.currentWeekDays[this.selectedDayIndex].date;
    }
    return new Date();
  }

  formatWeekRange(): string {
    if (this.currentWeekDays.length < 7) return '';
    const start = this.currentWeekDays[0].date;
    const end = this.currentWeekDays[6].date;
    const fmt = (d: Date) => `${d.getDate().toString().padStart(2, '0')}/${(d.getMonth() + 1).toString().padStart(2, '0')}/${d.getFullYear()}`;
    return `${fmt(start)}  to  ${fmt(end)}`;
  }

  formatSelectedDate(): string {
    const d = this.getSelectedDate();
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return `${days[d.getDay()]}, ${d.getDate()} ${months[d.getMonth()]}`;
  }

  formatTimeStr(timeVal: any): string {
    if (!timeVal) return '08:00';
    const s = timeVal.toString().trim();
    if (s.includes('T')) {
      const timePart = s.split('T')[1];
      return timePart.substring(0, 5);
    }
    const parts = s.split(':');
    if (parts.length >= 2) {
      return `${parts[0].padStart(2, '0')}:${parts[1].padStart(2, '0')}`;
    }
    return s;
  }

  getDateKey(dateVal: Date | string): string {
    if (!dateVal) return '';
    if (typeof dateVal === 'string') {
      const match = dateVal.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/);
      if (match) {
        return `${match[1]}-${match[2].padStart(2, '0')}-${match[3].padStart(2, '0')}`;
      }
      const slashMatch = dateVal.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})/);
      if (slashMatch) {
        return `${slashMatch[3]}-${slashMatch[2].padStart(2, '0')}-${slashMatch[1].padStart(2, '0')}`;
      }
    }
    const d = new Date(dateVal);
    if (isNaN(d.getTime())) return '';
    const y = d.getFullYear();
    const m = (d.getMonth() + 1).toString().padStart(2, '0');
    const day = d.getDate().toString().padStart(2, '0');
    return `${y}-${m}-${day}`;
  }

  hasSlotsForDay(targetDate: Date): boolean {
    const targetKey = this.getDateKey(targetDate);
    return this.allMySlots.some(slot => this.getDateKey(slot.date) === targetKey);
  }

  filterSlotsForSelectedDay(): void {
    const targetKey = this.getDateKey(this.getSelectedDate());
    this.selectedDaySlots = this.allMySlots.filter(slot => this.getDateKey(slot.date) === targetKey);
    this.cdr.detectChanges();
  }

  getUserIdFromToken(): number {
    try {
      const token = this.driverService.getToken();
      if (!token) return 0;
      const parts = token.split('.');
      if (parts.length < 2) return 0;
      const base64Url = parts[1];
      const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
      const jsonPayload = decodeURIComponent(
        atob(base64)
          .split('')
          .map(c => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
          .join('')
      );
      const payload = JSON.parse(jsonPayload);
      const userId = payload.id || payload.nameid || payload.userId || payload.sub;
      return userId ? Number(userId) : 0;
    } catch (e) {
      console.warn('Failed to parse token for userId:', e);
      return 0;
    }
  }

  // ---------------- API CALLS ----------------
  loadMyAvailabilities(): void {
    this.isLoading = true;
    this.driverService.getAvailabilities().subscribe({
      next: (res: any) => {
        this.isLoading = false;
        this.isRefreshing = false;
        let list: any[] = [];
        if (Array.isArray(res)) {
          list = res;
        } else if (res && typeof res === 'object') {
          list = res.drivers || res.Drivers || res.availabilities || res.Availabilities || res.value || res.data || res.result || [];
        }

        console.log('[Availability] Loaded from API:', list.length, list);

        this.allMySlots = list.map((item: any) => ({
          id: item.id ?? item.Id ?? item.availabilityId ?? item.AvailabilityId ?? 0,
          userId: item.userId ?? item.UserId ?? 0,
          date: item.date ?? item.Date ?? item.availabilityDate ?? item.AvailabilityDate ?? '',
          from: this.formatTimeStr(item.from ?? item.From ?? '08:00'),
          to: this.formatTimeStr(item.to ?? item.To ?? '17:00'),
          giveOrTake: !!(item.giveOrTake ?? item.GiveOrTake),
          type: item.type !== undefined ? item.type : (item.Type !== undefined ? item.Type : 1),
          note: item.note ?? item.Note ?? '',
          allocated: !!(item.allocated ?? item.Allocated)
        }));

        this.filterSlotsForSelectedDay();
      },
      error: (err) => {
        this.isLoading = false;
        this.isRefreshing = false;
        console.error('[Availability] Failed to load availabilities from API:', err);
        this.filterSlotsForSelectedDay();
      }
    });
  }

  loadFleetAvailabilities(): void {
    this.isLoadingFleet = true;
    const dateStr = this.getDateKey(this.getSelectedDate());

    this.driverService.getAllDriversAvailability(dateStr).subscribe({
      next: (res: any) => {
        this.isLoadingFleet = false;
        const list = Array.isArray(res) ? res : (res?.drivers || res?.Drivers || []);
        this.fleetDrivers = list.map((d: any) => ({
          fullName: d.fullName || d.driverName || d.FullName || 'Driver',
          vehicleType: d.vehicleType || d.VehicleType || 1,
          date: d.date || d.Date || dateStr,
          availableHours: d.availableHours || d.AvailableHours || [],
          unAvailableHours: d.unAvailableHours || d.UnAvailableHours || [],
          allocatedHours: d.allocatedHours || d.AllocatedHours || []
        }));
        this.cdr.detectChanges();
      },
      error: (err) => {
        this.isLoadingFleet = false;
        console.error('[Availability] Failed to load fleet availability:', err);
      }
    });
  }

  applyPreset(presetKey: string): void {
    this.selectedPresetKey = presetKey;
    switch (presetKey) {
      case 'am-school':
        this.fromHour = '07';
        this.fromMinute = '30';
        this.toHour = '09';
        this.toMinute = '30';
        this.customNote = 'AM School Run';
        break;
      case 'pm-school':
        this.fromHour = '14';
        this.fromMinute = '30';
        this.toHour = '16';
        this.toMinute = '30';
        this.customNote = 'PM School Run';
        break;
      case 'am-pm-school':
        this.fromHour = '07';
        this.fromMinute = '30';
        this.toHour = '16';
        this.toMinute = '30';
        this.customNote = 'Full School Run';
        break;
      case 'unavailable':
        this.fromHour = '00';
        this.fromMinute = '00';
        this.toHour = '23';
        this.toMinute = '59';
        this.customNote = 'Day Off';
        break;
    }
  }

  saveAvailability(type: number): void {
    const selDate = this.getSelectedDate();
    const dateKey = this.getDateKey(selDate);
    const dateFormatted = `${dateKey}T00:00:00.000Z`;
    const fromTime = `${this.fromHour}:${this.fromMinute}`;
    const toTime = `${this.toHour}:${this.toMinute}`;
    const resolvedUserId = this.getUserIdFromToken();

    const payload = {
      userId: resolvedUserId,
      date: dateFormatted,
      from: fromTime,
      to: toTime,
      giveOrTake: this.giveOrTake,
      type: type,
      note: this.customNote.trim() || (type === 1 ? 'Available' : 'Unavailable')
    };

    console.log('[Availability] Dispatching POST /api/DriverApp/SetAvailability payload:', payload);

    this.isSaving = true;
    this.driverService.setAvailability(payload).subscribe({
      next: (res: any) => {
        this.isSaving = false;
        console.log('[Availability] SetAvailability response:', res);
        this.snackBar.open(
          type === 1 ? 'Availability added successfully ✅' : 'Marked unavailable for selected time ❌',
          'Close',
          { duration: 3000, panelClass: type === 1 ? ['green-snackbar'] : ['red-snackbar'] }
        );
        this.loadMyAvailabilities();
      },
      error: (err) => {
        this.isSaving = false;
        console.error('[Availability] SetAvailability error:', err);
        const errorText = err?.error?.message || err?.message || 'Error saving availability to server';
        this.snackBar.open(`Notice: ${errorText}`, 'Close', { duration: 3000 });
        this.loadMyAvailabilities();
      }
    });
  }

  deleteSlot(slot: AvailabilitySlot): void {
    if (!slot.id) return;
    this.driverService.deleteAvailability(slot.id).subscribe({
      next: () => {
        this.snackBar.open('Shift removed successfully', 'Close', { duration: 2500 });
        this.loadMyAvailabilities();
      },
      error: (err) => {
        console.error('[Availability] Delete error:', err);
        this.snackBar.open('Shift removed', 'Close', { duration: 2500 });
        this.loadMyAvailabilities();
      }
    });
  }

  get filteredFleetDrivers(): DriverFleetAvailability[] {
    let list = this.fleetDrivers;
    if (this.fleetSearchQuery.trim()) {
      const q = this.fleetSearchQuery.toLowerCase();
      list = list.filter(d => d.fullName.toLowerCase().includes(q));
    }
    if (this.selectedVehicleFilter !== 'All') {
      list = list.filter(d => this.getVehicleName(d.vehicleType).toLowerCase() === this.selectedVehicleFilter.toLowerCase());
    }
    return list;
  }

  getVehicleName(type: number | string): string {
    const num = typeof type === 'number' ? type : parseInt(type) || 0;
    switch (num) {
      case 1: return 'Saloon';
      case 2: return 'Estate';
      case 3: return 'MPV';
      case 4: return 'MPVPlus';
      case 5: return 'SUV';
      default: return typeof type === 'string' && type.length > 0 ? type : 'Standard';
    }
  }

  getDriverInitials(name: string): string {
    if (!name) return 'D';
    const parts = name.trim().split(' ');
    if (parts.length >= 2) return `${parts[0][0]}${parts[1][0]}`.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  // Pull-to-refresh
  onTouchStart(e: TouchEvent): void {
    if (window.scrollY === 0) {
      this.pullStartY = e.touches[0].clientY;
    }
  }

  onTouchMove(e: TouchEvent): void {
    if (this.pullStartY > 0 && window.scrollY === 0) {
      const diff = e.touches[0].clientY - this.pullStartY;
      if (diff > 0) {
        this.pullDistance = Math.min(75, diff * 0.45);
      }
    }
  }

  onTouchEnd(): void {
    if (this.pullDistance > 45) {
      this.isRefreshing = true;
      this.pullDistance = 45;
      this.notifyNativeApp('pull_refresh');
      if (this.activeMode === 'my') {
        this.loadMyAvailabilities();
      } else {
        this.loadFleetAvailabilities();
      }
    } else {
      this.pullDistance = 0;
    }
    this.pullStartY = 0;
  }

  notifyNativeApp(msg: string): void {
    try {
      const channel = (window as any).FlutterChannel;
      if (channel && typeof channel.postMessage === 'function') {
        channel.postMessage(msg);
      }
    } catch (e) {
      console.warn('FlutterChannel not available:', e);
    }
  }
}
