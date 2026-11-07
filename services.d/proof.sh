#!/bin/sh
# proof: http://exe-host/ on the tailnet -> 127.0.0.1:8080
tailscale serve --bg --http=80 http://127.0.0.1:8080
