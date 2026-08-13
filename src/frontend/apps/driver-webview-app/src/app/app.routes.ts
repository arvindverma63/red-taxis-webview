import { Routes } from '@angular/router';
import { BookingsComponent } from './bookings/bookings';
import { ProfileComponent } from './profile/profile';
import { AvailabilityComponent } from './availability/availability';
import { DocumentUploadComponent } from './upload/upload';
import { LoginComponent } from './login/login';
import { JobOfferComponent } from './job-offer/job-offer';
import { authGuard } from './guards/auth.guard';

export const routes: Routes = [
  { path: 'login', component: LoginComponent },
  { path: 'bookings', component: BookingsComponent, canActivate: [authGuard] },
  { path: 'profile', component: ProfileComponent, canActivate: [authGuard] },
  { path: 'availability', component: AvailabilityComponent, canActivate: [authGuard] },
  { path: 'upload', component: DocumentUploadComponent, canActivate: [authGuard] },
  { path: 'job-offer', component: JobOfferComponent, canActivate: [authGuard] },
  { path: '', redirectTo: 'bookings', pathMatch: 'full' },
  { path: '**', redirectTo: 'bookings' }
];
