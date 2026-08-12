import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonToggleModule } from '@angular/material/button-toggle';
import { MatDividerModule } from '@angular/material/divider';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { MatDatepickerModule } from '@angular/material/datepicker';
import { MatNativeDateModule } from '@angular/material/core';
import { DriverService } from '../services/driver.service';
import { catchError, switchMap } from 'rxjs/operators';
import { of, forkJoin } from 'rxjs';

type AvailabilityStatus = 'Available' | 'Unavailable';

interface DayAvailability {
  dayName: string;
  status: AvailabilityStatus;
  fromTime: string;
  toTime: string;
  slotIds?: number[];
}

@Component({
  selector: 'app-availability',
  standalone: true,
  imports: [
    CommonModule,
    MatCardModule,
    MatButtonModule,
    MatIconModule,
    MatButtonToggleModule,
    MatDividerModule,
    MatSnackBarModule,
    MatDatepickerModule,
    MatNativeDateModule
  ],
  template: `
    <div class="material-container">


      <!-- Week Selector -->
      <mat-card class="week-selector-card">
        <mat-card-content class="week-selector-content">
          <button mat-icon-button (click)="changeWeek(-1)" [disabled]="isSaving" class="week-nav-btn">
            <mat-icon>chevron_left</mat-icon>
          </button>
          
          <input [matDatepicker]="picker" (dateChange)="onDateSelected($event.value)" style="display: none;">
          <mat-datepicker #picker></mat-datepicker>
          
          <div class="week-label-wrapper" (click)="picker.open()" style="cursor: pointer;">
            <mat-icon class="calendar-icon">calendar_today</mat-icon>
            <span class="week-range-text">{{ weekStartFormatted }} – {{ weekEndFormatted }}</span>
            <span *ngIf="currentWeekOffset === 0" class="current-week-badge">Current Week</span>
            <span *ngIf="currentWeekOffset === 1" class="current-week-badge future">Next Week</span>
            <span *ngIf="currentWeekOffset > 1" class="current-week-badge future">Week +{{currentWeekOffset}}</span>
            <span *ngIf="currentWeekOffset < 0" class="current-week-badge past">Past Week</span>
          </div>
          
          <button mat-icon-button (click)="changeWeek(1)" [disabled]="isSaving" class="week-nav-btn">
            <mat-icon>chevron_right</mat-icon>
          </button>
        </mat-card-content>
      </mat-card>

      <!-- Summary Stats & Presets -->
      <mat-card class="summary-card">
        <mat-card-content class="summary-content">
          <div class="summary-stats">
            <div class="stat">
              <span class="label">Hours Planned</span>
              <span class="value">{{ totalHours }} hrs</span>
            </div>
            <div class="stat">
              <span class="label">Days Selected</span>
              <span class="value active-highlight">{{ activeDaysCount }} / 7</span>
            </div>
          </div>

          <div class="presets-row">
            <button mat-flat-button class="preset-btn red-btn" (click)="applyPreset('weekdays')">
              Weekdays AM (08-16)
            </button>
            <button mat-flat-button class="preset-btn red-btn" (click)="applyPreset('weekends')">
              Weekends PM (16-24)
            </button>
            <button mat-stroked-button class="preset-btn clear-btn" (click)="clearAll()">
              Clear All
            </button>
          </div>
        </mat-card-content>
      </mat-card>

      <!-- Weekly Schedule Cards (Multiple Cards) -->
      <main class="schedule-list-container">
        <div *ngFor="let day of schedule; let dayIdx = index" 
             class="schedule-day-card" 
             [class.active-card]="day.status === 'Available'">
          
          <div class="card-header-row">
            <div class="day-title-wrapper">
              <span class="day-name-label">{{ day.dayName }}</span>
              <span class="day-date-sub">{{ getDayDateFormatted(dayIdx) }}</span>
            </div>
            
            <mat-button-toggle-group 
              [value]="day.status" 
              (change)="onStatusChange(dayIdx, $event.value)"
              class="toggle-group-custom"
            >
              <mat-button-toggle value="Available" class="slot-toggle green-toggle">Active</mat-button-toggle>
              <mat-button-toggle value="Unavailable" class="slot-toggle red-toggle">None</mat-button-toggle>
            </mat-button-toggle-group>
          </div>

          <!-- Custom Time Range pickers (shown only if status is Active) -->
          <div *ngIf="day.status === 'Available'" class="card-body-row animated-fade-in">
            <div class="time-pickers-container">
              <div class="time-select-group">
                <span class="input-prefix">From</span>
                <div class="select-inputs-row">
                  <select (change)="onHourChange(dayIdx, 'fromTime', $any($event.target).value)" class="custom-time-select">
                    <option *ngFor="let h of hoursList" [value]="h" [selected]="h === getHour(day.fromTime)">{{ h }}</option>
                  </select>
                  <span class="time-separator">:</span>
                  <select (change)="onMinuteChange(dayIdx, 'fromTime', $any($event.target).value)" class="custom-time-select">
                    <option *ngFor="let m of minutesList" [value]="m" [selected]="m === getMinute(day.fromTime)">{{ m }}</option>
                  </select>
                </div>
              </div>
              
              <span class="range-separator">–</span>

              <div class="time-select-group">
                <span class="input-prefix">To</span>
                <div class="select-inputs-row">
                  <select (change)="onHourChange(dayIdx, 'toTime', $any($event.target).value)" class="custom-time-select">
                    <option *ngFor="let h of hoursList" [value]="h" [selected]="h === getHour(day.toTime)">{{ h }}</option>
                  </select>
                  <span class="time-separator">:</span>
                  <select (change)="onMinuteChange(dayIdx, 'toTime', $any($event.target).value)" class="custom-time-select">
                    <option *ngFor="let m of minutesList" [value]="m" [selected]="m === getMinute(day.toTime)">{{ m }}</option>
                  </select>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>

      <!-- Sticky Save Bar -->
      <footer class="footer-actions">
        <button 
          mat-raised-button 
          class="save-btn" 
          [class.success]="saveSuccess"
          [disabled]="isSaving"
          (click)="saveAvailability()"
        >
          <mat-icon class="save-icon">{{ saveSuccess ? 'check' : 'save' }}</mat-icon>
          {{ isSaving ? 'Saving Shifts...' : saveSuccess ? 'Availability Saved!' : 'Save Shifts' }}
        </button>
      </footer>
    </div>
  `,
  styles: [`
    .material-container {
      padding: 16px;
      padding-bottom: 96px; /* Space for sticky footer save bar */
      background-color: var(--background-color, #F8F9FA); /* Light gray background */
      color: var(--text-primary, #263238);
      min-height: 100vh;
      font-family: inherit;
    }

    .app-header {
      margin-bottom: 20px;
      text-align: center;
    }

    .page-title {
      font-size: 22px;
      font-weight: 800;
      color: #121212; /* Pitch black */
      margin: 0;
      letter-spacing: 0.5px;
      text-transform: uppercase;
    }

    .page-subtitle {
      font-size: 12px;
      color: #546E7A; /* Slate grey */
      margin: 4px 0 0 0;
    }

    /* Week Selector Card */
    .week-selector-card {
      background-color: var(--surface-color, #FFFFFF);
      border: 1px solid var(--border-color, #E0E0E0);
      border-radius: 12px !important;
      margin-bottom: 16px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.02) !important;
    }

    .week-selector-content {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 8px 12px !important;
    }

    .week-nav-btn {
      color: #546E7A;
    }

    .week-label-wrapper {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .calendar-icon {
      color: #E53935;
      font-size: 18px;
      width: 18px;
      height: 18px;
    }

    .week-range-text {
      font-size: 14px;
      font-weight: 700;
      color: #121212;
    }

    .current-week-badge {
      font-size: 10px;
      font-weight: 800;
      padding: 2px 8px;
      border-radius: 12px;
      background-color: #ECEFF1;
      color: #546E7A;
      text-transform: uppercase;
    }
    .current-week-badge.future {
      background-color: rgba(229, 57, 53, 0.08);
      color: #E53935;
    }
    .current-week-badge.past {
      background-color: #ECEFF1;
      color: #90A4AE;
    }

    /* Summary Card */
    .summary-card {
      background-color: var(--surface-color, #FFFFFF); /* White card */
      border: 1px solid var(--border-color, #E0E0E0);
      border-radius: 12px !important;
      margin-bottom: 20px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.02) !important;
    }

    .summary-content {
      padding: 12px 16px !important;
    }

    .summary-stats {
      display: flex;
      justify-content: space-around;
      border-bottom: 1px solid var(--border-color, #E0E0E0);
      padding-bottom: 12px;
      margin-bottom: 12px;
    }

    .summary-stats .stat {
      display: flex;
      flex-direction: column;
      align-items: center;
    }

    .summary-stats .label {
      color: #546E7A;
      font-size: 10px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.8px;
      margin-bottom: 4px;
    }

    .summary-stats .value {
      font-size: 22px;
      font-weight: 900;
      color: #121212;
    }

    .active-highlight {
      color: #E53935 !important; /* Brand red */
    }

    .presets-row {
      display: flex;
      gap: 8px;
    }

    .preset-btn {
      flex: 1;
      font-size: 10px !important;
      font-weight: 800 !important;
      border-radius: 8px !important;
      height: 38px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    .preset-btn.red-btn {
      background-color: #E53935 !important;
      color: #FFFFFF !important;
      border: none !important;
    }
    .preset-btn.red-btn:hover {
      background-color: #B71C1C !important;
      box-shadow: 0 2px 8px rgba(229, 57, 53, 0.2) !important;
    }

    .clear-btn {
      border: 1px solid var(--border-color, #E0E0E0) !important;
      color: #546E7A !important;
      background: transparent !important;
    }
    .clear-btn:hover {
      background-color: rgba(0, 0, 0, 0.03) !important;
      color: #121212 !important;
    }

    /* Weekly Schedule List inside Single Card */
    .schedule-list-container {
      display: flex;
      flex-direction: column;
      gap: 12px;
      margin-bottom: 20px;
    }

    .schedule-day-card {
      background-color: var(--surface-color, #FFFFFF);
      border: 1px solid var(--border-color, #E0E0E0);
      border-radius: 12px !important;
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.02) !important;
      padding: 14px 16px;
      transition: all 0.2s ease-in-out;
    }
    
    .schedule-day-card:hover {
      transform: translateY(-2px);
      box-shadow: 0 6px 12px rgba(0, 0, 0, 0.04) !important;
      border-color: #CFD8DC;
    }

    .schedule-day-card.active-card {
      background-color: rgba(229, 57, 53, 0.01);
      border-color: rgba(229, 57, 53, 0.2);
    }

    .card-header-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    .day-title-wrapper {
      display: flex;
      flex-direction: column;
    }

    .day-name-label {
      font-weight: 800;
      color: #121212;
      font-size: 14px;
      letter-spacing: 0.3px;
    }

    .day-date-sub {
      font-size: 11px;
      color: #78909C;
      font-weight: 600;
      margin-top: 2px;
    }

    /* Toggle Group Capsule Styles */
    .toggle-group-custom {
      display: flex;
      width: 140px;
      box-shadow: none !important;
      border: 1px solid var(--border-color, #E0E0E0) !important;
      border-radius: 20px !important;
      overflow: hidden;
      background-color: #F8F9FA !important;
    }

    .slot-toggle {
      flex: 1;
      height: 32px;
      line-height: 32px;
      font-weight: 800;
      font-size: 11px;
      border: none !important;
      border-left: 1px solid var(--border-color, #E0E0E0) !important;
      color: #546E7A !important;
      background: transparent !important;
    }
    .slot-toggle:first-of-type {
      border-left: none !important;
    }

    /* Hide the built-in Angular Material Checkmark icon */
    ::ng-deep .toggle-group-custom .mat-button-toggle-checkmark {
      display: none !important;
    }

    /* Selected State Styles */
    ::ng-deep .toggle-group-custom .mat-button-toggle-checked {
      color: #FFFFFF !important;
    }
    ::ng-deep .toggle-group-custom .mat-button-toggle-checked.green-toggle {
      background-color: #E53935 !important; /* Custom Active color is brand red */
      box-shadow: inset 0 0 10px rgba(0, 0, 0, 0.1);
    }
    ::ng-deep .toggle-group-custom .mat-button-toggle-checked.red-toggle {
      background-color: #ECEFF1 !important; /* None color is very light grey */
      color: #546E7A !important;
    }
    ::ng-deep .toggle-group-custom .mat-button-toggle-checked.red-toggle .mat-button-toggle-label-content {
      color: #546E7A !important;
    }

    .card-body-row {
      margin-top: 12px;
      padding-top: 12px;
      border-top: 1px solid rgba(0, 0, 0, 0.05);
    }

    /* Time Range Picker Inputs */
    .time-pickers-container {
      display: flex;
      gap: 12px;
      align-items: center;
      justify-content: space-between;
    }

    .time-select-group {
      flex: 1;
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .select-inputs-row {
      display: flex;
      align-items: center;
      gap: 4px;
      flex: 1;
    }

    .custom-time-select {
      flex: 1;
      background-color: #F8F9FA;
      border: 1px solid var(--border-color, #E0E0E0);
      border-radius: 8px;
      padding: 0 8px;
      height: 38px;
      font-size: 13px;
      font-weight: 700;
      color: #121212;
      outline: none;
      transition: border-color 0.2s ease, box-shadow 0.2s ease;
      cursor: pointer;
      appearance: none; /* Hide default browser arrow if desired, or let standard browser styling handle it */
      -webkit-appearance: none;
      background-image: url("data:image/svg+xml;utf8,<svg fill='%23546E7A' height='24' viewBox='0 0 24 24' width='24' xmlns='http://www.w3.org/2000/svg'><path d='M7 10l5 5 5-5z'/><path d='M0 0h24v24H0z' fill='none'/></svg>");
      background-repeat: no-repeat;
      background-position: right 4px center;
      padding-right: 20px;
    }
    .custom-time-select:focus {
      border-color: #E53935;
      box-shadow: 0 0 6px rgba(229, 57, 53, 0.15);
    }

    .input-prefix {
      color: #546E7A;
      font-size: 10px;
      font-weight: 800;
      text-transform: uppercase;
      width: 32px;
      flex-shrink: 0;
    }

    .time-separator {
      color: #546E7A;
      font-weight: 800;
      font-size: 14px;
    }

    .range-separator {
      color: #90A4AE;
      font-weight: 800;
      margin: 0 4px;
    }

    /* Sticky Footer Save Button */
    .footer-actions {
      position: fixed;
      bottom: 0;
      left: 0;
      right: 0;
      padding: 16px;
      background-color: var(--background-color, #F8F9FA);
      border-top: 1px solid var(--border-color, #E0E0E0);
      z-index: 100;
      box-shadow: 0 -2px 10px rgba(0,0,0,0.05);
    }

    .save-btn {
      width: 100%;
      height: 48px;
      border-radius: 10px !important;
      font-size: 14px !important;
      font-weight: 800 !important;
      text-transform: uppercase;
      letter-spacing: 0.8px;
      background-color: #E53935 !important;
      color: #FFFFFF !important;
      border: none !important;
      transition: background-color 0.2s ease, box-shadow 0.2s ease !important;
    }
    .save-btn:not([disabled]):hover {
      background-color: #B71C1C !important;
      box-shadow: 0 2px 10px rgba(229, 57, 53, 0.3) !important;
    }

    .save-btn.success {
      background-color: #34C759 !important; /* Green on success */
      color: #FFFFFF !important;
    }

    .save-icon {
      font-size: 18px !important;
      width: 18px !important;
      height: 18px !important;
      margin-right: 6px;
      vertical-align: middle;
    }

    /* Micro Animations */
    .animated-fade-in {
      animation: fadeIn 0.25s ease-out forwards;
    }

    @keyframes fadeIn {
      from {
        opacity: 0;
        transform: translateY(4px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }
  `]
})
export class AvailabilityComponent implements OnInit {
  schedule: DayAvailability[] = [];
  currentWeekOffset = 0;
  saveSuccess = false;
  isSaving = false;

