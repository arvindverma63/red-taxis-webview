import { inject } from '@angular/core';
import { Router } from '@angular/router';

export const authGuard = () => {
  const router = inject(Router);
  
  const extractParam = (key: string): string | null => {
    let urlParams = new URLSearchParams(window.location.search);
    let val = urlParams.get(key);
    if (val) return val;

    const hash = window.location.hash;
    if (hash.includes('?')) {
      const queryString = hash.split('?')[1];
      urlParams = new URLSearchParams(queryString);
      val = urlParams.get(key);
      if (val) return val;
    }
    return null;
  };

  const token = extractParam('token');
  if (token) {
    localStorage.setItem('auth_token', token);
  }

  const theme = extractParam('theme');
  if (theme) {
    localStorage.setItem('theme', theme);
    if (theme === 'dark') {
      document.documentElement.classList.add('dark-theme');
    } else {
      document.documentElement.classList.remove('dark-theme');
    }
  }

  const tenantId = extractParam('tenantId');
  if (tenantId) {
    localStorage.setItem('tenant_id', tenantId);
  }

  const primaryColor = extractParam('primaryColor') || extractParam('color');
  if (primaryColor) {
    const formattedColor = primaryColor.startsWith('#') ? primaryColor : `#${primaryColor}`;
    document.documentElement.style.setProperty('--primary-color', formattedColor);
    localStorage.setItem('primary_color', formattedColor);
  }

  const activeToken = token || localStorage.getItem('auth_token');
  
  if (activeToken) {
    return true;
  }
  
  const attemptedUrl = window.location.hash.split('?')[0].replace('#', '');
  router.navigate(['/login'], { queryParams: { returnUrl: attemptedUrl } });
  return false;
};
