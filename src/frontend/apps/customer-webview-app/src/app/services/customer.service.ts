import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable, of } from 'rxjs';
import { map, tap, catchError } from 'rxjs/operators';

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
  id?: string;
  description: string;
  postcode?: string;
  lat?: number;
  lng?: number;
}

export interface ResolvedAddressResult {
  formattedAddress: string;
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
    let tenantKey = 'demo_key';

    if (typeof window !== 'undefined') {
      const urlParams = new URLSearchParams(window.location.search);
      const hash = window.location.hash;
      const hashParams = hash.includes('?') ? new URLSearchParams(hash.split('?')[1]) : null;

      token = urlParams.get('token') || hashParams?.get('token') || localStorage.getItem('auth_token') || '';
      tenantId = urlParams.get('tenantId') || hashParams?.get('tenantId') || localStorage.getItem('tenant_id') || 'org_ace_taxis';
      tenantKey = urlParams.get('tenantKey') || hashParams?.get('tenantKey') || localStorage.getItem('tenant_key') || 'demo_key';

      if (token) localStorage.setItem('auth_token', token);
      if (tenantId) localStorage.setItem('tenant_id', tenantId);
    }

    let headers = new HttpHeaders({
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Tenant-ID': tenantId,
      'X-Tenant-Key': tenantKey
    });

    if (token && token.trim()) {
      headers = headers.set('Authorization', `Bearer ${token}`);
    }

    return headers;
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
  searchAddress(query: string, sessionToken?: string): Observable<AddressSearchResult[]> {
    const payload = {
      query: query.trim(),
      limit: 10,
      sessionToken: sessionToken || undefined
    };

    return this.http.post<any>(`${this.apiUrl}/v2/public/address/search`, payload, { headers: this.getHeaders() }).pipe(
      map(res => {
        const raw = res?.data?.suggestions || res?.suggestions || (Array.isArray(res?.data) ? res.data : (Array.isArray(res) ? res : []));
        return raw.map((item: any) => ({
          id: item.id || item.placeId,
          description: item.label || item.description || item.formattedAddress || item.address || item.name || '',
          postcode: item.postcode || item.postalCode || '',
          lat: item.lat || item.latitude,
          lng: item.lng || item.longitude
        }));
      }),
      catchError(() => {
        // Fallback to /api/v2/address/search
        return this.http.post<any>(`${this.apiUrl}/v2/address/search`, payload, { headers: this.getHeaders() }).pipe(
          map(res => {
            const raw = res?.data?.suggestions || res?.suggestions || (Array.isArray(res?.data) ? res.data : (Array.isArray(res) ? res : []));
            return raw.map((item: any) => ({
              id: item.id || item.placeId,
              description: item.label || item.description || item.formattedAddress || item.address || item.name || '',
              postcode: item.postcode || item.postalCode || '',
              lat: item.lat || item.latitude,
              lng: item.lng || item.longitude
            }));
          }),
          catchError(() => {
            // Fallback to /api/Address/Search or /api/Address/Lookup
            return this.http.get<any>(`${this.apiUrl}/Address/Search?query=${encodeURIComponent(query)}`, { headers: this.getHeaders() }).pipe(
              map(res => {
                const list = Array.isArray(res) ? res : (res?.data || res?.suggestions || []);
                return list.map((item: any) => ({
                  id: item.id,
                  description: item.label || item.description || item.address || '',
                  postcode: item.postcode || '',
                  lat: item.lat,
                  lng: item.lng
                }));
              }),
              catchError(() => of([]))
            );
          })
        );
      })
    );
  }

  resolveAddress(id: string, sessionToken?: string): Observable<ResolvedAddressResult> {
    const params = sessionToken ? `?id=${encodeURIComponent(id)}&sessionToken=${encodeURIComponent(sessionToken)}` : `?id=${encodeURIComponent(id)}`;
    
    return this.http.get<any>(`${this.apiUrl}/v2/public/address/resolve${params}`, { headers: this.getHeaders() }).pipe(
      map(res => {
        const data = res?.data || res?.value || res || {};
        return {
          formattedAddress: data.formattedAddress || data.displayLabel || data.address || '',
          postcode: data.postcode || data.postalCode || '',
          lat: data.lat || data.latitude,
          lng: data.lng || data.longitude
        };
      }),
      catchError(() => {
        return this.http.get<any>(`${this.apiUrl}/v2/address/resolve${params}`, { headers: this.getHeaders() }).pipe(
          map(res => {
            const data = res?.data || res?.value || res || {};
            return {
              formattedAddress: data.formattedAddress || data.displayLabel || data.address || '',
              postcode: data.postcode || data.postalCode || '',
              lat: data.lat || data.latitude,
              lng: data.lng || data.longitude
            };
          }),
          catchError(() => of({ formattedAddress: id }))
        );
      })
    );
  }

