import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

class PlutoLeftFrozenColumns extends PlutoStatefulWidget {
  final PlutoGridStateManager stateManager;

  const PlutoLeftFrozenColumns(
    this.stateManager, {
    super.key,
  });

  @override
  PlutoLeftFrozenColumnsState createState() => PlutoLeftFrozenColumnsState();
}

class PlutoLeftFrozenColumnsState
    extends PlutoStateWithChange<PlutoLeftFrozenColumns> {
  List<PlutoColumn> _columns = [];

  List<PlutoColumnGroupPair> _columnGroups = [];

  bool _showColumnGroups = false;

  int _itemCount = 0;

  @override
  PlutoGridStateManager get stateManager => widget.stateManager;

  @override
  void initState() {
    super.initState();

    updateState();
  }

  @override
  void updateState() {
    _showColumnGroups = update<bool>(
      _showColumnGroups,
      stateManager.showColumnGroups,
    );

    _columns = update<List<PlutoColumn>>(
      _columns,
      _getColumns(),
      compare: listEquals,
    );

    if (changed && _showColumnGroups == true) {
      _columnGroups = stateManager.separateLinkedGroup(
        columnGroupList: stateManager.refColumnGroups!,
        columns: _columns,
      );
    }

    _itemCount = update<int>(_itemCount, _getItemCount());
  }

  List<PlutoColumn> _getColumns() {
    return stateManager.isLTR
        ? stateManager.leftFrozenColumns
        : stateManager.leftFrozenColumns.reversed.toList(growable: false);
  }

  int _getItemCount() {
    return _showColumnGroups == true ? _columnGroups.length : _columns.length;
  }

  Widget _buildColumnGroup(PlutoColumnGroupPair e) {
    return PlutoVisibilityLayoutId(
      id: e.key,
      child: PlutoBaseColumnGroup(
        stateManager: stateManager,
        columnGroup: e,
        depth: stateManager.columnGroupDepth(
          stateManager.refColumnGroups!,
        ),
      ),
    );
  }

  Widget _buildColumn(e) {
    return PlutoVisibilityLayoutId(
      id: e.field,
      child: PlutoBaseColumn(
        stateManager: stateManager,
        column: e,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomMultiChildLayout(
        delegate: MainColumnLayoutDelegate(
          stateManager: stateManager,
          columns: _columns,
          columnGroups: _columnGroups,
          frozen: PlutoColumnFrozen.start,
        ),
        children: _showColumnGroups == true
            ? _columnGroups.map(_buildColumnGroup).toList()
            : _columns.map(_buildColumn).toList());
  }
}
