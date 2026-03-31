// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class L10nId extends L10n {
  L10nId([String locale = 'id']) : super(locale);

  @override
  String get networkErrorDnsFailureUser =>
      'Cannot connect to server.\n• Check your internet connection\n• Disable VPN/DNS if active\n• Try again in a moment';

  @override
  String get networkErrorConnectionUser =>
      'Connection lost.\n• Check your internet connection\n• Ensure WiFi/data is active\n• Try again in a moment';

  @override
  String get networkErrorTimeoutUser =>
      'Connection timeout.\n• Check your internet speed\n• Try again in a moment\n• Contact admin if problem persists';

  @override
  String get networkErrorReceiveTimeoutUser =>
      'Server took too long to respond.\n• Your internet connection might be slow\n• Try again in a moment\n• Contact admin if problem persists';

  @override
  String get networkErrorServerUser =>
      'Server error occurred.\n• Try again in a moment\n• Contact admin if problem persists';

  @override
  String get networkErrorServer502User =>
      'Server unreachable.\n• Server might be under maintenance\n• Try again in a moment\n• Contact admin if problem persists';

  @override
  String get networkErrorServer503User =>
      'Service under maintenance.\n• Wait a moment\n• Try again later\n• Contact admin for more info';

  @override
  String get networkErrorServer504User =>
      'Server timeout.\n• Server is busy\n• Try again in a moment\n• Contact admin if problem persists';

  @override
  String get networkErrorHtmlResponse =>
      'Server returned HTML instead of JSON. Check API endpoint configuration.';

  @override
  String get networkErrorFileDownloaded => 'File downloaded successfully';

  @override
  String get networkErrorUnknown => 'Unknown error occurred';

  @override
  String get timeAgoJustNow => 'just now';

  @override
  String timeAgoMinute(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String timeAgoHour(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String timeAgoDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String timeAgoMonth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months ago',
      one: '1 month ago',
    );
    return '$_temp0';
  }

  @override
  String timeAgoYear(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years ago',
      one: '1 year ago',
    );
    return '$_temp0';
  }

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'Feb';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Apr';

  @override
  String get monthMay => 'May';

  @override
  String get monthJun => 'Jun';

  @override
  String get monthJul => 'Jul';

  @override
  String get monthAug => 'Aug';

  @override
  String get monthSep => 'Sep';

  @override
  String get monthOct => 'Oct';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'Dec';

  @override
  String get dayMon => 'Monday';

  @override
  String get dayTue => 'Tuesday';

  @override
  String get dayWed => 'Wednesday';

  @override
  String get dayThu => 'Thursday';

  @override
  String get dayFri => 'Friday';

  @override
  String get daySat => 'Saturday';

  @override
  String get daySun => 'Sunday';

  @override
  String get currencyBillionSuffix => 'B';

  @override
  String get currencyMillionSuffix => 'M';

  @override
  String get currencyThousandSuffix => 'K';

  @override
  String get enumSortOrderAsc => 'Ascending';

  @override
  String get enumSortOrderDesc => 'Descending';

  @override
  String get enumCategorySortByCategoryCode => 'Category Code';

  @override
  String get enumCategorySortByName => 'Name';

  @override
  String get enumCategorySortByCategoryName => 'Category Name';

  @override
  String get enumCategorySortByCreatedAt => 'Created Date';

  @override
  String get enumCategorySortByUpdatedAt => 'Updated Date';

  @override
  String get enumLocationSortByLocationCode => 'Location Code';

  @override
  String get enumLocationSortByName => 'Name';

  @override
  String get enumLocationSortByLocationName => 'Location Name';

  @override
  String get enumLocationSortByBuilding => 'Building';

  @override
  String get enumLocationSortByFloor => 'Floor';

  @override
  String get enumLocationSortByCreatedAt => 'Created Date';

  @override
  String get enumLocationSortByUpdatedAt => 'Updated Date';

  @override
  String get enumNotificationSortByType => 'Type';

  @override
  String get enumNotificationSortByIsRead => 'Read Status';

  @override
  String get enumNotificationSortByCreatedAt => 'Received Date';

  @override
  String get enumNotificationSortByTitle => 'Title';

  @override
  String get enumNotificationSortByMessage => 'Message';

  @override
  String get enumScanLogSortByScanTimestamp => 'Scan Time';

  @override
  String get enumScanLogSortByScannedValue => 'Scanned Value';

  @override
  String get enumScanLogSortByScanMethod => 'Scan Method';

  @override
  String get enumScanLogSortByScanResult => 'Scan Result';

  @override
  String get enumAssetSortByAssetTag => 'Asset Tag';

  @override
  String get enumAssetSortByAssetName => 'Asset Name';

  @override
  String get enumAssetSortByBrand => 'Brand';

  @override
  String get enumAssetSortByModel => 'Model';

  @override
  String get enumAssetSortBySerialNumber => 'Serial Number';

  @override
  String get enumAssetSortByPurchaseDate => 'Purchase Date';

  @override
  String get enumAssetSortByPurchasePrice => 'Purchase Price';

  @override
  String get enumAssetSortByVendorName => 'Vendor Name';

  @override
  String get enumAssetSortByWarrantyEnd => 'Warranty End Date';

  @override
  String get enumAssetSortByStatus => 'Status';

  @override
  String get enumAssetSortByConditionStatus => 'Condition';

  @override
  String get enumAssetSortByCreatedAt => 'Created Date';

  @override
  String get enumAssetSortByUpdatedAt => 'Updated Date';

  @override
  String get enumAssetMovementSortByMovementDate => 'Movement Date';

  @override
  String get enumAssetMovementSortByMovementdate => 'Movement Date';

  @override
  String get enumAssetMovementSortByCreatedAt => 'Created Date';

  @override
  String get enumAssetMovementSortByCreatedat => 'Created Date';

  @override
  String get enumAssetMovementSortByUpdatedAt => 'Updated Date';

  @override
  String get enumAssetMovementSortByUpdatedat => 'Updated Date';

  @override
  String get enumIssueReportSortByReportedDate => 'Reported Date';

  @override
  String get enumIssueReportSortByResolvedDate => 'Resolved Date';

  @override
  String get enumIssueReportSortByIssueType => 'Issue Type';

  @override
  String get enumIssueReportSortByPriority => 'Priority';

  @override
  String get enumIssueReportSortByStatus => 'Status';

  @override
  String get enumIssueReportSortByTitle => 'Title';

  @override
  String get enumIssueReportSortByDescription => 'Description';

  @override
  String get enumIssueReportSortByCreatedAt => 'Created Date';

  @override
  String get enumIssueReportSortByUpdatedAt => 'Updated Date';

  @override
  String get enumMaintenanceScheduleSortByNextScheduledDate =>
      'Next Scheduled Date';

  @override
  String get enumMaintenanceScheduleSortByMaintenanceType => 'Maintenance Type';

  @override
  String get enumMaintenanceScheduleSortByState => 'State';

  @override
  String get enumMaintenanceScheduleSortByCreatedAt => 'Created Date';

  @override
  String get enumMaintenanceScheduleSortByUpdatedAt => 'Updated Date';

  @override
  String get enumMaintenanceRecordSortByMaintenanceDate => 'Maintenance Date';

  @override
  String get enumMaintenanceRecordSortByActualCost => 'Actual Cost';

  @override
  String get enumMaintenanceRecordSortByTitle => 'Title';

  @override
  String get enumMaintenanceRecordSortByCreatedAt => 'Created Date';

  @override
  String get enumMaintenanceRecordSortByUpdatedAt => 'Updated Date';

  @override
  String get enumUserSortByName => 'Name';

  @override
  String get enumUserSortByFullName => 'Full Name';

  @override
  String get enumUserSortByEmail => 'Email';

  @override
  String get enumUserSortByRole => 'Role';

  @override
  String get enumUserSortByEmployeeId => 'Employee ID';

  @override
  String get enumUserSortByIsActive => 'Active Status';

  @override
  String get enumUserSortByCreatedAt => 'Joined Date';

  @override
  String get enumUserSortByUpdatedAt => 'Updated Date';

  @override
  String get enumExportFormatPdf => 'PDF';

  @override
  String get enumExportFormatExcel => 'Excel';

  @override
  String get enumMutationTypeCreate => 'Create';

  @override
  String get enumMutationTypeUpdate => 'Update';

  @override
  String get enumMutationTypeDelete => 'Delete';

  @override
  String get enumLanguageEnglish => 'English';

  @override
  String get enumLanguageJapanese => 'Japanese';

  @override
  String get enumLanguageIndonesian => 'Indonesian';

  @override
  String get enumUserRoleAdmin => 'Admin';

  @override
  String get enumUserRoleUser => 'User';

  @override
  String get enumAssetStatusActive => 'Active';

  @override
  String get enumAssetStatusMaintenance => 'Maintenance';

  @override
  String get enumAssetStatusDisposed => 'Disposed';

  @override
  String get enumAssetStatusLost => 'Lost';

  @override
  String get enumAssetConditionGood => 'Good';

  @override
  String get enumAssetConditionFair => 'Fair';

  @override
  String get enumAssetConditionPoor => 'Poor';

  @override
  String get enumAssetConditionDamaged => 'Damaged';

  @override
  String get enumNotificationTypeMaintenance => 'Maintenance';

  @override
  String get enumNotificationTypeWarranty => 'Warranty';

  @override
  String get enumNotificationTypeIssue => 'Issue';

  @override
  String get enumNotificationTypeMovement => 'Movement';

  @override
  String get enumNotificationTypeStatusChange => 'Status Change';

  @override
  String get enumNotificationTypeLocationChange => 'Location Change';

  @override
  String get enumNotificationTypeCategoryChange => 'Category Change';

  @override
  String get enumNotificationPriorityLow => 'Low';

  @override
  String get enumNotificationPriorityNormal => 'Normal';

  @override
  String get enumNotificationPriorityHigh => 'High';

  @override
  String get enumNotificationPriorityUrgent => 'Urgent';

  @override
  String get enumScanMethodTypeDataMatrix => 'Data Matrix';

  @override
  String get enumScanMethodTypeManualInput => 'Manual Input';

  @override
  String get enumScanResultTypeSuccess => 'Success';

  @override
  String get enumScanResultTypeInvalidID => 'Invalid ID';

  @override
  String get enumScanResultTypeAssetNotFound => 'Asset Not Found';

  @override
  String get enumMaintenanceScheduleTypePreventive => 'Preventive';

  @override
  String get enumMaintenanceScheduleTypeCorrective => 'Corrective';

  @override
  String get enumMaintenanceScheduleTypeInspection => 'Inspection';

  @override
  String get enumMaintenanceScheduleTypeCalibration => 'Calibration';

  @override
  String get enumScheduleStateActive => 'Active';

  @override
  String get enumScheduleStatePaused => 'Paused';

  @override
  String get enumScheduleStateStopped => 'Stopped';

  @override
  String get enumScheduleStateCompleted => 'Completed';

  @override
  String get enumIntervalUnitDays => 'Days';

  @override
  String get enumIntervalUnitWeeks => 'Weeks';

  @override
  String get enumIntervalUnitMonths => 'Months';

  @override
  String get enumIntervalUnitYears => 'Years';

  @override
  String get enumIssuePriorityLow => 'Low';

  @override
  String get enumIssuePriorityMedium => 'Medium';

  @override
  String get enumIssuePriorityHigh => 'High';

  @override
  String get enumIssuePriorityCritical => 'Critical';

  @override
  String get enumIssueStatusOpen => 'Open';

  @override
  String get enumIssueStatusInProgress => 'In Progress';

  @override
  String get enumIssueStatusResolved => 'Resolved';

  @override
  String get enumIssueStatusClosed => 'Closed';

  @override
  String get enumMaintenanceResultSuccess => 'Success';

  @override
  String get enumMaintenanceResultPartial => 'Partial';

  @override
  String get enumMaintenanceResultFailed => 'Failed';

  @override
  String get enumMaintenanceResultRescheduled => 'Rescheduled';

  @override
  String get foldersTitle => 'Folder';

  @override
  String get foldersAllNotes => 'Semua Catatan';

  @override
  String get foldersUncategorized => 'Tidak Berkategori';

  @override
  String get foldersEmpty => 'Tidak ada folder khusus';

  @override
  String foldersError(String error) {
    return 'Kesalahan: $error';
  }

  @override
  String get foldersCreateNew => 'Buat Folder Baru';

  @override
  String get foldersNewTitle => 'Folder Baru';

  @override
  String get foldersCancel => 'Batal';

  @override
  String get foldersCreateBtn => 'Buat';

  @override
  String get notesHidden => 'Tersembunyi';

  @override
  String notesError(String error) {
    return 'Kesalahan: $error';
  }

  @override
  String notesSelectedCount(int count) {
    return '$count dipilih';
  }

  @override
  String get notesHiddenTitle => 'Catatan Tersembunyi';

  @override
  String get notesNotFound => 'Catatan tidak ditemukan.';

  @override
  String get notesGraphTitle => 'Tampilan Grafik';

  @override
  String get notesGraphEmpty => 'Tidak ada catatan untuk grafik.';

  @override
  String get notesMyTitle => 'Catatan Saya';

  @override
  String get notesNew => 'Catatan Baru';

  @override
  String get notesEdit => 'Edit Catatan';

  @override
  String get notesNoContent => 'Tidak ada konten';

  @override
  String notesTags(String tags) {
    return 'Tag: $tags';
  }

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get settingsMaterialYou => 'Gunakan Material You';

  @override
  String get settingsMaterialYouSubtitle => 'Ikuti warna dinamis sistem';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeSystem => 'Sistem';

  @override
  String get settingsThemeLight => 'Terang';

  @override
  String get settingsThemeDark => 'Gelap';

  @override
  String get settingsLanguage => 'Bahasa';

  @override
  String get settingsLanguageEnglish => 'Inggris';

  @override
  String get settingsLanguageJapanese => 'Jepang';

  @override
  String get settingsLanguageIndonesian => 'Indonesia';

  @override
  String get tasksTitle => 'Tugas';

  @override
  String get tasksEmpty => 'Tidak ada Tugas. Buat satu!';

  @override
  String get tasksActive => 'Aktif';

  @override
  String get tasksCompleted => 'Selesai';

  @override
  String get tasksNothingHere => 'Tidak ada apa-apa di sini...';

  @override
  String get tasksNew => 'Tugas Baru';

  @override
  String get tasksEdit => 'Edit Tugas';

  @override
  String get tasksTitleLabel => 'Judul Tugas';

  @override
  String get tasksDueDate => 'Batas Waktu';

  @override
  String get tasksSave => 'Simpan Tugas';

  @override
  String tasksError(String error) {
    return 'Kesalahan: $error';
  }

  @override
  String get adminShellBottomNavDashboard => 'Dasbor';

  @override
  String get adminShellBottomNavScanAsset => 'Pindai Aset';

  @override
  String get adminShellBottomNavProfile => 'Profil';

  @override
  String get userShellBottomNavHome => 'Beranda';

  @override
  String get userShellBottomNavScanAsset => 'Pindai Aset';

  @override
  String get userShellBottomNavProfile => 'Profil';

  @override
  String get appEndDrawerTitle => 'Aplikasi Saya';

  @override
  String get appEndDrawerPleaseLoginFirst => 'Silakan masuk terlebih dahulu';

  @override
  String get appEndDrawerTheme => 'Tema';

  @override
  String get appEndDrawerLanguage => 'Bahasa';

  @override
  String get appEndDrawerLogout => 'Keluar';

  @override
  String get appEndDrawerManagementSection => 'Manajemen';

  @override
  String get appEndDrawerMaintenanceSection => 'Pemeliharaan';

  @override
  String get appEndDrawerEnglish => 'English';

  @override
  String get appEndDrawerIndonesian => 'Indonesia';

  @override
  String get appEndDrawerJapanese => '日本語';

  @override
  String get appEndDrawerMyAssets => 'Aset Saya';

  @override
  String get appEndDrawerNotifications => 'Notifikasi';

  @override
  String get appEndDrawerMyIssueReports => 'Laporan Masalah Saya';

  @override
  String get appEndDrawerAssets => 'Aset';

  @override
  String get appEndDrawerAssetMovements => 'Pergerakan Aset';

  @override
  String get appEndDrawerCategories => 'Kategori';

  @override
  String get appEndDrawerLocations => 'Lokasi';

  @override
  String get appEndDrawerUsers => 'Pengguna';

  @override
  String get appEndDrawerMaintenanceSchedules => 'Jadwal Pemeliharaan';

  @override
  String get appEndDrawerMaintenanceRecords => 'Catatan Pemeliharaan';

  @override
  String get appEndDrawerReports => 'Laporan';

  @override
  String get appEndDrawerIssueReports => 'Laporan Masalah';

  @override
  String get appEndDrawerScanLogs => 'Log Pemindaian';

  @override
  String get appEndDrawerScanAsset => 'Pindai Aset';

  @override
  String get appEndDrawerDashboard => 'Dasbor';

  @override
  String get appEndDrawerHome => 'Beranda';

  @override
  String get appEndDrawerProfile => 'Profil';

  @override
  String get customAppBarTitle => 'Aplikasi Saya';

  @override
  String get customAppBarOpenMenu => 'Buka Menu';

  @override
  String get appDropdownSelectOption => 'Pilih opsi';

  @override
  String get appSearchFieldHint => 'Cari...';

  @override
  String get appSearchFieldClear => 'Bersihkan';

  @override
  String get appSearchFieldNoResultsFound => 'Tidak ada hasil';

  @override
  String get staffShellBottomNavDashboard => 'Dasbor';

  @override
  String get staffShellBottomNavScanAsset => 'Pindai Aset';

  @override
  String get staffShellBottomNavProfile => 'Profil';

  @override
  String get shellDoubleBackToExitApp =>
      'Tekan kembali sekali lagi untuk keluar';

  @override
  String get sharedValidationErrors => 'Kesalahan Validasi';

  @override
  String sharedMaxFilesAllowed(int count) {
    return 'Maksimal $count file diizinkan';
  }

  @override
  String sharedFileTooLarge(String name, int size) {
    return 'File $name melebihi batas ${size}MB';
  }

  @override
  String get sharedFailedToPickFiles => 'Gagal memilih file';

  @override
  String get sharedChooseFiles => 'Pilih file';

  @override
  String get sharedUnableToPreviewImage => 'Tidak dapat pratinjau gambar';

  @override
  String get sharedVideoPreviewNotImplemented =>
      'Pratinjau video belum diimplementasikan';

  @override
  String get sharedPreviewNotAvailable =>
      'Pratinjau tidak tersedia untuk jenis file ini';

  @override
  String get sharedDelete => 'Hapus';

  @override
  String get sharedEdit => 'Edit';

  @override
  String get sharedOptions => 'Opsi';

  @override
  String get sharedCreate => 'Buat';

  @override
  String get sharedAddNewItem => 'Tambah item baru';

  @override
  String get sharedSelectMany => 'Pilih Banyak';

  @override
  String get sharedSelectItemsToDelete => 'Pilih beberapa item untuk dihapus';

  @override
  String get sharedFilterAndSort => 'Saring & Urutkan';

  @override
  String get sharedCustomizeDisplay => 'Sesuaikan tampilan';

  @override
  String get sharedExport => 'Ekspor';

  @override
  String get sharedExportDataToFile => 'Ekspor data ke file';

  @override
  String get sharedTimePlaceholder => 'JJ:MM';

  @override
  String get sharedRetry => 'Coba Lagi';
}
