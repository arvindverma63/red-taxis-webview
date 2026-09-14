import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, ActivatedRoute } from '@angular/router';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './login.html',
  styleUrl: './login.css'
})
export class LoginComponent implements OnInit {
  private router = inject(Router);
  private route = inject(ActivatedRoute);

  email = '';
  password = '';
  returnUrl = '/book';

  ngOnInit() {
    this.route.queryParams.subscribe(params => {
      if (params['token']) {
        localStorage.setItem('auth_token', params['token']);
        this.router.navigate([params['returnUrl'] || '/book']);
      }
      if (params['returnUrl']) {
        this.returnUrl = params['returnUrl'];
      }
    });
  }

  login() {
    // Save token and navigate
    localStorage.setItem('auth_token', 'mock_jwt_customer_token_123');
    this.router.navigate([this.returnUrl]);
  }
}
