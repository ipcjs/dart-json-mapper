import 'dart:convert' show base64Decode, base64Encode;
import 'dart:convert' show JsonDecoder;
import 'dart:typed_data' show Uint8List;

import 'package:intl/intl.dart';

import 'annotations.dart';
import 'index.dart';

typedef SerializeObjectFunction = dynamic Function(Object object);
typedef DeserializeObjectFunction = dynamic Function(Object object, Type type);
typedef GetConverterFunction = ICustomConverter Function(
    JsonProperty jsonProperty, Type declarationType);
typedef GetConvertedValueFunction = dynamic Function(
    ICustomConverter converter, dynamic value,
    [SerializationContext serializationContext,
    DeserializationContext deserializationContext]);

/// Abstract class for custom converters implementations
abstract class ICustomConverter<T> {
  dynamic toJSON(T object, [SerializationContext context]);
  T fromJSON(dynamic jsonValue, [DeserializationContext context]);
}

/// Abstract class for custom iterable converters implementations
abstract class ICustomIterableConverter {
  void setIterableInstance(Iterable instance);
}

/// Abstract class for custom map converters implementations
abstract class ICustomMapConverter {
  void setMapInstance(Map instance);
}

/// Abstract class for custom Enum converters implementations
abstract class ICustomEnumConverter {
  void setEnumValues(Iterable enumValues);
}

/// Abstract class for composite converters relying on other converters
abstract class ICompositeConverter {
  void setGetConverterFunction(GetConverterFunction getConverter);
  void setGetConvertedValueFunction(
      GetConvertedValueFunction getConvertedValue);
}

/// Abstract class for custom recursive converters implementations
abstract class IRecursiveConverter {
  void setSerializeObjectFunction(SerializeObjectFunction serializeObject);
  void setDeserializeObjectFunction(
      DeserializeObjectFunction deserializeObject);
}

/// Base class for custom type converter having access to parameters provided
/// by the [JsonProperty] meta
class BaseCustomConverter {
  const BaseCustomConverter() : super();
  dynamic getConverterParameter(String name, [JsonProperty jsonProperty]) {
    return jsonProperty != null && jsonProperty.converterParams != null
        ? jsonProperty.converterParams[name]
        : null;
  }
}

const dateConverter = DateConverter();

/// Default converter for [DateTime] type
class DateConverter extends BaseCustomConverter implements ICustomConverter {
  const DateConverter() : super();

  @override
  Object fromJSON(dynamic jsonValue, [DeserializationContext context]) {
    final format = getDateFormat(context.jsonPropertyMeta);

    if (jsonValue is String) {
      return format != null
          ? format.parse(jsonValue)
          : DateTime.parse(jsonValue);
    }

    return jsonValue;
  }

  @override
  dynamic toJSON(Object object, [SerializationContext context]) {
    final format = getDateFormat(context.jsonPropertyMeta);
    return format != null && object != null && !(object is String)
        ? format.format(object)
        : (object is List)
            ? object.map((item) => item.toString()).toList()
            : object != null
                ? object.toString()
                : null;
  }

  DateFormat getDateFormat([JsonProperty jsonProperty]) {
    String format = getConverterParameter('format', jsonProperty);
    return format != null ? DateFormat(format) : null;
  }
}

const numberConverter = NumberConverter();

/// Default converter for [num] type
class NumberConverter extends BaseCustomConverter implements ICustomConverter {
  const NumberConverter() : super();

  @override
  Object fromJSON(dynamic jsonValue, [DeserializationContext context]) {
    final format = getNumberFormat(context.jsonPropertyMeta);
    return format != null && (jsonValue is String)
        ? getNumberFormat(context.jsonPropertyMeta).parse(jsonValue)
        : (jsonValue is String)
            ? num.tryParse(jsonValue) ?? jsonValue
            : jsonValue;
  }

  @override
  dynamic toJSON(Object object, [SerializationContext context]) {
    final format = getNumberFormat(context.jsonPropertyMeta);
    return object != null && format != null
        ? getNumberFormat(context.jsonPropertyMeta).format(object)
        : (object is String)
            ? num.tryParse(object)
            : object;
  }

  NumberFormat getNumberFormat([JsonProperty jsonProperty]) {
    String format = getConverterParameter('format', jsonProperty);
    return format != null ? NumberFormat(format) : null;
  }
}

final defaultEnumConverter = enumConverterShort;

final enumConverter = EnumConverter();

/// Long converter for [enum] type
class EnumConverter implements ICustomConverter, ICustomEnumConverter {
  EnumConverter() : super();

  Iterable _enumValues = [];

  @override
  Object fromJSON(dynamic jsonValue, [DeserializationContext context]) {
    dynamic convert(value) => _enumValues.firstWhere(
        (eValue) => eValue.toString() == value.toString(),
        orElse: () => null);
    return jsonValue is Iterable
        ? jsonValue.map(convert).toList()
        : convert(jsonValue);
  }

