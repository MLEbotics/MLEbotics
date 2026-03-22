// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void triggerDownload(String url, String filename) {
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..setAttribute('target', '_blank')
    ..click();
}

void openLink(String url) {
  html.window.open(url, '_blank');
}
