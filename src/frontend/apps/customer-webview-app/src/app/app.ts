import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterOutlet } from '@angular/router';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, RouterOutlet],
  templateUrl: './app.html',
  styleUrl: './app.css'
})
export class App implements OnInit, OnDestroy {
  private cdr = inject(ChangeDetectorRef);

  isOffline = !navigator.onLine;
  showRestoredBanner = false;

  private onlineHandler = () => {
    this.isOffline = false;
    this.showRestoredBanner = true;
    this.cdr.detectChanges();
    setTimeout(() => {
      this.showRestoredBanner = false;
      this.cdr.detectChanges();
    }, 3000);
  };

  private offlineHandler = () => {
    this.isOffline = true;
    this.cdr.detectChanges();
  };

  ngOnInit() {
    window.addEventListener('online', this.onlineHandler);
    window.addEventListener('offline', this.offlineHandler);
  }

  ngOnDestroy() {
    window.removeEventListener('online', this.onlineHandler);
    window.removeEventListener('offline', this.offlineHandler);
  }
}
