# CineNexa Own Player

CineNexa v2.2.0 includes an in-app native video player for video files/streams you own or are licensed to distribute.

## Supported playback source

Use an HTTPS direct media URL supported by Flutter `video_player`, such as MP4 or HLS (`.m3u8`). Do not use a normal YouTube watch URL as a direct media URL.

## Firestore collection

Create collection:

`media_sources`

Movie document ID:

`movie_<TMDB_MOVIE_ID>`

Example: `movie_550`

Fields:

- `url` (string, required): direct HTTPS MP4/HLS URL
- `title` (string, optional)
- `subtitle` (string, optional)
- `active` (boolean, recommended: true)
- `headers` (map<string,string>, optional): only when your CDN requires safe static request headers

TV series document ID:

`tv_<TMDB_SERIES_ID>`

Episode-ready convention (service included for the next UI step):

`tv_<SERIES_ID>_s<SEASON>_e<EPISODE>`

Example: `tv_1399_s1_e1`

## Firestore rules

The included rules allow authenticated users to read `media_sources`, while client writes are denied. Add/update playback URLs from Firebase Console or a trusted admin backend.

## Production recommendation

Store owned/licensed video files on a streaming-capable CDN/object store (for example Cloudflare R2 + CDN, your server/CDN, or another authorized host) and put only the playback URL in Firestore.

For large movies, prefer HLS for adaptive streaming instead of bundling video files inside the Flutter app.
