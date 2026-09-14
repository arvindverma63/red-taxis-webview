import '@angular/compiler';
import { describe, it, expect } from 'vitest';
import { of } from 'rxjs';
import { CustomerService } from './services/customer.service';

describe('Customer Webview App Unit Tests', () => {
  const mockHttp = {
    get: (url: string) => of([
      {
        id: 'BK994821',
        pickupAddress: 'High Street, City Centre',
        dropoffAddress: 'Terminal 2, Heathrow Airport',
        price: 18.50,
        vehicleType: 'Saloon',
        status: 'driver_allocated',
        driverName: 'Mohammed Tariq'
      }
    ]),
    post: (url: string, data: any) => of({
      value: {
        fare: 14.50,
        distance: 4.2,
        duration: 12,
        pickupPostcode: 'SW1A 1AA',
        dropoffPostcode: 'TW6 1EW'
      }
    })
  } as any;

  it('should return vehicle options with default rates and capacities', () => {
    const service = new CustomerService(mockHttp);
    const options = service.getVehicleOptions();

    expect(options.length).toBe(5);
    expect(options[0].name).toBe('Saloon');
    expect(options[0].capacity).toBe(4);
    expect(options[0].basePrice).toBe(12.50);
    expect(options[2].name).toBe('Executive');
    expect(options[2].basePrice).toBe(22.00);
  });

  it('should parse live API bookings from getMyBookings', async () => {
    const service = new CustomerService(mockHttp);
    service.getMyBookings().subscribe(bookings => {
      expect(bookings.length).toBe(1);
      expect(bookings[0].id).toBe('BK994821');
      expect(bookings[0].status).toBe('driver_allocated');
      expect(bookings[0].driverName).toBe('Mohammed Tariq');
      expect(bookings[0].fare).toBe(18.50);
    });
  });

  it('should parse live API quote from getQuote', async () => {
    const service = new CustomerService(mockHttp);
    service.getQuote('SW1A 1AA', 'TW6 1EW', 'Saloon').subscribe(quote => {
      expect(quote.fare).toBe(14.50);
      expect(quote.distanceMiles).toBe(4.2);
      expect(quote.durationMinutes).toBe(12);
    });
  });
});
