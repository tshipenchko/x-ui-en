COMMIT_HASH="5d8689116288827eb322a16359fb3d8944a7f37d"

set -e

mkdir -p patch
cp diff.patch patch
cd patch

git clone https://github.com/vaxilu/x-ui
cd x-ui
git checkout $COMMIT_HASH
cd ..
patch -s -p0 < diff.patch

