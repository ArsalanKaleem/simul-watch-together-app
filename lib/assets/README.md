# assets/

Put static assets here. The About screen expects a profile photo at:

    lib/assets/portfo-img.jpg

Add your image with that exact name (or edit `_photo` in
`lib/screens/about_screen.dart`). If the file is missing, the About screen
falls back to showing an initial — it won't crash.

Make sure your `pubspec.yaml` registers the folder:

    flutter:
      assets:
        - lib/assets/
