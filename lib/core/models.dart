import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eventflow/core/constants/app_constants.dart';

// ─── Organization Model ────────────────────────────────────────────

class Organization {
  final String id;
  final String name;
  final String? logo;
  final String? email;
  final String? fiscalInfo;
  final String? primaryColor;
  final SubscriptionPlan plan;
  final DateTime createdAt;

  Organization({
    required this.id,
    required this.name,
    this.logo,
    this.email,
    this.fiscalInfo,
    this.primaryColor,
    this.plan = SubscriptionPlan.free,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Organization.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Organization(
      id: doc.id,
      name: data['name'] ?? '',
      logo: data['logo'],
      email: data['email'],
      fiscalInfo: data['fiscalInfo'],
      primaryColor: data['primaryColor'],
      plan: SubscriptionPlan.values.firstWhere(
        (p) => p.name == data['plan'],
        orElse: () => SubscriptionPlan.free,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'logo': logo,
    'email': email,
    'fiscalInfo': fiscalInfo,
    'primaryColor': primaryColor,
    'plan': plan.name,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

// ─── Organization Member Model ─────────────────────────────────────

class OrgMember {
  final String id;
  final String orgId;
  final String userId;
  final String email;
  final String? displayName;
  final OrgRole role;
  final DateTime joinedAt;

  OrgMember({
    required this.id,
    required this.orgId,
    required this.userId,
    required this.email,
    this.displayName,
    required this.role,
    DateTime? joinedAt,
  }) : joinedAt = joinedAt ?? DateTime.now();

  factory OrgMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrgMember(
      id: doc.id,
      orgId: data['orgId'] ?? '',
      userId: data['userId'] ?? '',
      email: data['email'] ?? '',
      displayName: data['displayName'],
      role: OrgRole.values.firstWhere(
        (r) => r.name == data['role'],
        orElse: () => OrgRole.viewer,
      ),
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'orgId': orgId,
    'userId': userId,
    'email': email,
    'displayName': displayName,
    'role': role.name,
    'joinedAt': Timestamp.fromDate(joinedAt),
  };
}

// ─── AppUser Model ─────────────────────────────────────────────────

class AppUser {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final List<String> organizationIds;
  final String? activeOrgId;
  final String? uiLanguage; // Persisted UI language preference ('it' | 'en')
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.organizationIds = const [],
    this.activeOrgId,
    this.uiLanguage,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      organizationIds: List<String>.from(data['organizationIds'] ?? []),
      activeOrgId: data['activeOrgId'],
      uiLanguage: data['uiLanguage'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'organizationIds': organizationIds,
    'activeOrgId': activeOrgId,
    'uiLanguage': uiLanguage,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  AppUser copyWith({
    String? displayName,
    String? photoUrl,
    List<String>? organizationIds,
    String? activeOrgId,
    String? uiLanguage,
  }) {
    return AppUser(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      organizationIds: organizationIds ?? this.organizationIds,
      activeOrgId: activeOrgId ?? this.activeOrgId,
      uiLanguage: uiLanguage ?? this.uiLanguage,
      createdAt: createdAt,
    );
  }
}

// ─── Time Slot Model ───────────────────────────────────────────────

class TimeSlot {
  final String id;
  final String label;
  final String startTime; // HH:mm format
  final String endTime;   // HH:mm format
  final int maxCapacity;
  final int bookedCount;

  TimeSlot({
    required this.id,
    required this.label,
    required this.startTime,
    required this.endTime,
    this.maxCapacity = 10,
    this.bookedCount = 0,
  });

  bool get isFull => bookedCount >= maxCapacity;
  int get availableSpots => maxCapacity - bookedCount;

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      id: map['id'] ?? '',
      label: map['label'] ?? '',
      startTime: map['startTime'] ?? '09:00',
      endTime: map['endTime'] ?? '10:00',
      maxCapacity: map['maxCapacity'] ?? 10,
      bookedCount: map['bookedCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'startTime': startTime,
    'endTime': endTime,
    'maxCapacity': maxCapacity,
    'bookedCount': bookedCount,
  };

  TimeSlot copyWith({
    String? label,
    String? startTime,
    String? endTime,
    int? maxCapacity,
    int? bookedCount,
  }) {
    return TimeSlot(
      id: id,
      label: label ?? this.label,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      bookedCount: bookedCount ?? this.bookedCount,
    );
  }
}

// ─── Event Model ───────────────────────────────────────────────────

class EventModel {
  final String id;
  final String orgId;
  final String title;
  final String? description;
  final DateTime date;
  final DateTime? endDate;
  final String? location;
  final EventStatus status;
  final int maxAttendees;
  final DateTime? registrationDeadline;
  final List<String> categories;
  final List<CustomField> customFields;
  final bool isPaid;
  final double? price;
  final String? publicUrl;
  final int attendeesCount;
  final double revenue;
  final bool hasTimeSlots;
  final List<TimeSlot> timeSlots;
  // Customization & Appearance
  final String? primaryColor;
  final bool showAttendeesCount;
  // Automated Emails
  final bool reminderEnabled;
  final int reminderDaysBefore; // 1, 3, 7
  final DateTime? reminderSentAt;
  final bool postEventEmailEnabled;
  final DateTime? postEventSentAt;
  final bool notifyOrganizerOnNewRegistration;
  final String? printerIpAddress;
  final bool autoPrintOnCheckIn;
  final bool isOnline;
  final String? meetingUrl;
  final bool allowGroupRegistration;
  final String language; // Event language for attendee-facing content ('it' | 'en')
  final DateTime createdAt;

  EventModel({
    required this.id,
    required this.orgId,
    required this.title,
    this.description,
    required this.date,
    this.endDate,
    this.location,
    this.status = EventStatus.draft,
    this.maxAttendees = 50,
    this.registrationDeadline,
    this.categories = const ['Standard'],
    this.customFields = const [],
    this.isPaid = false,
    this.price,
    this.publicUrl,
    this.attendeesCount = 0,
    this.revenue = 0,
    this.hasTimeSlots = false,
    this.timeSlots = const [],
    this.primaryColor,
    this.showAttendeesCount = false,
    this.reminderEnabled = false,
    this.reminderDaysBefore = 1,
    this.reminderSentAt,
    this.postEventEmailEnabled = false,
    this.postEventSentAt,
    this.notifyOrganizerOnNewRegistration = false,
    this.printerIpAddress,
    this.autoPrintOnCheckIn = false,
    this.isOnline = false,
    this.meetingUrl,
    this.allowGroupRegistration = false,
    this.language = 'it',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventModel(
      id: doc.id,
      orgId: data['orgId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      date: (data['date'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      location: data['location'],
      status: EventStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => EventStatus.draft,
      ),
      maxAttendees: data['maxAttendees'] ?? 50,
      registrationDeadline: (data['registrationDeadline'] as Timestamp?)?.toDate(),
      categories: List<String>.from(data['categories'] ?? ['Standard']),
      customFields: (data['customFields'] as List<dynamic>?)
          ?.map((f) => CustomField.fromMap(f as Map<String, dynamic>))
          .toList() ?? [],
      isPaid: data['isPaid'] ?? false,
      price: (data['price'] as num?)?.toDouble(),
      publicUrl: data['publicUrl'],
      attendeesCount: data['attendeesCount'] ?? 0,
      revenue: (data['revenue'] as num?)?.toDouble() ?? 0,
      hasTimeSlots: data['hasTimeSlots'] ?? false,
      timeSlots: (data['timeSlots'] as List<dynamic>?)
          ?.map((s) => TimeSlot.fromMap(s as Map<String, dynamic>))
          .toList() ?? [],
      primaryColor: data['primaryColor'],
      showAttendeesCount: data['showAttendeesCount'] ?? false,
      reminderEnabled: data['reminderEnabled'] ?? false,
      reminderDaysBefore: data['reminderDaysBefore'] ?? 1,
      reminderSentAt: (data['reminderSentAt'] as Timestamp?)?.toDate(),
      postEventEmailEnabled: data['postEventEmailEnabled'] ?? false,
      postEventSentAt: (data['postEventSentAt'] as Timestamp?)?.toDate(),
      notifyOrganizerOnNewRegistration: data['notifyOrganizerOnNewRegistration'] ?? false,
      printerIpAddress: data['printerIpAddress'],
      autoPrintOnCheckIn: data['autoPrintOnCheckIn'] ?? false,
      isOnline: data['isOnline'] ?? false,
      meetingUrl: data['meetingUrl'],
      allowGroupRegistration: data['allowGroupRegistration'] ?? false,
      language: data['language'] ?? 'it',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'orgId': orgId,
    'title': title,
    'description': description,
    'date': Timestamp.fromDate(date),
    'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
    'location': location,
    'status': status.name,
    'maxAttendees': maxAttendees,
    'registrationDeadline': registrationDeadline != null
        ? Timestamp.fromDate(registrationDeadline!)
        : null,
    'categories': categories,
    'customFields': customFields.map((f) => f.toMap()).toList(),
    'isPaid': isPaid,
    'price': price,
    'publicUrl': publicUrl,
    'attendeesCount': attendeesCount,
    'revenue': revenue,
    'hasTimeSlots': hasTimeSlots,
    'timeSlots': timeSlots.map((s) => s.toMap()).toList(),
    'primaryColor': primaryColor,
    'showAttendeesCount': showAttendeesCount,
    'reminderEnabled': reminderEnabled,
    'reminderDaysBefore': reminderDaysBefore,
    'reminderSentAt': reminderSentAt != null ? Timestamp.fromDate(reminderSentAt!) : null,
    'postEventEmailEnabled': postEventEmailEnabled,
    'postEventSentAt': postEventSentAt != null ? Timestamp.fromDate(postEventSentAt!) : null,
    'notifyOrganizerOnNewRegistration': notifyOrganizerOnNewRegistration,
    'printerIpAddress': printerIpAddress,
    'autoPrintOnCheckIn': autoPrintOnCheckIn,
    'isOnline': isOnline,
    'meetingUrl': meetingUrl,
    'allowGroupRegistration': allowGroupRegistration,
    'language': language,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  EventModel copyWith({
    String? title,
    String? description,
    DateTime? date,
    DateTime? endDate,
    String? location,
    EventStatus? status,
    int? maxAttendees,
    DateTime? registrationDeadline,
    List<String>? categories,
    List<CustomField>? customFields,
    bool? isPaid,
    double? price,
    String? publicUrl,
    int? attendeesCount,
    double? revenue,
    bool? hasTimeSlots,
    List<TimeSlot>? timeSlots,
    String? primaryColor,
    bool? showAttendeesCount,
    bool? reminderEnabled,
    int? reminderDaysBefore,
    DateTime? reminderSentAt,
    bool? postEventEmailEnabled,
    DateTime? postEventSentAt,
    bool? notifyOrganizerOnNewRegistration,
    String? printerIpAddress,
    bool? autoPrintOnCheckIn,
    bool? isOnline,
    String? meetingUrl,
    bool? allowGroupRegistration,
    String? language,
  }) {
    return EventModel(
      id: id,
      orgId: orgId,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      endDate: endDate ?? this.endDate,
      location: location ?? this.location,
      status: status ?? this.status,
      maxAttendees: maxAttendees ?? this.maxAttendees,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      categories: categories ?? this.categories,
      customFields: customFields ?? this.customFields,
      isPaid: isPaid ?? this.isPaid,
      price: price ?? this.price,
      publicUrl: publicUrl ?? this.publicUrl,
      attendeesCount: attendeesCount ?? this.attendeesCount,
      revenue: revenue ?? this.revenue,
      hasTimeSlots: hasTimeSlots ?? this.hasTimeSlots,
      timeSlots: timeSlots ?? this.timeSlots,
      primaryColor: primaryColor ?? this.primaryColor,
      showAttendeesCount: showAttendeesCount ?? this.showAttendeesCount,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      reminderSentAt: reminderSentAt ?? this.reminderSentAt,
      postEventEmailEnabled: postEventEmailEnabled ?? this.postEventEmailEnabled,
      postEventSentAt: postEventSentAt ?? this.postEventSentAt,
      notifyOrganizerOnNewRegistration: notifyOrganizerOnNewRegistration ?? this.notifyOrganizerOnNewRegistration,
      printerIpAddress: printerIpAddress ?? this.printerIpAddress,
      autoPrintOnCheckIn: autoPrintOnCheckIn ?? this.autoPrintOnCheckIn,
      isOnline: isOnline ?? this.isOnline,
      meetingUrl: meetingUrl ?? this.meetingUrl,
      allowGroupRegistration: allowGroupRegistration ?? this.allowGroupRegistration,
      language: language ?? this.language,
      createdAt: createdAt,
    );
  }

  bool get isFull => attendeesCount >= maxAttendees;
  bool get isRegistrationOpen =>
      status == EventStatus.published &&
      !isFull &&
      (registrationDeadline == null || DateTime.now().isBefore(registrationDeadline!));
}

// ─── Custom Field ──────────────────────────────────────────────────

class CustomField {
  final String id;
  final String label;
  final String type; // 'text', 'select', 'number', 'checkbox', 'email', 'phone'
  final bool required;
  final List<String>? options; // for 'select' type
  final String? placeholder;

  CustomField({
    String? id,
    required this.label,
    this.type = 'text',
    this.required = false,
    this.options,
    this.placeholder,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  factory CustomField.fromMap(Map<String, dynamic> map) {
    return CustomField(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      label: map['label'] ?? '',
      type: map['type'] ?? 'text',
      required: map['required'] ?? false,
      options: map['options'] != null ? List<String>.from(map['options']) : null,
      placeholder: map['placeholder'],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'type': type,
    'required': required,
    'options': options,
    'placeholder': placeholder,
  };

  String get typeLabel {
    switch (type) {
      case 'text': return 'Testo';
      case 'select': return 'Selezione';
      case 'number': return 'Numero';
      case 'checkbox': return 'Checkbox';
      case 'email': return 'Email';
      case 'phone': return 'Telefono';
      default: return type;
    }
  }
}

// ─── Attendee Model ────────────────────────────────────────────────

class Attendee {
  final String id;
  final String eventId;
  final String orgId;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String category;
  final RegistrationStatus status;
  final CheckInStatus checkInStatus;
  final DateTime? checkInTime;
  final String qrCode;
  final String? timeSlotId;
  final Map<String, dynamic> customData;
  final DateTime registeredAt;

  Attendee({
    required this.id,
    required this.eventId,
    required this.orgId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.category = 'Standard',
    this.status = RegistrationStatus.pending,
    this.checkInStatus = CheckInStatus.notCheckedIn,
    this.checkInTime,
    required this.qrCode,
    this.timeSlotId,
    this.customData = const {},
    DateTime? registeredAt,
  }) : registeredAt = registeredAt ?? DateTime.now();

  String get fullName => '$firstName $lastName';

  factory Attendee.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Attendee(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      orgId: data['orgId'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'],
      category: data['category'] ?? 'Standard',
      status: RegistrationStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => RegistrationStatus.pending,
      ),
      checkInStatus: CheckInStatus.values.firstWhere(
        (s) => s.name == data['checkInStatus'],
        orElse: () => CheckInStatus.notCheckedIn,
      ),
      checkInTime: (data['checkInTime'] as Timestamp?)?.toDate(),
      qrCode: data['qrCode'] ?? '',
      timeSlotId: data['timeSlotId'],
      customData: Map<String, dynamic>.from(data['customData'] ?? {}),
      registeredAt: (data['registeredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'eventId': eventId,
    'orgId': orgId,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'phone': phone,
    'category': category,
    'status': status.name,
    'checkInStatus': checkInStatus.name,
    'checkInTime': checkInTime != null ? Timestamp.fromDate(checkInTime!) : null,
    'qrCode': qrCode,
    'timeSlotId': timeSlotId,
    'customData': customData,
    'registeredAt': Timestamp.fromDate(registeredAt),
  };

  Attendee copyWith({
    RegistrationStatus? status,
    CheckInStatus? checkInStatus,
    DateTime? checkInTime,
    String? timeSlotId,
    Map<String, dynamic>? customData,
  }) {
    return Attendee(
      id: id,
      eventId: eventId,
      orgId: orgId,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      category: category,
      status: status ?? this.status,
      checkInStatus: checkInStatus ?? this.checkInStatus,
      checkInTime: checkInTime ?? this.checkInTime,
      qrCode: qrCode,
      timeSlotId: timeSlotId ?? this.timeSlotId,
      customData: customData ?? this.customData,
      registeredAt: registeredAt,
    );
  }
}

// ─── Promotion / Offer Model ────────────────────────────────────────

class PromotionModel {
  final String id;
  final String orgId;
  final String title;
  final String? description;
  final String? partnerName;
  final String? partnerLogoUrl;
  final String codePrefix;
  final int currentSequence;
  final int totalVouchers;
  final int claimedCount;
  final int redeemedCount;
  final DateTime expirationDate;
  final OfferType offerType;
  final double? discountValue;
  final double? price;
  final PromotionPaymentMethod paymentMethod;
  final String? linkedEventId;
  final PromotionStatus status;
  final String? primaryColor;
  final int validityDays; // Duration of voucher validity in days after registration
  final DateTime createdAt;
  final DateTime? updatedAt;

  PromotionModel({
    required this.id,
    required this.orgId,
    required this.title,
    this.description,
    this.partnerName,
    this.partnerLogoUrl,
    required this.codePrefix,
    this.currentSequence = 0,
    this.totalVouchers = 0,
    this.claimedCount = 0,
    this.redeemedCount = 0,
    required this.expirationDate,
    this.validityDays = 30,
    this.offerType = OfferType.twoForOne,
    this.discountValue,
    this.price,
    this.paymentMethod = PromotionPaymentMethod.atVenue,
    this.linkedEventId,
    this.status = PromotionStatus.active,
    this.primaryColor,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isExpired => DateTime.now().isAfter(expirationDate);
  bool get isActive => status == PromotionStatus.active && !isExpired;
  bool get isTwoForOne => offerType == OfferType.twoForOne;
  bool get isPartnership => partnerName != null && partnerName!.trim().isNotEmpty;
  int get availableCount => (totalVouchers - claimedCount).clamp(0, totalVouchers);
  double get redemptionRate => totalVouchers > 0 ? (redeemedCount / totalVouchers) : 0;
  double get claimRate => totalVouchers > 0 ? (claimedCount / totalVouchers) : 0;

  factory PromotionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PromotionModel(
      id: doc.id,
      orgId: data['orgId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      partnerName: data['partnerName'],
      partnerLogoUrl: data['partnerLogoUrl'],
      codePrefix: data['codePrefix'] ?? 'PROMO',
      currentSequence: data['currentSequence'] ?? 0,
      totalVouchers: data['totalVouchers'] ?? 0,
      claimedCount: data['claimedCount'] ?? 0,
      redeemedCount: data['redeemedCount'] ?? 0,
      expirationDate: (data['expirationDate'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 30)),
      validityDays: (data['validityDays'] as num?)?.toInt() ?? 30,
      offerType: OfferType.values.firstWhere(
        (t) => t.name == data['offerType'],
        orElse: () => OfferType.twoForOne,
      ),
      discountValue: (data['discountValue'] as num?)?.toDouble(),
      price: (data['price'] as num?)?.toDouble(),
      paymentMethod: PromotionPaymentMethod.values.firstWhere(
        (m) => m.name == data['paymentMethod'],
        orElse: () => PromotionPaymentMethod.atVenue,
      ),
      linkedEventId: data['linkedEventId'],
      status: PromotionStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => PromotionStatus.active,
      ),
      primaryColor: data['primaryColor'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'orgId': orgId,
    'title': title,
    'description': description,
    'partnerName': partnerName,
    'partnerLogoUrl': partnerLogoUrl,
    'codePrefix': codePrefix.toUpperCase().trim(),
    'currentSequence': currentSequence,
    'totalVouchers': totalVouchers,
    'claimedCount': claimedCount,
    'redeemedCount': redeemedCount,
    'expirationDate': Timestamp.fromDate(expirationDate),
    'validityDays': validityDays,
    'offerType': offerType.name,
    'discountValue': discountValue,
    'price': price,
    'paymentMethod': paymentMethod.name,
    'linkedEventId': linkedEventId,
    'status': status.name,
    'primaryColor': primaryColor,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
  };

  PromotionModel copyWith({
    String? title,
    String? description,
    String? partnerName,
    String? partnerLogoUrl,
    String? codePrefix,
    int? currentSequence,
    int? totalVouchers,
    int? claimedCount,
    int? redeemedCount,
    DateTime? expirationDate,
    int? validityDays,
    OfferType? offerType,
    double? discountValue,
    double? price,
    PromotionPaymentMethod? paymentMethod,
    String? linkedEventId,
    PromotionStatus? status,
    String? primaryColor,
    DateTime? updatedAt,
  }) {
    return PromotionModel(
      id: id,
      orgId: orgId,
      title: title ?? this.title,
      description: description ?? this.description,
      partnerName: partnerName ?? this.partnerName,
      partnerLogoUrl: partnerLogoUrl ?? this.partnerLogoUrl,
      codePrefix: codePrefix ?? this.codePrefix,
      currentSequence: currentSequence ?? this.currentSequence,
      totalVouchers: totalVouchers ?? this.totalVouchers,
      claimedCount: claimedCount ?? this.claimedCount,
      redeemedCount: redeemedCount ?? this.redeemedCount,
      expirationDate: expirationDate ?? this.expirationDate,
      validityDays: validityDays ?? this.validityDays,
      offerType: offerType ?? this.offerType,
      discountValue: discountValue ?? this.discountValue,
      price: price ?? this.price,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      linkedEventId: linkedEventId ?? this.linkedEventId,
      status: status ?? this.status,
      primaryColor: primaryColor ?? this.primaryColor,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ─── Voucher Model ──────────────────────────────────────────────────

class VoucherModel {
  final String id;
  final String promoId;
  final String orgId;
  final String code; // e.g. "FIT-0001"
  final int sequenceNumber;
  final VoucherStatus status;
  final DateTime? claimedAt;
  final DateTime? expiresAt; // Computed when claimed: claimedAt + validityDays
  final String? claimedFirstName;
  final String? claimedLastName;
  final String? claimedEmail;
  final String? claimedPhone;
  final DateTime? redeemedAt;
  final String? redeemedByUserId;
  final VoucherPaymentStatus paymentStatus;
  final DateTime createdAt;

  VoucherModel({
    required this.id,
    required this.promoId,
    required this.orgId,
    required this.code,
    required this.sequenceNumber,
    this.status = VoucherStatus.available,
    this.claimedAt,
    this.expiresAt,
    this.claimedFirstName,
    this.claimedLastName,
    this.claimedEmail,
    this.claimedPhone,
    this.redeemedAt,
    this.redeemedByUserId,
    this.paymentStatus = VoucherPaymentStatus.notRequired,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get claimedFullName => '${claimedFirstName ?? ''} ${claimedLastName ?? ''}'.trim();
  bool get isAvailable => status == VoucherStatus.available;
  bool get isClaimed => status == VoucherStatus.claimed;
  bool get isRedeemed => status == VoucherStatus.redeemed;
  bool get isCancelled => status == VoucherStatus.cancelled;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  int? get remainingDays {
    if (expiresAt == null) return null;
    final diff = expiresAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  factory VoucherModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VoucherModel(
      id: doc.id,
      promoId: data['promoId'] ?? '',
      orgId: data['orgId'] ?? '',
      code: data['code'] ?? '',
      sequenceNumber: data['sequenceNumber'] ?? 0,
      status: VoucherStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => VoucherStatus.available,
      ),
      claimedAt: (data['claimedAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      claimedFirstName: data['claimedFirstName'],
      claimedLastName: data['claimedLastName'],
      claimedEmail: data['claimedEmail'],
      claimedPhone: data['claimedPhone'],
      redeemedAt: (data['redeemedAt'] as Timestamp?)?.toDate(),
      redeemedByUserId: data['redeemedByUserId'],
      paymentStatus: VoucherPaymentStatus.values.firstWhere(
        (p) => p.name == data['paymentStatus'],
        orElse: () => VoucherPaymentStatus.notRequired,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'promoId': promoId,
    'orgId': orgId,
    'code': code,
    'sequenceNumber': sequenceNumber,
    'status': status.name,
    'claimedAt': claimedAt != null ? Timestamp.fromDate(claimedAt!) : null,
    'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
    'claimedFirstName': claimedFirstName,
    'claimedLastName': claimedLastName,
    'claimedEmail': claimedEmail,
    'claimedPhone': claimedPhone,
    'redeemedAt': redeemedAt != null ? Timestamp.fromDate(redeemedAt!) : null,
    'redeemedByUserId': redeemedByUserId,
    'paymentStatus': paymentStatus.name,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  VoucherModel copyWith({
    VoucherStatus? status,
    DateTime? claimedAt,
    DateTime? expiresAt,
    String? claimedFirstName,
    String? claimedLastName,
    String? claimedEmail,
    String? claimedPhone,
    DateTime? redeemedAt,
    String? redeemedByUserId,
    VoucherPaymentStatus? paymentStatus,
  }) {
    return VoucherModel(
      id: id,
      promoId: promoId,
      orgId: orgId,
      code: code,
      sequenceNumber: sequenceNumber,
      status: status ?? this.status,
      claimedAt: claimedAt ?? this.claimedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      claimedFirstName: claimedFirstName ?? this.claimedFirstName,
      claimedLastName: claimedLastName ?? this.claimedLastName,
      claimedEmail: claimedEmail ?? this.claimedEmail,
      claimedPhone: claimedPhone ?? this.claimedPhone,
      redeemedAt: redeemedAt ?? this.redeemedAt,
      redeemedByUserId: redeemedByUserId ?? this.redeemedByUserId,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt,
    );
  }
}

