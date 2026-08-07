import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router } from '@angular/router';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDividerModule } from '@angular/material/divider';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';

@Component({
  selector: 'app-document-upload',
  standalone: true,
  imports: [
    CommonModule,
    MatCardModule,
    MatButtonModule,
    MatIconModule,
    MatDividerModule,
    MatSnackBarModule
  ],
  template: `
    <div class="material-container">
      <!-- Back Navigation Header -->
      <div class="nav-header">
        <button mat-icon-button (click)="goBack()" class="back-btn">
          <span class="material-symbols-outlined">arrow_back</span>
        </button>
        <span class="nav-title">Upload Document</span>
      </div>

      <!-- Document Information -->
      <mat-card class="doc-info-card">
        <mat-card-content class="info-content">
          <span class="material-symbols-outlined doc-card-icon">description</span>
          <div class="doc-details">
            <h3 class="doc-name">{{ docName }}</h3>
            <p class="doc-helper">Please upload a clear, legible photo or PDF scan of this document for compliance verification.</p>
          </div>
        </mat-card-content>
      </mat-card>

      <!-- Upload Zone -->
      <main class="upload-section">
        <div 
          class="dropzone-box" 
          [class.dragover]="isDragOver" 
          (dragover)="onDragOver($event)" 
          (dragleave)="onDragLeave()"
          (drop)="onDrop($event)"
          (click)="fileInput.click()"
        >
          <input 
            #fileInput 
            type="file" 
            accept="image/*,application/pdf" 
            (change)="onFileSelected($event)" 
            style="display: none;" 
          />
          
          <div class="dropzone-content" *ngIf="!selectedFile">
            <span class="material-symbols-outlined upload-cloud-icon">cloud_upload</span>
            <span class="upload-title">Tap or drag file here</span>
            <span class="upload-subtitle">Supports JPG, PNG, or PDF up to 10MB</span>
          </div>

          <div class="selected-file-content" *ngIf="selectedFile" (click)="$event.stopPropagation()">
            <span class="material-symbols-outlined file-type-icon">
              {{ selectedFile.type.includes('pdf') ? 'picture_as_pdf' : 'image' }}
            </span>
            <div class="file-info">
              <span class="file-name">{{ selectedFile.name }}</span>
              <span class="file-size">{{ formatFileSize(selectedFile.size) }}</span>
            </div>
            <button mat-icon-button color="warn" (click)="clearSelectedFile()" class="remove-file-btn">
              <span class="material-symbols-outlined">close</span>
            </button>
          </div>
        </div>

        <!-- Simulated Upload Progress -->
        <div class="progress-container" *ngIf="uploadProgress > 0 && uploadProgress < 100">
          <div class="progress-bar-wrapper">
            <div class="progress-bar-fill" [style.width.%]="uploadProgress"></div>
          </div>
          <span class="progress-text">Uploading... {{ uploadProgress }}%</span>
        </div>

        <!-- Document Expiry Form Fields -->
        <mat-card class="form-card">
          <mat-card-content class="form-content">
            <div class="input-group">
              <label class="input-label">Document Number / ID</label>
              <input type="text" placeholder="e.g. LIC-12345-AB" class="form-input" />
            </div>

            <div class="input-group">
              <label class="input-label">Expiry Date</label>
              <input type="date" class="form-input" />
            </div>
          </mat-card-content>
        </mat-card>
      </main>

      <!-- Submit Footer -->
      <footer class="footer-actions">
        <button 
          mat-raised-button 
          color="primary" 
          class="submit-btn" 
          [disabled]="!selectedFile || isSubmitting"
          (click)="submitDocument()"
        >
          <span class="material-symbols-outlined btn-icon" *ngIf="!isSubmitting">check_circle</span>
          {{ isSubmitting ? 'Submitting File...' : 'Submit for Approval' }}
        </button>
      </footer>
    </div>
  `,
  styles: [`
    .material-container {
      padding: 16px;
      padding-bottom: 88px; /* Space for sticky submit button */
      background-color: var(--background-color);
      min-height: 100vh;
      font-family: 'Roboto', sans-serif;
    }

    /* Header Nav */
    .nav-header {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 16px;
    }
    .back-btn {
      color: var(--text-primary);
    }
    .nav-title {
      font-size: 16px;
      font-weight: 700;
      color: var(--text-primary);
    }

    /* Doc Info Card */
    .doc-info-card {
      border: 1px solid var(--border-color);
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.02) !important;
      border-radius: 12px !important;
      background-color: var(--surface-color);
      margin-bottom: 16px;
    }
    .info-content {
      display: flex;
      align-items: flex-start;
      gap: 14px;
      padding: 14px 16px !important;
    }
    .doc-card-icon {
      font-size: 28px;
      color: var(--primary-color);
    }
    .doc-details {
      flex: 1;
    }
    .doc-name {
      margin: 0 0 4px 0;
      font-size: 14px;
      font-weight: 700;
      color: var(--text-primary);
    }
    .doc-helper {
      margin: 0;
      font-size: 11px;
      color: var(--text-secondary);
      line-height: 1.4;
    }

    /* Upload zone */
    .upload-section {
      display: flex;
      flex-direction: column;
      gap: 16px;
    }
    .dropzone-box {
      border: 2px dashed var(--border-color);
      border-radius: 12px;
      padding: 28px 16px;
      text-align: center;
      background-color: var(--surface-color);
      cursor: pointer;
      transition: all 0.2s ease-in-out;
    }
    .dropzone-box.dragover {
      border-color: var(--primary-color);
      background-color: rgba(229, 57, 85, 0.02);
    }
    .dropzone-content {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 8px;
    }
    .upload-cloud-icon {
      font-size: 40px;
      color: var(--text-secondary);
    }
    .upload-title {
      font-size: 13px;
      font-weight: 700;
      color: var(--text-primary);
    }
    .upload-subtitle {
      font-size: 10px;
      color: var(--text-secondary);
    }

    /* File preview */
    .selected-file-content {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 8px 12px;
      border: 1px solid var(--border-color);
      border-radius: 8px;
      background-color: #F8F9FA;
      text-align: left;
    }
    .file-type-icon {
      font-size: 32px;
      color: var(--primary-color);
    }
    .file-info {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 2px;
      min-width: 0;
    }
    .file-name {
      font-size: 12px;
      font-weight: 700;
      color: var(--text-primary);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .file-size {
      font-size: 10px;
      color: var(--text-secondary);
    }
    .remove-file-btn {
      flex-shrink: 0;
    }

    /* Progress bar */
    .progress-container {
      display: flex;
      flex-direction: column;
      gap: 4px;
      padding: 0 4px;
    }
    .progress-bar-wrapper {
      height: 4px;
      background-color: var(--border-color);
      border-radius: 2px;
      overflow: hidden;
    }
    .progress-bar-fill {
      height: 100%;
      background-color: var(--primary-color);
      transition: width 0.1s ease;
    }
    .progress-text {
      font-size: 10px;
      color: var(--text-secondary);
      font-weight: 700;
    }

    /* Inputs Form */
    .form-card {
      border: 1px solid var(--border-color);
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.02) !important;
      border-radius: 12px !important;
      background-color: var(--surface-color);
    }
    .form-content {
      padding: 16px !important;
      display: flex;
      flex-direction: column;
      gap: 16px;
    }
    .input-group {
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .input-label {
      font-size: 10px;
      font-weight: 800;
      color: var(--text-secondary);
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .form-input {
      height: 44px;
      padding: 0 12px;
      border: 1px solid var(--border-color);
      border-radius: 8px;
      font-size: 13px;
      color: var(--text-primary);
      font-family: inherit;
      background-color: #FFFFFF;
      outline: none;
      transition: border-color 0.15s ease-in-out;
    }
    .form-input:focus {
      border-color: var(--primary-color);
    }

    /* Fixed Submit Footer */
    .footer-actions {
      position: fixed;
      bottom: 0;
      left: 0;
      right: 0;
      padding: 16px;
      background-color: var(--background-color);
      border-top: 1px solid var(--border-color);
      z-index: 100;
    }
    .submit-btn {
      width: 100%;
      height: 48px;
      border-radius: 8px !important;
      font-size: 14px !important;
      font-weight: bold !important;
      display: flex;
      justify-content: center;
      align-items: center;
      gap: 6px;
    }
    .btn-icon {
      font-size: 20px;
    }
  `]
})
export class DocumentUploadComponent implements OnInit {
  docName = 'Hackney Carriage / PHV License';
  isDragOver = false;
  selectedFile: File | null = null;
  uploadProgress = 0;
  isSubmitting = false;

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private snackBar: MatSnackBar
  ) {}

  ngOnInit(): void {
    this.route.queryParams.subscribe(params => {
      if (params['doc']) {
        this.docName = params['doc'];
      }
    });
  }

  goBack(): void {
    this.router.navigate(['/profile']);
  }

  onDragOver(event: DragEvent): void {
    event.preventDefault();
    this.isDragOver = true;
  }

  onDragLeave(): void {
    this.isDragOver = false;
  }

  onDrop(event: DragEvent): void {
    event.preventDefault();
    this.isDragOver = false;
    if (event.dataTransfer?.files && event.dataTransfer.files.length > 0) {
      this.handleFile(event.dataTransfer.files[0]);
    }
  }

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files.length > 0) {
      this.handleFile(input.files[0]);
    }
  }

  handleFile(file: File): void {
    if (file.size > 10 * 1024 * 1024) {
      this.snackBar.open('File size exceeds the 10MB limit.', 'Dismiss', {
        duration: 3000
      });
      return;
    }
    this.selectedFile = file;
    this.simulateUpload();
  }

  simulateUpload(): void {
    this.uploadProgress = 0;
    const interval = setInterval(() => {
      this.uploadProgress += 20;
      if (this.uploadProgress >= 100) {
        clearInterval(interval);
        this.snackBar.open('File uploaded successfully to local storage.', 'Dismiss', {
          duration: 2000
        });
      }
    }, 150);
  }

  clearSelectedFile(): void {
    this.selectedFile = null;
    this.uploadProgress = 0;
  }

  formatFileSize(bytes: number): string {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }

  submitDocument(): void {
    this.isSubmitting = true;
    setTimeout(() => {
      this.isSubmitting = false;
      this.snackBar.open('Document submitted for verification successfully!', 'Dismiss', {
        duration: 3000
      });
      this.router.navigate(['/profile']);
    }, 2000);
  }
}