  hoursList = Array.from({ length: 24 }, (_, i) => i.toString().padStart(2, '0'));
  minutesList = Array.from({ length: 60 }, (_, i) => i.toString().padStart(2, '0'));

  getHour(timeStr: string): string {
    if (!timeStr) return '08';
    const hr = timeStr.split(':')[0] || '08';
    return hr.padStart(2, '0');
  }

  getMinute(timeStr: string): string {
    if (!timeStr) return '00';
    const min = timeStr.split(':')[1] || '00';
    return min.padStart(2, '0');
  }

  formatTimeSpan(timeStr: string): string {
    if (!timeStr) return '08:00';
    const parts = timeStr.split(':');
    const hr = (parts[0] || '08').padStart(2, '0');
    const min = (parts[1] || '00').padStart(2, '0');
    return `${hr}:${min}`;
  }

  onHourChange(dayIdx: number, field: 'fromTime' | 'toTime', hr: string): void {
    const current = this.schedule[dayIdx][field] || '08:00';
    const min = current.split(':')[1] || '00';
    this.schedule[dayIdx][field] = `${hr}:${min}`;
    this.saveSuccess = false;
    console.log(`[Availability] Hour changed for dayIdx ${dayIdx}, field ${field}: ${this.schedule[dayIdx][field]}`);
  }

