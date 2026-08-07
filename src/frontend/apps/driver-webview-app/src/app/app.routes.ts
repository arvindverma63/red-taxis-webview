import { Routes } from '@angular/router';
import { FaqComponent } from './faq/faq';
import { TermsComponent } from './terms/terms';
import { ReportsComponent } from './reports/reports';

export const routes: Routes = [
  { path: 'faq', component: FaqComponent },
  { path: 'terms', component: TermsComponent },
  { path: 'reports', component: ReportsComponent },
  { path: '', redirectTo: 'faq', pathMatch: 'full' },
  { path: '**', redirectTo: 'faq' }
];
