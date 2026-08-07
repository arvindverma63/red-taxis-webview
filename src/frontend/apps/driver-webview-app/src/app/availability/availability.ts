import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonToggleModule } from '@angular/material/button-toggle';
import { MatDividerModule } from '@angular/material/divider';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';

interface ShiftSlot {
  name: 'AM' | 'PM' | 'Night';
  time: string;
  available: boolean;
}

interface DayAvailability {
  dayName: string;
  slots: ShiftSlot[];
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
      <header class="header">
        <h1 class="mat-headline-medium">Weekly Availability</h1>
        <p class="mat-body-medium">Set your working hours for the upcoming week.</p>
      </header>

      <!-- Summary & Actions -->
      <mat-card class="summary-card">
        <mat-card-content>
          <div class="summary-stats">
            <div class="stat">
              <span class="label mat-caption">Weekly Hours</span>
              <span class="value">{{ totalHours }} hrs</span>
            </div>
            <div class="stat">
              <span class="label mat-caption">Shifts Booked</span>
              <span class="value">{{ activeShiftsCount }} / 21</span>
            </div>
          </div>

          <div class="presets-row">
            <button mat-flat-button color="accent" class="preset-btn" (click)="applyPreset('weekdays')">
              Weekdays AM
            </button>
            <button mat-flat-button color="accent" class="preset-btn" (click)="applyPreset('weekends')">
              Weekends PM
            </button>
            <button mat-stroked-button class="preset-btn" (click)="clearAll()">
              Clear All
            </button>
          </div>
        </mat-card-content>
      </mat-card>

      <!-- Weekly Schedule Grid -->
      <main class="schedule-grid">
        <mat-card *ngFor="let day of schedule; let dayIdx = index" class="day-card">
          <mat-card-content class="day-card-content">
            <span class="day-label mat-subtitle-1">{{ day.dayName }}</span>
            
            <div class="slots-container">
              <mat-button-toggle-group multiple class="toggle-group-custom">
                <mat-button-toggle 
                  *ngFor="let slot of day.slots; let slotIdx = index" 
                  [checked]="slot.available"
                  (change)="onToggleChange(dayIdx, slotIdx, $event.source.checked)"
                  class="slot-toggle"
                >
                  <div class="slot-label-wrapper">
                    <span class="slot-name">{{ slot.name }}</span>
                    <span class="slot-time">{{ slot.time }}</span>
                  </div>
                </mat-button-toggle>
              </mat-button-toggle-group>
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
    }
    .header {
      margin-bottom: 16px;
    }
    .header h1 {
      margin: 0 0 4px 0;
      font-weight: 700;
      color: var(--text-primary);
    }
    .header p {
      margin: 0;
      color: var(--text-secondary);
    }

    /* Summary Card */
    .summary-card {
      border: 1px solid var(--border-color);
      box-shadow: none !important;
      border-radius: 12px !important;
      margin-bottom: 20px;
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
      font-weight: bold;
    }

    /* Schedule List */
    .schedule-grid {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .day-card {
      border: 1px solid var(--border-color);
      box-shadow: none !important;
      border-radius: 12px !important;
    }
    .day-card-content {
      padding: 12px 16px !important;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .day-label {
      font-weight: 700;
      color: var(--text-primary);
    }
    
    .slots-container {
      width: 100%;
    }
    
    .toggle-group-custom {
      display: flex;
      width: 100%;
      box-shadow: none !important;
      border: none !important;
      gap: 8px;
    }
    
    .slot-toggle {
      flex: 1;
      border: 1px solid var(--border-color) !important;
      border-radius: 8px !important;
      background-color: var(--surface-color);
      height: 48px;
    }
    
    .mat-button-toggle-checked {
      background-color: rgba(76, 175, 80, 0.08) !important;
      border-color: #4CAF50 !important;
      color: #388E3C !important;
    }
    
    .slot-label-wrapper {
      display: flex;
      flex-direction: column;
      align-items: center;
      line-height: 1.2;
      padding: 4px 0;
    }
    .slot-name {
      font-size: 12px;
      font-weight: bold;
    }
    .slot-time {
      font-size: 9px;
      opacity: 0.8;
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
    {
      dayName: 'Monday',
      slots: [
        { name: 'AM', time: '06:00-14:00', available: true },
        { name: 'PM', time: '14:00-22:00', available: false },
        { name: 'Night', time: '22:00-06:00', available: false }
      ]
    },
    {
      dayName: 'Tuesday',
      slots: [
        { name: 'AM', time: '06:00-14:00', available: true },
        { name: 'PM', time: '14:00-22:00', available: false },
        { name: 'Night', time: '22:00-06:00', available: false }
      ]
    },
    {
      dayName: 'Wednesday',
      slots: [
        { name: 'AM', time: '06:00-14:00', available: true },
        { name: 'PM', time: '14:00-22:00', available: true },
        { name: 'Night', time: '22:00-06:00', available: false }
      ]
    },
    {
      dayName: 'Thursday',
      slots: [
        { name: 'AM', time: '06:00-14:00', available: true },
        { name: 'PM', time: '14:00-22:00', available: true },
        { name: 'Night', time: '22:00-06:00', available: false }
      ]
    },
    {
      dayName: 'Friday',
      slots: [
        { name: 'AM', time: '06:00-14:00', available: false },
        { name: 'PM', time: '14:00-22:00', available: true },
        { name: 'Night', time: '22:00-06:00', available: true }
      ]
    },
    {
      dayName: 'Saturday',
      slots: [
        { name: 'AM', time: '06:00-14:00', available: false },
        { name: 'PM', time: '14:00-22:00', available: false },
        { name: 'Night', time: '22:00-06:00', available: true }
      ]
    },
    {
      dayName: 'Sunday',
      slots: [
        { name: 'AM', time: '06:00-14:00', available: false },
        { name: 'PM', time: '14:00-22:00', available: false },
        { name: 'Night', time: '22:00-06:00', available: false }
      ]
    }
  ];

  saveSuccess = false;

  constructor(private snackBar: MatSnackBar) {}

  get activeShiftsCount(): number {
    let count = 0;
    this.schedule.forEach(day => {
      day.slots.forEach(slot => {
        if (slot.available) count++;
      });
    });
    return count;
  }

  get totalHours(): number {
    return this.activeShiftsCount * 8;
  }

  onToggleChange(dayIdx: number, slotIdx: number, checked: boolean): void {
    this.schedule[dayIdx].slots[slotIdx].available = checked;
    this.saveSuccess = false;
  }

  applyPreset(preset: 'weekdays' | 'weekends'): void {
    this.saveSuccess = false;
    this.schedule.forEach((day, index) => {
      const isWeekend = day.dayName === 'Saturday' || day.dayName === 'Sunday';
      
      if (preset === 'weekdays' && !isWeekend) {
        day.slots[0].available = true;
      } else if (preset === 'weekends' && isWeekend) {
        day.slots[1].available = true;
      }
    });
    this.snackBar.open(`${preset === 'weekdays' ? 'Weekdays AM' : 'Weekends PM'} preset applied!`, 'Dismiss', {
      duration: 2000
    });
  }

  clearAll(): void {
    this.saveSuccess = false;
    this.schedule.forEach(day => {
      day.slots.forEach(slot => {
        slot.available = false;
      });
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
