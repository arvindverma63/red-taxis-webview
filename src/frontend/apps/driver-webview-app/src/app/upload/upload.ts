import { Component, OnInit, ViewChild, ElementRef, ChangeDetectorRef, OnDestroy } from '@angular/core';
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
    <div class="upload-container">
      <!-- 1. Header Bar -->
      <header class="upload-header">
        <button class="back-nav-btn" (click)="goBack()" title="Back to Profile">
          <span class="material-symbols-outlined">arrow_back</span>
        </button>
        <div class="header-titles">
          <h1 class="header-main-title">{{ docName }}</h1>
          <span class="header-sub-title">Compliance Verification Portal</span>
        </div>
      </header>

      <!-- 2. Document Information Card -->
      <div class="doc-badge-card">
        <div class="badge-icon-box">
          <span class="material-symbols-outlined">verified_user</span>
        </div>
        <div class="badge-text-col">
          <span class="badge-label">Document Requirement</span>
          <span class="badge-title">{{ docName }}</span>
          <span class="badge-hint">Upload a sharp, legible image or scan. Ensure all 4 corners and dates are clearly visible.</span>
        </div>
      </div>

      <!-- 3. Main Workspace -->
      <main class="upload-workspace">

        <!-- STATE 1: File Selection & Camera Launch -->
        <div class="selection-card animated-fade-in" *ngIf="!selectedFile && !isCameraActive">
          <div 
            class="drop-zone"
            (click)="triggerFileSelect()"
            (dragover)="onDragOver($event)"
            (dragleave)="onDragLeave($event)"
            (drop)="onFileDrop($event)"
            [class.dragover]="isDragging"
          >
            <div class="drop-icon-wrapper">
              <span class="material-symbols-outlined">cloud_upload</span>
            </div>
            <h3 class="drop-title">Upload Certificate</h3>
            <p class="drop-sub">Tap to browse files or snap a fresh photo</p>
            <span class="drop-formats">Supports JPG, PNG, PDF (Up to 10MB)</span>
          </div>

          <!-- Dual Action Buttons -->
          <div class="action-buttons-grid">
            <button class="btn-file-select" (click)="triggerFileSelect()">
              <span class="material-symbols-outlined">add_photo_alternate</span>
              <span>Select File / Gallery</span>
            </button>

            <button class="btn-camera-launch" (click)="startCamera()">
              <span class="material-symbols-outlined">photo_camera</span>
              <span>Take Photo</span>
            </button>
          </div>

          <!-- Verification Guidelines Checklist -->
          <div class="guidelines-box">
            <span class="guidelines-head">
              <span class="material-symbols-outlined">info</span>
              <span>Submission Guidelines:</span>
            </span>
            <ul class="guidelines-list">
              <li>Place the document on a flat, dark background</li>
              <li>Avoid flash glare, deep shadows, and blur</li>
              <li>Ensure issue and expiry dates are clearly readable</li>
            </ul>
          </div>
        </div>

        <!-- STATE 2: Live Camera Viewport -->
        <div class="camera-card animated-fade-in" *ngIf="isCameraActive">
          <div class="camera-viewport-wrapper">
            <video #videoElement autoplay playsinline class="camera-video"></video>
            
            <!-- Scanning HUD & Alignment Guides -->
            <div class="camera-hud-overlay">
              <div class="hud-corner top-left"></div>
              <div class="hud-corner top-right"></div>
              <div class="hud-corner bottom-left"></div>
              <div class="hud-corner bottom-right"></div>
              <div class="hud-scan-line"></div>
              <span class="hud-instruction">Align document within the frame</span>
            </div>
          </div>

          <div class="camera-controls-bar">
            <button class="btn-cam-cancel" (click)="stopCamera()">
              <span class="material-symbols-outlined">close</span>
              <span>Cancel</span>
            </button>
            <button class="btn-cam-shutter" (click)="capturePhoto()" title="Capture Document">
              <div class="shutter-inner">
                <span class="material-symbols-outlined">camera_alt</span>
              </div>
            </button>
          </div>
        </div>

        <!-- Hidden Native File Input -->
        <input 
          #fileInput 
          type="file" 
          accept="image/*" 
          (change)="onFileSelected($event)" 
          style="display: none;" 
        />

        <!-- STATE 3: Cropping & Fine-Tuning Workspace -->
        <div class="cropping-card animated-fade-in" *ngIf="selectedFile && !isCropped && !isCameraActive">
          <div class="crop-header-bar">
            <span class="crop-title">Adjust & Crop Document</span>
            <button class="rotate-tool-btn" (click)="rotateRight()">
              <span class="material-symbols-outlined">rotate_right</span>
              <span>Rotate 90°</span>
            </button>
          </div>

          <!-- Crop Viewport -->
          <div class="crop-viewport-outer">
            <div class="crop-viewport" #cropContainer>
              <img 
                [src]="imageSrc" 
                class="crop-base-img" 
                #cropImg 
                (load)="onImageLoaded()" 
                [style.transform]="'rotate(' + rotationAngle + 'deg)'" 
              />
              
              <!-- Draggable / Resizable Crop Box -->
              <div 
                class="crop-box-rect" 
                [style.top.%]="cropBoxY" 
                [style.left.%]="cropBoxX" 
                [style.width.%]="cropBoxW" 
                [style.height.%]="cropBoxH"
                (mousedown)="onDragStart($event)"
                (touchstart)="onDragStart($event)"
              >
                <div class="resize-handle tl" (mousedown)="onResizeStart($event, 'top-left'); $event.stopPropagation()" (touchstart)="onResizeStart($event, 'top-left'); $event.stopPropagation()"></div>
                <div class="resize-handle tr" (mousedown)="onResizeStart($event, 'top-right'); $event.stopPropagation()" (touchstart)="onResizeStart($event, 'top-right'); $event.stopPropagation()"></div>
                <div class="resize-handle bl" (mousedown)="onResizeStart($event, 'bottom-left'); $event.stopPropagation()" (touchstart)="onResizeStart($event, 'bottom-left'); $event.stopPropagation()"></div>
                <div class="resize-handle br" (mousedown)="onResizeStart($event, 'bottom-right'); $event.stopPropagation()" (touchstart)="onResizeStart($event, 'bottom-right'); $event.stopPropagation()"></div>
              </div>
            </div>
          </div>

          <!-- Crop Controls & Sliders -->
          <div class="crop-sliders-box">
            <div class="slider-row">
              <span class="slider-label">Crop Width</span>
              <input type="range" min="20" max="95" [value]="cropBoxW" (input)="onCropWidthChange($event)" class="range-input" />
            </div>
            <div class="slider-row">
              <span class="slider-label">Crop Height</span>
              <input type="range" min="20" max="95" [value]="cropBoxH" (input)="onCropHeightChange($event)" class="range-input" />
            </div>
          </div>

          <div class="crop-actions-row">
            <button class="btn-crop-cancel" (click)="clearSelectedFile()">
              <span class="material-symbols-outlined">restart_alt</span>
              <span>Reset</span>
            </button>
            <button class="btn-crop-apply" (click)="performCrop()">
              <span class="material-symbols-outlined">crop</span>
              <span>Crop & Inspect</span>
            </button>
          </div>
        </div>

        <!-- STATE 4: Cropped & Verified Preview -->
        <div class="preview-result-card animated-fade-in" *ngIf="selectedFile && isCropped && !isCameraActive">
          <div class="result-header">
            <span class="material-symbols-outlined check-icon">verified</span>
            <div class="result-header-text">
              <span class="result-title">Ready for Verification</span>
              <span class="result-sub">Review your document before final submission</span>
            </div>
          </div>

          <!-- Image Preview -->
          <div class="cropped-image-view">
            <img [src]="croppedPreviewSrc" alt="Cropped Document" class="result-img" />
          </div>

          <!-- Quality Verification Checklist -->
          <div class="quality-checklist">
            <div class="quality-item">
              <span class="material-symbols-outlined quality-icon">check_circle</span>
              <span>All 4 document borders are contained</span>
            </div>
            <div class="quality-item">
              <span class="material-symbols-outlined quality-icon">check_circle</span>
              <span>Certificate text & dates are sharp</span>
            </div>
            <div class="quality-item">
              <span class="material-symbols-outlined quality-icon">check_circle</span>
              <span>No harsh reflections or shadows</span>
            </div>
          </div>

          <button class="btn-retake" (click)="clearSelectedFile()">
            <span class="material-symbols-outlined">refresh</span>
            <span>Retake / Choose Another Photo</span>
          </button>
        </div>

        <!-- 4. Upload Progress Bar (during submission) -->
        <div class="upload-progress-box animated-fade-in" *ngIf="uploadProgress > 0 && uploadProgress < 100">
          <div class="progress-bar-track">
            <div class="progress-bar-fill" [style.width.%]="uploadProgress"></div>
          </div>
          <div class="progress-labels">
            <span>Uploading Document...</span>
            <span class="progress-pct">{{ uploadProgress }}%</span>
          </div>
        </div>

      </main>

      <!-- 5. Sticky Bottom Action Footer -->
      <footer class="upload-footer">
        <button 
          class="btn-submit-upload"
          [disabled]="!croppedFile || isSubmitting"
          (click)="submitDocument()"
        >
          <span class="material-symbols-outlined" *ngIf="!isSubmitting">cloud_upload</span>
          <span class="material-symbols-outlined spinning" *ngIf="isSubmitting">refresh</span>
          <span>{{ isSubmitting ? 'Submitting to Dispatch...' : 'Submit for Verification' }}</span>
        </button>
      </footer>
    </div>
  `,
  styles: [`
    :host {
      display: block;
      min-height: 100vh;
      background-color: var(--background-color, #F8F9FA);
      color: var(--text-primary, #263238);
      font-family: 'Roboto', -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }

    .upload-container {
      padding: 12px 14px 80px 14px;
      max-width: 580px;
      margin: 0 auto;
      box-sizing: border-box;
    }

    /* 1. Header Bar */
    .upload-header {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 12px;
    }
    .back-nav-btn {
      width: 36px;
      height: 36px;
      border-radius: 50%;
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      color: #1E293B;
      box-shadow: 0 1px 4px rgba(0, 0, 0, 0.04);
    }
    .back-nav-btn .material-symbols-outlined {
      font-size: 20px;
    }
    .header-titles {
      display: flex;
      flex-direction: column;
    }
    .header-main-title {
      margin: 0;
      font-size: 16px;
      font-weight: 700;
      color: #0F172A;
      letter-spacing: -0.2px;
    }
    .header-sub-title {
      font-size: 11px;
      color: #64748B;
    }

    /* 2. Document Info Card */
    .doc-badge-card {
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 12px;
      padding: 12px;
      margin-bottom: 12px;
      display: flex;
      align-items: flex-start;
      gap: 10px;
      box-shadow: 0 2px 6px rgba(0, 0, 0, 0.02);
    }
    .badge-icon-box {
      width: 34px;
      height: 34px;
      border-radius: 8px;
      background: #FEE2E2;
      color: #DC2626;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }
    .badge-icon-box .material-symbols-outlined {
      font-size: 20px;
    }
    .badge-text-col {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .badge-label {
      font-size: 9px;
      font-weight: 700;
      color: #DC2626;
      text-transform: uppercase;
      letter-spacing: 0.3px;
    }
    .badge-title {
      font-size: 13px;
      font-weight: 700;
      color: #0F172A;
    }
    .badge-hint {
      font-size: 10.5px;
      color: #64748B;
      line-height: 1.35;
    }

    /* 3. Selection Card */
    .selection-card {
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 14px;
      padding: 14px;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.03);
    }
    .drop-zone {
      border: 2px dashed #CBD5E1;
      border-radius: 12px;
      padding: 24px 16px;
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
      cursor: pointer;
      background: #F8FAFC;
      transition: all 0.2s ease;
      margin-bottom: 12px;
    }
    .drop-zone.dragover, .drop-zone:hover {
      border-color: #CD1A21;
      background: #FFF5F5;
    }
    .drop-icon-wrapper {
      width: 48px;
      height: 48px;
      border-radius: 50%;
      background: #FEE2E2;
      color: #DC2626;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-bottom: 8px;
    }
    .drop-icon-wrapper .material-symbols-outlined {
      font-size: 26px;
    }
    .drop-title {
      margin: 0 0 2px 0;
      font-size: 14px;
      font-weight: 700;
      color: #0F172A;
    }
    .drop-sub {
      margin: 0 0 4px 0;
      font-size: 11px;
      color: #64748B;
    }
    .drop-formats {
      font-size: 10px;
      color: #94A3B8;
      font-weight: 500;
    }

    .action-buttons-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 10px;
      margin-bottom: 14px;
    }
    .btn-file-select, .btn-camera-launch {
      border-radius: 10px;
      padding: 10px 12px;
      border: 1px solid #E2E8F0;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      font-size: 12px;
      font-weight: 600;
      cursor: pointer;
      transition: background 0.15s ease;
    }
    .btn-file-select {
      background: #F1F5F9;
      color: #1E293B;
    }
    .btn-camera-launch {
      background: #CD1A21;
      color: #FFFFFF;
      border-color: #CD1A21;
    }
    .btn-file-select .material-symbols-outlined,
    .btn-camera-launch .material-symbols-outlined {
      font-size: 18px;
    }

    .guidelines-box {
      background: #F8FAFC;
      border-radius: 10px;
      padding: 10px 12px;
      border: 1px solid #E2E8F0;
    }
    .guidelines-head {
      display: flex;
      align-items: center;
      gap: 5px;
      font-size: 11px;
      font-weight: 700;
      color: #475569;
      margin-bottom: 6px;
    }
    .guidelines-head .material-symbols-outlined {
      font-size: 14px;
      color: #CD1A21;
    }
    .guidelines-list {
      margin: 0;
      padding-left: 16px;
      font-size: 10.5px;
      color: #64748B;
      line-height: 1.5;
    }

    /* Live Camera HUD */
    .camera-card {
      background: #000000;
      border-radius: 16px;
      overflow: hidden;
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
    }
    .camera-viewport-wrapper {
      position: relative;
      width: 100%;
      height: 360px;
      overflow: hidden;
      display: flex;
      align-items: center;
      justify-content: center;
      background: #000000;
    }
    .camera-video {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
    .camera-hud-overlay {
      position: absolute;
      top: 20px;
      left: 20px;
      right: 20px;
      bottom: 20px;
      pointer-events: none;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .hud-corner {
      position: absolute;
      width: 28px;
      height: 28px;
      border-color: #10B981;
      border-style: solid;
    }
    .hud-corner.top-left { top: 0; left: 0; border-width: 3px 0 0 3px; border-top-left-radius: 8px; }
    .hud-corner.top-right { top: 0; right: 0; border-width: 3px 3px 0 0; border-top-right-radius: 8px; }
    .hud-corner.bottom-left { bottom: 0; left: 0; border-width: 0 0 3px 3px; border-bottom-left-radius: 8px; }
    .hud-corner.bottom-right { bottom: 0; right: 0; border-width: 0 3px 3px 0; border-bottom-right-radius: 8px; }
    .hud-instruction {
      background: rgba(0, 0, 0, 0.65);
      color: #FFFFFF;
      padding: 4px 10px;
      border-radius: 20px;
      font-size: 11px;
      font-weight: 500;
      position: absolute;
      bottom: 10px;
    }

    .camera-controls-bar {
      padding: 14px 20px;
      background: #111827;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .btn-cam-cancel {
      background: transparent;
      border: 1px solid #374151;
      color: #E5E7EB;
      padding: 6px 12px;
      border-radius: 8px;
      font-size: 12px;
      font-weight: 600;
      display: flex;
      align-items: center;
      gap: 4px;
      cursor: pointer;
    }
    .btn-cam-shutter {
      width: 54px;
      height: 54px;
      border-radius: 50%;
      background: #FFFFFF;
      border: 3px solid #E5E7EB;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      box-shadow: 0 0 16px rgba(255, 255, 255, 0.3);
    }
    .shutter-inner {
      width: 42px;
      height: 42px;
      border-radius: 50%;
      background: #CD1A21;
      color: #FFFFFF;
      display: flex;
      align-items: center;
      justify-content: center;
    }

    /* Cropping Viewport */
    .cropping-card {
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 14px;
      padding: 12px;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.03);
    }
    .crop-header-bar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 10px;
    }
    .crop-title {
      font-size: 13px;
      font-weight: 700;
      color: #0F172A;
    }
    .rotate-tool-btn {
      background: #F1F5F9;
      border: 1px solid #E2E8F0;
      padding: 4px 8px;
      border-radius: 6px;
      font-size: 11px;
      font-weight: 600;
      color: #334155;
      display: flex;
      align-items: center;
      gap: 4px;
      cursor: pointer;
    }
    .rotate-tool-btn .material-symbols-outlined {
      font-size: 14px;
    }

    .crop-viewport-outer {
      background: #0F172A;
      border-radius: 10px;
      padding: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-bottom: 10px;
    }
    .crop-viewport {
      position: relative;
      max-width: 100%;
      max-height: 280px;
      display: inline-block;
      overflow: hidden;
    }
    .crop-base-img {
      max-width: 100%;
      max-height: 280px;
      display: block;
      transition: transform 0.2s ease;
    }
    .crop-box-rect {
      position: absolute;
      border: 2px solid #38BDF8;
      box-shadow: 0 0 0 9999px rgba(0, 0, 0, 0.55);
      cursor: move;
      touch-action: none;
    }
    .resize-handle {
      position: absolute;
      width: 14px;
      height: 14px;
      background: #38BDF8;
      border: 2px solid #FFFFFF;
      border-radius: 50%;
    }
    .resize-handle.tl { top: -7px; left: -7px; cursor: nwse-resize; }
    .resize-handle.tr { top: -7px; right: -7px; cursor: nesw-resize; }
    .resize-handle.bl { bottom: -7px; left: -7px; cursor: nesw-resize; }
    .resize-handle.br { bottom: -7px; right: -7px; cursor: nwse-resize; }

    .crop-sliders-box {
      background: #F8FAFC;
      border-radius: 8px;
      padding: 8px 10px;
      border: 1px solid #E2E8F0;
      display: flex;
      flex-direction: column;
      gap: 6px;
      margin-bottom: 10px;
    }
    .slider-row {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .slider-label {
      font-size: 10px;
      font-weight: 600;
      color: #64748B;
      width: 65px;
      flex-shrink: 0;
    }
    .range-input {
      flex: 1;
      accent-color: #CD1A21;
    }

    .crop-actions-row {
      display: flex;
      gap: 8px;
      justify-content: flex-end;
    }
    .btn-crop-cancel {
      background: #F1F5F9;
      border: 1px solid #CBD5E1;
      padding: 8px 14px;
      border-radius: 8px;
      font-size: 12px;
      font-weight: 600;
      color: #475569;
      display: flex;
      align-items: center;
      gap: 4px;
      cursor: pointer;
    }
    .btn-crop-apply {
      background: #10B981;
      color: #FFFFFF;
      border: none;
      padding: 8px 16px;
      border-radius: 8px;
      font-size: 12px;
      font-weight: 600;
      display: flex;
      align-items: center;
      gap: 4px;
      cursor: pointer;
    }

    /* Preview Result Card */
    .preview-result-card {
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 14px;
      padding: 12px;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.03);
    }
    .result-header {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 10px;
    }
    .check-icon {
      font-size: 22px;
      color: #10B981;
    }
    .result-header-text {
      display: flex;
      flex-direction: column;
    }
    .result-title {
      font-size: 13px;
      font-weight: 700;
      color: #0F172A;
    }
    .result-sub {
      font-size: 10.5px;
      color: #64748B;
    }
    .cropped-image-view {
      background: #F8FAFC;
      border: 1px solid #E2E8F0;
      border-radius: 10px;
      padding: 6px;
      display: flex;
      justify-content: center;
      margin-bottom: 10px;
    }
    .result-img {
      max-width: 100%;
      max-height: 240px;
      object-fit: contain;
      border-radius: 6px;
    }
    .quality-checklist {
      background: #F8FAFC;
      border-radius: 8px;
      padding: 8px 10px;
      border: 1px solid #E2E8F0;
      display: flex;
      flex-direction: column;
      gap: 4px;
      margin-bottom: 10px;
    }
    .quality-item {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 11px;
      color: #334155;
    }
    .quality-icon {
      font-size: 14px;
      color: #10B981;
    }
    .btn-retake {
      width: 100%;
      background: #F1F5F9;
      border: 1px solid #E2E8F0;
      padding: 8px;
      border-radius: 8px;
      font-size: 11px;
      font-weight: 600;
      color: #475569;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 4px;
      cursor: pointer;
    }

    /* Upload Progress Box */
    .upload-progress-box {
      margin-top: 12px;
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 10px;
      padding: 10px 12px;
    }
    .progress-bar-track {
      width: 100%;
      height: 6px;
      background: #E2E8F0;
      border-radius: 3px;
      overflow: hidden;
      margin-bottom: 6px;
    }
    .progress-bar-fill {
      height: 100%;
      background: linear-gradient(90deg, #CD1A21, #EF4444);
      border-radius: 3px;
      transition: width 0.3s ease;
    }
    .progress-labels {
      display: flex;
      justify-content: space-between;
      font-size: 11px;
      color: #475569;
      font-weight: 600;
    }
    .progress-pct {
      color: #CD1A21;
    }

    /* Sticky Bottom Footer */
    .upload-footer {
      position: fixed;
      bottom: 0;
      left: 0;
      right: 0;
      padding: 10px 16px 14px 16px;
      background: #FFFFFF;
      border-top: 1px solid #E2E8F0;
      box-shadow: 0 -4px 14px rgba(0, 0, 0, 0.05);
      display: flex;
      justify-content: center;
      z-index: 100;
    }
    .btn-submit-upload {
      max-width: 580px;
      width: 100%;
      background: linear-gradient(135deg, #CD1A21 0%, #B71C1C 100%);
      color: #FFFFFF;
      border: none;
      padding: 12px;
      border-radius: 12px;
      font-size: 14px;
      font-weight: 700;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      cursor: pointer;
      box-shadow: 0 4px 12px rgba(205, 26, 33, 0.25);
      transition: opacity 0.15s ease;
    }
    .btn-submit-upload:disabled {
      opacity: 0.5;
      cursor: not-allowed;
      box-shadow: none;
    }
    .spinning {
      animation: spin 0.8s linear infinite;
    }
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }

    .animated-fade-in {
      animation: fadeIn 0.25s ease-in-out;
    }
    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }

    /* Dark Mode Support */
    :host-context(.dark-theme) {
      background-color: #121214 !important;
      color: #ECEFF1 !important;
    }
    :host-context(.dark-theme) .upload-footer {
      background: #1E1E24;
      border-top-color: #2D2D35;
    }
    :host-context(.dark-theme) .back-nav-btn {
      background: #1E1E24;
      border-color: #2D2D35;
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .header-main-title {
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .doc-badge-card,
    :host-context(.dark-theme) .selection-card,
    :host-context(.dark-theme) .cropping-card,
    :host-context(.dark-theme) .preview-result-card,
    :host-context(.dark-theme) .upload-progress-box {
      background: #1E1E24;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .badge-title,
    :host-context(.dark-theme) .drop-title,
    :host-context(.dark-theme) .crop-title,
    :host-context(.dark-theme) .result-title {
      color: #ECEFF1;
    }
    :host-context(.dark-theme) .drop-zone {
      background: #16161A;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .btn-file-select,
    :host-context(.dark-theme) .guidelines-box,
    :host-context(.dark-theme) .crop-sliders-box,
    :host-context(.dark-theme) .cropped-image-view,
    :host-context(.dark-theme) .quality-checklist,
    :host-context(.dark-theme) .btn-retake {
      background: #16161A;
      border-color: #2D2D35;
    }
    :host-context(.dark-theme) .btn-file-select,
    :host-context(.dark-theme) .rotate-tool-btn,
    :host-context(.dark-theme) .btn-crop-cancel {
      background: #2D2D35;
      color: #ECEFF1;
      border-color: #3E3E48;
    }
  `]
})
export class DocumentUploadComponent implements OnInit, OnDestroy {
  @ViewChild('fileInput') fileInput!: ElementRef<HTMLInputElement>;
  @ViewChild('videoElement') videoElement!: ElementRef<HTMLVideoElement>;
  @ViewChild('cropContainer') cropContainer!: ElementRef<HTMLDivElement>;
  @ViewChild('cropImg') cropImg!: ElementRef<HTMLImageElement>;

  docType = 0;
  docName = 'Document';

  selectedFile: File | null = null;
  imageSrc: string | null = null;
  croppedPreviewSrc: string | null = null;
  croppedFile: File | null = null;

  isCameraActive = false;
  mediaStream: MediaStream | null = null;

  isCropped = false;
  isSubmitting = false;
  uploadProgress = 0;
  isDragging = false;

  // Cropping variables
  cropBoxX = 10;
  cropBoxY = 10;
  cropBoxW = 80;
  cropBoxH = 80;
  rotationAngle = 0;

  isDraggingBox = false;
  isResizing = false;
  resizeHandleType = '';
  dragStartMouseX = 0;
  dragStartMouseY = 0;
  dragStartBoxX = 0;
  dragStartBoxY = 0;
  dragStartBoxW = 0;
  dragStartBoxH = 0;

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private driverService: DriverService,
    private snackBar: MatSnackBar,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.route.queryParams.subscribe(params => {
      this.docType = Number(params['type']) || 0;
      this.docName = params['name'] || 'Document';
    });
  }

  ngOnDestroy(): void {
    this.stopCamera();
  }

  goBack(): void {
    this.stopCamera();
    this.router.navigate(['/profile']);
  }

  triggerFileSelect(): void {
    this.fileInput.nativeElement.click();
  }

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files[0]) {
      this.handleFile(input.files[0]);
    }
  }

  onDragOver(event: DragEvent): void {
    event.preventDefault();
    this.isDragging = true;
  }

  onDragLeave(event: DragEvent): void {
    event.preventDefault();
    this.isDragging = false;
  }

  onFileDrop(event: DragEvent): void {
    event.preventDefault();
    this.isDragging = false;
    if (event.dataTransfer?.files && event.dataTransfer.files[0]) {
      this.handleFile(event.dataTransfer.files[0]);
    }
  }

  handleFile(file: File): void {
    this.selectedFile = file;
    this.isCropped = false;
    this.rotationAngle = 0;
    
    const reader = new FileReader();
    reader.onload = (e) => {
      this.imageSrc = e.target?.result as string;
      this.cdr.detectChanges();
    };
    reader.readAsDataURL(file);
  }

  startCamera(): void {
    if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
      navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'environment', width: { ideal: 1920 }, height: { ideal: 1080 } }
      }).then(stream => {
        this.mediaStream = stream;
        this.isCameraActive = true;
        this.cdr.detectChanges();
        setTimeout(() => {
          if (this.videoElement) {
            this.videoElement.nativeElement.srcObject = stream;
          }
        }, 100);
      }).catch(err => {
        console.error('Camera access error:', err);
        this.snackBar.open('Unable to access device camera. Please check camera permissions.', 'Dismiss', {
          duration: 3500
        });
      });
    }
  }

  stopCamera(): void {
    if (this.mediaStream) {
      this.mediaStream.getTracks().forEach(track => track.stop());
      this.mediaStream = null;
    }
    this.isCameraActive = false;
  }

  capturePhoto(): void {
    if (!this.videoElement) return;
    const video = this.videoElement.nativeElement;
    const canvas = document.createElement('canvas');
    canvas.width = video.videoWidth || 1280;
    canvas.height = video.videoHeight || 720;
    const ctx = canvas.getContext('2d');
    if (ctx) {
      ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
      canvas.toBlob((blob) => {
        if (blob) {
          const file = new File([blob], `document_capture_${Date.now()}.jpg`, { type: 'image/jpeg' });
          this.stopCamera();
          this.handleFile(file);
        }
      }, 'image/jpeg', 0.92);
    }
  }

  onImageLoaded(): void {
    this.cropBoxX = 10;
    this.cropBoxY = 10;
    this.cropBoxW = 80;
    this.cropBoxH = 80;
    this.cdr.detectChanges();
  }

  rotateRight(): void {
    this.rotationAngle = (this.rotationAngle + 90) % 360;
    this.cdr.detectChanges();
  }

  onCropWidthChange(event: Event): void {
    const val = Number((event.target as HTMLInputElement).value);
    if (!isNaN(val)) {
      this.cropBoxW = val;
      this.updateCropBox();
    }
  }

  onCropHeightChange(event: Event): void {
    const val = Number((event.target as HTMLInputElement).value);
    if (!isNaN(val)) {
      this.cropBoxH = val;
      this.updateCropBox();
    }
  }

  updateCropBox(): void {
    if (this.cropBoxX + this.cropBoxW > 100) this.cropBoxX = 100 - this.cropBoxW;
    if (this.cropBoxY + this.cropBoxH > 100) this.cropBoxY = 100 - this.cropBoxH;
    this.cdr.detectChanges();
  }

  onDragStart(event: MouseEvent | TouchEvent): void {
    event.preventDefault();
    this.isDraggingBox = true;
    const clientX = 'touches' in event ? event.touches[0].clientX : event.clientX;
    const clientY = 'touches' in event ? event.touches[0].clientY : event.clientY;
    this.dragStartMouseX = clientX;
    this.dragStartMouseY = clientY;
    this.dragStartBoxX = this.cropBoxX;
    this.dragStartBoxY = this.cropBoxY;

    const moveListener = (moveEvent: MouseEvent | TouchEvent) => {
      if (!this.isDraggingBox) return;
      const mX = 'touches' in moveEvent ? moveEvent.touches[0].clientX : moveEvent.clientX;
      const mY = 'touches' in moveEvent ? moveEvent.touches[0].clientY : moveEvent.clientY;
      const dx = ((mX - this.dragStartMouseX) / this.cropContainer.nativeElement.clientWidth) * 100;
      const dy = ((mY - this.dragStartMouseY) / this.cropContainer.nativeElement.clientHeight) * 100;

      let newX = this.dragStartBoxX + dx;
      let newY = this.dragStartBoxY + dy;

      newX = Math.max(0, Math.min(100 - this.cropBoxW, newX));
      newY = Math.max(0, Math.min(100 - this.cropBoxH, newY));

      this.cropBoxX = Math.round(newX);
      this.cropBoxY = Math.round(newY);
      this.cdr.detectChanges();
    };

    const upListener = () => {
      this.isDraggingBox = false;
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

    const x = (this.cropBoxX / 100) * tempCanvas.width;
    const y = (this.cropBoxY / 100) * tempCanvas.height;
    const w = (this.cropBoxW / 100) * tempCanvas.width;
    const h = (this.cropBoxH / 100) * tempCanvas.height;

    canvas.width = w;
    canvas.height = h;
    ctx.drawImage(tempCanvas, x, y, w, h, 0, 0, w, h);

    this.croppedPreviewSrc = canvas.toDataURL('image/jpeg', 0.9);

    canvas.toBlob((blob) => {
      if (blob) {
        this.croppedFile = new File([blob], this.selectedFile!.name, { type: 'image/jpeg' });
        this.isCropped = true;
        this.cdr.detectChanges();
        this.snackBar.open('Document cropped successfully!', 'Dismiss', {
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
        
        try {
          localStorage.setItem('pending_upload_' + this.docType, 'true');
        } catch (e) {
          console.warn('Failed to write to localStorage:', e);
        }

        this.snackBar.open('Document uploaded for verification successfully!', 'Dismiss', {
          duration: 2500
        });
        
        setTimeout(() => {
          this.router.navigate(['/profile']);
        }, 1200);
      }
    });
  }
}