  @override
  dynamic toJSON(Object object, [SerializationContext context]) {
    dynamic convert(value) => value.toString();
    return (object is Iterable)
        ? object.map(convert).toList()
        : convert(object);
  }

  @override
  void setEnumValues(Iterable enumValues) {
    _enumValues = enumValues;
  }
}

final enumConverterShort = EnumConverterShort();

/// Default converter for [enum] type
class EnumConverterShort implements ICustomConverter, ICustomEnumConverter {
  EnumConverterShort() : super();

  Iterable _enumValues = [];

  @override
  Object fromJSON(dynamic jsonValue, [DeserializationContext context]) {
    dynamic convert(value) => _enumValues.firstWhere(
        (eValue) =>
            transformFieldName(
                eValue.toString().split('.').last, _getCaseStyle(context)) ==
            value.toString().split('.').last,
        orElse: () => null);
    return jsonValue is Iterable
        ? jsonValue.map(convert).toList()
        : convert(jsonValue);
  }

  @override
  dynamic toJSON(Object object, [SerializationContext context]) {
    dynamic convert(value) => value != null
        ? transformFieldName(
            value.toString().split('.').last, _getCaseStyle(context))
        : null;
    return (object is Iterable)
        ? object.map(convert).toList()
        : convert(object);
  }

  @override
  void setEnumValues(Iterable<dynamic> enumValues) {
    _enumValues = enumValues;
  }

  CaseStyle _getCaseStyle(DeserializationContext context) =>
      context.classMeta != null && context.classMeta.caseStyle != null
          ? context.classMeta.caseStyle
          : context.options.caseStyle;
}

const enumConverterNumeric = ConstEnumConverterNumeric();

/// Const wrapper for [EnumConverterNumeric]
class ConstEnumConverterNumeric
    implements ICustomConverter, ICustomEnumConverter {
  const ConstEnumConverterNumeric();

  @override
  Object fromJSON(jsonValue, [DeserializationContext context]) =>
      _enumConverterNumeric.fromJSON(jsonValue, context);

  @override
  dynamic toJSON(object, [SerializationContext context]) =>
      _enumConverterNumeric.toJSON(object, context);

  @override
  void setEnumValues(Iterable<dynamic> enumValues) {
    _enumConverterNumeric.setEnumValues(enumValues);
  }
}

final _enumConverterNumeric = EnumConverterNumeric();

/// Numeric index based converter for [enum] type
class EnumConverterNumeric implements ICustomConverter, ICustomEnumConverter {
  EnumConverterNumeric() : super();

  var _enumValues = [];

  @override
  Object fromJSON(dynamic jsonValue, [DeserializationContext context]) {
    return jsonValue is int ? _enumValues[jsonValue] : jsonValue;
  }

  @override
  dynamic toJSON(Object object, [SerializationContext context]) {
    return _enumValues.indexOf(object);
  }

  @override
  void setEnumValues(Iterable<dynamic> enumValues) {
    _enumValues = enumValues;
  }
}

const symbolConverter = SymbolConverter();

/// Default converter for [Symbol] type
class SymbolConverter implements ICustomConverter {
  const SymbolConverter() : super();

  @override
  Object fromJSON(dynamic jsonValue, [DeserializationContext context]) {
    return jsonValue is String ? Symbol(jsonValue) : jsonValue;
  }

  @override
  dynamic toJSON(Object object, [SerializationContext context]) {
    return object != null
        ? RegExp('"(.+)"').allMatches(object.toString()).first.group(1)
        : null;
  }
}

const durationConverter = DurationConverter();

/// DurationConverter converter for [Duration] type
class DurationConverter implements ICustomConverter<Duration> {
  const DurationConverter() : super();

  @override
  Duration fromJSON(dynamic jsonValue, [DeserializationContext context]) {
    return jsonValue is num ? Duration(microseconds: jsonValue) : jsonValue;
  }

  @override
  dynamic toJSON(Duration object, [SerializationContext context]) {
    return object != null ? object.inMicroseconds : null;
  }
}

const uint8ListConverter = Uint8ListConverter();

/// [Uint8List] converter to base64 and back
class Uint8ListConverter implements ICustomConverter {
  const Uint8ListConverter() : super();

  @override
  Object fromJSON(dynamic jsonValue, [DeserializationContext context]) {
    return jsonValue is String ? base64Decode(jsonValue) : jsonValue;
  }

  @override
  dynamic toJSON(Object object, [SerializationContext context]) {
    return object is Uint8List ? base64Encode(object) : object;
  }
}

const bigIntConverter = BigIntConverter();

