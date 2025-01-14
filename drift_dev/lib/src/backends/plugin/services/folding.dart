import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/folding/folding.dart';
import 'package:drift_dev/src/backends/plugin/services/requests.dart';
import 'package:sqlparser/sqlparser.dart';

class MoorFoldingContributor implements FoldingContributor {
  const MoorFoldingContributor();

  @override
  void computeFolding(FoldingRequest request, FoldingCollector collector) {
    final moorRequest = request as MoorRequest;

    if (moorRequest.isMoorAndParsed) {
      final result = moorRequest.parsedMoor;
      final visitor = _FoldingVisitor(collector);
      result.parsedFile.acceptWithoutArg(visitor);
    }
  }
}

class _FoldingVisitor extends RecursiveVisitor<void, void> {
  final FoldingCollector collector;

  _FoldingVisitor(this.collector);

  @override
  void visitDriftSpecificNode(DriftSpecificNode e, void arg) {
    if (e is DriftFile) {
      visitMoorFile(e, arg);
    } else {
      visitChildren(e, arg);
    }
  }

  void visitMoorFile(DriftFile e, void arg) {
    // construct a folding region for import statements
    final imports = e.imports.toList();
    if (imports.length > 1) {
      final first = imports.first.firstPosition;
      final last = imports.last.lastPosition;

      collector.addRegion(first, last - first, FoldingKind.DIRECTIVES);
    }

    visitChildren(e, arg);
  }

  @override
  void visitCreateTableStatement(CreateTableStatement e, void arg) {
    final startBody = e.openingBracket;
    final endBody = e.closingBracket;

    if (startBody == null || endBody == null) return;

    // report everything between the two brackets as class body
    final first = startBody.span.end.offset + 1;
    final last = endBody.span.start.offset - 1;

    if (last - first < 0) return; // empty body, e.g. CREATE TABLE ()

    collector.addRegion(first, last - first, FoldingKind.CLASS_BODY);
  }
}
