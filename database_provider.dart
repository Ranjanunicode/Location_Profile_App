import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../constants/icons.dart';
import 'profile_category.dart';
import 'profile.dart';

class DatabaseProvider with ChangeNotifier {
  String _searchText = '';
  String get searchText => _searchText;
  set searchText(String value) {
    _searchText = value;
    notifyListeners();
    // when the value of the search text changes it will notify the widgets.
  }

  // in-app memory for holding the Expense categories temporarily
  List<ProfileCategory> _categories = [];
  List<ProfileCategory> get categories => _categories;

  List<Profile> _profiles = [];
  // when the search text is empty, return whole list, else search for the value
  List<Profile> get profiles {
    return _searchText != ''
        ? _profiles
            .where((e) =>
                e.title.toLowerCase().contains(_searchText.toLowerCase()))
            .toList()
        : _profiles;
  }

  Database? _database;
  Future<Database> get database async {
    // database directory
    final dbDirectory = await getDatabasesPath();
    // database name
    const dbName = 'profile_tc.db';
    // full path
    final path = join(dbDirectory, dbName);

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: _createDb, // will create this separately
    );

    return _database!;
  }

  // _createDb function
  static const cTable = 'categoryTable';
  static const pTable = 'profileTable';
  Future<void> _createDb(Database db, int version) async {
    // this method runs only once. when the database is being created
    // so create the tables here and if you want to insert some initial values
    // insert it in this function.

    await db.transaction((txn) async {
      // category table
      await txn.execute('''CREATE TABLE $cTable(
        title TEXT,
        entries INTEGER 
      )''');

      // totalAmount TEXT
      // profile table
      await txn.execute('''CREATE TABLE $pTable(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        latitude TEXT,
        longitude TEXT,
        date TEXT,
        category TEXT
      )''');

      //  latitude TEXT,   latitude longitude
      //  longitude TEXT,
      //  amount TEXT,

      // insert the initial categories.
      // this will add all the categories to category table and initialize the 'entries' with 0 and 'totalAmount' to 0.0
      for (int i = 0; i < icons.length; i++) {
        await txn.insert(cTable, {
          'title': icons.keys.toList()[i],
          'entries': 0,
          // 'totalAmount': (0.0).toString(),
        });
      }
    });
  }

  // method to fetch categories

  Future<List<ProfileCategory>> fetchCategories() async {
    // get the database
    final db = await database;
    return await db.transaction((txn) async {
      return await txn.query(cTable).then((data) {
        // 'data' is our fetched value
        // convert it from "Map<String, object>" to "Map<String, dynamic>"
        final converted = List<Map<String, dynamic>>.from(data);
        // create a 'ExpenseCategory'from every 'map' in this 'converted'
        List<ProfileCategory> nList = List.generate(converted.length,
            (index) => ProfileCategory.fromString(converted[index]));
        // set the value of 'categories' to 'nList'
        _categories = nList;
        // return the '_categories'
        return _categories;
      });
    });
  }

  Future<void> updateCategory(
    String category,
    int nEntries,
    // double nTotalAmount,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn
          .update(
        cTable, // category table
        {
          'entries': nEntries, // new value of 'entries'
          // 'totalAmount': nTotalAmount.toString(), // new value of 'totalAmount'
        },
        where: 'title == ?', // in table where the title ==
        whereArgs: [category], // this category.
      )
          .then((_) {
        // after updating in database. update it in our in-app memory too.
        var file =
            _categories.firstWhere((element) => element.title == category);
        file.entries = nEntries;
        // file.totalAmount = nTotalAmount;
        notifyListeners();
      });
    });
  }
  // method to add an expense to database

  Future<void> addProfile(Profile exp) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn
          .insert(
        pTable,
        exp.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      )
          .then((generatedId) {
        // after inserting in a database. we store it in in-app memory with new expense with generated id
        final file = Profile(
            id: generatedId,
            title: exp.title,
            // amount: exp.amount,
            latitude: exp.latitude,
            longitude: exp.longitude,
            // longitude : exp.longitude
            date: exp.date,
            category: exp.category);
        // add it to '_expenses'

        _profiles.add(file);
        // notify the listeners about the change in value of '_expenses'
        notifyListeners();
        // after we inserted the expense, we need to update the 'entries' and 'totalAmount' of the related 'category'
        var ex = findCategory(exp.category);

        updateCategory(
            // exp.category, ex.entries + 1, ex.totalAmount + exp.amount);
            exp.category,
            ex.entries + 1);
      });
    });
  }

  Future<void> deleteProfile(int expId, String category) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(pTable, where: 'id == ?', whereArgs: [expId]).then((_) {
        // remove from in-app memory too
        _profiles.removeWhere((element) => element.id == expId);
        notifyListeners();
        // we have to update the entries and totalamount too

        var ex = findCategory(category);
        // updateCategory(category, ex.entries - 1, ex.totalAmount - amount);
        updateCategory(category, ex.entries - 1);
      });
    });
  }

  Future<List<Profile>> fetchProfiles(String category) async {
    final db = await database;
    return await db.transaction((txn) async {
      return await txn.query(pTable,
          where: 'category == ?', whereArgs: [category]).then((data) {
        final converted = List<Map<String, dynamic>>.from(data);
        //
        List<Profile> nList = List.generate(
            converted.length, (index) => Profile.fromString(converted[index]));
        _profiles = nList;
        return _profiles;
      });
    });
  }

  // Future<List<Profile>> fetchprofile(String name) async {
  //   final db = await database;
  //   return await db.transaction((txn) async {
  //     return await txn
  //         .query(eTable, where: 'title == ?', whereArgs: [name]).then((data) {
  //       final converted = List<Map<String, dynamic>>.from(data);
  //       //
  //       List<Profile> nList = List.generate(
  //           converted.length, (index) => Profile.fromString(converted[index]));
  //       _expenses = nList;
  //       return _expenses;
  //     });
  //   });
  // }

  Future<List<Profile>> fetchAllProfiles() async {
    final db = await database;
    return await db.transaction((txn) async {
      return await txn.query(pTable).then((data) {
        final converted = List<Map<String, dynamic>>.from(data);
        List<Profile> nList = List.generate(
            converted.length, (index) => Profile.fromString(converted[index]));
        _profiles = nList;
        return _profiles;
      });
    });
  }

  ProfileCategory findCategory(String title) {
    return _categories.firstWhere((element) => element.title == title);
  }

  Map<String, dynamic> calculateEntriesAndAmount(String category) {
    // double total = 0.0;
    var list = _profiles.where((element) => element.category == category);
    // for (final i in list) {
    //   total += i.amount;
    // }
    // return {'entries': list.length, 'totalAmount': total};
    return {'entries': list.length};
  }

  // double calculateTotalExpenses() {
  //   return _categories.fold(
  //       0.0, (previousValue, element) => previousValue + element.totalAmount);
  // }

  // List<Map<String, dynamic>> calculateWeekExpenses() {
  //   List<Map<String, dynamic>> data = [];

  //   // we know that we need 7 entries
  //   for (int i = 0; i < 7; i++) {
  //     // 1 total for each entry
  //     // double total = 0.0;
  //     // subtract i from today to get previous dates.
  //     final weekDay = DateTime.now().subtract(Duration(days: i));

  //     // check how many transacitons happened that day
  //     for (int j = 0; j < _profiles.length; j++) {
  //       if (_profiles[j].date.year == weekDay.year &&
  //           _profiles[j].date.month == weekDay.month &&
  //           _profiles[j].date.day == weekDay.day) {
  //         // if found then add the amount to total
  //         // total += _expenses[j].amount;
  //       }
  //     }

  //     // add to a list
  //     // data.add({'day': weekDay, 'amount': total});
  //     data.add({'day': weekDay});
  //   }
  //   // return the list
  //   return data;
  // }
}
