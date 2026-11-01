/// Hindi and English UI text.
///
/// Deliberately a plain class with named fields rather than generated ARB
/// lookups: a missing or misspelled string becomes a compile error instead of a
/// silent fallback at runtime. Keep every label short - the UI leans on icons
/// and numbers, not sentences.
class S {
  const S({
    required this.lang,
    required this.appName,
    required this.navHome,
    required this.navStock,
    required this.navLow,
    required this.navReports,
    required this.settings,
    required this.items,
    required this.totalQty,
    required this.low,
    required this.out,
    required this.today,
    required this.inLabel,
    required this.outLabel,
    required this.addItem,
    required this.seeAll,
    required this.noItems,
    required this.search,
    required this.all,
    required this.clear,
    required this.sortName,
    required this.sortQty,
    required this.sortRecent,
    required this.category,
    required this.brand,
    required this.model,
    required this.noResults,
    required this.name,
    required this.qty,
    required this.minQty,
    required this.shelf,
    required this.note,
    required this.photo,
    required this.save,
    required this.newCategory,
    required this.nameRequired,
    required this.duplicate,
    required this.open,
    required this.camera,
    required this.gallery,
    required this.remove,
    required this.edit,
    required this.delete,
    required this.deleteConfirm,
    required this.cancel,
    required this.yes,
    required this.stockIn,
    required this.stockOut,
    required this.history,
    required this.noHistory,
    required this.undo,
    required this.undoConfirm,
    required this.notEnough,
    required this.saved,
    required this.reason,
    required this.rOpening,
    required this.rPurchase,
    required this.rSale,
    required this.rReturn,
    required this.rDamage,
    required this.rCorrection,
    required this.stAvailable,
    required this.stLow,
    required this.stOut,
    required this.pdf,
    required this.excel,
    required this.week,
    required this.month,
    required this.custom,
    required this.dayWise,
    required this.monthWise,
    required this.making,
    required this.shopName,
    required this.language,
    required this.defaultMin,
    required this.reminder,
    required this.time,
    required this.sheetSync,
    required this.connect,
    required this.disconnect,
    required this.syncNow,
    required this.openSheet,
    required this.backup,
    required this.restore,
    required this.restoreConfirm,
    required this.about,
    required this.version,
    required this.qtyOnly,
    required this.synced,
    required this.pending,
    required this.syncError,
    required this.retry,
    required this.syncOffline,
    required this.syncNote,
    required this.signInFailed,
    required this.sheetMissing,
    required this.createNew,
    required this.googleBusy,
    required this.tokenExpired,
    required this.ok,
    required this.error,
    required this.allGood,
    required this.done,
    required this.justNow,
    required this.minAgo,
    required this.hourAgo,
    required this.never,
    required this.setupNeeded,
    required this.fixCounts,
  });

  final String lang;
  final String appName;
  final String navHome;
  final String navStock;
  final String navLow;
  final String navReports;
  final String settings;
  final String items;
  final String totalQty;
  final String low;
  final String out;
  final String today;
  final String inLabel;
  final String outLabel;
  final String addItem;
  final String seeAll;
  final String noItems;
  final String search;
  final String all;
  final String clear;
  final String sortName;
  final String sortQty;
  final String sortRecent;
  final String category;
  final String brand;
  final String model;
  final String noResults;
  final String name;
  final String qty;
  final String minQty;
  final String shelf;
  final String note;
  final String photo;
  final String save;
  final String newCategory;
  final String nameRequired;
  final String duplicate;
  final String open;
  final String camera;
  final String gallery;
  final String remove;
  final String edit;
  final String delete;
  final String deleteConfirm;
  final String cancel;
  final String yes;
  final String stockIn;
  final String stockOut;
  final String history;
  final String noHistory;
  final String undo;
  final String undoConfirm;
  final String notEnough;
  final String saved;
  final String reason;
  final String rOpening;
  final String rPurchase;
  final String rSale;
  final String rReturn;
  final String rDamage;
  final String rCorrection;
  final String stAvailable;
  final String stLow;
  final String stOut;
  final String pdf;
  final String excel;
  final String week;
  final String month;
  final String custom;
  final String dayWise;
  final String monthWise;
  final String making;
  final String shopName;
  final String language;
  final String defaultMin;
  final String reminder;
  final String time;
  final String sheetSync;
  final String connect;
  final String disconnect;
  final String syncNow;
  final String openSheet;
  final String backup;
  final String restore;
  final String restoreConfirm;
  final String about;
  final String version;
  final String qtyOnly;
  final String synced;
  final String pending;
  final String syncError;
  final String retry;
  final String syncOffline;
  final String syncNote;
  final String signInFailed;
  final String sheetMissing;
  final String createNew;
  final String googleBusy;
  final String tokenExpired;
  final String ok;
  final String error;
  final String allGood;
  final String done;
  final String justNow;
  final String minAgo;
  final String hourAgo;
  final String never;
  final String setupNeeded;
  final String fixCounts;

