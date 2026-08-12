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

type AvailabilityStatus = 'AM' | 'PM' | 'Both' | 'Unavailable';

interface DayAvailability {
  dayName: string;
  status: AvailabilityStatus;
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
    <div class="material-container">
      <!-- Summary & Actions -->
      <mat-card class="summary-card">
        <mat-card-content>
          <div class="summary-stats">
            <div class="stat">
              <span class="label mat-caption">Weekly Hours</span>
              <span class="value">{{ totalHours }} hrs</span>
            </div>
            <div class="stat">
              <span class="label mat-caption">Days Active</span>
              <span class="value">{{ activeDaysCount }} / 7</span>
            </div>
          </div>

          <div class="presets-row">
            <button mat-flat-button color="primary" class="preset-btn" (click)="applyPreset('weekdays')">
              Weekdays AM
            </button>
            <button mat-flat-button color="primary" class="preset-btn" (click)="applyPreset('weekends')">
              Weekends PM
            </button>
            <button mat-stroked-button class="preset-btn clear-btn" (click)="clearAll()">
              Clear All
            </button>
          </div>
        </mat-card-content>
      </mat-card>

      <!-- Weekly Schedule List (Single Card) -->
      <main class="schedule-list-container">
        <mat-card class="schedule-card">
          <mat-card-content class="schedule-card-body">
            <div *ngFor="let day of schedule; let dayIdx = index; let last = last" class="day-row">
              <div class="day-info">
                <span class="day-label">{{ day.dayName }}</span>
              </div>
              
              <div class="slots-container">
                <mat-button-toggle-group 
                  [value]="day.status" 
                  (change)="onStatusChange(dayIdx, $event.value)"
                  class="toggle-group-custom"
                >
                  <mat-button-toggle value="AM" class="slot-toggle">AM</mat-button-toggle>
                  <mat-button-toggle value="PM" class="slot-toggle">PM</mat-button-toggle>
                  <mat-button-toggle value="Both" class="slot-toggle">Both</mat-button-toggle>
                  <mat-button-toggle value="Unavailable" class="slot-toggle red-toggle">None</mat-button-toggle>
                </mat-button-toggle-group>
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
          color="primary" 
          class="save-btn" 
          [class.success]="saveSuccess"
          [disabled]="isSaving"
          (click)="saveAvailability()"
        >
          <mat-icon>{{ saveSuccess ? 'check' : 'save' }}</mat-icon>
          {{ isSaving ? 'Saving...' : saveSuccess ? 'Saved Successfully' : 'Save Availability' }}
        </button>
      </footer>
    </div>
  `,
  styles: [`
    .material-container {
      padding: 16px;
      padding-bottom: 88px; /* Space for sticky save button */
      background-color: var(--background-color);
      min-height: 100vh;
      font-family: 'Roboto', sans-serif;
    }

    /* Summary Card */
    .summary-card {
      border: 1px solid var(--border-color);
      box-shadow: 0 1px 3px rgba(0,0,0,0.02) !important;
      border-radius: 12px !important;
      margin-bottom: 16px;
    }
    .summary-stats {
      display: flex;
      justify-content: space-around;
      border-bottom: 1px solid var(--border-color);
      padding-bottom: 12px;
      margin-bottom: 12px;
    }
    .summary-stats .stat {
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
    }
    .summary-stats .label {
      color: var(--text-secondary);
      margin-bottom: 4px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .summary-stats .value {
      font-size: 20px;
      font-weight: 800;
      color: var(--text-primary);
    }
    .presets-row {
      display: flex;
      gap: 8px;
    }
    .preset-btn {
      flex: 1;
      font-size: 11px !important;
      font-weight: 700 !important;
      border-radius: 6px !important;
      height: 36px;
    }
    .clear-btn {
      border-color: var(--border-color) !important;
      color: var(--text-secondary) !important;
    }

    /* Weekly Schedule List inside Single Card */
    .schedule-list-container {
      margin-bottom: 16px;
    }
    .schedule-card {
      border: 1px solid var(--border-color);
      box-shadow: 0 1px 3px rgba(0,0,0,0.02) !important;
      border-radius: 12px !important;
      background-color: var(--surface-color);
    }
    .schedule-card-body {
      padding: 4px 0 !important;
    }
    .day-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 10px 16px;
      position: relative;
    }
    .day-info {
      flex: 1;
      padding-right: 12px;
    }
    .day-label {
      font-weight: 700;
      color: var(--text-primary);
      font-size: 13px;
    }
    
    .slots-container {
      width: 220px;
      flex-shrink: 0;
    }
    
    /* Toggle Group Capsule Styles */
    .toggle-group-custom {
      display: flex;
      width: 100%;
      box-shadow: none !important;
      border: 1px solid var(--border-color) !important;
      border-radius: 20px !important;
      overflow: hidden;
      background-color: #F8F9FA;
    }
    
