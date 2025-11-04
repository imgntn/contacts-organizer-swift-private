# Hosting Privacy Policy and Support Pages

This document explains how to host the `privacy-policy.html` and `support.html` files for your Contacts Organizer app.

## Quick Setup with GitHub Pages (Recommended)

GitHub Pages is free and easy to set up:

### Step 1: Create a GitHub Repository

1. Go to [GitHub.com](https://github.com) and sign in
2. Click the "+" icon in the top right → "New repository"
3. Name it something like `contacts-organizer-web`
4. Make it **Public**
5. Click "Create repository"

### Step 2: Upload the HTML Files

1. In your new repository, click "Add file" → "Upload files"
2. Drag and drop both files:
   - `privacy-policy.html`
   - `support.html`
3. Click "Commit changes"

### Step 3: Enable GitHub Pages

1. In your repository, go to Settings → Pages
2. Under "Source", select "main" branch
3. Click "Save"
4. Wait a few minutes for deployment

### Step 4: Get Your URLs

Your pages will be available at:
```
https://[YOUR_USERNAME].github.io/contacts-organizer-web/privacy-policy.html
https://[YOUR_USERNAME].github.io/contacts-organizer-web/support.html
```

## Alternative: Custom Domain

If you have your own website:

1. Upload both HTML files to your web server
2. Your URLs will be something like:
   ```
   https://yourwebsite.com/privacy-policy.html
   https://yourwebsite.com/support.html
   ```

## Update the App

Once hosted, update the URLs in `SettingsView.swift`:

```swift
// In AboutView, replace:
Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
Link("Support", destination: URL(string: "https://example.com/support")!)

// With your actual URLs:
Link("Privacy Policy", destination: URL(string: "https://[YOUR_USERNAME].github.io/contacts-organizer-web/privacy-policy.html")!)
Link("Support", destination: URL(string: "https://[YOUR_USERNAME].github.io/contacts-organizer-web/support.html")!)
```

## Before Publishing

Before hosting, update the placeholder text in both HTML files:

### In `privacy-policy.html`:
- Replace `[YOUR_EMAIL_HERE]` with your support email
- Replace `[YOUR_WEBSITE_HERE]` with your website (or GitHub profile URL)

### In `support.html`:
- Replace `[YOUR_EMAIL_HERE]` with your support email

## Testing

After uploading:
1. Visit your URLs in a web browser
2. Make sure both pages load correctly
3. Test the links in the app's Settings → About section

## Apple App Store Requirements

Apple requires:
- ✅ A privacy policy URL (you now have this)
- ✅ Support URL or email (you now have this)

These URLs will be entered in App Store Connect when you submit your app.
