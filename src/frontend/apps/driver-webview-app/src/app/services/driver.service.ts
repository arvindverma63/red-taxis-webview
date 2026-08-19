import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { tap, catchError } from 'rxjs/operators';

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

  public getToken(): string | null {
    return this.getTokenFromUrl() || localStorage.getItem('auth_token');
  }

  getProfile(): Observable<any> {
    console.log('API Webview Request: GET /api/DriverApp/GetProfile');
    return this.http.get(`${this.baseUrl}/api/DriverApp/GetProfile`, { headers: this.getHeaders() }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: GET /api/DriverApp/GetProfile success:', res),
        error: (err) => console.error('API Webview Error: GET /api/DriverApp/GetProfile failed:', err)
      })
    );
  }

  getBookingsToday(): Observable<any> {
    console.log('API Webview Request: GET /api/Bookings/Today');
    return this.http.get(`${this.baseUrl}/api/Bookings/Today`, { headers: this.getHeaders() }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: GET /api/Bookings/Today success:', res),
        error: (err) => console.error('API Webview Error: GET /api/Bookings/Today failed:', err)
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
    console.log('API Webview Request: POST /api/DriverApp/SetAvailability data:', JSON.stringify(availabilityData));
    let headers = this.getHeaders();
    headers = headers.set('Content-Type', 'application/json');
    return this.http.post(`${this.baseUrl}/api/DriverApp/SetAvailability`, availabilityData, { headers }).pipe(
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

  getAllDriversAvailability(date: string): Observable<any> {
    console.log(`API Webview Request: GET /api/Availability/General?date=${date}`);
    return this.http.get(`${this.baseUrl}/api/Availability/General?date=${date}`, { headers: this.getHeaders() }).pipe(
      catchError(() => this.http.get(`${this.baseUrl}/api/DriverApp/General?date=${date}`, { headers: this.getHeaders() })),
      tap({
        next: (res) => console.log('API Webview Response: Fleet availability success:', res),
        error: (err) => console.error('API Webview Error: Fleet availability failed:', err)
      })
    );
  }

  uploadDocument(formData: FormData): Observable<any> {
    console.log('API Webview Request: POST /api/DriverApp/UploadDocument');
    return this.http.post(`${this.baseUrl}/api/DriverApp/UploadDocument`, formData, {
      headers: this.getHeaders(),
      reportProgress: true,
      observe: 'events',
      responseType: 'text'
    }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: POST /api/DriverApp/UploadDocument success event:', JSON.stringify(res)),
        error: (err) => console.error('API Webview Error: POST /api/DriverApp/UploadDocument failed:', JSON.stringify(err))
      })
    );
  }

  getDriverExpirys(): Observable<any> {
    console.log('API Webview Request: GET /api/AdminUI/GetDriverExpirys');
    return this.http.get(`${this.baseUrl}/api/AdminUI/GetDriverExpirys`, { headers: this.getHeaders() }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: GET /api/AdminUI/GetDriverExpirys success:', JSON.stringify(res)),
        error: (err) => console.error('API Webview Error: GET /api/AdminUI/GetDriverExpirys failed:', JSON.stringify(err))
      })
    );
  }

  getExpenses(userId: number, from: string, to: string): Observable<any> {
    console.log(`API Webview Request: GET /api/DriverApp/GetExpenses?UserId=${userId}&From=${from}&To=${to}`);
    return this.http.get(`${this.baseUrl}/api/DriverApp/GetExpenses?UserId=${userId}&From=${from}&To=${to}`, { headers: this.getHeaders() }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: GET /api/DriverApp/GetExpenses success:', res),
        error: (err) => console.error('API Webview Error: GET /api/DriverApp/GetExpenses failed:', err)
      })
    );
  }

  addExpense(expenseData: any): Observable<any> {
    console.log('API Webview Request: POST /api/DriverApp/AddExpense data:', JSON.stringify(expenseData));
    let headers = this.getHeaders();
    headers = headers.set('Content-Type', 'application/json');
    return this.http.post(`${this.baseUrl}/api/DriverApp/AddExpense`, expenseData, { headers }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: POST /api/DriverApp/AddExpense success:', res),
        error: (err) => console.error('API Webview Error: POST /api/DriverApp/AddExpense failed:', err)
      })
    );
  }

  getJobOffers(): Observable<any> {
    console.log('API Webview Request: GET /api/DriverApp/GetJobOffers');
    return this.http.get(`${this.baseUrl}/api/DriverApp/GetJobOffers`, { headers: this.getHeaders() }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: GET /api/DriverApp/GetJobOffers success:', res),
        error: (err) => console.error('API Webview Error: GET /api/DriverApp/GetJobOffers failed:', err)
      })
    );
  }

  getJobById(bookingId: string): Observable<any> {
    console.log(`API Webview Request: GET /api/Bookings/FindById?bookingId=${bookingId}`);
    return this.http.get(`${this.baseUrl}/api/Bookings/FindById?bookingId=${bookingId}`, { headers: this.getHeaders() }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: GET /api/Bookings/FindById success:', res),
        error: (err) => console.error('API Webview Error: GET /api/Bookings/FindById failed:', err)
      })
    );
  }

  retrieveJobOffer(guid: string): Observable<any> {
    console.log(`API Webview Request: GET /api/DriverApp/RetrieveJobOffer?guid=${guid}`);
    return this.http.get(`${this.baseUrl}/api/DriverApp/RetrieveJobOffer?guid=${guid}`, { headers: this.getHeaders() }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: GET /api/DriverApp/RetrieveJobOffer success:', res),
        error: (err) => console.error('API Webview Error: GET /api/DriverApp/RetrieveJobOffer failed:', err)
      })
    );
  }

  replyJobOffer(jobId: number, response: number, guid: string = ''): Observable<any> {
    let url = `${this.baseUrl}/api/DriverApp/JobOfferReply?jobno=${jobId}&response=${response}`;
    if (guid) {
      url += `&guid=${encodeURIComponent(guid)}`;
    }
    console.log(`API Webview Request: GET ${url} - parameters: jobId=${jobId}, response=${response}, guid=${guid}`);
    return this.http.get(url, { 
      headers: this.getHeaders(),
      responseType: 'text'
    }).pipe(
      tap({
        next: (res) => console.log(`API Webview Response: GET /api/DriverApp/JobOfferReply success. Response text: "${res}"`),
        error: (err) => {
          console.error(`API Webview Error: GET /api/DriverApp/JobOfferReply failed for jobId=${jobId}, response=${response}, guid=${guid}. Error details:`, err);
          try {
            console.error(`API Webview Error Serialized: ${JSON.stringify(err)}`);
          } catch(e) {}
        }
      })
    );
  }

  getDashTotals(): Observable<any> {
    console.log('API Webview Request: GET /api/DriverApp/dashTotals');
    return this.http.get(`${this.baseUrl}/api/DriverApp/dashTotals`, { headers: this.getHeaders() }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: GET /api/DriverApp/dashTotals success:', res),
        error: (err) => console.error('API Webview Error: GET /api/DriverApp/dashTotals failed:', err)
      })
    );
  }

  getActiveJob(): Observable<any> {
    console.log('API Webview Request: GET /api/DriverApp/GetActiveJob');
    return this.http.get(`${this.baseUrl}/api/DriverApp/GetActiveJob`, { headers: this.getHeaders() }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: GET /api/DriverApp/GetActiveJob success:', res),
        error: (err) => console.error('API Webview Error: GET /api/DriverApp/GetActiveJob failed:', err)
      })
    );
  }

  setActiveJob(bookingId: number | null): Observable<any> {
    const idVal = bookingId ?? 0;
    const url = `${this.baseUrl}/api/DriverApp/SetActiveJob?bookingId=${idVal}`;
    console.log(`API Webview Request: POST ${url}`);
    return this.http.post(url, { bookingId: idVal, BookingId: idVal }, { headers: this.getHeaders() }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: POST /api/DriverApp/SetActiveJob success:', res),
        error: (err) => console.error('API Webview Error: POST /api/DriverApp/SetActiveJob failed:', err)
      })
    );
  }

  completeJob(data: {
    bookingId: number;
    waitingTime?: number;
    parkingCharge?: number;
    driverPrice?: number;
    accountPrice?: number;
    tip?: number;
  }): Observable<any> {
    const payload = {
      bookingId: data.bookingId,
      BookingId: data.bookingId,
      waitingTime: data.waitingTime ?? 0,
      WaitingTime: data.waitingTime ?? 0,
      parkingCharge: data.parkingCharge ?? 0,
      ParkingCharge: data.parkingCharge ?? 0,
      driverPrice: data.driverPrice ?? 0,
      DriverPrice: data.driverPrice ?? 0,
      accountPrice: data.accountPrice ?? 0,
      AccountPrice: data.accountPrice ?? 0,
      tip: data.tip ?? 0,
      Tip: data.tip ?? 0
    };
    console.log('API Webview Request: POST /api/DriverApp/CompleteJob payload:', JSON.stringify(payload));
    return this.http.post(`${this.baseUrl}/api/DriverApp/CompleteJob`, payload, { headers: this.getHeaders() }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: POST /api/DriverApp/CompleteJob success:', res),
        error: (err) => console.error('API Webview Error: POST /api/DriverApp/CompleteJob failed:', err)
      })
    );
  }

  markArrived(bookingId: number): Observable<any> {
    console.log(`API Webview Request: GET /api/DriverApp/Arrived?bookingId=${bookingId}`);
    return this.http.get(`${this.baseUrl}/api/DriverApp/Arrived?bookingId=${bookingId}`, { headers: this.getHeaders() }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: GET /api/DriverApp/Arrived success:', res),
        error: (err) => console.error('API Webview Error: GET /api/DriverApp/Arrived failed:', err)
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

  searchAddress(term: string, sessionToken: string): Observable<any> {
    console.log(`API Webview Request: GET /api/address/dispatchsearch?q=${term}&sessionToken=${sessionToken}`);
    return this.http.get(`${this.baseUrl}/api/address/dispatchsearch?q=${term}&sessionToken=${sessionToken}`, { headers: this.getHeaders() }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: GET /api/address/dispatchsearch success:', res),
        error: (err) => console.error('API Webview Error: GET /api/address/dispatchsearch failed:', err)
      })
    );
  }

  resolveAddress(id: string, sessionToken: string): Observable<any> {
    console.log(`API Webview Request: GET /api/address/resolve?id=${id}&sessionToken=${sessionToken}`);
    return this.http.get(`${this.baseUrl}/api/address/resolve?id=${id}&sessionToken=${sessionToken}`, { headers: this.getHeaders() }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: GET /api/address/resolve success:', res),
        error: (err) => console.error('API Webview Error: GET /api/address/resolve failed:', err)
      })
    );
  }

  getBookingPrice(priceData: any): Observable<any> {
    console.log('API Webview Request: POST /api/Bookings/GetPrice data:', JSON.stringify(priceData));
    let headers = this.getHeaders().set('Content-Type', 'application/json');
    return this.http.post(`${this.baseUrl}/api/Bookings/GetPrice`, priceData, { headers }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: POST /api/Bookings/GetPrice success:', res),
        error: (err) => console.error('API Webview Error: POST /api/Bookings/GetPrice failed:', err)
      })
    );
  }

  createRankBooking(bookingData: any): Observable<any> {
    console.log('API Webview Request: POST /api/Bookings/RankCreate data:', JSON.stringify(bookingData));
    let headers = this.getHeaders().set('Content-Type', 'application/json');
    return this.http.post(`${this.baseUrl}/api/Bookings/RankCreate`, bookingData, { headers }).pipe(
      tap({
        next: (res) => console.log('API Webview Response: POST /api/Bookings/RankCreate success:', res),
        error: (err) => console.error('API Webview Error: POST /api/Bookings/RankCreate failed:', err)
      })
    );
  }
}
