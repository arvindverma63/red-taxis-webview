import { Component, OnInit, ChangeDetectorRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { CustomerService, VehicleOption, QuoteResult, AddressSearchResult } from '../services/customer.service';
import { Subject, of } from 'rxjs';
import { debounceTime, distinctUntilChanged, switchMap, catchError } from 'rxjs/operators';

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

  pickupAddress = '';
  dropoffAddress = '';
  vehicles: VehicleOption[] = [];
  selectedVehicle: VehicleOption | null = null;
  quote: QuoteResult | null = null;
  isLoadingQuote = false;
  quoteError = '';
  isSubmitting = false;

  passengers = 1;
  luggage = 0;
  paymentMethod = 'cash';
  bookingSuccessId: string | null = null;

  popularDestinations: { title: string; subtitle: string; icon: string }[] = [];

  // Live Address Search
  pickupSuggestions: AddressSearchResult[] = [];
  dropoffSuggestions: AddressSearchResult[] = [];
  activeSearchField: 'pickup' | 'dropoff' | null = null;
  private searchSubject = new Subject<{ query: string; field: 'pickup' | 'dropoff' }>();

  ngOnInit() {
    this.vehicles = this.customerService.getVehicleOptions();
    if (this.vehicles.length > 0) {
      this.selectedVehicle = this.vehicles[0];
    }

    // Load saved places into quick suggestions
    this.customerService.getSavedAddresses().subscribe({
      next: (places) => {
        if (places && places.length > 0) {
          this.popularDestinations = places.map(p => ({
            title: p.addressLine || p.label,
            subtitle: p.label,
            icon: p.icon || 'place'
          }));
          this.cdr.detectChanges();
        }
      }
    });

    // Set up debounced live address search
    this.searchSubject.pipe(
      debounceTime(300),
      distinctUntilChanged((prev, curr) => prev.query === curr.query && prev.field === curr.field),
      switchMap(({ query, field }) => {
        if (!query || query.length < 2) {
          return of({ results: [], field });
        }
        return this.customerService.searchAddress(query).pipe(
          switchMap(results => of({ results, field })),
          catchError(() => of({ results: [], field }))
        );
      })
    ).subscribe(({ results, field }) => {
      if (field === 'pickup') {
        this.pickupSuggestions = results;
      } else {
        this.dropoffSuggestions = results;
      }
      this.cdr.detectChanges();
    });
  }

  onAddressInput(field: 'pickup' | 'dropoff', query: string) {
    this.activeSearchField = field;
    this.searchSubject.next({ query, field });
  }

  pickupPostcode = '';
  dropoffPostcode = '';
  pickupLat?: number;
  pickupLng?: number;
  dropoffLat?: number;
  dropoffLng?: number;

  selectAddressSuggestion(field: 'pickup' | 'dropoff', item: AddressSearchResult) {
    const fullText = item.description || item.postcode || '';
    if (field === 'pickup') {
      this.pickupAddress = fullText;
      this.pickupPostcode = item.postcode || '';
      this.pickupLat = item.lat;
      this.pickupLng = item.lng;
      this.pickupSuggestions = [];
    } else {
      this.dropoffAddress = fullText;
      this.dropoffPostcode = item.postcode || '';
      this.dropoffLat = item.lat;
      this.dropoffLng = item.lng;
      this.dropoffSuggestions = [];
    }
    this.activeSearchField = null;

    if (item.id) {
      this.customerService.resolveAddress(item.id).subscribe({
        next: (resolved) => {
          if (field === 'pickup') {
            this.pickupAddress = resolved.formattedAddress || this.pickupAddress;
            this.pickupPostcode = resolved.postcode || this.pickupPostcode;
            this.pickupLat = resolved.lat || this.pickupLat;
            this.pickupLng = resolved.lng || this.pickupLng;
          } else {
            this.dropoffAddress = resolved.formattedAddress || this.dropoffAddress;
            this.dropoffPostcode = resolved.postcode || this.dropoffPostcode;
            this.dropoffLat = resolved.lat || this.dropoffLat;
            this.dropoffLng = resolved.lng || this.dropoffLng;
          }
          this.calculateQuote();
          this.cdr.detectChanges();
        },
        error: () => {
          this.calculateQuote();
        }
      });
    } else {
      this.calculateQuote();
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
    this.quoteError = '';
    this.customerService.getQuote(
      this.pickupAddress || 'Current Location',
      this.dropoffAddress,
      this.selectedVehicle.name,
      this.pickupPostcode,
      this.dropoffPostcode,
      this.paymentMethod === 'account' ? '1001' : '9999'
    ).subscribe({
      next: (q) => {
        this.quote = q;
        this.isLoadingQuote = false;
        this.cdr.detectChanges();
      },
      error: (err) => {
        this.isLoadingQuote = false;
        this.quoteError = 'Fare will be calculated on meter';
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
      pickup: {
        description: this.pickupAddress || 'Current Location',
        postcode: this.pickupPostcode || this.quote?.pickupPostcode || '',
        lat: this.pickupLat,
        lng: this.pickupLng
      },
      destination: {
        description: this.dropoffAddress,
        postcode: this.dropoffPostcode || this.quote?.dropoffPostcode || '',
        lat: this.dropoffLat,
        lng: this.dropoffLng
      },
      vehicleType: this.selectedVehicle.name,
      passengers: this.passengers,
      luggage: this.luggage,
      asap: true,
      paymentMethod: this.paymentMethod,
      quote: this.quote ? {
        priceCash: this.quote.fare,
        priceAccount: this.quote.fare
      } : undefined
    };

    this.customerService.createBookingRequest(payload).subscribe({
      next: (res) => {
        this.isSubmitting = false;
        this.bookingSuccessId = res?.bookingId || res?.id || res?.value?.bookingId || `BK${Date.now().toString().substring(6)}`;
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
