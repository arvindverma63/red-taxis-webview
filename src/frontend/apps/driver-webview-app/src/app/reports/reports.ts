import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';

interface EarningsDay {
  day: string;
  amount: number;
  percentage: number; // For rendering height in the bar chart
}

@Component({
  selector: 'app-reports',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="webview-container">
      <header class="header">
        <h1>Weekly Earnings Report</h1>
        <p>Overview of your metrics from Monday to Sunday.</p>
      </header>

      <main class="reports-content">
        <!-- Key Metrics Cards -->
        <div class="metrics-grid">
          <div class="metric-card">
            <span class="label">Total Revenue</span>
            <span class="value font-green">£{{ totalEarnings.toFixed(2) }}</span>
          </div>
          <div class="metric-card">
            <span class="label">Completed Jobs</span>
            <span class="value">{{ completedJobs }}</span>
          </div>
          <div class="metric-card">
            <span class="label">Average per Job</span>
            <span class="value">£{{ avgPerJob.toFixed(2) }}</span>
          </div>
        </div>

        <!-- Custom CSS Chart -->
        <div class="chart-section">
          <h2>Daily Breakdown</h2>
          <div class="chart-container">
            <div class="chart-y-axis">
              <span>£100</span>
              <span>£50</span>
              <span>£0</span>
            </div>
            <div class="chart-bars">
              <div *ngFor="let item of weeklyData" class="chart-column">
                <div class="bar-wrapper">
                  <div class="bar-tooltip">£{{ item.amount }}</div>
                  <div 
                    class="bar-fill" 
                    [style.height.%]="item.percentage"
                  ></div>
                </div>
                <span class="bar-label">{{ item.day }}</span>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  `,
  styles: [`
    .webview-container {
      padding: 16px;
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
    .metrics-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 10px;
      margin-bottom: 24px;
    }
    .metric-card {
      background-color: var(--surface-color);
      border: 1px solid var(--border-color);
      border-radius: 12px;
      padding: 12px;
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
    }
    .metric-card .label {
      font-size: 11px;
      color: var(--text-secondary);
      margin-bottom: 6px;
      font-weight: 500;
    }
    .metric-card .value {
      font-size: 16px;
      font-weight: bold;
      color: var(--text-primary);
    }
    .font-green {
      color: #4CAF50 !important;
    }
    .chart-section {
      background-color: var(--surface-color);
      border: 1px solid var(--border-color);
      border-radius: 16px;
      padding: 16px;
    }
    .chart-section h2 {
      font-size: 16px;
      margin: 0 0 16px 0;
      color: var(--text-primary);
      font-weight: 600;
    }
    .chart-container {
      display: flex;
      height: 180px;
      position: relative;
      padding-top: 20px;
    }
    .chart-y-axis {
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      color: var(--text-secondary);
      font-size: 11px;
      padding-right: 12px;
      border-right: 1px solid var(--border-color);
      padding-bottom: 20px;
    }
    .chart-bars {
      display: flex;
      flex: 1;
      justify-content: space-around;
      align-items: flex-end;
      padding-left: 8px;
    }
    .chart-column {
      display: flex;
      flex-direction: column;
      align-items: center;
      flex: 1;
      height: 100%;
      justify-content: flex-end;
    }
    .bar-wrapper {
      width: 16px;
      height: 100%;
      background-color: var(--border-color);
      border-radius: 8px 8px 0 0;
      display: flex;
      align-items: flex-end;
      position: relative;
      margin-bottom: 6px;
      cursor: pointer;
    }
    .bar-fill {
      width: 100%;
      background-color: var(--primary-color);
      border-radius: 8px 8px 0 0;
      transition: height 0.3s ease;
    }
    .bar-label {
      font-size: 11px;
      color: var(--text-secondary);
      font-weight: 500;
    }
    .bar-tooltip {
      position: absolute;
      top: -24px;
      left: 50%;
      transform: translateX(-50%);
      background-color: var(--text-primary);
      color: var(--surface-color);
      font-size: 10px;
      padding: 4px 6px;
      border-radius: 4px;
      font-weight: bold;
      opacity: 0;
      pointer-events: none;
      transition: opacity 0.15s ease;
      white-space: nowrap;
    }
    .bar-wrapper:hover .bar-tooltip {
      opacity: 1;
    }
  `]
})
export class ReportsComponent {
  totalEarnings = 345.50;
  completedJobs = 18;
  avgPerJob = 19.19;

  weeklyData: EarningsDay[] = [
    { day: 'Mon', amount: 45.00, percentage: 45 },
    { day: 'Tue', amount: 65.00, percentage: 65 },
    { day: 'Wed', amount: 30.00, percentage: 30 },
    { day: 'Thu', amount: 85.00, percentage: 85 },
    { day: 'Fri', amount: 100.00, percentage: 100 },
    { day: 'Sat', amount: 120.00, percentage: 100 }, // Max height bounds at 100%
    { day: 'Sun', amount: 0.00, percentage: 0 }
  ];
}
