import { Component, signal, OnInit, OnDestroy } from '@angular/core';
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
  protected readonly title = signal('driver-webview-app');
  protected isOffline = signal(typeof navigator !== 'undefined' ? !navigator.onLine : false);
  protected showOnlineToast = signal(false);

  private onlineListener = () => {
    this.isOffline.set(false);
    this.showOnlineToast.set(true);
    setTimeout(() => {
      this.showOnlineToast.set(false);
    }, 3000);
  };

  private offlineListener = () => {
    this.isOffline.set(true);
    this.showOnlineToast.set(false);
  };

  ngOnInit() {
    if (typeof window !== 'undefined') {
      window.addEventListener('online', this.onlineListener);
      window.addEventListener('offline', this.offlineListener);
    }
  }

  ngOnDestroy() {
    if (typeof window !== 'undefined') {
      window.removeEventListener('online', this.onlineListener);
      window.removeEventListener('offline', this.offlineListener);
    }
  }
}
