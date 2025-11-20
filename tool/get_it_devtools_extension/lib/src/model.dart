class RegistrationInfo {
  final String type;
  final String? instanceName;
  final String scopeName;
  final String registrationType;
  final bool isAsync;
  final bool isReady;
  final bool isCreated;
  final String? instanceDetails;

  RegistrationInfo({
    required this.type,
    this.instanceName,
    required this.scopeName,
    required this.registrationType,
    required this.isAsync,
    required this.isReady,
    required this.isCreated,
    this.instanceDetails,
  });

  factory RegistrationInfo.fromJson(Map<String, dynamic> json) {
    return RegistrationInfo(
      type: json['type'] as String,
      instanceName: json['instanceName'] as String?,
      scopeName: json['scopeName'] as String,
      registrationType: json['registrationType'] as String,
      isAsync: json['isAsync'] as bool,
      isReady: json['isReady'] as bool,
      isCreated: json['isCreated'] as bool,
      instanceDetails: json['instanceDetails'] as String?,
    );
  }
}
