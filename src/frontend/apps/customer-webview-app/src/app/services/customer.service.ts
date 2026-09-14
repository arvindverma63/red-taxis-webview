import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { map, tap } from 'rxjs/operators';

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
  currency?: string;
}

export interface AddressSearchResult {
  description: string;
  postcode?: string;
  lat?: number;
  lng?: number;
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
  vias?: any[];
  notes?: string;
}

export interface CustomerSavedAddressDto {
  id: string;
  label: string;
  addressLine: string;
  description?: string;
  postcode?: string;
  lat?: number;
  lng?: number;
  icon?: string;
}

export interface CustomerProfileDto {
  id?: string;
  fullName: string;
  email: string;
  phoneNumber: string;
  isVerified?: boolean;
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
    let token = '';
    let tenantId = 'org_ace_taxis';
    if (typeof localStorage !== 'undefined') {
      token = localStorage.getItem('auth_token') || '';
      tenantId = localStorage.getItem('tenant_id') || 'org_ace_taxis';
    }
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

  // ==========================================
  // V2 Customer Authentication APIs
  // ==========================================
  login(credentials: { username: string; password: string }): Observable<any> {
    return this.http.post<any>(`${this.apiUrl}/v2/customer-auth/login`, credentials, { headers: this.getHeaders() }).pipe(
      tap(res => {
        const token = res?.token || res?.accessToken || (typeof res === 'string' ? res : null);
        if (token) {
          localStorage.setItem('auth_token', token);
        }
      })
    );
  }

  register(data: { fullName: string; email: string; phoneNumber: string; password: string }): Observable<any> {
    return this.http.post<any>(`${this.apiUrl}/v2/customer-auth/register-customer`, data, { headers: this.getHeaders() });
  }

  // ==========================================
  // V2 Customer Profile & Addresses
  // ==========================================
  getProfile(): Observable<CustomerProfileDto> {
    return this.http.get<any>(`${this.apiUrl}/v2/customers/me/profile`, { headers: this.getHeaders() }).pipe(
      map(res => {
        const data = res?.value || res?.data || res || {};
        return {
          id: data.id || data.userId,
          fullName: data.fullName || data.name || '',
          email: data.email || '',
          phoneNumber: data.phoneNumber || data.phone || '',
          isVerified: data.isVerified ?? false
        };
      })
    );
  }

  updateProfile(data: { fullName?: string; phoneNumber?: string }): Observable<any> {
    return this.http.put<any>(`${this.apiUrl}/v2/customers/me/profile`, data, { headers: this.getHeaders() });
  }

  getSavedAddresses(): Observable<CustomerSavedAddressDto[]> {
    return this.http.get<any>(`${this.apiUrl}/v2/customers/me/addresses`, { headers: this.getHeaders() }).pipe(
      map(res => {
        const list = Array.isArray(res) ? res : (res?.data || res?.value || res?.addresses || []);
        return list.map((item: any) => ({
          id: item.id || item.addressId || item._id,
          label: item.label || 'Saved Place',
          addressLine: item.addressLine || item.description || item.address || '',
          description: item.description,
          postcode: item.postcode,
          lat: item.lat,
          lng: item.lng,
          icon: (item.label?.toLowerCase() === 'home') ? 'home' : (item.label?.toLowerCase() === 'work') ? 'work' : 'place'
        }));
      })
    );
  }

  addSavedAddress(data: { label: string; addressLine: string; postcode?: string; lat?: number; lng?: number; description?: string }): Observable<any> {
    return this.http.post<any>(`${this.apiUrl}/v2/customers/me/addresses`, data, { headers: this.getHeaders() });
  }

  deleteSavedAddress(id: string): Observable<any> {
    return this.http.delete<any>(`${this.apiUrl}/v2/customers/me/addresses/${id}`, { headers: this.getHeaders() });
  }

  // ==========================================
  // V2 Address Search & Resolution APIs
  // ==========================================
  searchAddress(query: string): Observable<AddressSearchResult[]> {
    return this.http.post<any>(`${this.apiUrl}/v2/public/address/search`, { query }, { headers: this.getHeaders() }).pipe(
      map(res => {
        const list = Array.isArray(res) ? res : (res?.data || res?.results || res?.value || []);
        return list.map((item: any) => ({
          description: item.description || item.formattedAddress || item.address || '',
          postcode: item.postcode || item.postalCode || '',
          lat: item.lat || item.latitude,
          lng: item.lng || item.longitude
        }));
      })
    );
  }

