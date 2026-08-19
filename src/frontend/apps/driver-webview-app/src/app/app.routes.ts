import { Routes } from '@angular/router';
import { BookingsComponent } from './bookings/bookings';
import { ProfileComponent } from './profile/profile';
import { AvailabilityComponent } from './availability/availability';
import { DocumentUploadComponent } from './upload/upload';
import { LoginComponent } from './login/login';
import { JobOfferComponent } from './job-offer/job-offer';
import { ActiveTripComponent } from './active-trip/active-trip';
import { TripCompleteComponent } from './trip-complete/trip-complete';
import { DashboardComponent } from './dashboard/dashboard';
import { ExpensesComponent } from './expenses/expenses';
import { CreateBookingComponent } from './create-booking/create-booking';
import { authGuard } from './guards/auth.guard';

export const routes: Routes = [
  { path: 'login', component: LoginComponent },
  { path: 'bookings', component: BookingsComponent, canActivate: [authGuard] },
  { path: 'profile', component: ProfileComponent, canActivate: [authGuard] },
  { path: 'availability', component: AvailabilityComponent, canActivate: [authGuard] },
  { path: 'upload', component: DocumentUploadComponent, canActivate: [authGuard] },
  { path: 'job-offer', component: JobOfferComponent, canActivate: [authGuard] },
  { path: 'active-trip', component: ActiveTripComponent, canActivate: [authGuard] },
  { path: 'trip-complete', component: TripCompleteComponent, canActivate: [authGuard] },
  { path: 'dashboard', component: DashboardComponent, canActivate: [authGuard] },
  { path: 'expenses', component: ExpensesComponent, canActivate: [authGuard] },
  { path: 'create-booking', component: CreateBookingComponent, canActivate: [authGuard] },
  { path: '', redirectTo: 'bookings', pathMatch: 'full' },
  { path: '**', redirectTo: 'bookings' }
];
