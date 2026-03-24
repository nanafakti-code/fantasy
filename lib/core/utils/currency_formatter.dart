import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class CurrencyFormatter {
  static String format(num value) {
    // Reemplazamos los separadores para asegurar el formato solicitado (puntos para miles, sin decimales)
    final formatted = NumberFormat.decimalPattern('es_ES').format(value.toInt());
    return '$formatted€';
  }
}

extension CurrencyFormatting on num {
  String get toCurrency => CurrencyFormatter.format(this);
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Limpiar entrada para dejar solo números
    String cleanedStr = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cleanedStr.isEmpty) {
      return newValue.copyWith(text: '', selection: const TextSelection.collapsed(offset: 0));
    }

    // Manejar números extremadamente largos para evitar errores de parseo
    if (cleanedStr.length > 12) {
      cleanedStr = cleanedStr.substring(0, 12);
    }

    final double value = double.parse(cleanedStr);
    
    // Formatear con puntos para miles
    final formatter = NumberFormat.decimalPattern('es_ES');
    final String newText = formatter.format(value.toInt());

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
