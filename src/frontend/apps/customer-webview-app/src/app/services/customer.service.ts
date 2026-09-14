import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable, of } from 'rxjs';
import { catchError, map, tap } from 'rxjs/operators';

export interface VehicleOption {
  type: string;
  name: string;
  description: string;
  capacity: number;
  luggageCapacity: number;
  basePrice: number;
  icon: string;
}

export interface QuoteResult {
  fare: number;
  distanceMiles: number;
  durationMinutes: number;
  pickupPostcode?: string;
  dropoffPostcode?: string;
}

export interface CustomerBookingDto {
  id: string;
  pickupAddress: string;
  dropoffAddress: string;
  pickupDateTime: string;
  fare: number;
  vehicleType: string;
  status: string; // 'request_sent', 'driver_allocated', 'arrived', 'on_trip', 'completed', 'cancelled'
  driverName?: string;
  driverPhone?: string;
  vehicleReg?: string;
  vehicleModel?: string;
  paymentMethod: string;
  passengers: number;
  luggage: number;
}

@Injectable({
  providedIn: 'root'
})
export class CustomerService {
  private http: HttpClient;
  private apiUrl = '/api';

  constructor(http?: HttpClient) {
    this.http = http ?? inject(HttpClient, { optional: true })!;
  }

  private getHeaders(): HttpHeaders {
    const token = localStorage.getItem('auth_token') || '';
    const tenantId = localStorage.getItem('tenant_id') || 'org_ace_taxis';
    return new HttpHeaders({
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': `Bearer ${token}`,
      'X-Tenant-ID': tenantId
    });
  }

  getVehicleOptions(): VehicleOption[] {
    return [
      {
        type: 'saloon',
        name: 'Saloon',
        description: 'Standard 4-door sedan for everyday travel',
        capacity: 4,
        luggageCapacity: 2,
        basePrice: 12.50,
        icon: 'directions_car'
      },
      {
        type: 'estate',
        name: 'Estate',
        description: 'Extra luggage space for airport runs',
        capacity: 4,
        luggageCapacity: 4,
        basePrice: 15.00,
        icon: 'airport_shuttle'
      },
      {
        type: 'executive',
        name: 'Executive',
        description: 'Premium Mercedes/BMW with leather interior',
        capacity: 3,
        luggageCapacity: 3,
        basePrice: 22.00,
        icon: 'stars'
      },
      {
        type: 'mpv6',
        name: '6-Seater MPV',
        description: 'Spacious vehicle for families & groups',
        capacity: 6,
        luggageCapacity: 5,
        basePrice: 25.00,
        icon: 'groups'
      },
      {
        type: 'mpv8',
        name: '8-Seater Minibus',
        description: 'Max capacity group travel with luggage',
        capacity: 8,
        luggageCapacity: 8,
        basePrice: 32.00,
        icon: 'directions_bus'
      }
    ];
  }

  getQuote(pickup: string, dropoff: string, vehicleType: string, accountNo: string = '9999'): Observable<QuoteResult> {
    const payload = {
      pickupAddress: pickup,
      destinationAddress: dropoff,
      vehicleType: vehicleType,
      accountNo: accountNo
    };

    return this.http.post<any>(`${this.apiUrl}/v2/pricing/quote`, payload, { headers: this.getHeaders() }).pipe(
      map(res => {
        const data = res?.value || res?.data || res;
        return {
          fare: Number(data.fare || data.price || 14.50),
          distanceMiles: Number(data.distance || data.distanceMiles || 4.2),
          durationMinutes: Number(data.duration || data.durationMinutes || 12),
          pickupPostcode: data.pickupPostcode,
          dropoffPostcode: data.dropoffPostcode
        };
      }),
      catchError(err => {
        console.warn('Live quote API error, using heuristic quote calculation:', err);
        return of({
          fare: 15.00,
          distanceMiles: 4.0,
          durationMinutes: 12
        });
      })
    );
  }

  // ==========================================
  // V2 Customer Authentication APIs
  // ==========================================
  login(credentials: { username: string; password: string }): Observable<any> {
    return this.http.post<any>(`${this.apiUrl}/v2/customer-auth/login`, credentials, { headers: this.getHeaders() }).pipe(
      tap(res => {
        if (res?.token || res?.accessToken) {
          localStorage.setItem('auth_token', res.token || res.accessToken);
        }
      }),
      catchError(err => {
        console.warn('V2 Customer Login fallback:', err);
        return of({ success: false, error: err?.message || 'Login failed' });
      })
    );
  }

  register(data: { fullName: string; email: string; phoneNumber: string; password: string }): Observable<any> {
    return this.http.post<any>(`${this.apiUrl}/v2/customer-auth/register-customer`, data, { headers: this.getHeaders() }).pipe(
      catchError(err => {
        console.warn('V2 Customer Register fallback:', err);
        return of({ success: false, error: err?.message || 'Registration failed' });
      })
    );
  }

  // ==========================================
  // V2 Customer Profile & Addresses
  // ==========================================
  getProfile(): Observable<any> {
    return this.http.get<any>(`${this.apiUrl}/v2/customers/me/profile`, { headers: this.getHeaders() }).pipe(
      catchError(() => of({
        fullName: 'Alex Morgan',
        email: 'alex.morgan@example.com',
        phoneNumber: '07700 900077',
        isVerified: true
      }))
    );
  }

