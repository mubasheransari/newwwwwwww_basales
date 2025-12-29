

import 'package:flutter/material.dart';
import 'package:new_amst_flutter/Model/products_data.dart';
import 'package:new_amst_flutter/Data/order_storage.dart';
import 'package:new_amst_flutter/Firebase/firebase_services.dart';
import 'package:new_amst_flutter/Repository/repository.dart';


const kText = Color(0xFF1E1E1E);
const kMuted = Color(0xFF707883);
const kField = Color(0xFFF2F3F5);
const kCard = Colors.white;
const kShadow = Color(0x14000000);

const _kGrad = LinearGradient(
  colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

const _kCardDeco = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(16)),
  boxShadow: [
    BoxShadow(
      color: Colors.black12,
      blurRadius: 12,
      offset: Offset(0, 6),
    ),
  ],
);

/* --------------------------- Primary Gradient Button --------------------------- */

class PrimaryGradientButton extends StatelessWidget {
  const PrimaryGradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final disabled = loading || onPressed == null;
    return Opacity(
      opacity: disabled ? 0.7 : 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: _kGrad,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7F53FD).withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: disabled ? null : onPressed,
            child: SizedBox(
              height: 44,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        text,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'ClashGrotesk',
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* --------------------------- Data Model --------------------------- */

class TeaItem {
  final String key;
  final String? itemId;
  final String name;
  final String desc;
  final String brand;

  const TeaItem({
    required this.key,
    required this.itemId,
    required this.name,
    required this.desc,
    required this.brand,
  });
}

/// Map your local `kTeaProducts` list (List<Map<String,dynamic>>) to TeaItem.
List<TeaItem> mapLocalToTea(List<Map<String, dynamic>> raw) {
  final list = <TeaItem>[];
  for (var i = 0; i < raw.length; i++) {
    final m = raw[i];
    final id = '${m['id'] ?? ''}'.trim();
    final name =
        '${m['name'] ?? m['item_name'] ?? 'Unknown Product'}'.trim();
    final desc = '${m['item_desc'] ?? ''}'.trim();
    final brandRaw = '${m['brand'] ?? ''}'.trim();
    final brand = brandRaw.isNotEmpty ? brandRaw : 'Meezan';
    final key = id.isNotEmpty ? id : '$name|$brand|$i';
    list.add(
      TeaItem(
        key: key,
        itemId: id.isNotEmpty ? id : null,
        name: name,
        desc: desc,
        brand: brand,
      ),
    );
  }
  return list;
}


class LocalTeaCatalogSkuOnly extends StatefulWidget {
  const LocalTeaCatalogSkuOnly({super.key});
  @override
  State<LocalTeaCatalogSkuOnly> createState() =>
      _LocalTeaCatalogSkuOnlyState();
}

class _LocalTeaCatalogSkuOnlyState extends State<LocalTeaCatalogSkuOnly> {
  final _search = TextEditingController();
  final _store = CartStorage(); 

  late final List<TeaItem> _all;
  final Map<String, int> _cartSku = {};
  String _selectedBrand = "All";

  @override
  void initState() {
    super.initState();
    _all = mapLocalToTea(kTeaProducts);
    _cartSku
      ..clear()
      ..addAll(_store.loadSku());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _getSku(String k) => _cartSku[k] ?? 0;
  Future<void> _persist() => _store.saveSku(_cartSku);

  void _incSku(TeaItem it) {
    setState(() => _cartSku[it.key] = _getSku(it.key) + 1);
    _persist();
  }

  void _decSku(TeaItem it) {
    setState(() {
      final q = _getSku(it.key);
      if (q > 1) {
        _cartSku[it.key] = q - 1;
      } else {
        _cartSku.remove(it.key);
      }
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
     final api = Repository(); // <-- use your repo class name
    final brands = <String>[
      "All",
      ...{for (final i in _all) i.brand}.where((s) => s.isNotEmpty),
    ];
    final q = _search.text.trim().toLowerCase();

    final filtered = _all.where((e) {
      final brandOk = _selectedBrand == "All" || e.brand == _selectedBrand;
      final searchOk = q.isEmpty ||
          e.name.toLowerCase().contains(q) ||
          e.desc.toLowerCase().contains(q);
      return brandOk && searchOk;
    }).toList();

    final totalSku = _cartSku.values.fold(0, (a, b) => a + b);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Products',
          style: TextStyle(
            color: kText,
            fontWeight: FontWeight.w700,
            fontFamily: 'ClashGrotesk',
          ),
        ),
        iconTheme: const IconThemeData(color: kText),
      ),
      bottomNavigationBar: totalSku <= 0
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: _PrimaryGradButton(
                    text: 'VIEW LIST ($totalSku)',
                    onPressed: () async {

//  debugPrint('🔘 Button tapped');

//             try {
//               final res = await api.createBaSale(
//                 skuId: '1',
//                 skuName: 'Tea Sample5',
//                 skuPrice: '500',
//                 skuQty: '10',
//                 brandName: 'Mezan',
//                 baCode: '001',
//                 createdBy: 'XYZ',
//               );

//               debugPrint('✅ createBaSale done: ${res.statusCode}');
//               debugPrint('Body: ${res.body}');
//             } catch (e, st) {
//               debugPrint('❌ Exception in caller: $e\n$st');
//             }                     
 final res =
                          await Navigator.of(context).push<Map<String, dynamic>>(
                        MaterialPageRoute(
                          builder: (_) => _CartScreenSkuOnly(
                            allItems: _all,
                            cartSku: _cartSku,
                          ),
                        ),
                      );
                      if (res?['submitted'] == true) {
                        setState(() => _cartSku.clear());
                        await _store.clear();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Order was successfully recorded in sales. ✅',
                              ),
                            ),
                          );
                        }
                      } else {
                        await _persist();
                      }
                    },
                  ),
                ),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Container(
                height: 52,
                decoration: _kCardDeco.copyWith(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEDEFF2)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: Colors.black54),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          hintText: 'Search products (e.g. UR, Green tea, 100)',
                          hintStyle: TextStyle(
                            color: Colors.black54,
                            fontFamily: 'ClashGrotesk',
                          ),
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.only(top: 2),
                        ),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          fontFamily: 'ClashGrotesk',
                        ),
                      ),
                    ),
                    if (_search.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.black45,
                        ),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Brand chips
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: brands.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final label = brands[i];
                  final selected = _selectedBrand == label;
                  return ChoiceChip(
                    label: Text(
                      label,
                      style: const TextStyle(fontFamily: 'ClashGrotesk'),
                    ),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _selectedBrand = label),
                    selectedColor: const Color(0xFF7F53FD),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : kText,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'ClashGrotesk',
                    ),
                    backgroundColor: Colors.white,
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: selected
                            ? Colors.transparent
                            : const Color(0xFFEDEFF2),
                      ),
                    ),
                    elevation: selected ? 2 : 0,
                  );
                },
              ),
            ),

            // Counts
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Text(
                    '${filtered.length} products',
                    style: const TextStyle(
                      color: kMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'ClashGrotesk',
                    ),
                  ),
                  const Spacer(),
                  if (totalSku > 0)
                    const Text(
                      'In list:',
                      style: TextStyle(
                        color: Color(0xFF7F53FD),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        fontFamily: 'ClashGrotesk',
                      ),
                    ),
                  if (totalSku > 0) const SizedBox(width: 6),
                  if (totalSku > 0)
                    Text(
                      'SKU $totalSku',
                      style: const TextStyle(
                        color: Color(0xFF7F53FD),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        fontFamily: 'ClashGrotesk',
                      ),
                    ),
                ],
              ),
            ),

            // Product list (cards at 95% width)
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(0, 6, 0, 16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final it = filtered[i];
                  return Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.95, // 95% width
                      child: _ProductCardSkuOnly(
                        name: it.name,
                        desc: it.desc,
                        brand: it.brand,
                        qty: _getSku(it.key),
                        onInc: () => _incSku(it),
                        onDec: () => _decSku(it),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* --------------------------- Product Card (95% width, SKU only) --------------------------- */

class _ProductCardSkuOnly extends StatelessWidget {
  const _ProductCardSkuOnly({
    required this.name,
    required this.desc,
    required this.brand,
    required this.qty,
    required this.onInc,
    required this.onDec,
  });

  final String name;
  final String desc;
  final String brand;
  final int qty;
  final VoidCallback onInc;
  final VoidCallback onDec;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      decoration: const BoxDecoration(
        gradient: _kGrad,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Container(
        margin: const EdgeInsets.all(1.6),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(14.4),
          boxShadow: const [
            BoxShadow(
              color: kShadow,
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7F53FD).withOpacity(.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFF7F53FD).withOpacity(.25),
                      ),
                    ),
                    child: Text(
                      brand,
                      style: const TextStyle(
                        color: kText,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        fontFamily: 'ClashGrotesk',
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium?.copyWith(
                      color: kText,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'ClashGrotesk',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(
                      color: kMuted,
                      fontFamily: 'ClashGrotesk',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _QtyControlsSku(qty: qty, onInc: onInc, onDec: onDec),
          ],
        ),
      ),
    );
  }
}

class _QtyControlsSku extends StatelessWidget {
  const _QtyControlsSku({
    required this.qty,
    required this.onInc,
    required this.onDec,
  });

  final int qty;
  final VoidCallback onInc;
  final VoidCallback onDec;

  @override
  Widget build(BuildContext context) {
    if (qty <= 0) {
      return SizedBox(
        width: 78,
        child: _PrimaryGradButton(text: 'ADD', onPressed: onInc),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: kField,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onDec,
            icon: const Icon(
              Icons.remove_rounded,
              size: 20,
              color: kText,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '$qty',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: kText,
                fontFamily: 'ClashGrotesk',
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onInc,
            icon: const Icon(
              Icons.add_rounded,
              size: 20,
              color: kText,
            ),
          ),
        ],
      ),
    );
  }
}

/* --------------------------- Cart (No Stack) --------------------------- */

class _CartScreenSkuOnly extends StatefulWidget {
  const _CartScreenSkuOnly({
    required this.allItems,
    required this.cartSku,
  });

  final List<TeaItem> allItems;
  final Map<String, int> cartSku;

  @override
  State<_CartScreenSkuOnly> createState() => _CartScreenSkuOnlyState();
}

class _CartScreenSkuOnlyState extends State<_CartScreenSkuOnly> {
  bool _saving = false;

  List<_CartRow> get _rows {
    final keys = widget.cartSku.keys.toList()..sort();
    return [
      for (final k in keys)
        _CartRow(
          item: widget.allItems.firstWhere(
            (e) => e.key == k,
            orElse: () => const TeaItem(
              key: 'missing',
              itemId: null,
              name: 'Unknown',
              desc: '',
              brand: 'Meezan',
            ),
          ),
          qty: widget.cartSku[k] ?? 0,
        )
    ]..removeWhere((r) => r.qty <= 0);
  }

  int get _total => widget.cartSku.values.fold(0, (a, b) => a + b);


    Future<void> _save() async {
    if (!mounted) return;
    setState(() => _saving = true);

    try {
      // ✅ Build an order record from the cart
      final lines = <Map<String, dynamic>>[
        for (final r in _rows)
          {
            'key': r.item.key,
            'itemId': r.item.itemId,
            'name': r.item.name,
            'brand': r.item.brand,
            'qty': r.qty,
          },
      ];

      final rec = OrderRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        lines: lines,
        itemCount: _rows.length,
        totalQty: _total,
        title: _rows.isNotEmpty
            ? '${_rows.first.item.name}${_rows.length > 1 ? ' +${_rows.length - 1} more' : ''}'
            : null,
      );

      // Save locally (existing charts/history keep working)
      await OrdersStorage().addOrder(rec);

      // Save to Firebase under users/{uid}/sales
      final uid = Fb.uid;
      if (uid != null) {
        await FbSalesRepo.addOrder(uid: uid, orderJson: rec.toJson());
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale saved to Firebase')),
      );
      Navigator.pop(context, {'submitted': true});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving sale: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

/*
  Future<void> _save() async {
    var api = Repository();

     try {
      final res = await api.createBaSale(
        skuId: '1',
        skuName: 'Tea Sample5',
        skuPrice: '500',
        skuQty: '10',
        brandName: 'Mezan',
        baCode: '001',
        createdBy: 'XYZ',
      );

      if (!context.mounted) return;

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('BA sale saved successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${res.statusCode}')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }

    // if (!mounted) return;
    // setState(() => _saving = true);
    // try {
    //   final lines = <Map<String, dynamic>>[
    //     for (final r in _rows)
    //       {
    //         'key': r.item.key,
    //         'itemId': r.item.itemId,
    //         'name': r.item.name,
    //         'brand': r.item.brand,
    //         'qty': r.qty,
    //       },
    //   ];

    //   final rec = OrderRecord(
    //     id: DateTime.now().microsecondsSinceEpoch.toString(),
    //     createdAt: DateTime.now(),
    //     lines: lines,
    //     itemCount: _rows.length,
    //     totalQty: _total,
    //     title: _rows.isNotEmpty
    //         ? '${_rows.first.item.name}${_rows.length > 1 ? ' +${_rows.length - 1} more' : ''}'
    //         : null,
    //   );

    //   await OrdersStorage().addOrder(rec);
    //   if (!mounted) return;
    //   Navigator.pop(context, {'submitted': true});
    // } finally {
    //   if (mounted) setState(() => _saving = false);
    // }
  }
*/
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      appBar: AppBar(
        elevation: 0,
        iconTheme: const IconThemeData(color: kText),
        title: const Text(
          'Order List',
          style: TextStyle(
            color: kText,
            fontWeight: FontWeight.w700,
            fontFamily: 'ClashGrotesk',
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: _PrimaryGradButton(
              text: 'CONFIRM & SAVE',
              onPressed: _rows.isEmpty || _saving ? null : _save,
              loading: _saving,
            ),
          ),
        ),
      ),
      body: _rows.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_grocery_store_outlined,
                    size: 56,
                    color: kMuted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your list is empty',
                    style: t.titleMedium?.copyWith(
                      color: kText,
                      fontFamily: 'ClashGrotesk',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add products from the catalog.',
                    style: t.bodySmall?.copyWith(
                      color: kMuted,
                      fontFamily: 'ClashGrotesk',
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: _rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final row = _rows[i];
                return Container(
                  decoration: _kCardDeco,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7F53FD).withOpacity(.10),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFF7F53FD)
                                      .withOpacity(.25),
                                ),
                              ),
                              child: Text(
                                row.item.brand,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: kText,
                                  fontFamily: 'ClashGrotesk',
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              row.item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.titleMedium?.copyWith(
                                color: kText,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'ClashGrotesk',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              row.item.desc,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodySmall?.copyWith(
                                color: kMuted,
                                fontFamily: 'ClashGrotesk',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F7),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Text(
                                'Qty: ${row.qty}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: kText,
                                  fontFamily: 'ClashGrotesk',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _CartRow {
  final TeaItem item;
  final int qty;
  const _CartRow({required this.item, required this.qty});
}

/* --------------------------- Small gradient button (internal) --------------------------- */

class _PrimaryGradButton extends StatelessWidget {
  const _PrimaryGradButton({
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final disabled = loading || onPressed == null;
    return Opacity(
      opacity: disabled ? 0.7 : 1,
      child: Container(
        height: 37,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: _kGrad,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7F53FD).withOpacity(0.2),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: disabled ? null : onPressed,
            child: SizedBox(
              height: 44,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        text,
                        style: const TextStyle(
                          fontFamily: 'ClashGrotesk',
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
