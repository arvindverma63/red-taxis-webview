import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';

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
  imports: [CommonModule],
  template: `
    <div class="webview-container">
      <header class="header">
        <h1>Weekly Availability</h1>
        <p>Set your working hours for the upcoming week.</p>
      </header>

      <!-- Summary & Actions -->
      <div class="summary-card">
        <div class="summary-stats">
          <div class="stat">
            <span class="label">Weekly Hours</span>
            <span class="value">{{ totalHours }} hrs</span>
          </div>
          <div class="stat">
            <span class="label">Shifts Booked</span>
            <span class="value">{{ activeShiftsCount }} / 21</span>
          </div>
        </div>

        <div class="presets-row">
          <button class="preset-btn" (click)="applyPreset('weekdays')">Weekdays AM</button>
          <button class="preset-btn" (click)="applyPreset('weekends')">Weekends PM</button>
          <button class="preset-btn outline" (click)="clearAll()">Clear All</button>
        </div>
      </div>

      <!-- Weekly Schedule Grid -->
      <main class="schedule-grid">
        <div *ngFor="let day of schedule; let dayIdx = index" class="day-card">
          <span class="day-label">{{ day.dayName }}</span>
          
          <div class="slots-container">
            <button 
              *ngFor="let slot of day.slots; let slotIdx = index" 
              class="slot-bubble"
              [class.active]="slot.available"
              (click)="toggleSlot(dayIdx, slotIdx)"
            >
              <span class="slot-name">{{ slot.name }}</span>
              <span class="slot-time">{{ slot.time }}</span>
            </button>
          </div>
        </div>
      </main>

      <!-- Save Button with click reaction -->
      <footer class="footer-actions">
        <button 
          class="save-btn" 
          [class.success]="saveSuccess"
          (click)="saveAvailability()"
        >
          {{ saveSuccess ? '✓ Saved Successfully' : 'Save Availability' }}
        </button>
      </footer>
    </div>
  `,
  styles: [`
    .webview-container {
      padding: 16px;
      padding-bottom: 80px; /* Space for sticky footer save button */
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    }
    .header {
      margin-bottom: 20px;
    }
    .header h1 {
      font-size: 24px;
      margin: 0 0 6px 0;
      color: var(--text-primary);
    }
    .header p {
      font-size: 14px;
      margin: 0;
      color: var(--text-secondary);
    }

    /* Summary Card */
    .summary-card {
      background-color: var(--surface-color);
      border: 1px solid var(--border-color);
      border-radius: 16px;
      padding: 16px;
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
      font-size: 11px;
      color: var(--text-secondary);
      margin-bottom: 4px;
    }
    .summary-stats .value {
      font-size: 18px;
      font-weight: 800;
      color: var(--text-primary);
    }
    .presets-row {
      display: flex;
      gap: 8px;
    }
    .preset-btn {
      flex: 1;
      border: none;
      background-color: rgba(229, 57, 85, 0.08);
      color: var(--primary-color);
      font-size: 11px;
      font-weight: 700;
      padding: 8px 6px;
      border-radius: 8px;
      cursor: pointer;
      transition: all 0.2s ease;
      text-align: center;
    }
    .preset-btn:hover {
      background-color: var(--primary-color);
      color: #FFFFFF;
    }
    .preset-btn.outline {
      background: none;
      border: 1px solid var(--border-color);
      color: var(--text-secondary);
    }
    .preset-btn.outline:hover {
      background-color: rgba(0,0,0,0.03);
      color: var(--text-primary);
    }
    @media(prefers-color-scheme: dark) {
      .preset-btn.outline:hover {
        background-color: rgba(255,255,255,0.03);
      }
    }

    /* Schedule List */
    .schedule-grid {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .day-card {
      background-color: var(--surface-color);
      border: 1px solid var(--border-color);
      border-radius: 16px;
      padding: 14px 16px;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .day-label {
      font-size: 14px;
      font-weight: 700;
      color: var(--text-primary);
    }
    .slots-container {
      display: flex;
      gap: 8px;
    }
    .slot-bubble {
      flex: 1;
      border: 1px solid var(--border-color);
      background-color: var(--surface-color);
      padding: 10px 4px;
      border-radius: 10px;
      display: flex;
      flex-direction: column;
      align-items: center;
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .slot-name {
      font-size: 12px;
      font-weight: bold;
      color: var(--text-primary);
      margin-bottom: 2px;
    }
    .slot-time {
      font-size: 9px;
      color: var(--text-secondary);
    }
    
    .slot-bubble.active {
      background-color: rgba(76, 175, 80, 0.08);
      border-color: #4CAF50;
    }
    .slot-bubble.active .slot-name {
      color: #4CAF50;
    }
    .slot-bubble.active .slot-time {
      color: #388E3C;
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
      border: none;
      background: linear-gradient(135deg, var(--primary-color) 0%, var(--primary-dark) 100%);
      color: #FFFFFF;
      font-size: 15px;
      font-weight: 700;
      padding: 14px;
      border-radius: 12px;
      cursor: pointer;
      box-shadow: 0 4px 12px rgba(229, 57, 85, 0.2);
      transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
    }
    .save-btn:active {
      transform: scale(0.98);
    }
    .save-btn.success {
      background: linear-gradient(135deg, #4CAF50 0%, #388E3C 100%);
      box-shadow: 0 4px 12px rgba(76, 175, 80, 0.2);
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
    return this.activeShiftsCount * 8; // Each shift is 8 hours
  }

  toggleSlot(dayIdx: number, slotIdx: number): void {
    this.schedule[dayIdx].slots[slotIdx].available = !this.schedule[dayIdx].slots[slotIdx].available;
    this.saveSuccess = false; // Reset success state on edit
  }

  applyPreset(preset: 'weekdays' | 'weekends'): void {
    this.saveSuccess = false;
    this.schedule.forEach((day, index) => {
      const isWeekend = day.dayName === 'Saturday' || day.dayName === 'Sunday';
      
      if (preset === 'weekdays' && !isWeekend) {
        day.slots[0].available = true; // Set AM available
      } else if (preset === 'weekends' && isWeekend) {
        day.slots[1].available = true; // Set PM available
      }
    });
  }

  clearAll(): void {
    this.saveSuccess = false;
    this.schedule.forEach(day => {
      day.slots.forEach(slot => {
        slot.available = false;
      });
    });
  }

  saveAvailability(): void {
    this.saveSuccess = true;
    setTimeout(() => {
      this.saveSuccess = false;
    }, 3000);
  }
}
