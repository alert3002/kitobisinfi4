/// ҷ/ғ/ҳ/ӯ/ӣ → ч/г/х/у/и, то ҷустуҷӯ бе клавиатураи тоҷикӣ ҳам кор кунад.
String foldTajik(String input) {
  final b = StringBuffer();
  for (final unit in input.toLowerCase().codeUnits) {
    switch (unit) {
      case 0x04B7: // ҷ
        b.writeCharCode(0x0447); // ч
      case 0x0493: // ғ
        b.writeCharCode(0x0433); // г
      case 0x04B3: // ҳ
        b.writeCharCode(0x0445); // х
      case 0x04EF: // ӯ
        b.writeCharCode(0x0443); // у
      case 0x04E3: // ӣ
        b.writeCharCode(0x0438); // и
      default:
        b.writeCharCode(unit);
    }
  }
  return b.toString();
}

Pattern tajikSearchPattern(String query) {
  final q = query.trim();
  final b = StringBuffer();
  for (final ch in q.split('')) {
    switch (ch.toLowerCase()) {
      case 'ҷ':
      case 'ч':
        b.write('[ҷчҶЧ]');
      case 'ғ':
      case 'г':
        b.write('[ғгҒГ]');
      case 'ҳ':
      case 'х':
        b.write('[ҳхҲХ]');
      case 'ӯ':
      case 'у':
        b.write('[ӯуӮУ]');
      case 'ӣ':
      case 'и':
        b.write('[ӣиӢИ]');
      default:
        b.write(RegExp.escape(ch));
    }
  }
  return RegExp(b.toString(), caseSensitive: false, unicode: true);
}