    .slot-toggle {
      flex: 1;
      height: 32px;
      line-height: 32px;
      font-weight: 700;
      font-size: 11px;
      border: none !important;
      border-left: 1px solid var(--border-color) !important;
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
      background-color: var(--primary-color) !important;
      color: #FFFFFF !important;
    }
    ::ng-deep .toggle-group-custom .mat-button-toggle-checked.red-toggle {
      background-color: #E53935 !important;
      color: #FFFFFF !important;
    }
    ::ng-deep .toggle-group-custom .mat-button-toggle-checked .mat-button-toggle-label-content {
      color: #FFFFFF !important;
    }
    
    .row-divider {
      position: absolute;
      bottom: 0;
      left: 16px;
      right: 16px;
      width: auto;
    }

    /* Sticky Footer Save Button */
    .footer-actions {
      position: fixed;
      bottom: 0;
      left: 0;
      right: 0;
      padding: 16px;
      background-color: var(--background-color);
      border-top: 1px solid var(--border-color);
      z-index: 100;
    }
    .save-btn {
      width: 100%;
      height: 48px;
      border-radius: 8px !important;
      font-size: 14px !important;
      font-weight: bold !important;
    }
    .save-btn.success {
      background: #4CAF50 !important;
      color: #FFFFFF !important;
    }
  `]
})
export class AvailabilityComponent implements OnInit {
  schedule: DayAvailability[] = [
    { dayName: 'Monday', status: 'AM', slotIds: [] },
    { dayName: 'Tuesday', status: 'AM', slotIds: [] },
    { dayName: 'Wednesday', status: 'Both', slotIds: [] },
    { dayName: 'Thursday', status: 'Both', slotIds: [] },
    { dayName: 'Friday', status: 'PM', slotIds: [] },
    { dayName: 'Saturday', status: 'Unavailable', slotIds: [] },
    { dayName: 'Sunday', status: 'Unavailable', slotIds: [] }
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
              if (!dayItem.slotIds) {
                dayItem.slotIds = [];
              }
              if (apiDay.id) {
                dayItem.slotIds.push(apiDay.id);
              }

              // Determine status based on times
              const fromStr = apiDay.from || apiDay.fromTime || '';
              const toStr = apiDay.to || apiDay.toTime || '';
              const isAm = fromStr.startsWith('08:');
              const isPm = fromStr.startsWith('16:') || toStr.startsWith('23:59') || toStr.startsWith('24:');
              
              if (dayItem.status === 'Unavailable') {
                if (isAm && toStr.startsWith('16:')) {
                  dayItem.status = 'AM';
                } else if (fromStr.startsWith('16:') && (toStr.startsWith('23:59') || toStr.startsWith('24:') || toStr.startsWith('00:00'))) {
                  dayItem.status = 'PM';
                } else if (isAm && (toStr.startsWith('23:59') || toStr.startsWith('24:') || toStr.startsWith('00:00'))) {
                  dayItem.status = 'Both';
                } else {
                  dayItem.status = 'AM';
                }
              } else if (dayItem.status === 'AM' && isPm) {
                dayItem.status = 'Both';
              } else if (dayItem.status === 'PM' && isAm) {
                dayItem.status = 'Both';
              }
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
      if (day.status === 'AM' || day.status === 'PM') {
        total += 8;
      } else if (day.status === 'Both') {
        total += 16;
      }
    });
    return total;
  }

  onStatusChange(dayIdx: number, newStatus: AvailabilityStatus): void {
    this.schedule[dayIdx].status = newStatus;
    this.saveSuccess = false;
  }

  applyPreset(preset: 'weekdays' | 'weekends'): void {
    this.saveSuccess = false;
    this.schedule.forEach((day) => {
      const isWeekend = day.dayName === 'Saturday' || day.dayName === 'Sunday';
      
      if (preset === 'weekdays' && !isWeekend) {
        day.status = 'AM';
      } else if (preset === 'weekends' && isWeekend) {
        day.status = 'PM';
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
      if (day.status !== 'Unavailable') {
        const date = new Date(monday);
        date.setDate(monday.getDate() + idx);
        
        if (day.status === 'AM') {
          createRequests.push({
            userId,
            date: date.toISOString(),
            from: '08:00',
            to: '16:00',
            type: 1
          });
        } else if (day.status === 'PM') {
          createRequests.push({
            userId,
            date: date.toISOString(),
            from: '16:00',
            to: '23:59',
            type: 1
          });
        } else if (day.status === 'Both') {
          createRequests.push({
            userId,
            date: date.toISOString(),
            from: '08:00',
            to: '23:59',
            type: 1
          });
        }
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
