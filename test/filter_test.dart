import 'package:query/query.dart';
import 'package:test/test.dart';

void main() {
  group('filter test', () {
    test('TextQuery', () {
      final result = parseToFilter('test', ['colA', 'colB']);
      print(result);

      expect(result, "colA ~ '%test%' OR colB ~ '%test%'");
    });

    test('PhraseQuery', () {
      final result = parseToFilter('colA = "test phrase"', ['colA', 'colB']);

      expect(result, "colA = 'test phrase'");
    });

    test('ScopeQuery', () {
      final result = parseToFilter("colA:test", ['colA', 'colB']);

      expect(result, "colA = 'test'");
    });

    test('CompareQuery', () {
      final result = parseToFilter("colA > test", ['colA', 'colB']);

      expect(result, "colA > 'test'");
    });
  });
}

extension on Query {
  /// Convert the query to a filter string.
  /// - (Implicit) boolean AND: `a AND b` or `a b`
  /// - boolean OR: `a OR b OR c`
  /// - boolean NOT: `-a` or `NOT a`
  /// - group query: `(a b) OR (c d)`
  /// - text match: `abc` or `"words in close proximity"`
  /// - range query: `[1 TO 20]` (inclusive), `]aaa TO dzz[` (exclusive), or `[1 TO 20[` (mixed)
  /// - scopes: `field:(a b)` or `field:abc`
  /// - field comparison: `year < 2000`
  Iterable<String> toFilter({
    bool negate = false,
    bool exact = false,
  }) sync* {
    print((this.runtimeType, this));
    // = Equal
    // != NOT equal
    // > Greater than
    // >= Greater than or equal
    // < Less than
    // <= Less than or equal
    // ~ Like/Contains (if not specified auto wraps the right string OPERAND in a "%" for wildcard match)
    // !~ NOT Like/Contains (if not specified auto wraps the right string OPERAND in a "%" for wildcard match)
    // ?= Any/At least one of Equal
    // ?!= Any/At least one of NOT equal
    // ?> Any/At least one of Greater than
    // ?>= Any/At least one of Greater than or equal
    // ?< Any/At least one of Less than
    // ?<= Any/At least one of Less than or equal
    // ?~ Any/At least one of Like/Contains (if not specified auto wraps the right string OPERAND in a "%" for wildcard match)
    // ?!~ Any/At least one of NOT Like/Contains (if not specified auto wraps the right string OPERAND in a "%" for wildcard match)
    var target = this;
    String op() {
      return [
        negate ? '!' : '',
        exact ? '=' : '~',
      ].join('');
    }

    if (target is GroupQuery) {
      yield '(${target.child.toFilter(negate: negate, exact: exact).join()})';
      return;
    }
    if (target is ScopeQuery) {
      exact = true;
      yield "${target.field.text} ${target.child.toFilter(negate: negate, exact: exact).join()}";
      return;
    }
    if (target is CompareQuery) {
      yield "${target.field.text} ${target.operator.text} '${target.text.text}'";
      return;
    }
    if (target is NotQuery) {
      negate = true;
      yield* target.child.toFilter(negate: negate, exact: exact);
      return;
    }
    if (target is AndQuery) {
      yield target.children
          .map((n) => n.toFilter(negate: negate, exact: exact).join())
          .toList()
          .join(' AND ');
      return;
    }
    if (target is OrQuery) {
      yield target.children
          .map((n) => n.toFilter(negate: negate, exact: exact).join())
          .toList()
          .join(' OR ');
      return;
    }
    if (target is PhraseQuery) {
      exact = true;
      final str = target.children.map((n) => n.text).join();
      yield "${op()} '$str'";
      return;
    }
    if (target is TextQuery) {
      yield "${op()} '";
      if (!exact) yield "%";
      yield target.text;
      if (!exact) yield "%";
      yield "'";
      return;
    }
  }
}

String parseToFilter(String src, List<String> fields) {
  var query = parseQuery(src);
  if (query is TextQuery) {
    src = fields.map((f) => f + " ~ '%$src%'").join(' OR ');
    query = parseQuery(src);
  }
  final result = query.toFilter().join();
  print('parse: "$src" "$result"');
  return result;
}

// class TargetAllTextQuery extends TextQuery {
//   final List<String> fields;
//   TargetAllTextQuery({
//     required super.text,
//     required super.position,
//     required this.fields,
//   });
// }

enum QueryMode {
  and,
  or,
}

class QueryNotSupportedError extends Error {
  QueryNotSupportedError(this.query);

  final Query query;

  @override
  String toString() {
    return 'QueryNotSupportedError: ${query}';
  }
}
