import { Component, OnInit, ChangeDetectorRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { CustomerService, CustomerBookingDto } from '../services/customer.service';

@Component({
  selector: 'app-activity',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './activity.html',
  styleUrl: './activity.css'
})
export class ActivityComponent implements OnInit {
  private customerService = inject(CustomerService);
  private router = inject(Router);
  private cdr = inject(ChangeDetectorRef);

  selectedTab: 'all' | 'active' | 'completed' = 'all';
  bookings: CustomerBookingDto[] = [];
  isLoading = true;
  selectedBooking: CustomerBookingDto | null = null;
  activeBooking: CustomerBookingDto | null = null;

  ngOnInit() {
    this.loadBookings();
  }

  loadBookings() {
    this.isLoading = true;
    this.customerService.getMyBookings().subscribe({
      next: (list) => {
        this.bookings = list || [];
        this.activeBooking = this.bookings.find(b => b.status !== 'completed' && b.status !== 'cancelled') || null;
        this.isLoading = false;
        this.cdr.detectChanges();
      },
      error: (err) => {
        console.warn('Live API response error loading bookings:', err);
        this.bookings = [];
        this.activeBooking = null;
        this.isLoading = false;
        this.cdr.detectChanges();
      }
    });
  }

  get activeCount(): number {
    return this.bookings.filter(b => b.status !== 'completed' && b.status !== 'cancelled').length;
  }

  get completedCount(): number {
    return this.bookings.filter(b => b.status === 'completed').length;
  }

  get totalSpent(): number {
    return this.bookings
      .filter(b => b.status === 'completed')
      .reduce((sum, b) => sum + (b.fare || 0), 0);
  }

  get filteredBookings(): CustomerBookingDto[] {
    if (this.selectedTab === 'active') {
      return this.bookings.filter(b => b.status !== 'completed' && b.status !== 'cancelled');
    }
    if (this.selectedTab === 'completed') {
      return this.bookings.filter(b => b.status === 'completed' || b.status === 'cancelled');
    }
    return this.bookings;
  }

  openBookingDetails(b: CustomerBookingDto) {
    if (b.status !== 'completed' && b.status !== 'cancelled') {
      this.router.navigate(['/active-ride']);
    } else {
      this.selectedBooking = b;
    }
  }

  closeDetails() {
    this.selectedBooking = null;
  }

  rebookTrip(b: CustomerBookingDto, event?: MouseEvent) {
    if (event) event.stopPropagation();
    this.router.navigate(['/book']);
  }

  trackRide(b: CustomerBookingDto, event?: MouseEvent) {
    if (event) event.stopPropagation();
    this.router.navigate(['/active-ride']);
  }

  openGoogleMap(address: string | undefined, event?: MouseEvent) {
    if (event) event.stopPropagation();
    if (!address) return;
    const url = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(address)}`;
    window.open(url, '_blank');
  }

  printReceipt() {
    window.print();
  }

  getStatusClass(status: string): string {
    const s = (status || '').toLowerCase();
    if (s.includes('complete') || s.includes('arrived')) return 'badge-success';
    if (s.includes('allocat') || s.includes('trip') || s.includes('progress') || s.includes('pob')) return 'badge-primary';
    if (s.includes('sent') || s.includes('request')) return 'badge-warning';
    if (s.includes('cancel') || s.includes('reject')) return 'badge-danger';
    return 'badge-neutral';
  }

  formatDate(b: CustomerBookingDto): string {
    const timeStr = b.pickupDateTime || (b as any).pickupTime;
    if (timeStr) {
      try {
        const d = new Date(timeStr);
        if (!isNaN(d.getTime())) {
          return d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
        }
      } catch (_) {}
    }
    return 'Recent Trip';
  }
}
