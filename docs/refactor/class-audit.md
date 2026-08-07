# Class & Interface Audit

Generated: 2026-03-24 | Phase 0

## Summary

- Total Services: 23 (8 over 300 lines)
- Total Models: 38 (including base classes)
- Total DTOs: 45 files
- Total Interfaces: 10
- Total Domain: 10
- Total Modules: 13 files (Membership + Messaging)
- Total PDF: 4
- Total Other: 13 (Configuration, Shared, Integrations, misc)
- Flagged for cleanup: 27

---

## Services

| Class | File | Lines | Purpose | Flags |
|-------|------|-------|---------|-------|
| BaseService\<T\> | Services/.Structure/BaseService.cs | 32 | Abstract base for all services; holds DbContext, ILogger, and transaction helper | — |
| AccountsService | Services/AccountsService.cs | 2313 | Account invoicing, billing, credit notes, statement generation, account CRUD | [GOD-SERVICE] |
| AceMessagingService | Services/AceMessagingService.cs | 883 | SMS/email/WhatsApp notifications for booking events; extends MessageService | [GOD-SERVICE] [ACE-SPECIFIC] |
| AddressLookupService | Services/AddressLookupService.cs | 420 | Address autocomplete and resolution via Google Places, Ideal Postcodes, and local POI | [GOD-SERVICE] |
| AdminUIService | Services/AdminUIService.cs | 252 | Admin dashboard data: broadcast messages, on-shift drivers, dashboard stats | — |
| AvailabilityService | Services/AvailabilityService.cs | 493 | Driver availability/shift management: create, validate, report, on-shift tracking | [GOD-SERVICE] |
| BookingService | Services/BookingService.cs | 2186 | Core booking CRUD, scheduling, recurrence, cancellation, amendments, web bookings | [GOD-SERVICE] |
| DispatchService | Services/DispatchService.cs | 1025 | Driver allocation/unallocation, job offers, dispatch logic | [GOD-SERVICE] |
| DocumentService | Services/DocumentService.cs | 249 | Dropbox file upload/management for driver documents (insurance, MOT, DBS, etc.) | — |
| GeoZoneService | Services/GeoZoneService.cs | 42 | CRUD for zone-to-zone pricing | — |
| GoogleCalendarService | Services/GoogleCalendarService.cs | 104 | Google Calendar event sync (read events) | [ACE-SPECIFIC] |
| LocalPOIService | Services/LocalPOIService.cs | 173 | Local points-of-interest CRUD and search for address lookup | — |
| ReportingService | Services/ReportingService.cs | 1263 | Driver earnings, account reports, booking statistics, revenue reports | [GOD-SERVICE] |
| RevoluttService | Services/RevoluttService.cs | 285 | Revolut payment order creation, capture, and status checks | [ACE-SPECIFIC] |
| TariffService | Services/TariffService.cs | 716 | Pricing engine: tariff management, distance-based pricing via Google Maps | [GOD-SERVICE] [ACE-SPECIFIC] |
| UINotificationService | Services/UINotificationService.cs | 187 | In-app UI notification creation and management | — |
| UrlTrackingService | Services/UrlTrackingService.cs | 37 | Short URL resolution and QR code click tracking | — |
| UserActionsService | Services/UserActionsService.cs | 379 | Audit logging for booking/dispatch actions | [GOD-SERVICE] |
| UserProfileService | Services/UserProfileService.cs | 1066 | User/driver profile CRUD, GPS updates, FCM tokens, document expiry management | [GOD-SERVICE] |
| MessagingCacheService | Services/Cache/MessagingCacheService.cs | 6 | Empty placeholder class | [DEAD] |
| StartupCacheService | Services/Cache/StartupCacheService.cs | 118 | IHostedService that warms Redis caches (GPS locations + user profiles) on startup | — |
| UserLocationCacheService | Services/Cache/UserLocationCacheService.cs | 153 | Redis-backed driver GPS location cache with sorted-set proximity queries | — |
| UserProfileCacheService | Services/Cache/UserProfileCacheService.cs | 51 | Redis-backed user profile cache (get/set) | — |

