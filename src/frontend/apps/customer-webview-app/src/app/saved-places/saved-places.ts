import { Component, OnInit, ChangeDetectorRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { CustomerService, CustomerSavedAddressDto } from '../services/customer.service';

@Component({
  selector: 'app-saved-places',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './saved-places.html',
  styleUrl: './saved-places.css'
})
export class SavedPlacesComponent implements OnInit {
  private customerService = inject(CustomerService);
  private router = inject(Router);
  private cdr = inject(ChangeDetectorRef);

  places: CustomerSavedAddressDto[] = [];
  isLoading = true;
  showAddModal = false;
  isSaving = false;

  newLabel = 'Home';
  newAddress = '';
  newPostcode = '';

  ngOnInit() {
    this.loadPlaces();
  }

  loadPlaces() {
    this.isLoading = true;
    this.customerService.getSavedAddresses().subscribe({
      next: (list) => {
        this.places = list || [];
        this.isLoading = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.places = [];
        this.isLoading = false;
        this.cdr.detectChanges();
      }
    });
  }

  goBack() {
    this.router.navigate(['/profile']);
  }

  openAddModal() {
    this.newLabel = 'Home';
    this.newAddress = '';
    this.newPostcode = '';
    this.showAddModal = true;
  }

  closeAddModal() {
    this.showAddModal = false;
  }

  savePlace() {
    if (!this.newAddress.trim()) return;

    this.isSaving = true;
    this.customerService.addSavedAddress({
      label: this.newLabel,
      addressLine: this.newAddress,
      postcode: this.newPostcode,
      description: this.newAddress
    }).subscribe({
      next: () => {
        this.isSaving = false;
        this.showAddModal = false;
        this.loadPlaces();
      },
      error: (err) => {
        console.warn('Error saving address:', err);
        this.isSaving = false;
        this.showAddModal = false;
        this.loadPlaces();
      }
    });
  }

  deletePlace(id: string) {
    this.customerService.deleteSavedAddress(id).subscribe({
      next: () => this.loadPlaces(),
      error: () => this.loadPlaces()
    });
  }
}
