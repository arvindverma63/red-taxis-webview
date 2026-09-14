import { Routes } from '@angular/router';
import { authGuard } from './guards/auth.guard';

export const routes: Routes = [
  {
    path: '',
    redirectTo: 'book',
    pathMatch: 'full'
  },
  {
    path: 'book',
    loadComponent: () => import('./book/book').then(m => m.BookComponent),
    canActivate: [authGuard]
  },
  {
    path: 'activity',
    loadComponent: () => import('./activity/activity').then(m => m.ActivityComponent),
    canActivate: [authGuard]
  },
  {
    path: 'active-ride',
    loadComponent: () => import('./active-ride/active-ride').then(m => m.ActiveRideComponent),
    canActivate: [authGuard]
  },
  {
    path: 'profile',
    loadComponent: () => import('./profile/profile').then(m => m.ProfileComponent),
    canActivate: [authGuard]
  },
  {
    path: 'saved-places',
    loadComponent: () => import('./saved-places/saved-places').then(m => m.SavedPlacesComponent),
    canActivate: [authGuard]
  },
  {
    path: 'login',
    loadComponent: () => import('./login/login').then(m => m.LoginComponent)
  },
  {
    path: '**',
    redirectTo: 'book'
  }
];
