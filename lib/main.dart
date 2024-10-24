import 'dart:convert';
import 'dart:core';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

/// Code Structure
/// Ciy = data model
/// MyAppState = Centrailzed Data Storage (We use this class to share data between page)
/// MyApp  = main app
///  -> My Home Page = Home page, with navigation bar on the left and body on the right, show page index 0 by default
///     (0) -> City List Page = List of cities, retrieve from server. You can open individual city (will show in City Detail Page) or favorite (show in Favorites Page) 
///     (1) -> Favorites Page = List of favorite cities. You can open individual city (will show in City Detail Page) or unfavorite city (YOUR WORK!!!)
///  -> City Detail Page = Page to show info from individual city, retrieve from server.

/// Main application, your code start here
void main() {
  runApp(MyApp());
}

/// Data model for data retrieved form server
class City {
  // The type depend on the returned data, check the Swagger for type
  final int id;
  final String name;
  final double temperature;
  final String condition;
  final double windSpeed;
  final String windDirection;
  final double humidity;
  final double precipitation;
  final double uv;

  const City(
    {
      required this.id,
      required this.name,
      required this.temperature,
      required this.condition,
      required this.windSpeed,
      required this.windDirection,
      required this.humidity,
      required this.precipitation,
      required this.uv,

    }
  );

  // To make sure that we can handle both int and double case, convert every number to double
  factory City.fromJson(Map<String, dynamic> json) {
    return City(
        id : json['id'],
        name : json['name'],
        temperature: json['temperature'].toDouble(),
        condition: json['condition'],
        windSpeed: json['windSpeed'].toDouble(),
        windDirection: json['windDirection'],
        humidity: json['humidity'].toDouble(),
        precipitation: json['precipitation'].toDouble(),
        uv: json['uv'].toDouble()
    );
  }
}

/// This class maintain data for the pages
/// favorites = list of favorite city
/// selectedCityId = Id of city that will be shown in City Detail Page
/// baseUrl = base URL of the server
/// 
class MyAppState extends ChangeNotifier {

  var favorites = <City>[];
  var selectedCityId  = 0;
  final baseUrl = 'http://localhost:5282/api/cities/';

  void toggleFavoriteCity(City city)
  {
    var contain = favorites.where((aCity) => aCity.name == city.name);
    if (contain.isEmpty) {
      favorites.add(city);
    } else {
      favorites.remove(city);
    }
  }

  void setSelectedCity(int id)
  {
    selectedCityId = id;
  }
}

/// Main application, set color theme and load the home page
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Weather Better',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

/// Homepage, set the layout of the application
/// On the left, navigation bar with two items , (0) City List and (1) Favorites
/// On the right, content area, show (0) City List by default
class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;
  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = CityListPage();
      case 1:
        page = FavoritesPage();
      default:
        throw UnimplementedError('No widget for $selectedIndex');
    }
    // Basic scaffold, same structure as in tutorial
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: NavigationRail(
              extended: false,
              destinations: [
                NavigationRailDestination(
                  icon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.favorite),
                  label: Text('Favorites'),
                ),
              ],
              selectedIndex: selectedIndex,
              onDestinationSelected: (value) {
                setState(() {
                  selectedIndex = value;
                });
              },
            ),
          ),
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: page,
            ),
          ),
        ],
      ),
    );
  }
}

/// Page that retrieve city list from server, then show in the page with two buttons, before and after.
class CityListPage extends StatefulWidget {

  @override
  State<CityListPage> createState() => _CityListPageState();
}

class _CityListPageState extends State<CityListPage> {

  /// Retrieve city list from server, this is future (basically async operation)
  late Future<List<City>> cityList = fetchCityList();

  /// This method retrieve list of city (in JSON), then put into List<City>
  Future<List<City>> fetchCityList() async {
    var appState = context.watch<MyAppState>();
    final response = await http.get(Uri.parse(appState.baseUrl));

    if (response.statusCode == 200) {
      return (json.decode(response.body) as List)
          .map((item) => City.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load city list');
    }
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    return FutureBuilder<List<City>> (
      future: cityList,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
        } else if (snapshot.hasData) {
          final cities = snapshot.data!;
          // List of city, each item consists of [favorite][name][open]
          // favorite => add to favorite
          // name => city name
          // open => open city in City Detail Page
          return ListView(
          children: [
            for (City city in cities) 
              ListTile(
                contentPadding: EdgeInsets.zero,
                // [favorite]
                leading: IconButton(
                  icon: Icon(Icons.favorite),
                  onPressed: ()  {
                    // Add to favorite
                    appState.toggleFavoriteCity(city);
                  }
                ),
                // [name]
                title: Text(city.name),
                // [open]
                trailing: IconButton(
                  icon: Icon(Icons.open_in_new),
                  onPressed: () { 
                    // Set selected index in appState
                    appState.setSelectedCity(city.id);
                    // Open the City detail page
                    Navigator.push(context, MaterialPageRoute(builder: (context) => CityDetailPage()));
                  }
                ),
              ),
          ],
          );
        } else {
          return const Text("No data available");
        }
      },
   );
  }
}

/// Page that show list of favorite city, it use the same layout as City List Page, except that [favorite] button
/// suppose to de-favorite
class FavoritesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    if (appState.favorites.isEmpty) {
      return Center(
        child: Text('No favorites yet.'),
      );
    }
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('You have '
              '${appState.favorites.length} favorites:'),
        ),
        for (var city in appState.favorites)
          ListTile(
            leading: IconButton(
              icon: Icon(Icons.favorite),
              onPressed: () {
                appState.toggleFavoriteCity(city);
              },
            ),
            title: Text(city.name),
            trailing: IconButton(
                icon: Icon(Icons.open_in_new),
                onPressed: () {
                  appState.setSelectedCity(city.id);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => CityDetailPage()));
                } //openCityDetailPage(city.id),
                ),
          ),
      ],
    );
  }
}

/// Page to show individual city's detail
class CityDetailPage extends StatefulWidget {

  const CityDetailPage({super.key});
  @override
  State<CityDetailPage> createState() => _CityDetailPageState();
}

class _CityDetailPageState extends State<CityDetailPage> {
  // Load individual city data from server
  late Future<City> aCity = fetchCity();

  Future<City> fetchCity() async {
    var appState = context.watch<MyAppState>();

    // Retreive from REST api server
    final response = await http.get(Uri.parse(appState.baseUrl + appState.selectedCityId.toString()));

    // Converte returned JSON to City object
    if (response.statusCode == 200) {
      return City.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw Exception('Failed to load city');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<City> (
      future: aCity,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasData) {
          final city= snapshot.data!;
          return Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              title: Text('Weather of ${city.name}'),
            ),
            body: ListView(
              // Show individual data in BigCard with name and value
              children: [
                BigCard(property : 'Temperature', value: '${city.temperature} °C'),
                BigCard(property: 'Condition', value: city.condition.toString()),
                BigCard(property: 'Wind', value: '${city.windSpeed} km/Hr ${city.windDirection}'),
                BigCard(property: 'Humidty', value: '${city.humidity} %'),
                BigCard(property: 'Percipitation', value: '${city.precipitation} mm'),
                BigCard(property: 'UV', value: city.uv.toString())
              ]
            ),
          );
        } else {
          return const Text("No data available");
        }
      }
    );
  }
}

class BigCard extends StatelessWidget {
  const BigCard({
    super.key,
    required this.property,
    required this.value
  });
  final String property;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.displaySmall!
        .copyWith(color: theme.colorScheme.onPrimary);
    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          '$property: $value',
          style: style,
          semanticsLabel: "$property $value",
        ),
      ),
    );
  }
}
