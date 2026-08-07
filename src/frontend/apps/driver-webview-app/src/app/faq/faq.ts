import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';

interface FaqItem {
  question: String;
  answer: String;
  isOpen: boolean;
}

@Component({
  selector: 'app-faq',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="webview-container">
      <header class="header">
        <h1>Driver Help & FAQs</h1>
        <p>Find answers to common questions about shifts, bookings, and payments.</p>
      </header>

      <main class="faq-list">
        <div 
          *ngFor="let item of faqs; let i = index" 
          class="faq-item" 
          [class.open]="item.isOpen"
          (click)="toggleFaq(i)"
        >
          <div class="faq-question">
            <h3>{{ item.question }}</h3>
            <span class="faq-icon"></span>
          </div>
          <div class="faq-answer">
            <p>{{ item.answer }}</p>
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
      margin-bottom: 24px;
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
    .faq-list {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .faq-item {
      background-color: var(--surface-color);
      border-radius: 12px;
      border: 1px solid var(--border-color);
      overflow: hidden;
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .faq-question {
      padding: 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .faq-question h3 {
      font-size: 16px;
      margin: 0;
      font-weight: 600;
      color: var(--text-primary);
    }
    .faq-icon {
      width: 20px;
      height: 20px;
      position: relative;
    }
    .faq-icon::before, .faq-icon::after {
      content: '';
      position: absolute;
      background-color: var(--text-secondary);
      transition: transform 0.2s ease;
    }
    .faq-icon::before {
      top: 9px;
      left: 2px;
      width: 16px;
      height: 2px;
    }
    .faq-icon::after {
      top: 2px;
      left: 9px;
      width: 2px;
      height: 16px;
    }
    .faq-item.open .faq-icon::after {
      transform: rotate(90deg);
    }
    .faq-answer {
      max-height: 0;
      overflow: hidden;
      transition: max-height 0.25s ease-out;
      padding: 0 16px;
    }
    .faq-item.open .faq-answer {
      max-height: 200px;
      padding: 0 16px 16px 16px;
      border-top: 1px solid var(--border-color);
      margin-top: 4px;
      padding-top: 12px;
    }
    .faq-answer p {
      font-size: 14px;
      line-height: 1.5;
      margin: 0;
      color: var(--text-secondary);
    }
  `]
})
export class FaqComponent {
  faqs: FaqItem[] = [
    {
      question: 'How do I accept a job?',
      answer: 'When a new job is offered, a full-screen window with a 15-second timer will show on your app. Slide the "Slide to Accept" slider at the bottom of the screen to secure the booking.',
      isOpen: false
    },
    {
      question: 'How do cash collections work?',
      answer: 'For cash bookings, the final screen will display the exact amount to collect from the passenger. Once they pay you, check the amount, and tap "Complete Trip". Do not collect cash for Card or Account bookings.',
      isOpen: false
    },
    {
      question: 'What do I do if a passenger is a no-show?',
      answer: 'Wait at least 5 minutes at the pickup address. Try calling the passenger using the "Call Customer" button. If they do not answer, call dispatch/office using the "Call Office" button before cancelling.',
      isOpen: false
    },
    {
      question: 'How do I update my expired documents?',
      answer: 'Go to the "Documents" tab on your profile page. Tap on the expired document (License, Insurance, or MOT), take a clear photo of the new document, and submit it for admin approval.',
      isOpen: false
    }
  ];

  toggleFaq(index: number): void {
    this.faqs[index].isOpen = !this.faqs[index].isOpen;
  }
}
