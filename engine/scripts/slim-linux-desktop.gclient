# Copy this file to the root of your flutter checkout to bootstrap gclient
# or just run gclient sync in an empty directory with this file.
solutions = [
  {
    "custom_deps": {},
    "deps_file": "DEPS",
    "managed": False,
    "name": ".",
    "safesync_url": "",

    # If you are using SSH to connect to GitHub, change the URL to:
    # git@github.com:flutter/flutter.git
    "url": "https://github.com/flutter/flutter.git",


    "custom_vars": {
        "download_linux_deps": True,
        "download_android_deps": False,
        "download_esbuild": False,
        "download_fuchsia_deps": False,
    }
  },
]