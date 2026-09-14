import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';

@Component({
  selector: 'app-active-ride',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './active-ride.html',
  styleUrl: './active-ride.css'
})
export class ActiveRideComponent implements OnInit, OnDestroy {
  private router = inject(Router);
  private cdr = inject(ChangeDetectorRef);

  status: 'driver_allocated' | 'arrived' | 'on_trip' | 'completed' = 'driver_allocated';
  etaMinutes = 4;
  driverName = 'Mohammed Tariq';
  driverPhone = '07123 456789';
  vehicleModel = 'Toyota Prius (Silver)';
  vehicleReg = 'LD67 WRX';
  fare = 18.50;
  pickupAddress = 'High Street, City Centre';
  dropoffAddress = 'Terminal 2, Heathrow Airport';

  private timer: any;

  ngOnInit() {
    this.startSimulation();
  }

  ngOnDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  startSimulation() {
    this.timer = setInterval(() => {
      if (this.status === 'driver_allocated') {
        this.status = 'arrived';
        this.etaMinutes = 0;
        this.cdr.detectChanges();
      } else if (this.status === 'arrived') {
        this.status = 'on_trip';
        this.etaMinutes = 15;
        this.cdr.detectChanges();
      }
    }, 20000);
  }

  callDriver() {
    window.location.href = `tel:${this.driverPhone}`;
  }

  callOffice() {
    window.location.href = 'tel:01234567890';
  }

  cancelRide() {
    if (confirm('Are you sure you want to cancel this booking?')) {
      this.router.navigate(['/activity']);
    }
  }

  goBack() {
    this.router.navigate(['/activity']);
  }
}
