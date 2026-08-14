import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartAccountantApp());
}

class SmartAccountantApp extends StatelessWidget {
  const SmartAccountantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'المحاسب الذكي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A),
          primary: const Color(0xFF0F172A),
          secondary: const Color(0xFF0D9488),
          tertiary: const Color(0xFFD97706),
          background: const Color(0xFFF8FAFC),
        ),
        fontFamily: 'Roboto',
      ),
      home: const MainHomeScreen(),
    );
  }
}

// ==========================================
// DATABASE HELPER (قاعدة البيانات المحلية)
// ==========================================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('smart_accountant.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        buyPrice REAL NOT NULL,
        sellPrice REAL NOT NULL,
        quantity INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        customerName TEXT NOT NULL,
        phone TEXT NOT NULL,
        productName TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        totalAmount REAL NOT NULL,
        paidAmount REAL NOT NULL,
        remainingAmount REAL NOT NULL,
        date TEXT NOT NULL
      )
    ''');
  }

  // Operations for Products
  Future<int> insertProduct(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('products', row);
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await instance.database;
    return await db.query('products', orderBy: 'id DESC');
  }

  Future<int> updateProductQuantity(String name, int newQty) async {
    final db = await instance.database;
    return await db.update(
      'products',
      {'quantity': newQty},
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // Operations for Transactions
  Future<int> insertTransaction(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('transactions', row);
  }

  Future<List<Map<String, dynamic>>> getTransactions() async {
    final db = await instance.database;
    return await db.query('transactions', orderBy: 'id DESC');
  }

  Future<List<Map<String, dynamic>>> getDebts() async {
    final db = await instance.database;
    return await db.query('transactions',
        where: 'remainingAmount > ?', whereArgs: [0], orderBy: 'id DESC');
  }
}

// ==========================================
// MAIN SCREEN WITH NAVIGATION BAR
// ==========================================
class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardTab(),
    const InventoryTab(),
    const TransactionsTab(),
    const DebtsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 4,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calculate_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المحاسب الذكي',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
                Text(
                  'إعداد وتصميم: عقبة الرحيمي',
                  style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => _showAboutDialog(context),
          )
        ],
      ),
      drawer: _buildAppDrawer(context),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: Directionality(
        textDirection: TextDirection.rtl,
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF0D9488).withOpacity(0.2),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
            NavigationDestination(
                icon: Icon(Icons.inventory_2_rounded), label: 'المخزون'),
            NavigationDestination(
                icon: Icon(Icons.receipt_long_rounded), label: 'الفواتير'),
            NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_rounded),
                label: 'الديون'),
          ],
        ),
      ),
    );
  }

  Widget _buildAppDrawer(BuildContext context) {
    return Drawer(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                ),
              ),
              accountName: const Text(
                'برنامج المحاسبة والتجارة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              accountEmail: const Text(
                'مصمم التطبيق: عقبة الرحيمي',
                style: TextStyle(
                    color: Color(0xFFF59E0B), fontWeight: FontWeight.bold),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: const Color(0xFF0D9488),
                child: const Icon(Icons.account_balance_rounded,
                    size: 36, color: Colors.white),
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.developer_mode, color: Color(0xFF0D9488)),
              title: const Text('حول المصمم'),
              subtitle: const Text('عقبة الرحيمي - مطور تطبيقات'),
              onTap: () {
                Navigator.pop(context);
                _showAboutDialog(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.blueGrey),
              title: const Text('المساعدة والدعم'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.verified, color: Color(0xFF0D9488)),
            SizedBox(width: 8),
            Text('عن التطبيق'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('تطبيق المحاسبة الذكي وإدارة المخزون والديون.'),
            SizedBox(height: 12),
            Text('👨‍💻 **إعداد وتصميم:** عقبة الرحيمي',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            SizedBox(height: 6),
            Text(
                '⚡ يتيح لك التطبيق إرسال الرسائل والفواتير عبر واتساب ورسائل SMS مباشرة للعملاء.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          )
        ],
      ),
    );
  }
}

// ==========================================
// 1. DASHBOARD TAB (الرئيسية)
// ==========================================
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  double totalSales = 0.0;
  double totalPurchases = 0.0;
  double totalDebts = 0.0;
  int totalProducts = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final db = DatabaseHelper.instance;
    final transactions = await db.getTransactions();
    final products = await db.getProducts();

    double sales = 0;
    double purchases = 0;
    double debts = 0;

    for (var t in transactions) {
      final amt = (t['totalAmount'] as num).toDouble();
      final rem = (t['remainingAmount'] as num).toDouble();
      if (t['type'] == 'sale') {
        sales += amt;
      } else {
        purchases += amt;
      }
      debts += rem;
    }

    setState(() {
      totalSales = sales;
      totalPurchases = purchases;
      totalDebts = debts;
      totalProducts = products.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Welcome Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'أهلاً بك في المحاسب الذكي 📈',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('تصميم: عقبة الرحيمي',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'إدارة احترافية للمبيعات، المشتريات، الديون وإشعارات الواتساب.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Cards Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _buildStatCard(
                  'إجمالي المبيعات',
                  '\$${totalSales.toStringAsFixed(2)}',
                  Icons.arrow_upward_rounded,
                  Colors.green),
              _buildStatCard(
                  'إجمالي المشتريات',
                  '\$${totalPurchases.toStringAsFixed(2)}',
                  Icons.arrow_downward_rounded,
                  Colors.orange),
              _buildStatCard(
                  'إجمالي الديون/المتبقي',
                  '\$${totalDebts.toStringAsFixed(2)}',
                  Icons.account_balance_wallet_rounded,
                  Colors.redAccent),
              _buildStatCard('عدد الأصناف', '$totalProducts صنف',
                  Icons.category_rounded, Colors.blue),
            ],
          ),
          const SizedBox(height: 20),

          // Quick Action Section
          const Text('عمليات سريعة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _openNewTransactionModal(context, 'sale'),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('فاتورة بيع جديدة'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () =>
                      _openNewTransactionModal(context, 'purchase'),
                  icon: const Icon(Icons.add_business_rounded),
                  label: const Text('فاتورة شراء'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              CircleAvatar(
                radius: 16,
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  void _openNewTransactionModal(BuildContext context, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => NewTransactionDialog(type: type, onSaved: _loadStats),
    );
  }
}

// ==========================================
// 2. INVENTORY TAB (إدارة المخزون)
// ==========================================
class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _refreshProducts();
  }

  Future<void> _refreshProducts() async {
    final data = await DatabaseHelper.instance.getProducts();
    setState(() {
      _products = data;
    });
  }

  void _showAddProductDialog() {
    final nameCtrl = TextEditingController();
    final buyPriceCtrl = TextEditingController();
    final sellPriceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إضافة صنف جديد بالمخزون'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'اسم الصنف')),
                TextField(
                    controller: buyPriceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'سعر الشراء')),
                TextField(
                    controller: sellPriceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'سعر البيع')),
                TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'الكمية الأولية')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488)),
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty && qtyCtrl.text.isNotEmpty) {
                  await DatabaseHelper.instance.insertProduct({
                    'name': nameCtrl.text,
                    'buyPrice': double.tryParse(buyPriceCtrl.text) ?? 0.0,
                    'sellPrice': double.tryParse(sellPriceCtrl.text) ?? 0.0,
                    'quantity': int.tryParse(qtyCtrl.text) ?? 0,
                  });
                  Navigator.pop(ctx);
                  _refreshProducts();
                }
              },
              child: const Text('حفظ الصنف',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D9488),
        onPressed: _showAddProductDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة صنف', style: TextStyle(color: Colors.white)),
      ),
      body: _products.isEmpty
          ? const Center(child: Text('لا توجد أصناف في المخزون حالياً'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _products.length,
              itemBuilder: (ctx, i) {
                final item = _products[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF0F172A),
                      child: Text('${item['quantity']}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                    title: Text(item['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'سعر الشراء: \$${item['buyPrice']} | سعر البيع: \$${item['sellPrice']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        await DatabaseHelper.instance.deleteProduct(item['id']);
                        _refreshProducts();
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ==========================================
// 3. TRANSACTIONS TAB (سجل الفواتير)
// ==========================================
class TransactionsTab extends StatefulWidget {
  const TransactionsTab({super.key});

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final list = await DatabaseHelper.instance.getTransactions();
    setState(() {
      _transactions = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _transactions.isEmpty
          ? const Center(child: Text('لا توجد فواتير مسجلة بعد'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _transactions.length,
              itemBuilder: (ctx, i) {
                final t = _transactions[i];
                final isSale = t['type'] == 'sale';

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Icon(
                      isSale ? Icons.shopping_bag : Icons.local_shipping,
                      color: isSale ? Colors.green : Colors.orange,
                    ),
                    title: Text(
                        '${isSale ? "بيع" : "شراء"}: ${t['customerName']}'),
                    subtitle: Text(
                        'الصنف: ${t['productName']} | المتبقي: \$${t['remainingAmount']}\nالتاريخ: ${t['date']}'),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('\$${t['totalAmount']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        IconButton(
                          icon: const Icon(Icons.print,
                              size: 20, color: Color(0xFF0F172A)),
                          onPressed: () => MessageHelper.generatePdfInvoice(t),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ==========================================
// 4. DEBTS TAB (الديون والمستحقات مع الواتساب)
// ==========================================
class DebtsTab extends StatefulWidget {
  const DebtsTab({super.key});

  @override
  State<DebtsTab> createState() => _DebtsTabState();
}

class _DebtsTabState extends State<DebtsTab> {
  List<Map<String, dynamic>> _debts = [];

  @override
  void initState() {
    super.initState();
    _loadDebts();
  }

  Future<void> _loadDebts() async {
    final list = await DatabaseHelper.instance.getDebts();
    setState(() {
      _debts = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _debts.isEmpty
          ? const Center(child: Text('🎉 ممتاز! لا توجد أية ديون معلقة'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _debts.length,
              itemBuilder: (ctx, i) {
                final d = _debts[i];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(d['customerName'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('المتبقي: \$${d['remainingAmount']}',
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                            'الهاتف: ${d['phone']} | الصنف: ${d['productName']}'),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  foregroundColor: Colors.white),
                              onPressed: () {
                                final msg =
                                    'عزيزي ${d['customerName']}، نود تذكيركم بالقبل المبلغ المتبقي وقدره \$${d['remainingAmount']} الخاص بفاتورة ${d['productName']}.\nشكراً لتعاملكم معنا!\n— إعداد التطبيق: عقبة الرحيمي';
                                MessageHelper.sendWhatsApp(d['phone'], msg);
                              },
                              icon: const Icon(Icons.chat),
                              label: const Text('تذكير واتساب'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                final msg =
                                    'تذكير: المتبقي عليك مبلغ \$${d['remainingAmount']} لصالح المحاسب الذكي.';
                                MessageHelper.sendSMS(d['phone'], msg);
                              },
                              icon: const Icon(Icons.sms),
                              label: const Text('إرسال SMS'),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ==========================================
// NEW TRANSACTION DIALOG FORM
// ==========================================
class NewTransactionDialog extends StatefulWidget {
  final String type; // 'sale' or 'purchase'
  final VoidCallback onSaved;

  const NewTransactionDialog(
      {super.key, required this.type, required this.onSaved});

  @override
  State<NewTransactionDialog> createState() => _NewTransactionDialogState();
}

class _NewTransactionDialogState extends State<NewTransactionDialog> {
  final _customerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _paidCtrl = TextEditingController();

  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic>? _selectedProduct;

  double totalAmount = 0.0;
  double remainingAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    final list = await DatabaseHelper.instance.getProducts();
    setState(() {
      _products = list;
      if (list.isNotEmpty) {
        _selectedProduct = list.first;
        _calculateTotal();
      }
    });
  }

  void _calculateTotal() {
    if (_selectedProduct == null) return;
    final qty = int.tryParse(_qtyCtrl.text) ?? 1;
    final price = widget.type == 'sale'
        ? (_selectedProduct!['sellPrice'] as num).toDouble()
        : (_selectedProduct!['buyPrice'] as num).toDouble();

    final paid = double.tryParse(_paidCtrl.text) ?? 0.0;

    setState(() {
      totalAmount = qty * price;
      remainingAmount = totalAmount - paid;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSale = widget.type == 'sale';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSale
                    ? 'تسجيل فاتورة بيع جديدة 🛒'
                    : 'تسجيل فاتورة شراء جديدة 📦',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _customerCtrl,
                decoration: InputDecoration(
                  labelText: isSale ? 'اسم العميل' : 'اسم المورد',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف (مع الرمز الدولي للواتساب)',
                  border: OutlineInputBorder(),
                  hintText: '+967xxxxxxxxx',
                ),
              ),
              const SizedBox(height: 10),
              _products.isEmpty
                  ? const Text('⚠️ رجاء إضافة منتجات في صفحة المخزون أولاً',
                      style: TextStyle(color: Colors.red))
                  : DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedProduct,
                      decoration: const InputDecoration(
                          labelText: 'اختر الصنف',
                          border: OutlineInputBorder()),
                      items: _products.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child:
                              Text('${p['name']} (المتوفر: ${p['quantity']})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedProduct = val;
                          _calculateTotal();
                        });
                      },
                    ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'الكمية', border: OutlineInputBorder()),
                      onChanged: (_) => _calculateTotal(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _paidCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'المبلغ المدفوع',
                          border: OutlineInputBorder()),
                      onChanged: (_) => _calculateTotal(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('الإجمالي: \$${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('المتبقي: \$${remainingAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () async {
                  if (_customerCtrl.text.isEmpty || _selectedProduct == null)
                    return;

                  final now = intl.DateFormat('yyyy-MM-dd HH:mm')
                      .format(DateTime.now());
                  final qty = int.tryParse(_qtyCtrl.text) ?? 1;

                  final row = {
                    'type': widget.type,
                    'customerName': _customerCtrl.text,
                    'phone': _phoneCtrl.text,
                    'productName': _selectedProduct!['name'],
                    'quantity': qty,
                    'totalAmount': totalAmount,
                    'paidAmount': double.tryParse(_paidCtrl.text) ?? 0.0,
                    'remainingAmount': remainingAmount,
                    'date': now,
                  };

                  await DatabaseHelper.instance.insertTransaction(row);

                  // Update stock level
                  final currentQty = _selectedProduct!['quantity'] as int;
                  final newQty =
                      isSale ? (currentQty - qty) : (currentQty + qty);
                  await DatabaseHelper.instance
                      .updateProductQuantity(_selectedProduct!['name'], newQty);

                  widget.onSaved();
                  Navigator.pop(context);

                  // Offer sending notification message
                  if (_phoneCtrl.text.isNotEmpty) {
                    final messageText =
                        'مرحباً ${_customerCtrl.text}، تم تسجيل عملية ${isSale ? "شراء" : "توريد"} لمنتج ${_selectedProduct!['name']} بنجاح.\nالإجمالي: \$$totalAmount | المدفوع: \$${_paidCtrl.text}\nالمتبقي: \$$remainingAmount.\nشكراً لتعاملكم معنا! (تطبيق تصميم: عقبة الرحيمي)';
                    MessageHelper.sendWhatsApp(_phoneCtrl.text, messageText);
                  }
                },
                child: const Text('حفظ وإرسال الفاتورة',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// HELPER FOR MESSAGING & PDF PRINTING
// ==========================================
class MessageHelper {
  static Future<void> sendWhatsApp(String phone, String text) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse(
        "https://wa.me/$cleanPhone?text=${Uri.encodeComponent(text)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> sendSMS(String phone, String text) async {
    final url = Uri.parse("sms:$phone?body=${Uri.encodeComponent(text)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  static Future<void> generatePdfInvoice(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                    level: 0,
                    child: pw.Text('فاتورة حساب - المحاسب الذكي',
                        style: pw.TextStyle(
                            fontSize: 24, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(height: 10),
                pw.Text('العميل / المورد: ${data['customerName']}'),
                pw.Text('التاريخ: ${data['date']}'),
                pw.Text(
                    'نوع العملية: ${data['type'] == 'sale' ? 'بيع' : 'شراء'}'),
                pw.Divider(),
                pw.Text('المنتج: ${data['productName']}'),
                pw.Text('الكمية: ${data['quantity']}'),
                pw.Text('الإجمالي: \$${data['totalAmount']}'),
                pw.Text('المدفوع: \$${data['paidAmount']}'),
                pw.Text('المتبقي: \$${data['remainingAmount']}'),
                pw.Divider(),
                pw.SizedBox(height: 20),
                pw.Center(
                    child: pw.Text(
                        'تم إنشاء هذه الفاتورة عبر تطبيق المحاسب الذكي - إعداد وتصميم: عقبة الرحيمي')),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
