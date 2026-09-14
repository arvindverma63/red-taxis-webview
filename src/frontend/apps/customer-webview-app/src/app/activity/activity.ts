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

  ngOnInit() {
    this.loadBookings();
  }

  loadBookings() {
    this.isLoading = true;
    this.customerService.getMyBookings().subscribe({
      next: (list) => {
        this.bookings = list;
        this.isLoading = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.bookings = this.customerService.getMockBookings();
        this.isLoading = false;
        this.cdr.detectChanges();
      }
    });
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

  getStatusClass(status: string): string {
    const s = status.toLowerCase();
    if (s.includes('complete') || s.includes('arrived')) return 'badge-success';
    if (s.includes('allocat') || s.includes('trip') || s.includes('progress')) return 'badge-primary';
    if (s.includes('sent') || s.includes('request')) return 'badge-warning';
    if (s.includes('cancel') || s.includes('reject')) return 'badge-danger';
    return 'badge-neutral';
  }
}
