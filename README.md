ProvisioningProfileCleaner
==========================

Command line tool / Xcode Plugin to clean up your Provisioning profile folder!

Run it from anywhere (even just run / build it in Xcode) and it will take your profiles in ~/Library/MobileDevice/Provisioning Profiles and organize them
into Duplicate Profiles / Expired Profiles / Invalid Profiles folders as necessary. 

- Expired Profiles are passed their expiration date and are no longer valid.
- Duplicate profiles are profiles where you have a newer version of them (generally with more UDID's) that should be ignored
- Invalid Profiles are ones that don't have an active / valid keychain certificate to sign from. Profiles in this folder should NOT be expired, just invalid.

This command line tool is structured to be non destructive, that is why files are moved into new folders so you can inspect them as necessary, inside each
folder there is a log that will accompany it with text similar to the following: 

The following provisioning profiles have newer duplicates:
---------------------------------------------------

Profile PROFILE_UDID.mobileprovision has duplicates!
it expires on 2015-03-13 16:01:35 +0000 with team: Your Company, LLC (UNIQUE_CERT_ID)
profile name: CatchAllProfile 
appID: UNIQUE_CERT_ID.* appIDName: Xcode: iOS Wildcard App ID


The following provisioning profiles have expired:
---------------------------------------------------

Profile PROFILE_UDID.mobileprovision expired on 2013-10-18 06:24:40 +0000
with team: Your Name (UNIQUE_CERT_ID) profile name: Your Profile Name
appID: UNIQUE_CERT_ID.com.yourcompany.AppName appIDName: Your App ID Name

Future Plans
------------
 Make it into a companion Xcode plugin and get it added to Alcatraz
