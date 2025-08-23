## SabarApp ##

### UserProfileSetup ###
Profile Data created with 
- UID
- Email
- Name
- Age
- ReligiousLevel
- Country
When user chooses their religious background 
It should reflect the options chosen in the application
- Newly Convert
- Born Muslim - Beginner
- Born Muslim - Intermediate
- Born Muslim - Advanced
- Islamic Scholar
Country Chosen should reflect the prayer time for the particular country || Area Code?


### Qibla Screen ###
Geeolocator Dart is used to get the current location and position of the user / LocationAccuracy High
Flutter compass package is called as a CompassEvent

### PrayerTimeProvider ###
Gelocator Package 
Using location services to pinpoint current user location
Timezone Package
Gets the currentTimeZone from the device
#### MuslimWorldLeague ####
Follows Madhab Shafi

### PrayerTimesScreen ###
Testing Button with Fixed Location of Mecca 21.4225, 39.8262 (long, lat)
Shows the remaining time for each current prayer time left in the header

### QuranVersesScreen ###
Default surah using Al-Fatihah
Al-Quran Cloud API is used
- 'https://api.alquran.cloud/v1/surah/$surahNumber/editions/quran-uthmani,en.asad,ar.alafasy'
API returns multiple editions in an array
- Arabic Text (Uthmani)
- English Translation
- Audio URLs
The data received using the API is their 
- number 
- number in surah
- arabic text
- english translation
- audio Url
- surah name
- surah name in arabic
#### Alternative Audio ####
EveryAyah.com
- https://audio.tanzil.net/Alafasy/$surahNum$ayahNum.mp3
Simple Mapping for the first few surahsd

GoRoute ?