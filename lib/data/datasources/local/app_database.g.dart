// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalSettingsTable extends LocalSettings
    with TableInfo<$LocalSettingsTable, LocalSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  LocalSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalSettingsTable createAlias(String alias) {
    return $LocalSettingsTable(attachedDatabase, alias);
  }
}

class LocalSetting extends DataClass implements Insertable<LocalSetting> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const LocalSetting({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalSettingsCompanion toCompanion(bool nullToAbsent) {
    return LocalSettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalSetting copyWith({String? key, String? value, DateTime? updatedAt}) =>
      LocalSetting(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LocalSetting copyWithCompanion(LocalSettingsCompanion data) {
    return LocalSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSetting(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSetting &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class LocalSettingsCompanion extends UpdateCompanion<LocalSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSettingsCompanion.insert({
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<LocalSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalUserProfilesTable extends LocalUserProfiles
    with TableInfo<$LocalUserProfilesTable, LocalUserProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalUserProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstNameMeta = const VerificationMeta(
    'firstName',
  );
  @override
  late final GeneratedColumn<String> firstName = GeneratedColumn<String>(
    'first_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _middleNameMeta = const VerificationMeta(
    'middleName',
  );
  @override
  late final GeneratedColumn<String> middleName = GeneratedColumn<String>(
    'middle_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastNameMeta = const VerificationMeta(
    'lastName',
  );
  @override
  late final GeneratedColumn<String> lastName = GeneratedColumn<String>(
    'last_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    email,
    role,
    firstName,
    middleName,
    lastName,
    status,
    isArchived,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_user_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalUserProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('first_name')) {
      context.handle(
        _firstNameMeta,
        firstName.isAcceptableOrUnknown(data['first_name']!, _firstNameMeta),
      );
    }
    if (data.containsKey('middle_name')) {
      context.handle(
        _middleNameMeta,
        middleName.isAcceptableOrUnknown(data['middle_name']!, _middleNameMeta),
      );
    }
    if (data.containsKey('last_name')) {
      context.handle(
        _lastNameMeta,
        lastName.isAcceptableOrUnknown(data['last_name']!, _lastNameMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalUserProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalUserProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      firstName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}first_name'],
      )!,
      middleName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}middle_name'],
      ),
      lastName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_name'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalUserProfilesTable createAlias(String alias) {
    return $LocalUserProfilesTable(attachedDatabase, alias);
  }
}

class LocalUserProfile extends DataClass
    implements Insertable<LocalUserProfile> {
  final String id;
  final String email;
  final String role;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String status;
  final bool isArchived;
  final DateTime updatedAt;
  const LocalUserProfile({
    required this.id,
    required this.email,
    required this.role,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.status,
    required this.isArchived,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['email'] = Variable<String>(email);
    map['role'] = Variable<String>(role);
    map['first_name'] = Variable<String>(firstName);
    if (!nullToAbsent || middleName != null) {
      map['middle_name'] = Variable<String>(middleName);
    }
    map['last_name'] = Variable<String>(lastName);
    map['status'] = Variable<String>(status);
    map['is_archived'] = Variable<bool>(isArchived);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalUserProfilesCompanion toCompanion(bool nullToAbsent) {
    return LocalUserProfilesCompanion(
      id: Value(id),
      email: Value(email),
      role: Value(role),
      firstName: Value(firstName),
      middleName: middleName == null && nullToAbsent
          ? const Value.absent()
          : Value(middleName),
      lastName: Value(lastName),
      status: Value(status),
      isArchived: Value(isArchived),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalUserProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalUserProfile(
      id: serializer.fromJson<String>(json['id']),
      email: serializer.fromJson<String>(json['email']),
      role: serializer.fromJson<String>(json['role']),
      firstName: serializer.fromJson<String>(json['firstName']),
      middleName: serializer.fromJson<String?>(json['middleName']),
      lastName: serializer.fromJson<String>(json['lastName']),
      status: serializer.fromJson<String>(json['status']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'email': serializer.toJson<String>(email),
      'role': serializer.toJson<String>(role),
      'firstName': serializer.toJson<String>(firstName),
      'middleName': serializer.toJson<String?>(middleName),
      'lastName': serializer.toJson<String>(lastName),
      'status': serializer.toJson<String>(status),
      'isArchived': serializer.toJson<bool>(isArchived),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalUserProfile copyWith({
    String? id,
    String? email,
    String? role,
    String? firstName,
    Value<String?> middleName = const Value.absent(),
    String? lastName,
    String? status,
    bool? isArchived,
    DateTime? updatedAt,
  }) => LocalUserProfile(
    id: id ?? this.id,
    email: email ?? this.email,
    role: role ?? this.role,
    firstName: firstName ?? this.firstName,
    middleName: middleName.present ? middleName.value : this.middleName,
    lastName: lastName ?? this.lastName,
    status: status ?? this.status,
    isArchived: isArchived ?? this.isArchived,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalUserProfile copyWithCompanion(LocalUserProfilesCompanion data) {
    return LocalUserProfile(
      id: data.id.present ? data.id.value : this.id,
      email: data.email.present ? data.email.value : this.email,
      role: data.role.present ? data.role.value : this.role,
      firstName: data.firstName.present ? data.firstName.value : this.firstName,
      middleName: data.middleName.present
          ? data.middleName.value
          : this.middleName,
      lastName: data.lastName.present ? data.lastName.value : this.lastName,
      status: data.status.present ? data.status.value : this.status,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalUserProfile(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('role: $role, ')
          ..write('firstName: $firstName, ')
          ..write('middleName: $middleName, ')
          ..write('lastName: $lastName, ')
          ..write('status: $status, ')
          ..write('isArchived: $isArchived, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    email,
    role,
    firstName,
    middleName,
    lastName,
    status,
    isArchived,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalUserProfile &&
          other.id == this.id &&
          other.email == this.email &&
          other.role == this.role &&
          other.firstName == this.firstName &&
          other.middleName == this.middleName &&
          other.lastName == this.lastName &&
          other.status == this.status &&
          other.isArchived == this.isArchived &&
          other.updatedAt == this.updatedAt);
}

class LocalUserProfilesCompanion extends UpdateCompanion<LocalUserProfile> {
  final Value<String> id;
  final Value<String> email;
  final Value<String> role;
  final Value<String> firstName;
  final Value<String?> middleName;
  final Value<String> lastName;
  final Value<String> status;
  final Value<bool> isArchived;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalUserProfilesCompanion({
    this.id = const Value.absent(),
    this.email = const Value.absent(),
    this.role = const Value.absent(),
    this.firstName = const Value.absent(),
    this.middleName = const Value.absent(),
    this.lastName = const Value.absent(),
    this.status = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalUserProfilesCompanion.insert({
    required String id,
    required String email,
    required String role,
    this.firstName = const Value.absent(),
    this.middleName = const Value.absent(),
    this.lastName = const Value.absent(),
    this.status = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       email = Value(email),
       role = Value(role);
  static Insertable<LocalUserProfile> custom({
    Expression<String>? id,
    Expression<String>? email,
    Expression<String>? role,
    Expression<String>? firstName,
    Expression<String>? middleName,
    Expression<String>? lastName,
    Expression<String>? status,
    Expression<bool>? isArchived,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (email != null) 'email': email,
      if (role != null) 'role': role,
      if (firstName != null) 'first_name': firstName,
      if (middleName != null) 'middle_name': middleName,
      if (lastName != null) 'last_name': lastName,
      if (status != null) 'status': status,
      if (isArchived != null) 'is_archived': isArchived,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalUserProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? email,
    Value<String>? role,
    Value<String>? firstName,
    Value<String?>? middleName,
    Value<String>? lastName,
    Value<String>? status,
    Value<bool>? isArchived,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalUserProfilesCompanion(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      status: status ?? this.status,
      isArchived: isArchived ?? this.isArchived,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (firstName.present) {
      map['first_name'] = Variable<String>(firstName.value);
    }
    if (middleName.present) {
      map['middle_name'] = Variable<String>(middleName.value);
    }
    if (lastName.present) {
      map['last_name'] = Variable<String>(lastName.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalUserProfilesCompanion(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('role: $role, ')
          ..write('firstName: $firstName, ')
          ..write('middleName: $middleName, ')
          ..write('lastName: $lastName, ')
          ..write('status: $status, ')
          ..write('isArchived: $isArchived, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSubjectsTable extends LocalSubjects
    with TableInfo<$LocalSubjectsTable, LocalSubject> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSubjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectCodeMeta = const VerificationMeta(
    'subjectCode',
  );
  @override
  late final GeneratedColumn<String> subjectCode = GeneratedColumn<String>(
    'subject_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectNameMeta = const VerificationMeta(
    'subjectName',
  );
  @override
  late final GeneratedColumn<String> subjectName = GeneratedColumn<String>(
    'subject_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gradeLevelMeta = const VerificationMeta(
    'gradeLevel',
  );
  @override
  late final GeneratedColumn<int> gradeLevel = GeneratedColumn<int>(
    'grade_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectCode,
    subjectName,
    gradeLevel,
    isArchived,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_subjects';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSubject> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('subject_code')) {
      context.handle(
        _subjectCodeMeta,
        subjectCode.isAcceptableOrUnknown(
          data['subject_code']!,
          _subjectCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectCodeMeta);
    }
    if (data.containsKey('subject_name')) {
      context.handle(
        _subjectNameMeta,
        subjectName.isAcceptableOrUnknown(
          data['subject_name']!,
          _subjectNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectNameMeta);
    }
    if (data.containsKey('grade_level')) {
      context.handle(
        _gradeLevelMeta,
        gradeLevel.isAcceptableOrUnknown(data['grade_level']!, _gradeLevelMeta),
      );
    } else if (isInserting) {
      context.missing(_gradeLevelMeta);
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSubject map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSubject(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      subjectCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_code'],
      )!,
      subjectName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_name'],
      )!,
      gradeLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grade_level'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
    );
  }

  @override
  $LocalSubjectsTable createAlias(String alias) {
    return $LocalSubjectsTable(attachedDatabase, alias);
  }
}

class LocalSubject extends DataClass implements Insertable<LocalSubject> {
  final String id;
  final String subjectCode;
  final String subjectName;
  final int gradeLevel;
  final bool isArchived;
  const LocalSubject({
    required this.id,
    required this.subjectCode,
    required this.subjectName,
    required this.gradeLevel,
    required this.isArchived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['subject_code'] = Variable<String>(subjectCode);
    map['subject_name'] = Variable<String>(subjectName);
    map['grade_level'] = Variable<int>(gradeLevel);
    map['is_archived'] = Variable<bool>(isArchived);
    return map;
  }

  LocalSubjectsCompanion toCompanion(bool nullToAbsent) {
    return LocalSubjectsCompanion(
      id: Value(id),
      subjectCode: Value(subjectCode),
      subjectName: Value(subjectName),
      gradeLevel: Value(gradeLevel),
      isArchived: Value(isArchived),
    );
  }

  factory LocalSubject.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSubject(
      id: serializer.fromJson<String>(json['id']),
      subjectCode: serializer.fromJson<String>(json['subjectCode']),
      subjectName: serializer.fromJson<String>(json['subjectName']),
      gradeLevel: serializer.fromJson<int>(json['gradeLevel']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'subjectCode': serializer.toJson<String>(subjectCode),
      'subjectName': serializer.toJson<String>(subjectName),
      'gradeLevel': serializer.toJson<int>(gradeLevel),
      'isArchived': serializer.toJson<bool>(isArchived),
    };
  }

  LocalSubject copyWith({
    String? id,
    String? subjectCode,
    String? subjectName,
    int? gradeLevel,
    bool? isArchived,
  }) => LocalSubject(
    id: id ?? this.id,
    subjectCode: subjectCode ?? this.subjectCode,
    subjectName: subjectName ?? this.subjectName,
    gradeLevel: gradeLevel ?? this.gradeLevel,
    isArchived: isArchived ?? this.isArchived,
  );
  LocalSubject copyWithCompanion(LocalSubjectsCompanion data) {
    return LocalSubject(
      id: data.id.present ? data.id.value : this.id,
      subjectCode: data.subjectCode.present
          ? data.subjectCode.value
          : this.subjectCode,
      subjectName: data.subjectName.present
          ? data.subjectName.value
          : this.subjectName,
      gradeLevel: data.gradeLevel.present
          ? data.gradeLevel.value
          : this.gradeLevel,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSubject(')
          ..write('id: $id, ')
          ..write('subjectCode: $subjectCode, ')
          ..write('subjectName: $subjectName, ')
          ..write('gradeLevel: $gradeLevel, ')
          ..write('isArchived: $isArchived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, subjectCode, subjectName, gradeLevel, isArchived);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSubject &&
          other.id == this.id &&
          other.subjectCode == this.subjectCode &&
          other.subjectName == this.subjectName &&
          other.gradeLevel == this.gradeLevel &&
          other.isArchived == this.isArchived);
}

class LocalSubjectsCompanion extends UpdateCompanion<LocalSubject> {
  final Value<String> id;
  final Value<String> subjectCode;
  final Value<String> subjectName;
  final Value<int> gradeLevel;
  final Value<bool> isArchived;
  final Value<int> rowid;
  const LocalSubjectsCompanion({
    this.id = const Value.absent(),
    this.subjectCode = const Value.absent(),
    this.subjectName = const Value.absent(),
    this.gradeLevel = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSubjectsCompanion.insert({
    required String id,
    required String subjectCode,
    required String subjectName,
    required int gradeLevel,
    this.isArchived = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       subjectCode = Value(subjectCode),
       subjectName = Value(subjectName),
       gradeLevel = Value(gradeLevel);
  static Insertable<LocalSubject> custom({
    Expression<String>? id,
    Expression<String>? subjectCode,
    Expression<String>? subjectName,
    Expression<int>? gradeLevel,
    Expression<bool>? isArchived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectCode != null) 'subject_code': subjectCode,
      if (subjectName != null) 'subject_name': subjectName,
      if (gradeLevel != null) 'grade_level': gradeLevel,
      if (isArchived != null) 'is_archived': isArchived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSubjectsCompanion copyWith({
    Value<String>? id,
    Value<String>? subjectCode,
    Value<String>? subjectName,
    Value<int>? gradeLevel,
    Value<bool>? isArchived,
    Value<int>? rowid,
  }) {
    return LocalSubjectsCompanion(
      id: id ?? this.id,
      subjectCode: subjectCode ?? this.subjectCode,
      subjectName: subjectName ?? this.subjectName,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      isArchived: isArchived ?? this.isArchived,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (subjectCode.present) {
      map['subject_code'] = Variable<String>(subjectCode.value);
    }
    if (subjectName.present) {
      map['subject_name'] = Variable<String>(subjectName.value);
    }
    if (gradeLevel.present) {
      map['grade_level'] = Variable<int>(gradeLevel.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSubjectsCompanion(')
          ..write('id: $id, ')
          ..write('subjectCode: $subjectCode, ')
          ..write('subjectName: $subjectName, ')
          ..write('gradeLevel: $gradeLevel, ')
          ..write('isArchived: $isArchived, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSectionsTable extends LocalSections
    with TableInfo<$LocalSectionsTable, LocalSection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sectionNameMeta = const VerificationMeta(
    'sectionName',
  );
  @override
  late final GeneratedColumn<String> sectionName = GeneratedColumn<String>(
    'section_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gradeLevelMeta = const VerificationMeta(
    'gradeLevel',
  );
  @override
  late final GeneratedColumn<int> gradeLevel = GeneratedColumn<int>(
    'grade_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schoolYearMeta = const VerificationMeta(
    'schoolYear',
  );
  @override
  late final GeneratedColumn<String> schoolYear = GeneratedColumn<String>(
    'school_year',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('2026-2027'),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sectionName,
    gradeLevel,
    schoolYear,
    isArchived,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_sections';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('section_name')) {
      context.handle(
        _sectionNameMeta,
        sectionName.isAcceptableOrUnknown(
          data['section_name']!,
          _sectionNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sectionNameMeta);
    }
    if (data.containsKey('grade_level')) {
      context.handle(
        _gradeLevelMeta,
        gradeLevel.isAcceptableOrUnknown(data['grade_level']!, _gradeLevelMeta),
      );
    } else if (isInserting) {
      context.missing(_gradeLevelMeta);
    }
    if (data.containsKey('school_year')) {
      context.handle(
        _schoolYearMeta,
        schoolYear.isAcceptableOrUnknown(data['school_year']!, _schoolYearMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSection(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sectionName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_name'],
      )!,
      gradeLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grade_level'],
      )!,
      schoolYear: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}school_year'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
    );
  }

  @override
  $LocalSectionsTable createAlias(String alias) {
    return $LocalSectionsTable(attachedDatabase, alias);
  }
}

class LocalSection extends DataClass implements Insertable<LocalSection> {
  final String id;
  final String sectionName;
  final int gradeLevel;
  final String schoolYear;
  final bool isArchived;
  const LocalSection({
    required this.id,
    required this.sectionName,
    required this.gradeLevel,
    required this.schoolYear,
    required this.isArchived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['section_name'] = Variable<String>(sectionName);
    map['grade_level'] = Variable<int>(gradeLevel);
    map['school_year'] = Variable<String>(schoolYear);
    map['is_archived'] = Variable<bool>(isArchived);
    return map;
  }

  LocalSectionsCompanion toCompanion(bool nullToAbsent) {
    return LocalSectionsCompanion(
      id: Value(id),
      sectionName: Value(sectionName),
      gradeLevel: Value(gradeLevel),
      schoolYear: Value(schoolYear),
      isArchived: Value(isArchived),
    );
  }

  factory LocalSection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSection(
      id: serializer.fromJson<String>(json['id']),
      sectionName: serializer.fromJson<String>(json['sectionName']),
      gradeLevel: serializer.fromJson<int>(json['gradeLevel']),
      schoolYear: serializer.fromJson<String>(json['schoolYear']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sectionName': serializer.toJson<String>(sectionName),
      'gradeLevel': serializer.toJson<int>(gradeLevel),
      'schoolYear': serializer.toJson<String>(schoolYear),
      'isArchived': serializer.toJson<bool>(isArchived),
    };
  }

  LocalSection copyWith({
    String? id,
    String? sectionName,
    int? gradeLevel,
    String? schoolYear,
    bool? isArchived,
  }) => LocalSection(
    id: id ?? this.id,
    sectionName: sectionName ?? this.sectionName,
    gradeLevel: gradeLevel ?? this.gradeLevel,
    schoolYear: schoolYear ?? this.schoolYear,
    isArchived: isArchived ?? this.isArchived,
  );
  LocalSection copyWithCompanion(LocalSectionsCompanion data) {
    return LocalSection(
      id: data.id.present ? data.id.value : this.id,
      sectionName: data.sectionName.present
          ? data.sectionName.value
          : this.sectionName,
      gradeLevel: data.gradeLevel.present
          ? data.gradeLevel.value
          : this.gradeLevel,
      schoolYear: data.schoolYear.present
          ? data.schoolYear.value
          : this.schoolYear,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSection(')
          ..write('id: $id, ')
          ..write('sectionName: $sectionName, ')
          ..write('gradeLevel: $gradeLevel, ')
          ..write('schoolYear: $schoolYear, ')
          ..write('isArchived: $isArchived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sectionName, gradeLevel, schoolYear, isArchived);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSection &&
          other.id == this.id &&
          other.sectionName == this.sectionName &&
          other.gradeLevel == this.gradeLevel &&
          other.schoolYear == this.schoolYear &&
          other.isArchived == this.isArchived);
}

class LocalSectionsCompanion extends UpdateCompanion<LocalSection> {
  final Value<String> id;
  final Value<String> sectionName;
  final Value<int> gradeLevel;
  final Value<String> schoolYear;
  final Value<bool> isArchived;
  final Value<int> rowid;
  const LocalSectionsCompanion({
    this.id = const Value.absent(),
    this.sectionName = const Value.absent(),
    this.gradeLevel = const Value.absent(),
    this.schoolYear = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSectionsCompanion.insert({
    required String id,
    required String sectionName,
    required int gradeLevel,
    this.schoolYear = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sectionName = Value(sectionName),
       gradeLevel = Value(gradeLevel);
  static Insertable<LocalSection> custom({
    Expression<String>? id,
    Expression<String>? sectionName,
    Expression<int>? gradeLevel,
    Expression<String>? schoolYear,
    Expression<bool>? isArchived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sectionName != null) 'section_name': sectionName,
      if (gradeLevel != null) 'grade_level': gradeLevel,
      if (schoolYear != null) 'school_year': schoolYear,
      if (isArchived != null) 'is_archived': isArchived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSectionsCompanion copyWith({
    Value<String>? id,
    Value<String>? sectionName,
    Value<int>? gradeLevel,
    Value<String>? schoolYear,
    Value<bool>? isArchived,
    Value<int>? rowid,
  }) {
    return LocalSectionsCompanion(
      id: id ?? this.id,
      sectionName: sectionName ?? this.sectionName,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      schoolYear: schoolYear ?? this.schoolYear,
      isArchived: isArchived ?? this.isArchived,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sectionName.present) {
      map['section_name'] = Variable<String>(sectionName.value);
    }
    if (gradeLevel.present) {
      map['grade_level'] = Variable<int>(gradeLevel.value);
    }
    if (schoolYear.present) {
      map['school_year'] = Variable<String>(schoolYear.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSectionsCompanion(')
          ..write('id: $id, ')
          ..write('sectionName: $sectionName, ')
          ..write('gradeLevel: $gradeLevel, ')
          ..write('schoolYear: $schoolYear, ')
          ..write('isArchived: $isArchived, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSubjectOfferingsTable extends LocalSubjectOfferings
    with TableInfo<$LocalSubjectOfferingsTable, LocalSubjectOffering> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSubjectOfferingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _teacherIdMeta = const VerificationMeta(
    'teacherId',
  );
  @override
  late final GeneratedColumn<String> teacherId = GeneratedColumn<String>(
    'teacher_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sectionIdMeta = const VerificationMeta(
    'sectionId',
  );
  @override
  late final GeneratedColumn<String> sectionId = GeneratedColumn<String>(
    'section_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectNameMeta = const VerificationMeta(
    'subjectName',
  );
  @override
  late final GeneratedColumn<String> subjectName = GeneratedColumn<String>(
    'subject_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sectionNameMeta = const VerificationMeta(
    'sectionName',
  );
  @override
  late final GeneratedColumn<String> sectionName = GeneratedColumn<String>(
    'section_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gradeLevelMeta = const VerificationMeta(
    'gradeLevel',
  );
  @override
  late final GeneratedColumn<int> gradeLevel = GeneratedColumn<int>(
    'grade_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wwWeightMeta = const VerificationMeta(
    'wwWeight',
  );
  @override
  late final GeneratedColumn<double> wwWeight = GeneratedColumn<double>(
    'ww_weight',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(20.0),
  );
  static const VerificationMeta _ptWeightMeta = const VerificationMeta(
    'ptWeight',
  );
  @override
  late final GeneratedColumn<double> ptWeight = GeneratedColumn<double>(
    'pt_weight',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(50.0),
  );
  static const VerificationMeta _exWeightMeta = const VerificationMeta(
    'exWeight',
  );
  @override
  late final GeneratedColumn<double> exWeight = GeneratedColumn<double>(
    'ex_weight',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(30.0),
  );
  static const VerificationMeta _schoolYearMeta = const VerificationMeta(
    'schoolYear',
  );
  @override
  late final GeneratedColumn<String> schoolYear = GeneratedColumn<String>(
    'school_year',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('2026-2027'),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    teacherId,
    subjectId,
    sectionId,
    subjectName,
    sectionName,
    gradeLevel,
    wwWeight,
    ptWeight,
    exWeight,
    schoolYear,
    isArchived,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_subject_offerings';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSubjectOffering> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('teacher_id')) {
      context.handle(
        _teacherIdMeta,
        teacherId.isAcceptableOrUnknown(data['teacher_id']!, _teacherIdMeta),
      );
    } else if (isInserting) {
      context.missing(_teacherIdMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('section_id')) {
      context.handle(
        _sectionIdMeta,
        sectionId.isAcceptableOrUnknown(data['section_id']!, _sectionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sectionIdMeta);
    }
    if (data.containsKey('subject_name')) {
      context.handle(
        _subjectNameMeta,
        subjectName.isAcceptableOrUnknown(
          data['subject_name']!,
          _subjectNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectNameMeta);
    }
    if (data.containsKey('section_name')) {
      context.handle(
        _sectionNameMeta,
        sectionName.isAcceptableOrUnknown(
          data['section_name']!,
          _sectionNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sectionNameMeta);
    }
    if (data.containsKey('grade_level')) {
      context.handle(
        _gradeLevelMeta,
        gradeLevel.isAcceptableOrUnknown(data['grade_level']!, _gradeLevelMeta),
      );
    } else if (isInserting) {
      context.missing(_gradeLevelMeta);
    }
    if (data.containsKey('ww_weight')) {
      context.handle(
        _wwWeightMeta,
        wwWeight.isAcceptableOrUnknown(data['ww_weight']!, _wwWeightMeta),
      );
    }
    if (data.containsKey('pt_weight')) {
      context.handle(
        _ptWeightMeta,
        ptWeight.isAcceptableOrUnknown(data['pt_weight']!, _ptWeightMeta),
      );
    }
    if (data.containsKey('ex_weight')) {
      context.handle(
        _exWeightMeta,
        exWeight.isAcceptableOrUnknown(data['ex_weight']!, _exWeightMeta),
      );
    }
    if (data.containsKey('school_year')) {
      context.handle(
        _schoolYearMeta,
        schoolYear.isAcceptableOrUnknown(data['school_year']!, _schoolYearMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSubjectOffering map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSubjectOffering(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      teacherId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}teacher_id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      )!,
      sectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_id'],
      )!,
      subjectName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_name'],
      )!,
      sectionName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_name'],
      )!,
      gradeLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grade_level'],
      )!,
      wwWeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ww_weight'],
      )!,
      ptWeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pt_weight'],
      )!,
      exWeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ex_weight'],
      )!,
      schoolYear: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}school_year'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
    );
  }

  @override
  $LocalSubjectOfferingsTable createAlias(String alias) {
    return $LocalSubjectOfferingsTable(attachedDatabase, alias);
  }
}

class LocalSubjectOffering extends DataClass
    implements Insertable<LocalSubjectOffering> {
  final String id;
  final String teacherId;
  final String subjectId;
  final String sectionId;
  final String subjectName;
  final String sectionName;
  final int gradeLevel;
  final double wwWeight;
  final double ptWeight;
  final double exWeight;
  final String schoolYear;
  final bool isArchived;
  const LocalSubjectOffering({
    required this.id,
    required this.teacherId,
    required this.subjectId,
    required this.sectionId,
    required this.subjectName,
    required this.sectionName,
    required this.gradeLevel,
    required this.wwWeight,
    required this.ptWeight,
    required this.exWeight,
    required this.schoolYear,
    required this.isArchived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['teacher_id'] = Variable<String>(teacherId);
    map['subject_id'] = Variable<String>(subjectId);
    map['section_id'] = Variable<String>(sectionId);
    map['subject_name'] = Variable<String>(subjectName);
    map['section_name'] = Variable<String>(sectionName);
    map['grade_level'] = Variable<int>(gradeLevel);
    map['ww_weight'] = Variable<double>(wwWeight);
    map['pt_weight'] = Variable<double>(ptWeight);
    map['ex_weight'] = Variable<double>(exWeight);
    map['school_year'] = Variable<String>(schoolYear);
    map['is_archived'] = Variable<bool>(isArchived);
    return map;
  }

  LocalSubjectOfferingsCompanion toCompanion(bool nullToAbsent) {
    return LocalSubjectOfferingsCompanion(
      id: Value(id),
      teacherId: Value(teacherId),
      subjectId: Value(subjectId),
      sectionId: Value(sectionId),
      subjectName: Value(subjectName),
      sectionName: Value(sectionName),
      gradeLevel: Value(gradeLevel),
      wwWeight: Value(wwWeight),
      ptWeight: Value(ptWeight),
      exWeight: Value(exWeight),
      schoolYear: Value(schoolYear),
      isArchived: Value(isArchived),
    );
  }

  factory LocalSubjectOffering.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSubjectOffering(
      id: serializer.fromJson<String>(json['id']),
      teacherId: serializer.fromJson<String>(json['teacherId']),
      subjectId: serializer.fromJson<String>(json['subjectId']),
      sectionId: serializer.fromJson<String>(json['sectionId']),
      subjectName: serializer.fromJson<String>(json['subjectName']),
      sectionName: serializer.fromJson<String>(json['sectionName']),
      gradeLevel: serializer.fromJson<int>(json['gradeLevel']),
      wwWeight: serializer.fromJson<double>(json['wwWeight']),
      ptWeight: serializer.fromJson<double>(json['ptWeight']),
      exWeight: serializer.fromJson<double>(json['exWeight']),
      schoolYear: serializer.fromJson<String>(json['schoolYear']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'teacherId': serializer.toJson<String>(teacherId),
      'subjectId': serializer.toJson<String>(subjectId),
      'sectionId': serializer.toJson<String>(sectionId),
      'subjectName': serializer.toJson<String>(subjectName),
      'sectionName': serializer.toJson<String>(sectionName),
      'gradeLevel': serializer.toJson<int>(gradeLevel),
      'wwWeight': serializer.toJson<double>(wwWeight),
      'ptWeight': serializer.toJson<double>(ptWeight),
      'exWeight': serializer.toJson<double>(exWeight),
      'schoolYear': serializer.toJson<String>(schoolYear),
      'isArchived': serializer.toJson<bool>(isArchived),
    };
  }

  LocalSubjectOffering copyWith({
    String? id,
    String? teacherId,
    String? subjectId,
    String? sectionId,
    String? subjectName,
    String? sectionName,
    int? gradeLevel,
    double? wwWeight,
    double? ptWeight,
    double? exWeight,
    String? schoolYear,
    bool? isArchived,
  }) => LocalSubjectOffering(
    id: id ?? this.id,
    teacherId: teacherId ?? this.teacherId,
    subjectId: subjectId ?? this.subjectId,
    sectionId: sectionId ?? this.sectionId,
    subjectName: subjectName ?? this.subjectName,
    sectionName: sectionName ?? this.sectionName,
    gradeLevel: gradeLevel ?? this.gradeLevel,
    wwWeight: wwWeight ?? this.wwWeight,
    ptWeight: ptWeight ?? this.ptWeight,
    exWeight: exWeight ?? this.exWeight,
    schoolYear: schoolYear ?? this.schoolYear,
    isArchived: isArchived ?? this.isArchived,
  );
  LocalSubjectOffering copyWithCompanion(LocalSubjectOfferingsCompanion data) {
    return LocalSubjectOffering(
      id: data.id.present ? data.id.value : this.id,
      teacherId: data.teacherId.present ? data.teacherId.value : this.teacherId,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      sectionId: data.sectionId.present ? data.sectionId.value : this.sectionId,
      subjectName: data.subjectName.present
          ? data.subjectName.value
          : this.subjectName,
      sectionName: data.sectionName.present
          ? data.sectionName.value
          : this.sectionName,
      gradeLevel: data.gradeLevel.present
          ? data.gradeLevel.value
          : this.gradeLevel,
      wwWeight: data.wwWeight.present ? data.wwWeight.value : this.wwWeight,
      ptWeight: data.ptWeight.present ? data.ptWeight.value : this.ptWeight,
      exWeight: data.exWeight.present ? data.exWeight.value : this.exWeight,
      schoolYear: data.schoolYear.present
          ? data.schoolYear.value
          : this.schoolYear,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSubjectOffering(')
          ..write('id: $id, ')
          ..write('teacherId: $teacherId, ')
          ..write('subjectId: $subjectId, ')
          ..write('sectionId: $sectionId, ')
          ..write('subjectName: $subjectName, ')
          ..write('sectionName: $sectionName, ')
          ..write('gradeLevel: $gradeLevel, ')
          ..write('wwWeight: $wwWeight, ')
          ..write('ptWeight: $ptWeight, ')
          ..write('exWeight: $exWeight, ')
          ..write('schoolYear: $schoolYear, ')
          ..write('isArchived: $isArchived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    teacherId,
    subjectId,
    sectionId,
    subjectName,
    sectionName,
    gradeLevel,
    wwWeight,
    ptWeight,
    exWeight,
    schoolYear,
    isArchived,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSubjectOffering &&
          other.id == this.id &&
          other.teacherId == this.teacherId &&
          other.subjectId == this.subjectId &&
          other.sectionId == this.sectionId &&
          other.subjectName == this.subjectName &&
          other.sectionName == this.sectionName &&
          other.gradeLevel == this.gradeLevel &&
          other.wwWeight == this.wwWeight &&
          other.ptWeight == this.ptWeight &&
          other.exWeight == this.exWeight &&
          other.schoolYear == this.schoolYear &&
          other.isArchived == this.isArchived);
}

class LocalSubjectOfferingsCompanion
    extends UpdateCompanion<LocalSubjectOffering> {
  final Value<String> id;
  final Value<String> teacherId;
  final Value<String> subjectId;
  final Value<String> sectionId;
  final Value<String> subjectName;
  final Value<String> sectionName;
  final Value<int> gradeLevel;
  final Value<double> wwWeight;
  final Value<double> ptWeight;
  final Value<double> exWeight;
  final Value<String> schoolYear;
  final Value<bool> isArchived;
  final Value<int> rowid;
  const LocalSubjectOfferingsCompanion({
    this.id = const Value.absent(),
    this.teacherId = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.subjectName = const Value.absent(),
    this.sectionName = const Value.absent(),
    this.gradeLevel = const Value.absent(),
    this.wwWeight = const Value.absent(),
    this.ptWeight = const Value.absent(),
    this.exWeight = const Value.absent(),
    this.schoolYear = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSubjectOfferingsCompanion.insert({
    required String id,
    required String teacherId,
    required String subjectId,
    required String sectionId,
    required String subjectName,
    required String sectionName,
    required int gradeLevel,
    this.wwWeight = const Value.absent(),
    this.ptWeight = const Value.absent(),
    this.exWeight = const Value.absent(),
    this.schoolYear = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       teacherId = Value(teacherId),
       subjectId = Value(subjectId),
       sectionId = Value(sectionId),
       subjectName = Value(subjectName),
       sectionName = Value(sectionName),
       gradeLevel = Value(gradeLevel);
  static Insertable<LocalSubjectOffering> custom({
    Expression<String>? id,
    Expression<String>? teacherId,
    Expression<String>? subjectId,
    Expression<String>? sectionId,
    Expression<String>? subjectName,
    Expression<String>? sectionName,
    Expression<int>? gradeLevel,
    Expression<double>? wwWeight,
    Expression<double>? ptWeight,
    Expression<double>? exWeight,
    Expression<String>? schoolYear,
    Expression<bool>? isArchived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (teacherId != null) 'teacher_id': teacherId,
      if (subjectId != null) 'subject_id': subjectId,
      if (sectionId != null) 'section_id': sectionId,
      if (subjectName != null) 'subject_name': subjectName,
      if (sectionName != null) 'section_name': sectionName,
      if (gradeLevel != null) 'grade_level': gradeLevel,
      if (wwWeight != null) 'ww_weight': wwWeight,
      if (ptWeight != null) 'pt_weight': ptWeight,
      if (exWeight != null) 'ex_weight': exWeight,
      if (schoolYear != null) 'school_year': schoolYear,
      if (isArchived != null) 'is_archived': isArchived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSubjectOfferingsCompanion copyWith({
    Value<String>? id,
    Value<String>? teacherId,
    Value<String>? subjectId,
    Value<String>? sectionId,
    Value<String>? subjectName,
    Value<String>? sectionName,
    Value<int>? gradeLevel,
    Value<double>? wwWeight,
    Value<double>? ptWeight,
    Value<double>? exWeight,
    Value<String>? schoolYear,
    Value<bool>? isArchived,
    Value<int>? rowid,
  }) {
    return LocalSubjectOfferingsCompanion(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      subjectId: subjectId ?? this.subjectId,
      sectionId: sectionId ?? this.sectionId,
      subjectName: subjectName ?? this.subjectName,
      sectionName: sectionName ?? this.sectionName,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      wwWeight: wwWeight ?? this.wwWeight,
      ptWeight: ptWeight ?? this.ptWeight,
      exWeight: exWeight ?? this.exWeight,
      schoolYear: schoolYear ?? this.schoolYear,
      isArchived: isArchived ?? this.isArchived,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (teacherId.present) {
      map['teacher_id'] = Variable<String>(teacherId.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (sectionId.present) {
      map['section_id'] = Variable<String>(sectionId.value);
    }
    if (subjectName.present) {
      map['subject_name'] = Variable<String>(subjectName.value);
    }
    if (sectionName.present) {
      map['section_name'] = Variable<String>(sectionName.value);
    }
    if (gradeLevel.present) {
      map['grade_level'] = Variable<int>(gradeLevel.value);
    }
    if (wwWeight.present) {
      map['ww_weight'] = Variable<double>(wwWeight.value);
    }
    if (ptWeight.present) {
      map['pt_weight'] = Variable<double>(ptWeight.value);
    }
    if (exWeight.present) {
      map['ex_weight'] = Variable<double>(exWeight.value);
    }
    if (schoolYear.present) {
      map['school_year'] = Variable<String>(schoolYear.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSubjectOfferingsCompanion(')
          ..write('id: $id, ')
          ..write('teacherId: $teacherId, ')
          ..write('subjectId: $subjectId, ')
          ..write('sectionId: $sectionId, ')
          ..write('subjectName: $subjectName, ')
          ..write('sectionName: $sectionName, ')
          ..write('gradeLevel: $gradeLevel, ')
          ..write('wwWeight: $wwWeight, ')
          ..write('ptWeight: $ptWeight, ')
          ..write('exWeight: $exWeight, ')
          ..write('schoolYear: $schoolYear, ')
          ..write('isArchived: $isArchived, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalStudentsTable extends LocalStudents
    with TableInfo<$LocalStudentsTable, LocalStudent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalStudentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _studentIdMeta = const VerificationMeta(
    'studentId',
  );
  @override
  late final GeneratedColumn<String> studentId = GeneratedColumn<String>(
    'student_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lrnMeta = const VerificationMeta('lrn');
  @override
  late final GeneratedColumn<String> lrn = GeneratedColumn<String>(
    'lrn',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rfidUidMeta = const VerificationMeta(
    'rfidUid',
  );
  @override
  late final GeneratedColumn<String> rfidUid = GeneratedColumn<String>(
    'rfid_uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firstNameMeta = const VerificationMeta(
    'firstName',
  );
  @override
  late final GeneratedColumn<String> firstName = GeneratedColumn<String>(
    'first_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _middleNameMeta = const VerificationMeta(
    'middleName',
  );
  @override
  late final GeneratedColumn<String> middleName = GeneratedColumn<String>(
    'middle_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastNameMeta = const VerificationMeta(
    'lastName',
  );
  @override
  late final GeneratedColumn<String> lastName = GeneratedColumn<String>(
    'last_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
    'gender',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unspecified'),
  );
  static const VerificationMeta _departmentOrSectionMeta =
      const VerificationMeta('departmentOrSection');
  @override
  late final GeneratedColumn<String> departmentOrSection =
      GeneratedColumn<String>(
        'department_or_section',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    studentId,
    lrn,
    rfidUid,
    firstName,
    middleName,
    lastName,
    gender,
    departmentOrSection,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_students';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalStudent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('student_id')) {
      context.handle(
        _studentIdMeta,
        studentId.isAcceptableOrUnknown(data['student_id']!, _studentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studentIdMeta);
    }
    if (data.containsKey('lrn')) {
      context.handle(
        _lrnMeta,
        lrn.isAcceptableOrUnknown(data['lrn']!, _lrnMeta),
      );
    }
    if (data.containsKey('rfid_uid')) {
      context.handle(
        _rfidUidMeta,
        rfidUid.isAcceptableOrUnknown(data['rfid_uid']!, _rfidUidMeta),
      );
    }
    if (data.containsKey('first_name')) {
      context.handle(
        _firstNameMeta,
        firstName.isAcceptableOrUnknown(data['first_name']!, _firstNameMeta),
      );
    } else if (isInserting) {
      context.missing(_firstNameMeta);
    }
    if (data.containsKey('middle_name')) {
      context.handle(
        _middleNameMeta,
        middleName.isAcceptableOrUnknown(data['middle_name']!, _middleNameMeta),
      );
    }
    if (data.containsKey('last_name')) {
      context.handle(
        _lastNameMeta,
        lastName.isAcceptableOrUnknown(data['last_name']!, _lastNameMeta),
      );
    } else if (isInserting) {
      context.missing(_lastNameMeta);
    }
    if (data.containsKey('gender')) {
      context.handle(
        _genderMeta,
        gender.isAcceptableOrUnknown(data['gender']!, _genderMeta),
      );
    }
    if (data.containsKey('department_or_section')) {
      context.handle(
        _departmentOrSectionMeta,
        departmentOrSection.isAcceptableOrUnknown(
          data['department_or_section']!,
          _departmentOrSectionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {studentId};
  @override
  LocalStudent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalStudent(
      studentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}student_id'],
      )!,
      lrn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lrn'],
      ),
      rfidUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rfid_uid'],
      ),
      firstName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}first_name'],
      )!,
      middleName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}middle_name'],
      ),
      lastName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_name'],
      )!,
      gender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gender'],
      )!,
      departmentOrSection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}department_or_section'],
      ),
    );
  }

  @override
  $LocalStudentsTable createAlias(String alias) {
    return $LocalStudentsTable(attachedDatabase, alias);
  }
}

class LocalStudent extends DataClass implements Insertable<LocalStudent> {
  final String studentId;
  final String? lrn;
  final String? rfidUid;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String gender;
  final String? departmentOrSection;
  const LocalStudent({
    required this.studentId,
    this.lrn,
    this.rfidUid,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.gender,
    this.departmentOrSection,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['student_id'] = Variable<String>(studentId);
    if (!nullToAbsent || lrn != null) {
      map['lrn'] = Variable<String>(lrn);
    }
    if (!nullToAbsent || rfidUid != null) {
      map['rfid_uid'] = Variable<String>(rfidUid);
    }
    map['first_name'] = Variable<String>(firstName);
    if (!nullToAbsent || middleName != null) {
      map['middle_name'] = Variable<String>(middleName);
    }
    map['last_name'] = Variable<String>(lastName);
    map['gender'] = Variable<String>(gender);
    if (!nullToAbsent || departmentOrSection != null) {
      map['department_or_section'] = Variable<String>(departmentOrSection);
    }
    return map;
  }

  LocalStudentsCompanion toCompanion(bool nullToAbsent) {
    return LocalStudentsCompanion(
      studentId: Value(studentId),
      lrn: lrn == null && nullToAbsent ? const Value.absent() : Value(lrn),
      rfidUid: rfidUid == null && nullToAbsent
          ? const Value.absent()
          : Value(rfidUid),
      firstName: Value(firstName),
      middleName: middleName == null && nullToAbsent
          ? const Value.absent()
          : Value(middleName),
      lastName: Value(lastName),
      gender: Value(gender),
      departmentOrSection: departmentOrSection == null && nullToAbsent
          ? const Value.absent()
          : Value(departmentOrSection),
    );
  }

  factory LocalStudent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalStudent(
      studentId: serializer.fromJson<String>(json['studentId']),
      lrn: serializer.fromJson<String?>(json['lrn']),
      rfidUid: serializer.fromJson<String?>(json['rfidUid']),
      firstName: serializer.fromJson<String>(json['firstName']),
      middleName: serializer.fromJson<String?>(json['middleName']),
      lastName: serializer.fromJson<String>(json['lastName']),
      gender: serializer.fromJson<String>(json['gender']),
      departmentOrSection: serializer.fromJson<String?>(
        json['departmentOrSection'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'studentId': serializer.toJson<String>(studentId),
      'lrn': serializer.toJson<String?>(lrn),
      'rfidUid': serializer.toJson<String?>(rfidUid),
      'firstName': serializer.toJson<String>(firstName),
      'middleName': serializer.toJson<String?>(middleName),
      'lastName': serializer.toJson<String>(lastName),
      'gender': serializer.toJson<String>(gender),
      'departmentOrSection': serializer.toJson<String?>(departmentOrSection),
    };
  }

  LocalStudent copyWith({
    String? studentId,
    Value<String?> lrn = const Value.absent(),
    Value<String?> rfidUid = const Value.absent(),
    String? firstName,
    Value<String?> middleName = const Value.absent(),
    String? lastName,
    String? gender,
    Value<String?> departmentOrSection = const Value.absent(),
  }) => LocalStudent(
    studentId: studentId ?? this.studentId,
    lrn: lrn.present ? lrn.value : this.lrn,
    rfidUid: rfidUid.present ? rfidUid.value : this.rfidUid,
    firstName: firstName ?? this.firstName,
    middleName: middleName.present ? middleName.value : this.middleName,
    lastName: lastName ?? this.lastName,
    gender: gender ?? this.gender,
    departmentOrSection: departmentOrSection.present
        ? departmentOrSection.value
        : this.departmentOrSection,
  );
  LocalStudent copyWithCompanion(LocalStudentsCompanion data) {
    return LocalStudent(
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      lrn: data.lrn.present ? data.lrn.value : this.lrn,
      rfidUid: data.rfidUid.present ? data.rfidUid.value : this.rfidUid,
      firstName: data.firstName.present ? data.firstName.value : this.firstName,
      middleName: data.middleName.present
          ? data.middleName.value
          : this.middleName,
      lastName: data.lastName.present ? data.lastName.value : this.lastName,
      gender: data.gender.present ? data.gender.value : this.gender,
      departmentOrSection: data.departmentOrSection.present
          ? data.departmentOrSection.value
          : this.departmentOrSection,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalStudent(')
          ..write('studentId: $studentId, ')
          ..write('lrn: $lrn, ')
          ..write('rfidUid: $rfidUid, ')
          ..write('firstName: $firstName, ')
          ..write('middleName: $middleName, ')
          ..write('lastName: $lastName, ')
          ..write('gender: $gender, ')
          ..write('departmentOrSection: $departmentOrSection')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    studentId,
    lrn,
    rfidUid,
    firstName,
    middleName,
    lastName,
    gender,
    departmentOrSection,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalStudent &&
          other.studentId == this.studentId &&
          other.lrn == this.lrn &&
          other.rfidUid == this.rfidUid &&
          other.firstName == this.firstName &&
          other.middleName == this.middleName &&
          other.lastName == this.lastName &&
          other.gender == this.gender &&
          other.departmentOrSection == this.departmentOrSection);
}

class LocalStudentsCompanion extends UpdateCompanion<LocalStudent> {
  final Value<String> studentId;
  final Value<String?> lrn;
  final Value<String?> rfidUid;
  final Value<String> firstName;
  final Value<String?> middleName;
  final Value<String> lastName;
  final Value<String> gender;
  final Value<String?> departmentOrSection;
  final Value<int> rowid;
  const LocalStudentsCompanion({
    this.studentId = const Value.absent(),
    this.lrn = const Value.absent(),
    this.rfidUid = const Value.absent(),
    this.firstName = const Value.absent(),
    this.middleName = const Value.absent(),
    this.lastName = const Value.absent(),
    this.gender = const Value.absent(),
    this.departmentOrSection = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalStudentsCompanion.insert({
    required String studentId,
    this.lrn = const Value.absent(),
    this.rfidUid = const Value.absent(),
    required String firstName,
    this.middleName = const Value.absent(),
    required String lastName,
    this.gender = const Value.absent(),
    this.departmentOrSection = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : studentId = Value(studentId),
       firstName = Value(firstName),
       lastName = Value(lastName);
  static Insertable<LocalStudent> custom({
    Expression<String>? studentId,
    Expression<String>? lrn,
    Expression<String>? rfidUid,
    Expression<String>? firstName,
    Expression<String>? middleName,
    Expression<String>? lastName,
    Expression<String>? gender,
    Expression<String>? departmentOrSection,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (studentId != null) 'student_id': studentId,
      if (lrn != null) 'lrn': lrn,
      if (rfidUid != null) 'rfid_uid': rfidUid,
      if (firstName != null) 'first_name': firstName,
      if (middleName != null) 'middle_name': middleName,
      if (lastName != null) 'last_name': lastName,
      if (gender != null) 'gender': gender,
      if (departmentOrSection != null)
        'department_or_section': departmentOrSection,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalStudentsCompanion copyWith({
    Value<String>? studentId,
    Value<String?>? lrn,
    Value<String?>? rfidUid,
    Value<String>? firstName,
    Value<String?>? middleName,
    Value<String>? lastName,
    Value<String>? gender,
    Value<String?>? departmentOrSection,
    Value<int>? rowid,
  }) {
    return LocalStudentsCompanion(
      studentId: studentId ?? this.studentId,
      lrn: lrn ?? this.lrn,
      rfidUid: rfidUid ?? this.rfidUid,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      departmentOrSection: departmentOrSection ?? this.departmentOrSection,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (studentId.present) {
      map['student_id'] = Variable<String>(studentId.value);
    }
    if (lrn.present) {
      map['lrn'] = Variable<String>(lrn.value);
    }
    if (rfidUid.present) {
      map['rfid_uid'] = Variable<String>(rfidUid.value);
    }
    if (firstName.present) {
      map['first_name'] = Variable<String>(firstName.value);
    }
    if (middleName.present) {
      map['middle_name'] = Variable<String>(middleName.value);
    }
    if (lastName.present) {
      map['last_name'] = Variable<String>(lastName.value);
    }
    if (gender.present) {
      map['gender'] = Variable<String>(gender.value);
    }
    if (departmentOrSection.present) {
      map['department_or_section'] = Variable<String>(
        departmentOrSection.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalStudentsCompanion(')
          ..write('studentId: $studentId, ')
          ..write('lrn: $lrn, ')
          ..write('rfidUid: $rfidUid, ')
          ..write('firstName: $firstName, ')
          ..write('middleName: $middleName, ')
          ..write('lastName: $lastName, ')
          ..write('gender: $gender, ')
          ..write('departmentOrSection: $departmentOrSection, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalEnrollmentsTable extends LocalEnrollments
    with TableInfo<$LocalEnrollmentsTable, LocalEnrollment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalEnrollmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _studentIdMeta = const VerificationMeta(
    'studentId',
  );
  @override
  late final GeneratedColumn<String> studentId = GeneratedColumn<String>(
    'student_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectOfferingIdMeta = const VerificationMeta(
    'subjectOfferingId',
  );
  @override
  late final GeneratedColumn<String> subjectOfferingId =
      GeneratedColumn<String>(
        'subject_offering_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('enrolled'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    studentId,
    subjectOfferingId,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_enrollments';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalEnrollment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('student_id')) {
      context.handle(
        _studentIdMeta,
        studentId.isAcceptableOrUnknown(data['student_id']!, _studentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studentIdMeta);
    }
    if (data.containsKey('subject_offering_id')) {
      context.handle(
        _subjectOfferingIdMeta,
        subjectOfferingId.isAcceptableOrUnknown(
          data['subject_offering_id']!,
          _subjectOfferingIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectOfferingIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalEnrollment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalEnrollment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      studentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}student_id'],
      )!,
      subjectOfferingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_offering_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $LocalEnrollmentsTable createAlias(String alias) {
    return $LocalEnrollmentsTable(attachedDatabase, alias);
  }
}

class LocalEnrollment extends DataClass implements Insertable<LocalEnrollment> {
  final String id;
  final String studentId;
  final String subjectOfferingId;
  final String status;
  const LocalEnrollment({
    required this.id,
    required this.studentId,
    required this.subjectOfferingId,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['student_id'] = Variable<String>(studentId);
    map['subject_offering_id'] = Variable<String>(subjectOfferingId);
    map['status'] = Variable<String>(status);
    return map;
  }

  LocalEnrollmentsCompanion toCompanion(bool nullToAbsent) {
    return LocalEnrollmentsCompanion(
      id: Value(id),
      studentId: Value(studentId),
      subjectOfferingId: Value(subjectOfferingId),
      status: Value(status),
    );
  }

  factory LocalEnrollment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalEnrollment(
      id: serializer.fromJson<String>(json['id']),
      studentId: serializer.fromJson<String>(json['studentId']),
      subjectOfferingId: serializer.fromJson<String>(json['subjectOfferingId']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'studentId': serializer.toJson<String>(studentId),
      'subjectOfferingId': serializer.toJson<String>(subjectOfferingId),
      'status': serializer.toJson<String>(status),
    };
  }

  LocalEnrollment copyWith({
    String? id,
    String? studentId,
    String? subjectOfferingId,
    String? status,
  }) => LocalEnrollment(
    id: id ?? this.id,
    studentId: studentId ?? this.studentId,
    subjectOfferingId: subjectOfferingId ?? this.subjectOfferingId,
    status: status ?? this.status,
  );
  LocalEnrollment copyWithCompanion(LocalEnrollmentsCompanion data) {
    return LocalEnrollment(
      id: data.id.present ? data.id.value : this.id,
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      subjectOfferingId: data.subjectOfferingId.present
          ? data.subjectOfferingId.value
          : this.subjectOfferingId,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalEnrollment(')
          ..write('id: $id, ')
          ..write('studentId: $studentId, ')
          ..write('subjectOfferingId: $subjectOfferingId, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, studentId, subjectOfferingId, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalEnrollment &&
          other.id == this.id &&
          other.studentId == this.studentId &&
          other.subjectOfferingId == this.subjectOfferingId &&
          other.status == this.status);
}

class LocalEnrollmentsCompanion extends UpdateCompanion<LocalEnrollment> {
  final Value<String> id;
  final Value<String> studentId;
  final Value<String> subjectOfferingId;
  final Value<String> status;
  final Value<int> rowid;
  const LocalEnrollmentsCompanion({
    this.id = const Value.absent(),
    this.studentId = const Value.absent(),
    this.subjectOfferingId = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalEnrollmentsCompanion.insert({
    required String id,
    required String studentId,
    required String subjectOfferingId,
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       studentId = Value(studentId),
       subjectOfferingId = Value(subjectOfferingId);
  static Insertable<LocalEnrollment> custom({
    Expression<String>? id,
    Expression<String>? studentId,
    Expression<String>? subjectOfferingId,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (studentId != null) 'student_id': studentId,
      if (subjectOfferingId != null) 'subject_offering_id': subjectOfferingId,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalEnrollmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? studentId,
    Value<String>? subjectOfferingId,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return LocalEnrollmentsCompanion(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      subjectOfferingId: subjectOfferingId ?? this.subjectOfferingId,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (studentId.present) {
      map['student_id'] = Variable<String>(studentId.value);
    }
    if (subjectOfferingId.present) {
      map['subject_offering_id'] = Variable<String>(subjectOfferingId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalEnrollmentsCompanion(')
          ..write('id: $id, ')
          ..write('studentId: $studentId, ')
          ..write('subjectOfferingId: $subjectOfferingId, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalParentsTable extends LocalParents
    with TableInfo<$LocalParentsTable, LocalParent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalParentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstNameMeta = const VerificationMeta(
    'firstName',
  );
  @override
  late final GeneratedColumn<String> firstName = GeneratedColumn<String>(
    'first_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _middleNameMeta = const VerificationMeta(
    'middleName',
  );
  @override
  late final GeneratedColumn<String> middleName = GeneratedColumn<String>(
    'middle_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastNameMeta = const VerificationMeta(
    'lastName',
  );
  @override
  late final GeneratedColumn<String> lastName = GeneratedColumn<String>(
    'last_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contactNumberMeta = const VerificationMeta(
    'contactNumber',
  );
  @override
  late final GeneratedColumn<String> contactNumber = GeneratedColumn<String>(
    'contact_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _relationshipMeta = const VerificationMeta(
    'relationship',
  );
  @override
  late final GeneratedColumn<String> relationship = GeneratedColumn<String>(
    'relationship',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Guardian'),
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    parentId,
    firstName,
    middleName,
    lastName,
    contactNumber,
    relationship,
    email,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_parents';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalParent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_parentIdMeta);
    }
    if (data.containsKey('first_name')) {
      context.handle(
        _firstNameMeta,
        firstName.isAcceptableOrUnknown(data['first_name']!, _firstNameMeta),
      );
    } else if (isInserting) {
      context.missing(_firstNameMeta);
    }
    if (data.containsKey('middle_name')) {
      context.handle(
        _middleNameMeta,
        middleName.isAcceptableOrUnknown(data['middle_name']!, _middleNameMeta),
      );
    }
    if (data.containsKey('last_name')) {
      context.handle(
        _lastNameMeta,
        lastName.isAcceptableOrUnknown(data['last_name']!, _lastNameMeta),
      );
    } else if (isInserting) {
      context.missing(_lastNameMeta);
    }
    if (data.containsKey('contact_number')) {
      context.handle(
        _contactNumberMeta,
        contactNumber.isAcceptableOrUnknown(
          data['contact_number']!,
          _contactNumberMeta,
        ),
      );
    }
    if (data.containsKey('relationship')) {
      context.handle(
        _relationshipMeta,
        relationship.isAcceptableOrUnknown(
          data['relationship']!,
          _relationshipMeta,
        ),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {parentId};
  @override
  LocalParent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalParent(
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      )!,
      firstName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}first_name'],
      )!,
      middleName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}middle_name'],
      ),
      lastName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_name'],
      )!,
      contactNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_number'],
      )!,
      relationship: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relationship'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
    );
  }

  @override
  $LocalParentsTable createAlias(String alias) {
    return $LocalParentsTable(attachedDatabase, alias);
  }
}

class LocalParent extends DataClass implements Insertable<LocalParent> {
  final String parentId;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String contactNumber;
  final String relationship;
  final String? email;
  const LocalParent({
    required this.parentId,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.contactNumber,
    required this.relationship,
    this.email,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['parent_id'] = Variable<String>(parentId);
    map['first_name'] = Variable<String>(firstName);
    if (!nullToAbsent || middleName != null) {
      map['middle_name'] = Variable<String>(middleName);
    }
    map['last_name'] = Variable<String>(lastName);
    map['contact_number'] = Variable<String>(contactNumber);
    map['relationship'] = Variable<String>(relationship);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    return map;
  }

  LocalParentsCompanion toCompanion(bool nullToAbsent) {
    return LocalParentsCompanion(
      parentId: Value(parentId),
      firstName: Value(firstName),
      middleName: middleName == null && nullToAbsent
          ? const Value.absent()
          : Value(middleName),
      lastName: Value(lastName),
      contactNumber: Value(contactNumber),
      relationship: Value(relationship),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
    );
  }

  factory LocalParent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalParent(
      parentId: serializer.fromJson<String>(json['parentId']),
      firstName: serializer.fromJson<String>(json['firstName']),
      middleName: serializer.fromJson<String?>(json['middleName']),
      lastName: serializer.fromJson<String>(json['lastName']),
      contactNumber: serializer.fromJson<String>(json['contactNumber']),
      relationship: serializer.fromJson<String>(json['relationship']),
      email: serializer.fromJson<String?>(json['email']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'parentId': serializer.toJson<String>(parentId),
      'firstName': serializer.toJson<String>(firstName),
      'middleName': serializer.toJson<String?>(middleName),
      'lastName': serializer.toJson<String>(lastName),
      'contactNumber': serializer.toJson<String>(contactNumber),
      'relationship': serializer.toJson<String>(relationship),
      'email': serializer.toJson<String?>(email),
    };
  }

  LocalParent copyWith({
    String? parentId,
    String? firstName,
    Value<String?> middleName = const Value.absent(),
    String? lastName,
    String? contactNumber,
    String? relationship,
    Value<String?> email = const Value.absent(),
  }) => LocalParent(
    parentId: parentId ?? this.parentId,
    firstName: firstName ?? this.firstName,
    middleName: middleName.present ? middleName.value : this.middleName,
    lastName: lastName ?? this.lastName,
    contactNumber: contactNumber ?? this.contactNumber,
    relationship: relationship ?? this.relationship,
    email: email.present ? email.value : this.email,
  );
  LocalParent copyWithCompanion(LocalParentsCompanion data) {
    return LocalParent(
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      firstName: data.firstName.present ? data.firstName.value : this.firstName,
      middleName: data.middleName.present
          ? data.middleName.value
          : this.middleName,
      lastName: data.lastName.present ? data.lastName.value : this.lastName,
      contactNumber: data.contactNumber.present
          ? data.contactNumber.value
          : this.contactNumber,
      relationship: data.relationship.present
          ? data.relationship.value
          : this.relationship,
      email: data.email.present ? data.email.value : this.email,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalParent(')
          ..write('parentId: $parentId, ')
          ..write('firstName: $firstName, ')
          ..write('middleName: $middleName, ')
          ..write('lastName: $lastName, ')
          ..write('contactNumber: $contactNumber, ')
          ..write('relationship: $relationship, ')
          ..write('email: $email')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    parentId,
    firstName,
    middleName,
    lastName,
    contactNumber,
    relationship,
    email,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalParent &&
          other.parentId == this.parentId &&
          other.firstName == this.firstName &&
          other.middleName == this.middleName &&
          other.lastName == this.lastName &&
          other.contactNumber == this.contactNumber &&
          other.relationship == this.relationship &&
          other.email == this.email);
}

class LocalParentsCompanion extends UpdateCompanion<LocalParent> {
  final Value<String> parentId;
  final Value<String> firstName;
  final Value<String?> middleName;
  final Value<String> lastName;
  final Value<String> contactNumber;
  final Value<String> relationship;
  final Value<String?> email;
  final Value<int> rowid;
  const LocalParentsCompanion({
    this.parentId = const Value.absent(),
    this.firstName = const Value.absent(),
    this.middleName = const Value.absent(),
    this.lastName = const Value.absent(),
    this.contactNumber = const Value.absent(),
    this.relationship = const Value.absent(),
    this.email = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalParentsCompanion.insert({
    required String parentId,
    required String firstName,
    this.middleName = const Value.absent(),
    required String lastName,
    this.contactNumber = const Value.absent(),
    this.relationship = const Value.absent(),
    this.email = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : parentId = Value(parentId),
       firstName = Value(firstName),
       lastName = Value(lastName);
  static Insertable<LocalParent> custom({
    Expression<String>? parentId,
    Expression<String>? firstName,
    Expression<String>? middleName,
    Expression<String>? lastName,
    Expression<String>? contactNumber,
    Expression<String>? relationship,
    Expression<String>? email,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (parentId != null) 'parent_id': parentId,
      if (firstName != null) 'first_name': firstName,
      if (middleName != null) 'middle_name': middleName,
      if (lastName != null) 'last_name': lastName,
      if (contactNumber != null) 'contact_number': contactNumber,
      if (relationship != null) 'relationship': relationship,
      if (email != null) 'email': email,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalParentsCompanion copyWith({
    Value<String>? parentId,
    Value<String>? firstName,
    Value<String?>? middleName,
    Value<String>? lastName,
    Value<String>? contactNumber,
    Value<String>? relationship,
    Value<String?>? email,
    Value<int>? rowid,
  }) {
    return LocalParentsCompanion(
      parentId: parentId ?? this.parentId,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      contactNumber: contactNumber ?? this.contactNumber,
      relationship: relationship ?? this.relationship,
      email: email ?? this.email,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (firstName.present) {
      map['first_name'] = Variable<String>(firstName.value);
    }
    if (middleName.present) {
      map['middle_name'] = Variable<String>(middleName.value);
    }
    if (lastName.present) {
      map['last_name'] = Variable<String>(lastName.value);
    }
    if (contactNumber.present) {
      map['contact_number'] = Variable<String>(contactNumber.value);
    }
    if (relationship.present) {
      map['relationship'] = Variable<String>(relationship.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalParentsCompanion(')
          ..write('parentId: $parentId, ')
          ..write('firstName: $firstName, ')
          ..write('middleName: $middleName, ')
          ..write('lastName: $lastName, ')
          ..write('contactNumber: $contactNumber, ')
          ..write('relationship: $relationship, ')
          ..write('email: $email, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalParentStudentLinksTable extends LocalParentStudentLinks
    with TableInfo<$LocalParentStudentLinksTable, LocalParentStudentLink> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalParentStudentLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _studentIdMeta = const VerificationMeta(
    'studentId',
  );
  @override
  late final GeneratedColumn<String> studentId = GeneratedColumn<String>(
    'student_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relationshipMeta = const VerificationMeta(
    'relationship',
  );
  @override
  late final GeneratedColumn<String> relationship = GeneratedColumn<String>(
    'relationship',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Guardian'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, parentId, studentId, relationship];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_parent_student_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalParentStudentLink> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_parentIdMeta);
    }
    if (data.containsKey('student_id')) {
      context.handle(
        _studentIdMeta,
        studentId.isAcceptableOrUnknown(data['student_id']!, _studentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studentIdMeta);
    }
    if (data.containsKey('relationship')) {
      context.handle(
        _relationshipMeta,
        relationship.isAcceptableOrUnknown(
          data['relationship']!,
          _relationshipMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalParentStudentLink map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalParentStudentLink(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      )!,
      studentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}student_id'],
      )!,
      relationship: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relationship'],
      )!,
    );
  }

  @override
  $LocalParentStudentLinksTable createAlias(String alias) {
    return $LocalParentStudentLinksTable(attachedDatabase, alias);
  }
}

class LocalParentStudentLink extends DataClass
    implements Insertable<LocalParentStudentLink> {
  final String id;
  final String parentId;
  final String studentId;
  final String relationship;
  const LocalParentStudentLink({
    required this.id,
    required this.parentId,
    required this.studentId,
    required this.relationship,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['parent_id'] = Variable<String>(parentId);
    map['student_id'] = Variable<String>(studentId);
    map['relationship'] = Variable<String>(relationship);
    return map;
  }

  LocalParentStudentLinksCompanion toCompanion(bool nullToAbsent) {
    return LocalParentStudentLinksCompanion(
      id: Value(id),
      parentId: Value(parentId),
      studentId: Value(studentId),
      relationship: Value(relationship),
    );
  }

  factory LocalParentStudentLink.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalParentStudentLink(
      id: serializer.fromJson<String>(json['id']),
      parentId: serializer.fromJson<String>(json['parentId']),
      studentId: serializer.fromJson<String>(json['studentId']),
      relationship: serializer.fromJson<String>(json['relationship']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'parentId': serializer.toJson<String>(parentId),
      'studentId': serializer.toJson<String>(studentId),
      'relationship': serializer.toJson<String>(relationship),
    };
  }

  LocalParentStudentLink copyWith({
    String? id,
    String? parentId,
    String? studentId,
    String? relationship,
  }) => LocalParentStudentLink(
    id: id ?? this.id,
    parentId: parentId ?? this.parentId,
    studentId: studentId ?? this.studentId,
    relationship: relationship ?? this.relationship,
  );
  LocalParentStudentLink copyWithCompanion(
    LocalParentStudentLinksCompanion data,
  ) {
    return LocalParentStudentLink(
      id: data.id.present ? data.id.value : this.id,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      relationship: data.relationship.present
          ? data.relationship.value
          : this.relationship,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalParentStudentLink(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('studentId: $studentId, ')
          ..write('relationship: $relationship')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, parentId, studentId, relationship);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalParentStudentLink &&
          other.id == this.id &&
          other.parentId == this.parentId &&
          other.studentId == this.studentId &&
          other.relationship == this.relationship);
}

class LocalParentStudentLinksCompanion
    extends UpdateCompanion<LocalParentStudentLink> {
  final Value<String> id;
  final Value<String> parentId;
  final Value<String> studentId;
  final Value<String> relationship;
  final Value<int> rowid;
  const LocalParentStudentLinksCompanion({
    this.id = const Value.absent(),
    this.parentId = const Value.absent(),
    this.studentId = const Value.absent(),
    this.relationship = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalParentStudentLinksCompanion.insert({
    required String id,
    required String parentId,
    required String studentId,
    this.relationship = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       parentId = Value(parentId),
       studentId = Value(studentId);
  static Insertable<LocalParentStudentLink> custom({
    Expression<String>? id,
    Expression<String>? parentId,
    Expression<String>? studentId,
    Expression<String>? relationship,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentId != null) 'parent_id': parentId,
      if (studentId != null) 'student_id': studentId,
      if (relationship != null) 'relationship': relationship,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalParentStudentLinksCompanion copyWith({
    Value<String>? id,
    Value<String>? parentId,
    Value<String>? studentId,
    Value<String>? relationship,
    Value<int>? rowid,
  }) {
    return LocalParentStudentLinksCompanion(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      studentId: studentId ?? this.studentId,
      relationship: relationship ?? this.relationship,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (studentId.present) {
      map['student_id'] = Variable<String>(studentId.value);
    }
    if (relationship.present) {
      map['relationship'] = Variable<String>(relationship.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalParentStudentLinksCompanion(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('studentId: $studentId, ')
          ..write('relationship: $relationship, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAttendanceRecordsTable extends LocalAttendanceRecords
    with TableInfo<$LocalAttendanceRecordsTable, LocalAttendanceRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAttendanceRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _studentIdMeta = const VerificationMeta(
    'studentId',
  );
  @override
  late final GeneratedColumn<String> studentId = GeneratedColumn<String>(
    'student_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectOfferingIdMeta = const VerificationMeta(
    'subjectOfferingId',
  );
  @override
  late final GeneratedColumn<String> subjectOfferingId =
      GeneratedColumn<String>(
        'subject_offering_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _attendanceDateMeta = const VerificationMeta(
    'attendanceDate',
  );
  @override
  late final GeneratedColumn<String> attendanceDate = GeneratedColumn<String>(
    'attendance_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordingMethodMeta = const VerificationMeta(
    'recordingMethod',
  );
  @override
  late final GeneratedColumn<String> recordingMethod = GeneratedColumn<String>(
    'recording_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Manual'),
  );
  static const VerificationMeta _timeInMeta = const VerificationMeta('timeIn');
  @override
  late final GeneratedColumn<String> timeIn = GeneratedColumn<String>(
    'time_in',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remarksMeta = const VerificationMeta(
    'remarks',
  );
  @override
  late final GeneratedColumn<String> remarks = GeneratedColumn<String>(
    'remarks',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _recordedByMeta = const VerificationMeta(
    'recordedBy',
  );
  @override
  late final GeneratedColumn<String> recordedBy = GeneratedColumn<String>(
    'recorded_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('synced'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    studentId,
    subjectOfferingId,
    attendanceDate,
    status,
    recordingMethod,
    timeIn,
    deviceId,
    remarks,
    source,
    recordedBy,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_attendance_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalAttendanceRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('student_id')) {
      context.handle(
        _studentIdMeta,
        studentId.isAcceptableOrUnknown(data['student_id']!, _studentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studentIdMeta);
    }
    if (data.containsKey('subject_offering_id')) {
      context.handle(
        _subjectOfferingIdMeta,
        subjectOfferingId.isAcceptableOrUnknown(
          data['subject_offering_id']!,
          _subjectOfferingIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectOfferingIdMeta);
    }
    if (data.containsKey('attendance_date')) {
      context.handle(
        _attendanceDateMeta,
        attendanceDate.isAcceptableOrUnknown(
          data['attendance_date']!,
          _attendanceDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attendanceDateMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('recording_method')) {
      context.handle(
        _recordingMethodMeta,
        recordingMethod.isAcceptableOrUnknown(
          data['recording_method']!,
          _recordingMethodMeta,
        ),
      );
    }
    if (data.containsKey('time_in')) {
      context.handle(
        _timeInMeta,
        timeIn.isAcceptableOrUnknown(data['time_in']!, _timeInMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('remarks')) {
      context.handle(
        _remarksMeta,
        remarks.isAcceptableOrUnknown(data['remarks']!, _remarksMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('recorded_by')) {
      context.handle(
        _recordedByMeta,
        recordedBy.isAcceptableOrUnknown(data['recorded_by']!, _recordedByMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalAttendanceRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAttendanceRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      studentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}student_id'],
      )!,
      subjectOfferingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_offering_id'],
      )!,
      attendanceDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attendance_date'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      recordingMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_method'],
      )!,
      timeIn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_in'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
      remarks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remarks'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      recordedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recorded_by'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $LocalAttendanceRecordsTable createAlias(String alias) {
    return $LocalAttendanceRecordsTable(attachedDatabase, alias);
  }
}

class LocalAttendanceRecord extends DataClass
    implements Insertable<LocalAttendanceRecord> {
  final String id;
  final String studentId;
  final String subjectOfferingId;
  final String attendanceDate;
  final String status;
  final String recordingMethod;
  final String? timeIn;
  final String? deviceId;
  final String? remarks;
  final String source;
  final String? recordedBy;
  final String syncStatus;
  const LocalAttendanceRecord({
    required this.id,
    required this.studentId,
    required this.subjectOfferingId,
    required this.attendanceDate,
    required this.status,
    required this.recordingMethod,
    this.timeIn,
    this.deviceId,
    this.remarks,
    required this.source,
    this.recordedBy,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['student_id'] = Variable<String>(studentId);
    map['subject_offering_id'] = Variable<String>(subjectOfferingId);
    map['attendance_date'] = Variable<String>(attendanceDate);
    map['status'] = Variable<String>(status);
    map['recording_method'] = Variable<String>(recordingMethod);
    if (!nullToAbsent || timeIn != null) {
      map['time_in'] = Variable<String>(timeIn);
    }
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    if (!nullToAbsent || remarks != null) {
      map['remarks'] = Variable<String>(remarks);
    }
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || recordedBy != null) {
      map['recorded_by'] = Variable<String>(recordedBy);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  LocalAttendanceRecordsCompanion toCompanion(bool nullToAbsent) {
    return LocalAttendanceRecordsCompanion(
      id: Value(id),
      studentId: Value(studentId),
      subjectOfferingId: Value(subjectOfferingId),
      attendanceDate: Value(attendanceDate),
      status: Value(status),
      recordingMethod: Value(recordingMethod),
      timeIn: timeIn == null && nullToAbsent
          ? const Value.absent()
          : Value(timeIn),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
      remarks: remarks == null && nullToAbsent
          ? const Value.absent()
          : Value(remarks),
      source: Value(source),
      recordedBy: recordedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(recordedBy),
      syncStatus: Value(syncStatus),
    );
  }

  factory LocalAttendanceRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAttendanceRecord(
      id: serializer.fromJson<String>(json['id']),
      studentId: serializer.fromJson<String>(json['studentId']),
      subjectOfferingId: serializer.fromJson<String>(json['subjectOfferingId']),
      attendanceDate: serializer.fromJson<String>(json['attendanceDate']),
      status: serializer.fromJson<String>(json['status']),
      recordingMethod: serializer.fromJson<String>(json['recordingMethod']),
      timeIn: serializer.fromJson<String?>(json['timeIn']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
      remarks: serializer.fromJson<String?>(json['remarks']),
      source: serializer.fromJson<String>(json['source']),
      recordedBy: serializer.fromJson<String?>(json['recordedBy']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'studentId': serializer.toJson<String>(studentId),
      'subjectOfferingId': serializer.toJson<String>(subjectOfferingId),
      'attendanceDate': serializer.toJson<String>(attendanceDate),
      'status': serializer.toJson<String>(status),
      'recordingMethod': serializer.toJson<String>(recordingMethod),
      'timeIn': serializer.toJson<String?>(timeIn),
      'deviceId': serializer.toJson<String?>(deviceId),
      'remarks': serializer.toJson<String?>(remarks),
      'source': serializer.toJson<String>(source),
      'recordedBy': serializer.toJson<String?>(recordedBy),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  LocalAttendanceRecord copyWith({
    String? id,
    String? studentId,
    String? subjectOfferingId,
    String? attendanceDate,
    String? status,
    String? recordingMethod,
    Value<String?> timeIn = const Value.absent(),
    Value<String?> deviceId = const Value.absent(),
    Value<String?> remarks = const Value.absent(),
    String? source,
    Value<String?> recordedBy = const Value.absent(),
    String? syncStatus,
  }) => LocalAttendanceRecord(
    id: id ?? this.id,
    studentId: studentId ?? this.studentId,
    subjectOfferingId: subjectOfferingId ?? this.subjectOfferingId,
    attendanceDate: attendanceDate ?? this.attendanceDate,
    status: status ?? this.status,
    recordingMethod: recordingMethod ?? this.recordingMethod,
    timeIn: timeIn.present ? timeIn.value : this.timeIn,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
    remarks: remarks.present ? remarks.value : this.remarks,
    source: source ?? this.source,
    recordedBy: recordedBy.present ? recordedBy.value : this.recordedBy,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  LocalAttendanceRecord copyWithCompanion(
    LocalAttendanceRecordsCompanion data,
  ) {
    return LocalAttendanceRecord(
      id: data.id.present ? data.id.value : this.id,
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      subjectOfferingId: data.subjectOfferingId.present
          ? data.subjectOfferingId.value
          : this.subjectOfferingId,
      attendanceDate: data.attendanceDate.present
          ? data.attendanceDate.value
          : this.attendanceDate,
      status: data.status.present ? data.status.value : this.status,
      recordingMethod: data.recordingMethod.present
          ? data.recordingMethod.value
          : this.recordingMethod,
      timeIn: data.timeIn.present ? data.timeIn.value : this.timeIn,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      remarks: data.remarks.present ? data.remarks.value : this.remarks,
      source: data.source.present ? data.source.value : this.source,
      recordedBy: data.recordedBy.present
          ? data.recordedBy.value
          : this.recordedBy,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAttendanceRecord(')
          ..write('id: $id, ')
          ..write('studentId: $studentId, ')
          ..write('subjectOfferingId: $subjectOfferingId, ')
          ..write('attendanceDate: $attendanceDate, ')
          ..write('status: $status, ')
          ..write('recordingMethod: $recordingMethod, ')
          ..write('timeIn: $timeIn, ')
          ..write('deviceId: $deviceId, ')
          ..write('remarks: $remarks, ')
          ..write('source: $source, ')
          ..write('recordedBy: $recordedBy, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    studentId,
    subjectOfferingId,
    attendanceDate,
    status,
    recordingMethod,
    timeIn,
    deviceId,
    remarks,
    source,
    recordedBy,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAttendanceRecord &&
          other.id == this.id &&
          other.studentId == this.studentId &&
          other.subjectOfferingId == this.subjectOfferingId &&
          other.attendanceDate == this.attendanceDate &&
          other.status == this.status &&
          other.recordingMethod == this.recordingMethod &&
          other.timeIn == this.timeIn &&
          other.deviceId == this.deviceId &&
          other.remarks == this.remarks &&
          other.source == this.source &&
          other.recordedBy == this.recordedBy &&
          other.syncStatus == this.syncStatus);
}

class LocalAttendanceRecordsCompanion
    extends UpdateCompanion<LocalAttendanceRecord> {
  final Value<String> id;
  final Value<String> studentId;
  final Value<String> subjectOfferingId;
  final Value<String> attendanceDate;
  final Value<String> status;
  final Value<String> recordingMethod;
  final Value<String?> timeIn;
  final Value<String?> deviceId;
  final Value<String?> remarks;
  final Value<String> source;
  final Value<String?> recordedBy;
  final Value<String> syncStatus;
  final Value<int> rowid;
  const LocalAttendanceRecordsCompanion({
    this.id = const Value.absent(),
    this.studentId = const Value.absent(),
    this.subjectOfferingId = const Value.absent(),
    this.attendanceDate = const Value.absent(),
    this.status = const Value.absent(),
    this.recordingMethod = const Value.absent(),
    this.timeIn = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.remarks = const Value.absent(),
    this.source = const Value.absent(),
    this.recordedBy = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAttendanceRecordsCompanion.insert({
    required String id,
    required String studentId,
    required String subjectOfferingId,
    required String attendanceDate,
    required String status,
    this.recordingMethod = const Value.absent(),
    this.timeIn = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.remarks = const Value.absent(),
    this.source = const Value.absent(),
    this.recordedBy = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       studentId = Value(studentId),
       subjectOfferingId = Value(subjectOfferingId),
       attendanceDate = Value(attendanceDate),
       status = Value(status);
  static Insertable<LocalAttendanceRecord> custom({
    Expression<String>? id,
    Expression<String>? studentId,
    Expression<String>? subjectOfferingId,
    Expression<String>? attendanceDate,
    Expression<String>? status,
    Expression<String>? recordingMethod,
    Expression<String>? timeIn,
    Expression<String>? deviceId,
    Expression<String>? remarks,
    Expression<String>? source,
    Expression<String>? recordedBy,
    Expression<String>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (studentId != null) 'student_id': studentId,
      if (subjectOfferingId != null) 'subject_offering_id': subjectOfferingId,
      if (attendanceDate != null) 'attendance_date': attendanceDate,
      if (status != null) 'status': status,
      if (recordingMethod != null) 'recording_method': recordingMethod,
      if (timeIn != null) 'time_in': timeIn,
      if (deviceId != null) 'device_id': deviceId,
      if (remarks != null) 'remarks': remarks,
      if (source != null) 'source': source,
      if (recordedBy != null) 'recorded_by': recordedBy,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAttendanceRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? studentId,
    Value<String>? subjectOfferingId,
    Value<String>? attendanceDate,
    Value<String>? status,
    Value<String>? recordingMethod,
    Value<String?>? timeIn,
    Value<String?>? deviceId,
    Value<String?>? remarks,
    Value<String>? source,
    Value<String?>? recordedBy,
    Value<String>? syncStatus,
    Value<int>? rowid,
  }) {
    return LocalAttendanceRecordsCompanion(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      subjectOfferingId: subjectOfferingId ?? this.subjectOfferingId,
      attendanceDate: attendanceDate ?? this.attendanceDate,
      status: status ?? this.status,
      recordingMethod: recordingMethod ?? this.recordingMethod,
      timeIn: timeIn ?? this.timeIn,
      deviceId: deviceId ?? this.deviceId,
      remarks: remarks ?? this.remarks,
      source: source ?? this.source,
      recordedBy: recordedBy ?? this.recordedBy,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (studentId.present) {
      map['student_id'] = Variable<String>(studentId.value);
    }
    if (subjectOfferingId.present) {
      map['subject_offering_id'] = Variable<String>(subjectOfferingId.value);
    }
    if (attendanceDate.present) {
      map['attendance_date'] = Variable<String>(attendanceDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (recordingMethod.present) {
      map['recording_method'] = Variable<String>(recordingMethod.value);
    }
    if (timeIn.present) {
      map['time_in'] = Variable<String>(timeIn.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (remarks.present) {
      map['remarks'] = Variable<String>(remarks.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (recordedBy.present) {
      map['recorded_by'] = Variable<String>(recordedBy.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAttendanceRecordsCompanion(')
          ..write('id: $id, ')
          ..write('studentId: $studentId, ')
          ..write('subjectOfferingId: $subjectOfferingId, ')
          ..write('attendanceDate: $attendanceDate, ')
          ..write('status: $status, ')
          ..write('recordingMethod: $recordingMethod, ')
          ..write('timeIn: $timeIn, ')
          ..write('deviceId: $deviceId, ')
          ..write('remarks: $remarks, ')
          ..write('source: $source, ')
          ..write('recordedBy: $recordedBy, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAttendanceCutoffsTable extends LocalAttendanceCutoffs
    with TableInfo<$LocalAttendanceCutoffsTable, LocalAttendanceCutoff> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAttendanceCutoffsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _subjectOfferingIdMeta = const VerificationMeta(
    'subjectOfferingId',
  );
  @override
  late final GeneratedColumn<String> subjectOfferingId =
      GeneratedColumn<String>(
        'subject_offering_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _presentStartMinsBeforeMeta =
      const VerificationMeta('presentStartMinsBefore');
  @override
  late final GeneratedColumn<int> presentStartMinsBefore = GeneratedColumn<int>(
    'present_start_mins_before',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(15),
  );
  static const VerificationMeta _presentGraceMinsMeta = const VerificationMeta(
    'presentGraceMins',
  );
  @override
  late final GeneratedColumn<int> presentGraceMins = GeneratedColumn<int>(
    'present_grace_mins',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(15),
  );
  static const VerificationMeta _lateCutoffMinsMeta = const VerificationMeta(
    'lateCutoffMins',
  );
  @override
  late final GeneratedColumn<int> lateCutoffMins = GeneratedColumn<int>(
    'late_cutoff_mins',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(45),
  );
  static const VerificationMeta _absentCutoffMinsMeta = const VerificationMeta(
    'absentCutoffMins',
  );
  @override
  late final GeneratedColumn<int> absentCutoffMins = GeneratedColumn<int>(
    'absent_cutoff_mins',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(60),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    subjectOfferingId,
    presentStartMinsBefore,
    presentGraceMins,
    lateCutoffMins,
    absentCutoffMins,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_attendance_cutoffs';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalAttendanceCutoff> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('subject_offering_id')) {
      context.handle(
        _subjectOfferingIdMeta,
        subjectOfferingId.isAcceptableOrUnknown(
          data['subject_offering_id']!,
          _subjectOfferingIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectOfferingIdMeta);
    }
    if (data.containsKey('present_start_mins_before')) {
      context.handle(
        _presentStartMinsBeforeMeta,
        presentStartMinsBefore.isAcceptableOrUnknown(
          data['present_start_mins_before']!,
          _presentStartMinsBeforeMeta,
        ),
      );
    }
    if (data.containsKey('present_grace_mins')) {
      context.handle(
        _presentGraceMinsMeta,
        presentGraceMins.isAcceptableOrUnknown(
          data['present_grace_mins']!,
          _presentGraceMinsMeta,
        ),
      );
    }
    if (data.containsKey('late_cutoff_mins')) {
      context.handle(
        _lateCutoffMinsMeta,
        lateCutoffMins.isAcceptableOrUnknown(
          data['late_cutoff_mins']!,
          _lateCutoffMinsMeta,
        ),
      );
    }
    if (data.containsKey('absent_cutoff_mins')) {
      context.handle(
        _absentCutoffMinsMeta,
        absentCutoffMins.isAcceptableOrUnknown(
          data['absent_cutoff_mins']!,
          _absentCutoffMinsMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {subjectOfferingId};
  @override
  LocalAttendanceCutoff map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAttendanceCutoff(
      subjectOfferingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_offering_id'],
      )!,
      presentStartMinsBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}present_start_mins_before'],
      )!,
      presentGraceMins: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}present_grace_mins'],
      )!,
      lateCutoffMins: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}late_cutoff_mins'],
      )!,
      absentCutoffMins: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}absent_cutoff_mins'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalAttendanceCutoffsTable createAlias(String alias) {
    return $LocalAttendanceCutoffsTable(attachedDatabase, alias);
  }
}

class LocalAttendanceCutoff extends DataClass
    implements Insertable<LocalAttendanceCutoff> {
  final String subjectOfferingId;
  final int presentStartMinsBefore;
  final int presentGraceMins;
  final int lateCutoffMins;
  final int absentCutoffMins;
  final DateTime updatedAt;
  const LocalAttendanceCutoff({
    required this.subjectOfferingId,
    required this.presentStartMinsBefore,
    required this.presentGraceMins,
    required this.lateCutoffMins,
    required this.absentCutoffMins,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['subject_offering_id'] = Variable<String>(subjectOfferingId);
    map['present_start_mins_before'] = Variable<int>(presentStartMinsBefore);
    map['present_grace_mins'] = Variable<int>(presentGraceMins);
    map['late_cutoff_mins'] = Variable<int>(lateCutoffMins);
    map['absent_cutoff_mins'] = Variable<int>(absentCutoffMins);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalAttendanceCutoffsCompanion toCompanion(bool nullToAbsent) {
    return LocalAttendanceCutoffsCompanion(
      subjectOfferingId: Value(subjectOfferingId),
      presentStartMinsBefore: Value(presentStartMinsBefore),
      presentGraceMins: Value(presentGraceMins),
      lateCutoffMins: Value(lateCutoffMins),
      absentCutoffMins: Value(absentCutoffMins),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalAttendanceCutoff.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAttendanceCutoff(
      subjectOfferingId: serializer.fromJson<String>(json['subjectOfferingId']),
      presentStartMinsBefore: serializer.fromJson<int>(
        json['presentStartMinsBefore'],
      ),
      presentGraceMins: serializer.fromJson<int>(json['presentGraceMins']),
      lateCutoffMins: serializer.fromJson<int>(json['lateCutoffMins']),
      absentCutoffMins: serializer.fromJson<int>(json['absentCutoffMins']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'subjectOfferingId': serializer.toJson<String>(subjectOfferingId),
      'presentStartMinsBefore': serializer.toJson<int>(presentStartMinsBefore),
      'presentGraceMins': serializer.toJson<int>(presentGraceMins),
      'lateCutoffMins': serializer.toJson<int>(lateCutoffMins),
      'absentCutoffMins': serializer.toJson<int>(absentCutoffMins),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalAttendanceCutoff copyWith({
    String? subjectOfferingId,
    int? presentStartMinsBefore,
    int? presentGraceMins,
    int? lateCutoffMins,
    int? absentCutoffMins,
    DateTime? updatedAt,
  }) => LocalAttendanceCutoff(
    subjectOfferingId: subjectOfferingId ?? this.subjectOfferingId,
    presentStartMinsBefore:
        presentStartMinsBefore ?? this.presentStartMinsBefore,
    presentGraceMins: presentGraceMins ?? this.presentGraceMins,
    lateCutoffMins: lateCutoffMins ?? this.lateCutoffMins,
    absentCutoffMins: absentCutoffMins ?? this.absentCutoffMins,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalAttendanceCutoff copyWithCompanion(
    LocalAttendanceCutoffsCompanion data,
  ) {
    return LocalAttendanceCutoff(
      subjectOfferingId: data.subjectOfferingId.present
          ? data.subjectOfferingId.value
          : this.subjectOfferingId,
      presentStartMinsBefore: data.presentStartMinsBefore.present
          ? data.presentStartMinsBefore.value
          : this.presentStartMinsBefore,
      presentGraceMins: data.presentGraceMins.present
          ? data.presentGraceMins.value
          : this.presentGraceMins,
      lateCutoffMins: data.lateCutoffMins.present
          ? data.lateCutoffMins.value
          : this.lateCutoffMins,
      absentCutoffMins: data.absentCutoffMins.present
          ? data.absentCutoffMins.value
          : this.absentCutoffMins,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAttendanceCutoff(')
          ..write('subjectOfferingId: $subjectOfferingId, ')
          ..write('presentStartMinsBefore: $presentStartMinsBefore, ')
          ..write('presentGraceMins: $presentGraceMins, ')
          ..write('lateCutoffMins: $lateCutoffMins, ')
          ..write('absentCutoffMins: $absentCutoffMins, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    subjectOfferingId,
    presentStartMinsBefore,
    presentGraceMins,
    lateCutoffMins,
    absentCutoffMins,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAttendanceCutoff &&
          other.subjectOfferingId == this.subjectOfferingId &&
          other.presentStartMinsBefore == this.presentStartMinsBefore &&
          other.presentGraceMins == this.presentGraceMins &&
          other.lateCutoffMins == this.lateCutoffMins &&
          other.absentCutoffMins == this.absentCutoffMins &&
          other.updatedAt == this.updatedAt);
}

class LocalAttendanceCutoffsCompanion
    extends UpdateCompanion<LocalAttendanceCutoff> {
  final Value<String> subjectOfferingId;
  final Value<int> presentStartMinsBefore;
  final Value<int> presentGraceMins;
  final Value<int> lateCutoffMins;
  final Value<int> absentCutoffMins;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalAttendanceCutoffsCompanion({
    this.subjectOfferingId = const Value.absent(),
    this.presentStartMinsBefore = const Value.absent(),
    this.presentGraceMins = const Value.absent(),
    this.lateCutoffMins = const Value.absent(),
    this.absentCutoffMins = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAttendanceCutoffsCompanion.insert({
    required String subjectOfferingId,
    this.presentStartMinsBefore = const Value.absent(),
    this.presentGraceMins = const Value.absent(),
    this.lateCutoffMins = const Value.absent(),
    this.absentCutoffMins = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : subjectOfferingId = Value(subjectOfferingId);
  static Insertable<LocalAttendanceCutoff> custom({
    Expression<String>? subjectOfferingId,
    Expression<int>? presentStartMinsBefore,
    Expression<int>? presentGraceMins,
    Expression<int>? lateCutoffMins,
    Expression<int>? absentCutoffMins,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (subjectOfferingId != null) 'subject_offering_id': subjectOfferingId,
      if (presentStartMinsBefore != null)
        'present_start_mins_before': presentStartMinsBefore,
      if (presentGraceMins != null) 'present_grace_mins': presentGraceMins,
      if (lateCutoffMins != null) 'late_cutoff_mins': lateCutoffMins,
      if (absentCutoffMins != null) 'absent_cutoff_mins': absentCutoffMins,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAttendanceCutoffsCompanion copyWith({
    Value<String>? subjectOfferingId,
    Value<int>? presentStartMinsBefore,
    Value<int>? presentGraceMins,
    Value<int>? lateCutoffMins,
    Value<int>? absentCutoffMins,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalAttendanceCutoffsCompanion(
      subjectOfferingId: subjectOfferingId ?? this.subjectOfferingId,
      presentStartMinsBefore:
          presentStartMinsBefore ?? this.presentStartMinsBefore,
      presentGraceMins: presentGraceMins ?? this.presentGraceMins,
      lateCutoffMins: lateCutoffMins ?? this.lateCutoffMins,
      absentCutoffMins: absentCutoffMins ?? this.absentCutoffMins,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (subjectOfferingId.present) {
      map['subject_offering_id'] = Variable<String>(subjectOfferingId.value);
    }
    if (presentStartMinsBefore.present) {
      map['present_start_mins_before'] = Variable<int>(
        presentStartMinsBefore.value,
      );
    }
    if (presentGraceMins.present) {
      map['present_grace_mins'] = Variable<int>(presentGraceMins.value);
    }
    if (lateCutoffMins.present) {
      map['late_cutoff_mins'] = Variable<int>(lateCutoffMins.value);
    }
    if (absentCutoffMins.present) {
      map['absent_cutoff_mins'] = Variable<int>(absentCutoffMins.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAttendanceCutoffsCompanion(')
          ..write('subjectOfferingId: $subjectOfferingId, ')
          ..write('presentStartMinsBefore: $presentStartMinsBefore, ')
          ..write('presentGraceMins: $presentGraceMins, ')
          ..write('lateCutoffMins: $lateCutoffMins, ')
          ..write('absentCutoffMins: $absentCutoffMins, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSchedulesTable extends LocalSchedules
    with TableInfo<$LocalSchedulesTable, LocalSchedule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSchedulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectOfferingIdMeta = const VerificationMeta(
    'subjectOfferingId',
  );
  @override
  late final GeneratedColumn<String> subjectOfferingId =
      GeneratedColumn<String>(
        'subject_offering_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _teacherIdMeta = const VerificationMeta(
    'teacherId',
  );
  @override
  late final GeneratedColumn<String> teacherId = GeneratedColumn<String>(
    'teacher_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayOfWeekMeta = const VerificationMeta(
    'dayOfWeek',
  );
  @override
  late final GeneratedColumn<String> dayOfWeek = GeneratedColumn<String>(
    'day_of_week',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<String> startTime = GeneratedColumn<String>(
    'start_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<String> endTime = GeneratedColumn<String>(
    'end_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roomMeta = const VerificationMeta('room');
  @override
  late final GeneratedColumn<String> room = GeneratedColumn<String>(
    'room',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectOfferingId,
    teacherId,
    dayOfWeek,
    startTime,
    endTime,
    room,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_schedules';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSchedule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('subject_offering_id')) {
      context.handle(
        _subjectOfferingIdMeta,
        subjectOfferingId.isAcceptableOrUnknown(
          data['subject_offering_id']!,
          _subjectOfferingIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectOfferingIdMeta);
    }
    if (data.containsKey('teacher_id')) {
      context.handle(
        _teacherIdMeta,
        teacherId.isAcceptableOrUnknown(data['teacher_id']!, _teacherIdMeta),
      );
    } else if (isInserting) {
      context.missing(_teacherIdMeta);
    }
    if (data.containsKey('day_of_week')) {
      context.handle(
        _dayOfWeekMeta,
        dayOfWeek.isAcceptableOrUnknown(data['day_of_week']!, _dayOfWeekMeta),
      );
    } else if (isInserting) {
      context.missing(_dayOfWeekMeta);
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_endTimeMeta);
    }
    if (data.containsKey('room')) {
      context.handle(
        _roomMeta,
        room.isAcceptableOrUnknown(data['room']!, _roomMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSchedule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSchedule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      subjectOfferingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_offering_id'],
      )!,
      teacherId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}teacher_id'],
      )!,
      dayOfWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_of_week'],
      )!,
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_time'],
      )!,
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_time'],
      )!,
      room: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}room'],
      ),
    );
  }

  @override
  $LocalSchedulesTable createAlias(String alias) {
    return $LocalSchedulesTable(attachedDatabase, alias);
  }
}

class LocalSchedule extends DataClass implements Insertable<LocalSchedule> {
  final String id;
  final String subjectOfferingId;
  final String teacherId;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final String? room;
  const LocalSchedule({
    required this.id,
    required this.subjectOfferingId,
    required this.teacherId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.room,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['subject_offering_id'] = Variable<String>(subjectOfferingId);
    map['teacher_id'] = Variable<String>(teacherId);
    map['day_of_week'] = Variable<String>(dayOfWeek);
    map['start_time'] = Variable<String>(startTime);
    map['end_time'] = Variable<String>(endTime);
    if (!nullToAbsent || room != null) {
      map['room'] = Variable<String>(room);
    }
    return map;
  }

  LocalSchedulesCompanion toCompanion(bool nullToAbsent) {
    return LocalSchedulesCompanion(
      id: Value(id),
      subjectOfferingId: Value(subjectOfferingId),
      teacherId: Value(teacherId),
      dayOfWeek: Value(dayOfWeek),
      startTime: Value(startTime),
      endTime: Value(endTime),
      room: room == null && nullToAbsent ? const Value.absent() : Value(room),
    );
  }

  factory LocalSchedule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSchedule(
      id: serializer.fromJson<String>(json['id']),
      subjectOfferingId: serializer.fromJson<String>(json['subjectOfferingId']),
      teacherId: serializer.fromJson<String>(json['teacherId']),
      dayOfWeek: serializer.fromJson<String>(json['dayOfWeek']),
      startTime: serializer.fromJson<String>(json['startTime']),
      endTime: serializer.fromJson<String>(json['endTime']),
      room: serializer.fromJson<String?>(json['room']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'subjectOfferingId': serializer.toJson<String>(subjectOfferingId),
      'teacherId': serializer.toJson<String>(teacherId),
      'dayOfWeek': serializer.toJson<String>(dayOfWeek),
      'startTime': serializer.toJson<String>(startTime),
      'endTime': serializer.toJson<String>(endTime),
      'room': serializer.toJson<String?>(room),
    };
  }

  LocalSchedule copyWith({
    String? id,
    String? subjectOfferingId,
    String? teacherId,
    String? dayOfWeek,
    String? startTime,
    String? endTime,
    Value<String?> room = const Value.absent(),
  }) => LocalSchedule(
    id: id ?? this.id,
    subjectOfferingId: subjectOfferingId ?? this.subjectOfferingId,
    teacherId: teacherId ?? this.teacherId,
    dayOfWeek: dayOfWeek ?? this.dayOfWeek,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    room: room.present ? room.value : this.room,
  );
  LocalSchedule copyWithCompanion(LocalSchedulesCompanion data) {
    return LocalSchedule(
      id: data.id.present ? data.id.value : this.id,
      subjectOfferingId: data.subjectOfferingId.present
          ? data.subjectOfferingId.value
          : this.subjectOfferingId,
      teacherId: data.teacherId.present ? data.teacherId.value : this.teacherId,
      dayOfWeek: data.dayOfWeek.present ? data.dayOfWeek.value : this.dayOfWeek,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      room: data.room.present ? data.room.value : this.room,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSchedule(')
          ..write('id: $id, ')
          ..write('subjectOfferingId: $subjectOfferingId, ')
          ..write('teacherId: $teacherId, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('room: $room')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    subjectOfferingId,
    teacherId,
    dayOfWeek,
    startTime,
    endTime,
    room,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSchedule &&
          other.id == this.id &&
          other.subjectOfferingId == this.subjectOfferingId &&
          other.teacherId == this.teacherId &&
          other.dayOfWeek == this.dayOfWeek &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.room == this.room);
}

class LocalSchedulesCompanion extends UpdateCompanion<LocalSchedule> {
  final Value<String> id;
  final Value<String> subjectOfferingId;
  final Value<String> teacherId;
  final Value<String> dayOfWeek;
  final Value<String> startTime;
  final Value<String> endTime;
  final Value<String?> room;
  final Value<int> rowid;
  const LocalSchedulesCompanion({
    this.id = const Value.absent(),
    this.subjectOfferingId = const Value.absent(),
    this.teacherId = const Value.absent(),
    this.dayOfWeek = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.room = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSchedulesCompanion.insert({
    required String id,
    required String subjectOfferingId,
    required String teacherId,
    required String dayOfWeek,
    required String startTime,
    required String endTime,
    this.room = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       subjectOfferingId = Value(subjectOfferingId),
       teacherId = Value(teacherId),
       dayOfWeek = Value(dayOfWeek),
       startTime = Value(startTime),
       endTime = Value(endTime);
  static Insertable<LocalSchedule> custom({
    Expression<String>? id,
    Expression<String>? subjectOfferingId,
    Expression<String>? teacherId,
    Expression<String>? dayOfWeek,
    Expression<String>? startTime,
    Expression<String>? endTime,
    Expression<String>? room,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectOfferingId != null) 'subject_offering_id': subjectOfferingId,
      if (teacherId != null) 'teacher_id': teacherId,
      if (dayOfWeek != null) 'day_of_week': dayOfWeek,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (room != null) 'room': room,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSchedulesCompanion copyWith({
    Value<String>? id,
    Value<String>? subjectOfferingId,
    Value<String>? teacherId,
    Value<String>? dayOfWeek,
    Value<String>? startTime,
    Value<String>? endTime,
    Value<String?>? room,
    Value<int>? rowid,
  }) {
    return LocalSchedulesCompanion(
      id: id ?? this.id,
      subjectOfferingId: subjectOfferingId ?? this.subjectOfferingId,
      teacherId: teacherId ?? this.teacherId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      room: room ?? this.room,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (subjectOfferingId.present) {
      map['subject_offering_id'] = Variable<String>(subjectOfferingId.value);
    }
    if (teacherId.present) {
      map['teacher_id'] = Variable<String>(teacherId.value);
    }
    if (dayOfWeek.present) {
      map['day_of_week'] = Variable<String>(dayOfWeek.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<String>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<String>(endTime.value);
    }
    if (room.present) {
      map['room'] = Variable<String>(room.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSchedulesCompanion(')
          ..write('id: $id, ')
          ..write('subjectOfferingId: $subjectOfferingId, ')
          ..write('teacherId: $teacherId, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('room: $room, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAssessmentsTable extends LocalAssessments
    with TableInfo<$LocalAssessmentsTable, LocalAssessment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAssessmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectOfferingIdMeta = const VerificationMeta(
    'subjectOfferingId',
  );
  @override
  late final GeneratedColumn<String> subjectOfferingId =
      GeneratedColumn<String>(
        'subject_offering_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _componentMeta = const VerificationMeta(
    'component',
  );
  @override
  late final GeneratedColumn<String> component = GeneratedColumn<String>(
    'component',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalScoreMeta = const VerificationMeta(
    'totalScore',
  );
  @override
  late final GeneratedColumn<double> totalScore = GeneratedColumn<double>(
    'total_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quarterMeta = const VerificationMeta(
    'quarter',
  );
  @override
  late final GeneratedColumn<int> quarter = GeneratedColumn<int>(
    'quarter',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectOfferingId,
    title,
    component,
    totalScore,
    quarter,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_assessments';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalAssessment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('subject_offering_id')) {
      context.handle(
        _subjectOfferingIdMeta,
        subjectOfferingId.isAcceptableOrUnknown(
          data['subject_offering_id']!,
          _subjectOfferingIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectOfferingIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('component')) {
      context.handle(
        _componentMeta,
        component.isAcceptableOrUnknown(data['component']!, _componentMeta),
      );
    } else if (isInserting) {
      context.missing(_componentMeta);
    }
    if (data.containsKey('total_score')) {
      context.handle(
        _totalScoreMeta,
        totalScore.isAcceptableOrUnknown(data['total_score']!, _totalScoreMeta),
      );
    } else if (isInserting) {
      context.missing(_totalScoreMeta);
    }
    if (data.containsKey('quarter')) {
      context.handle(
        _quarterMeta,
        quarter.isAcceptableOrUnknown(data['quarter']!, _quarterMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalAssessment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAssessment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      subjectOfferingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_offering_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      component: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}component'],
      )!,
      totalScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_score'],
      )!,
      quarter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quarter'],
      )!,
    );
  }

  @override
  $LocalAssessmentsTable createAlias(String alias) {
    return $LocalAssessmentsTable(attachedDatabase, alias);
  }
}

class LocalAssessment extends DataClass implements Insertable<LocalAssessment> {
  final String id;
  final String subjectOfferingId;
  final String title;
  final String component;
  final double totalScore;
  final int quarter;
  const LocalAssessment({
    required this.id,
    required this.subjectOfferingId,
    required this.title,
    required this.component,
    required this.totalScore,
    required this.quarter,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['subject_offering_id'] = Variable<String>(subjectOfferingId);
    map['title'] = Variable<String>(title);
    map['component'] = Variable<String>(component);
    map['total_score'] = Variable<double>(totalScore);
    map['quarter'] = Variable<int>(quarter);
    return map;
  }

  LocalAssessmentsCompanion toCompanion(bool nullToAbsent) {
    return LocalAssessmentsCompanion(
      id: Value(id),
      subjectOfferingId: Value(subjectOfferingId),
      title: Value(title),
      component: Value(component),
      totalScore: Value(totalScore),
      quarter: Value(quarter),
    );
  }

  factory LocalAssessment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAssessment(
      id: serializer.fromJson<String>(json['id']),
      subjectOfferingId: serializer.fromJson<String>(json['subjectOfferingId']),
      title: serializer.fromJson<String>(json['title']),
      component: serializer.fromJson<String>(json['component']),
      totalScore: serializer.fromJson<double>(json['totalScore']),
      quarter: serializer.fromJson<int>(json['quarter']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'subjectOfferingId': serializer.toJson<String>(subjectOfferingId),
      'title': serializer.toJson<String>(title),
      'component': serializer.toJson<String>(component),
      'totalScore': serializer.toJson<double>(totalScore),
      'quarter': serializer.toJson<int>(quarter),
    };
  }

  LocalAssessment copyWith({
    String? id,
    String? subjectOfferingId,
    String? title,
    String? component,
    double? totalScore,
    int? quarter,
  }) => LocalAssessment(
    id: id ?? this.id,
    subjectOfferingId: subjectOfferingId ?? this.subjectOfferingId,
    title: title ?? this.title,
    component: component ?? this.component,
    totalScore: totalScore ?? this.totalScore,
    quarter: quarter ?? this.quarter,
  );
  LocalAssessment copyWithCompanion(LocalAssessmentsCompanion data) {
    return LocalAssessment(
      id: data.id.present ? data.id.value : this.id,
      subjectOfferingId: data.subjectOfferingId.present
          ? data.subjectOfferingId.value
          : this.subjectOfferingId,
      title: data.title.present ? data.title.value : this.title,
      component: data.component.present ? data.component.value : this.component,
      totalScore: data.totalScore.present
          ? data.totalScore.value
          : this.totalScore,
      quarter: data.quarter.present ? data.quarter.value : this.quarter,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAssessment(')
          ..write('id: $id, ')
          ..write('subjectOfferingId: $subjectOfferingId, ')
          ..write('title: $title, ')
          ..write('component: $component, ')
          ..write('totalScore: $totalScore, ')
          ..write('quarter: $quarter')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, subjectOfferingId, title, component, totalScore, quarter);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAssessment &&
          other.id == this.id &&
          other.subjectOfferingId == this.subjectOfferingId &&
          other.title == this.title &&
          other.component == this.component &&
          other.totalScore == this.totalScore &&
          other.quarter == this.quarter);
}

class LocalAssessmentsCompanion extends UpdateCompanion<LocalAssessment> {
  final Value<String> id;
  final Value<String> subjectOfferingId;
  final Value<String> title;
  final Value<String> component;
  final Value<double> totalScore;
  final Value<int> quarter;
  final Value<int> rowid;
  const LocalAssessmentsCompanion({
    this.id = const Value.absent(),
    this.subjectOfferingId = const Value.absent(),
    this.title = const Value.absent(),
    this.component = const Value.absent(),
    this.totalScore = const Value.absent(),
    this.quarter = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAssessmentsCompanion.insert({
    required String id,
    required String subjectOfferingId,
    required String title,
    required String component,
    required double totalScore,
    this.quarter = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       subjectOfferingId = Value(subjectOfferingId),
       title = Value(title),
       component = Value(component),
       totalScore = Value(totalScore);
  static Insertable<LocalAssessment> custom({
    Expression<String>? id,
    Expression<String>? subjectOfferingId,
    Expression<String>? title,
    Expression<String>? component,
    Expression<double>? totalScore,
    Expression<int>? quarter,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectOfferingId != null) 'subject_offering_id': subjectOfferingId,
      if (title != null) 'title': title,
      if (component != null) 'component': component,
      if (totalScore != null) 'total_score': totalScore,
      if (quarter != null) 'quarter': quarter,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAssessmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? subjectOfferingId,
    Value<String>? title,
    Value<String>? component,
    Value<double>? totalScore,
    Value<int>? quarter,
    Value<int>? rowid,
  }) {
    return LocalAssessmentsCompanion(
      id: id ?? this.id,
      subjectOfferingId: subjectOfferingId ?? this.subjectOfferingId,
      title: title ?? this.title,
      component: component ?? this.component,
      totalScore: totalScore ?? this.totalScore,
      quarter: quarter ?? this.quarter,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (subjectOfferingId.present) {
      map['subject_offering_id'] = Variable<String>(subjectOfferingId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (component.present) {
      map['component'] = Variable<String>(component.value);
    }
    if (totalScore.present) {
      map['total_score'] = Variable<double>(totalScore.value);
    }
    if (quarter.present) {
      map['quarter'] = Variable<int>(quarter.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAssessmentsCompanion(')
          ..write('id: $id, ')
          ..write('subjectOfferingId: $subjectOfferingId, ')
          ..write('title: $title, ')
          ..write('component: $component, ')
          ..write('totalScore: $totalScore, ')
          ..write('quarter: $quarter, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalStudentScoresTable extends LocalStudentScores
    with TableInfo<$LocalStudentScoresTable, LocalStudentScore> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalStudentScoresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assessmentIdMeta = const VerificationMeta(
    'assessmentId',
  );
  @override
  late final GeneratedColumn<String> assessmentId = GeneratedColumn<String>(
    'assessment_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _studentIdMeta = const VerificationMeta(
    'studentId',
  );
  @override
  late final GeneratedColumn<String> studentId = GeneratedColumn<String>(
    'student_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remarksMeta = const VerificationMeta(
    'remarks',
  );
  @override
  late final GeneratedColumn<String> remarks = GeneratedColumn<String>(
    'remarks',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    assessmentId,
    studentId,
    score,
    remarks,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_student_scores';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalStudentScore> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('assessment_id')) {
      context.handle(
        _assessmentIdMeta,
        assessmentId.isAcceptableOrUnknown(
          data['assessment_id']!,
          _assessmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_assessmentIdMeta);
    }
    if (data.containsKey('student_id')) {
      context.handle(
        _studentIdMeta,
        studentId.isAcceptableOrUnknown(data['student_id']!, _studentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studentIdMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('remarks')) {
      context.handle(
        _remarksMeta,
        remarks.isAcceptableOrUnknown(data['remarks']!, _remarksMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalStudentScore map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalStudentScore(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      assessmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assessment_id'],
      )!,
      studentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}student_id'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}score'],
      )!,
      remarks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remarks'],
      ),
    );
  }

  @override
  $LocalStudentScoresTable createAlias(String alias) {
    return $LocalStudentScoresTable(attachedDatabase, alias);
  }
}

class LocalStudentScore extends DataClass
    implements Insertable<LocalStudentScore> {
  final String id;
  final String assessmentId;
  final String studentId;
  final double score;
  final String? remarks;
  const LocalStudentScore({
    required this.id,
    required this.assessmentId,
    required this.studentId,
    required this.score,
    this.remarks,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['assessment_id'] = Variable<String>(assessmentId);
    map['student_id'] = Variable<String>(studentId);
    map['score'] = Variable<double>(score);
    if (!nullToAbsent || remarks != null) {
      map['remarks'] = Variable<String>(remarks);
    }
    return map;
  }

  LocalStudentScoresCompanion toCompanion(bool nullToAbsent) {
    return LocalStudentScoresCompanion(
      id: Value(id),
      assessmentId: Value(assessmentId),
      studentId: Value(studentId),
      score: Value(score),
      remarks: remarks == null && nullToAbsent
          ? const Value.absent()
          : Value(remarks),
    );
  }

  factory LocalStudentScore.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalStudentScore(
      id: serializer.fromJson<String>(json['id']),
      assessmentId: serializer.fromJson<String>(json['assessmentId']),
      studentId: serializer.fromJson<String>(json['studentId']),
      score: serializer.fromJson<double>(json['score']),
      remarks: serializer.fromJson<String?>(json['remarks']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'assessmentId': serializer.toJson<String>(assessmentId),
      'studentId': serializer.toJson<String>(studentId),
      'score': serializer.toJson<double>(score),
      'remarks': serializer.toJson<String?>(remarks),
    };
  }

  LocalStudentScore copyWith({
    String? id,
    String? assessmentId,
    String? studentId,
    double? score,
    Value<String?> remarks = const Value.absent(),
  }) => LocalStudentScore(
    id: id ?? this.id,
    assessmentId: assessmentId ?? this.assessmentId,
    studentId: studentId ?? this.studentId,
    score: score ?? this.score,
    remarks: remarks.present ? remarks.value : this.remarks,
  );
  LocalStudentScore copyWithCompanion(LocalStudentScoresCompanion data) {
    return LocalStudentScore(
      id: data.id.present ? data.id.value : this.id,
      assessmentId: data.assessmentId.present
          ? data.assessmentId.value
          : this.assessmentId,
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      score: data.score.present ? data.score.value : this.score,
      remarks: data.remarks.present ? data.remarks.value : this.remarks,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalStudentScore(')
          ..write('id: $id, ')
          ..write('assessmentId: $assessmentId, ')
          ..write('studentId: $studentId, ')
          ..write('score: $score, ')
          ..write('remarks: $remarks')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, assessmentId, studentId, score, remarks);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalStudentScore &&
          other.id == this.id &&
          other.assessmentId == this.assessmentId &&
          other.studentId == this.studentId &&
          other.score == this.score &&
          other.remarks == this.remarks);
}

class LocalStudentScoresCompanion extends UpdateCompanion<LocalStudentScore> {
  final Value<String> id;
  final Value<String> assessmentId;
  final Value<String> studentId;
  final Value<double> score;
  final Value<String?> remarks;
  final Value<int> rowid;
  const LocalStudentScoresCompanion({
    this.id = const Value.absent(),
    this.assessmentId = const Value.absent(),
    this.studentId = const Value.absent(),
    this.score = const Value.absent(),
    this.remarks = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalStudentScoresCompanion.insert({
    required String id,
    required String assessmentId,
    required String studentId,
    required double score,
    this.remarks = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       assessmentId = Value(assessmentId),
       studentId = Value(studentId),
       score = Value(score);
  static Insertable<LocalStudentScore> custom({
    Expression<String>? id,
    Expression<String>? assessmentId,
    Expression<String>? studentId,
    Expression<double>? score,
    Expression<String>? remarks,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (assessmentId != null) 'assessment_id': assessmentId,
      if (studentId != null) 'student_id': studentId,
      if (score != null) 'score': score,
      if (remarks != null) 'remarks': remarks,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalStudentScoresCompanion copyWith({
    Value<String>? id,
    Value<String>? assessmentId,
    Value<String>? studentId,
    Value<double>? score,
    Value<String?>? remarks,
    Value<int>? rowid,
  }) {
    return LocalStudentScoresCompanion(
      id: id ?? this.id,
      assessmentId: assessmentId ?? this.assessmentId,
      studentId: studentId ?? this.studentId,
      score: score ?? this.score,
      remarks: remarks ?? this.remarks,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (assessmentId.present) {
      map['assessment_id'] = Variable<String>(assessmentId.value);
    }
    if (studentId.present) {
      map['student_id'] = Variable<String>(studentId.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (remarks.present) {
      map['remarks'] = Variable<String>(remarks.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalStudentScoresCompanion(')
          ..write('id: $id, ')
          ..write('assessmentId: $assessmentId, ')
          ..write('studentId: $studentId, ')
          ..write('score: $score, ')
          ..write('remarks: $remarks, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OfflineSyncQueueTable extends OfflineSyncQueue
    with TableInfo<$OfflineSyncQueueTable, OfflineSyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineSyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetTableMeta = const VerificationMeta(
    'targetTable',
  );
  @override
  late final GeneratedColumn<String> targetTable = GeneratedColumn<String>(
    'target_table',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    action,
    targetTable,
    payloadJson,
    createdAt,
    retryCount,
    status,
    errorMessage,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfflineSyncQueueData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('target_table')) {
      context.handle(
        _targetTableMeta,
        targetTable.isAcceptableOrUnknown(
          data['target_table']!,
          _targetTableMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetTableMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OfflineSyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineSyncQueueData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      targetTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_table'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
    );
  }

  @override
  $OfflineSyncQueueTable createAlias(String alias) {
    return $OfflineSyncQueueTable(attachedDatabase, alias);
  }
}

class OfflineSyncQueueData extends DataClass
    implements Insertable<OfflineSyncQueueData> {
  final String id;
  final String action;
  final String targetTable;
  final String payloadJson;
  final DateTime createdAt;
  final int retryCount;
  final String status;
  final String? errorMessage;
  const OfflineSyncQueueData({
    required this.id,
    required this.action,
    required this.targetTable,
    required this.payloadJson,
    required this.createdAt,
    required this.retryCount,
    required this.status,
    this.errorMessage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['action'] = Variable<String>(action);
    map['target_table'] = Variable<String>(targetTable);
    map['payload_json'] = Variable<String>(payloadJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['retry_count'] = Variable<int>(retryCount);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    return map;
  }

  OfflineSyncQueueCompanion toCompanion(bool nullToAbsent) {
    return OfflineSyncQueueCompanion(
      id: Value(id),
      action: Value(action),
      targetTable: Value(targetTable),
      payloadJson: Value(payloadJson),
      createdAt: Value(createdAt),
      retryCount: Value(retryCount),
      status: Value(status),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
    );
  }

  factory OfflineSyncQueueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineSyncQueueData(
      id: serializer.fromJson<String>(json['id']),
      action: serializer.fromJson<String>(json['action']),
      targetTable: serializer.fromJson<String>(json['targetTable']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      status: serializer.fromJson<String>(json['status']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'action': serializer.toJson<String>(action),
      'targetTable': serializer.toJson<String>(targetTable),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'retryCount': serializer.toJson<int>(retryCount),
      'status': serializer.toJson<String>(status),
      'errorMessage': serializer.toJson<String?>(errorMessage),
    };
  }

  OfflineSyncQueueData copyWith({
    String? id,
    String? action,
    String? targetTable,
    String? payloadJson,
    DateTime? createdAt,
    int? retryCount,
    String? status,
    Value<String?> errorMessage = const Value.absent(),
  }) => OfflineSyncQueueData(
    id: id ?? this.id,
    action: action ?? this.action,
    targetTable: targetTable ?? this.targetTable,
    payloadJson: payloadJson ?? this.payloadJson,
    createdAt: createdAt ?? this.createdAt,
    retryCount: retryCount ?? this.retryCount,
    status: status ?? this.status,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
  );
  OfflineSyncQueueData copyWithCompanion(OfflineSyncQueueCompanion data) {
    return OfflineSyncQueueData(
      id: data.id.present ? data.id.value : this.id,
      action: data.action.present ? data.action.value : this.action,
      targetTable: data.targetTable.present
          ? data.targetTable.value
          : this.targetTable,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      status: data.status.present ? data.status.value : this.status,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineSyncQueueData(')
          ..write('id: $id, ')
          ..write('action: $action, ')
          ..write('targetTable: $targetTable, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('status: $status, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    action,
    targetTable,
    payloadJson,
    createdAt,
    retryCount,
    status,
    errorMessage,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineSyncQueueData &&
          other.id == this.id &&
          other.action == this.action &&
          other.targetTable == this.targetTable &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt &&
          other.retryCount == this.retryCount &&
          other.status == this.status &&
          other.errorMessage == this.errorMessage);
}

class OfflineSyncQueueCompanion extends UpdateCompanion<OfflineSyncQueueData> {
  final Value<String> id;
  final Value<String> action;
  final Value<String> targetTable;
  final Value<String> payloadJson;
  final Value<DateTime> createdAt;
  final Value<int> retryCount;
  final Value<String> status;
  final Value<String?> errorMessage;
  final Value<int> rowid;
  const OfflineSyncQueueCompanion({
    this.id = const Value.absent(),
    this.action = const Value.absent(),
    this.targetTable = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.status = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OfflineSyncQueueCompanion.insert({
    required String id,
    required String action,
    required String targetTable,
    required String payloadJson,
    this.createdAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.status = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       action = Value(action),
       targetTable = Value(targetTable),
       payloadJson = Value(payloadJson);
  static Insertable<OfflineSyncQueueData> custom({
    Expression<String>? id,
    Expression<String>? action,
    Expression<String>? targetTable,
    Expression<String>? payloadJson,
    Expression<DateTime>? createdAt,
    Expression<int>? retryCount,
    Expression<String>? status,
    Expression<String>? errorMessage,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (action != null) 'action': action,
      if (targetTable != null) 'target_table': targetTable,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (retryCount != null) 'retry_count': retryCount,
      if (status != null) 'status': status,
      if (errorMessage != null) 'error_message': errorMessage,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OfflineSyncQueueCompanion copyWith({
    Value<String>? id,
    Value<String>? action,
    Value<String>? targetTable,
    Value<String>? payloadJson,
    Value<DateTime>? createdAt,
    Value<int>? retryCount,
    Value<String>? status,
    Value<String?>? errorMessage,
    Value<int>? rowid,
  }) {
    return OfflineSyncQueueCompanion(
      id: id ?? this.id,
      action: action ?? this.action,
      targetTable: targetTable ?? this.targetTable,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (targetTable.present) {
      map['target_table'] = Variable<String>(targetTable.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflineSyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('action: $action, ')
          ..write('targetTable: $targetTable, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('status: $status, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalSettingsTable localSettings = $LocalSettingsTable(this);
  late final $LocalUserProfilesTable localUserProfiles =
      $LocalUserProfilesTable(this);
  late final $LocalSubjectsTable localSubjects = $LocalSubjectsTable(this);
  late final $LocalSectionsTable localSections = $LocalSectionsTable(this);
  late final $LocalSubjectOfferingsTable localSubjectOfferings =
      $LocalSubjectOfferingsTable(this);
  late final $LocalStudentsTable localStudents = $LocalStudentsTable(this);
  late final $LocalEnrollmentsTable localEnrollments = $LocalEnrollmentsTable(
    this,
  );
  late final $LocalParentsTable localParents = $LocalParentsTable(this);
  late final $LocalParentStudentLinksTable localParentStudentLinks =
      $LocalParentStudentLinksTable(this);
  late final $LocalAttendanceRecordsTable localAttendanceRecords =
      $LocalAttendanceRecordsTable(this);
  late final $LocalAttendanceCutoffsTable localAttendanceCutoffs =
      $LocalAttendanceCutoffsTable(this);
  late final $LocalSchedulesTable localSchedules = $LocalSchedulesTable(this);
  late final $LocalAssessmentsTable localAssessments = $LocalAssessmentsTable(
    this,
  );
  late final $LocalStudentScoresTable localStudentScores =
      $LocalStudentScoresTable(this);
  late final $OfflineSyncQueueTable offlineSyncQueue = $OfflineSyncQueueTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localSettings,
    localUserProfiles,
    localSubjects,
    localSections,
    localSubjectOfferings,
    localStudents,
    localEnrollments,
    localParents,
    localParentStudentLinks,
    localAttendanceRecords,
    localAttendanceCutoffs,
    localSchedules,
    localAssessments,
    localStudentScores,
    offlineSyncQueue,
  ];
}

typedef $$LocalSettingsTableCreateCompanionBuilder =
    LocalSettingsCompanion Function({
      required String key,
      required String value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$LocalSettingsTableUpdateCompanionBuilder =
    LocalSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSettingsTable> {
  $$LocalSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSettingsTable> {
  $$LocalSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSettingsTable> {
  $$LocalSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSettingsTable,
          LocalSetting,
          $$LocalSettingsTableFilterComposer,
          $$LocalSettingsTableOrderingComposer,
          $$LocalSettingsTableAnnotationComposer,
          $$LocalSettingsTableCreateCompanionBuilder,
          $$LocalSettingsTableUpdateCompanionBuilder,
          (
            LocalSetting,
            BaseReferences<_$AppDatabase, $LocalSettingsTable, LocalSetting>,
          ),
          LocalSetting,
          PrefetchHooks Function()
        > {
  $$LocalSettingsTableTableManager(_$AppDatabase db, $LocalSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSettingsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSettingsCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSettingsTable,
      LocalSetting,
      $$LocalSettingsTableFilterComposer,
      $$LocalSettingsTableOrderingComposer,
      $$LocalSettingsTableAnnotationComposer,
      $$LocalSettingsTableCreateCompanionBuilder,
      $$LocalSettingsTableUpdateCompanionBuilder,
      (
        LocalSetting,
        BaseReferences<_$AppDatabase, $LocalSettingsTable, LocalSetting>,
      ),
      LocalSetting,
      PrefetchHooks Function()
    >;
typedef $$LocalUserProfilesTableCreateCompanionBuilder =
    LocalUserProfilesCompanion Function({
      required String id,
      required String email,
      required String role,
      Value<String> firstName,
      Value<String?> middleName,
      Value<String> lastName,
      Value<String> status,
      Value<bool> isArchived,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$LocalUserProfilesTableUpdateCompanionBuilder =
    LocalUserProfilesCompanion Function({
      Value<String> id,
      Value<String> email,
      Value<String> role,
      Value<String> firstName,
      Value<String?> middleName,
      Value<String> lastName,
      Value<String> status,
      Value<bool> isArchived,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalUserProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalUserProfilesTable> {
  $$LocalUserProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firstName => $composableBuilder(
    column: $table.firstName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get middleName => $composableBuilder(
    column: $table.middleName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastName => $composableBuilder(
    column: $table.lastName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalUserProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalUserProfilesTable> {
  $$LocalUserProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firstName => $composableBuilder(
    column: $table.firstName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get middleName => $composableBuilder(
    column: $table.middleName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastName => $composableBuilder(
    column: $table.lastName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalUserProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalUserProfilesTable> {
  $$LocalUserProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get firstName =>
      $composableBuilder(column: $table.firstName, builder: (column) => column);

  GeneratedColumn<String> get middleName => $composableBuilder(
    column: $table.middleName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastName =>
      $composableBuilder(column: $table.lastName, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalUserProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalUserProfilesTable,
          LocalUserProfile,
          $$LocalUserProfilesTableFilterComposer,
          $$LocalUserProfilesTableOrderingComposer,
          $$LocalUserProfilesTableAnnotationComposer,
          $$LocalUserProfilesTableCreateCompanionBuilder,
          $$LocalUserProfilesTableUpdateCompanionBuilder,
          (
            LocalUserProfile,
            BaseReferences<
              _$AppDatabase,
              $LocalUserProfilesTable,
              LocalUserProfile
            >,
          ),
          LocalUserProfile,
          PrefetchHooks Function()
        > {
  $$LocalUserProfilesTableTableManager(
    _$AppDatabase db,
    $LocalUserProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalUserProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalUserProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalUserProfilesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> firstName = const Value.absent(),
                Value<String?> middleName = const Value.absent(),
                Value<String> lastName = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalUserProfilesCompanion(
                id: id,
                email: email,
                role: role,
                firstName: firstName,
                middleName: middleName,
                lastName: lastName,
                status: status,
                isArchived: isArchived,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String email,
                required String role,
                Value<String> firstName = const Value.absent(),
                Value<String?> middleName = const Value.absent(),
                Value<String> lastName = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalUserProfilesCompanion.insert(
                id: id,
                email: email,
                role: role,
                firstName: firstName,
                middleName: middleName,
                lastName: lastName,
                status: status,
                isArchived: isArchived,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalUserProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalUserProfilesTable,
      LocalUserProfile,
      $$LocalUserProfilesTableFilterComposer,
      $$LocalUserProfilesTableOrderingComposer,
      $$LocalUserProfilesTableAnnotationComposer,
      $$LocalUserProfilesTableCreateCompanionBuilder,
      $$LocalUserProfilesTableUpdateCompanionBuilder,
      (
        LocalUserProfile,
        BaseReferences<
          _$AppDatabase,
          $LocalUserProfilesTable,
          LocalUserProfile
        >,
      ),
      LocalUserProfile,
      PrefetchHooks Function()
    >;
typedef $$LocalSubjectsTableCreateCompanionBuilder =
    LocalSubjectsCompanion Function({
      required String id,
      required String subjectCode,
      required String subjectName,
      required int gradeLevel,
      Value<bool> isArchived,
      Value<int> rowid,
    });
typedef $$LocalSubjectsTableUpdateCompanionBuilder =
    LocalSubjectsCompanion Function({
      Value<String> id,
      Value<String> subjectCode,
      Value<String> subjectName,
      Value<int> gradeLevel,
      Value<bool> isArchived,
      Value<int> rowid,
    });

class $$LocalSubjectsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSubjectsTable> {
  $$LocalSubjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectCode => $composableBuilder(
    column: $table.subjectCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectName => $composableBuilder(
    column: $table.subjectName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gradeLevel => $composableBuilder(
    column: $table.gradeLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSubjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSubjectsTable> {
  $$LocalSubjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectCode => $composableBuilder(
    column: $table.subjectCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectName => $composableBuilder(
    column: $table.subjectName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gradeLevel => $composableBuilder(
    column: $table.gradeLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSubjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSubjectsTable> {
  $$LocalSubjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get subjectCode => $composableBuilder(
    column: $table.subjectCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subjectName => $composableBuilder(
    column: $table.subjectName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gradeLevel => $composableBuilder(
    column: $table.gradeLevel,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );
}

class $$LocalSubjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSubjectsTable,
          LocalSubject,
          $$LocalSubjectsTableFilterComposer,
          $$LocalSubjectsTableOrderingComposer,
          $$LocalSubjectsTableAnnotationComposer,
          $$LocalSubjectsTableCreateCompanionBuilder,
          $$LocalSubjectsTableUpdateCompanionBuilder,
          (
            LocalSubject,
            BaseReferences<_$AppDatabase, $LocalSubjectsTable, LocalSubject>,
          ),
          LocalSubject,
          PrefetchHooks Function()
        > {
  $$LocalSubjectsTableTableManager(_$AppDatabase db, $LocalSubjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSubjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSubjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSubjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> subjectCode = const Value.absent(),
                Value<String> subjectName = const Value.absent(),
                Value<int> gradeLevel = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSubjectsCompanion(
                id: id,
                subjectCode: subjectCode,
                subjectName: subjectName,
                gradeLevel: gradeLevel,
                isArchived: isArchived,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String subjectCode,
                required String subjectName,
                required int gradeLevel,
                Value<bool> isArchived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSubjectsCompanion.insert(
                id: id,
                subjectCode: subjectCode,
                subjectName: subjectName,
                gradeLevel: gradeLevel,
                isArchived: isArchived,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSubjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSubjectsTable,
      LocalSubject,
      $$LocalSubjectsTableFilterComposer,
      $$LocalSubjectsTableOrderingComposer,
      $$LocalSubjectsTableAnnotationComposer,
      $$LocalSubjectsTableCreateCompanionBuilder,
      $$LocalSubjectsTableUpdateCompanionBuilder,
      (
        LocalSubject,
        BaseReferences<_$AppDatabase, $LocalSubjectsTable, LocalSubject>,
      ),
      LocalSubject,
      PrefetchHooks Function()
    >;
typedef $$LocalSectionsTableCreateCompanionBuilder =
    LocalSectionsCompanion Function({
      required String id,
      required String sectionName,
      required int gradeLevel,
      Value<String> schoolYear,
      Value<bool> isArchived,
      Value<int> rowid,
    });
typedef $$LocalSectionsTableUpdateCompanionBuilder =
    LocalSectionsCompanion Function({
      Value<String> id,
      Value<String> sectionName,
      Value<int> gradeLevel,
      Value<String> schoolYear,
      Value<bool> isArchived,
      Value<int> rowid,
    });

class $$LocalSectionsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSectionsTable> {
  $$LocalSectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionName => $composableBuilder(
    column: $table.sectionName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gradeLevel => $composableBuilder(
    column: $table.gradeLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schoolYear => $composableBuilder(
    column: $table.schoolYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSectionsTable> {
  $$LocalSectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionName => $composableBuilder(
    column: $table.sectionName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gradeLevel => $composableBuilder(
    column: $table.gradeLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schoolYear => $composableBuilder(
    column: $table.schoolYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSectionsTable> {
  $$LocalSectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sectionName => $composableBuilder(
    column: $table.sectionName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gradeLevel => $composableBuilder(
    column: $table.gradeLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get schoolYear => $composableBuilder(
    column: $table.schoolYear,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );
}

class $$LocalSectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSectionsTable,
          LocalSection,
          $$LocalSectionsTableFilterComposer,
          $$LocalSectionsTableOrderingComposer,
          $$LocalSectionsTableAnnotationComposer,
          $$LocalSectionsTableCreateCompanionBuilder,
          $$LocalSectionsTableUpdateCompanionBuilder,
          (
            LocalSection,
            BaseReferences<_$AppDatabase, $LocalSectionsTable, LocalSection>,
          ),
          LocalSection,
          PrefetchHooks Function()
        > {
  $$LocalSectionsTableTableManager(_$AppDatabase db, $LocalSectionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sectionName = const Value.absent(),
                Value<int> gradeLevel = const Value.absent(),
                Value<String> schoolYear = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSectionsCompanion(
                id: id,
                sectionName: sectionName,
                gradeLevel: gradeLevel,
                schoolYear: schoolYear,
                isArchived: isArchived,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sectionName,
                required int gradeLevel,
                Value<String> schoolYear = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSectionsCompanion.insert(
                id: id,
                sectionName: sectionName,
                gradeLevel: gradeLevel,
                schoolYear: schoolYear,
                isArchived: isArchived,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSectionsTable,
      LocalSection,
      $$LocalSectionsTableFilterComposer,
      $$LocalSectionsTableOrderingComposer,
      $$LocalSectionsTableAnnotationComposer,
      $$LocalSectionsTableCreateCompanionBuilder,
      $$LocalSectionsTableUpdateCompanionBuilder,
      (
        LocalSection,
        BaseReferences<_$AppDatabase, $LocalSectionsTable, LocalSection>,
      ),
      LocalSection,
      PrefetchHooks Function()
    >;
typedef $$LocalSubjectOfferingsTableCreateCompanionBuilder =
    LocalSubjectOfferingsCompanion Function({
      required String id,
      required String teacherId,
      required String subjectId,
      required String sectionId,
      required String subjectName,
      required String sectionName,
      required int gradeLevel,
      Value<double> wwWeight,
      Value<double> ptWeight,
      Value<double> exWeight,
      Value<String> schoolYear,
      Value<bool> isArchived,
      Value<int> rowid,
    });
typedef $$LocalSubjectOfferingsTableUpdateCompanionBuilder =
    LocalSubjectOfferingsCompanion Function({
      Value<String> id,
      Value<String> teacherId,
      Value<String> subjectId,
      Value<String> sectionId,
      Value<String> subjectName,
      Value<String> sectionName,
      Value<int> gradeLevel,
      Value<double> wwWeight,
      Value<double> ptWeight,
      Value<double> exWeight,
      Value<String> schoolYear,
      Value<bool> isArchived,
      Value<int> rowid,
    });

class $$LocalSubjectOfferingsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSubjectOfferingsTable> {
  $$LocalSubjectOfferingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get teacherId => $composableBuilder(
    column: $table.teacherId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectName => $composableBuilder(
    column: $table.subjectName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionName => $composableBuilder(
    column: $table.sectionName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gradeLevel => $composableBuilder(
    column: $table.gradeLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get wwWeight => $composableBuilder(
    column: $table.wwWeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ptWeight => $composableBuilder(
    column: $table.ptWeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get exWeight => $composableBuilder(
    column: $table.exWeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schoolYear => $composableBuilder(
    column: $table.schoolYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSubjectOfferingsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSubjectOfferingsTable> {
  $$LocalSubjectOfferingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get teacherId => $composableBuilder(
    column: $table.teacherId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionId => $composableBuilder(
    column: $table.sectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectName => $composableBuilder(
    column: $table.subjectName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionName => $composableBuilder(
    column: $table.sectionName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gradeLevel => $composableBuilder(
    column: $table.gradeLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get wwWeight => $composableBuilder(
    column: $table.wwWeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ptWeight => $composableBuilder(
    column: $table.ptWeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get exWeight => $composableBuilder(
    column: $table.exWeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schoolYear => $composableBuilder(
    column: $table.schoolYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSubjectOfferingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSubjectOfferingsTable> {
  $$LocalSubjectOfferingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get teacherId =>
      $composableBuilder(column: $table.teacherId, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get sectionId =>
      $composableBuilder(column: $table.sectionId, builder: (column) => column);

  GeneratedColumn<String> get subjectName => $composableBuilder(
    column: $table.subjectName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sectionName => $composableBuilder(
    column: $table.sectionName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gradeLevel => $composableBuilder(
    column: $table.gradeLevel,
    builder: (column) => column,
  );

  GeneratedColumn<double> get wwWeight =>
      $composableBuilder(column: $table.wwWeight, builder: (column) => column);

  GeneratedColumn<double> get ptWeight =>
      $composableBuilder(column: $table.ptWeight, builder: (column) => column);

  GeneratedColumn<double> get exWeight =>
      $composableBuilder(column: $table.exWeight, builder: (column) => column);

  GeneratedColumn<String> get schoolYear => $composableBuilder(
    column: $table.schoolYear,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );
}

class $$LocalSubjectOfferingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSubjectOfferingsTable,
          LocalSubjectOffering,
          $$LocalSubjectOfferingsTableFilterComposer,
          $$LocalSubjectOfferingsTableOrderingComposer,
          $$LocalSubjectOfferingsTableAnnotationComposer,
          $$LocalSubjectOfferingsTableCreateCompanionBuilder,
          $$LocalSubjectOfferingsTableUpdateCompanionBuilder,
          (
            LocalSubjectOffering,
            BaseReferences<
              _$AppDatabase,
              $LocalSubjectOfferingsTable,
              LocalSubjectOffering
            >,
          ),
          LocalSubjectOffering,
          PrefetchHooks Function()
        > {
  $$LocalSubjectOfferingsTableTableManager(
    _$AppDatabase db,
    $LocalSubjectOfferingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSubjectOfferingsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalSubjectOfferingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalSubjectOfferingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> teacherId = const Value.absent(),
                Value<String> subjectId = const Value.absent(),
                Value<String> sectionId = const Value.absent(),
                Value<String> subjectName = const Value.absent(),
                Value<String> sectionName = const Value.absent(),
                Value<int> gradeLevel = const Value.absent(),
                Value<double> wwWeight = const Value.absent(),
                Value<double> ptWeight = const Value.absent(),
                Value<double> exWeight = const Value.absent(),
                Value<String> schoolYear = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSubjectOfferingsCompanion(
                id: id,
                teacherId: teacherId,
                subjectId: subjectId,
                sectionId: sectionId,
                subjectName: subjectName,
                sectionName: sectionName,
                gradeLevel: gradeLevel,
                wwWeight: wwWeight,
                ptWeight: ptWeight,
                exWeight: exWeight,
                schoolYear: schoolYear,
                isArchived: isArchived,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String teacherId,
                required String subjectId,
                required String sectionId,
                required String subjectName,
                required String sectionName,
                required int gradeLevel,
                Value<double> wwWeight = const Value.absent(),
                Value<double> ptWeight = const Value.absent(),
                Value<double> exWeight = const Value.absent(),
                Value<String> schoolYear = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSubjectOfferingsCompanion.insert(
                id: id,
                teacherId: teacherId,
                subjectId: subjectId,
                sectionId: sectionId,
                subjectName: subjectName,
                sectionName: sectionName,
                gradeLevel: gradeLevel,
                wwWeight: wwWeight,
                ptWeight: ptWeight,
                exWeight: exWeight,
                schoolYear: schoolYear,
                isArchived: isArchived,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSubjectOfferingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSubjectOfferingsTable,
      LocalSubjectOffering,
      $$LocalSubjectOfferingsTableFilterComposer,
      $$LocalSubjectOfferingsTableOrderingComposer,
      $$LocalSubjectOfferingsTableAnnotationComposer,
      $$LocalSubjectOfferingsTableCreateCompanionBuilder,
      $$LocalSubjectOfferingsTableUpdateCompanionBuilder,
      (
        LocalSubjectOffering,
        BaseReferences<
          _$AppDatabase,
          $LocalSubjectOfferingsTable,
          LocalSubjectOffering
        >,
      ),
      LocalSubjectOffering,
      PrefetchHooks Function()
    >;
typedef $$LocalStudentsTableCreateCompanionBuilder =
    LocalStudentsCompanion Function({
      required String studentId,
      Value<String?> lrn,
      Value<String?> rfidUid,
      required String firstName,
      Value<String?> middleName,
      required String lastName,
      Value<String> gender,
      Value<String?> departmentOrSection,
      Value<int> rowid,
    });
typedef $$LocalStudentsTableUpdateCompanionBuilder =
    LocalStudentsCompanion Function({
      Value<String> studentId,
      Value<String?> lrn,
      Value<String?> rfidUid,
      Value<String> firstName,
      Value<String?> middleName,
      Value<String> lastName,
      Value<String> gender,
      Value<String?> departmentOrSection,
      Value<int> rowid,
    });

class $$LocalStudentsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalStudentsTable> {
  $$LocalStudentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get studentId => $composableBuilder(
    column: $table.studentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lrn => $composableBuilder(
    column: $table.lrn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rfidUid => $composableBuilder(
    column: $table.rfidUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firstName => $composableBuilder(
    column: $table.firstName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get middleName => $composableBuilder(
    column: $table.middleName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastName => $composableBuilder(
    column: $table.lastName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get departmentOrSection => $composableBuilder(
    column: $table.departmentOrSection,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalStudentsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalStudentsTable> {
  $$LocalStudentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get studentId => $composableBuilder(
    column: $table.studentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lrn => $composableBuilder(
    column: $table.lrn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rfidUid => $composableBuilder(
    column: $table.rfidUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firstName => $composableBuilder(
    column: $table.firstName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get middleName => $composableBuilder(
    column: $table.middleName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastName => $composableBuilder(
    column: $table.lastName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get departmentOrSection => $composableBuilder(
    column: $table.departmentOrSection,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalStudentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalStudentsTable> {
  $$LocalStudentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get studentId =>
      $composableBuilder(column: $table.studentId, builder: (column) => column);

  GeneratedColumn<String> get lrn =>
      $composableBuilder(column: $table.lrn, builder: (column) => column);

  GeneratedColumn<String> get rfidUid =>
      $composableBuilder(column: $table.rfidUid, builder: (column) => column);

  GeneratedColumn<String> get firstName =>
      $composableBuilder(column: $table.firstName, builder: (column) => column);

  GeneratedColumn<String> get middleName => $composableBuilder(
    column: $table.middleName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastName =>
      $composableBuilder(column: $table.lastName, builder: (column) => column);

  GeneratedColumn<String> get gender =>
      $composableBuilder(column: $table.gender, builder: (column) => column);

  GeneratedColumn<String> get departmentOrSection => $composableBuilder(
    column: $table.departmentOrSection,
    builder: (column) => column,
  );
}

class $$LocalStudentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalStudentsTable,
          LocalStudent,
          $$LocalStudentsTableFilterComposer,
          $$LocalStudentsTableOrderingComposer,
          $$LocalStudentsTableAnnotationComposer,
          $$LocalStudentsTableCreateCompanionBuilder,
          $$LocalStudentsTableUpdateCompanionBuilder,
          (
            LocalStudent,
            BaseReferences<_$AppDatabase, $LocalStudentsTable, LocalStudent>,
          ),
          LocalStudent,
          PrefetchHooks Function()
        > {
  $$LocalStudentsTableTableManager(_$AppDatabase db, $LocalStudentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalStudentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalStudentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalStudentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> studentId = const Value.absent(),
                Value<String?> lrn = const Value.absent(),
                Value<String?> rfidUid = const Value.absent(),
                Value<String> firstName = const Value.absent(),
                Value<String?> middleName = const Value.absent(),
                Value<String> lastName = const Value.absent(),
                Value<String> gender = const Value.absent(),
                Value<String?> departmentOrSection = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalStudentsCompanion(
                studentId: studentId,
                lrn: lrn,
                rfidUid: rfidUid,
                firstName: firstName,
                middleName: middleName,
                lastName: lastName,
                gender: gender,
                departmentOrSection: departmentOrSection,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String studentId,
                Value<String?> lrn = const Value.absent(),
                Value<String?> rfidUid = const Value.absent(),
                required String firstName,
                Value<String?> middleName = const Value.absent(),
                required String lastName,
                Value<String> gender = const Value.absent(),
                Value<String?> departmentOrSection = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalStudentsCompanion.insert(
                studentId: studentId,
                lrn: lrn,
                rfidUid: rfidUid,
                firstName: firstName,
                middleName: middleName,
                lastName: lastName,
                gender: gender,
                departmentOrSection: departmentOrSection,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalStudentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalStudentsTable,
      LocalStudent,
      $$LocalStudentsTableFilterComposer,
      $$LocalStudentsTableOrderingComposer,
      $$LocalStudentsTableAnnotationComposer,
      $$LocalStudentsTableCreateCompanionBuilder,
      $$LocalStudentsTableUpdateCompanionBuilder,
      (
        LocalStudent,
        BaseReferences<_$AppDatabase, $LocalStudentsTable, LocalStudent>,
      ),
      LocalStudent,
      PrefetchHooks Function()
    >;
typedef $$LocalEnrollmentsTableCreateCompanionBuilder =
    LocalEnrollmentsCompanion Function({
      required String id,
      required String studentId,
      required String subjectOfferingId,
      Value<String> status,
      Value<int> rowid,
    });
typedef $$LocalEnrollmentsTableUpdateCompanionBuilder =
    LocalEnrollmentsCompanion Function({
      Value<String> id,
      Value<String> studentId,
      Value<String> subjectOfferingId,
      Value<String> status,
      Value<int> rowid,
    });

class $$LocalEnrollmentsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalEnrollmentsTable> {
  $$LocalEnrollmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get studentId => $composableBuilder(
    column: $table.studentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectOfferingId => $composableBuilder(
    column: $table.subjectOfferingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalEnrollmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalEnrollmentsTable> {
  $$LocalEnrollmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get studentId => $composableBuilder(
    column: $table.studentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectOfferingId => $composableBuilder(
    column: $table.subjectOfferingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalEnrollmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalEnrollmentsTable> {
  $$LocalEnrollmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get studentId =>
      $composableBuilder(column: $table.studentId, builder: (column) => column);

  GeneratedColumn<String> get subjectOfferingId => $composableBuilder(
    column: $table.subjectOfferingId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$LocalEnrollmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalEnrollmentsTable,
          LocalEnrollment,
          $$LocalEnrollmentsTableFilterComposer,
          $$LocalEnrollmentsTableOrderingComposer,
          $$LocalEnrollmentsTableAnnotationComposer,
          $$LocalEnrollmentsTableCreateCompanionBuilder,
          $$LocalEnrollmentsTableUpdateCompanionBuilder,
          (
            LocalEnrollment,
            BaseReferences<
              _$AppDatabase,
              $LocalEnrollmentsTable,
              LocalEnrollment
            >,
          ),
          LocalEnrollment,
          PrefetchHooks Function()
        > {
  $$LocalEnrollmentsTableTableManager(
    _$AppDatabase db,
    $LocalEnrollmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalEnrollmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalEnrollmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalEnrollmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> studentId = const Value.absent(),
                Value<String> subjectOfferingId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEnrollmentsCompanion(
                id: id,
                studentId: studentId,
                subjectOfferingId: subjectOfferingId,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String studentId,
                required String subjectOfferingId,
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEnrollmentsCompanion.insert(
                id: id,
                studentId: studentId,
                subjectOfferingId: subjectOfferingId,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalEnrollmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalEnrollmentsTable,
      LocalEnrollment,
      $$LocalEnrollmentsTableFilterComposer,
      $$LocalEnrollmentsTableOrderingComposer,
      $$LocalEnrollmentsTableAnnotationComposer,
      $$LocalEnrollmentsTableCreateCompanionBuilder,
      $$LocalEnrollmentsTableUpdateCompanionBuilder,
      (
        LocalEnrollment,
        BaseReferences<_$AppDatabase, $LocalEnrollmentsTable, LocalEnrollment>,
      ),
      LocalEnrollment,
      PrefetchHooks Function()
    >;
typedef $$LocalParentsTableCreateCompanionBuilder =
    LocalParentsCompanion Function({
      required String parentId,
      required String firstName,
      Value<String?> middleName,
      required String lastName,
      Value<String> contactNumber,
      Value<String> relationship,
      Value<String?> email,
      Value<int> rowid,
    });
typedef $$LocalParentsTableUpdateCompanionBuilder =
    LocalParentsCompanion Function({
      Value<String> parentId,
      Value<String> firstName,
      Value<String?> middleName,
      Value<String> lastName,
      Value<String> contactNumber,
      Value<String> relationship,
      Value<String?> email,
      Value<int> rowid,
    });

class $$LocalParentsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalParentsTable> {
  $$LocalParentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firstName => $composableBuilder(
    column: $table.firstName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get middleName => $composableBuilder(
    column: $table.middleName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastName => $composableBuilder(
    column: $table.lastName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactNumber => $composableBuilder(
    column: $table.contactNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relationship => $composableBuilder(
    column: $table.relationship,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalParentsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalParentsTable> {
  $$LocalParentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firstName => $composableBuilder(
    column: $table.firstName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get middleName => $composableBuilder(
    column: $table.middleName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastName => $composableBuilder(
    column: $table.lastName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactNumber => $composableBuilder(
    column: $table.contactNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relationship => $composableBuilder(
    column: $table.relationship,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalParentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalParentsTable> {
  $$LocalParentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get firstName =>
      $composableBuilder(column: $table.firstName, builder: (column) => column);

  GeneratedColumn<String> get middleName => $composableBuilder(
    column: $table.middleName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastName =>
      $composableBuilder(column: $table.lastName, builder: (column) => column);

  GeneratedColumn<String> get contactNumber => $composableBuilder(
    column: $table.contactNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relationship => $composableBuilder(
    column: $table.relationship,
    builder: (column) => column,
  );

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);
}

class $$LocalParentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalParentsTable,
          LocalParent,
          $$LocalParentsTableFilterComposer,
          $$LocalParentsTableOrderingComposer,
          $$LocalParentsTableAnnotationComposer,
          $$LocalParentsTableCreateCompanionBuilder,
          $$LocalParentsTableUpdateCompanionBuilder,
          (
            LocalParent,
            BaseReferences<_$AppDatabase, $LocalParentsTable, LocalParent>,
          ),
          LocalParent,
          PrefetchHooks Function()
        > {
  $$LocalParentsTableTableManager(_$AppDatabase db, $LocalParentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalParentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalParentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalParentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> parentId = const Value.absent(),
                Value<String> firstName = const Value.absent(),
                Value<String?> middleName = const Value.absent(),
                Value<String> lastName = const Value.absent(),
                Value<String> contactNumber = const Value.absent(),
                Value<String> relationship = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalParentsCompanion(
                parentId: parentId,
                firstName: firstName,
                middleName: middleName,
                lastName: lastName,
                contactNumber: contactNumber,
                relationship: relationship,
                email: email,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String parentId,
                required String firstName,
                Value<String?> middleName = const Value.absent(),
                required String lastName,
                Value<String> contactNumber = const Value.absent(),
                Value<String> relationship = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalParentsCompanion.insert(
                parentId: parentId,
                firstName: firstName,
                middleName: middleName,
                lastName: lastName,
                contactNumber: contactNumber,
                relationship: relationship,
                email: email,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalParentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalParentsTable,
      LocalParent,
      $$LocalParentsTableFilterComposer,
      $$LocalParentsTableOrderingComposer,
      $$LocalParentsTableAnnotationComposer,
      $$LocalParentsTableCreateCompanionBuilder,
      $$LocalParentsTableUpdateCompanionBuilder,
      (
        LocalParent,
        BaseReferences<_$AppDatabase, $LocalParentsTable, LocalParent>,
      ),
      LocalParent,
      PrefetchHooks Function()
    >;
typedef $$LocalParentStudentLinksTableCreateCompanionBuilder =
    LocalParentStudentLinksCompanion Function({
      required String id,
      required String parentId,
      required String studentId,
      Value<String> relationship,
      Value<int> rowid,
    });
typedef $$LocalParentStudentLinksTableUpdateCompanionBuilder =
    LocalParentStudentLinksCompanion Function({
      Value<String> id,
      Value<String> parentId,
      Value<String> studentId,
      Value<String> relationship,
      Value<int> rowid,
    });

class $$LocalParentStudentLinksTableFilterComposer
    extends Composer<_$AppDatabase, $LocalParentStudentLinksTable> {
  $$LocalParentStudentLinksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get studentId => $composableBuilder(
    column: $table.studentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relationship => $composableBuilder(
    column: $table.relationship,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalParentStudentLinksTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalParentStudentLinksTable> {
  $$LocalParentStudentLinksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get studentId => $composableBuilder(
    column: $table.studentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relationship => $composableBuilder(
    column: $table.relationship,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalParentStudentLinksTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalParentStudentLinksTable> {
  $$LocalParentStudentLinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get studentId =>
      $composableBuilder(column: $table.studentId, builder: (column) => column);

  GeneratedColumn<String> get relationship => $composableBuilder(
    column: $table.relationship,
    builder: (column) => column,
  );
}

class $$LocalParentStudentLinksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalParentStudentLinksTable,
          LocalParentStudentLink,
          $$LocalParentStudentLinksTableFilterComposer,
          $$LocalParentStudentLinksTableOrderingComposer,
          $$LocalParentStudentLinksTableAnnotationComposer,
          $$LocalParentStudentLinksTableCreateCompanionBuilder,
          $$LocalParentStudentLinksTableUpdateCompanionBuilder,
          (
            LocalParentStudentLink,
            BaseReferences<
              _$AppDatabase,
              $LocalParentStudentLinksTable,
              LocalParentStudentLink
            >,
          ),
          LocalParentStudentLink,
          PrefetchHooks Function()
        > {
  $$LocalParentStudentLinksTableTableManager(
    _$AppDatabase db,
    $LocalParentStudentLinksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalParentStudentLinksTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalParentStudentLinksTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalParentStudentLinksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> parentId = const Value.absent(),
                Value<String> studentId = const Value.absent(),
                Value<String> relationship = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalParentStudentLinksCompanion(
                id: id,
                parentId: parentId,
                studentId: studentId,
                relationship: relationship,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String parentId,
                required String studentId,
                Value<String> relationship = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalParentStudentLinksCompanion.insert(
                id: id,
                parentId: parentId,
                studentId: studentId,
                relationship: relationship,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalParentStudentLinksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalParentStudentLinksTable,
      LocalParentStudentLink,
      $$LocalParentStudentLinksTableFilterComposer,
      $$LocalParentStudentLinksTableOrderingComposer,
      $$LocalParentStudentLinksTableAnnotationComposer,
      $$LocalParentStudentLinksTableCreateCompanionBuilder,
      $$LocalParentStudentLinksTableUpdateCompanionBuilder,
      (
        LocalParentStudentLink,
        BaseReferences<
          _$AppDatabase,
          $LocalParentStudentLinksTable,
          LocalParentStudentLink
        >,
      ),
      LocalParentStudentLink,
      PrefetchHooks Function()
    >;
typedef $$LocalAttendanceRecordsTableCreateCompanionBuilder =
    LocalAttendanceRecordsCompanion Function({
      required String id,
      required String studentId,
      required String subjectOfferingId,
      required String attendanceDate,
      required String status,
      Value<String> recordingMethod,
      Value<String?> timeIn,
      Value<String?> deviceId,
      Value<String?> remarks,
      Value<String> source,
      Value<String?> recordedBy,
      Value<String> syncStatus,
      Value<int> rowid,
    });
typedef $$LocalAttendanceRecordsTableUpdateCompanionBuilder =
    LocalAttendanceRecordsCompanion Function({
      Value<String> id,
      Value<String> studentId,
      Value<String> subjectOfferingId,
      Value<String> attendanceDate,
      Value<String> status,
      Value<String> recordingMethod,
      Value<String?> timeIn,
      Value<String?> deviceId,
      Value<String?> remarks,
      Value<String> source,
      Value<String?> recordedBy,
      Value<String> syncStatus,
      Value<int> rowid,
    });

class $$LocalAttendanceRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalAttendanceRecordsTable> {
  $$LocalAttendanceRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get studentId => $composableBuilder(
    column: $table.studentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectOfferingId => $composableBuilder(
    column: $table.subjectOfferingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attendanceDate => $composableBuilder(
    column: $table.attendanceDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordingMethod => $composableBuilder(
    column: $table.recordingMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeIn => $composableBuilder(
    column: $table.timeIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remarks => $composableBuilder(
    column: $table.remarks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordedBy => $composableBuilder(
    column: $table.recordedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalAttendanceRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalAttendanceRecordsTable> {
  $$LocalAttendanceRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get studentId => $composableBuilder(
    column: $table.studentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectOfferingId => $composableBuilder(
    column: $table.subjectOfferingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attendanceDate => $composableBuilder(
    column: $table.attendanceDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordingMethod => $composableBuilder(
    column: $table.recordingMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeIn => $composableBuilder(
    column: $table.timeIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remarks => $composableBuilder(
    column: $table.remarks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordedBy => $composableBuilder(
    column: $table.recordedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalAttendanceRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalAttendanceRecordsTable> {
  $$LocalAttendanceRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get studentId =>
      $composableBuilder(column: $table.studentId, builder: (column) => column);

  GeneratedColumn<String> get subjectOfferingId => $composableBuilder(
    column: $table.subjectOfferingId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attendanceDate => $composableBuilder(
    column: $table.attendanceDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get recordingMethod => $composableBuilder(
    column: $table.recordingMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timeIn =>
      $composableBuilder(column: $table.timeIn, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get remarks =>
      $composableBuilder(column: $table.remarks, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get recordedBy => $composableBuilder(
    column: $table.recordedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );
}

class $$LocalAttendanceRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalAttendanceRecordsTable,
          LocalAttendanceRecord,
          $$LocalAttendanceRecordsTableFilterComposer,
          $$LocalAttendanceRecordsTableOrderingComposer,
          $$LocalAttendanceRecordsTableAnnotationComposer,
          $$LocalAttendanceRecordsTableCreateCompanionBuilder,
          $$LocalAttendanceRecordsTableUpdateCompanionBuilder,
          (
            LocalAttendanceRecord,
            BaseReferences<
              _$AppDatabase,
              $LocalAttendanceRecordsTable,
              LocalAttendanceRecord
            >,
          ),
          LocalAttendanceRecord,
          PrefetchHooks Function()
        > {
  $$LocalAttendanceRecordsTableTableManager(
    _$AppDatabase db,
    $LocalAttendanceRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAttendanceRecordsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalAttendanceRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalAttendanceRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> studentId = const Value.absent(),
                Value<String> subjectOfferingId = const Value.absent(),
                Value<String> attendanceDate = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> recordingMethod = const Value.absent(),
                Value<String?> timeIn = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<String?> remarks = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> recordedBy = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAttendanceRecordsCompanion(
                id: id,
                studentId: studentId,
                subjectOfferingId: subjectOfferingId,
                attendanceDate: attendanceDate,
                status: status,
                recordingMethod: recordingMethod,
                timeIn: timeIn,
                deviceId: deviceId,
                remarks: remarks,
                source: source,
                recordedBy: recordedBy,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String studentId,
                required String subjectOfferingId,
                required String attendanceDate,
                required String status,
                Value<String> recordingMethod = const Value.absent(),
                Value<String?> timeIn = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<String?> remarks = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> recordedBy = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAttendanceRecordsCompanion.insert(
                id: id,
                studentId: studentId,
                subjectOfferingId: subjectOfferingId,
                attendanceDate: attendanceDate,
                status: status,
                recordingMethod: recordingMethod,
                timeIn: timeIn,
                deviceId: deviceId,
                remarks: remarks,
                source: source,
                recordedBy: recordedBy,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalAttendanceRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalAttendanceRecordsTable,
      LocalAttendanceRecord,
      $$LocalAttendanceRecordsTableFilterComposer,
      $$LocalAttendanceRecordsTableOrderingComposer,
      $$LocalAttendanceRecordsTableAnnotationComposer,
      $$LocalAttendanceRecordsTableCreateCompanionBuilder,
      $$LocalAttendanceRecordsTableUpdateCompanionBuilder,
      (
        LocalAttendanceRecord,
        BaseReferences<
          _$AppDatabase,
          $LocalAttendanceRecordsTable,
          LocalAttendanceRecord
        >,
      ),
      LocalAttendanceRecord,
      PrefetchHooks Function()
    >;
typedef $$LocalAttendanceCutoffsTableCreateCompanionBuilder =
    LocalAttendanceCutoffsCompanion Function({
      required String subjectOfferingId,
      Value<int> presentStartMinsBefore,
      Value<int> presentGraceMins,
      Value<int> lateCutoffMins,
      Value<int> absentCutoffMins,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$LocalAttendanceCutoffsTableUpdateCompanionBuilder =
    LocalAttendanceCutoffsCompanion Function({
      Value<String> subjectOfferingId,
      Value<int> presentStartMinsBefore,
      Value<int> presentGraceMins,
      Value<int> lateCutoffMins,
      Value<int> absentCutoffMins,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalAttendanceCutoffsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalAttendanceCutoffsTable> {
  $$LocalAttendanceCutoffsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get subjectOfferingId => $composableBuilder(
    column: $table.subjectOfferingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get presentStartMinsBefore => $composableBuilder(
    column: $table.presentStartMinsBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get presentGraceMins => $composableBuilder(
    column: $table.presentGraceMins,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lateCutoffMins => $composableBuilder(
    column: $table.lateCutoffMins,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get absentCutoffMins => $composableBuilder(
    column: $table.absentCutoffMins,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalAttendanceCutoffsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalAttendanceCutoffsTable> {
  $$LocalAttendanceCutoffsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get subjectOfferingId => $composableBuilder(
    column: $table.subjectOfferingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get presentStartMinsBefore => $composableBuilder(
    column: $table.presentStartMinsBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get presentGraceMins => $composableBuilder(
    column: $table.presentGraceMins,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lateCutoffMins => $composableBuilder(
    column: $table.lateCutoffMins,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get absentCutoffMins => $composableBuilder(
    column: $table.absentCutoffMins,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalAttendanceCutoffsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalAttendanceCutoffsTable> {
  $$LocalAttendanceCutoffsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get subjectOfferingId => $composableBuilder(
    column: $table.subjectOfferingId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get presentStartMinsBefore => $composableBuilder(
    column: $table.presentStartMinsBefore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get presentGraceMins => $composableBuilder(
    column: $table.presentGraceMins,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lateCutoffMins => $composableBuilder(
    column: $table.lateCutoffMins,
    builder: (column) => column,
  );

  GeneratedColumn<int> get absentCutoffMins => $composableBuilder(
    column: $table.absentCutoffMins,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalAttendanceCutoffsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalAttendanceCutoffsTable,
          LocalAttendanceCutoff,
          $$LocalAttendanceCutoffsTableFilterComposer,
          $$LocalAttendanceCutoffsTableOrderingComposer,
          $$LocalAttendanceCutoffsTableAnnotationComposer,
          $$LocalAttendanceCutoffsTableCreateCompanionBuilder,
          $$LocalAttendanceCutoffsTableUpdateCompanionBuilder,
          (
            LocalAttendanceCutoff,
            BaseReferences<
              _$AppDatabase,
              $LocalAttendanceCutoffsTable,
              LocalAttendanceCutoff
            >,
          ),
          LocalAttendanceCutoff,
          PrefetchHooks Function()
        > {
  $$LocalAttendanceCutoffsTableTableManager(
    _$AppDatabase db,
    $LocalAttendanceCutoffsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAttendanceCutoffsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalAttendanceCutoffsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalAttendanceCutoffsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> subjectOfferingId = const Value.absent(),
                Value<int> presentStartMinsBefore = const Value.absent(),
                Value<int> presentGraceMins = const Value.absent(),
                Value<int> lateCutoffMins = const Value.absent(),
                Value<int> absentCutoffMins = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAttendanceCutoffsCompanion(
                subjectOfferingId: subjectOfferingId,
                presentStartMinsBefore: presentStartMinsBefore,
                presentGraceMins: presentGraceMins,
                lateCutoffMins: lateCutoffMins,
                absentCutoffMins: absentCutoffMins,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String subjectOfferingId,
                Value<int> presentStartMinsBefore = const Value.absent(),
                Value<int> presentGraceMins = const Value.absent(),
                Value<int> lateCutoffMins = const Value.absent(),
                Value<int> absentCutoffMins = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAttendanceCutoffsCompanion.insert(
                subjectOfferingId: subjectOfferingId,
                presentStartMinsBefore: presentStartMinsBefore,
                presentGraceMins: presentGraceMins,
                lateCutoffMins: lateCutoffMins,
                absentCutoffMins: absentCutoffMins,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalAttendanceCutoffsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalAttendanceCutoffsTable,
      LocalAttendanceCutoff,
      $$LocalAttendanceCutoffsTableFilterComposer,
      $$LocalAttendanceCutoffsTableOrderingComposer,
      $$LocalAttendanceCutoffsTableAnnotationComposer,
      $$LocalAttendanceCutoffsTableCreateCompanionBuilder,
      $$LocalAttendanceCutoffsTableUpdateCompanionBuilder,
      (
        LocalAttendanceCutoff,
        BaseReferences<
          _$AppDatabase,
          $LocalAttendanceCutoffsTable,
          LocalAttendanceCutoff
        >,
      ),
      LocalAttendanceCutoff,
      PrefetchHooks Function()
    >;
typedef $$LocalSchedulesTableCreateCompanionBuilder =
    LocalSchedulesCompanion Function({
      required String id,
      required String subjectOfferingId,
      required String teacherId,
      required String dayOfWeek,
      required String startTime,
      required String endTime,
      Value<String?> room,
      Value<int> rowid,
    });
typedef $$LocalSchedulesTableUpdateCompanionBuilder =
    LocalSchedulesCompanion Function({
      Value<String> id,
      Value<String> subjectOfferingId,
      Value<String> teacherId,
      Value<String> dayOfWeek,
      Value<String> startTime,
      Value<String> endTime,
      Value<String?> room,
      Value<int> rowid,
    });

class $$LocalSchedulesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSchedulesTable> {
  $$LocalSchedulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectOfferingId => $composableBuilder(
    column: $table.subjectOfferingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get teacherId => $composableBuilder(
    column: $table.teacherId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayOfWeek => $composableBuilder(
    column: $table.dayOfWeek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get room => $composableBuilder(
    column: $table.room,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSchedulesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSchedulesTable> {
  $$LocalSchedulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectOfferingId => $composableBuilder(
    column: $table.subjectOfferingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get teacherId => $composableBuilder(
    column: $table.teacherId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayOfWeek => $composableBuilder(
    column: $table.dayOfWeek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get room => $composableBuilder(
    column: $table.room,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSchedulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSchedulesTable> {
  $$LocalSchedulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get subjectOfferingId => $composableBuilder(
    column: $table.subjectOfferingId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get teacherId =>
      $composableBuilder(column: $table.teacherId, builder: (column) => column);

  GeneratedColumn<String> get dayOfWeek =>
      $composableBuilder(column: $table.dayOfWeek, builder: (column) => column);

  GeneratedColumn<String> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<String> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<String> get room =>
      $composableBuilder(column: $table.room, builder: (column) => column);
}

class $$LocalSchedulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSchedulesTable,
          LocalSchedule,
          $$LocalSchedulesTableFilterComposer,
          $$LocalSchedulesTableOrderingComposer,
          $$LocalSchedulesTableAnnotationComposer,
          $$LocalSchedulesTableCreateCompanionBuilder,
          $$LocalSchedulesTableUpdateCompanionBuilder,
          (
            LocalSchedule,
            BaseReferences<_$AppDatabase, $LocalSchedulesTable, LocalSchedule>,
          ),
          LocalSchedule,
          PrefetchHooks Function()
        > {
  $$LocalSchedulesTableTableManager(
    _$AppDatabase db,
    $LocalSchedulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSchedulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSchedulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSchedulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> subjectOfferingId = const Value.absent(),
                Value<String> teacherId = const Value.absent(),
                Value<String> dayOfWeek = const Value.absent(),
                Value<String> startTime = const Value.absent(),
                Value<String> endTime = const Value.absent(),
                Value<String?> room = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSchedulesCompanion(
                id: id,
                subjectOfferingId: subjectOfferingId,
                teacherId: teacherId,
                dayOfWeek: dayOfWeek,
                startTime: startTime,
                endTime: endTime,
                room: room,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String subjectOfferingId,
                required String teacherId,
                required String dayOfWeek,
                required String startTime,
                required String endTime,
                Value<String?> room = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSchedulesCompanion.insert(
                id: id,
                subjectOfferingId: subjectOfferingId,
                teacherId: teacherId,
                dayOfWeek: dayOfWeek,
                startTime: startTime,
                endTime: endTime,
                room: room,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSchedulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSchedulesTable,
      LocalSchedule,
      $$LocalSchedulesTableFilterComposer,
      $$LocalSchedulesTableOrderingComposer,
      $$LocalSchedulesTableAnnotationComposer,
      $$LocalSchedulesTableCreateCompanionBuilder,
      $$LocalSchedulesTableUpdateCompanionBuilder,
      (
        LocalSchedule,
        BaseReferences<_$AppDatabase, $LocalSchedulesTable, LocalSchedule>,
      ),
      LocalSchedule,
      PrefetchHooks Function()
    >;
typedef $$LocalAssessmentsTableCreateCompanionBuilder =
    LocalAssessmentsCompanion Function({
      required String id,
      required String subjectOfferingId,
      required String title,
      required String component,
      required double totalScore,
      Value<int> quarter,
      Value<int> rowid,
    });
typedef $$LocalAssessmentsTableUpdateCompanionBuilder =
    LocalAssessmentsCompanion Function({
      Value<String> id,
      Value<String> subjectOfferingId,
      Value<String> title,
      Value<String> component,
      Value<double> totalScore,
      Value<int> quarter,
      Value<int> rowid,
    });

class $$LocalAssessmentsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalAssessmentsTable> {
  $$LocalAssessmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectOfferingId => $composableBuilder(
    column: $table.subjectOfferingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get component => $composableBuilder(
    column: $table.component,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalScore => $composableBuilder(
    column: $table.totalScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quarter => $composableBuilder(
    column: $table.quarter,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalAssessmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalAssessmentsTable> {
  $$LocalAssessmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectOfferingId => $composableBuilder(
    column: $table.subjectOfferingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get component => $composableBuilder(
    column: $table.component,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalScore => $composableBuilder(
    column: $table.totalScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quarter => $composableBuilder(
    column: $table.quarter,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalAssessmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalAssessmentsTable> {
  $$LocalAssessmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get subjectOfferingId => $composableBuilder(
    column: $table.subjectOfferingId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get component =>
      $composableBuilder(column: $table.component, builder: (column) => column);

  GeneratedColumn<double> get totalScore => $composableBuilder(
    column: $table.totalScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get quarter =>
      $composableBuilder(column: $table.quarter, builder: (column) => column);
}

class $$LocalAssessmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalAssessmentsTable,
          LocalAssessment,
          $$LocalAssessmentsTableFilterComposer,
          $$LocalAssessmentsTableOrderingComposer,
          $$LocalAssessmentsTableAnnotationComposer,
          $$LocalAssessmentsTableCreateCompanionBuilder,
          $$LocalAssessmentsTableUpdateCompanionBuilder,
          (
            LocalAssessment,
            BaseReferences<
              _$AppDatabase,
              $LocalAssessmentsTable,
              LocalAssessment
            >,
          ),
          LocalAssessment,
          PrefetchHooks Function()
        > {
  $$LocalAssessmentsTableTableManager(
    _$AppDatabase db,
    $LocalAssessmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAssessmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAssessmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAssessmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> subjectOfferingId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> component = const Value.absent(),
                Value<double> totalScore = const Value.absent(),
                Value<int> quarter = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAssessmentsCompanion(
                id: id,
                subjectOfferingId: subjectOfferingId,
                title: title,
                component: component,
                totalScore: totalScore,
                quarter: quarter,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String subjectOfferingId,
                required String title,
                required String component,
                required double totalScore,
                Value<int> quarter = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAssessmentsCompanion.insert(
                id: id,
                subjectOfferingId: subjectOfferingId,
                title: title,
                component: component,
                totalScore: totalScore,
                quarter: quarter,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalAssessmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalAssessmentsTable,
      LocalAssessment,
      $$LocalAssessmentsTableFilterComposer,
      $$LocalAssessmentsTableOrderingComposer,
      $$LocalAssessmentsTableAnnotationComposer,
      $$LocalAssessmentsTableCreateCompanionBuilder,
      $$LocalAssessmentsTableUpdateCompanionBuilder,
      (
        LocalAssessment,
        BaseReferences<_$AppDatabase, $LocalAssessmentsTable, LocalAssessment>,
      ),
      LocalAssessment,
      PrefetchHooks Function()
    >;
typedef $$LocalStudentScoresTableCreateCompanionBuilder =
    LocalStudentScoresCompanion Function({
      required String id,
      required String assessmentId,
      required String studentId,
      required double score,
      Value<String?> remarks,
      Value<int> rowid,
    });
typedef $$LocalStudentScoresTableUpdateCompanionBuilder =
    LocalStudentScoresCompanion Function({
      Value<String> id,
      Value<String> assessmentId,
      Value<String> studentId,
      Value<double> score,
      Value<String?> remarks,
      Value<int> rowid,
    });

class $$LocalStudentScoresTableFilterComposer
    extends Composer<_$AppDatabase, $LocalStudentScoresTable> {
  $$LocalStudentScoresTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assessmentId => $composableBuilder(
    column: $table.assessmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get studentId => $composableBuilder(
    column: $table.studentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remarks => $composableBuilder(
    column: $table.remarks,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalStudentScoresTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalStudentScoresTable> {
  $$LocalStudentScoresTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assessmentId => $composableBuilder(
    column: $table.assessmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get studentId => $composableBuilder(
    column: $table.studentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remarks => $composableBuilder(
    column: $table.remarks,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalStudentScoresTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalStudentScoresTable> {
  $$LocalStudentScoresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get assessmentId => $composableBuilder(
    column: $table.assessmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get studentId =>
      $composableBuilder(column: $table.studentId, builder: (column) => column);

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<String> get remarks =>
      $composableBuilder(column: $table.remarks, builder: (column) => column);
}

class $$LocalStudentScoresTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalStudentScoresTable,
          LocalStudentScore,
          $$LocalStudentScoresTableFilterComposer,
          $$LocalStudentScoresTableOrderingComposer,
          $$LocalStudentScoresTableAnnotationComposer,
          $$LocalStudentScoresTableCreateCompanionBuilder,
          $$LocalStudentScoresTableUpdateCompanionBuilder,
          (
            LocalStudentScore,
            BaseReferences<
              _$AppDatabase,
              $LocalStudentScoresTable,
              LocalStudentScore
            >,
          ),
          LocalStudentScore,
          PrefetchHooks Function()
        > {
  $$LocalStudentScoresTableTableManager(
    _$AppDatabase db,
    $LocalStudentScoresTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalStudentScoresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalStudentScoresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalStudentScoresTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> assessmentId = const Value.absent(),
                Value<String> studentId = const Value.absent(),
                Value<double> score = const Value.absent(),
                Value<String?> remarks = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalStudentScoresCompanion(
                id: id,
                assessmentId: assessmentId,
                studentId: studentId,
                score: score,
                remarks: remarks,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String assessmentId,
                required String studentId,
                required double score,
                Value<String?> remarks = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalStudentScoresCompanion.insert(
                id: id,
                assessmentId: assessmentId,
                studentId: studentId,
                score: score,
                remarks: remarks,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalStudentScoresTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalStudentScoresTable,
      LocalStudentScore,
      $$LocalStudentScoresTableFilterComposer,
      $$LocalStudentScoresTableOrderingComposer,
      $$LocalStudentScoresTableAnnotationComposer,
      $$LocalStudentScoresTableCreateCompanionBuilder,
      $$LocalStudentScoresTableUpdateCompanionBuilder,
      (
        LocalStudentScore,
        BaseReferences<
          _$AppDatabase,
          $LocalStudentScoresTable,
          LocalStudentScore
        >,
      ),
      LocalStudentScore,
      PrefetchHooks Function()
    >;
typedef $$OfflineSyncQueueTableCreateCompanionBuilder =
    OfflineSyncQueueCompanion Function({
      required String id,
      required String action,
      required String targetTable,
      required String payloadJson,
      Value<DateTime> createdAt,
      Value<int> retryCount,
      Value<String> status,
      Value<String?> errorMessage,
      Value<int> rowid,
    });
typedef $$OfflineSyncQueueTableUpdateCompanionBuilder =
    OfflineSyncQueueCompanion Function({
      Value<String> id,
      Value<String> action,
      Value<String> targetTable,
      Value<String> payloadJson,
      Value<DateTime> createdAt,
      Value<int> retryCount,
      Value<String> status,
      Value<String?> errorMessage,
      Value<int> rowid,
    });

class $$OfflineSyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $OfflineSyncQueueTable> {
  $$OfflineSyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OfflineSyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $OfflineSyncQueueTable> {
  $$OfflineSyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OfflineSyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfflineSyncQueueTable> {
  $$OfflineSyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );
}

class $$OfflineSyncQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OfflineSyncQueueTable,
          OfflineSyncQueueData,
          $$OfflineSyncQueueTableFilterComposer,
          $$OfflineSyncQueueTableOrderingComposer,
          $$OfflineSyncQueueTableAnnotationComposer,
          $$OfflineSyncQueueTableCreateCompanionBuilder,
          $$OfflineSyncQueueTableUpdateCompanionBuilder,
          (
            OfflineSyncQueueData,
            BaseReferences<
              _$AppDatabase,
              $OfflineSyncQueueTable,
              OfflineSyncQueueData
            >,
          ),
          OfflineSyncQueueData,
          PrefetchHooks Function()
        > {
  $$OfflineSyncQueueTableTableManager(
    _$AppDatabase db,
    $OfflineSyncQueueTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineSyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfflineSyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OfflineSyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> targetTable = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfflineSyncQueueCompanion(
                id: id,
                action: action,
                targetTable: targetTable,
                payloadJson: payloadJson,
                createdAt: createdAt,
                retryCount: retryCount,
                status: status,
                errorMessage: errorMessage,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String action,
                required String targetTable,
                required String payloadJson,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfflineSyncQueueCompanion.insert(
                id: id,
                action: action,
                targetTable: targetTable,
                payloadJson: payloadJson,
                createdAt: createdAt,
                retryCount: retryCount,
                status: status,
                errorMessage: errorMessage,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OfflineSyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OfflineSyncQueueTable,
      OfflineSyncQueueData,
      $$OfflineSyncQueueTableFilterComposer,
      $$OfflineSyncQueueTableOrderingComposer,
      $$OfflineSyncQueueTableAnnotationComposer,
      $$OfflineSyncQueueTableCreateCompanionBuilder,
      $$OfflineSyncQueueTableUpdateCompanionBuilder,
      (
        OfflineSyncQueueData,
        BaseReferences<
          _$AppDatabase,
          $OfflineSyncQueueTable,
          OfflineSyncQueueData
        >,
      ),
      OfflineSyncQueueData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalSettingsTableTableManager get localSettings =>
      $$LocalSettingsTableTableManager(_db, _db.localSettings);
  $$LocalUserProfilesTableTableManager get localUserProfiles =>
      $$LocalUserProfilesTableTableManager(_db, _db.localUserProfiles);
  $$LocalSubjectsTableTableManager get localSubjects =>
      $$LocalSubjectsTableTableManager(_db, _db.localSubjects);
  $$LocalSectionsTableTableManager get localSections =>
      $$LocalSectionsTableTableManager(_db, _db.localSections);
  $$LocalSubjectOfferingsTableTableManager get localSubjectOfferings =>
      $$LocalSubjectOfferingsTableTableManager(_db, _db.localSubjectOfferings);
  $$LocalStudentsTableTableManager get localStudents =>
      $$LocalStudentsTableTableManager(_db, _db.localStudents);
  $$LocalEnrollmentsTableTableManager get localEnrollments =>
      $$LocalEnrollmentsTableTableManager(_db, _db.localEnrollments);
  $$LocalParentsTableTableManager get localParents =>
      $$LocalParentsTableTableManager(_db, _db.localParents);
  $$LocalParentStudentLinksTableTableManager get localParentStudentLinks =>
      $$LocalParentStudentLinksTableTableManager(
        _db,
        _db.localParentStudentLinks,
      );
  $$LocalAttendanceRecordsTableTableManager get localAttendanceRecords =>
      $$LocalAttendanceRecordsTableTableManager(
        _db,
        _db.localAttendanceRecords,
      );
  $$LocalAttendanceCutoffsTableTableManager get localAttendanceCutoffs =>
      $$LocalAttendanceCutoffsTableTableManager(
        _db,
        _db.localAttendanceCutoffs,
      );
  $$LocalSchedulesTableTableManager get localSchedules =>
      $$LocalSchedulesTableTableManager(_db, _db.localSchedules);
  $$LocalAssessmentsTableTableManager get localAssessments =>
      $$LocalAssessmentsTableTableManager(_db, _db.localAssessments);
  $$LocalStudentScoresTableTableManager get localStudentScores =>
      $$LocalStudentScoresTableTableManager(_db, _db.localStudentScores);
  $$OfflineSyncQueueTableTableManager get offlineSyncQueue =>
      $$OfflineSyncQueueTableTableManager(_db, _db.offlineSyncQueue);
}
