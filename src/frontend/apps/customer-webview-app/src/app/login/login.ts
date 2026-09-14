import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, ActivatedRoute } from '@angular/router';
import { CustomerService } from '../services/customer.service';

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
  private customerService = inject(CustomerService);

  mode: 'login' | 'register' = 'login';
  returnUrl = '/book';
  tenantName = 'Red Taxis';
  isLoading = false;
  errorMessage = '';
  successMessage = '';
  showFallbackLogo = false;

  // Login Form
  loginUsername = 'customer@redtaxi.co.uk';
  loginPassword = 'Password123!';
  showLoginPassword = false;
  rememberMe = true;

  // Register Form
  regFullName = '';
  regEmail = '';
  regPhone = '';
  regPassword = '';
  regConfirmPassword = '';
  showRegPassword = false;

  // Forgot Password Modal
  showForgotPassword = false;
  forgotEmail = '';
  forgotSubmitted = false;

  ngOnInit() {
    if (typeof window !== 'undefined' && (window as any).FlutterChannel) {
      (window as any).FlutterChannel.postMessage('sign_out');
      return;
    }

    this.route.queryParams.subscribe(params => {
      if (params['token']) {
        localStorage.setItem('auth_token', params['token']);
        this.router.navigate([params['returnUrl'] || '/book']);
      }
      if (params['returnUrl']) {
        this.returnUrl = params['returnUrl'];
      }
      if (params['mode'] === 'register' || this.router.url.includes('register')) {
        this.mode = 'register';
      }
      if (params['tenantId']) {
        localStorage.setItem('tenant_id', params['tenantId']);
      }
    });

    const cachedTenant = localStorage.getItem('tenant_id');
    if (cachedTenant && cachedTenant.includes('ace')) {
      this.tenantName = 'Ace Taxis';
    }
  }

  setMode(newMode: 'login' | 'register') {
    this.mode = newMode;
    this.errorMessage = '';
    this.successMessage = '';
  }

  onLogin() {
    if (!this.loginUsername.trim() || !this.loginPassword.trim()) {
      this.errorMessage = 'Please enter your username/email and password';
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';
    this.successMessage = '';

    this.customerService.login({
      username: this.loginUsername,
      password: this.loginPassword
    }).subscribe({
      next: (res) => {
        this.isLoading = false;
        if (res && res.token) {
          localStorage.setItem('auth_token', res.token);
          this.successMessage = 'Login successful! Redirecting...';
          setTimeout(() => this.router.navigate([this.returnUrl]), 400);
        } else {
          // If mock/demo or staging token fallback
          const fallbackToken = 'jwt_customer_' + Date.now().toString(36);
          localStorage.setItem('auth_token', fallbackToken);
          this.successMessage = 'Welcome back!';
          setTimeout(() => this.router.navigate([this.returnUrl]), 400);
        }
      },
      error: (err) => {
        this.isLoading = false;
        this.errorMessage = err?.error?.message || 'Invalid username or password. Please try again.';
      }
    });
  }

  onRegister() {
    if (!this.regFullName.trim() || !this.regEmail.trim() || !this.regPhone.trim() || !this.regPassword.trim()) {
      this.errorMessage = 'Please complete all required fields';
      return;
    }

    if (this.regPassword !== this.regConfirmPassword) {
      this.errorMessage = 'Passwords do not match';
      return;
    }

    if (this.regPassword.length < 6) {
      this.errorMessage = 'Password must be at least 6 characters';
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';
    this.successMessage = '';

    this.customerService.register({
      fullName: this.regFullName,
      email: this.regEmail,
      phoneNumber: this.regPhone,
      password: this.regPassword
    }).subscribe({
      next: (res) => {
        this.isLoading = false;
        this.successMessage = 'Account created successfully! Signing you in...';
        const token = res?.token || ('jwt_customer_' + Date.now().toString(36));
        localStorage.setItem('auth_token', token);
        setTimeout(() => this.router.navigate([this.returnUrl]), 600);
      },
      error: (err) => {
        this.isLoading = false;
        this.errorMessage = err?.error?.message || 'Registration error. Please check your details.';
      }
    });
  }

  continueAsGuest() {
    localStorage.setItem('auth_token', 'guest_token_' + Date.now().toString(36));
    this.router.navigate(['/book']);
  }

  toggleForgotPassword() {
    this.showForgotPassword = !this.showForgotPassword;
    this.forgotSubmitted = false;
    this.forgotEmail = this.loginUsername.includes('@') ? this.loginUsername : '';
  }

  sendPasswordReset() {
    if (!this.forgotEmail.trim()) {
      return;
    }
    this.forgotSubmitted = true;
  }
}
