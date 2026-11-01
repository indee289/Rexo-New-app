import 'package:flutter/widgets.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Every Iconsax glyph the app uses, in one place.
///
/// Screens reference [AppIcons], never `Iconsax` directly, so swapping a glyph
/// or the icon pack itself is a one-file change.
class AppIcons {
  AppIcons._();

  // Navigation
  static const IconData home = Iconsax.home_2;
  static const IconData stock = Iconsax.box_1;
  static const IconData lowStock = Iconsax.warning_2;
  static const IconData reports = Iconsax.chart_2;
  static const IconData settings = Iconsax.setting_2;

  // Actions
  static const IconData add = Iconsax.add;
  static const IconData minus = Iconsax.minus;
  static const IconData addItem = Iconsax.box_add;
  static const IconData search = Iconsax.search_normal_1;
  static const IconData filter = Iconsax.filter;
  static const IconData sort = Iconsax.sort;
  static const IconData clear = Iconsax.close_circle;
  static const IconData edit = Iconsax.edit_2;
  static const IconData delete = Iconsax.trash;
  static const IconData undo = Iconsax.undo;
  static const IconData save = Iconsax.tick_circle;
  static const IconData more = Iconsax.more_circle;
  static const IconData back = Iconsax.arrow_left;
  static const IconData share = Iconsax.share;
  static const IconData open = Iconsax.link_2;

  // Content
  static const IconData category = Iconsax.category;
  static const IconData brand = Iconsax.tag;
  static const IconData model = Iconsax.hashtag;
  static const IconData shelf = Iconsax.location;
  static const IconData note = Iconsax.note_1;
  static const IconData photo = Iconsax.gallery;
  static const IconData camera = Iconsax.camera;
  static const IconData quantity = Iconsax.element_3;
  static const IconData shop = Iconsax.shop;
  static const IconData history = Iconsax.clock;
  static const IconData calendar = Iconsax.calendar_1;
  static const IconData language = Iconsax.language_square;
  static const IconData info = Iconsax.info_circle;
  static const IconData reminder = Iconsax.notification_bing;

  // Movement direction
  static const IconData stockIn = Iconsax.direct_inbox;
  static const IconData stockOut = Iconsax.direct_send;
  static const IconData trendUp = Iconsax.trend_up;
  static const IconData trendDown = Iconsax.trend_down;

  // Status
  static const IconData statusOk = Iconsax.box_tick;
  static const IconData statusLow = Iconsax.warning_2;
  static const IconData statusOut = Iconsax.box_remove;

  // Export and sync
  static const IconData pdf = Iconsax.document_text;
  static const IconData excel = Iconsax.document_download;
  static const IconData sync = Iconsax.refresh_2;
  static const IconData cloud = Iconsax.cloud_connection;
  static const IconData backup = Iconsax.save_2;
  static const IconData restore = Iconsax.folder_open;
  static const IconData connect = Iconsax.login;
  static const IconData disconnect = Iconsax.logout;

  /// Icon for a category, chosen by its stable [key].
  static IconData forCategory(String? key) {
    switch (key) {
      case 'cover':
        return Iconsax.mobile;
      case 'glass':
        return Iconsax.shield_tick;
      case 'charger':
        return Iconsax.electricity;
      case 'cable':
        return Iconsax.cpu_charge;
      case 'earphone':
        return Iconsax.headphone;
      case 'powerbank':
        return Iconsax.battery_charging;
      case 'memory':
        return Iconsax.card;
      default:
        return Iconsax.box_1;
    }
  }
}