**Service totals:** 23 classes, 12,433 lines total. 8 services exceed 300 lines.

### Key Findings — Services

- **AccountsService (2313 lines)** and **BookingService (2186 lines)** are the largest god-services and primary refactor targets.
- **AceMessagingService** contains hardcoded Ace Taxis email addresses, SMTP credentials, and email subjects.
- **RevoluttService** has a hardcoded production API key on line 15 — security risk.
- **TariffService** has a hardcoded `BasePostcode = "SP8 4PZ"` (Ace Taxis HQ postcode).
- **GoogleCalendarService** has a hardcoded Calendar ID and `ApplicationName = "Ace"`.
- **MessagingCacheService** is completely empty (6 lines, just a namespace and empty class).

---

## Data / DbContext

| Class | File | Lines | Purpose | Flags |
|-------|------|-------|---------|-------|
| AppDbContext | Data/AppDbContext.cs | 76 | Identity DbContext base; configures Identity table names | — |
| AppDbContextFactory | Data/AppDbContext.cs | — | Design-time factory for EF migrations | — |
| RedTaxiDbContext | Data/AceDbContext.cs | 263 | Main DbContext inheriting AppDbContext; all DbSets and model configuration | [BAD-NAME] |
| MockData | Data/MockData.cs | 286 | Generates mock bookings for development/testing | [ACE-SPECIFIC] |
| ScheduleData | Data/ScheduleData.cs | 417 | Generates sample schedule/booking data for UI development | [GOD-SERVICE] [ACE-SPECIFIC] |

**Note:** The file is named `AceDbContext.cs` but the class inside is `RedTaxiDbContext` — misleading filename.

---

## Data / Models

| Class | File | Lines | Purpose | Flags |
|-------|------|-------|---------|-------|
| ModelBase | Data/Models/.Structure/ModelBase.cs | 26 | Abstract base entity with Id, DateCreated, DateUpdated | — |
| SwaggerIgnorePropertyAttribute | Data/Models/.Structure/SwaggerIgnore.cs | 34 | Attribute + schema filter to hide properties from Swagger | — |
| Account | Data/Models/Account.cs | 48 | Business account entity (name, contact, billing details) | — |
| AccountInvoice | Data/Models/AccountInvoice.cs | 48 | Account invoice entity (PDF path, totals, dates) | — |
| AccountPassenger | Data/Models/AccountPassenger.cs | 22 | Named passenger linked to an account | — |
| AccountTariff | Data/Models/AccountTariff.cs | 30 | Account-specific tariff override | — |
| Booking | Data/Models/Booking.cs | 182 | Core booking entity (~50 properties: addresses, pricing, status, allocation) | — |
| BookingChangeAudit | Data/Models/BookingChangeAudit.cs | 38 | Audit trail for booking field changes | — |
| BookingVia | Data/Models/BookingVia.cs | 37 | Via/waypoint for multi-stop bookings | — |
| COARecord | Data/Models/COARecord.cs | 28 | Chart of accounts record for financial reporting | — |
| CompanyConfig | Data/Models/CompanyConfig.cs | 34 | Tenant company configuration (name, address, VAT, Revolut key) | — |
| CreditNote | Data/Models/CreditNote.cs | 40 | Credit note against an account invoice | — |
| DocumentExpiry | Data/Models/DocumentExpiry.cs | 23 | Tracks driver document expiry dates | — |
| DriverAllocation | Data/Models/DriverAllocation.cs | 25 | Links a driver to a booking (allocation record) | — |
| DriverAvailability | Data/Models/DriverAvailability.cs | 32 | Driver shift/availability time slot | — |
| DriverAvailabilityAudit | Data/Models/DriverAvailabilityAudit.cs | 22 | Audit record for availability changes | — |
| DriverExpense | Data/Models/DriverExpense.cs | 29 | Driver expense claim entity | — |
| DriverInvoiceStatement | Data/Models/DriverInvoiceStatement.cs | 95 | Driver weekly statement (earnings, commission, deductions) | — |
| DriverLocationHistory | Data/Models/DriverLocationHistory.cs | 31 | Historical GPS location record for a driver | — |
| DriverMessage | Data/Models/DriverMessage.cs | 20 | Direct message to/from a driver | — |
| DriverOnShift | Data/Models/DriverOnShift.cs | 24 | Currently on-shift driver record | — |
| DriverShiftLog | Data/Models/DriverShiftLog.cs | 22 | Log entry for shift start/end events | — |
| FixedPriceJourney | Data/Models/FixedPriceJourney.cs | 23 | Predefined fixed-price route | — |
| GeoFence | Data/Models/GeoFence.cs | 18 | Geographic zone boundary definition | — |
| JobOffer | Data/Models/JobOffer.cs | 21 | Pending job offer sent to a driver | — |
| LocalPOI | Data/Models/LocalPOI.cs | 40 | Local point of interest (name, address, lat/lng, categories) | — |
| MessagingNotifyConfig | Data/Models/MessagingNotifyConfig.cs | 45 | Per-event-type messaging channel configuration | — |
| QRCodeClick | Data/Models/QRCodeClick.cs | 19 | QR code scan tracking record | — |
| ReviewRequest | Data/Models/ReviewRequest.cs | 17 | Customer review request record | — |
| Tariff | Data/Models/Tariff.cs | 29 | Tariff rate definition (name, per-mile rate, minimum charge) | — |
| TurnDown | Data/Models/TurnDown.cs | 18 | Record of a driver turning down a job | — |
| UINotification | Data/Models/UINotification.cs | 17 | In-app notification entity | — |
| UrlMapping | Data/Models/UrlMapping.cs | 15 | Short URL to long URL mapping with click counter | — |
| UserActionLog | Data/Models/UserActionLog.cs | 19 | Audit log entry for user actions | — |
| UserProfile | Data/Models/UserProfile.cs | 82 | Driver/user extended profile (vehicle, GPS, FCM, commission rate) | — |
| WebAmendmentRequest | Data/Models/WebAmendmentRequest.cs | 21 | Web booking amendment request from account users | — |
| WebBooking | Data/Models/WebBooking.cs | 74 | Web-submitted booking (pre-dispatch, from account portal) | — |
| ZoneToZonePrice | Data/Models/ZoneToZonePrice.cs | 20 | Zone-based fixed pricing entry | — |

