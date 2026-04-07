import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n? of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n);
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
    Locale('ja'),
  ];

  /// Network error dns failure user
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to server.\n• Check your internet connection\n• Disable VPN/DNS if active\n• Try again in a moment'**
  String get networkErrorDnsFailureUser;

  /// Network error connection user
  ///
  /// In en, this message translates to:
  /// **'Connection lost.\n• Check your internet connection\n• Ensure WiFi/data is active\n• Try again in a moment'**
  String get networkErrorConnectionUser;

  /// Network error timeout user
  ///
  /// In en, this message translates to:
  /// **'Connection timeout.\n• Check your internet speed\n• Try again in a moment\n• Contact admin if problem persists'**
  String get networkErrorTimeoutUser;

  /// Network error receive timeout user
  ///
  /// In en, this message translates to:
  /// **'Server took too long to respond.\n• Your internet connection might be slow\n• Try again in a moment\n• Contact admin if problem persists'**
  String get networkErrorReceiveTimeoutUser;

  /// Network error server user
  ///
  /// In en, this message translates to:
  /// **'Server error occurred.\n• Try again in a moment\n• Contact admin if problem persists'**
  String get networkErrorServerUser;

  /// Network error server502 user
  ///
  /// In en, this message translates to:
  /// **'Server unreachable.\n• Server might be under maintenance\n• Try again in a moment\n• Contact admin if problem persists'**
  String get networkErrorServer502User;

  /// Network error server503 user
  ///
  /// In en, this message translates to:
  /// **'Service under maintenance.\n• Wait a moment\n• Try again later\n• Contact admin for more info'**
  String get networkErrorServer503User;

  /// Network error server504 user
  ///
  /// In en, this message translates to:
  /// **'Server timeout.\n• Server is busy\n• Try again in a moment\n• Contact admin if problem persists'**
  String get networkErrorServer504User;

  /// Network error html response
  ///
  /// In en, this message translates to:
  /// **'Server returned HTML instead of JSON. Check API endpoint configuration.'**
  String get networkErrorHtmlResponse;

  /// Network error file downloaded
  ///
  /// In en, this message translates to:
  /// **'File downloaded successfully'**
  String get networkErrorFileDownloaded;

  /// Network error unknown
  ///
  /// In en, this message translates to:
  /// **'Unknown error occurred'**
  String get networkErrorUnknown;

  /// Time ago just now
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeAgoJustNow;

  /// No description provided for @timeAgoMinute.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String timeAgoMinute(int count);

  /// No description provided for @timeAgoHour.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String timeAgoHour(int count);

  /// No description provided for @timeAgoDay.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String timeAgoDay(int count);

  /// No description provided for @timeAgoMonth.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month ago} other{{count} months ago}}'**
  String timeAgoMonth(int count);

  /// No description provided for @timeAgoYear.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year ago} other{{count} years ago}}'**
  String timeAgoYear(int count);

  /// Month jan
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get monthJan;

  /// Month feb
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get monthFeb;

  /// Month mar
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get monthMar;

  /// Month apr
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get monthApr;

  /// Month may
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// Month jun
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get monthJun;

  /// Month jul
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get monthJul;

  /// Month aug
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get monthAug;

  /// Month sep
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get monthSep;

  /// Month oct
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get monthOct;

  /// Month nov
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get monthNov;

  /// Month dec
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get monthDec;

  /// Day mon
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get dayMon;

  /// Day tue
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get dayTue;

  /// Day wed
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get dayWed;

  /// Day thu
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get dayThu;

  /// Day fri
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get dayFri;

  /// Day sat
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get daySat;

  /// Day sun
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get daySun;

  /// Currency billion suffix
  ///
  /// In en, this message translates to:
  /// **'B'**
  String get currencyBillionSuffix;

  /// Currency million suffix
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get currencyMillionSuffix;

  /// Currency thousand suffix
  ///
  /// In en, this message translates to:
  /// **'K'**
  String get currencyThousandSuffix;

  /// Sort order ascending
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get enumSortOrderAsc;

  /// Sort order descending
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get enumSortOrderDesc;

  /// Sort by category code
  ///
  /// In en, this message translates to:
  /// **'Category Code'**
  String get enumCategorySortByCategoryCode;

  /// Sort by name
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get enumCategorySortByName;

  /// Sort by category name
  ///
  /// In en, this message translates to:
  /// **'Category Name'**
  String get enumCategorySortByCategoryName;

  /// Sort by creation date
  ///
  /// In en, this message translates to:
  /// **'Created Date'**
  String get enumCategorySortByCreatedAt;

  /// Sort by update date
  ///
  /// In en, this message translates to:
  /// **'Updated Date'**
  String get enumCategorySortByUpdatedAt;

  /// Sort by location code
  ///
  /// In en, this message translates to:
  /// **'Location Code'**
  String get enumLocationSortByLocationCode;

  /// Sort by name
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get enumLocationSortByName;

  /// Sort by location name
  ///
  /// In en, this message translates to:
  /// **'Location Name'**
  String get enumLocationSortByLocationName;

  /// Sort by building
  ///
  /// In en, this message translates to:
  /// **'Building'**
  String get enumLocationSortByBuilding;

  /// Sort by floor
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get enumLocationSortByFloor;

  /// Sort by creation date
  ///
  /// In en, this message translates to:
  /// **'Created Date'**
  String get enumLocationSortByCreatedAt;

  /// Sort by update date
  ///
  /// In en, this message translates to:
  /// **'Updated Date'**
  String get enumLocationSortByUpdatedAt;

  /// Sort by type
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get enumNotificationSortByType;

  /// Sort by read status
  ///
  /// In en, this message translates to:
  /// **'Read Status'**
  String get enumNotificationSortByIsRead;

  /// Sort by received date
  ///
  /// In en, this message translates to:
  /// **'Received Date'**
  String get enumNotificationSortByCreatedAt;

  /// Sort by title
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get enumNotificationSortByTitle;

  /// Sort by message
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get enumNotificationSortByMessage;

  /// Sort by scan timestamp
  ///
  /// In en, this message translates to:
  /// **'Scan Time'**
  String get enumScanLogSortByScanTimestamp;

  /// Sort by scanned value
  ///
  /// In en, this message translates to:
  /// **'Scanned Value'**
  String get enumScanLogSortByScannedValue;

  /// Sort by scan method
  ///
  /// In en, this message translates to:
  /// **'Scan Method'**
  String get enumScanLogSortByScanMethod;

  /// Sort by scan result
  ///
  /// In en, this message translates to:
  /// **'Scan Result'**
  String get enumScanLogSortByScanResult;

  /// Sort by asset tag
  ///
  /// In en, this message translates to:
  /// **'Asset Tag'**
  String get enumAssetSortByAssetTag;

  /// Sort by asset name
  ///
  /// In en, this message translates to:
  /// **'Asset Name'**
  String get enumAssetSortByAssetName;

  /// Sort by brand
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get enumAssetSortByBrand;

  /// Sort by model
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get enumAssetSortByModel;

  /// Sort by serial number
  ///
  /// In en, this message translates to:
  /// **'Serial Number'**
  String get enumAssetSortBySerialNumber;

  /// Sort by purchase date
  ///
  /// In en, this message translates to:
  /// **'Purchase Date'**
  String get enumAssetSortByPurchaseDate;

  /// Sort by purchase price
  ///
  /// In en, this message translates to:
  /// **'Purchase Price'**
  String get enumAssetSortByPurchasePrice;

  /// Sort by vendor name
  ///
  /// In en, this message translates to:
  /// **'Vendor Name'**
  String get enumAssetSortByVendorName;

  /// Sort by warranty end date
  ///
  /// In en, this message translates to:
  /// **'Warranty End Date'**
  String get enumAssetSortByWarrantyEnd;

  /// Sort by status
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get enumAssetSortByStatus;

  /// Sort by condition
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get enumAssetSortByConditionStatus;

  /// Sort by creation date
  ///
  /// In en, this message translates to:
  /// **'Created Date'**
  String get enumAssetSortByCreatedAt;

  /// Sort by update date
  ///
  /// In en, this message translates to:
  /// **'Updated Date'**
  String get enumAssetSortByUpdatedAt;

  /// Sort by movement date
  ///
  /// In en, this message translates to:
  /// **'Movement Date'**
  String get enumAssetMovementSortByMovementDate;

  /// Sort by movement date (lowercase alias)
  ///
  /// In en, this message translates to:
  /// **'Movement Date'**
  String get enumAssetMovementSortByMovementdate;

  /// Sort by creation date
  ///
  /// In en, this message translates to:
  /// **'Created Date'**
  String get enumAssetMovementSortByCreatedAt;

  /// Sort by creation date (lowercase alias)
  ///
  /// In en, this message translates to:
  /// **'Created Date'**
  String get enumAssetMovementSortByCreatedat;

  /// Sort by update date
  ///
  /// In en, this message translates to:
  /// **'Updated Date'**
  String get enumAssetMovementSortByUpdatedAt;

  /// Sort by update date (lowercase alias)
  ///
  /// In en, this message translates to:
  /// **'Updated Date'**
  String get enumAssetMovementSortByUpdatedat;

  /// Sort by reported date
  ///
  /// In en, this message translates to:
  /// **'Reported Date'**
  String get enumIssueReportSortByReportedDate;

  /// Sort by resolved date
  ///
  /// In en, this message translates to:
  /// **'Resolved Date'**
  String get enumIssueReportSortByResolvedDate;

  /// Sort by issue type
  ///
  /// In en, this message translates to:
  /// **'Issue Type'**
  String get enumIssueReportSortByIssueType;

  /// Sort by priority
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get enumIssueReportSortByPriority;

  /// Sort by status
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get enumIssueReportSortByStatus;

  /// Sort by title
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get enumIssueReportSortByTitle;

  /// Sort by description
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get enumIssueReportSortByDescription;

  /// Sort by creation date
  ///
  /// In en, this message translates to:
  /// **'Created Date'**
  String get enumIssueReportSortByCreatedAt;

  /// Sort by update date
  ///
  /// In en, this message translates to:
  /// **'Updated Date'**
  String get enumIssueReportSortByUpdatedAt;

  /// Sort by next scheduled date
  ///
  /// In en, this message translates to:
  /// **'Next Scheduled Date'**
  String get enumMaintenanceScheduleSortByNextScheduledDate;

  /// Sort by maintenance type
  ///
  /// In en, this message translates to:
  /// **'Maintenance Type'**
  String get enumMaintenanceScheduleSortByMaintenanceType;

  /// Sort by state
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get enumMaintenanceScheduleSortByState;

  /// Sort by creation date
  ///
  /// In en, this message translates to:
  /// **'Created Date'**
  String get enumMaintenanceScheduleSortByCreatedAt;

  /// Sort by update date
  ///
  /// In en, this message translates to:
  /// **'Updated Date'**
  String get enumMaintenanceScheduleSortByUpdatedAt;

  /// Sort by maintenance date
  ///
  /// In en, this message translates to:
  /// **'Maintenance Date'**
  String get enumMaintenanceRecordSortByMaintenanceDate;

  /// Sort by cost
  ///
  /// In en, this message translates to:
  /// **'Actual Cost'**
  String get enumMaintenanceRecordSortByActualCost;

  /// Sort by title
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get enumMaintenanceRecordSortByTitle;

  /// Sort by creation date
  ///
  /// In en, this message translates to:
  /// **'Created Date'**
  String get enumMaintenanceRecordSortByCreatedAt;

  /// Sort by update date
  ///
  /// In en, this message translates to:
  /// **'Updated Date'**
  String get enumMaintenanceRecordSortByUpdatedAt;

  /// Sort by name
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get enumUserSortByName;

  /// Sort by full name
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get enumUserSortByFullName;

  /// Sort by email
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get enumUserSortByEmail;

  /// Sort by role
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get enumUserSortByRole;

  /// Sort by employee ID
  ///
  /// In en, this message translates to:
  /// **'Employee ID'**
  String get enumUserSortByEmployeeId;

  /// Sort by active status
  ///
  /// In en, this message translates to:
  /// **'Active Status'**
  String get enumUserSortByIsActive;

  /// Sort by join date
  ///
  /// In en, this message translates to:
  /// **'Joined Date'**
  String get enumUserSortByCreatedAt;

  /// Sort by update date
  ///
  /// In en, this message translates to:
  /// **'Updated Date'**
  String get enumUserSortByUpdatedAt;

  /// Export format PDF
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get enumExportFormatPdf;

  /// Export format Excel
  ///
  /// In en, this message translates to:
  /// **'Excel'**
  String get enumExportFormatExcel;

  /// Mutation type create
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get enumMutationTypeCreate;

  /// Mutation type update
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get enumMutationTypeUpdate;

  /// Mutation type delete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get enumMutationTypeDelete;

  /// Language English
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get enumLanguageEnglish;

  /// Language Japanese
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get enumLanguageJapanese;

  /// Language Indonesian
  ///
  /// In en, this message translates to:
  /// **'Indonesian'**
  String get enumLanguageIndonesian;

  /// User role Admin
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get enumUserRoleAdmin;

  /// User role User
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get enumUserRoleUser;

  /// Asset status Active
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get enumAssetStatusActive;

  /// Asset status Maintenance
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get enumAssetStatusMaintenance;

  /// Asset status Disposed
  ///
  /// In en, this message translates to:
  /// **'Disposed'**
  String get enumAssetStatusDisposed;

  /// Asset status Lost
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get enumAssetStatusLost;

  /// Asset condition Good
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get enumAssetConditionGood;

  /// Asset condition Fair
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get enumAssetConditionFair;

  /// Asset condition Poor
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get enumAssetConditionPoor;

  /// Asset condition Damaged
  ///
  /// In en, this message translates to:
  /// **'Damaged'**
  String get enumAssetConditionDamaged;

  /// Notification type Maintenance
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get enumNotificationTypeMaintenance;

  /// Notification type Warranty
  ///
  /// In en, this message translates to:
  /// **'Warranty'**
  String get enumNotificationTypeWarranty;

  /// Notification type Issue
  ///
  /// In en, this message translates to:
  /// **'Issue'**
  String get enumNotificationTypeIssue;

  /// Notification type Movement
  ///
  /// In en, this message translates to:
  /// **'Movement'**
  String get enumNotificationTypeMovement;

  /// Notification type Status Change
  ///
  /// In en, this message translates to:
  /// **'Status Change'**
  String get enumNotificationTypeStatusChange;

  /// Notification type Location Change
  ///
  /// In en, this message translates to:
  /// **'Location Change'**
  String get enumNotificationTypeLocationChange;

  /// Notification type Category Change
  ///
  /// In en, this message translates to:
  /// **'Category Change'**
  String get enumNotificationTypeCategoryChange;

  /// Priority Low
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get enumNotificationPriorityLow;

  /// Priority Normal
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get enumNotificationPriorityNormal;

  /// Priority High
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get enumNotificationPriorityHigh;

  /// Priority Urgent
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get enumNotificationPriorityUrgent;

  /// Scan method Data Matrix
  ///
  /// In en, this message translates to:
  /// **'Data Matrix'**
  String get enumScanMethodTypeDataMatrix;

  /// Scan method Manual Input
  ///
  /// In en, this message translates to:
  /// **'Manual Input'**
  String get enumScanMethodTypeManualInput;

  /// Scan result Success
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get enumScanResultTypeSuccess;

  /// Scan result Invalid ID
  ///
  /// In en, this message translates to:
  /// **'Invalid ID'**
  String get enumScanResultTypeInvalidID;

  /// Scan result Asset Not Found
  ///
  /// In en, this message translates to:
  /// **'Asset Not Found'**
  String get enumScanResultTypeAssetNotFound;

  /// Schedule type Preventive
  ///
  /// In en, this message translates to:
  /// **'Preventive'**
  String get enumMaintenanceScheduleTypePreventive;

  /// Schedule type Corrective
  ///
  /// In en, this message translates to:
  /// **'Corrective'**
  String get enumMaintenanceScheduleTypeCorrective;

  /// Schedule type Inspection
  ///
  /// In en, this message translates to:
  /// **'Inspection'**
  String get enumMaintenanceScheduleTypeInspection;

  /// Schedule type Calibration
  ///
  /// In en, this message translates to:
  /// **'Calibration'**
  String get enumMaintenanceScheduleTypeCalibration;

  /// Schedule state Active
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get enumScheduleStateActive;

  /// Schedule state Paused
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get enumScheduleStatePaused;

  /// Schedule state Stopped
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get enumScheduleStateStopped;

  /// Schedule state Completed
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get enumScheduleStateCompleted;

  /// Interval unit Days
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get enumIntervalUnitDays;

  /// Interval unit Weeks
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get enumIntervalUnitWeeks;

  /// Interval unit Months
  ///
  /// In en, this message translates to:
  /// **'Months'**
  String get enumIntervalUnitMonths;

  /// Interval unit Years
  ///
  /// In en, this message translates to:
  /// **'Years'**
  String get enumIntervalUnitYears;

  /// Issue priority Low
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get enumIssuePriorityLow;

  /// Issue priority Medium
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get enumIssuePriorityMedium;

  /// Issue priority High
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get enumIssuePriorityHigh;

  /// Issue priority Critical
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get enumIssuePriorityCritical;

  /// Issue status Open
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get enumIssueStatusOpen;

  /// Issue status In Progress
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get enumIssueStatusInProgress;

  /// Issue status Resolved
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get enumIssueStatusResolved;

  /// Issue status Closed
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get enumIssueStatusClosed;

  /// Maintenance result Success
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get enumMaintenanceResultSuccess;

  /// Maintenance result Partial
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get enumMaintenanceResultPartial;

  /// Maintenance result Failed
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get enumMaintenanceResultFailed;

  /// Maintenance result Rescheduled
  ///
  /// In en, this message translates to:
  /// **'Rescheduled'**
  String get enumMaintenanceResultRescheduled;

  /// Message shown when pressing back button at home root
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit'**
  String get pressBackAgainToExit;

  /// Folders title
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get foldersTitle;

  /// Folders all notes
  ///
  /// In en, this message translates to:
  /// **'All Notes'**
  String get foldersAllNotes;

  /// Folders uncategorized
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get foldersUncategorized;

  /// Folders empty
  ///
  /// In en, this message translates to:
  /// **'No custom folders'**
  String get foldersEmpty;

  /// No description provided for @foldersError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String foldersError(String error);

  /// Folders create new
  ///
  /// In en, this message translates to:
  /// **'Create New Folder'**
  String get foldersCreateNew;

  /// Folders new title
  ///
  /// In en, this message translates to:
  /// **'New Folder'**
  String get foldersNewTitle;

  /// Folders cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get foldersCancel;

  /// Folders create btn
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get foldersCreateBtn;

  /// Notes hidden
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get notesHidden;

  /// No description provided for @notesError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String notesError(String error);

  /// No description provided for @notesSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String notesSelectedCount(int count);

  /// Notes hidden title
  ///
  /// In en, this message translates to:
  /// **'Hidden Notes'**
  String get notesHiddenTitle;

  /// Notes not found
  ///
  /// In en, this message translates to:
  /// **'No notes found.'**
  String get notesNotFound;

  /// Notes graph title
  ///
  /// In en, this message translates to:
  /// **'Graph View'**
  String get notesGraphTitle;

  /// Notes graph empty
  ///
  /// In en, this message translates to:
  /// **'No notes available for graph.'**
  String get notesGraphEmpty;

  /// Notes my title
  ///
  /// In en, this message translates to:
  /// **'My Notes'**
  String get notesMyTitle;

  /// Notes new
  ///
  /// In en, this message translates to:
  /// **'New Note'**
  String get notesNew;

  /// Notes edit
  ///
  /// In en, this message translates to:
  /// **'Edit Note'**
  String get notesEdit;

  /// Notes no content
  ///
  /// In en, this message translates to:
  /// **'No content'**
  String get notesNoContent;

  /// No description provided for @notesTags.
  ///
  /// In en, this message translates to:
  /// **'Tags: {tags}'**
  String notesTags(String tags);

  /// Notes importing notes
  ///
  /// In en, this message translates to:
  /// **'Importing Notes'**
  String get notesImportingNotes;

  /// Notes title optional
  ///
  /// In en, this message translates to:
  /// **'Title (Optional)'**
  String get notesTitleOptional;

  /// Notes search notes
  ///
  /// In en, this message translates to:
  /// **'Search notes...'**
  String get notesSearchNotes;

  /// Notes search hidden notes
  ///
  /// In en, this message translates to:
  /// **'Search hidden notes...'**
  String get notesSearchHiddenNotes;

  /// Untitled note default title
  ///
  /// In en, this message translates to:
  /// **'Untitled Note'**
  String get notesUntitledNote;

  /// Settings title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings material you
  ///
  /// In en, this message translates to:
  /// **'Use Material You'**
  String get settingsMaterialYou;

  /// Settings material you subtitle
  ///
  /// In en, this message translates to:
  /// **'Follow system dynamic colors'**
  String get settingsMaterialYouSubtitle;

  /// Settings theme
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// Settings theme system
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// Settings theme light
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// Settings theme dark
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// Settings language
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Settings language english
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// Settings language japanese
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get settingsLanguageJapanese;

  /// Settings language indonesian
  ///
  /// In en, this message translates to:
  /// **'Indonesian'**
  String get settingsLanguageIndonesian;

  /// Settings trash
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get settingsTrash;

  /// Settings cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsCancel;

  /// Settings delete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get settingsDelete;

  /// Settings restore
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get settingsRestore;

  /// Settings delete permanently
  ///
  /// In en, this message translates to:
  /// **'Delete Permanently'**
  String get settingsDeletePermanently;

  /// Settings error loading auto backup status
  ///
  /// In en, this message translates to:
  /// **'Error loading auto backup status'**
  String get settingsErrorLoadingAutoBackup;

  /// Settings continue
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get settingsContinue;

  /// Settings backup and restore
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settingsBackupAndRestore;

  /// Settings export your notes
  ///
  /// In en, this message translates to:
  /// **'Export your notes to a zip file.'**
  String get settingsExportYourNotesToAZipFile;

  /// Settings are you sure
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get settingsAreYouSure;

  /// Settings empty trash question
  ///
  /// In en, this message translates to:
  /// **'Empty Trash?'**
  String get settingsEmptyTrashQuestion;

  /// Settings trash is empty
  ///
  /// In en, this message translates to:
  /// **'Trash is empty.'**
  String get settingsTrashIsEmpty;

  /// Trash delete subtitle
  ///
  /// In en, this message translates to:
  /// **'Deleted (auto-delete in {days} days)'**
  String settingsTrashDeleteSubtitleReady(int days);

  /// Trash delete subtitle soon
  ///
  /// In en, this message translates to:
  /// **'Deleted (auto-delete very soon)'**
  String get settingsTrashDeleteSubtitleSoon;

  /// Untitled fallback
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get settingsUntitled;

  /// Settings import bulk
  ///
  /// In en, this message translates to:
  /// **'Import Xiaomi Notes (Bulk)'**
  String get settingsImportXiaomiNotesBulk;

  /// Settings import failed
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String settingsImportFailed(String error);

  /// Settings import successful
  ///
  /// In en, this message translates to:
  /// **'Import successful!'**
  String get settingsImportSuccessful;

  /// Settings import folder
  ///
  /// In en, this message translates to:
  /// **'Import Xiaomi Notes (Folder)'**
  String get settingsImportXiaomiNotesFolder;

  /// Settings trash delete description
  ///
  /// In en, this message translates to:
  /// **'All notes in the trash will be permanently deleted.'**
  String get settingsTrashDeleteDescription;

  /// Settings import another running
  ///
  /// In en, this message translates to:
  /// **'Another import is running in the background'**
  String get settingsImportAnotherRunning;

  /// Settings folder import failed
  ///
  /// In en, this message translates to:
  /// **'Folder import failed: {error}'**
  String settingsFolderImportFailed(String error);

  /// Settings import folder progress
  ///
  /// In en, this message translates to:
  /// **'{processed} / {total} imported'**
  String settingsImportFolderProgress(int processed, int total);

  /// No description provided for @settingsManualBackup.
  ///
  /// In en, this message translates to:
  /// **'Manual Backup'**
  String get settingsManualBackup;

  /// No description provided for @settingsExportBackup.
  ///
  /// In en, this message translates to:
  /// **'Export Backup'**
  String get settingsExportBackup;

  /// No description provided for @settingsRestoreBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore Backup'**
  String get settingsRestoreBackupTitle;

  /// No description provided for @settingsRestoreDescription.
  ///
  /// In en, this message translates to:
  /// **'Import notes from a zip file. This will replace your current data.'**
  String get settingsRestoreDescription;

  /// No description provided for @settingsImportBackupBtn.
  ///
  /// In en, this message translates to:
  /// **'Import Backup'**
  String get settingsImportBackupBtn;

  /// No description provided for @settingsAutoBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto Backup'**
  String get settingsAutoBackupTitle;

  /// No description provided for @settingsLastAutoBackup.
  ///
  /// In en, this message translates to:
  /// **'Last auto backup: {date}'**
  String settingsLastAutoBackup(Object date);

  /// No description provided for @settingsNoAutoBackup.
  ///
  /// In en, this message translates to:
  /// **'No auto backup available.'**
  String get settingsNoAutoBackup;

  /// No description provided for @settingsRestoreFromAutoBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from Auto Backup'**
  String get settingsRestoreFromAutoBackup;

  /// No description provided for @settingsBackupExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup exported successfully'**
  String get settingsBackupExportSuccess;

  /// No description provided for @settingsBackupExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup export cancelled or failed'**
  String get settingsBackupExportFailed;

  /// No description provided for @settingsRestoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Restore successful, restarting app...'**
  String get settingsRestoreSuccess;

  /// No description provided for @settingsRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed'**
  String get settingsRestoreFailed;

  /// No description provided for @settingsOverwriteWarning.
  ///
  /// In en, this message translates to:
  /// **'This will overwrite all your current notes. This action cannot be undone.'**
  String get settingsOverwriteWarning;

  /// No description provided for @settingsAutoBackupSettings.
  ///
  /// In en, this message translates to:
  /// **'Auto Backup Settings'**
  String get settingsAutoBackupSettings;

  /// No description provided for @settingsAutoBackupFolder.
  ///
  /// In en, this message translates to:
  /// **'Backup Folder'**
  String get settingsAutoBackupFolder;

  /// No description provided for @settingsAutoBackupFolderDefault.
  ///
  /// In en, this message translates to:
  /// **'Default (App Documents)'**
  String get settingsAutoBackupFolderDefault;

  /// No description provided for @settingsAutoBackupChooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose Folder'**
  String get settingsAutoBackupChooseFolder;

  /// No description provided for @settingsAutoBackupResetFolder.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsAutoBackupResetFolder;

  /// No description provided for @settingsAutoBackupTime.
  ///
  /// In en, this message translates to:
  /// **'Backup Time (daily)'**
  String get settingsAutoBackupTime;

  /// No description provided for @settingsAutoBackupSetTime.
  ///
  /// In en, this message translates to:
  /// **'Set Time'**
  String get settingsAutoBackupSetTime;

  /// No description provided for @settingsAutoBackupRunNow.
  ///
  /// In en, this message translates to:
  /// **'Run Auto Backup Now'**
  String get settingsAutoBackupRunNow;

  /// No description provided for @settingsAutoBackupRunSuccess.
  ///
  /// In en, this message translates to:
  /// **'Auto backup completed successfully'**
  String get settingsAutoBackupRunSuccess;

  /// No description provided for @settingsAutoBackupRunFailed.
  ///
  /// In en, this message translates to:
  /// **'Auto backup failed'**
  String get settingsAutoBackupRunFailed;

  /// Tasks title
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasksTitle;

  /// Tasks empty
  ///
  /// In en, this message translates to:
  /// **'No Tasks. Create one!'**
  String get tasksEmpty;

  /// Tasks active
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get tasksActive;

  /// Tasks completed
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get tasksCompleted;

  /// Tasks nothing here
  ///
  /// In en, this message translates to:
  /// **'Nothing here...'**
  String get tasksNothingHere;

  /// Tasks new
  ///
  /// In en, this message translates to:
  /// **'New Task'**
  String get tasksNew;

  /// Tasks edit
  ///
  /// In en, this message translates to:
  /// **'Edit Task'**
  String get tasksEdit;

  /// Tasks title label
  ///
  /// In en, this message translates to:
  /// **'Task Title'**
  String get tasksTitleLabel;

  /// Tasks due date
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get tasksDueDate;

  /// Tasks save
  ///
  /// In en, this message translates to:
  /// **'Save Task'**
  String get tasksSave;

  /// No description provided for @tasksError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String tasksError(String error);

  /// Tasks task reminder
  ///
  /// In en, this message translates to:
  /// **'Task Reminder'**
  String get tasksTaskReminder;

  /// Admin shell bottom navigation label for dashboard
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get adminShellBottomNavDashboard;

  /// Admin shell bottom navigation label for scan asset
  ///
  /// In en, this message translates to:
  /// **'Scan Asset'**
  String get adminShellBottomNavScanAsset;

  /// Admin shell bottom navigation label for profile
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get adminShellBottomNavProfile;

  /// User shell bottom navigation label for home
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get userShellBottomNavHome;

  /// User shell bottom navigation label for scan asset
  ///
  /// In en, this message translates to:
  /// **'Scan Asset'**
  String get userShellBottomNavScanAsset;

  /// User shell bottom navigation label for profile
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get userShellBottomNavProfile;

  /// App end drawer title
  ///
  /// In en, this message translates to:
  /// **'My App'**
  String get appEndDrawerTitle;

  /// Message shown when user needs to login
  ///
  /// In en, this message translates to:
  /// **'Please login first'**
  String get appEndDrawerPleaseLoginFirst;

  /// Theme settings label
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get appEndDrawerTheme;

  /// Language settings label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get appEndDrawerLanguage;

  /// Logout button label
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get appEndDrawerLogout;

  /// Management section header
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get appEndDrawerManagementSection;

  /// Maintenance section header
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get appEndDrawerMaintenanceSection;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get appEndDrawerEnglish;

  /// Indonesian language option
  ///
  /// In en, this message translates to:
  /// **'Indonesia'**
  String get appEndDrawerIndonesian;

  /// Japanese language option
  ///
  /// In en, this message translates to:
  /// **'日本語'**
  String get appEndDrawerJapanese;

  /// My assets menu item
  ///
  /// In en, this message translates to:
  /// **'My Assets'**
  String get appEndDrawerMyAssets;

  /// Notifications menu item
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get appEndDrawerNotifications;

  /// My issue reports menu item
  ///
  /// In en, this message translates to:
  /// **'My Issue Reports'**
  String get appEndDrawerMyIssueReports;

  /// Assets menu item
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get appEndDrawerAssets;

  /// Asset movements menu item
  ///
  /// In en, this message translates to:
  /// **'Asset Movements'**
  String get appEndDrawerAssetMovements;

  /// Categories menu item
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get appEndDrawerCategories;

  /// Locations menu item
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get appEndDrawerLocations;

  /// Users menu item
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get appEndDrawerUsers;

  /// Maintenance schedules menu item
  ///
  /// In en, this message translates to:
  /// **'Maintenance Schedules'**
  String get appEndDrawerMaintenanceSchedules;

  /// Maintenance records menu item
  ///
  /// In en, this message translates to:
  /// **'Maintenance Records'**
  String get appEndDrawerMaintenanceRecords;

  /// Reports menu item
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get appEndDrawerReports;

  /// Issue reports menu item
  ///
  /// In en, this message translates to:
  /// **'Issue Reports'**
  String get appEndDrawerIssueReports;

  /// Scan logs menu item
  ///
  /// In en, this message translates to:
  /// **'Scan Logs'**
  String get appEndDrawerScanLogs;

  /// Scan asset menu item
  ///
  /// In en, this message translates to:
  /// **'Scan Asset'**
  String get appEndDrawerScanAsset;

  /// Dashboard menu item
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get appEndDrawerDashboard;

  /// Home menu item
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get appEndDrawerHome;

  /// Profile menu item
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get appEndDrawerProfile;

  /// App bar title
  ///
  /// In en, this message translates to:
  /// **'My App'**
  String get customAppBarTitle;

  /// Open menu button label
  ///
  /// In en, this message translates to:
  /// **'Open Menu'**
  String get customAppBarOpenMenu;

  /// Dropdown select option placeholder
  ///
  /// In en, this message translates to:
  /// **'Select option'**
  String get appDropdownSelectOption;

  /// Search field hint text
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get appSearchFieldHint;

  /// Clear search button label
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get appSearchFieldClear;

  /// No results found message
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get appSearchFieldNoResultsFound;

  /// Staff shell bottom navigation label for dashboard
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get staffShellBottomNavDashboard;

  /// Staff shell bottom navigation label for scan asset
  ///
  /// In en, this message translates to:
  /// **'Scan Asset'**
  String get staffShellBottomNavScanAsset;

  /// Staff shell bottom navigation label for profile
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get staffShellBottomNavProfile;

  /// Message shown when user needs to press back again to exit app
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit'**
  String get shellDoubleBackToExitApp;

  /// Title for validation errors widget
  ///
  /// In en, this message translates to:
  /// **'Validation Errors'**
  String get sharedValidationErrors;

  /// Error message for max files allowed
  ///
  /// In en, this message translates to:
  /// **'Maximum {count} files allowed'**
  String sharedMaxFilesAllowed(int count);

  /// Error message for file size limit
  ///
  /// In en, this message translates to:
  /// **'File {name} exceeds {size}MB limit'**
  String sharedFileTooLarge(String name, int size);

  /// Error message for file picking failure
  ///
  /// In en, this message translates to:
  /// **'Failed to pick files'**
  String get sharedFailedToPickFiles;

  /// Hint text for file picker
  ///
  /// In en, this message translates to:
  /// **'Choose file(s)'**
  String get sharedChooseFiles;

  /// Error text for image preview failure
  ///
  /// In en, this message translates to:
  /// **'Unable to preview image'**
  String get sharedUnableToPreviewImage;

  /// Placeholder text for video preview
  ///
  /// In en, this message translates to:
  /// **'Video preview not implemented yet'**
  String get sharedVideoPreviewNotImplemented;

  /// Error text for unsupported file preview
  ///
  /// In en, this message translates to:
  /// **'Preview not available for this file type'**
  String get sharedPreviewNotAvailable;

  /// Delete button label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get sharedDelete;

  /// Edit button label
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get sharedEdit;

  /// Options title
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get sharedOptions;

  /// Create button label
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get sharedCreate;

  /// Add new item subtitle
  ///
  /// In en, this message translates to:
  /// **'Add a new item'**
  String get sharedAddNewItem;

  /// Select many option title
  ///
  /// In en, this message translates to:
  /// **'Select Many'**
  String get sharedSelectMany;

  /// Select items to delete subtitle
  ///
  /// In en, this message translates to:
  /// **'Select multiple items to delete'**
  String get sharedSelectItemsToDelete;

  /// Filter and sort option title
  ///
  /// In en, this message translates to:
  /// **'Filter & Sort'**
  String get sharedFilterAndSort;

  /// Customize display subtitle
  ///
  /// In en, this message translates to:
  /// **'Customize display'**
  String get sharedCustomizeDisplay;

  /// Export option title
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get sharedExport;

  /// Export data subtitle
  ///
  /// In en, this message translates to:
  /// **'Export data to file'**
  String get sharedExportDataToFile;

  /// Time placeholder
  ///
  /// In en, this message translates to:
  /// **'HH:MM'**
  String get sharedTimePlaceholder;

  /// Retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get sharedRetry;

  /// Shared my notes
  ///
  /// In en, this message translates to:
  /// **'My Notes'**
  String get sharedMyNotes;

  /// Shared tasks
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get sharedTasks;

  /// Shared settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get sharedSettings;

  /// Shared material you
  ///
  /// In en, this message translates to:
  /// **'Material You'**
  String get sharedMaterialYou;

  /// Shared app name
  ///
  /// In en, this message translates to:
  /// **'Kawai Notes'**
  String get sharedAppName;

  /// Shared route not found
  ///
  /// In en, this message translates to:
  /// **'Route not found'**
  String get sharedRouteNotFound;

  /// Shared error initializing app
  ///
  /// In en, this message translates to:
  /// **'Error initializing app'**
  String get sharedErrorInitializingApp;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return L10nEn();
    case 'id':
      return L10nId();
    case 'ja':
      return L10nJa();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
