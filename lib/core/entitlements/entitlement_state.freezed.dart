// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'entitlement_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$EntitlementState {
  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            PlanTier tier, DateTime? expiresAt, Set<AppFeature> overrides)
        $default, {
    required TResult Function() loading,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            PlanTier tier, DateTime? expiresAt, Set<AppFeature> overrides)?
        $default, {
    TResult? Function()? loading,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            PlanTier tier, DateTime? expiresAt, Set<AppFeature> overrides)?
        $default, {
    TResult Function()? loading,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_EntitlementResolved value) $default, {
    required TResult Function(_EntitlementLoading value) loading,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_EntitlementResolved value)? $default, {
    TResult? Function(_EntitlementLoading value)? loading,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_EntitlementResolved value)? $default, {
    TResult Function(_EntitlementLoading value)? loading,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EntitlementStateCopyWith<$Res> {
  factory $EntitlementStateCopyWith(
          EntitlementState value, $Res Function(EntitlementState) then) =
      _$EntitlementStateCopyWithImpl<$Res, EntitlementState>;
}

/// @nodoc
class _$EntitlementStateCopyWithImpl<$Res, $Val extends EntitlementState>
    implements $EntitlementStateCopyWith<$Res> {
  _$EntitlementStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;
}

/// @nodoc
abstract class _$$EntitlementResolvedImplCopyWith<$Res> {
  factory _$$EntitlementResolvedImplCopyWith(_$EntitlementResolvedImpl value,
          $Res Function(_$EntitlementResolvedImpl) then) =
      __$$EntitlementResolvedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({PlanTier tier, DateTime? expiresAt, Set<AppFeature> overrides});
}

/// @nodoc
class __$$EntitlementResolvedImplCopyWithImpl<$Res>
    extends _$EntitlementStateCopyWithImpl<$Res, _$EntitlementResolvedImpl>
    implements _$$EntitlementResolvedImplCopyWith<$Res> {
  __$$EntitlementResolvedImplCopyWithImpl(_$EntitlementResolvedImpl _value,
      $Res Function(_$EntitlementResolvedImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tier = null,
    Object? expiresAt = freezed,
    Object? overrides = null,
  }) {
    return _then(_$EntitlementResolvedImpl(
      tier: null == tier
          ? _value.tier
          : tier // ignore: cast_nullable_to_non_nullable
              as PlanTier,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      overrides: null == overrides
          ? _value._overrides
          : overrides // ignore: cast_nullable_to_non_nullable
              as Set<AppFeature>,
    ));
  }
}

/// @nodoc

class _$EntitlementResolvedImpl extends _EntitlementResolved {
  const _$EntitlementResolvedImpl(
      {required this.tier,
      this.expiresAt,
      final Set<AppFeature> overrides = const <AppFeature>{}})
      : _overrides = overrides,
        super._();

  @override
  final PlanTier tier;

  /// UTC expiry from Firebase. null = no expiry (lifetime / manual plans).
  @override
  final DateTime? expiresAt;

  /// Firebase-console-managed per-institution feature overrides.
  /// An override grants a feature regardless of tier or expiry.
  /// Stored as a Set<AppFeature> to allow O(1) lookup.
  final Set<AppFeature> _overrides;

  /// Firebase-console-managed per-institution feature overrides.
  /// An override grants a feature regardless of tier or expiry.
  /// Stored as a Set<AppFeature> to allow O(1) lookup.
  @override
  @JsonKey()
  Set<AppFeature> get overrides {
    if (_overrides is EqualUnmodifiableSetView) return _overrides;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_overrides);
  }

  @override
  String toString() {
    return 'EntitlementState(tier: $tier, expiresAt: $expiresAt, overrides: $overrides)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EntitlementResolvedImpl &&
            (identical(other.tier, tier) || other.tier == tier) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            const DeepCollectionEquality()
                .equals(other._overrides, _overrides));
  }

  @override
  int get hashCode => Object.hash(runtimeType, tier, expiresAt,
      const DeepCollectionEquality().hash(_overrides));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$EntitlementResolvedImplCopyWith<_$EntitlementResolvedImpl> get copyWith =>
      __$$EntitlementResolvedImplCopyWithImpl<_$EntitlementResolvedImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            PlanTier tier, DateTime? expiresAt, Set<AppFeature> overrides)
        $default, {
    required TResult Function() loading,
  }) {
    return $default(tier, expiresAt, overrides);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            PlanTier tier, DateTime? expiresAt, Set<AppFeature> overrides)?
        $default, {
    TResult? Function()? loading,
  }) {
    return $default?.call(tier, expiresAt, overrides);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            PlanTier tier, DateTime? expiresAt, Set<AppFeature> overrides)?
        $default, {
    TResult Function()? loading,
    required TResult orElse(),
  }) {
    if ($default != null) {
      return $default(tier, expiresAt, overrides);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_EntitlementResolved value) $default, {
    required TResult Function(_EntitlementLoading value) loading,
  }) {
    return $default(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_EntitlementResolved value)? $default, {
    TResult? Function(_EntitlementLoading value)? loading,
  }) {
    return $default?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_EntitlementResolved value)? $default, {
    TResult Function(_EntitlementLoading value)? loading,
    required TResult orElse(),
  }) {
    if ($default != null) {
      return $default(this);
    }
    return orElse();
  }
}

