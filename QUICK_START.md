# Quick Start Guide - Playable Future LLC

You're enrolled in the Apple Developer Program! Here's what to do RIGHT NOW.

## ✅ What You Have

- Apple Developer Program membership (Playable Future LLC)
- Team ID: FBK354237N
- Complete Swift/SwiftUI codebase
- All configuration files ready

## 🚀 Next 2 Hours - Get It Running

### Step 1: Open Xcode (10 minutes)

```bash
cd /Volumes/CORSAIR/swift_contacts_organizer
open -a Xcode
```

1. In Xcode: **File → New → Project**
2. Choose: **macOS** → **App**
3. Click **Next**

### Step 2: Configure Project (5 minutes)

Fill in these EXACT values:

| Field | Value |
|-------|-------|
| Product Name | `Contacts Organizer` |
| Team | **Playable Future LLC (FBK354237N)** ⭐ |
| Organization Identifier | `com.playablefuture` |
| Bundle Identifier | `com.playablefuture.contactsorganizer` (auto-fills) |
| Interface | SwiftUI |
| Language | Swift |
| Storage | None |
| Include Tests | ✅ Checked |

Click **Next**, save to `/Volumes/CORSAIR/swift_contacts_organizer/`

### Step 3: Add Your Team in Xcode (2 minutes)

1. **Xcode → Settings** (Cmd+,)
2. Click **Accounts** tab
3. Click **+** → **Apple ID**
4. Sign in with your Apple ID (the one enrolled in Developer Program)
5. Verify you see: **Playable Future LLC (FBK354237N)**

### Step 4: Import Source Files (15 minutes)

1. In Xcode, **right-click** on the "Contacts Organizer" folder (blue icon)
2. Select **Add Files to "Contacts Organizer"**
3. Navigate to `/Volumes/CORSAIR/swift_contacts_organizer/ContactsOrganizer/`
4. Select these folders:
   - `App/`
   - `Models/`
   - `Services/`
   - `Views/`
   - `SupportingFiles/`
5. **IMPORTANT**: Check these options:
   - ✅ **Copy items if needed**
   - 🔘 **Create groups** (not folder references)
   - ✅ **Contacts Organizer** target
6. Click **Add**

### Step 5: Clean Up Duplicates (5 minutes)

Xcode created some default files we don't need:

