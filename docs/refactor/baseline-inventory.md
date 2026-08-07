# Baseline Endpoint Inventory

Generated: 2026-03-24 | Phase 0

## Summary

- Total Controllers: 16
- Total Endpoints: 153

## Endpoints by Controller

---

### AccountsController

**Route prefix:** `api/Accounts`
**Auth:** Per-endpoint (noted below)

| Method | Route | Action | Service Method Called | Auth |
|--------|-------|--------|---------------------|------|
| GET | api/Accounts/GetAccountTariffs | GetAccountTariffs | AccountsService.GetAccountTariffs | No |
| POST | api/Accounts/CreateOrUpdateAccountTariff | CreateOrUpdateAccountTariff | AccountsService.CreateOrUpdateAccountTariff | No |
| POST | api/Accounts/AddOrUpdateZonePrice | AddOrUpdateZonePrice | GeoZoneService.AddZonePrice / GeoZoneService.UpdateZonePrice | No |
| GET | api/Accounts/GetZonePrices | GetZonePrices | GeoZoneService.GetZonePrices | No |
| GET | api/Accounts/GetList | GetAccountsList | AccountsService.GetAllAccounts | [Authorize] |
| POST | api/Accounts/PostOrUnPostJobsAccountDriver | PostOrUnPostJobsAccountDriver | AccountsService.PostJob, AccountsService.PostJobDriver | No |
| POST | api/Accounts/DriverPriceJobByMileage | DriverPriceJobByMileage | AccountsService.PriceBookingByMileage | [Authorize] |
| POST | api/Accounts/DriverPostOrUnPostJobs | DriverPostOrUnPostJobs | AccountsService.PostJobDriver | No |
| POST | api/Accounts/DriverGetChargableJobs | DriverGetChargableJobs | AccountsService.GetChargableJobsForDriver | No |
| POST | api/Accounts/DriverUpdateChargesData | DriverUpdateChargesData | AccountsService.UpdateChargesDataDriver | No |
| POST | api/Accounts/DriverCreateStatments | DriverCreateStatements | AccountsService.ProcessDrivers | No |
| POST | api/Accounts/DriverGetStatments | DriverGetStatments | AccountsService.GetStatements, AccountsService.GetDriverNameColor | No |
| GET | api/Accounts/ResendDriverStatement | ResendDriverStatement | AccountsService.ResendDriverStatement | No |
| GET | api/Accounts/MarkStatementAsPaid | MarkStatementAsPaid | AccountsService.MarkStatementPaid | No |
| POST | api/Accounts/AccountPriceManually | AccountPriceManually | AccountsService.ManualPriceAccountUpdate | No |
| POST | api/Accounts/AccountPriceJobByMileage | AccountPriceJobByMileage | AccountsService.PriceBookingByMileageAccount | No |
| POST | api/Accounts/AccountPriceJobHVS | AccountPriceJobHVS | AccountsService.UpdateGetAccPriceHVS | No |
| POST | api/Accounts/PriceBulk | PriceBulk | AccountsService.UpdatePricesHVSBulk / AccountsService.UpdatePricesBulk | No |
| POST | api/Accounts/AccountPriceJobHVSBulk | AccountPriceJobHVSBulk | AccountsService.UpdatePricesHVSBulk | No |
| POST | api/Accounts/AccountPostOrUnPostJobs | AccountPostOrUnPostJobs | AccountsService.PostJob | No |
| POST | api/Accounts/AccountGetChargableJobs | AccountGetChargableJobs | AccountsService.GetChargableJobsForAccount | No |
| POST | api/Accounts/AccountGetChargableJobsGroupedSplit | AccountGetChargableJobsGroupedSplit | AccountsService.GetChargableJobsForAccount, AccountsService.GroupBidirectionalByPassenger, AccountsService.GroupByBirectionalJourney | No |
| POST | api/Accounts/AccountGetChargableJobsGrouped | AccountGetChargableJobsGrouped | AccountsService.GetChargableJobsForAccount, AccountsService.GroupBidirectionalByPassenger | No |
| POST | api/Accounts/AccountUpdateChargesData | AccountUpdateChargesData | AccountsService.UpdateChargesDataAcc | No |
| POST | api/Accounts/AccountCreateInvoice | AccountCreateInvoice | AccountsService.ProcessAccounts | No |
| GET | api/Accounts/MarkInvoiceAsPaid | MarkInvoiceAsPaid | AccountsService.MarkInvoicePaid | No |
| GET | api/Accounts/DeleteInvoice, api/Accounts/ClearInvoice, api/Accounts/CreditInvoice | CreditInvoice | AccountsService.CreditInvoice | [Authorize] |
| POST | api/Accounts/CreditJourneys | CreditJourneys | AccountsService.GenerateSendCreditNotePDF | [Authorize] |
| GET | api/Accounts/GetCreditNotes | GetCreditNotes | AccountsService.GetCreditNotes | No |
| GET | api/Accounts/DownloadCreditNote | GetCreditNote | Direct file serve (Data\CreditNotes) | No |
| GET | api/Accounts/GetInvoices | GetInvoices | AccountsService.GetInvoices | No |
| GET | api/Accounts/DownloadInvoice | GetInvoice | Direct file serve (Data\Invoices) | No |
| GET | api/Accounts/DownloadStatement | GetStatement | Direct file serve (Data\Statements) | No |
| GET | api/Accounts/DownloadInvoiceCSV | GetInvoiceCSV | AccountsService.GenerateInvoiceCSV | No |
| GET | api/Accounts/ResendInvoice | ReSendInvoice | AccountsService.ResendAccountInvoice | No |
| POST | api/Accounts/VATOutputs | VATOutputs | AccountsService.CalculateVatOutputs | No |

