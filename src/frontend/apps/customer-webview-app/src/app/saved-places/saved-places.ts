import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';

@Component({
  selector: 'app-saved-places',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './saved-places.html',
  styleUrl: './saved-places.css'
})
export class SavedPlacesComponent {
  private router = inject(Router);

  places = [
    { title: 'Home', address: '42 Meadowbrook Avenue, SW15 2PQ', icon: 'home' },
    { title: 'Work', address: 'Canary Wharf Tower 4, E14 5AB', icon: 'work' },
    { title: 'Gym', address: 'PureGym Central, High St', icon: 'fitness_center' }
  ];

  goBack() {
    this.router.navigate(['/profile']);
  }

  addPlace() {
    alert('Add new address modal');
  }
}