**Model totals:** 38 classes, 1,368 lines total. All models are reasonably sized.

---

## DTOs

| Class/File | File | Lines | Purpose | Flags |
|------------|------|-------|---------|-------|
| GeneralResponseDto | DTOs/.Structure/GeneralResponseDto.cs | 20 | Generic API response wrapper (Success, Error, Value) | — |
| AccountDtos | DTOs/AccountDtos.cs | 58 | Account list/detail DTOs | — |
| AccountProcessingDtos | DTOs/AccountProcessingDtos.cs | 47 | Account invoice processing request/response DTOs | — |
| AddressSuggestion | DTOs/Address/AddressSuggestion.cs | 13 | Autocomplete suggestion DTO | — |
| ResolvedAddress | DTOs/Address/ResolvedAddress.cs | 17 | Fully resolved address DTO (address, postcode, lat/lng) | — |
| DashboardDataDto | DTOs/Admin/DashboardDataDto.cs | 23 | Admin dashboard summary DTO | — |
| DriverOnShiftDto | DTOs/Admin/DriverOnShiftDto.cs | 22 | On-shift driver list item DTO | — |
| GetWebBookingsRequestDto | DTOs/Admin/GetWebBookingsRequestDto.cs | 10 | Web bookings query filter DTO | — |
| AvailabilityDtos | DTOs/Booking/AvailabilityDtos.cs | 194 | Availability report and hours DTOs (multiple classes) | — |
| BookingModels | DTOs/Booking/BookingModels.cs | 324 | Booking-related DTOs: AccountPassengerDto, CreateBookingDto, etc. | [GOD-SERVICE] |
| BookingRequests | DTOs/Booking/BookingRequests.cs | 110 | Booking query/filter request DTOs | — |
| BookingResponses | DTOs/Booking/BookingResponses.cs | 162 | Booking list/detail response DTOs | — |
| DashboardDtos | DTOs/Booking/DashboardDtos.cs | 62 | Booking dashboard data DTOs | — |
| EarningsDtos | DTOs/Booking/EarningsDtos.cs | 204 | Driver earnings and commission DTOs | — |
| InvoiceDtos | DTOs/Booking/InvoiceDtos.cs | 232 | Invoice/statement DTOs for accounts and drivers | — |
| MiscDtos | DTOs/Booking/MiscDtos.cs | 51 | Miscellaneous booking DTOs (allocate, turn-down) | — |
| PricingRequests | DTOs/Booking/PricingRequests.cs | 78 | Pricing calculation request/response DTOs | — |
| WebBookingDtos | DTOs/Booking/WebBookingDtos.cs | 109 | Web booking submission/response DTOs | — |
| CreateGeoFenceDto | DTOs/CreateGeoFenceDto.cs | 22 | GeoFence creation request DTO | — |
| DriverDashDto | DTOs/DriverDashDto.cs | 19 | Driver dashboard summary DTO | — |
| DriverEarningsRequestDto | DTOs/DriverEarningsRequestDto.cs | 14 | Earnings report request DTO | — |
| DriverExpenseDto | DTOs/DriverExpenseDto.cs | 37 | Driver expense submission DTO | — |
| DriverExpensesResponseDto | DTOs/DriverExpensesResponseDto.cs | 12 | Driver expenses list response DTO | — |
| GetAddressResponse | DTOs/GetAddressResponse.cs | 20 | Address lookup response DTO | — |
| LocalPOI Models | DTOs/LocalPOI/Models.cs | 17 | Local POI view model | — |
| LocalPOI Requests | DTOs/LocalPOI/Requests.cs | 33 | Local POI CRUD request DTOs | — |
| ReportDtos | DTOs/ReportDtos.cs | 91 | Reporting DTOs (booking stats, revenue) | — |
| SubmitTicketRequest | DTOs/SubmitTicketRequest.cs | 12 | Support ticket submission DTO | — |
| AuthResult | DTOs/User/AuthResult.cs | 11 | Auth result wrapper DTO | — |
| DriverAvailabilitiesDto | DTOs/User/DriverAvailabilitiesDto.cs | 65 | Driver availability list DTO | — |
| RefreshTokenRequestDto | DTOs/User/Requests/RefreshTokenRequestDto.cs | 14 | JWT refresh token request | — |
| RequestAvailabilityDto | DTOs/User/Requests/RequestAvailabilityDto.cs | 13 | Availability request DTO | — |
| UpdateExpiryDto | DTOs/User/Requests/UpdateExpiryDto.cs | 15 | Document expiry update request | — |
| UpdateFCMRequestDto | DTOs/User/Requests/UpdateFCMRequestDto.cs | 10 | FCM token update request | — |
| UpdateGpsPositionDto | DTOs/User/Requests/UpdateGpsPositionDto.cs | 21 | GPS position update request | — |
| UserLoginRequestDto | DTOs/User/Requests/UserLoginRequestDto.cs | 13 | User login request | — |
| UserRegistrationRequestDto | DTOs/User/Requests/UserRegistrationRequestDto.cs | 44 | User registration request with profile fields | — |
| UserUpdateDetailsRequestDto | DTOs/User/Requests/UserUpdateDetailsRequestDto.cs | 12 | User details partial update request | — |
| UserUpdateRequestDto | DTOs/User/Requests/UserUpdateRequestDto.cs | 42 | Full user update request | — |
| RegistrationLoginResponseDto | DTOs/User/Responses/RegistrationLoginResponseDto.cs | 24 | Registration/login response with token | — |
| UpdateUserDetailsResponseDto | DTOs/User/Responses/UpdateUserDetailsResponseDto.cs | 7 | User details update response | — |
| UsersListResponseDto | DTOs/User/Responses/UsersListResponseDto.cs | 64 | Users list response with driver details | — |
| CachedLocation | DTOs/_Cache/CachedLocation.cs | 13 | Redis-cached driver location DTO | — |
| CachedUserProfile | DTOs/_Cache/CachedUserProfile.cs | 13 | Redis-cached user profile DTO | — |
| EmailTemplates | DTOs/_MessageTemplates/EmailTemplates.cs | 115 | Email template enum + email model classes | — |

