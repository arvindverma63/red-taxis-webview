import { Component, OnInit, ChangeDetectorRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { CustomerService, CustomerProfileDto } from '../services/customer.service';

@Component({
  selector: 'app-profile',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './profile.html',
  styleUrl: './profile.css'
})
export class ProfileComponent implements OnInit {
  private customerService = inject(CustomerService);
  private router = inject(Router);
  private cdr = inject(ChangeDetectorRef);

  profile: CustomerProfileDto = {
    fullName: '',
    email: '',
    phoneNumber: '',
    isVerified: false
  };

  isLoading = true;
  isEditing = false;
  isSaving = false;
  editFullName = '';
  editPhone = '';

  tenantName = 'Red Taxis';

  ngOnInit() {
    this.loadProfile();
  }

  loadProfile() {
    this.isLoading = true;

    // Decode token fallback identity if token present
    const token = localStorage.getItem('auth_token');
    if (token) {
      try {
        const payload = JSON.parse(atob(token.split('.')[1]));
        if (payload.unique_name || payload.name || payload.email) {
          this.profile.fullName = payload.unique_name || payload.name || '';
          this.profile.email = payload.email || '';
        }
      } catch (_) {}
    }

    this.customerService.getProfile().subscribe({
      next: (data) => {
        if (data.fullName || data.email || data.phoneNumber) {
          this.profile = data;
        }
        this.isLoading = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.isLoading = false;
        this.cdr.detectChanges();
      }
    });

    const cachedTenant = localStorage.getItem('tenant_id');
    if (cachedTenant && cachedTenant.includes('ace')) {
      this.tenantName = 'Ace Taxis';
    }
  }

  openEdit() {
    this.editFullName = this.profile.fullName;
    this.editPhone = this.profile.phoneNumber;
    this.isEditing = true;
  }

  cancelEdit() {
    this.isEditing = false;
  }

  saveProfile() {
    this.isSaving = true;
    this.customerService.updateProfile({
      fullName: this.editFullName,
      phoneNumber: this.editPhone
    }).subscribe({
      next: () => {
        this.profile.fullName = this.editFullName;
        this.profile.phoneNumber = this.editPhone;
        this.isSaving = false;
        this.isEditing = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.isSaving = false;
        this.isEditing = false;
        this.cdr.detectChanges();
      }
    });
  }

  goToSavedPlaces() {
    this.router.navigate(['/saved-places']);
  }

  goToActivity() {
    this.router.navigate(['/activity']);
  }

  signOut() {
    localStorage.removeItem('auth_token');
    if (typeof window !== 'undefined' && (window as any).FlutterChannel) {
      (window as any).FlutterChannel.postMessage('sign_out');
    } else {
      this.router.navigate(['/login']);
    }
  }
}