**Endpoints: 35**

---

### AddressController

**Route prefix:** `api/Address`
**Auth:** None

| Method | Route | Action | Service Method Called | Auth |
|--------|-------|--------|---------------------|------|
| GET | api/Address/DispatchSearch | DispatchSearch | IAddressLookupService.GetPoisForDispatch, IAddressLookupService.IdealSearchAddress | No |
| GET | api/Address/WebBookerSearch | WebBookerSearch | IAddressLookupService.IdealSearchAddress | No |
| GET | api/Address/Resolve | Resolve | IAddressLookupService.ResolvePOIAsync / ResolveGooglePlaceAsync / ResolveIdealAddressAsync | No |
| GET | api/Address/PostcodeLookup | PostcodeLookup | IAddressLookupService.IdealPostcodeSearch | No |
| GET | api/Address/IdealSearch | Ideal | IAddressLookupService.IdealSearchAddress | No |
| GET | api/Address/IdealPostcode | IdealPostcode | IAddressLookupService.IdealPostcodeSearch | No |

**Endpoints: 6**

---

### AdminUIController

**Route prefix:** `api/AdminUI`
**Auth:** Per-endpoint (noted below)

| Method | Route | Action | Service Method Called | Auth |
|--------|-------|--------|---------------------|------|
| GET | api/AdminUI/Move9014To10026 | Move9014To10026 | Direct DB queries (Bookings, LocalPOIs) | No |
| POST | api/AdminUI/SendMessageToDriver | SendMessageToDriver | AdminUIService.SendDriverMessage | [Authorize] |
| POST | api/AdminUI/SendMessageToAllDrivers | SendMessageToAllDrivers | AdminUIService.SendAllDriversMessage | [Authorize] |
| GET | api/AdminUI/Dashboard | GetDashData | AdminUIService.GetDashData | [Authorize] |
| GET | api/AdminUI/GetSMSHeartBeat | GetHeartbeat | AdminUIService.GetSMSHeartBeat | [Authorize] |
| GET | api/AdminUI/DriversOnShift | DriversOnShift | AvailabilityService.GetOnShiftDrivers | No |
| POST | api/AdminUI/DriverEarningsReport | DriverEarningsReport | AccountsService.GetEarningsWithinRange | No |
| POST | api/AdminUI/DriverExpenses | DriverExpenses | Direct DB query (DriverExpenses) | No |
| GET | api/AdminUI/DriversList | DriversList | UserProfileService.ListUsersAll | No |
| POST | api/AdminUI/DriverAdd | DriverAdd | UserProfileService.Create | No |
| POST | api/AdminUI/DriverUpdate | DriverUpdate | UserProfileService.GetProfile, UpdateProfile, AddUserToRole, RemoveUserFromRole | No |
| POST | api/AdminUI/DriverDelete | DriverDelete | UserProfileService.SetProfileDeleted | No |
| GET | api/AdminUI/DriverResendLogin | DriverResendLogin | UserProfileService.ChangePassword | No |
| GET | api/AdminUI/DriverShowAllJobs | DriverShowAllJobs | UserProfileService.ShowAllOnOff | No |
| GET | api/AdminUI/DriverShowHVSJobs | DriverShowHVSJobs | UserProfileService.ShowHVSOnOff | No |
| GET | api/AdminUI/DriverLockout | DriverLockout | UserProfileService.LockoutOnOff | No |
| GET | api/AdminUI/GetDriverExpirys | DriverExpirys | Direct DB query (DocumentExpirys, UserProfiles) | No |
| POST | api/AdminUI/UpdateDriverExpiry | UpdateDriverExpiry | Direct DB query (DocumentExpirys) | No |
| POST | api/AdminUI/BookingsByStatus | DriverEarningsReport (overload) | BookingService.GetCancelledJobs / GetCompletedJobs / GetAllocatedJobs / GetUnallocatedJobs | No |
| GET | api/AdminUI/AirportRuns | AirportRuns | BookingService.GetAirportRuns | No |
| GET | api/AdminUI/BookingAudit | BookingAudit | BookingService.GetAuditLog | No |
| GET | api/AdminUI/CardBookings | CardBookings | BookingService.GetActiveCardJobs | No |
| POST | api/AdminUI/SendCardPaymentReminder | SendCardPaymentReminder | BookingService.GetPaymentLink, AceMessagingService.SendPaymentLinkReminderSMS | No |
| POST | api/AdminUI/CancelBookingsInRange | CancelBookingsInRange | BookingService.CancelBookingsByDateRange | [Authorize] |
| POST | api/AdminUI/CancelBookingsInRangeReport | CancelBookingsInRangeReport | BookingService.CancelBookingsByDateRangeReport | [Authorize] |
| POST | api/AdminUI/GetTurndowns | GetTurndowns | Direct DB query (TurnDowns) | No |
| POST | api/AdminUI/AddAccount | AddAccount | AccountsService.CreateAccount | No |
| POST | api/AdminUI/UpdateAccount | UpdateAccount | AccountsService.UpdateAccount | No |
| GET | api/AdminUI/DeleteAccount | DeleteAccount | AccountsService.DeleteAccount | No |
| GET | api/AdminUI/GetAccounts | GetAccounts | AccountsService.GetAllAccounts | No |
| POST | api/AdminUI/RegisterAccountWebBooker | RegisterAccountWebBooker | UserProfileService.CreateAccountUser | No |
| GET | api/AdminUI/AvailabilityLog | AvailabilityLog | AvailabilityService.GetAuditLog | No |
| GET | api/AdminUI/GetAvailability | GetAvailability | AvailabilityService.GetAvailabilities | No |
| GET | api/AdminUI/DeleteAvailability | DeleteAvailability | AvailabilityService.Delete | [Authorize] |
| POST | api/AdminUI/SetAvailability | SetAvailability | AvailabilityService.Create | [Authorize] |
| POST | api/AdminUI/AvailabilityReport | AvailabilityReport | AvailabilityService.GetAvailabilityForPeriod | [Authorize] |
| POST | api/AdminUI/AddPOI | AddPOI | LocalPOIService.CreatePOI | No |
| POST | api/AdminUI/UpdatePOI | UpdatePOI | LocalPOIService.UpdatePOI | No |
| GET | api/AdminUI/DeletePOI | DeletePOI | LocalPOIService.DeletePOI | No |
| GET | api/AdminUI/GetPOIs | GetPOIs | LocalPOIService.GetLocalPOI | No |
| GET | api/AdminUI/GetMessageConfig | GetMessageConfig | Direct DB query (MessagingNotifyConfig) | No |
| POST | api/AdminUI/UpdateMessageConfig | UpdateMessageConfig | Direct DB query (MessagingNotifyConfig) | No |
| GET | api/AdminUI/GetCompanyConfig | GetCompanyConfig | Direct DB query (CompanyConfig) | No |
| POST | api/AdminUI/UpdateCompanyConfig | AddCompanyConfig | Direct DB query (CompanyConfig) | No |
| GET | api/AdminUI/GetTariffConfig | GetTariffConfig | TariffService.GetAllTariffs | No |
| POST | api/AdminUI/SetTariffConfig | SetTariffConfig | TariffService.Update | No |
| GET | api/AdminUI/GetNotifications | GetNotifications | AdminUIService.GetNotifications | No |
| GET | api/AdminUI/ClearNotification | ClearNotification | AdminUIService.ClearNotification | No |
| GET | api/AdminUI/ClearAllNotifications | ClearAllNotification | AdminUIService.ClearAllNotifications | No |
| POST | api/AdminUI/ClearAllNotifications | ClearAllNotificationbyType | AdminUIService.ClearAllNotificationByType | No |
| POST | api/AdminUI/UpdateBrowserFCM | UpdateBrowserFCM | Direct DB query (UserProfiles) | [Authorize] |
| POST | api/AdminUI/GetBrowserFCMs | GetBrowserFCMs | Direct DB query (UserProfiles), AceMessagingService.SendBrowserNotification | No |
| POST | api/AdminUI/RemoveBrowserFCM | RemoveBrowserFCM | Direct DB query (UserProfiles) | [Authorize] |
| GET | api/AdminUI/GetWebChangeRequests | GetWebChangeRequests | Direct DB query (WebAmendmentRequests, Bookings) | No |
| GET | api/AdminUI/UpdateWebChangeRequest | UpdateWebChangeRequests | Direct DB query (WebAmendmentRequests) | No |
| POST | api/AdminUI/SubmitTicket | SubmitTicket | AceMessagingService.SendEmailRaiseTicket | No |