  // ==========================================
  // V2 Pricing & Quotes
  // ==========================================
  getQuote(
    pickup: string,
    dropoff: string,
    vehicleType: string,
    pickupPostcode?: string,
    dropoffPostcode?: string,
    accountNo: string = '9999'
  ): Observable<QuoteResult> {
    const payload = {
      pickupAddress: pickup,
      destinationAddress: dropoff,
      pickupPostcode: pickupPostcode || undefined,
      destinationPostcode: dropoffPostcode || undefined,
      viaPostcodes: [],
      vehicleType: vehicleType,
      accountNo: accountNo,
      passengers: 1,
      priceFromBase: false,
      pickupDateTime: new Date().toISOString()
    };

    return this.http.post<any>(`${this.apiUrl}/v2/pricing/quote`, payload, { headers: this.getHeaders() }).pipe(
      map(res => {
        const data = res?.data || res?.value || res || {};
        return {
          fare: Number(data.fare || data.price || data.priceCash || data.priceDriver || 0),
          distanceMiles: Number(data.distance || data.distanceMiles || 0),
          durationMinutes: Number(data.duration || data.durationMinutes || 0),
          pickupPostcode: data.pickupPostcode || pickupPostcode,
          dropoffPostcode: data.dropoffPostcode || dropoffPostcode,
          currency: '£'
        };
      }),
      catchError(() => {
        // Fallback to /api/v2/public/pricing/quote
        return this.http.post<any>(`${this.apiUrl}/v2/public/pricing/quote`, payload, { headers: this.getHeaders() }).pipe(
          map(res => {
            const data = res?.data || res?.value || res || {};
            return {
              fare: Number(data.fare || data.price || data.priceCash || data.priceDriver || 0),
              distanceMiles: Number(data.distance || data.distanceMiles || 0),
              durationMinutes: Number(data.duration || data.durationMinutes || 0),
              pickupPostcode: data.pickupPostcode || pickupPostcode,
              dropoffPostcode: data.dropoffPostcode || dropoffPostcode,
              currency: '£'
            };
          })
        );
      })
    );
  }

  // ==========================================
  // V2 Customer Bookings & Ride Management
  // ==========================================
  createBookingRequest(data: any): Observable<any> {
    const customerPayload = {
      pickupAddress: data.pickup?.description || data.pickupAddress || '',
      pickupPostcode: data.pickup?.postcode || data.pickupPostcode || '',
      pickupLat: data.pickup?.lat,
      pickupLng: data.pickup?.lng,
      destinationAddress: data.destination?.description || data.dropoffAddress || '',
      destinationPostcode: data.destination?.postcode || data.dropoffPostcode || '',
      destinationLat: data.destination?.lat,
      destinationLng: data.destination?.lng,
      vehicleType: data.vehicleType || 'Saloon',
      passengers: data.passengers || 1,
      luggage: data.luggage || 0,
      pickupDateTime: data.scheduledFor || data.pickupDateTime || new Date().toISOString(),
      paymentMethod: data.paymentMethod || 'cash',
      notes: data.details || data.notes || '',
      fare: data.quote?.priceCash || data.fare || 0,
      asap: data.asap ?? true,
      passengerName: data.passengerName || 'Valued Customer',
      phoneNumber: data.phoneNumber || '',
      email: data.email || ''
    };

    // 1. Try customer authenticated bookings endpoint
    return this.http.post<any>(`${this.apiUrl}/v2/customers/me/bookings`, customerPayload, { headers: this.getHeaders() }).pipe(
      catchError(() => {
        // 2. Fallback to /api/v2/public/bookings/request
        return this.http.post<any>(`${this.apiUrl}/v2/public/bookings/request`, data, { headers: this.getHeaders() }).pipe(
          catchError(() => {
            // 3. Fallback to /api/DriverApp/CreateBooking
            const legacyPayload = {
              pickup: customerPayload.pickupAddress,
              destination: customerPayload.destinationAddress,
              pickupDateTime: customerPayload.pickupDateTime,
              vehicleType: customerPayload.vehicleType,
              passengers: customerPayload.passengers,
              paymentMethod: customerPayload.paymentMethod,
              price: customerPayload.fare,
              notes: customerPayload.notes
            };
            return this.http.post<any>(`${this.apiUrl}/DriverApp/CreateBooking`, legacyPayload, { headers: this.getHeaders() });
          })
        );
      })
    );
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
