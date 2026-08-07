import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonToggleModule } from '@angular/material/button-toggle';
import { MatDividerModule } from '@angular/material/divider';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';

type AvailabilityStatus = 'AM' | 'PM' | 'Both' | 'Unavailable';

interface DayAvailability {
  dayName: string;
  status: AvailabilityStatus;
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
          (click)="saveAvailability()"
        >
          <mat-icon>{{ saveSuccess ? 'check' : 'save' }}</mat-icon>
          {{ saveSuccess ? 'Saved Successfully' : 'Save Availability' }}
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
export class AvailabilityComponent {
  schedule: DayAvailability[] = [
    { dayName: 'Monday', status: 'AM' },
    { dayName: 'Tuesday', status: 'AM' },
    { dayName: 'Wednesday', status: 'Both' },
    { dayName: 'Thursday', status: 'Both' },
    { dayName: 'Friday', status: 'PM' },
    { dayName: 'Saturday', status: 'Unavailable' },
    { dayName: 'Sunday', status: 'Unavailable' }
  ];

  saveSuccess = false;

  constructor(private snackBar: MatSnackBar) {}

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
    this.schedule.forEach(day => {
      day.status = 'Unavailable';
    });
    this.snackBar.open('All availability cleared!', 'Dismiss', {
      duration: 2000
    });
  }

  saveAvailability(): void {
    this.saveSuccess = true;
    this.snackBar.open('Weekly availability saved successfully!', 'Dismiss', {
      duration: 3000
    });
    setTimeout(() => {
      this.saveSuccess = false;
    }, 3000);
  }
}
