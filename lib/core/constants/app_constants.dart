// Firestore collection names
class Collections {
  static const organizations = 'organizations';
  static const users = 'users';
  static const events = 'events';
  static const attendees = 'attendees';
  static const invitations = 'invitations';
  static const checkIns = 'checkIns';
  static const subscriptions = 'subscriptions';
  static const promotions = 'promotions';
  static const vouchers = 'vouchers';
}

// Subscription plans
enum SubscriptionPlan {
  free('Free', maxEvents: 1, maxAttendeesPerEvent: 50, maxTeamMembers: 1,
       csvImport: false, emailEnabled: false, customDomain: false,
       analytics: false, removeBranding: false,
       aiEnabled: false, maxAiUsagesPerMonth: 0,
       monthlyPrice: 0, yearlyPrice: 0,
       maxActivePromotions: 1, maxVouchersPerPromotion: 25,
       canOnlinePromotionPayment: false),
  pro('Pro', maxEvents: 10, maxAttendeesPerEvent: 500, maxTeamMembers: 5,
      csvImport: true, emailEnabled: true, customDomain: false,
      analytics: false, removeBranding: true,
      aiEnabled: true, maxAiUsagesPerMonth: 5,
      monthlyPrice: 29, yearlyPrice: 249,
      maxActivePromotions: 5, maxVouchersPerPromotion: 250,
      canOnlinePromotionPayment: true),
  business('Business', maxEvents: -1, maxAttendeesPerEvent: -1, maxTeamMembers: -1,
           csvImport: true, emailEnabled: true, customDomain: false,
           analytics: true, removeBranding: true,
           aiEnabled: true, maxAiUsagesPerMonth: -1,
           monthlyPrice: 79, yearlyPrice: 699,
           maxActivePromotions: -1, maxVouchersPerPromotion: -1,
           canOnlinePromotionPayment: true);

  final String label;
  final int maxEvents;           // -1 = unlimited
  final int maxAttendeesPerEvent; // -1 = unlimited
  final int maxTeamMembers;      // -1 = unlimited
  final bool csvImport;
  final bool emailEnabled;
  final bool customDomain;
  final bool analytics;
  final bool removeBranding;
  final bool aiEnabled;
  final int maxAiUsagesPerMonth; // -1 = unlimited
  final int monthlyPrice;
  final int yearlyPrice;
  final int maxActivePromotions; // -1 = unlimited
  final int maxVouchersPerPromotion; // -1 = unlimited
  final bool canOnlinePromotionPayment;
  
  const SubscriptionPlan(this.label, {
    required this.maxEvents,
    required this.maxAttendeesPerEvent,
    required this.maxTeamMembers,
    required this.csvImport,
    required this.emailEnabled,
    required this.customDomain,
    required this.analytics,
    required this.removeBranding,
    required this.aiEnabled,
    required this.maxAiUsagesPerMonth,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.maxActivePromotions,
    required this.maxVouchersPerPromotion,
    required this.canOnlinePromotionPayment,
  });
  
  bool get isUnlimitedEvents => maxEvents == -1;
  bool get isUnlimitedAttendees => maxAttendeesPerEvent == -1;
  bool get isUnlimitedTeam => maxTeamMembers == -1;
  bool get isUnlimitedAi => maxAiUsagesPerMonth == -1;
  bool get isUnlimitedPromotions => maxActivePromotions == -1;
  bool get isUnlimitedVouchers => maxVouchersPerPromotion == -1;
  bool get isFree => this == SubscriptionPlan.free;
  bool get isPaid => this != SubscriptionPlan.free;
}

// User roles within an organization
enum OrgRole {
  owner('Owner'),
  admin('Admin'),
  staff('Staff'),
  viewer('Viewer');

  final String label;
  const OrgRole(this.label);
  
  bool get canManageOrg => this == owner;
  bool get canManageEvents => this == owner || this == admin;
  bool get canManageAttendees => this == owner || this == admin;
  bool get canCheckIn => this == owner || this == admin || this == staff;
  bool get canSendEmails => this == owner || this == admin;
  bool get isReadOnly => this == viewer;
}

// Event status
enum EventStatus {
  draft('Draft'),
  published('Published'),
  canceled('Canceled'),
  completed('Completed');

  final String label;
  const EventStatus(this.label);
}

// Registration status
enum RegistrationStatus {
  pending('Pending'),
  confirmed('Confirmed'),
  canceled('Canceled'),
  waitlist('Waitlist');

  final String label;
  const RegistrationStatus(this.label);
}

// Check-in status
enum CheckInStatus {
  notCheckedIn('Not Checked In'),
  checkedIn('Checked In');

  final String label;
  const CheckInStatus(this.label);
}

// Offer / Promotion type
enum OfferType {
  twoForOne('2x1 (Due per uno)'),
  percentageDiscount('Sconto percentuale'),
  fixedDiscount('Sconto fisso (€)'),
  specialPrice('Prezzo promozionale fisso'),
  freeAccess('Ingresso omaggio'),
  custom('Offerta personalizzata');

  final String label;
  const OfferType(this.label);
}

// Promotion payment method
enum PromotionPaymentMethod {
  atVenue('Paga in struttura'),
  online('Paga online (Stripe)'),
  free('Gratuito / Non richiesto');

  final String label;
  const PromotionPaymentMethod(this.label);
}

// Promotion campaign status
enum PromotionStatus {
  active('Attiva'),
  paused('In pausa'),
  expired('Scaduta');

  final String label;
  const PromotionStatus(this.label);
}

// Voucher status
enum VoucherStatus {
  available('Disponibile'),
  claimed('Attivato da cliente'),
  redeemed('Riscattato'),
  cancelled('Annullato');

  final String label;
  const VoucherStatus(this.label);
}

// Voucher payment status
enum VoucherPaymentStatus {
  pending('In attesa'),
  paidAtVenue('Pagato in struttura'),
  paidOnline('Pagato online'),
  notRequired('Non richiesto');

  final String label;
  const VoucherPaymentStatus(this.label);
}

