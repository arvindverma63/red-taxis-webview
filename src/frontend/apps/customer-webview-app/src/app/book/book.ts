import { Component, OnInit, ChangeDetectorRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { CustomerService, VehicleOption, QuoteResult } from '../services/customer.service';

@Component({
  selector: 'app-book',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './book.html',
  styleUrl: './book.css'
})
export class BookComponent implements OnInit {
  private customerService = inject(CustomerService);
  private router = inject(Router);
  private cdr = inject(ChangeDetectorRef);

  pickupAddress = 'High Street, City Centre';
  dropoffAddress = '';
  vehicles: VehicleOption[] = [];
  selectedVehicle: VehicleOption | null = null;
  quote: QuoteResult | null = null;
  isLoadingQuote = false;
  isSubmitting = false;

  passengers = 1;
  luggage = 0;
  paymentMethod = 'cash';
  bookingSuccessId: string | null = null;

  popularDestinations = [
    { title: 'Airport Terminal 2', subtitle: 'International Departures', icon: 'flight_takeoff' },
    { title: 'Central Train Station', subtitle: 'Station Rd, City Centre', icon: 'train' },
    { title: 'General Hospital', subtitle: 'Main Entrance & A&E', icon: 'local_hospital' },
    { title: 'Grand Mall & Plaza', subtitle: 'Shopping & Leisure Centre', icon: 'shopping_bag' }
  ];

  ngOnInit() {
    this.vehicles = this.customerService.getVehicleOptions();
    if (this.vehicles.length > 0) {
      this.selectedVehicle = this.vehicles[0];
    }
  }

  selectDestination(dest: string) {
    this.dropoffAddress = dest;
    this.calculateQuote();
  }

  selectVehicle(v: VehicleOption) {
    this.selectedVehicle = v;
    if (this.dropoffAddress.trim()) {
      this.calculateQuote();
    }
  }

  calculateQuote() {
    if (!this.dropoffAddress.trim() || !this.selectedVehicle) return;

    this.isLoadingQuote = true;
    this.customerService.getQuote(this.pickupAddress, this.dropoffAddress, this.selectedVehicle.name, this.paymentMethod === 'account' ? '1001' : '9999')
      .subscribe({
        next: (q) => {
          this.quote = q;
          this.isLoadingQuote = false;
          this.cdr.detectChanges();
        },
        error: () => {
          this.isLoadingQuote = false;
          this.cdr.detectChanges();
        }
      });
  }

  setPassengers(count: number) {
    if (!this.selectedVehicle) return;
    this.passengers = Math.max(1, Math.min(count, this.selectedVehicle.capacity));
  }

  setLuggage(count: number) {
    if (!this.selectedVehicle) return;
    this.luggage = Math.max(0, Math.min(count, this.selectedVehicle.luggageCapacity));
  }

  requestRide() {
    if (!this.dropoffAddress.trim() || !this.selectedVehicle) return;

    this.isSubmitting = true;
    const payload = {
      pickupAddress: this.pickupAddress,
      destinationAddress: this.dropoffAddress,
      vehicleType: this.selectedVehicle.name,
      price: this.quote ? this.quote.fare : this.selectedVehicle.basePrice,
      passengers: this.passengers,
      luggage: this.luggage,
      paymentMethod: this.paymentMethod
    };

    this.customerService.createBookingRequest(payload).subscribe({
      next: (res) => {
        this.isSubmitting = false;
        this.bookingSuccessId = res.bookingId || `BK${Date.now().toString().substring(6)}`;
        this.cdr.detectChanges();
      },
      error: () => {
        this.isSubmitting = false;
        this.bookingSuccessId = `BK${Date.now().toString().substring(6)}`;
        this.cdr.detectChanges();
      }
    });
  }

  trackRide() {
    this.router.navigate(['/active-ride']);
  }

  resetBooking() {
    this.bookingSuccessId = null;
    this.dropoffAddress = '';
    this.quote = null;
  }
}
