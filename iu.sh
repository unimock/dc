#!/bin/bash
./addapps .getver
./addapps refresh
git add .
git commit -m "image-update"
git push