1. Find and **DELETE** (move to trash):
   - `ContentView.swift` (Xcode's default - we have our own)
   - `ContactsOrganizerApp.swift` (Xcode's default - we have our own)
   - Any duplicate `Assets.xcassets` or `Info.plist`

2. Keep ONLY the files you imported from `ContactsOrganizer/`

### Step 6: Configure Signing (5 minutes)

1. Click project name in navigator (top item with blue icon)
2. Select **"Contacts Organizer"** under TARGETS
3. Click **Signing & Capabilities** tab
4. Set:
   - **Automatically manage signing**: ✅
   - **Team**: **Playable Future LLC (FBK354237N)**
   - Should say: "Signing Certificate: Mac Development"

### Step 7: Add App Sandbox (3 minutes)

Still in **Signing & Capabilities**:

1. Click **+ Capability** button
2. Double-click **App Sandbox**
3. Under "App Sandbox" section that appears:
   - Expand **Personal Information**
   - ✅ Check **Contacts**
   - Expand **File Access**
   - ✅ Check **User Selected Files** (Read/Write)

### Step 8: Configure Info.plist (5 minutes)

1. In navigator, find `ContactsOrganizer/SupportingFiles/Info.plist`
2. Click on it
3. Verify you see:
   - `NSContactsUsageDescription` with text about needing contacts access
   - `LSApplicationCategoryType` = `public.app-category.productivity`

If it's not there:
1. Select your target → Info tab
2. Custom macOS Target Properties
3. Add the Info.plist from SupportingFiles

### Step 9: Build! (2 minutes)

1. Select **"My Mac"** as the run destination (top left, next to project name)
2. Press **Cmd+B** to build
3. Watch for errors in the Issues navigator (⚠️ icon)

**Common Issues**:
- "Cannot find 'CNContact' in scope" → Add Contacts framework
- "Duplicate symbol" → You have duplicate files, delete Xcode's defaults
- Build settings errors → Check deployment target is macOS 12.0+

### Step 10: Run! (1 minute)

1. Press **Cmd+R** (or click ▶️ Play button)
2. You should see the **Onboarding screen**!
3. Click through onboarding → Grant Contacts permission
4. See your actual contacts in the app!

## ✅ Success Checklist

After completing the above, you should have:

- [x] Xcode project created with Playable Future LLC team
- [x] All source files imported
- [x] App Sandbox enabled with Contacts access
- [x] Code signing configured
- [x] App builds without errors
- [x] App runs and shows onboarding
- [x] Can grant Contacts permission
- [x] Can see your contacts in the app

## 🎉 You Did It!

Your app is now running locally! Time to celebrate for 5 minutes, then move on to...

## 📋 Next Steps (Do Tomorrow)

### Priority 1: Test Thoroughly (4-6 hours)

Run through all features:
- [ ] Onboarding flow
- [ ] Permission request and denial
- [ ] Dashboard shows correct statistics
- [ ] Duplicate detection finds real duplicates
- [ ] Data quality analysis identifies issues
- [ ] Settings view works
- [ ] App handles permission revocation

**IMPORTANT**: Backup your contacts first!
```bash
# Open Contacts, then:
File → Export → Export vCard
```

### Priority 2: Design App Icon (2-4 hours)

Requirements:
- 1024 x 1024 pixels
- PNG format
- Display P3 color space
- No transparency

**Design Ideas**:
- Two overlapping contact cards merging
- Magnifying glass over contacts
- Clean, organized contact book icon
- Use colors: Blue, Green, or Purple (productivity vibes)

**Tools to Use**:
- Figma (free): https://figma.com
- Sketch ($99/year)
- Canva (free): https://canva.com
- Icon generator: https://appicon.co

**Add to Xcode**:
1. Open `Assets.xcassets`
2. Click "AppIcon"
3. Drag your 1024x1024 PNG into the "Mac" slot

### Priority 3: Take Screenshots (2-3 hours)

Need 3-10 screenshots at 2880x1800 pixels showing:

1. **Dashboard Overview** - Statistics and health score
2. **Duplicate Detection** - Show duplicate groups found
3. **Data Quality** - Show cleanup recommendations
4. **Before/After** - Show improvement after cleanup (optional)
5. **Permission Request** - Privacy-first messaging (optional)

**How to Capture**:
```bash
# Run app in full screen, then:
Cmd+Shift+4 → Space → Click window
```

Resize to exactly 2880x1800 in Preview or Photoshop.

## 🗓️ This Week's Plan

| Day | Task | Time |
|-----|------|------|
| **Today** | ✅ Create Xcode project and run locally | 2 hours |
| **Tomorrow** | Test all features thoroughly | 4-6 hours |
| **Day 3** | Design app icon | 2-4 hours |
| **Day 4** | Take and edit screenshots | 2-3 hours |
| **Day 5** | Write privacy policy, set up hosting | 2-3 hours |
| **Day 6** | Create App Store Connect listing | 2-3 hours |
| **Day 7** | Final testing and polish | 3-4 hours |

**Total**: About 15-25 hours of focused work

## 📱 Contact Information to Add

When setting up App Store Connect, you'll need:

**Support Email**:
- Create: support@playablefuture.com
- Or use: your-email@playablefuture.com

**Privacy Policy URL**:
- Host at: https://playablefuture.com/contacts-organizer/privacy
- Or use: GitHub Pages (free)

**Marketing URL** (optional):
- https://playablefuture.com/contacts-organizer

## 💡 Pro Tips

1. **Test with a test contacts database**: Create a separate user account on your Mac for testing
2. **Backup everything**: Time Machine before major changes
3. **Version control**: Consider adding this to git (create .gitignore first)
4. **Take notes**: Document any bugs or issues you find
5. **Ask for feedback**: Show it to friends/colleagues before submitting

## 🆘 Having Issues?

### App won't build?
- Check target → Build Settings → Deployment Target is 12.0 or higher
- Make sure you deleted Xcode's default files
- Clean build folder: Product → Clean Build Folder (Cmd+Shift+K)

### Can't select team?
- Xcode → Settings → Accounts → verify Apple ID is signed in
- Wait a few minutes for Xcode to sync with Apple servers
- Sign out and sign back in

### Permission not working?
- Check Info.plist has `NSContactsUsageDescription`
- Check App Sandbox has Contacts enabled
- Reset permissions: `tccutil reset AddressBook`

### Still stuck?
- Check `SETUP_GUIDE.md` for detailed troubleshooting
- Search Apple Developer Forums
- Check Console app for error messages

## 🎯 Your Goal This Week

By end of week, you should have:
- ✅ App running locally with no issues
- ✅ App icon designed and added
- ✅ Screenshots taken and edited
- ✅ Privacy policy written and hosted
- ✅ App Store Connect listing created

Next week: Submit for review!

## 📚 Reference Files

- `TEAM_CONFIG.md` - Your team-specific configuration
- `SETUP_GUIDE.md` - Complete App Store submission guide
- `NEXT_STEPS.md` - Week-by-week checklist
- `README.md` - Project architecture and documentation

---

**Current Status**: 🟢 Developer Account Active - Ready to Build!

Let's ship this app! 🚀
