import 'dart:ui';

/// Parses SVG path data (`M L H V C S A Z`, absolute and relative) into a
/// [Path]. Enough for the icon paths in design/source; not a general SVG
/// parser. Throws [FormatException] on anything it does not understand.
Path parseSvgPath(String d) {
  final p = _Parser(d);
  final path = Path();
  var x = 0.0, y = 0.0; // current point
  var sx = 0.0, sy = 0.0; // subpath start
  double? cx, cy; // last cubic control point, for S
  String? cmd;

  while (true) {
    p.skipSeparators();
    if (p.done) break;
    if (p.atCommand) cmd = p.readCommand();
    if (cmd == null) throw FormatException('Path must start with a command', d);
    final rel = cmd.toLowerCase() == cmd;
    final c = cmd.toLowerCase();
    double ox() => rel ? x : 0;
    double oy() => rel ? y : 0;

    switch (c) {
      case 'm':
        x = ox() + p.number();
        y = oy() + p.number();
        path.moveTo(x, y);
        sx = x;
        sy = y;
        cx = cy = null;
        // Extra pairs after M are implicit lineTos.
        cmd = rel ? 'l' : 'L';
      case 'l':
        x = ox() + p.number();
        y = oy() + p.number();
        path.lineTo(x, y);
        cx = cy = null;
      case 'h':
        x = ox() + p.number();
        path.lineTo(x, y);
        cx = cy = null;
      case 'v':
        y = oy() + p.number();
        path.lineTo(x, y);
        cx = cy = null;
      case 'c':
        final x1 = ox() + p.number(), y1 = oy() + p.number();
        final x2 = ox() + p.number(), y2 = oy() + p.number();
        final nx = ox() + p.number(), ny = oy() + p.number();
        path.cubicTo(x1, y1, x2, y2, nx, ny);
        cx = x2;
        cy = y2;
        x = nx;
        y = ny;
      case 's':
        final x1 = cx == null ? x : 2 * x - cx;
        final y1 = cy == null ? y : 2 * y - cy;
        final x2 = ox() + p.number(), y2 = oy() + p.number();
        final nx = ox() + p.number(), ny = oy() + p.number();
        path.cubicTo(x1, y1, x2, y2, nx, ny);
        cx = x2;
        cy = y2;
        x = nx;
        y = ny;
      case 'a':
        final rx = p.number(), ry = p.number();
        final rot = p.number();
        final large = p.flag(), sweep = p.flag();
        final nx = ox() + p.number(), ny = oy() + p.number();
        path.arcToPoint(
          Offset(nx, ny),
          radius: Radius.elliptical(rx, ry),
          rotation: rot,
          largeArc: large,
          clockwise: sweep,
        );
        x = nx;
        y = ny;
        cx = cy = null;
      case 'z':
        path.close();
        x = sx;
        y = sy;
        cx = cy = null;
      default:
        throw FormatException('Unsupported path command "$cmd"', d);
    }
  }
  return path;
}

class _Parser {
  _Parser(this.s);

  final String s;
  int i = 0;

  bool get done => i >= s.length;

  static const _commands = 'MmLlHhVvCcSsAaZz';

  bool get atCommand => _commands.contains(s[i]);

  String readCommand() => s[i++];

  void skipSeparators() {
    while (i < s.length && (s[i] == ' ' || s[i] == ',' || s[i] == '\n')) {
      i++;
    }
  }

  double number() {
    skipSeparators();
    final start = i;
    if (i < s.length && (s[i] == '-' || s[i] == '+')) i++;
    var seenDot = false;
    while (i < s.length) {
      final ch = s[i];
      if (ch == '.' && !seenDot) {
        seenDot = true;
        i++;
      } else if (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) {
        i++;
      } else {
        break;
      }
    }
    if (start == i) throw FormatException('Expected a number at $start', s);
    return double.parse(s.substring(start, i));
  }

  /// Arc flags are a single `0` or `1` and may be packed without separators.
  bool flag() {
    skipSeparators();
    if (i >= s.length || (s[i] != '0' && s[i] != '1')) {
      throw FormatException('Expected an arc flag at $i', s);
    }
    return s[i++] == '1';
  }
}