**Endpoints: 55**

---

### ATestController

**Route prefix:** `api/ATest`
**Auth:** None

| Method | Route | Action | Service Method Called | Auth |
|--------|-------|--------|---------------------|------|
| GET | api/ATest/test | Ping | None (returns "pong") | No |

**Endpoints: 1**

---

### AvailabilityController

**Route prefix:** `api/Availability`
**Auth:** Per-endpoint

| Method | Route | Action | Service Method Called | Auth |
|--------|-------|--------|---------------------|------|
| GET | api/Availability/General | GetGeneralAvailability | AvailabilityService.GetGeneralAvailability | [Authorize] |
| GET | api/Availability/Reminder | SendReminder | AceMessagingService.SendDriverAvailabilityReminderSMS | No (key-gated) |

**Endpoints: 2**

---

### BookingsController

**Route prefix:** `api/Bookings`
**Auth:** Per-endpoint (noted below)

| Method | Route | Action | Service Method Called | Auth |
|--------|-------|--------|---------------------|------|
| GET | api/Bookings/Today | GetBookingsToday | (calls GetBookings internally) BookingService.GetBookings | [Authorize] |
| GET | api/Bookings/FindByTerm | FindByTerm | BookingService.KeywordSearch | [Authorize] |
| POST | api/Bookings/FindBookings | FindBookings | BookingService.FindBookings | No |
| GET | api/Bookings/FindById | GetById | BookingService.GetBooking | [Authorize] |
| POST | api/Bookings/DateRange | GetBookings | BookingService.GetBookings | [Authorize] |
| POST | api/Bookings/Cancel | CancelBooking | BookingService.CancelBooking, BookingService.GetCancelBookingEmailData, AceMessagingService.SendAccountBookingCancelledEmail | [Authorize] |
| POST | api/Bookings/RemoveCOA | RemoveCancellOnArrival | BookingService.RemoveCancellOnArrival | [Authorize] |
| POST | api/Bookings/Update | UpdateBooking | BookingService.UpdateBooking | [Authorize] |
| POST | api/Bookings/UpdateDate | UpdateBookingDate | BookingService.UpdateBookingDate | [Authorize] |
| POST | api/Bookings/Create | CreateBooking | BookingService.CreateBooking | [Authorize] |
| POST | api/Bookings/RankCreate | RankPickup | (calls CreateBooking internally) BookingService.CreateBooking | [Authorize] |
| POST | api/Bookings/CancelByDateRange | CancelJobsByDateRange | BookingService.CancelBookingsByDateRange | [Authorize] |
| GET | api/Bookings/PickupHistory | GetPickupHistory | BookingService.GetPickupAddressHistory | [Authorize] |
| POST | api/Bookings/SoftAllocate | SoftAllocate | BookingService.SoftAllocate | [Authorize] |
| POST | api/Bookings/ConfirmAllSoftAllocates | ConfirmAllSoftAllocates | BookingService.SoftAllocateConfirmAll, (calls Allocate internally) | [Authorize] |
| POST | api/Bookings/RestoreCancelled | RestoreCancelled | BookingService.RestoreCancelledJob | [Authorize] |
| POST | api/Bookings/Allocate | Allocate | DispatchService.AllocateBooking | [Authorize] |
| POST | api/Bookings/GetPrice | GetPrice | TariffService.GetPriceHVS / Get9999CashPrice / GetOnInvoicePrices | No |
| POST | api/Bookings/UpdateQuote | UpdateQuote | AccountsService.PriceBookingByMileage | [Authorize] |
| POST | api/Bookings/ManualPrice | ManualPriceUpdate | AccountsService.ManualPriceUpdate | [Authorize] |
| POST | api/Bookings/Complete | Complete | DispatchService.Complete | [Authorize] |
| GET | api/Bookings/SendConfirmationText | SendCustomerConfirmation | AceMessagingService.SendCustomerOnBookedSMS | [Authorize] |
| GET | api/Bookings/PaymentLink | SendPaymentLink | RevoluttService.CreateOrder, AceMessagingService.ShorternUrl, BookingService.SetScope / SetPaymentStatus / SetPaymentOrderId, AceMessagingService.SendPaymentLinkSMS / SendPaymentLinkEmail | No |
| GET | api/Bookings/ReminderPaymentLink | ResendPaymentLink | BookingService.GetPaymentLink, AceMessagingService.SendPaymentLinkReminderSMS | [Authorize] |
| GET | api/Bookings/RefundPayment | RefundPayment | BookingService.GetPaymentOrderId, RevoluttService.RefundOrder, BookingService.SetPaymentStatus / SetPaymentOrderId | [Authorize] |
| GET | api/Bookings/UpdatePaymentStatus | UpdatePaymentStatus | BookingService.GetPaymentIds, RevoluttService.GetOrderStatus, BookingService.UpdatePaymentStatus | No |
| POST | api/Bookings/SendQuote | SendQuote | TariffService.Get9999CashPrice, AceMessagingService.SendCustomerQuoteEmail / SendCustomerQuoteSMS | [Authorize] |
| GET | api/Bookings/SendPaymentReceipt | SendPaymentReceipt | BookingService.GetScope, BookingService.CreateAndSendPaymentReceipt | [Authorize] |
| GET | api/Bookings/DownloadReceipt | GetPaymentReceipt | Direct file serve (Data\Receipts) | No |
| GET | api/Bookings/CreateRevWebHook | CreateRevoluttWebHook | RevoluttService.CreateWebHook | No |
| GET | api/Bookings/ClearRevWebHooks | ClearRevoluttWebHooks | RevoluttService.GetWebHookList, RevoluttService.DeleteWebHook | No |
| POST | api/Bookings/RevPaymentUpdate | RevPaymentUpdate | BookingService.UpdatePaymentStatus | No |
| GET | api/Bookings/RecordTurnDown | RecordTurnDown | BookingService.RecordTurnDown | [Authorize] |
| GET | api/Bookings/GetActionLogs | GetActionLogs | UserActionsService.GetLogs | No |
| GET | api/Bookings/GetDuration | GetDuration | TariffService.Get9999CashPrice | No |
| GET | api/Bookings/MergeBookings | MergeBookings | BookingService.MergeBookings | No |
| POST | api/Bookings/CreateCOAEntry | CreateCOAEntry | BookingService.RecordCOAEntry | No |
| GET | api/Bookings/GetCOAEntrys | GetCOAEntrys | BookingService.GetCOAEntrys | No |
| GET | api/Bookings/test | TestLog | None (logger test) | No |