**DTO totals:** 45 files, 2,509 lines total.

---

## Domain

| Class | File | Lines | Purpose | Flags |
|-------|------|-------|---------|-------|
| AceRoles | Domain/AceRoles.cs | 11 | Role enum: Admin, User, Driver, Account | [ACE-SPECIFIC] [BAD-NAME] |
| BookingEnums | Domain/BookingEnums.cs | 239 | All booking-related enums (status, scope, payment type, vehicle type, etc.) | — |
| BookingRule | Domain/BookingRule.cs | 366 | Recurrence rule parser and date generator for recurring bookings | [GOD-SERVICE] |
| Constants | Domain/Constants.cs | 38 | Hardcoded airport names list and colour/time constants | [ACE-SPECIFIC] |
| Exceptions | Domain/Exceptions.cs | 9 | Custom NotFoundException | — |
| IdealPostcodesClient | Domain/IdealPostcodesClient.cs | 482 | HTTP client for Ideal Postcodes address lookup API | [GOD-SERVICE] |
| JourneyCount | Domain/JourneyCount.cs | 10 | Simple DTO: passenger name, pickup, AM/PM counts | — |
| LatLong | Domain/LatLong.cs | 14 | Latitude/Longitude value object | — |
| ModelValidator | Domain/ModelValidator.cs | 110 | Base class with DataAnnotations validation support | — |
| Result\<T\> / Result | Domain/Result.cs | 337 | Generic operation result monad (Ok/Fail pattern) | [GOD-SERVICE] |

