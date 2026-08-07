import { Routes } from '@angular/router';
import { BookingsComponent } from './bookings/bookings';
import { ProfileComponent } from './profile/profile';
import { AvailabilityComponent } from './availability/availability';

export const routes: Routes = [
  { path: 'bookings', component: BookingsComponent },
  { path: 'profile', component: ProfileComponent },
  { path: 'availability', component: AvailabilityComponent },
  { path: '', redirectTo: 'bookings', pathMatch: 'full' },
  { path: '**', redirectTo: 'bookings' }
];
