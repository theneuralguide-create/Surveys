#!/bin/bash
# Double-click this file to run the Survey Hub on your computer.
# Keep the terminal window it opens in the background while you use the site;
# closing that window stops the site (your data is safe — it lives in the browser).
cd "$(dirname "$0")"
PORT=8765
if ! lsof -i :"$PORT" >/dev/null 2>&1; then
  python3 -m http.server "$PORT" >/dev/null 2>&1 &
  sleep 1
fi
open "http://localhost:$PORT/"
echo "Survey Hub is running at http://localhost:$PORT/"
echo "Keep this window open while you use the site. Press Ctrl+C or close the window to stop."
wait