**Endpoints: 39**

---

### CallEventsController

**Route prefix:** `api/CallEvents`
**Auth:** None

| Method | Route | Action | Service Method Called | Auth |
|--------|-------|--------|---------------------|------|
| GET | api/CallEvents/CallNotification | CallNotification | Direct DB queries (Bookings), Pusher trigger | No |
| GET | api/CallEvents/LookupNumber | LookupByNumber | (calls CallNotification internally) | No |
| GET | api/CallEvents/LookupEmail | LookupByEmail | None (returns email) | No |
| GET | api/CallEvents/CallerLookup | CallNotificationLookup | Direct DB queries (Bookings) | No |
| POST | api/CallEvents/Create | Create | (calls CallNotification internally) | No |
| GET | api/CallEvents/GetCustomerByEmail | GetCustomerByEmail | None (stub) | No |

**Endpoints: 6**

---

### DriverAppController

**Route prefix:** `api/DriverApp`
**Auth:** Per-endpoint (noted below)

| Method | Route | Action | Service Method Called | Auth |
|--------|-------|--------|---------------------|------|
| GET | api/DriverApp/GetProfile | GetProfile | UserProfileService.FindByName, Direct DB query (UserProfiles) | [Authorize] |
| GET | api/DriverApp/RetrieveJobOffer | RetrieveJobOffer | DispatchService.GetJobOfferEntry | No |
| GET | api/DriverApp/RefreshJobOffers | RefreshJobOffers | DispatchService.RefreshJobOffers | No |
| GET | api/DriverApp/GetJobOffers | GetJobOffers | DispatchService.GetJobOffers | [Authorize] |
| GET | api/DriverApp/JobOfferReply | JobOfferReply | DispatchService.GetJobOfferEntry, DispatchService.AcceptReject, DispatchService.DeleteJobOfferEntry | No |
| GET | api/DriverApp/NoJob | JobStatusReply (NoJob) | UINotificationService.AddNoJobNotification | [Authorize] |
| GET | api/DriverApp/GetOnShiftStatus | GetOnShiftStatus | DispatchService.GetOnShiftStatus | No |
| GET | api/DriverApp/JobStatusReply | JobStatusReply | DispatchService.UpdateJobStatus | No |
| GET | api/DriverApp/DashTotals | DashTotals | ReportingService.DriverLoadTodaysTotals / DriverLoadWeeksTotals / DriverLoadMonthsTotals | [Authorize] |
| GET | api/DriverApp/DriverShift | DriverShift | DispatchService.DriverShift | No |
| POST | api/DriverApp/CompleteJob | Complete | DispatchService.Complete | [Authorize] |
| POST | api/DriverApp/UpdateGPS | UpdateUserGPS | UserProfileService.FindById, UserProfileService.UpdateGpsPosition | [Authorize] |
| POST | api/DriverApp/UpdateFCM | UpdateFCM | UserProfileService.FindByName, UserProfileService.UpdateFCMToken | [Authorize] |
| GET | api/DriverApp/TodaysJobs | TodayJobs | BookingService.GetBookingsByDriver | [Authorize] |
| GET | api/DriverApp/FutureJobs | FutureJobs | BookingService.GetBookingsByDriver | [Authorize] |
| GET | api/DriverApp/CompletedJobs | CompletedJobs | Direct DB query (Bookings) | [Authorize] |
| POST | api/DriverApp/DateRange | GetBookings | BookingService.GetBookingsByDriver | [Authorize] |
| GET | api/DriverApp/Earnings | Earnings | AccountsService.GetDailyEarningsWithinRange | [Authorize] |
| GET | api/DriverApp/Statements | Statements | AccountsService.GetStatements | [Authorize] |
| GET | api/DriverApp/Availabilities | GetAvailabilities | AvailabilityService.GetAvailabilities | [Authorize] |
| POST | api/DriverApp/SetAvailability | SetAvailability | AvailabilityService.Create | [Authorize] |
| GET | api/DriverApp/DeleteAvailability | DeleteAvailability | AvailabilityService.Delete | [Authorize] |
| GET | api/DriverApp/Arrived | Arrived | Direct DB queries, AceMessagingService.SendCustomerArrivedSMS, DispatchService.UpdateJobStatus | [Authorize] |
| POST | api/DriverApp/AddExpense | AddExpense | UserProfileService.AddDriverExpense | [Authorize] |
| GET | api/DriverApp/GetExpenses | GetExpenses | UserProfileService.GetDriverExpenses | [Authorize] |
| POST | api/DriverApp/UploadDocument | UploadDocument | DocumentService.UploadDocument | [Authorize] |
| POST | api/DriverApp/SetActiveJob | SetActiveJob | Direct DB query (DriversOnShift) | [Authorize] |
| GET | api/DriverApp/GetActiveJob | GetActiveJob | Direct DB query (DriversOnShift) | [Authorize] |
| GET | api/DriverApp/GetStatementHeaders | GetStatementHeaders | Direct DB query (DriverInvoiceStatements) | [Authorize] |

