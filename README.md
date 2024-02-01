# Ad-hoc Zoom to Panopto Script

## Summary

This shell script:
- Fetches the camera and screen streams of a Zoom recording using
  [yt-dlp](https://github.com/yt-dlp/yt-dlp),
- Merges the two videos using [ffmpeg](https://ffmpeg.org/),
- Removes silences using [auto-editor](https://github.com/WyattBlue/auto-editor),
- Uploads the unedited video and the video with silences removed to Panopto using [their Python examples ](https://github.com/Panopto/upload-python-sample).

## Prerequisites

- Python packages:
  ```
  pip install requests oauthlib requests_oauthlib
  pip install boto3
  ```
- A recent version of [yt-dlp](https://github.com/yt-dlp/yt-dlp).  I use version
  2023-12-30.  Previous versions have trouble listing all the Zoom streams and
  will fail.
- [ffmpeg](https://ffmpeg.org/).
- [auto-editor](https://github.com/WyattBlue/auto-editor).
  
## Panopto Credentials
1. Sign in to Panopto web site
2. Click your name in right-upper corner, and clikc "User Settings"
3. Select "API Clients" tab
4. Click "Create new API Client" button
5. Enter arbitrary Client Name
6. Select Server-side Web Application type.
7. Enter ```https://localhost``` into CORS Origin URL.
8. Enter ```http://localhost:9127/redirect``` into Redirect URL.
9. The rest can be blank. Click "Create API Client" button.
10. Note the created Client ID and Client Secret.

## Panopto Configuration File

You should have, in `~/.panopto` (or set the environment variable
`PANOPTO_FILE`), the following fields populated:

```
server=<Panopto server, e.g., depaul.hosted.panopto.com>
clientid=<your client ID>
clientsecret=<your client secret>
<folder1>=<folder1 ID>
<folder2>=<folder2 ID>
```

In there, `<folderN>` is an arbitrary name you give to a folder.  It does not
correlate with the actual name of the folder.  It is mapped to a corresponding
_Panopto folder ID_ which can be found by navigating to the Panopto folder on a
web browser and inspecting the URL.

## How to run

1. Gather your client ID, client secret, folder IDs from Panopto
2. Log in to Zoom and retrieve your cookies for Zoom; this can be done using any
   number of plugins, for instance, [this one on Chrome](https://chromewebstore.google.com/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc).
3. Obtain the shareable URL of your recording.  This is the URL that is sent by
   email when the recording is available.  It starts with
   `https://depaul.zoom.us/rec/share/`.
4. Run:
   ```./zoom2panopto.sh "Name of Video" "path/to/cookies.txt" "Zoom URL" "folder name as in ~/.panopto"```
