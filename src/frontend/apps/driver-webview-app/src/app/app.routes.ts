import { Routes } from '@angular/router';
import { BookingsComponent } from './bookings/bookings';
import { ProfileComponent } from './profile/profile';
import { AvailabilityComponent } from './availability/availability';
import { DocumentUploadComponent } from './upload/upload';

export const routes: Routes = [
  { path: 'bookings', component: BookingsComponent },
  { path: 'profile', component: ProfileComponent },
  { path: 'availability', component: AvailabilityComponent },
  { path: 'upload', component: DocumentUploadComponent },
  { path: '', redirectTo: 'bookings', pathMatch: 'full' },
  { path: '**', redirectTo: 'bookings' }
];