---

## Interfaces

| Interface | File | Lines | Purpose | Flags |
|-----------|------|-------|---------|-------|
| IAddressLookupService | Interfaces/IAddressLookupService.cs | 18 | Address search and resolution contract | [SINGLE-IMPL-INTERFACE] |
| IBookingModel | Interfaces/IBooking.cs | 57 | Booking entity shape contract (used by Booking + BookingFormModel) | — |
| IPersistedBookingModel | Interfaces/IBooking.cs | — | Persisted booking fields contract (driver, colour, userId) | — |
| IGetBookingsRequestDto | Interfaces/IDTOs.cs | 30 | Booking query request shape | — |
| IListedUser | Interfaces/IDTOs.cs | — | User list item shape (includes AceRoles reference) | [ACE-SPECIFIC] |
| IUserLocation | Interfaces/IDTOs.cs | — | GPS location shape | — |
| IModelValidator | Domain/ModelValidator.cs | — | Validation contract (in Domain, not Interfaces folder) | — |
| IMessageService | Modules/Messaging/Services/MessageService.cs | — | Email/SMS messaging contract | — |
| IPushNotificationService | Modules/Messaging/Services/PushNotificationService.cs | — | FCM push notification contract | — |
| IAuthenticationService | Modules/Membership/Services/AuthenticationService.cs | — | JWT auth contract | — |
| IUsersService | Modules/Membership/Services/UsersService.cs | — | Identity user management contract | — |
| IDriverInvoiceStatement | Data/Models/DriverInvoiceStatement.cs | — | Driver statement shape (defined in model file) | — |

---

## Modules / Membership

