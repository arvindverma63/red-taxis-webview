import { inject } from '@angular/core';
import { Router } from '@angular/router';

export const authGuard = () => {
  const router = inject(Router);
  
  // Extract token from URL search parameters or hash query parameters
  const extractToken = (): string | null => {
    let urlParams = new URLSearchParams(window.location.search);
    let token = urlParams.get('token');
    if (token) {
      localStorage.setItem('auth_token', token);
      return token;
    }

    const hash = window.location.hash;
    if (hash.includes('?')) {
      const queryString = hash.split('?')[1];
      urlParams = new URLSearchParams(queryString);
      token = urlParams.get('token');
      if (token) {
        localStorage.setItem('auth_token', token);
        return token;
      }
    }
    return null;
  };

  const token = extractToken() || localStorage.getItem('auth_token');
  
  if (token) {
    return true;
  }
  
  const attemptedUrl = window.location.hash.split('?')[0].replace('#', '');
  router.navigate(['/login'], { queryParams: { returnUrl: attemptedUrl } });
  return false;
};
