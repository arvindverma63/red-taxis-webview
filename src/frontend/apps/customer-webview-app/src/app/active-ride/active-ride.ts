import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { CustomerService, CustomerBookingDto } from '../services/customer.service';

@Component({
  selector: 'app-active-ride',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './active-ride.html',
  styleUrl: './active-ride.css'
})
export class ActiveRideComponent implements OnInit, OnDestroy {
  private customerService = inject(CustomerService);
  private router = inject(Router);
  private cdr = inject(ChangeDetectorRef);

  activeBooking: CustomerBookingDto | null = null;
  isLoading = true;
  isCancelling = false;
  private pollInterval: any;

  ngOnInit() {
    this.loadActiveRide();
    // Poll active ride status every 10 seconds
    this.pollInterval = setInterval(() => this.loadActiveRide(false), 10000);
  }

  ngOnDestroy() {
    if (this.pollInterval) clearInterval(this.pollInterval);
  }

  loadActiveRide(showLoader: boolean = true) {
    if (showLoader) this.isLoading = true;

    this.customerService.getMyBookings().subscribe({
      next: (list) => {
        const active = list.find(b => b.status !== 'completed' && b.status !== 'cancelled');
        this.activeBooking = active || null;
        this.isLoading = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.activeBooking = null;
        this.isLoading = false;
        this.cdr.detectChanges();
      }
    });
  }

  callDriver() {
    if (this.activeBooking?.driverPhone) {
      window.location.href = `tel:${this.activeBooking.driverPhone}`;
    }
  }

  callOffice() {
    window.location.href = 'tel:01234567890';
  }

  cancelRide() {
    if (!this.activeBooking) return;
    if (confirm('Are you sure you want to cancel this booking?')) {
      this.isCancelling = true;
      this.customerService.cancelBooking(this.activeBooking.id).subscribe({
        next: () => {
          this.isCancelling = false;
          this.router.navigate(['/activity']);
        },
        error: () => {
          this.isCancelling = false;
          this.router.navigate(['/activity']);
        }
      });
    }
  }

  goToBook() {
    this.router.navigate(['/book']);
  }
}