**Endpoints: 29**

---

### LocalPOIController

**Route prefix:** `api/LocalPOI`
**Auth:** Per-endpoint (noted below)

| Method | Route | Action | Service Method Called | Auth |
|--------|-------|--------|---------------------|------|
| POST | api/LocalPOI/GetPOI | GetLocalPOI | LocalPOIService.GetLocalPOI | No |
| POST | api/LocalPOI/GetPOI2 | GetAddressWithPOI | LocalPOIService.GetLocalPOI | No |
| POST | api/LocalPOI/Create | CreateLocalPOI | LocalPOIService.CreatePOI | [Authorize] |
| POST | api/LocalPOI/Update | UpdateLocalPOI | LocalPOIService.UpdatePOI | [Authorize] |
| POST | api/LocalPOI/Delete | DeleteLocalPOI | LocalPOIService.DeletePOI | [Authorize] |
| POST | api/LocalPOI/Upload | Post | LocalPOIService.ImportCsv | No |

**Endpoints: 6**

---

### QRCodeClickCounter

**Route prefix:** `qrcode/{location}`
**Auth:** None

| Method | Route | Action | Service Method Called | Auth |
|--------|-------|--------|---------------------|------|
| GET | qrcode/{location} | RedirectToLongUrl | UrlTrackingService.RecordQRCodeClick | No |

