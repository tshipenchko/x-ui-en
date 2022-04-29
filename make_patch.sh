COMMIT_HASH="5d8689116288827eb322a16359fb3d8944a7f37d"

set -e

git clone https://github.com/vaxilu/x-ui
cd x-ui
git checkout $COMMIT_HASH
cd ..
diff -ruN x-ui/ x-ui-diff/ -x .git -x bin > diff.patch