/// [BigInt] converter
class BigIntConverter implements ICustomConverter {
  const BigIntConverter() : super();

  @override
  Object fromJSON(dynamic jsonValue, [DeserializationContext context]) {
    return jsonValue is String ? BigInt.tryParse(jsonValue) : jsonValue;
  }

  @override
  dynamic toJSON(Object object, [SerializationContext context]) {
    return object is BigInt ? object.toString() : object;
  }
}

final mapConverter = MapConverter();

/// [Map<K, V>] converter
class MapConverter
    implements ICustomConverter<Map>, IRecursiveConverter, ICustomMapConverter {
  MapConverter() : super();

  SerializeObjectFunction _serializeObject;
  DeserializeObjectFunction _deserializeObject;
  Map _instance;
  final _jsonDecoder = JsonDecoder();

  @override
  Map fromJSON(dynamic jsonValue, [DeserializationContext context]) {
    var result = jsonValue;
    final _typeInfo = context.typeInfo;
    if (jsonValue is String) {
      result = _jsonDecoder.convert(jsonValue);
    }
    if (_typeInfo != null && result is Map) {
      if (_instance != null && _instance is Map || _instance == null) {
        result = result.map((key, value) => MapEntry(
            _deserializeObject(key, _typeInfo.parameters.first),
            _deserializeObject(value, _typeInfo.parameters.last)));
      }
      if (_instance != null && _instance is Map) {
        result.forEach((key, value) => _instance[key] = value);
        result = _instance;
      }
    }
    return result;
  }

  @override
  dynamic toJSON(Map object, [SerializationContext context]) =>
      object.map((key, value) =>
          MapEntry(_serializeObject(key).toString(), _serializeObject(value)));

  @override
  void setSerializeObjectFunction(SerializeObjectFunction serializeObject) {
    _serializeObject = serializeObject;
  }

  @override
  void setDeserializeObjectFunction(
      DeserializeObjectFunction deserializeObject) {
    _deserializeObject = deserializeObject;
  }

  @override
  void setMapInstance(Map instance) {
    _instance = instance;
  }
}

final defaultIterableConverter = DefaultIterableConverter();

/// Default Iterable converter
class DefaultIterableConverter
    implements ICustomConverter, ICustomIterableConverter, ICompositeConverter {
  DefaultIterableConverter() : super();

  Iterable _instance;
  GetConverterFunction _getConverter;
  GetConvertedValueFunction _getConvertedValue;

  @override
  dynamic fromJSON(dynamic jsonValue, [DeserializationContext context]) {
    dynamic convert(item) => _getConvertedValue(
        _getConverter(context.jsonPropertyMeta, context.typeInfo.scalarType),
        item,
        null,
        context);

    if (_instance != null && jsonValue is Iterable && jsonValue != _instance) {
      if (_instance is List) {
        (_instance as List).clear();
        jsonValue.forEach((item) => (_instance as List).add(convert(item)));
      }
      if (_instance is Set) {
        (_instance as Set).clear();
        jsonValue.forEach((item) => (_instance as Set).add(convert(item)));
      }
      return _instance;
    }
    return jsonValue;
  }

  @override
  dynamic toJSON(dynamic object, [SerializationContext context]) {
    return object;
  }

  @override
  void setIterableInstance(Iterable instance) {
    _instance = instance;
  }

  @override
  void setGetConverterFunction(GetConverterFunction getConverter) {
    _getConverter = getConverter;
  }

  @override
  void setGetConvertedValueFunction(
      GetConvertedValueFunction getConvertedValue) {
    _getConvertedValue = getConvertedValue;
  }
}

const uriConverter = UriConverter();

/// Uri converter
class UriConverter implements ICustomConverter<Uri> {
  const UriConverter() : super();

  @override
  Uri fromJSON(dynamic jsonValue, [DeserializationContext context]) =>
      jsonValue is String ? Uri.tryParse(jsonValue) : jsonValue;

  @override
  String toJSON(Uri object, [SerializationContext context]) =>
      object.toString();
}

const regExpConverter = RegExpConverter();

/// RegExp converter
class RegExpConverter implements ICustomConverter<RegExp> {
  const RegExpConverter() : super();

  @override
  RegExp fromJSON(dynamic jsonValue, [DeserializationContext context]) =>
      jsonValue is String ? RegExp(jsonValue) : jsonValue;

  @override
  dynamic toJSON(RegExp object, [SerializationContext context]) =>
      object.pattern;
}

const defaultConverter = DefaultConverter();

/// Default converter for all types
class DefaultConverter implements ICustomConverter {
  const DefaultConverter() : super();

  @override
  Object fromJSON(dynamic jsonValue, [DeserializationContext context]) =>
      jsonValue;

  @override
  dynamic toJSON(Object object, [SerializationContext context]) => object;
}
