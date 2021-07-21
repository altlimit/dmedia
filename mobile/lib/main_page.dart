import 'package:flutter/material.dart';
import 'package:dmedia/model.dart';
import 'package:dmedia/account_page.dart';
import 'package:dmedia/store.dart';
import 'package:dmedia/preference.dart';
import 'package:dmedia/background.dart';
import 'dart:convert';

class MainPage extends StatefulWidget {
  @override
  _MainPage createState() => _MainPage();
}

class TabElement {
  String label = "";
  IconData icon;
  Widget widget;

  TabElement(this.label, this.icon, this.widget);
}

class _MainPage extends State<MainPage> with Store {
  final _db = DBProvider();
  int _tabIndex = 0;
  BuildContext? _buildContext;
  final List<TabElement> _tabs = [
    TabElement(
        "Gallery",
        Icons.photo,
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return Container(
                color: index.isOdd ? Colors.white : Colors.black12,
                height: 100.0,
                child: Center(
                  child: Text('$index', textScaleFactor: 5),
                ),
              );
            },
            childCount: 20,
          ),
        )),
    TabElement(
        "Albums",
        Icons.photo_album,
        SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200.0,
            mainAxisSpacing: 10.0,
            crossAxisSpacing: 10.0,
            childAspectRatio: 4.0,
          ),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return Container(
                alignment: Alignment.center,
                color: Colors.teal[100 * (index % 9)],
                child: Text('grid item $index'),
              );
            },
            childCount: 20,
          ),
        )),
    TabElement(
        "Search",
        Icons.search,
        SliverFixedExtentList(
          itemExtent: 50.0,
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return Container(
                alignment: Alignment.center,
                color: Colors.lightBlue[100 * (index % 9)],
                child: Text('list item $index'),
              );
            },
          ),
        ))
  ];

  @override
  void initState() {
    super.initState();

    Bg.on(taskSync, 'message', (d) {
      if (_buildContext != null) {
        var data = d as Map<String, String>;
        if (data.containsKey('message'))
          Util.showMessage(context, data['message']!);
      }
    });
  }

  @override
  void dispose() {
    Bg.off(taskSync, name: 'message');
    super.dispose();
  }

  void onTabTapped(int index) {
    setState(() {
      _tabIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    _buildContext = context;
    return Scaffold(
        body: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              actions: [
                IconButton(
                  icon: Icon(Icons.account_circle),
                  onPressed: () async {
                    Util.showMessage(context, 'Hello World');
                    // Util.runSingleInstance('test', () {
                    //   print('Called');
                    // });
                    // Preference.clear();
                    // await Bg.manager()
                    //   ..registerOneOffTask('1000', taskSync,
                    //       inputData: {'test': 1235},
                    //       initialDelay: Duration(seconds: 2));
                    var accounts = Util.getAccounts();
                    if (accounts.length == 0) {
                      Navigator.pushNamed(context, '/account');
                      return;
                    }
                    List<int> accountIds = [];
                    List<String> accountOptions = [];
                    for (var key in accounts.keys) {
                      accountIds.add(key);
                      accountOptions.add(accounts[key].toString());
                    }
                    accountOptions.add("Add New");
                    int? selectedId;
                    Util.dialogList(context, "Select Account", accountOptions,
                        (index, selected) {
                      if (selected != "Add New") {
                        selectedId = accountIds[index];
                      }
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  AccountPage(internalId: selectedId)));
                    });
                  },
                ),
                IconButton(
                  icon: Icon(Icons.settings),
                  onPressed: () {
                    Navigator.pushNamed(context, '/settings');
                  },
                )
              ],
              leading: Icon(_tabs[_tabIndex].icon),
              floating: true,
              flexibleSpace:
                  FlexibleSpaceBar(title: Text(_tabs[_tabIndex].label)),
            ),
            _tabs[_tabIndex].widget
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
            onTap: onTabTapped,
            currentIndex: _tabIndex,
            items: _tabs
                .map((tab) => BottomNavigationBarItem(
                      icon: Icon(tab.icon),
                      label: tab.label,
                    ))
                .toList()));
  }
}
