# Team Configuration - Playable Future LLC

## Apple Developer Account Details

- **Organization Name**: Playable Future LLC
- **Team ID**: FBK354237N
- **Account Type**: Organization
- **Status**: ✅ Active

## Bundle Identifier Configuration

### Recommended Bundle ID
```
com.playablefuture.contactsorganizer
```

**Format**: `com.[company].[appname]`
- Must be globally unique
- Use lowercase, no spaces
- Can only use letters, numbers, hyphens, periods
- Cannot start with number or period

### Alternative Bundle IDs (if first is taken)
```
com.playablefuture.contacts-organizer
com.playablefuture.contacts
com.playablefuture.contactmanager
```

## Xcode Configuration Steps

### 1. Create New Xcode Project

1. Open Xcode
2. File → New → Project
3. Select: **macOS** → **App**
4. Configure project:
   - **Product Name**: `Contacts Organizer`
   - **Team**: `Playable Future LLC (FBK354237N)`
   - **Organization Identifier**: `com.playablefuture`
   - **Bundle Identifier**: `com.playablefuture.contactsorganizer` (auto-fills)
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Include Tests**: ✅
5. Save location: `/Volumes/CORSAIR/swift_contacts_organizer/`

### 2. Verify Team in Xcode

1. Xcode → Settings → Accounts
2. Verify your Apple ID is signed in
3. Under "Apple ID → Playable Future LLC", you should see:
   - Team Name: Playable Future LLC
   - Team ID: FBK354237N
   - Role: (your role - likely Admin or Account Holder)

### 3. Configure Signing & Capabilities

1. Select project in navigator
2. Select "Contacts Organizer" target
3. **Signing & Capabilities** tab:
   - **Automatically manage signing**: ✅ (recommended)
   - **Team**: Select "Playable Future LLC (FBK354237N)"
   - **Signing Certificate**: Mac App Distribution (Xcode will create)
   - **Provisioning Profile**: Xcode Managed Profile

4. **Add Capabilities**:
   - Click "+ Capability"
   - Add "App Sandbox"
   - Under App Sandbox:
     - ✅ Contacts (under Personal Information)
     - ✅ User Selected Files (under File Access, Read/Write)

### 4. Update Info.plist

The Info.plist in `SupportingFiles/` already has the correct configuration, but verify:

```xml
<key>CFBundleIdentifier</key>
<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>

<key>NSContactsUsageDescription</key>
<string>Contacts Organizer needs access to your contacts to help you find and merge duplicates, organize contacts into smart groups, and improve your contact data quality. All processing happens locally on your Mac and your data never leaves your device.</string>
```

## App Store Connect Configuration

### App Record Setup

When creating your app in App Store Connect:

1. **Platform**: macOS
2. **Name**: Contacts Organizer (or alternative if taken)
3. **Primary Language**: English (U.S.)
4. **Bundle ID**: Select `com.playablefuture.contactsorganizer`
5. **SKU**: `contacts-organizer-playablefuture-001`
6. **User Access**: Full Access

### Organization Information

Your app will be published under:
- **Developer Name**: Playable Future LLC
- **Seller Name**: Playable Future LLC (as shown in App Store)

## Code Signing Certificates

Xcode will automatically create these certificates for you:

1. **Development**: Mac Development
   - Used for: Local testing and debugging
   - Created automatically when you build

2. **Distribution**: Mac App Distribution
   - Used for: App Store submission
   - Created automatically when you archive

You can view these in:
- Xcode → Settings → Accounts → Manage Certificates
- Or: https://developer.apple.com/account/resources/certificates/list

## Provisioning Profiles

Xcode manages these automatically with "Automatically manage signing" enabled.

To view:
- https://developer.apple.com/account/resources/profiles/list

## Bundle ID Registration

Your bundle ID `com.playablefuture.contactsorganizer` will be automatically registered when you:
1. Build the project in Xcode with your team selected
2. Or manually register at: https://developer.apple.com/account/resources/identifiers/list

### Capabilities to Enable on Bundle ID
- ✅ App Sandbox
- ✅ Personal Information (Contacts)

## Banking and Tax Setup

**IMPORTANT**: Complete this in App Store Connect before you can sell apps.

1. Go to: https://appstoreconnect.apple.com
2. Agreements, Tax, and Banking
3. Complete:
   - **Paid Applications Agreement** (sign as organization)
   - **Tax Forms**:
     - US LLC: Form W-9
     - Non-US: Form W-8BEN-E (for entity)
   - **Banking Information**:
     - US bank account in Playable Future LLC's name
     - Or international bank with SWIFT code

## App Naming Options

If "Contacts Organizer" is taken on App Store:

**Alternative Names**:
1. Contacts Cleaner
2. Clean Contacts
3. Contact Manager Pro
4. Duplicate Contact Finder
5. My Contacts Organizer
6. Playable Contacts (uses your brand)

Check availability at: https://appstoreconnect.apple.com

## Support and Marketing URLs

You'll need these for App Store Connect:

**Support URL** (required):
- Create: support@playablefuture.com email
- Or: https://playablefuture.com/contacts-organizer/support
- Or: GitHub Issues page

**Marketing URL** (optional):
- https://playablefuture.com/contacts-organizer
- Product landing page

**Privacy Policy URL** (required):
- https://playablefuture.com/privacy
- Or: https://playablefuture.github.io/privacy

## Team Roles

If you have multiple team members, assign roles in App Store Connect:

- **Account Holder**: Full access (typically one person)
- **Admin**: Can manage users and apps
- **App Manager**: Can manage apps and submissions
- **Developer**: Can access certificates and profiles
- **Marketing**: Can manage metadata only
- **Sales**: Can view sales reports only

Manage at: https://appstoreconnect.apple.com/access/users

## Next Immediate Steps

Now that you have your team configured:

1. ✅ **Open Xcode** and create the project with your team
2. ✅ **Import source files** from ContactsOrganizer/ directory
3. ✅ **Test build** to verify everything compiles
4. → **Design app icon** (next priority)
5. → **Set up App Store Connect** with your team

## Quick Reference

| Setting | Value |
|---------|-------|
| Team Name | Playable Future LLC |
| Team ID | FBK354237N |
| Organization ID | com.playablefuture |
| Bundle ID | com.playablefuture.contactsorganizer |
| SKU | contacts-organizer-playablefuture-001 |
| Category | Productivity |
| Price | $9.99 or $14.99 (recommend) |

## Questions?

- Apple Developer Support: https://developer.apple.com/contact/
- App Store Connect Help: https://developer.apple.com/help/app-store-connect/
- Team ID Verification: https://developer.apple.com/account/#/membership

---

**Status**: ✅ Team Active - Ready to create Xcode project!