**Endpoints: 1**

---

### RedirectController

**Route prefix:** `/u/{shortCode}`
**Auth:** None

| Method | Route | Action | Service Method Called | Auth |
|--------|-------|--------|---------------------|------|
| GET | /u/{shortCode} | RedirectToLongUrl | UrlTrackingService.ResolveAndTrackShortUrl | No |

**Endpoints: 1**

---

### ReportingController

**Route prefix:** `api/Reporting`
**Auth:** None

| Method | Route | Action | Service Method Called | Auth |
|--------|-------|--------|---------------------|------|
| POST | api/Reporting/DuplicateBookingsReport | DuplicateBookingsReport | ReportingService.DuplicateBookingsReport | No |
| POST | api/Reporting/GetBookingScopeBreakdown | GetBookingScopeBreakdown | ReportingService.GetBookingScopeBreakdownAsync | No |
| POST | api/Reporting/GetTopCustomers | GetTopCustomers | ReportingService.GetTopCustomers | No |
| POST | api/Reporting/GetPickupPostcodes | GetPickupPostcodes | ReportingService.GetPickupPostcodes | No |
| POST | api/Reporting/GetVehicleTypeCounts | GetVehicleTypeCounts | ReportingService.GetVehicleTypeCounts | No |
| POST | api/Reporting/GetAverageDuration | GetAverageDuration | ReportingService.GetAverageDuration | No |
| POST | api/Reporting/GetGrowthByPeriod | GetGrowthByPeriod | ReportingService.GetBookingGrowthByMonthOrYear | No |
| POST | api/Reporting/RevenueByMonth | RevenueByMonth | ReportingService.RevenueByMonth | No |
| POST | api/Reporting/PayoutsByMonth | PayoutsByMonth | ReportingService.PayoutsByMonth | No |
| POST | api/Reporting/ProfitabilityOnInvoices | ProfitabilityOnInvoices | ReportingService.ProfitabilityOnInvoices | No |
| POST | api/Reporting/TotalProfitabilityByPeriod | TotalProfitabilityByPeriod | ReportingService.TotalProfitabilityByPeriod | No |
| POST | api/Reporting/ProfitsByDateRange | ProfitsByDateRange | ReportingService.GetProfitsByDateRange | No |
| GET | api/Reporting/GetQRScans | GetQRCounts | ReportingService.GetQRCodeScans | No |

