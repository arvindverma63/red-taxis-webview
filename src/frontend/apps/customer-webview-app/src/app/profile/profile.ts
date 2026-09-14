import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';

@Component({
  selector: 'app-profile',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './profile.html',
  styleUrl: './profile.css'
})
export class ProfileComponent implements OnInit {
  private router = inject(Router);

  customerName = 'Valued Customer';
  email = 'customer@redtaxi.co.uk';
  phone = '+44 7123 456789';
  tenantName = 'Ace Taxis';
  isDarkMode = false;

  ngOnInit() {
    this.isDarkMode = document.documentElement.classList.contains('dark-theme');
    const token = localStorage.getItem('auth_token');
    if (token) {
      try {
        const payload = JSON.parse(atob(token.split('.')[1]));
        if (payload.unique_name || payload.name || payload.email) {
          this.customerName = payload.unique_name || payload.name || 'Valued Customer';
          this.email = payload.email || this.email;
        }
      } catch (_) {}
    }
  }

  toggleTheme() {
    this.isDarkMode = !this.isDarkMode;
    if (this.isDarkMode) {
      document.documentElement.classList.add('dark-theme');
      localStorage.setItem('theme', 'dark');
    } else {
      document.documentElement.classList.remove('dark-theme');
      localStorage.setItem('theme', 'light');
    }
  }

  goToSavedPlaces() {
    this.router.navigate(['/saved-places']);
  }

  signOut() {
    localStorage.removeItem('auth_token');
    this.router.navigate(['/login']);
  }
}
