import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class DriverService {
  private baseUrl = 'https://staging-api.redtaxi.co.uk';

  constructor(private http: HttpClient) {}

  private getHeaders(): HttpHeaders {
    let headers = new HttpHeaders();
    const token = localStorage.getItem('auth_token') || this.getTokenFromUrl();
    if (token) {
      headers = headers.set('Authorization', `Bearer ${token}`);
    }
    return headers;
  }

  private getTokenFromUrl(): string | null {
    const urlParams = new URLSearchParams(window.location.search);
    const token = urlParams.get('token');
    if (token) {
      localStorage.setItem('auth_token', token);
    }
    return token;
  }

  getProfile(): Observable<any> {
    return this.http.get(`${this.baseUrl}/api/DriverApp/GetProfile`, { headers: this.getHeaders() });
  }

  getTodaysJobs(): Observable<any> {
    return this.http.get(`${this.baseUrl}/api/DriverApp/TodaysJobs`, { headers: this.getHeaders() });
  }

  getFutureJobs(): Observable<any> {
    return this.http.get(`${this.baseUrl}/api/DriverApp/FutureJobs`, { headers: this.getHeaders() });
  }

  getCompletedJobs(): Observable<any> {
    return this.http.get(`${this.baseUrl}/api/DriverApp/CompletedJobs`, { headers: this.getHeaders() });
  }

  getAvailabilities(): Observable<any> {
    return this.http.get(`${this.baseUrl}/api/DriverApp/Availabilities`, { headers: this.getHeaders() });
  }

  setAvailability(availabilityData: any): Observable<any> {
    return this.http.post(`${this.baseUrl}/api/DriverApp/SetAvailability`, availabilityData, { headers: this.getHeaders() });
  }

  deleteAvailability(id: number): Observable<any> {
    return this.http.get(`${this.baseUrl}/api/DriverApp/DeleteAvailability?id=${id}`, { headers: this.getHeaders() });
  }

  uploadDocument(formData: FormData): Observable<any> {
    return this.http.post(`${this.baseUrl}/api/DriverApp/UploadDocument`, formData, { headers: this.getHeaders() });
  }

  login(username: string, password: string): Observable<any> {
    return this.http.post(`${this.baseUrl}/api/UserProfile/Login`, { username, password });
  }
}