**Endpoints: 13**

---

### SmsQueController

**Route prefix:** `api/SmsQue`
**Auth:** Per-endpoint

| Method | Route | Action | Service Method Called | Auth |
|--------|-------|--------|---------------------|------|
| GET | api/SmsQue/Get | GetMessages | Direct RabbitMQ consumer, DB query (MessagingNotifyConfig) | No |
| POST | api/SmsQue/SendText | SendTextMessage | AceMessagingService.SendSmsAsync | [Authorize] |

**Endpoints: 2**

---

### UserProfileController

**Route prefix:** `api/UserProfile`
**Auth:** Per-endpoint (noted below)

| Method | Route | Action | Service Method Called | Auth |
|--------|-------|--------|---------------------|------|
| POST | api/UserProfile/Register | Register | IUsersService.FindByName / Create, IAuthenticationService.GetAPIToken, UserProfileService.GetRoleFromRoleName / AddUserToRole / GetUserRoles / GetRoleId | No |
| POST | api/UserProfile/Login | Login | IAuthenticationService.GetAPIToken, UserProfileService.GetProfile / GetUserRoles / GetRoleFromRoleName / GetRoleId / UpdateLastLoginDateTime | No |
| POST | api/UserProfile/RefreshToken | RefreshToken | IAuthenticationService.ValidateRefreshToken | No |
| POST | api/UserProfile/Update | Update | UserProfileService.FindByName, UserProfileService.UpdateUser | [Authorize] |
| POST | api/UserProfile/UpdateFCM | UpdateFCM | UserProfileService.FindByName, UserProfileService.UpdateFCMToken | [Authorize] |
| GET | api/UserProfile/ListUsers | ListUsers | UserProfileService.ListUsers | [Authorize] |
| GET | api/UserProfile/GetUser | GetUser | UserProfileService.FindByName | [Authorize] |
| POST | api/UserProfile/UpdateGPS | UpdateUserGPS | UserProfileService.FindById, UserProfileService.UpdateGpsPosition | [Authorize] |
| GET | api/UserProfile/GetGPS | GetUserGPS | UserProfileService.GetGpsPosition | [Authorize] |
| GET | api/UserProfile/GetAllGPS | GetAllUsersGPS | UserProfileService.GetAllCurrentGpsPositionsCache | No |
| POST | api/UserProfile/SetAvailability | SetAvailability | UserProfileService.FindByName, UserProfileService.CreateUpdateAvailability | [Authorize] |
| POST | api/UserProfile/GetAvailability | GetAvailability | UserProfileService.GetAvailabilities | [Authorize] |
| GET | api/UserProfile/ResetPassword | ResetPassword | UserProfileService.GetEmail, UserProfileService.ChangePassword | No |
| POST | api/UserProfile/Upload | Post | UserProfileService.ImportCsv | No |

**Endpoints: 14**

---

### WeBookingController

**Route prefix:** `api/WeBooking`
**Auth:** Per-endpoint (noted below)