| Class | File | Lines | Purpose | Flags |
|-------|------|-------|---------|-------|
| AuthorizeAttribute | Modules/Membership/AuthorizationAttribute.cs | 48 | Custom JWT authorization filter attribute | — |
| JwtConfig | Modules/Membership/JwtConfig.cs | 24 | JWT settings POCO (Key, Issuer, ExpiryDays) | — |
| JwtMiddleware | Modules/Membership/JwtMiddleware.cs | 80 | Middleware that validates JWT and sets HttpContext.Items["User"] | — |
| RegisterUserRequestDto | Modules/Membership/DTO/Requests.cs | 56 | Registration + auth request DTOs (multiple classes) | — |
| AuthenticateResponse | Modules/Membership/DTO/Responses.cs | 42 | Auth response DTOs (token, user info) | — |
| AppRefreshToken | Modules/Membership/Models/AppRefreshToken.cs | 19 | Refresh token entity | — |
| AppRole | Modules/Membership/Models/AppRole.cs | 11 | Identity role entity | — |
| AppUser | Modules/Membership/Models/AppUser.cs | 13 | Identity user entity (adds FullName) | — |
| AuthenticationService | Modules/Membership/Services/AuthenticationService.cs | 243 | JWT token generation, refresh, and validation | — |
| UsersService | Modules/Membership/Services/UsersService.cs | 144 | Identity user CRUD, role management, lockout | — |

## Modules / Messaging

| Class | File | Lines | Purpose | Flags |
|-------|------|-------|---------|-------|
| MessagingConfig | Modules/Messaging/Config/MessagingConfig.cs | 45 | Messaging config POCO (SMS, Email, Push, Twilio settings) | — |
| PushNotificationRequest | Modules/Messaging/DTO/Requests.cs | 39 | FCM push + SMS request DTOs | — |
| MessageService | Modules/Messaging/Services/MessageService.cs | 255 | SendGrid email, Twilio SMS, SMTP email sender | — |
| PushNotificationService | Modules/Messaging/Services/PushNotificationService.cs | 80 | Firebase FCM push notification sender | — |

---

## PDF

| Class | File | Lines | Purpose | Flags |
|-------|------|-------|---------|-------|
| AccountInvoiceDocument | PDF/AccountInvoiceDocument.cs | 242 | QuestPDF account invoice generator | — |
| AccountCreditNoteDocument | PDF/AccountCreditNoteDocument.cs | 251 | QuestPDF credit note generator | — |
| DriverStatementDocument | PDF/DriverStatementDocument.cs | 256 | QuestPDF driver weekly statement generator | — |
| PaymentReceipt | PDF/PaymentReceipt.cs | 157 | QuestPDF payment receipt generator | [ACE-SPECIFIC] |

---

## Integrations

| Class | File | Lines | Purpose | Flags |
|-------|------|-------|---------|-------|
| AWSConfig | Integrations/Aws/AWSConfig.cs | 15 | AWS S3 configuration POCO | — |
| AmazonAWSService | Integrations/Aws/AmazonAWSService.cs | 124 | AWS S3 file upload/download service | — |

---

## Configuration

| Class | File | Lines | Purpose | Flags |
|-------|------|-------|---------|-------|
| DictionaryToJsonConverter | Configuration/DictionaryToJsonConverter.cs | 27 | EF Core value converter for Dictionary\<string,string\> to JSON | — |
| DictionaryValueComparer | Configuration/DictionaryToJsonConverter.cs | — | EF Core value comparer for the above | — |
| DropBoxConfig | Configuration/DropBoxConfig.cs | 46 | Dropbox API config POCO with refresh token persistence | — |
| SimpleFileLogger | Configuration/SimpleFileLogger.cs | 60 | Basic file-based ILogger implementation | — |
| SimpleFileLoggerProvider | Configuration/SimpleFileLoggerProvider.cs | 21 | ILoggerProvider for SimpleFileLogger | — |

---

## Shared

| Class | File | Lines | Purpose | Flags |
|-------|------|-------|---------|-------|
| MiddlewareInitializer | Shared/OneSoftExtensions.cs | 238 | Static extension methods for app and service builder DI registration | [BAD-NAME] |
| ResponseDTO | Shared/ResponseDTO.cs | 20 | Generic API response DTO (Success, Errors, Result) | — |

---

## Miscellaneous

| Class | File | Lines | Purpose | Flags |
|-------|------|-------|---------|-------|
| DateTimeExtensions | ExtensionMethods.cs | 79 | Extension methods: ToUKTime, To2359, StartOfWeek, RemoveExtraSpaces, Substring | — |
| Annotations | Annotations.cs | 1038 | JetBrains ReSharper annotation attributes (vendored) | — |
| PostcodeLookup | PostcodeLookup.cs | 150 | getAddress.io UK postcode lookup client | — |
| BookingFormModel | FormModels/BookingFormModel.cs | 90 | Blazor/form model for booking entry (used by desktop app) | — |

