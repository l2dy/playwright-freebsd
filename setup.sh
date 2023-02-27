#!/usr/bin/env bash
set -e

# Environment setup for .github/workflows/publish_release_driver.yml

pkg install bash zip git npm-node16

PLAYWRIGHT_BRANCH=1.31

# run following as a normal user reserved for building playwright
#
# node prefix set-up
WORKDIR="$HOME/work"
mkdir -p "$WORKDIR"
cd "$WORKDIR"
NODE_PREFIX="$WORKDIR/nodeenv"
npm config set prefix "$NODE_PREFIX"
npm i -g npm@8
ln -s /usr/local/bin/bash "$NODE_PREFIX/bin/sh"
export PATH="$NODE_PREFIX/bin:$PATH"
sh --version # fail-safe

# build playwright driver
git clone -b release-$PLAYWRIGHT_BRANCH --depth 1 https://github.com/microsoft/playwright.git
pushd playwright

git apply <<'EOF'
diff --git a/packages/playwright-core/src/server/registry/index.ts b/packages/playwright-core/src/server/registry/index.ts
index 25c6394..04df982 100644
--- a/packages/playwright-core/src/server/registry/index.ts
+++ b/packages/playwright-core/src/server/registry/index.ts
@@ -53,6 +53,7 @@ if (process.env.PW_TEST_CDN_THAT_SHOULD_WORK) {
 const EXECUTABLE_PATHS = {
   'chromium': {
     'linux': ['chrome-linux', 'chrome'],
+    'freebsd': ['chromium'],
     'mac': ['chrome-mac', 'Chromium.app', 'Contents', 'MacOS', 'Chromium'],
     'win': ['chrome-win', 'chrome.exe'],
   },
@@ -236,7 +237,7 @@ export const registryDirectory = (() => {
     result = envDefined;
   } else {
     let cacheDirectory: string;
-    if (process.platform === 'linux')
+    if (process.platform === 'linux' || process.platform === 'freebsd')
       cacheDirectory = process.env.XDG_CACHE_HOME || path.join(os.homedir(), '.cache');
     else if (process.platform === 'darwin')
       cacheDirectory = path.join(os.homedir(), 'Library', 'Caches');
@@ -342,6 +343,8 @@ export class Registry {
       let tokens = undefined;
       if (process.platform === 'linux')
         tokens = EXECUTABLE_PATHS[name]['linux'];
+      else if (process.platform === 'freebsd')
+        tokens = EXECUTABLE_PATHS[name]['freebsd'];
       else if (process.platform === 'darwin')
         tokens = EXECUTABLE_PATHS[name]['mac'];
       else if (process.platform === 'win32')
diff --git a/utils/build/build-playwright-driver.sh b/utils/build/build-playwright-driver.sh
index 9fba7fc..7e99fa7 100755
--- a/utils/build/build-playwright-driver.sh
+++ b/utils/build/build-playwright-driver.sh
@@ -32,28 +32,10 @@ function build {
   mkdir -p ./output/playwright-${SUFFIX}
   tar -xzf ./output/playwright-core.tgz -C ./output/playwright-${SUFFIX}/

-  curl ${NODE_URL} -o ./output/${NODE_DIR}.${ARCHIVE}
-  NPM_PATH=""
-  if [[ "${ARCHIVE}" == "zip" ]]; then
-    cd ./output
-    unzip -q ./${NODE_DIR}.zip
-    cd ..
-    cp ./output/${NODE_DIR}/node.exe ./output/playwright-${SUFFIX}/
-    NPM_PATH="node_modules/npm/bin/npm-cli.js"
-  elif [[ "${ARCHIVE}" == "tar.gz" ]]; then
-    tar -xzf ./output/${NODE_DIR}.tar.gz -C ./output/
-    cp ./output/${NODE_DIR}/bin/node ./output/playwright-${SUFFIX}/
-    NPM_PATH="lib/node_modules/npm/bin/npm-cli.js"
-  else
-    echo "Unsupported ARCHIVE ${ARCHIVE}"
-    exit 1
-  fi
-
-  cp ./output/${NODE_DIR}/LICENSE ./output/playwright-${SUFFIX}/
   cp ./output/api.json ./output/playwright-${SUFFIX}/package/
   cp ./output/protocol.yml ./output/playwright-${SUFFIX}/package/
   cd ./output/playwright-${SUFFIX}/package
-  PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 node "../../${NODE_DIR}/${NPM_PATH}" install --production --ignore-scripts
+  PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install --production --ignore-scripts
   rm package-lock.json

   cd ..
@@ -77,8 +59,4 @@ function build {
   zip -q -r ../playwright-${PACKAGE_VERSION}-${SUFFIX}.zip .
 }

-build "node-v${NODE_VERSION}-darwin-x64" "mac" "tar.gz" "run-driver-posix.sh"
-build "node-v${NODE_VERSION}-darwin-arm64" "mac-arm64" "tar.gz" "run-driver-posix.sh"
-build "node-v${NODE_VERSION}-linux-x64" "linux" "tar.gz" "run-driver-posix.sh"
-build "node-v${NODE_VERSION}-linux-arm64" "linux-arm64" "tar.gz" "run-driver-posix.sh"
-build "node-v${NODE_VERSION}-win-x64" "win32_x64" "zip" "run-driver-win.cmd"
+build "node-v${NODE_VERSION}-freebsd-x64" "freebsd" "tar.gz" "run-driver-posix.sh"
EOF

npm uninstall electron electron-to-chromium # electron is not available on FreeBSD
npm run build
bash utils/build/build-playwright-driver.sh

popd
# END of playwright driver

# as target user
DESTDIR="$HOME/venv"
python3.9 -m venv "$DESTDIR"
source "$DESTDIR/bin/activate"

mkdir -p "$DESTDIR/sources"
cd "$DESTDIR/sources"
git clone https://github.com/microsoft/playwright-python.git
pushd playwright-python

git apply <<'EOF'
diff --git a/setup.py b/setup.py
index b3f15d5..096825a 100644
--- a/setup.py
+++ b/setup.py
@@ -77,6 +77,12 @@ class PlaywrightBDistWheelCommand(BDistWheelCommand):
         os.makedirs("driver", exist_ok=True)
         os.makedirs("playwright/driver", exist_ok=True)
         base_wheel_bundles: List[Dict[str, str]] = [
+            {
+                "wheel": "freebsd_13_0_amd64.whl",
+                "machine": "amd64",
+                "platform": "freebsd13",
+                "zip_name": "freebsd",
+            },
             {
                 "wheel": "macosx_10_13_x86_64.whl",
                 "machine": "x86_64",
EOF

PLAYWRIGHT_DRIVER_FILE="playwright-$(sed -n 's/"$//; s/driver_version = "//p' setup.py)-freebsd.zip"
install -d driver
cp -v "$WORKDIR/playwright/utils/build/output/playwright-$PLAYWRIGHT_BRANCH."?"-freebsd.zip" "driver/$PLAYWRIGHT_DRIVER_FILE"
pip install .

CR_REVISION=1048
install -d "$DESTDIR/chromium-$CR_REVISION"
ln -s /usr/local/bin/ungoogled-chromium "$DESTDIR/chromium-$CR_REVISION/chromium"

popd
