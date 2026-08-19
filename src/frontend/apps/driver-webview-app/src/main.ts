import { bootstrapApplication } from '@angular/platform-browser';
import { appConfig } from './app/app.config';
import { App } from './app/app';

// Prevent raw icon text flashing by adding class when fonts are loaded
if ((document as any).fonts) {
  (document as any).fonts.ready.then(() => {
    document.body.classList.add('fonts-loaded');
  });
} else {
  // Fallback if not supported
  document.body.classList.add('fonts-loaded');
}

bootstrapApplication(App, appConfig)
  .catch((err) => console.error(err));