---

## Flagged Items Summary

### [GOD-SERVICE] — Over 300 lines (10 items)

| Class | Lines | Priority |
|-------|-------|----------|
| AccountsService | 2313 | CRITICAL |
| BookingService | 2186 | CRITICAL |
| ReportingService | 1263 | HIGH |
| UserProfileService | 1066 | HIGH |
| DispatchService | 1025 | HIGH |
| AceMessagingService | 883 | HIGH |
| TariffService | 716 | MEDIUM |
| IdealPostcodesClient | 482 | MEDIUM |
| AvailabilityService | 493 | MEDIUM |
| ScheduleData | 417 | LOW |
| UserActionsService | 379 | LOW |
| BookingRule | 366 | LOW |
| Result\<T\> | 337 | LOW |
| BookingModels (DTOs) | 324 | LOW |

### [ACE-SPECIFIC] — Hardcoded Ace Taxis logic (8 items)

| Class | Issue |
|-------|-------|
| AceMessagingService | Hardcoded Ace Taxis email addresses, SMTP creds, email subjects |
| RevoluttService | Hardcoded production Revolut API key (security risk!) |
| TariffService | Hardcoded BasePostcode "SP8 4PZ" (Ace HQ) |
| GoogleCalendarService | Hardcoded Calendar ID and ApplicationName "Ace" |
| Constants | Hardcoded UK airport list (Ace service area) |
| AceRoles | Enum named "AceRoles" — should be generic tenant roles |
| MockData | Hardcoded SP8 4PZ postcode and Ace-specific test data |
| PaymentReceipt | Hardcoded "acetaxisdorset.co.uk" in PDF output |

### [SINGLE-IMPL-INTERFACE] (1 item)

| Interface | Implementation |
|-----------|---------------|
| IAddressLookupService | AddressLookupService (only impl, no test injection observed) |

### [DEAD] — Appears unused (1 item)

| Class | Reason |
|-------|--------|
| MessagingCacheService | Empty class — 0 methods, 0 references |

### [BAD-NAME] — Naming concerns (3 items)

| Class | Issue |
|-------|-------|
| RedTaxiDbContext | File is named AceDbContext.cs but class is RedTaxiDbContext |
| AceRoles | Tenant-specific name for a generic concept |
| MiddlewareInitializer (OneSoftExtensions.cs) | File named after previous company; class is static partial |

---

## Security Issues

| File | Issue | Severity |
|------|-------|----------|
| RevoluttService.cs:15 | Production Revolut API key hardcoded in source | CRITICAL |
| AceMessagingService.cs:95 | SMTP password hardcoded in source | HIGH |
| GoogleCalendarService.cs:12 | Calendar ID hardcoded | MEDIUM |

These secrets must be moved to configuration/secrets management before multi-tenancy.

---

## Recommended Refactor Order

1. **Extract secrets** from RevoluttService, AceMessagingService, GoogleCalendarService into configuration
2. **Split AccountsService** (2313 lines) into: AccountCrud, InvoiceGeneration, BillingProcess, CreditNotes
3. **Split BookingService** (2186 lines) into: BookingCrud, BookingScheduler, WebBookingHandler, BookingAmendments
4. **Split ReportingService** (1263 lines) into: DriverEarningsReport, AccountReport, BookingStatsReport
5. **Split UserProfileService** (1066 lines) into: UserProfileCrud, DriverGps, DriverDocuments
6. **Split DispatchService** (1025 lines) into: AllocateBooking, JobOfferHandler, DispatchQueries
7. **Rename AceRoles** to TenantRoles or just Roles
8. **Rename AceDbContext.cs** file to RedTaxiDbContext.cs to match class name
9. **Delete MessagingCacheService** (dead code)
10. **Move IdealPostcodesClient** from Domain/ to Infrastructure/ (it is an external integration)