  static const S hi = S(
    lang: 'hi',
    appName: 'StockSaathi',
    navHome: 'होम',
    navStock: 'स्टॉक',
    navLow: 'कम',
    navReports: 'रिपोर्ट',
    settings: 'सेटिंग',
    items: 'आइटम',
    totalQty: 'कुल',
    low: 'कम',
    out: 'खत्म',
    today: 'आज',
    inLabel: 'आया',
    outLabel: 'गया',
    addItem: 'आइटम जोड़ें',
    seeAll: 'सब देखें',
    noItems: 'कोई आइटम नहीं',
    search: 'खोजें',
    all: 'सब',
    clear: 'हटाएं',
    sortName: 'नाम',
    sortQty: 'मात्रा',
    sortRecent: 'नया',
    category: 'कैटेगरी',
    brand: 'ब्रांड',
    model: 'मॉडल',
    noResults: 'कुछ नहीं मिला',
    name: 'नाम',
    qty: 'मात्रा',
    minQty: 'कम से कम',
    shelf: 'जगह',
    note: 'नोट',
    photo: 'फोटो',
    save: 'सेव',
    newCategory: 'नई कैटेगरी',
    nameRequired: 'नाम डालें',
    duplicate: 'ये आइटम पहले से है',
    open: 'खोलें',
    camera: 'कैमरा',
    gallery: 'गैलरी',
    remove: 'हटाएं',
    edit: 'बदलें',
    delete: 'मिटाएं',
    deleteConfirm: 'मिटाना है?',
    cancel: 'रद्द',
    yes: 'हां',
    stockIn: 'आया',
    stockOut: 'गया',
    history: 'हिस्ट्री',
    noHistory: 'कोई रिकॉर्ड नहीं',
    undo: 'वापस',
    undoConfirm: 'वापस करना है?',
    notEnough: 'इतना स्टॉक नहीं',
    saved: 'सेव हो गया',
    reason: 'वजह',
    rOpening: 'शुरुआती',
    rPurchase: 'नया माल',
    rSale: 'बेचा',
    rReturn: 'वापस आया',
    rDamage: 'खराब',
    rCorrection: 'सुधार',
    stAvailable: 'ठीक',
    stLow: 'कम',
    stOut: 'खत्म',
    pdf: 'PDF',
    excel: 'Excel',
    week: 'हफ्ता',
    month: 'महीना',
    custom: 'चुनें',
    dayWise: 'दिन',
    monthWise: 'महीना',
    making: 'बन रहा है',
    shopName: 'दुकान का नाम',
    language: 'भाषा',
    defaultMin: 'डिफ़ॉल्ट कम से कम',
    reminder: 'रोज़ याद दिलाएं',
    time: 'समय',
    sheetSync: 'Google Sheet',
    connect: 'जोड़ें',
    disconnect: 'हटाएं',
    syncNow: 'अभी भेजें',
    openSheet: 'Sheet खोलें',
    backup: 'बैकअप',
    restore: 'वापस लाएं',
    restoreConfirm: 'सारा डेटा बदल जाएगा',
    about: 'ऐप',
    version: 'वर्ज़न',
    qtyOnly: 'सिर्फ़ मात्रा, और कुछ नहीं',
    synced: 'भेज दिया',
    pending: 'बाकी',
    syncError: 'दिक्कत',
    retry: 'फिर कोशिश',
    syncOffline: 'नेट नहीं',
    syncNote: 'Sheet में किया बदलाव ऐप में नहीं आएगा',
    signInFailed: 'लॉगिन नहीं हुआ',
    sheetMissing: 'Sheet नहीं मिली',
    createNew: 'नई बनाएं',
    googleBusy: 'बाद में कोशिश होगी',
    tokenExpired: 'दोबारा जोड़ें',
    ok: 'ठीक',
    error: 'दिक्कत',
    allGood: 'सब ठीक है',
    done: 'हो गया',
    justNow: 'अभी',
    minAgo: 'मिनट पहले',
    hourAgo: 'घंटे पहले',
    never: 'कभी नहीं',
    setupNeeded: 'Google सेटअप बाकी है',
    fixCounts: 'गिनती ठीक करें',
  );

