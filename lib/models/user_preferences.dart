class UserPreferences {
  final bool receivePushNotifications;
  final bool alertNewRides;
  final bool remindUpcomingRide;
  final bool hideIdentityInReviews;
  final bool emailSummaries;

  const UserPreferences({
    this.receivePushNotifications = true,
    this.alertNewRides = true,
    this.remindUpcomingRide = true,
    this.hideIdentityInReviews = false,
    this.emailSummaries = true,
  });

  factory UserPreferences.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const UserPreferences();
    }

    return UserPreferences(
      receivePushNotifications:
          map['receivePushNotifications'] as bool? ?? true,
      alertNewRides: map['alertNewRides'] as bool? ?? true,
      remindUpcomingRide: map['remindUpcomingRide'] as bool? ?? true,
      hideIdentityInReviews: map['hideIdentityInReviews'] as bool? ?? false,
      emailSummaries: map['emailSummaries'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'receivePushNotifications': receivePushNotifications,
      'alertNewRides': alertNewRides,
      'remindUpcomingRide': remindUpcomingRide,
      'hideIdentityInReviews': hideIdentityInReviews,
      'emailSummaries': emailSummaries,
    };
  }

  UserPreferences copyWith({
    bool? receivePushNotifications,
    bool? alertNewRides,
    bool? remindUpcomingRide,
    bool? hideIdentityInReviews,
    bool? emailSummaries,
  }) {
    return UserPreferences(
      receivePushNotifications:
          receivePushNotifications ?? this.receivePushNotifications,
      alertNewRides: alertNewRides ?? this.alertNewRides,
      remindUpcomingRide: remindUpcomingRide ?? this.remindUpcomingRide,
      hideIdentityInReviews:
          hideIdentityInReviews ?? this.hideIdentityInReviews,
      emailSummaries: emailSummaries ?? this.emailSummaries,
    );
  }
}
