import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';

@Injectable({
  providedIn: 'root'
})
export class DriverService {
  private baseUrl = '';

  constructor(private http: HttpClient) {}

  private getHeaders(): HttpHeaders {
    let headers = new HttpHeaders();
    const token = this.getTokenFromUrl() || localStorage.getItem('auth_token');
    if (token) {
      headers = headers.set('Authorization', `Bearer ${token}`);
    }
    return headers;
  }

  private getTokenFromUrl(): string | null {
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
  }

  getProfile(): Observable<any> {
    console.log('API Webview Request: GET /api/DriverApp/GetProfile');
    return this.http.get(`${this.baseUrl}/api/DriverApp/GetProfile`, { headers: this.getHeaders() }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: GET /api/DriverApp/GetProfile success:', JSON.stringify(res)),
        error: (err) => console.error('API Webview Error: GET /api/DriverApp/GetProfile failed:', err)
      })
    );
  }

  getTodaysJobs(): Observable<any> {
    console.log('API Webview Request: GET /api/DriverApp/TodaysJobs');
    return this.http.get(`${this.baseUrl}/api/DriverApp/TodaysJobs`, { headers: this.getHeaders() }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: GET /api/DriverApp/TodaysJobs success:', res),
        error: (err) => console.error('API Webview Error: GET /api/DriverApp/TodaysJobs failed:', err)
      })
    );
  }

  getFutureJobs(): Observable<any> {
    console.log('API Webview Request: GET /api/DriverApp/FutureJobs');
    return this.http.get(`${this.baseUrl}/api/DriverApp/FutureJobs`, { headers: this.getHeaders() }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: GET /api/DriverApp/FutureJobs success:', res),
        error: (err) => console.error('API Webview Error: GET /api/DriverApp/FutureJobs failed:', err)
      })
    );
  }

  getCompletedJobs(): Observable<any> {
    console.log('API Webview Request: GET /api/DriverApp/CompletedJobs');
    return this.http.get(`${this.baseUrl}/api/DriverApp/CompletedJobs`, { headers: this.getHeaders() }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: GET /api/DriverApp/CompletedJobs success:', res),
        error: (err) => console.error('API Webview Error: GET /api/DriverApp/CompletedJobs failed:', err)
      })
    );
  }

  getAvailabilities(): Observable<any> {
    console.log('API Webview Request: GET /api/DriverApp/Availabilities');
    return this.http.get(`${this.baseUrl}/api/DriverApp/Availabilities`, { headers: this.getHeaders() }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: GET /api/DriverApp/Availabilities success:', res),
        error: (err) => console.error('API Webview Error: GET /api/DriverApp/Availabilities failed:', err)
      })
    );
  }

  setAvailability(availabilityData: any): Observable<any> {
    console.log('API Webview Request: POST /api/DriverApp/SetAvailability data:', availabilityData);
    return this.http.post(`${this.baseUrl}/api/DriverApp/SetAvailability`, availabilityData, { headers: this.getHeaders() }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: POST /api/DriverApp/SetAvailability success:', res),
        error: (err) => console.error('API Webview Error: POST /api/DriverApp/SetAvailability failed:', err)
      })
    );
  }

  deleteAvailability(id: number): Observable<any> {
    console.log(`API Webview Request: GET /api/DriverApp/DeleteAvailability?id=${id}`);
    return this.http.get(`${this.baseUrl}/api/DriverApp/DeleteAvailability?id=${id}`, { headers: this.getHeaders() }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: GET /api/DriverApp/DeleteAvailability success:', res),
        error: (err) => console.error('API Webview Error: GET /api/DriverApp/DeleteAvailability failed:', err)
      })
    );
  }

  uploadDocument(formData: FormData): Observable<any> {
    console.log('API Webview Request: POST /api/DriverApp/UploadDocument');
    return this.http.post(`${this.baseUrl}/api/DriverApp/UploadDocument`, formData, { headers: this.getHeaders() }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: POST /api/DriverApp/UploadDocument success:', res),
        error: (err) => console.error('API Webview Error: POST /api/DriverApp/UploadDocument failed:', err)
      })
    );
  }

  login(username: string, password: string): Observable<any> {
    console.log(`API Webview Request: POST /api/UserProfile/Login username: ${username}`);
    return this.http.post(`${this.baseUrl}/api/UserProfile/Login`, { username, password }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: POST /api/UserProfile/Login success:', res),
        error: (err) => console.error('API Webview Error: POST /api/UserProfile/Login failed:', err)
      })
    );
  }
}
