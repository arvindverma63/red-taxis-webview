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
  showSafetyModal = false;
  toastMessage: string | null = null;
  driverRating = 4.97;
  driverTripsCount = 1420;
  private pollInterval: any;
  private toastTimeout: any;

  ngOnInit() {
    this.loadActiveRide();
    // Poll active ride status every 10 seconds
    this.pollInterval = setInterval(() => this.loadActiveRide(false), 10000);
  }

  ngOnDestroy() {
    if (this.pollInterval) clearInterval(this.pollInterval);
    if (this.toastTimeout) clearTimeout(this.toastTimeout);
  }

  loadActiveRide(showLoader: boolean = true) {
    if (showLoader) this.isLoading = true;

    this.customerService.getMyBookings().subscribe({
      next: (list) => {
        const active = (list || []).find(b => b.status !== 'completed' && b.status !== 'cancelled');
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

  getStepStatus(stepIndex: number): 'completed' | 'active' | 'upcoming' {
    if (!this.activeBooking) return 'upcoming';
    const status = (this.activeBooking.status || '').toLowerCase();
    
    // Step 0: Ride Confirmed & Dispatched
    // Step 1: Driver Allocated & En Route
    // Step 2: Driver Arrived at Pickup
    // Step 3: On Trip to Destination

    let currentStep = 0;
    if (status.includes('allocat') || status.includes('en_route') || status.includes('dispatch')) {
      currentStep = 1;
    } else if (status.includes('arrived') || status.includes('wait')) {
      currentStep = 2;
    } else if (status.includes('trip') || status.includes('progress') || status.includes('pob')) {
      currentStep = 3;
    }

    if (stepIndex < currentStep) return 'completed';
    if (stepIndex === currentStep) return 'active';
    return 'upcoming';
  }

  callDriver() {
    if (this.activeBooking?.driverPhone) {
      window.location.href = `tel:${this.activeBooking.driverPhone}`;
    } else {
      this.callOffice();
    }
  }

  messageDriver() {
    if (this.activeBooking?.driverPhone) {
      window.location.href = `sms:${this.activeBooking.driverPhone}`;
    } else {
      this.showToast('Driver mobile number not available yet.');
    }
  }

  callOffice() {
    window.location.href = 'tel:01234567890';
  }

  openGoogleMap(address: string | undefined) {
    if (!address) return;
    const url = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(address)}`;
    window.open(url, '_blank');
  }

  shareTrip() {
    if (!this.activeBooking) return;
    const shareText = `Tracking my Red Taxis ride #${this.activeBooking.id} to ${this.activeBooking.dropoffAddress}. Driver: ${this.activeBooking.driverName || 'Ace Driver'} (${this.activeBooking.vehicleReg || 'Taxi'}).`;
    
    if (navigator.share) {
      navigator.share({
        title: 'My Live Taxi Ride',
        text: shareText,
        url: window.location.href,
      }).catch(() => {
        this.copyToClipboard(shareText);
      });
    } else {
      this.copyToClipboard(shareText);
    }
  }

  private copyToClipboard(text: string) {
    if (navigator.clipboard) {
      navigator.clipboard.writeText(text).then(() => {
        this.showToast('Ride details copied to clipboard!');
      });
    } else {
      this.showToast('Live tracking active');
    }
  }

  toggleSafetyModal(open: boolean) {
    this.showSafetyModal = open;
  }

  showToast(message: string) {
    this.toastMessage = message;
    if (this.toastTimeout) clearTimeout(this.toastTimeout);
    this.toastTimeout = setTimeout(() => {
      this.toastMessage = null;
      this.cdr.detectChanges();
    }, 3200);
    this.cdr.detectChanges();
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
