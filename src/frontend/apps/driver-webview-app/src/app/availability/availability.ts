import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonToggleModule } from '@angular/material/button-toggle';
import { MatDividerModule } from '@angular/material/divider';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
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
    MatSnackBarModule
  ],
  template: `
    <div class="material-container dark-theme">
      <!-- Header / Brand -->
      <header class="app-header">
        <h1 class="page-title">Shift Availability</h1>
        <p class="page-subtitle">Configure your weekly working schedule</p>
      </header>

      <!-- Summary & Actions -->
      <mat-card class="summary-card dark-card">
        <mat-card-content>
          <div class="summary-stats">
            <div class="stat">
              <span class="label mat-caption">Weekly Hours</span>
              <span class="value">{{ totalHours }} hrs</span>
            </div>
            <div class="stat">
              <span class="label mat-caption">Days Active</span>
              <span class="value active-highlight">{{ activeDaysCount }} / 7</span>
            </div>
          </div>

          <div class="presets-row">
            <button mat-flat-button class="preset-btn red-btn" (click)="applyPreset('weekdays')">
              Weekdays AM (08:00-16:00)
            </button>
            <button mat-flat-button class="preset-btn red-btn" (click)="applyPreset('weekends')">
              Weekends PM (16:00-23:59)
            </button>
            <button mat-stroked-button class="preset-btn clear-btn" (click)="clearAll()">
              Clear All
            </button>
          </div>
        </mat-card-content>
      </mat-card>

      <!-- Weekly Schedule List (Single Card) -->
      <main class="schedule-list-container">
        <mat-card class="schedule-card dark-card">
          <mat-card-content class="schedule-card-body">
            <div *ngFor="let day of schedule; let dayIdx = index; let last = last" class="day-row" [class.active-row]="day.status === 'Available'">
              <div class="day-info-section">
                <span class="day-label">{{ day.dayName }}</span>
              </div>
              
              <div class="controls-section">
                <!-- Status Toggle -->
                <mat-button-toggle-group 
                  [value]="day.status" 
                  (change)="onStatusChange(dayIdx, $event.value)"
                  class="toggle-group-custom"
                >
                  <mat-button-toggle value="Available" class="slot-toggle green-toggle">Active</mat-button-toggle>
                  <mat-button-toggle value="Unavailable" class="slot-toggle red-toggle">None</mat-button-toggle>
                </mat-button-toggle-group>

                <!-- Custom Time Pickers (only shown if Active) -->
                <div *ngIf="day.status === 'Available'" class="time-pickers-row animated-fade-in">
                  <div class="time-input-wrapper">
                    <span class="input-prefix">From</span>
                    <input 
                      type="time" 
                      [value]="day.fromTime" 
                      (change)="onTimeChange(dayIdx, 'fromTime', $any($event.target).value)" 
                      class="custom-time-input"
                    />
                  </div>
                  <div class="time-input-wrapper">
                    <span class="input-prefix">To</span>
                    <input 
                      type="time" 
                      [value]="day.toTime" 
                      (change)="onTimeChange(dayIdx, 'toTime', $any($event.target).value)" 
                      class="custom-time-input"
                    />
                  </div>
                </div>
              </div>
              <mat-divider *ngIf="!last" class="row-divider"></mat-divider>
            </div>
          </mat-card-content>
        </mat-card>
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
    .material-container.dark-theme {
      padding: 16px;
      padding-bottom: 96px; /* Space for sticky footer save bar */
      background-color: #121212; /* Black background */
      color: #E0E0E0;
      min-height: 100vh;
      font-family: 'Roboto', sans-serif;
    }

    .app-header {
      margin-bottom: 20px;
      text-align: center;
    }

    .page-title {
      font-size: 22px;
      font-weight: 800;
      color: #FFFFFF;
      margin: 0;
      letter-spacing: 0.5px;
      text-transform: uppercase;
      text-shadow: 0 0 10px rgba(229, 57, 53, 0.3); /* Red glow effect */
    }

    .page-subtitle {
      font-size: 12px;
      color: #8E8E93;
      margin: 4px 0 0 0;
    }

    /* Summary Card */
    .summary-card.dark-card {
      background-color: #1C1C1E; /* Very dark charcoal */
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 16px !important;
      margin-bottom: 20px;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4) !important;
    }

    .summary-stats {
      display: flex;
      justify-content: space-around;
      border-bottom: 1px solid rgba(255, 255, 255, 0.08);
      padding-bottom: 14px;
      margin-bottom: 14px;
    }

    .summary-stats .stat {
      display: flex;
      flex-direction: column;
      align-items: center;
    }

    .summary-stats .label {
      color: #8E8E93;
      font-size: 10px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.8px;
      margin-bottom: 4px;
    }

    .summary-stats .value {
      font-size: 22px;
      font-weight: 900;
      color: #FFFFFF;
    }

    .active-highlight {
      color: #E53935 !important; /* Brand red */
      text-shadow: 0 0 8px rgba(229, 57, 53, 0.4);
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
      box-shadow: 0 0 10px rgba(229, 57, 53, 0.4) !important;
    }

    .clear-btn {
      border: 1px solid rgba(255, 255, 255, 0.15) !important;
      color: #AEAEB2 !important;
      background: transparent !important;
    }
    .clear-btn:hover {
      background-color: rgba(255, 255, 255, 0.05) !important;
      color: #FFFFFF !important;
    }

    /* Weekly Schedule List inside Single Card */
    .schedule-list-container {
      margin-bottom: 20px;
    }

    .schedule-card.dark-card {
      background-color: #1C1C1E;
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 16px !important;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4) !important;
    }

    .schedule-card-body {
      padding: 0 !important;
    }

    .day-row {
      display: flex;
      flex-direction: column;
      padding: 16px;
      position: relative;
      background-color: transparent;
      transition: background-color 0.2s ease;
    }
    .day-row.active-row {
      background-color: rgba(229, 57, 53, 0.03); /* Extremely subtle red tint */
    }

    .day-info-section {
      margin-bottom: 10px;
    }

    .day-label {
      font-weight: 800;
      color: #FFFFFF;
      font-size: 14px;
      letter-spacing: 0.3px;
    }

    .controls-section {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }

    /* Toggle Group Capsule Styles */
    .toggle-group-custom {
      display: flex;
      width: 100%;
      box-shadow: none !important;
      border: 1px solid rgba(255, 255, 255, 0.12) !important;
      border-radius: 10px !important;
      overflow: hidden;
      background-color: #2C2C2E !important;
    }

    .slot-toggle {
      flex: 1;
      height: 36px;
      line-height: 36px;
      font-weight: 800;
      font-size: 12px;
      border: none !important;
      border-left: 1px solid rgba(255, 255, 255, 0.12) !important;
      color: #AEAEB2 !important;
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
      box-shadow: inset 0 0 10px rgba(0, 0, 0, 0.2);
    }
    ::ng-deep .toggle-group-custom .mat-button-toggle-checked.red-toggle {
      background-color: #3A3A3C !important; /* None color is dark grey */
    }
    ::ng-deep .toggle-group-custom .mat-button-toggle-checked .mat-button-toggle-label-content {
      color: #FFFFFF !important;
    }

    /* Time Range Picker Inputs */
    .time-pickers-row {
      display: flex;
      gap: 12px;
      align-items: center;
      justify-content: space-between;
    }

    .time-input-wrapper {
      flex: 1;
      display: flex;
      align-items: center;
      background-color: #2C2C2E;
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 8px;
      padding: 0 10px;
      height: 38px;
      transition: border-color 0.2s ease;
    }
    .time-input-wrapper:focus-within {
      border-color: #E53935;
      box-shadow: 0 0 6px rgba(229, 57, 53, 0.3);
    }

    .input-prefix {
      color: #8E8E93;
      font-size: 10px;
      font-weight: 800;
      text-transform: uppercase;
      margin-right: 8px;
      width: 32px;
      flex-shrink: 0;
    }

    .custom-time-input {
      background: transparent;
      border: none;
      color: #FFFFFF;
      font-size: 13px;
      font-weight: 700;
      width: 100%;
      outline: none;
    }

    /* Webkit time picker icon overrides */
    .custom-time-input::-webkit-calendar-picker-indicator {
      filter: invert(1) sepia(1) saturate(5) hue-rotate(320deg); /* Style time icon to be brand red */
      cursor: pointer;
    }

    .row-divider {
      position: absolute;
      bottom: 0;
      left: 16px;
      right: 16px;
      width: auto;
      border-color: rgba(255, 255, 255, 0.08) !important;
    }

    /* Sticky Footer Save Button */
    .footer-actions {
      position: fixed;
      bottom: 0;
      left: 0;
      right: 0;
      padding: 16px;
      background-color: #121212;
      border-top: 1px solid rgba(255, 255, 255, 0.08);
      z-index: 100;
      box-shadow: 0 -4px 20px rgba(0,0,0,0.5);
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
      box-shadow: 0 0 15px rgba(229, 57, 53, 0.5) !important;
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
  schedule: DayAvailability[] = [
    { dayName: 'Monday', status: 'Available', fromTime: '08:00', toTime: '16:00', slotIds: [] },
    { dayName: 'Tuesday', status: 'Available', fromTime: '08:00', toTime: '16:00', slotIds: [] },
    { dayName: 'Wednesday', status: 'Available', fromTime: '08:00', toTime: '23:59', slotIds: [] },
    { dayName: 'Thursday', status: 'Available', fromTime: '08:00', toTime: '23:59', slotIds: [] },
    { dayName: 'Friday', status: 'Available', fromTime: '16:00', toTime: '23:59', slotIds: [] },
    { dayName: 'Saturday', status: 'Unavailable', fromTime: '08:00', toTime: '16:00', slotIds: [] },
    { dayName: 'Sunday', status: 'Unavailable', fromTime: '08:00', toTime: '16:00', slotIds: [] }
  ];

  saveSuccess = false;
  isSaving = false;

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

  ngOnInit(): void {
    const userId = this.getUserIdFromToken();
    if (!userId) {
      console.warn('Driver UserId could not be parsed from token.');
    }

    this.driverService.getAvailabilities().pipe(
      catchError(err => {
        console.warn('Staging API GetAvailabilities failed, using mock data:', err);
        return of(null);
      })
    ).subscribe(dataResponse => {
      const data = dataResponse?.drivers || dataResponse?.value?.drivers || dataResponse;
      
      if (data && Array.isArray(data)) {
        // Reset all days to Unavailable and clear slotIds
        this.schedule.forEach(day => {
          day.status = 'Unavailable';
          day.slotIds = [];
        });

        // Determine Monday of the current week
        const today = new Date();
        const currentDay = today.getDay(); // 0 = Sunday, 1 = Monday, ...
        const distanceToMonday = currentDay === 0 ? -6 : 1 - currentDay;
        const monday = new Date(today);
        monday.setDate(today.getDate() + distanceToMonday);
        monday.setHours(0, 0, 0, 0);

        data.forEach((apiDay: any) => {
          if (!apiDay.date) return;
          const slotDate = new Date(apiDay.date);
          slotDate.setHours(0, 0, 0, 0);
          
          // Calculate difference in days from Monday
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
              
              // Set times
              const fromStr = apiDay.from || apiDay.fromTime || '08:00:00';
              const toStr = apiDay.to || apiDay.toTime || '16:00:00';
              dayItem.fromTime = fromStr.slice(0, 5);
              dayItem.toTime = toStr.slice(0, 5);
            }
          }
        });
        
        this.cdr.detectChanges();
      }
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

    if (deleteIds.length > 0) {
      this.isSaving = true;
      const deleteObs = deleteIds.map(id => this.driverService.deleteAvailability(id).pipe(catchError(() => of(null))));
      forkJoin(deleteObs).subscribe(() => {
        this.isSaving = false;
        this.snackBar.open('All availability cleared!', 'Dismiss', {
          duration: 2000
        });
        this.cdr.detectChanges();
      });
    } else {
      this.snackBar.open('No availability to clear.', 'Dismiss', {
        duration: 2000
      });
    }
  }

  saveAvailability(): void {
    const userId = this.getUserIdFromToken();
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
      this.snackBar.open(validationError, 'Dismiss', {
        duration: 4000
      });
      return;
    }

    this.isSaving = true;

    // Collect all existing slots to delete
    const deleteIds: number[] = [];
    this.schedule.forEach(day => {
      if (day.slotIds && day.slotIds.length > 0) {
        deleteIds.push(...day.slotIds);
      }
    });

    // Determine Monday of current week
    const today = new Date();
    const currentDay = today.getDay();
    const distanceToMonday = currentDay === 0 ? -6 : 1 - currentDay;
    const monday = new Date(today);
    monday.setDate(today.getDate() + distanceToMonday);
    monday.setHours(0, 0, 0, 0);

    const createRequests: any[] = [];
    this.schedule.forEach((day, idx) => {
      if (day.status === 'Available') {
        const date = new Date(monday);
        date.setDate(monday.getDate() + idx);
        
        createRequests.push({
          userId,
          date: date.toISOString(),
          from: day.fromTime,
          to: day.toTime,
          type: 1
        });
      }
    });

    const deleteObs = deleteIds.map(id => this.driverService.deleteAvailability(id).pipe(catchError(() => of(null))));
    const saveObs = createRequests.map(req => this.driverService.setAvailability(req).pipe(catchError(() => of(null))));

    const runDeletes = deleteObs.length > 0 ? forkJoin(deleteObs) : of([]);

    runDeletes.pipe(
      switchMap(() => {
        return saveObs.length > 0 ? forkJoin(saveObs) : of([]);
      })
    ).subscribe(() => {
      this.isSaving = false;
      this.saveSuccess = true;
      this.snackBar.open('Weekly availability saved successfully!', 'Dismiss', {
        duration: 3000
      });
      this.ngOnInit();
      setTimeout(() => {
        this.saveSuccess = false;
        this.cdr.detectChanges();
      }, 3000);
    });
  }
}