  onMinuteChange(dayIdx: number, field: 'fromTime' | 'toTime', min: string): void {
    const current = this.schedule[dayIdx][field] || '08:00';
    const hr = current.split(':')[0] || '08';
    this.schedule[dayIdx][field] = `${hr}:${min}`;
    this.saveSuccess = false;
    console.log(`[Availability] Minute changed for dayIdx ${dayIdx}, field ${field}: ${this.schedule[dayIdx][field]}`);
  }

  parseLocalDate(dateStr: string): Date {
    if (!dateStr) return new Date();
    // Split by 'T' to get date part (YYYY-MM-DD)
    const datePart = dateStr.split('T')[0];
    const [year, month, day] = datePart.split('-').map(Number);
    // Construct local date at midnight
    return new Date(year, month - 1, day, 0, 0, 0, 0);
  }

  formatDateToLocalDateString(date: Date): string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}T00:00:00`;
  }

  constructor(private snackBar: MatSnackBar, private driverService: DriverService, private cdr: ChangeDetectorRef) {}

  private getUserIdFromToken(): number {
    const token = localStorage.getItem('auth_token');
    if (!token) return 0;
    try {
      const parts = token.split('.');
      if (parts.length !== 3) return 0;
      const payloadDecoded = atob(parts[1].replace(/-/g, '+').replace(/_/g, '/'));
      const payload = JSON.parse(payloadDecoded);
      return parseInt(payload.id || payload.userId || '0', 10);
    } catch (e) {
      console.error('Error decoding JWT token:', e);
      return 0;
    }
  }

  get mondayDate(): Date {
    const today = new Date();
    const currentDay = today.getDay();
    const distanceToMonday = currentDay === 0 ? -6 : 1 - currentDay;
    const monday = new Date(today);
    monday.setDate(today.getDate() + distanceToMonday + (this.currentWeekOffset * 7));
    monday.setHours(0, 0, 0, 0);
    return monday;
  }

  get weekStartFormatted(): string {
    return this.formatDateLabel(this.mondayDate);
  }

  get weekEndFormatted(): string {
    const date = new Date(this.mondayDate);
    date.setDate(date.getDate() + 6);
    return this.formatDateLabel(date);
  }

  formatDateLabel(date: Date): string {
    const options: Intl.DateTimeFormatOptions = { month: 'short', day: 'numeric' };
    return date.toLocaleDateString('en-US', options);
  }

  getDayDateFormatted(dayIdx: number): string {
    const date = new Date(this.mondayDate);
    date.setDate(date.getDate() + dayIdx);
    const options: Intl.DateTimeFormatOptions = { month: 'short', day: 'numeric' };
    return date.toLocaleDateString('en-US', options);
  }

  changeWeek(offsetChange: number): void {
    if (this.isSaving) return;
    this.currentWeekOffset += offsetChange;
    this.saveSuccess = false;
    this.ngOnInit();
  }

  onDateSelected(selectedDate: Date): void {
    if (!selectedDate || this.isSaving) return;
    console.log('[Availability] Selected date from calendar picker:', selectedDate);

    // Calculate the Monday of the week containing selectedDate
    const currentDay = selectedDate.getDay();
    const distanceToMonday = currentDay === 0 ? -6 : 1 - currentDay;
    const selectedMonday = new Date(selectedDate);
    selectedMonday.setDate(selectedDate.getDate() + distanceToMonday);
    selectedMonday.setHours(0, 0, 0, 0);

    // Calculate current week's Monday (offset = 0)
    const today = new Date();
    const todayDay = today.getDay();
    const todayDistanceToMonday = todayDay === 0 ? -6 : 1 - todayDay;
    const currentMonday = new Date(today);
    currentMonday.setDate(today.getDate() + todayDistanceToMonday);
    currentMonday.setHours(0, 0, 0, 0);

    // Calculate currentWeekOffset based on difference in weeks
    const diffTime = selectedMonday.getTime() - currentMonday.getTime();
    const diffWeeks = Math.round(diffTime / (1000 * 60 * 60 * 24 * 7));
    
    console.log(`[Availability] Computed week offset from datepicker: ${diffWeeks}`);
    this.currentWeekOffset = diffWeeks;
    this.saveSuccess = false;
    this.ngOnInit();
  }

  ngOnInit(): void {
    const userId = this.getUserIdFromToken();
    console.log('[Availability] ngOnInit triggered. Active week range:', this.weekStartFormatted, 'to', this.weekEndFormatted);
    console.log('[Availability] Decoded userId from auth token:', userId);
    if (!userId) {
      console.warn('[Availability] Driver UserId could not be parsed from token.');
    }

    // Pre-populate with default schedule structure
    this.schedule = [
      { dayName: 'Monday', status: 'Unavailable', fromTime: '08:00', toTime: '16:00', slotIds: [] },
      { dayName: 'Tuesday', status: 'Unavailable', fromTime: '08:00', toTime: '16:00', slotIds: [] },
      { dayName: 'Wednesday', status: 'Unavailable', fromTime: '08:00', toTime: '16:00', slotIds: [] },
      { dayName: 'Thursday', status: 'Unavailable', fromTime: '08:00', toTime: '16:00', slotIds: [] },
      { dayName: 'Friday', status: 'Unavailable', fromTime: '08:00', toTime: '16:00', slotIds: [] },
      { dayName: 'Saturday', status: 'Unavailable', fromTime: '08:00', toTime: '16:00', slotIds: [] },
      { dayName: 'Sunday', status: 'Unavailable', fromTime: '08:00', toTime: '16:00', slotIds: [] }
    ];

    console.log('[Availability] Fetching availabilities via GET /api/DriverApp/Availabilities...');
    this.driverService.getAvailabilities().pipe(
      catchError(err => {
        console.error('[Availability] Staging API GetAvailabilities failed:', JSON.stringify(err));
        return of(null);
      })
    ).subscribe(dataResponse => {
      console.log('[Availability] Raw GET /api/DriverApp/Availabilities response:', JSON.stringify(dataResponse));
      const data = dataResponse?.drivers || dataResponse?.value?.drivers || dataResponse;
      
      if (data && Array.isArray(data)) {
        const monday = this.mondayDate;

        data.forEach((apiDay: any) => {
          if (!apiDay.date) return;
          const slotDate = this.parseLocalDate(apiDay.date);
          
          // Calculate difference in days from the selected week's Monday
          const diffTime = slotDate.getTime() - monday.getTime();
          const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24));
          
          if (diffDays >= 0 && diffDays < 7) {
            const dayItem = this.schedule[diffDays];
            if (dayItem) {
              dayItem.status = 'Available';
              if (!dayItem.slotIds) {
                dayItem.slotIds = [];
              }
              if (apiDay.id) {
                dayItem.slotIds.push(apiDay.id);
              }
              
              // Set custom times
              dayItem.fromTime = this.formatTimeSpan(apiDay.from || apiDay.fromTime);
              dayItem.toTime = this.formatTimeSpan(apiDay.to || apiDay.toTime);
            }
          }
        });
        console.log('[Availability] Mapped schedule for active week:', JSON.stringify(this.schedule));
      }
      this.cdr.detectChanges();
    });
  }

  get activeDaysCount(): number {
    return this.schedule.filter(day => day.status !== 'Unavailable').length;
  }

  get totalHours(): number {
    let total = 0;
    this.schedule.forEach(day => {
      if (day.status === 'Available' && day.fromTime && day.toTime) {
        try {
          const [fhr, fmm] = day.fromTime.split(':').map(Number);
          const [thr, tmm] = day.toTime.split(':').map(Number);
          const fromMins = fhr * 60 + fmm;
          const toMins = thr * 60 + tmm;
          if (toMins > fromMins) {
            total += (toMins - fromMins) / 60;
          }
        } catch (e) {
          // ignore
        }
      }
    });
    return Math.round(total * 10) / 10;
  }

  onStatusChange(dayIdx: number, newStatus: AvailabilityStatus): void {
    this.schedule[dayIdx].status = newStatus;
    this.saveSuccess = false;
  }

  onTimeChange(dayIdx: number, field: 'fromTime' | 'toTime', value: string): void {
    if (value) {
      this.schedule[dayIdx][field] = value;
      this.saveSuccess = false;
    }
  }

  applyPreset(preset: 'weekdays' | 'weekends'): void {
    this.saveSuccess = false;
    this.schedule.forEach((day) => {
      const isWeekend = day.dayName === 'Saturday' || day.dayName === 'Sunday';
      
      if (preset === 'weekdays' && !isWeekend) {
        day.status = 'Available';
        day.fromTime = '08:00';
        day.toTime = '16:00';
      } else if (preset === 'weekends' && isWeekend) {
        day.status = 'Available';
        day.fromTime = '16:00';
        day.toTime = '23:59';
      }
    });
    this.snackBar.open(`${preset === 'weekdays' ? 'Weekdays AM' : 'Weekends PM'} preset applied!`, 'Dismiss', {
      duration: 2000
    });
  }

  clearAll(): void {
    this.saveSuccess = false;
    const deleteIds: number[] = [];
    this.schedule.forEach(day => {
      if (day.slotIds && day.slotIds.length > 0) {
        deleteIds.push(...day.slotIds);
      }
      day.status = 'Unavailable';
      day.slotIds = [];
      day.fromTime = '08:00';
      day.toTime = '16:00';
    });

    console.log('[Availability] clearAll triggered. Slot IDs marked for deletion:', deleteIds);

    if (deleteIds.length > 0) {
      this.isSaving = true;
      const deleteObs = deleteIds.map(id => {
        console.log(`[Availability] Sending request GET /api/DriverApp/DeleteAvailability?id=${id}`);
        return this.driverService.deleteAvailability(id).pipe(
          catchError(err => {
            console.error(`[Availability] Delete failed for ID ${id}:`, err);
            return of(null);
          })
        );
      });
      forkJoin(deleteObs).subscribe(results => {
        console.log('[Availability] All deleteAvailability requests completed. Response values:', results);
        this.isSaving = false;
        this.snackBar.open('All availability for selected week cleared!', 'Dismiss', {
          duration: 2000
        });
        this.cdr.detectChanges();
      });
    } else {
      console.log('[Availability] No slots found to clear.');
      this.snackBar.open('No availability to clear on selected week.', 'Dismiss', {
        duration: 2000
      });
    }
  }

  saveAvailability(): void {
    const userId = this.getUserIdFromToken();
    console.log('[Availability] saveAvailability triggered. Target user ID:', userId);
    if (!userId) {
      this.snackBar.open('Error: User session expired or invalid.', 'Dismiss', {
        duration: 3000
      });
      return;
    }

    // Validate that for all active days, fromTime < toTime
    let validationError = '';
    this.schedule.forEach(day => {
      if (day.status === 'Available') {
        const [fhr, fmm] = day.fromTime.split(':').map(Number);
        const [thr, tmm] = day.toTime.split(':').map(Number);
        if (fhr * 60 + fmm >= thr * 60 + tmm) {
          validationError = `Invalid times for ${day.dayName}: From time must be earlier than To time.`;
        }
      }
    });

    if (validationError) {
      console.warn('[Availability] Time validation failed:', validationError);
      this.snackBar.open(validationError, 'Dismiss', {
        duration: 4000
      });
      return;
    }

    this.isSaving = true;

    // Collect all existing slots for this week to delete
    const deleteIds: number[] = [];
    this.schedule.forEach(day => {
      if (day.slotIds && day.slotIds.length > 0) {
        deleteIds.push(...day.slotIds);
      }
    });
    console.log('[Availability] Existing slots marked for cleanup before saving:', deleteIds);

    // Determine Monday of current selected week
    const monday = this.mondayDate;

    const createRequests: any[] = [];
    this.schedule.forEach((day, idx) => {
      if (day.status === 'Available') {
        const date = new Date(monday);
        date.setDate(monday.getDate() + idx);
        
        createRequests.push({
          userId,
          date: this.formatDateToLocalDateString(date),
          from: day.fromTime,
          to: day.toTime,
          type: 1
        });
      }
    });
    console.log('[Availability] New availability slots to set:', JSON.stringify(createRequests));

    const deleteObs = deleteIds.map(id => {
      console.log(`[Availability] Issuing DELETE request for slot ID ${id}`);
      return this.driverService.deleteAvailability(id).pipe(catchError(() => of(null)));
    });
    const saveObs = createRequests.map(req => {
      console.log('[Availability] Issuing POST request to SetAvailability with payload:', JSON.stringify(req));
      return this.driverService.setAvailability(req).pipe(
        catchError(err => {
          console.error('[Availability] SetAvailability request failed:', JSON.stringify(err));
          return of(null);
        })
      );
    });

    const runDeletes = deleteObs.length > 0 ? forkJoin(deleteObs) : of([]);

    runDeletes.pipe(
      switchMap(delResults => {
        if (deleteIds.length > 0) {
          console.log('[Availability] Deletions completed. Responses:', JSON.stringify(delResults));
        }
        return saveObs.length > 0 ? forkJoin(saveObs) : of([]);
      })
    ).subscribe(saveResults => {
      console.log('[Availability] All SetAvailability operations resolved. Responses:', JSON.stringify(saveResults));
      
      // Check if any operation failed (returned null)
      const failedIndices: number[] = [];
      saveResults.forEach((res, idx) => {
        if (res === null || (res && res.success === false)) {
          failedIndices.push(idx);
        }
      });

      this.isSaving = false;

      if (failedIndices.length > 0) {
        const failedDays = failedIndices.map(idx => {
          const req = createRequests[idx];
          const dateObj = new Date(req.date);
          const dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
          return dayNames[dateObj.getDay()];
        }).join(', ');
        
        console.error('[Availability] Failed to save shifts for: ' + failedDays);
        this.snackBar.open(`Error: Failed to save shifts for ${failedDays}. Check for overlaps.`, 'Dismiss', {
          duration: 5000
        });
      } else {
        this.saveSuccess = true;
        this.snackBar.open('Weekly availability saved successfully!', 'Dismiss', {
          duration: 3000
        });
      }

      this.ngOnInit();
      setTimeout(() => {
        this.saveSuccess = false;
        this.cdr.detectChanges();
      }, 3000);
    });
  }
}
