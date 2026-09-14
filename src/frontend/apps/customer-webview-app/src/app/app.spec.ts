import '@angular/compiler';
import { describe, it, expect } from 'vitest';
import { CustomerService } from './services/customer.service';

describe('Customer Webview App Unit Tests', () => {
  const mockHttp = {} as any;

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

  it('should return mock bookings for preview and offline activity logs', () => {
    const service = new CustomerService(mockHttp);
    const bookings = service.getMockBookings();

    expect(bookings.length).toBeGreaterThan(0);
    expect(bookings[0].id).toBe('BK994821');
    expect(bookings[0].status).toBe('driver_allocated');
    expect(bookings[0].driverName).toBe('Mohammed Tariq');
  });
});