  static const S en = S(
    lang: 'en',
    appName: 'StockSaathi',
    navHome: 'Home',
    navStock: 'Stock',
    navLow: 'Low',
    navReports: 'Reports',
    settings: 'Settings',
    items: 'Items',
    totalQty: 'Total',
    low: 'Low',
    out: 'Out',
    today: 'Today',
    inLabel: 'In',
    outLabel: 'Out',
    addItem: 'Add item',
    seeAll: 'See all',
    noItems: 'No items',
    search: 'Search',
    all: 'All',
    clear: 'Clear',
    sortName: 'Name',
    sortQty: 'Qty',
    sortRecent: 'Recent',
    category: 'Category',
    brand: 'Brand',
    model: 'Model',
    noResults: 'Nothing found',
    name: 'Name',
    qty: 'Qty',
    minQty: 'Minimum',
    shelf: 'Shelf',
    note: 'Note',
    photo: 'Photo',
    save: 'Save',
    newCategory: 'New category',
    nameRequired: 'Enter a name',
    duplicate: 'This item already exists',
    open: 'Open',
    camera: 'Camera',
    gallery: 'Gallery',
    remove: 'Remove',
    edit: 'Edit',
    delete: 'Delete',
    deleteConfirm: 'Delete this?',
    cancel: 'Cancel',
    yes: 'Yes',
    stockIn: 'In',
    stockOut: 'Out',
    history: 'History',
    noHistory: 'No records',
    undo: 'Undo',
    undoConfirm: 'Undo this?',
    notEnough: 'Not enough stock',
    saved: 'Saved',
    reason: 'Reason',
    rOpening: 'Opening',
    rPurchase: 'New stock',
    rSale: 'Sold',
    rReturn: 'Returned',
    rDamage: 'Damaged',
    rCorrection: 'Correction',
    stAvailable: 'OK',
    stLow: 'Low',
    stOut: 'Out',
    pdf: 'PDF',
    excel: 'Excel',
    week: 'Week',
    month: 'Month',
    custom: 'Pick',
    dayWise: 'Daily',
    monthWise: 'Monthly',
    making: 'Creating',
    shopName: 'Shop name',
    language: 'Language',
    defaultMin: 'Default minimum',
    reminder: 'Daily reminder',
    time: 'Time',
    sheetSync: 'Google Sheet',
    connect: 'Connect',
    disconnect: 'Disconnect',
    syncNow: 'Sync now',
    openSheet: 'Open Sheet',
    backup: 'Backup',
    restore: 'Restore',
    restoreConfirm: 'All data will be replaced',
    about: 'App',
    version: 'Version',
    qtyOnly: 'Quantity only, nothing else',
    synced: 'Synced',
    pending: 'Pending',
    syncError: 'Error',
    retry: 'Retry',
    syncOffline: 'No net',
    syncNote: 'Edits made in the Sheet do not come back',
    signInFailed: 'Sign-in failed',
    sheetMissing: 'Sheet not found',
    createNew: 'Create new',
    googleBusy: 'Will retry later',
    tokenExpired: 'Reconnect',
    ok: 'OK',
    error: 'Error',
    allGood: 'All good',
    done: 'Done',
    justNow: 'just now',
    minAgo: 'min ago',
    hourAgo: 'h ago',
    never: 'never',
    setupNeeded: 'Google setup pending',
    fixCounts: 'Fix counts',
  );

  static S forCode(String code) => code == 'en' ? en : hi;
}