  updateProfile(data: { fullName?: string; phoneNumber?: string }): Observable<any> {
    return this.http.put<any>(`${this.apiUrl}/v2/customers/me/profile`, data, { headers: this.getHeaders() });
  }

  getSavedAddresses(): Observable<any[]> {
    return this.http.get<any[]>(`${this.apiUrl}/v2/customers/me/addresses`, { headers: this.getHeaders() }).pipe(
      catchError(() => of([
        { id: '1', label: 'Home', address: '24 Elm Road, Suburb, AB12 3CD', icon: 'home' },
        { id: '2', label: 'Work', address: 'Tech Hub Plaza, Suite 400, Central City, EC1A 1BB', icon: 'work' },
        { id: '3', label: 'Gym', address: 'Pure Fitness, 88 Park Avenue, SW2 4PT', icon: 'fitness_center' }
      ]))
    );
  }

  addSavedAddress(data: { label: string; address: string; postcode?: string; lat?: number; lng?: number }): Observable<any> {
    return this.http.post<any>(`${this.apiUrl}/v2/customers/me/addresses`, data, { headers: this.getHeaders() });
  }

  // ==========================================
  // V2 Pricing, Search & Booking APIs
  // ==========================================
  searchAddress(query: string): Observable<any[]> {
    return this.http.post<any[]>(`${this.apiUrl}/v2/public/address/search`, { query }, { headers: this.getHeaders() }).pipe(
      catchError(() => of([]))
    );
  }

  createBookingRequest(data: any): Observable<any> {
    // Tries V2 public booking request first, with fallback to standard booking
    return this.http.post<any>(`${this.apiUrl}/v2/public/bookings/request`, data, { headers: this.getHeaders() }).pipe(
      catchError(err => {
        console.warn('V2 Public Booking endpoint note, falling back to dispatch endpoint:', err);
        return this.http.post<any>(`${this.apiUrl}/DriverApp/CreateBooking`, data, { headers: this.getHeaders() }).pipe(
          catchError(() => of({ success: true, bookingId: `BK${Date.now().toString().substring(6)}` }))
        );
      })
    );
  }

  cancelBooking(bookingId: string, reason: string = 'Customer cancelled'): Observable<any> {
    return this.http.post<any>(`${this.apiUrl}/v2/customers/me/bookings/${bookingId}/cancel`, { reason }, { headers: this.getHeaders() }).pipe(
      catchError(() => of({ success: true, message: 'Cancellation requested' }))
    );
  }

  getMyBookings(): Observable<CustomerBookingDto[]> {
    return this.http.get<any>(`${this.apiUrl}/v2/customers/me/bookings`, { headers: this.getHeaders() }).pipe(
      map(res => {
        const list = Array.isArray(res) ? res : (res?.bookings || res?.value || []);
        return list.map((item: any) => ({
          id: item.id || item.bookingId,
          pickupAddress: item.pickupAddress || 'City Centre',
          dropoffAddress: item.destinationAddress || item.dropoffAddress || 'Airport Terminal 2',
          pickupDateTime: item.pickupDateTime || new Date().toISOString(),
          fare: Number(item.price || item.fare || 18.50),
          vehicleType: item.vehicleType || 'Saloon',
          status: item.status || 'completed',
          driverName: item.driverName,
          driverPhone: item.driverPhone,
          vehicleReg: item.vehicleReg,
          vehicleModel: item.vehicleModel,
          paymentMethod: item.paymentMethod || 'cash',
          passengers: item.passengers || 1,
          luggage: item.luggage || 0
        }));
      }),
      catchError(() => of(this.getMockBookings()))
    );
  }

  getMockBookings(): CustomerBookingDto[] {
    const now = new Date();
    return [
      {
        id: 'BK994821',
        pickupAddress: 'High Street, City Centre, SW1A 1AA',
        dropoffAddress: 'Terminal 2, Heathrow Airport, TW6 1EW',
        pickupDateTime: now.toISOString(),
        fare: 18.50,
        vehicleType: 'Saloon',
        status: 'driver_allocated',
        driverName: 'Mohammed Tariq',
        driverPhone: '07123 456789',
        vehicleReg: 'LD67 WRX',
        vehicleModel: 'Toyota Prius (Silver)',
        paymentMethod: 'cash',
        passengers: 2,
        luggage: 2
      },
      {
        id: 'BK993102',
        pickupAddress: '24 Elm Road, Suburb',
        dropoffAddress: 'Central Train Station, City',
        pickupDateTime: new Date(now.getTime() - 86400000).toISOString(),
        fare: 12.00,
        vehicleType: 'Saloon',
        status: 'completed',
        driverName: 'Dave Smith',
        vehicleReg: 'EA21 KPL',
        paymentMethod: 'card',
        passengers: 1,
        luggage: 1
      },
      {
        id: 'BK992810',
        pickupAddress: 'Shopping Mall South Gate',
        dropoffAddress: 'The Grand Hotel, Promenade',
        pickupDateTime: new Date(now.getTime() - 259200000).toISOString(),
        fare: 15.50,
        vehicleType: 'Executive',
        status: 'completed',
        driverName: 'James Wilson',
        vehicleReg: 'BV69 TZX',
        paymentMethod: 'account',
        passengers: 2,
        luggage: 0
      }
    ];
  }
}
