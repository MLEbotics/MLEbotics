import 'package:url_launcher/url_launcher.dart';

void triggerDownload(String url, String filename) {
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

void openLink(String url) {
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