| Method | Route | Action | Service Method Called | Auth |
|--------|-------|--------|---------------------|------|
| POST | api/WeBooking/CreatePolygon | CreatePolygon | Direct DB (GeoFences) | No |
| POST | api/WeBooking/UpdatePolygon | UpdatePolygon | Direct DB (GeoFences) | No |
| DELETE | api/WeBooking/DeletePolygon | DeletePolygon | Direct DB (GeoFences, ZoneToZonePrices) | No |
| GET | api/WeBooking/GetAllPolygons | GetAllPolygons | Direct DB (GeoFences) | No |
| POST | api/WeBooking/GetAdressSuggestions | GetAdressSuggestions | Direct DB (LocalPOIs) | No |
| POST | api/WeBooking/AddNewPassenger | AddNewPassenger | Direct DB (AccountPassengers) via AutoMapper | No |
| DELETE | api/WeBooking/DeletePassenger | DeletePassenger | Direct DB (AccountPassengers) | No |
| GET | api/WeBooking/GetPassengers | GetPassengerList | Direct DB (AccountPassengers) via AutoMapper | No |
| POST | api/WeBooking/CreateWebBooking | CreateWebBooking | Direct DB (WebBookings), UINotificationService.WebBookingCreated, AceMessagingService.SendBrowserNotification | No |
| POST | api/WeBooking/CreateCashBooking | CreateCashBooking | Direct DB (WebBookings), UINotificationService.WebBookingCreated, AceMessagingService.SendBrowserNotification / SendSmsMessage | No |
| POST | api/WeBooking/GetWebBookings | GetWebBookings | Direct DB (WebBookings) | [Authorize] |
| POST | api/WeBooking/Accept | AcceptWebBooking | Direct DB, BookingService.CreateBooking, TariffService.GetOnInvoicePrices / GetPriceHVS, AceMessagingService.SendCashBookingAcceptedEmail / SendAccountBookingAcceptedEmail | [Authorize] |
| POST | api/WeBooking/Reject | RejectWebBooking | Direct DB (WebBookings), AceMessagingService.SendCashBookingRejectedEmail / SendAccountBookingRejectedEmail | [Authorize] |
| POST | api/WeBooking/AmendAccept | AmendAcceptWebBooking | Direct DB (WebBookings) | [Authorize] |
| GET | api/WeBooking/ShortenUrl | ShortenUrl | AceMessagingService.ShorternUrl | No |
| GET | api/WeBooking/GetDuration | GetDuration | TariffService.Get9999CashPrice | [Authorize] |
| GET | api/WeBooking/GetAccountActiveBookings | GetAccountActiveBookings | BookingService.GetAccountActiveBookings, Direct DB (WebAmendmentRequests) | No |
| GET | api/WeBooking/RequestAmendment | RequestAmendment | UINotificationService.BookingAmendmentRequest, Direct DB (WebAmendmentRequests), AceMessagingService.SendSmsMessage | [Authorize] |
| GET | api/WeBooking/RequestCancellation | RequestCancellation | UINotificationService.BookingCancelationRequest, AceMessagingService.SendBrowserNotification, Direct DB (WebAmendmentRequests) | [Authorize] |

**Endpoints: 19**

---

### WhatsAppController

**Route prefix:** `api/WhatsApp`
**Auth:** None
**Note:** Consumes `application/x-www-form-urlencoded`. Extends `TwilioController`.

| Method | Route | Action | Service Method Called | Auth |
|--------|-------|--------|---------------------|------|
| POST | api/WhatsApp/RecieveReply | RecieveReply | UserProfileService.GetUserFromPhoneNo, Direct DB (DriverMessages, Bookings, DriverAllocations), UserActionsService.LogBookingAccepted / LogBookingRejected, UINotificationService.AddJobRejectNotification | No |
| GET | api/WhatsApp/Send | Send | AceMessagingService.SendWhatsAppMessage | No |

**Endpoints: 2**

---

## Observations

### Auth Gaps (endpoints with no [Authorize] that likely should have it)
- Most ReportingController endpoints have no auth
- Most AdminUIController endpoints for driver/account management have no auth
- Several AccountsController billing endpoints have no auth
- CallEventsController has no auth at all
- WeBookingController geo-fence/polygon endpoints have no auth

### Direct DB Access (bypassing services)
- CallEventsController: all endpoints use raw DB queries
- AdminUIController: multiple endpoints (DriverExpenses, DriverExpirys, config, notifications)
- DriverAppController: CompletedJobs, SetActiveJob, GetActiveJob, GetStatementHeaders, Arrived
- WeBookingController: polygon CRUD, passenger CRUD, web booking CRUD
- WhatsAppController: RecieveReply uses direct DB

### Hardcoded Tenant/Account Logic
- BookingsController.GetPrice: hardcoded account numbers 9014, 10026, 10031
- AccountsController.PriceBulk: hardcoded account numbers 9014, 10026, 10031
- AdminUIController.Move9014To10026: hardcoded account migration
- WeBookingController.AcceptWebBooking: hardcoded 9014/10026 logic
- WeBookingController.CreateCashBooking: hardcoded SMS numbers
- BookingsController.CreateBooking: hardcoded machine name check ("i7")

### Duplicate/Overlapping Endpoints
- UserProfileController.UpdateFCM and DriverAppController.UpdateFCM (same logic)
- UserProfileController.UpdateGPS and DriverAppController.UpdateGPS (same logic)
- UserProfileController.SetAvailability and DriverAppController.SetAvailability (different implementations)
- AdminUIController has availability endpoints that overlap with AvailabilityController

### Non-standard Patterns
- CreditInvoice action has three route aliases: DeleteInvoice, ClearInvoice, CreditInvoice
- AdminUIController.ClearAllNotifications has both GET and POST on same route (different param signatures)
- SmsQueController.SendTextMessage returns void instead of IActionResult
- WhatsAppController.Send returns void instead of IActionResult
- QRCodeClickCounter and RedirectController use non-api route prefixes
