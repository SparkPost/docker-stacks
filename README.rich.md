Modifications for local tongfamily build
========================================

- Change the OWNER in the Makefile to tongfamily
- Changed Dockerfile to use BASE_ORGANIZATION instead of defaulting to Jupyter and
Makefile too
- Changed Makefile to add a tag for the git commit SHA with `git rev-parse HEAD`
  in the docker image
- Added a push all to put all the images on the disk up into the hub

