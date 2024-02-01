#!/bin/zsh -f

SCRIPT_PATH="${0:A:h}"
PANOPTO_FILE=${PANOPTO_FILE:-$HOME/.panopto}
PANOPTO_UPLOADER=$SCRIPT_PATH/panopto-uploader/upload.py

panopto_upload () {
    echo "Uploading $1..."
    rm -f err
    python -u $PANOPTO_UPLOADER \
             --server $panoptoserver --folder-id $folderid --client-id $clientid --client-secret $clientsecret \
             --upload-file $1 |&
        while read line; do
            case $line; in
                'Share ID: '*) shareid=${line/*: /};;
                *) ;;
            esac
            echo "$line" >> err
        done
   if (( pipestatus[1] )); then
     echo "Error while uploading $1, exiting."
     cat err
     exit 3
   fi
}

## PREREQS
declare -A reqs
reqs=(
  [ffmpeg]='.'
  [yt-dlp]='\(2023.12.30\|202[4-9].*\)'
  [auto-editor]='.'
)

for prog match in ${(kv)reqs}; do
  which $prog &> /dev/null || { echo "$prog: requirement not found."; exit 2 }
  if [[ $match != '.' ]]; then
    $prog --version |& grep -q $match || {
      echo "$prog: version requirement $match not matched."
      exit 2
    }
  fi
done

## Command line args
getfield () {
    sed -n "s/^$1=//p" $PANOPTO_FILE || { echo "cannot find field $1 in $PANOPTO_FILE"; exit 2 }
}

(( $# == 4 )) || { 
  cat <<EOF
usage: $0 NAME COOKIES URL FOLDERNAME
- NAME is the name of the video, e.g., "Week 4"; cannot contain /.
- COOKIES is the cookies.txt file obtained from Zoom.  For instance, use
    https://chromewebstore.google.com/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc
- URL is the Zoom URL
- FOLDERNAME is the name of the Panopto folder, the corresponding Panopto ID
    needs to appear in $PANOPTO_FILE.

The file $PANOPTO_FILE should contain at least:
    
EOF
  exit 2
}

name=$1
cookies=$2
url=$3
folderid=$(getfield $4)
clientid=$(getfield clientid)
clientsecret=$(getfield clientsecret)
panoptoserver=$(getfield server)

tmp=$(mktemp -d)
cd $tmp
echo "working directory: $tmp"

echo "TESTING PANOPTO UPLOAD"
( panopto_upload /dev/null &> err ) ## This will fail, since /dev/null is empty.
                                    ## Just checking that a proper attempt was made.
if ! grep -q 'Calling POST' err; then
  echo "ERROR, failed to upload to panopto"
  cat err
  exit 2
fi

echo "FETCHING ZOOM VIDEOS"
for f in share view; do
    yt-dlp -o $f.mp4 -f $f --cookies $cookies $url || exit 2
done

echo "MERGING SHARE/VIEW VIDEOS (hit q to stop midway)..."
ffmpeg -loglevel warning -i share.mp4 -i view.mp4 -filter_complex "
  color=size=2240x1080:c=black [background];
  [0:v] setpts=PTS-STARTPTS, scale=w=1920:h=-1 [slides];
  [1:v] setpts=PTS-STARTPTS, scale=w=320:h=-1 [speaker];
  [background][speaker] overlay=shortest=1:x=main_w-overlay_w:y=0 [background+speaker];
  [background+speaker][slides] overlay=shortest=1 [mix]
  " -map "[mix]" -map "1:a" merge.mp4 || exit 2

## Remove blanks
echo "STRIPPING SILENCES"
auto-editor --no-open merge.mp4 || exit 2

mv merge.mp4 "$name unedited.mp4"
mv merge_ALTERED.mp4 "$name.mp4"

## Upload in Panopto
echo "UPLOADING TO PANOPTO"

panopto_upload "$name.mp4"
s1=$shareid
panopto_upload "$name unedited.mp4"


mp4time () {
    secs=$(mp4info $1 | sed -n 's/^1.* \([0-9]*\)\.[0-9]* secs.*/\1/p')
    echo $((secs / 60))
}

echo "RESULT TABLE"

echo "| $name | | $s1 | $(mp4time "$name.mp4") | "
echo "| $name unedited | | $shareid | $(mp4time "$name unedited.mp4") | "

rm -fR $tmp
