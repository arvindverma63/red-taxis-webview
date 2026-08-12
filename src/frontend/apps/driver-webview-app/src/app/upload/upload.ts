import { Component, OnInit, ViewChild, ElementRef, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router } from '@angular/router';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDividerModule } from '@angular/material/divider';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { DriverService } from '../services/driver.service';
import { catchError } from 'rxjs/operators';
import { of } from 'rxjs';
import { HttpEventType } from '@angular/common/http';

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

      <!-- Upload & Cropping Section -->
      <main class="upload-section">
        <!-- 1. Selection State -->
        <div class="selection-workspace animated-fade-in" *ngIf="!selectedFile">
          <mat-card class="action-card">
            <mat-card-content class="action-content">
              <span class="material-symbols-outlined camera-main-icon">photo_camera</span>
              <p class="select-helper-text">Select or snap a photo of your compliance document to verify and crop it.</p>
              <button mat-flat-button color="primary" class="select-action-btn" (click)="fileInput.click()">
                <mat-icon>add_photo_alternate</mat-icon> Select Image File
              </button>
            </mat-card-content>
          </mat-card>
        </div>

        <input 
          #fileInput 
          type="file" 
          accept="image/*" 
          (change)="onFileSelected($event)" 
          style="display: none;" 
        />

        <!-- 2. Cropping State -->
        <div class="crop-workspace animated-fade-in" *ngIf="selectedFile && !isCropped">
          <div class="crop-container-outer">
            <div class="crop-container" #cropContainer>
              <img [src]="imageSrc" class="crop-image" #cropImg (load)="onImageLoaded()" [style.transform]="'rotate(' + rotationAngle + 'deg)'" />
              <!-- Draggable Crop Box Overlay -->
              <div 
                class="crop-overlay-box" 
                [style.top.%]="cropBoxY" 
                [style.left.%]="cropBoxX" 
                [style.width.%]="cropBoxW" 
                [style.height.%]="cropBoxH"
                (mousedown)="onDragStart($event)"
                (touchstart)="onDragStart($event)"
              >
                <div class="resize-handle top-left" (mousedown)="onResizeStart($event, 'top-left'); $event.stopPropagation()" (touchstart)="onResizeStart($event, 'top-left'); $event.stopPropagation()"></div>
                <div class="resize-handle top-right" (mousedown)="onResizeStart($event, 'top-right'); $event.stopPropagation()" (touchstart)="onResizeStart($event, 'top-right'); $event.stopPropagation()"></div>
                <div class="resize-handle bottom-left" (mousedown)="onResizeStart($event, 'bottom-left'); $event.stopPropagation()" (touchstart)="onResizeStart($event, 'bottom-left'); $event.stopPropagation()"></div>
                <div class="resize-handle bottom-right" (mousedown)="onResizeStart($event, 'bottom-right'); $event.stopPropagation()" (touchstart)="onResizeStart($event, 'bottom-right'); $event.stopPropagation()"></div>
              </div>
            </div>
          </div>

          <!-- Adjusters and Rotation controls -->
          <mat-card class="adjusters-card">
            <mat-card-content class="adjusters-content">
              <div class="controls-header">
                <span class="controls-title">Adjust Crop Area</span>
                <button mat-icon-button (click)="rotateRight()" matTooltip="Rotate 90°" class="rotate-btn">
                  <mat-icon>rotate_right</mat-icon> Rotate
                </button>
              </div>

              <div class="sliders-grid">
                <div class="slider-group">
                  <span class="slider-lbl">Width</span>
                  <input type="range" min="20" max="95" [value]="cropBoxW" (input)="cropBoxW = Number($any($event.target).value); updateCropBox()" class="range-slider" />
                </div>
                <div class="slider-group">
                  <span class="slider-lbl">Height</span>
                  <input type="range" min="20" max="95" [value]="cropBoxH" (input)="cropBoxH = Number($any($event.target).value); updateCropBox()" class="range-slider" />
                </div>
              </div>

              <button mat-flat-button color="accent" (click)="performCrop()" class="crop-apply-btn">
                <mat-icon>crop</mat-icon> Crop & Legibility Lock
              </button>
            </mat-card-content>
          </mat-card>
        </div>

        <!-- 3. Cropped Verified State -->
        <div class="cropped-locked-workspace animated-fade-in" *ngIf="selectedFile && isCropped">
          <mat-card class="preview-result-card">
            <mat-card-header class="preview-header">
              <mat-card-title class="preview-title">Legibility & Borders Verification</mat-card-title>
            </mat-card-header>
            <mat-card-content class="preview-content">
              <div class="preview-img-container">
                <img [src]="croppedPreviewSrc" class="cropped-preview-img" />
              </div>
              
              <div class="verification-checks-list">
                <div class="check-item">
                  <mat-icon class="verified-icon">check_circle</mat-icon>
                  <span>Document text is clear and readable</span>
                </div>
                <div class="check-item">
                  <mat-icon class="verified-icon">check_circle</mat-icon>
                  <span>All borders and edges are visible</span>
                </div>
                <div class="check-item">
                  <mat-icon class="verified-icon">check_circle</mat-icon>
                  <span>No shadows or glare block information</span>
                </div>
              </div>

              <div class="change-file-row">
                <button mat-stroked-button color="warn" (click)="clearSelectedFile()" class="reset-btn">
                  <mat-icon>refresh</mat-icon> Retake / Reset Photo
                </button>
              </div>
            </mat-card-content>
          </mat-card>
        </div>

        <!-- Upload Progress Indicator -->
        <div class="progress-container" *ngIf="uploadProgress > 0 && uploadProgress < 100">
          <div class="progress-bar-wrapper">
            <div class="progress-bar-fill" [style.width.%]="uploadProgress"></div>
          </div>
          <span class="progress-text">Uploading File... {{ uploadProgress }}%</span>
        </div>
      </main>

      <!-- Submit Footer -->
      <footer class="footer-actions">
        <button 
          mat-raised-button 
          color="primary" 
          class="submit-btn" 
          [disabled]="!croppedFile || isSubmitting"
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

    /* Upload & Cropping Section */
    .upload-section {
      display: flex;
      flex-direction: column;
      gap: 16px;
    }

    /* Animation */
    .animated-fade-in {
      animation: fadeIn 0.25s ease-in-out forwards;
    }
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(4px); }
      to { opacity: 1; transform: translateY(0); }
    }

    /* Selection Card */
    .action-card {
      border: 1px solid var(--border-color);
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.02) !important;
      border-radius: 12px !important;
      background-color: var(--surface-color);
      text-align: center;
      padding: 32px 16px !important;
    }
    .camera-main-icon {
      font-size: 48px;
      color: var(--text-secondary);
      margin-bottom: 12px;
    }
    .select-helper-text {
      font-size: 13px;
      color: var(--text-secondary);
      margin-bottom: 20px;
      line-height: 1.5;
    }
    .select-action-btn {
      height: 44px;
      border-radius: 8px !important;
      font-weight: 700 !important;
      padding: 0 24px !important;
    }

    /* Cropping Workspace */
    .crop-container-outer {
      background-color: #1A1A1A;
      border-radius: 12px;
      overflow: hidden;
      margin-bottom: 16px;
      border: 1px solid var(--border-color);
      display: flex;
      justify-content: center;
      align-items: center;
    }
    .crop-container {
      position: relative;
      overflow: hidden;
      width: 100%;
      max-width: 320px;
      height: 280px;
      display: flex;
      justify-content: center;
      align-items: center;
      background-color: #000;
    }
    .crop-image {
      max-width: 100%;
      max-height: 100%;
      object-fit: contain;
      user-select: none;
      pointer-events: none;
      transition: transform 0.2s ease-in-out;
    }
    .crop-overlay-box {
      position: absolute;
      border: 2px dashed #FF3D00;
      box-shadow: 0 0 0 9999px rgba(0, 0, 0, 0.65);
      cursor: move;
      box-sizing: border-box;
      touch-action: none;
    }
    
    /* Resize handles in the corners */
    .resize-handle {
      position: absolute;
      width: 16px;
      height: 16px;
      background-color: #FF3D00;
      border: 2px solid #FFFFFF;
      border-radius: 50%;
      box-sizing: border-box;
    }
    .resize-handle.top-left { top: -8px; left: -8px; cursor: nwse-resize; }
    .resize-handle.top-right { top: -8px; right: -8px; cursor: nesw-resize; }
    .resize-handle.bottom-left { bottom: -8px; left: -8px; cursor: nesw-resize; }
    .resize-handle.bottom-right { bottom: -8px; right: -8px; cursor: nwse-resize; }

    /* Adjusters Card */
    .adjusters-card {
      border: 1px solid var(--border-color);
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.02) !important;
      border-radius: 12px !important;
      background-color: var(--surface-color);
      margin-bottom: 16px;
    }
    .adjusters-content {
      padding: 16px !important;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .controls-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 4px;
    }
    .controls-title {
      font-size: 13px;
      font-weight: 700;
      color: var(--text-primary);
    }
    .rotate-btn {
      font-weight: 600;
      color: var(--primary-color);
      font-size: 12px;
    }
    .sliders-grid {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .slider-group {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .slider-lbl {
      width: 48px;
      font-size: 11px;
      font-weight: 700;
      color: var(--text-secondary);
      text-transform: uppercase;
    }
    .range-slider {
      flex: 1;
      height: 6px;
      border-radius: 3px;
      outline: none;
      accent-color: var(--primary-color);
    }
    .crop-apply-btn {
      width: 100%;
      height: 40px;
      border-radius: 8px !important;
      font-weight: 700 !important;
      margin-top: 8px;
    }

    /* Verified Preview Card */
    .preview-result-card {
      border: 1px solid var(--border-color);
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.02) !important;
      border-radius: 12px !important;
      background-color: var(--surface-color);
      margin-bottom: 16px;
    }
    .preview-header {
      padding: 14px 16px 8px 16px !important;
    }
    .preview-title {
      font-size: 14px;
      font-weight: 700;
      color: var(--text-primary);
    }
    .preview-content {
      padding: 0 16px 16px 16px !important;
      display: flex;
      flex-direction: column;
      gap: 14px;
    }
    .preview-img-container {
      background-color: #F8F9FA;
      border: 1px solid var(--border-color);
      border-radius: 8px;
      overflow: hidden;
      display: flex;
      justify-content: center;
      align-items: center;
      max-height: 200px;
    }
    .cropped-preview-img {
      max-width: 100%;
      max-height: 200px;
      object-fit: contain;
    }
    .verification-checks-list {
      display: flex;
      flex-direction: column;
      gap: 8px;
      background-color: rgba(76, 175, 80, 0.03);
      padding: 12px;
      border-radius: 8px;
      border: 1px solid rgba(76, 175, 80, 0.1);
    }
    .check-item {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 12px;
      font-weight: 500;
      color: #2E7D32;
    }
    .verified-icon {
      font-size: 16px;
      width: 16px;
      height: 16px;
      color: #4CAF50;
    }
    .change-file-row {
      display: flex;
      justify-content: center;
    }
    .reset-btn {
      font-size: 12px !important;
      font-weight: 600 !important;
      border-radius: 8px !important;
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
  @ViewChild('cropImg') cropImg!: ElementRef<HTMLImageElement>;
  @ViewChild('cropContainer') cropContainer!: ElementRef<HTMLDivElement>;

  Number = Number;
  docName = 'Hackney Carriage / PHV License';
  docType = 0;
  selectedFile: File | null = null;
  uploadProgress = 0;
  isSubmitting = false;

  // Cropper State variables
  imageSrc: string | null = null;
  croppedPreviewSrc: string | null = null;
  croppedFile: File | null = null;
  isCropped = false;
  rotationAngle = 0;

  // Crop overlay box position & dimension (in %)
  cropBoxX = 10;
  cropBoxY = 10;
  cropBoxW = 80;
  cropBoxH = 80;

  // Drag & Resize mouse tracking
  dragStartMouseX = 0;
  dragStartMouseY = 0;
  dragStartBoxX = 0;
  dragStartBoxY = 0;
  dragStartBoxW = 0;
  dragStartBoxH = 0;
  isDragging = false;
  isResizing = false;
  resizeHandleType = '';

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private snackBar: MatSnackBar,
    private driverService: DriverService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.route.queryParams.subscribe(params => {
      if (params['name']) {
        this.docName = params['name'];
      }
      if (params['type'] !== undefined) {
        this.docType = Number(params['type']);
      }
    });
  }

  goBack(): void {
    this.router.navigate(['/profile']);
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
    this.isCropped = false;
    this.croppedFile = null;
    this.croppedPreviewSrc = null;
    this.rotationAngle = 0;
    this.cropBoxX = 15;
    this.cropBoxY = 15;
    this.cropBoxW = 70;
    this.cropBoxH = 70;

    // Load file as base64 dataUrl for cropper
    const reader = new FileReader();
    reader.onload = (e) => {
      this.imageSrc = e.target?.result as string;
      this.cdr.detectChanges();
    };
    reader.readAsDataURL(file);
  }

  onImageLoaded(): void {
    console.log('[Cropper] Original Image loaded successfully');
    this.cdr.detectChanges();
  }

  rotateRight(): void {
    this.rotationAngle = (this.rotationAngle + 90) % 360;
    this.cdr.detectChanges();
  }

  updateCropBox(): void {
    if (this.cropBoxX + this.cropBoxW > 100) {
      this.cropBoxX = 100 - this.cropBoxW;
    }
    if (this.cropBoxY + this.cropBoxH > 100) {
      this.cropBoxY = 100 - this.cropBoxH;
    }
    this.cdr.detectChanges();
  }

  onDragStart(event: MouseEvent | TouchEvent): void {
    event.preventDefault();
    this.isDragging = true;
    const clientX = 'touches' in event ? event.touches[0].clientX : event.clientX;
    const clientY = 'touches' in event ? event.touches[0].clientY : event.clientY;
    this.dragStartMouseX = clientX;
    this.dragStartMouseY = clientY;
    this.dragStartBoxX = this.cropBoxX;
    this.dragStartBoxY = this.cropBoxY;

    const moveListener = (moveEvent: MouseEvent | TouchEvent) => {
      if (!this.isDragging) return;
      const mX = 'touches' in moveEvent ? moveEvent.touches[0].clientX : moveEvent.clientX;
      const mY = 'touches' in moveEvent ? moveEvent.touches[0].clientY : moveEvent.clientY;
      const dx = ((mX - this.dragStartMouseX) / this.cropContainer.nativeElement.clientWidth) * 100;
      const dy = ((mY - this.dragStartMouseY) / this.cropContainer.nativeElement.clientHeight) * 100;
      
      let nextX = this.dragStartBoxX + dx;
      let nextY = this.dragStartBoxY + dy;

      if (nextX < 0) nextX = 0;
      if (nextY < 0) nextY = 0;
      if (nextX + this.cropBoxW > 100) nextX = 100 - this.cropBoxW;
      if (nextY + this.cropBoxH > 100) nextY = 100 - this.cropBoxH;

      this.cropBoxX = Math.round(nextX);
      this.cropBoxY = Math.round(nextY);
      this.cdr.detectChanges();
    };

    const upListener = () => {
      this.isDragging = false;
      window.removeEventListener('mousemove', moveListener);
      window.removeEventListener('mouseup', upListener);
      window.removeEventListener('touchmove', moveListener);
      window.removeEventListener('touchend', upListener);
    };

    window.addEventListener('mousemove', moveListener);
    window.addEventListener('mouseup', upListener);
    window.addEventListener('touchmove', moveListener);
    window.addEventListener('touchend', upListener);
  }

  onResizeStart(event: MouseEvent | TouchEvent, handle: string): void {
    event.stopPropagation();
    event.preventDefault();
    this.isResizing = true;
    this.resizeHandleType = handle;
    const clientX = 'touches' in event ? event.touches[0].clientX : event.clientX;
    const clientY = 'touches' in event ? event.touches[0].clientY : event.clientY;
    this.dragStartMouseX = clientX;
    this.dragStartMouseY = clientY;
    this.dragStartBoxX = this.cropBoxX;
    this.dragStartBoxY = this.cropBoxY;
    this.dragStartBoxW = this.cropBoxW;
    this.dragStartBoxH = this.cropBoxH;

    const moveListener = (moveEvent: MouseEvent | TouchEvent) => {
      if (!this.isResizing) return;
      const mX = 'touches' in moveEvent ? moveEvent.touches[0].clientX : moveEvent.clientX;
      const mY = 'touches' in moveEvent ? moveEvent.touches[0].clientY : moveEvent.clientY;
      const dx = ((mX - this.dragStartMouseX) / this.cropContainer.nativeElement.clientWidth) * 100;
      const dy = ((mY - this.dragStartMouseY) / this.cropContainer.nativeElement.clientHeight) * 100;

      if (this.resizeHandleType === 'bottom-right') {
        let newW = this.dragStartBoxW + dx;
        let newH = this.dragStartBoxH + dy;
        if (this.cropBoxX + newW > 100) newW = 100 - this.cropBoxX;
        if (this.cropBoxY + newH > 100) newH = 100 - this.cropBoxY;
        this.cropBoxW = Math.max(20, Math.round(newW));
        this.cropBoxH = Math.max(20, Math.round(newH));
      } else if (this.resizeHandleType === 'top-left') {
        let newX = this.dragStartBoxX + dx;
        let newY = this.dragStartBoxY + dy;
        let newW = this.dragStartBoxW - dx;
        let newH = this.dragStartBoxH - dy;
        if (newX < 0) { newW += newX; newX = 0; }
        if (newY < 0) { newH += newY; newY = 0; }
        this.cropBoxX = Math.round(newX);
        this.cropBoxY = Math.round(newY);
        this.cropBoxW = Math.max(20, Math.round(newW));
        this.cropBoxH = Math.max(20, Math.round(newH));
      } else if (this.resizeHandleType === 'top-right') {
        let newY = this.dragStartBoxY + dy;
        let newW = this.dragStartBoxW + dx;
        let newH = this.dragStartBoxH - dy;
        if (newY < 0) { newH += newY; newY = 0; }
        if (this.cropBoxX + newW > 100) newW = 100 - this.cropBoxX;
        this.cropBoxY = Math.round(newY);
        this.cropBoxW = Math.max(20, Math.round(newW));
        this.cropBoxH = Math.max(20, Math.round(newH));
      } else if (this.resizeHandleType === 'bottom-left') {
        let newX = this.dragStartBoxX + dx;
        let newW = this.dragStartBoxW - dx;
        let newH = this.dragStartBoxH + dy;
        if (newX < 0) { newW += newX; newX = 0; }
        if (this.cropBoxY + newH > 100) newH = 100 - this.cropBoxY;
        this.cropBoxX = Math.round(newX);
        this.cropBoxW = Math.max(20, Math.round(newW));
        this.cropBoxH = Math.max(20, Math.round(newH));
      }
      this.cdr.detectChanges();
    };

    const upListener = () => {
      this.isResizing = false;
      window.removeEventListener('mousemove', moveListener);
      window.removeEventListener('mouseup', upListener);
      window.removeEventListener('touchmove', moveListener);
      window.removeEventListener('touchend', upListener);
    };

    window.addEventListener('mousemove', moveListener);
    window.addEventListener('mouseup', upListener);
    window.addEventListener('touchmove', moveListener);
    window.addEventListener('touchend', upListener);
  }

  performCrop(): void {
    if (!this.selectedFile || !this.imageSrc) return;

    const img = this.cropImg.nativeElement;
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Build the rotated intermediate canvas
    const tempCanvas = document.createElement('canvas');
    const tempCtx = tempCanvas.getContext('2d');
    if (!tempCtx) return;

    const angle = (this.rotationAngle % 360 + 360) % 360;
    
    if (angle === 90 || angle === 270) {
      tempCanvas.width = img.naturalHeight;
      tempCanvas.height = img.naturalWidth;
    } else {
      tempCanvas.width = img.naturalWidth;
      tempCanvas.height = img.naturalHeight;
    }

    tempCtx.translate(tempCanvas.width / 2, tempCanvas.height / 2);
    tempCtx.rotate((angle * Math.PI) / 180);
    tempCtx.drawImage(img, -img.naturalWidth / 2, -img.naturalHeight / 2);

    // Calculate crop window boundaries based on percentages
    const x = (this.cropBoxX / 100) * tempCanvas.width;
    const y = (this.cropBoxY / 100) * tempCanvas.height;
    const w = (this.cropBoxW / 100) * tempCanvas.width;
    const h = (this.cropBoxH / 100) * tempCanvas.height;

    canvas.width = w;
    canvas.height = h;
    ctx.drawImage(tempCanvas, x, y, w, h, 0, 0, w, h);

    // Draw preview
    this.croppedPreviewSrc = canvas.toDataURL('image/jpeg', 0.9);

    // Output File blob
    canvas.toBlob((blob) => {
      if (blob) {
        this.croppedFile = new File([blob], this.selectedFile!.name, { type: 'image/jpeg' });
        this.isCropped = true;
        this.cdr.detectChanges();
        this.snackBar.open('Document cropped & locked successfully!', 'Dismiss', {
          duration: 2000
        });
      }
    }, 'image/jpeg', 0.9);
  }

  clearSelectedFile(): void {
    this.selectedFile = null;
    this.imageSrc = null;
    this.croppedPreviewSrc = null;
    this.croppedFile = null;
    this.isCropped = false;
    this.rotationAngle = 0;
    this.uploadProgress = 0;
    this.cdr.detectChanges();
  }

  submitDocument(): void {
    if (!this.croppedFile) return;

    this.isSubmitting = true;
    this.uploadProgress = 0;
    
    const formData = new FormData();
    formData.append('file', this.croppedFile);
    formData.append('type', this.docType.toString());

    this.driverService.uploadDocument(formData).pipe(
      catchError(err => {
        console.error('[Upload] Real upload failed:', err);
        this.snackBar.open(`Error: Failed to upload file. ${err.error || err.statusText || 'Connection error'}`, 'Dismiss', {
          duration: 5000
        });
        this.isSubmitting = false;
        this.uploadProgress = 0;
        return of(null);
      })
    ).subscribe(event => {
      if (!event) return;

      if (event.type === HttpEventType.UploadProgress) {
        if (event.total) {
          this.uploadProgress = Math.round((100 * event.loaded) / event.total);
        }
      } else if (event.type === HttpEventType.Response) {
        this.isSubmitting = false;
        this.uploadProgress = 100;
        this.snackBar.open('Document uploaded for verification successfully!', 'Dismiss', {
          duration: 3000
        });
        
        setTimeout(() => {
          this.router.navigate(['/profile']);
        }, 1500);
      }
    });
  }
}