abstract class _EntitlementResolved extends EntitlementState {
  const factory _EntitlementResolved(
      {required final PlanTier tier,
      final DateTime? expiresAt,
      final Set<AppFeature> overrides}) = _$EntitlementResolvedImpl;
  const _EntitlementResolved._() : super._();

  PlanTier get tier;

  /// UTC expiry from Firebase. null = no expiry (lifetime / manual plans).
  DateTime? get expiresAt;

  /// Firebase-console-managed per-institution feature overrides.
  /// An override grants a feature regardless of tier or expiry.
  /// Stored as a Set<AppFeature> to allow O(1) lookup.
  Set<AppFeature> get overrides;
  @JsonKey(ignore: true)
  _$$EntitlementResolvedImplCopyWith<_$EntitlementResolvedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$EntitlementLoadingImplCopyWith<$Res> {
  factory _$$EntitlementLoadingImplCopyWith(_$EntitlementLoadingImpl value,
          $Res Function(_$EntitlementLoadingImpl) then) =
      __$$EntitlementLoadingImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$EntitlementLoadingImplCopyWithImpl<$Res>
    extends _$EntitlementStateCopyWithImpl<$Res, _$EntitlementLoadingImpl>
    implements _$$EntitlementLoadingImplCopyWith<$Res> {
  __$$EntitlementLoadingImplCopyWithImpl(_$EntitlementLoadingImpl _value,
      $Res Function(_$EntitlementLoadingImpl) _then)
      : super(_value, _then);
}

/// @nodoc

class _$EntitlementLoadingImpl extends _EntitlementLoading {
  const _$EntitlementLoadingImpl() : super._();

  @override
  String toString() {
    return 'EntitlementState.loading()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$EntitlementLoadingImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            PlanTier tier, DateTime? expiresAt, Set<AppFeature> overrides)
        $default, {
    required TResult Function() loading,
  }) {
    return loading();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            PlanTier tier, DateTime? expiresAt, Set<AppFeature> overrides)?
        $default, {
    TResult? Function()? loading,
  }) {
    return loading?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            PlanTier tier, DateTime? expiresAt, Set<AppFeature> overrides)?
        $default, {
    TResult Function()? loading,
    required TResult orElse(),
  }) {
    if (loading != null) {
      return loading();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_EntitlementResolved value) $default, {
    required TResult Function(_EntitlementLoading value) loading,
  }) {
    return loading(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_EntitlementResolved value)? $default, {
    TResult? Function(_EntitlementLoading value)? loading,
  }) {
    return loading?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_EntitlementResolved value)? $default, {
    TResult Function(_EntitlementLoading value)? loading,
    required TResult orElse(),
  }) {
    if (loading != null) {
      return loading(this);
    }
    return orElse();
  }
}

abstract class _EntitlementLoading extends EntitlementState {
  const factory _EntitlementLoading() = _$EntitlementLoadingImpl;
  const _EntitlementLoading._() : super._();
}