  // ==========================================
  // V2 Pricing & Quotes
  // ==========================================
  getQuote(pickup: string, dropoff: string, vehicleType: string, accountNo: string = '9999'): Observable<QuoteResult> {
    const payload = {
      pickupAddress: pickup,
      destinationAddress: dropoff,
      vehicleType: vehicleType,
      accountNo: accountNo,
      passengers: 1,
      priceFromBase: false,
      pickupDateTime: new Date().toISOString()
    };

    return this.http.post<any>(`${this.apiUrl}/v2/pricing/quote`, payload, { headers: this.getHeaders() }).pipe(
      map(res => {
        const data = res?.value || res?.data || res;
        return {
          fare: Number(data.fare || data.price || data.priceCash || 0),
          distanceMiles: Number(data.distance || data.distanceMiles || 0),
          durationMinutes: Number(data.duration || data.durationMinutes || 0),
          pickupPostcode: data.pickupPostcode,
          dropoffPostcode: data.dropoffPostcode,
          currency: '£'
        };
      })
    );
  }

  // ==========================================
  // V2 Customer Bookings & Ride Management
  // ==========================================
  createBookingRequest(data: any): Observable<any> {
    return this.http.post<any>(`${this.apiUrl}/v2/public/bookings/request`, data, { headers: this.getHeaders() });
  }

  getMyBookings(status?: string): Observable<CustomerBookingDto[]> {
    const endpoint = status
      ? `${this.apiUrl}/v2/customers/me/bookings?status=${status}`
      : `${this.apiUrl}/v2/customers/me/bookings`;

    return this.http.get<any>(endpoint, { headers: this.getHeaders() }).pipe(
      map(res => {
        const list = Array.isArray(res) ? res : (res?.bookings || res?.data || res?.value || []);
        return list.map((item: any) => ({
          id: item.id || item.bookingId,
          pickupAddress: item.pickupAddress || item.pickup?.description || '',
          dropoffAddress: item.destinationAddress || item.dropoffAddress || item.destination?.description || '',
          pickupDateTime: item.pickupDateTime || item.scheduledFor || '',
          fare: Number(item.price || item.fare || item.quote?.priceCash || 0),
          vehicleType: item.vehicleType || 'Saloon',
          status: item.status || 'request_sent',
          driverName: item.driverName,
          driverPhone: item.driverPhone,
          vehicleReg: item.vehicleReg,
          vehicleModel: item.vehicleModel,
          paymentMethod: item.paymentMethod || 'cash',
          passengers: item.passengers || 1,
          luggage: item.luggage || 0,
          vias: item.vias || [],
          notes: item.details || item.notes
        }));
      })
    );
  }

  getBookingById(id: string): Observable<CustomerBookingDto> {
    return this.http.get<any>(`${this.apiUrl}/v2/customers/me/bookings/${id}`, { headers: this.getHeaders() }).pipe(
      map(item => ({
        id: item.id || item.bookingId,
        pickupAddress: item.pickupAddress || item.pickup?.description || '',
        dropoffAddress: item.destinationAddress || item.dropoffAddress || item.destination?.description || '',
        pickupDateTime: item.pickupDateTime || item.scheduledFor || '',
        fare: Number(item.price || item.fare || item.quote?.priceCash || 0),
        vehicleType: item.vehicleType || 'Saloon',
        status: item.status || 'request_sent',
        driverName: item.driverName,
        driverPhone: item.driverPhone,
        vehicleReg: item.vehicleReg,
        vehicleModel: item.vehicleModel,
        paymentMethod: item.paymentMethod || 'cash',
        passengers: item.passengers || 1,
        luggage: item.luggage || 0,
        vias: item.vias || [],
        notes: item.details || item.notes
      }))
    );
  }

  cancelBooking(bookingId: string, reason: string = 'Customer cancelled'): Observable<any> {
    return this.http.post<any>(`${this.apiUrl}/v2/customers/me/bookings/${bookingId}/cancel`, { reason }, { headers: this.getHeaders() });
  }

  changeBooking(bookingId: string, data: any): Observable<any> {
    return this.http.post<any>(`${this.apiUrl}/v2/customers/me/bookings/${bookingId}/change`, data, { headers: this.getHeaders() });
  }
}
