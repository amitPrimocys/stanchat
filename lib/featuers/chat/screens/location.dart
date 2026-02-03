import 'dart:convert';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:stanchat/utils/app_size_config.dart';
import 'package:stanchat/utils/preference_key/constant/app_assets.dart';
import 'package:stanchat/utils/preference_key/constant/app_colors.dart';
import 'package:stanchat/utils/preference_key/constant/app_text_style.dart';
import 'package:stanchat/utils/preference_key/constant/app_theme_manage.dart';
import 'package:stanchat/utils/preference_key/constant/strings.dart';
import 'package:stanchat/widgets/cusotm_blur_appbar.dart';
import 'package:stanchat/widgets/global.dart';
import 'package:geocoding/geocoding.dart';

// ignore: must_be_immutable
class LocationScreen extends StatefulWidget {
  double latitude;
  double longitude;
  final String userLocation;
  LocationScreen({
    super.key,
    this.latitude = 0,
    this.longitude = 0,
    required this.userLocation,
  });

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  String placeApiKey = "AIzaSyAo178gm6y82PrD-BBC5s4UST_leL_I1Ns";
  Set<Marker> markers = {};
  String locName = '';
  String locality = '';
  TextEditingController searchController = TextEditingController();
  GoogleMapController? _controller;
  String selectedAddress = "";
  bool isHide = true;

  Future<void> setImageAsMarker(
    double latitude,
    double longitude,
    var markerID,
  ) async {
    BitmapDescriptor markerbitmap = await BitmapDescriptor.asset(
      const ImageConfiguration(),
      "assets/images/location_red.png",
    );
    markers.add(
      Marker(
        //add start location marker
        markerId: MarkerId(markerID),
        position: LatLng(latitude, longitude), //position of marker
        infoWindow: const InfoWindow(
          //popup info
          title: ' You are here ',
          snippet: '',
        ),
        icon: markerbitmap, //Icon for Marker
        draggable: true,
        onDragStart: (value) async {
          _mapresult.clear();
          // markers.clear();
          FocusScope.of(context).unfocus();
        },
        onDragEnd: (value) {
          log('$value LAtLNG Value');
          setState(() {
            _latitude = value.latitude;
            _longitude = value.longitude;
          });
          getUserLocation(_latitude, _longitude);
        },
      ),
    );
    setState(() {});
  }

  var _latitude = 0.0;
  var _longitude = 0.0;
  var uuid = const Uuid();
  final String _sessionToken = "";
  List<dynamic> _mapresult = [];

  void onChange() {
    getsuggestion(searchController.text);
  }

  Future<void> getUserLocation(double lat, double lon) async {
    List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
    Placemark place = placemarks[0];
    log("$place PLACE");
    setState(() {
      locality = place.locality!;
      locName = place.name!;
      selectedAddress =
          "${place.name}, ${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
    });
    setState(() {});
  }

  void getsuggestion(String input) async {
    String kPlaceApiKey = placeApiKey;
    String baseURL =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json";
    String request =
        '$baseURL?input=$input&key=$kPlaceApiKey&sessiontoken=$_sessionToken';

    var response = await http.get(Uri.parse(request));

    debugPrint(response.body.toString());
    if (response.statusCode == 200) {
      setState(() {
        _mapresult = jsonDecode(response.body)['predictions'];
      });
      log("Map Result $_mapresult");
    } else {
      if (!mounted) return;
      snackbarNew(context, msg: "Problem while getting Location");
    }
  }

  Future<void> getLonLat(String input) async {
    String kPlaceApiKey = placeApiKey;
    String baseURL =
        'https://maps.googleapis.com/maps/api/geocode/json?address=$input&key=$kPlaceApiKey';

    var response = await http.get(Uri.parse(baseURL));

    debugPrint(response.body.toString());
    if (response.statusCode == 200) {
      final data = await jsonDecode(response.body);
      final location = data['results'][0]['geometry']['location'];

      log("LOCATION--- $location");
      log('LAT FROM API ${location['lat']}');
      log('LAT FROM API ${location['lng']}');

      setState(() {
        _latitude = location['lat'];
        widget.latitude = _latitude;
        _longitude = location['lng'];
        widget.longitude = _longitude;
      });

      await getUserLocation(_latitude, _longitude);

      debugPrint('Latitude: $_latitude');
      debugPrint('Longitude: $_longitude');
    } else {
      debugPrint('Error getting location data: ${response.statusCode}');
    }
  }

  void onMapCreatedLight() async {
    // Load JSON depending on theme
    String style = await rootBundle.loadString(AppAssets.lightMap);
    // ignore: deprecated_member_use
    _controller?.setMapStyle(style);
  }

  void onMapCreatedNight() async {
    // Load JSON depending on theme
    String style = await rootBundle.loadString(AppAssets.darkMap);
    // ignore: deprecated_member_use
    _controller?.setMapStyle(style);
  }

  List<dynamic> _nearbyPlaces = [];

  Future<void> getNearbyPlaces(double lat, double lon) async {
    log("Near_Lat:$lat and long:$lon");
    String apiKey = placeApiKey; // put your key here
    final String url =
        "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lon&radius=1500&key=$apiKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      setState(() {
        _nearbyPlaces = data["results"];
      });
    } else {
      debugPrint("Nearby places fetch failed: ${response.statusCode}");
    }
  }

  final FocusNode searchFocusNode = FocusNode();
  @override
  void initState() {
    selectedAddress = widget.userLocation;
    setState(() {
      _longitude = widget.latitude;
      _longitude = widget.longitude;
      getUserLocation(widget.latitude, widget.longitude);
    });
    setImageAsMarker(widget.latitude, widget.longitude, widget.userLocation);
    log("LATITUDE AND LONGITUDE ${widget.latitude} : ${widget.longitude}");
    getNearbyPlaces(widget.latitude, widget.longitude);
    _controller?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(widget.latitude, widget.latitude),
          zoom: 10.0,
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
    searchFocusNode.addListener(() {
      if (!searchFocusNode.hasFocus) {
        // Keyboard closed
        setState(() {
          isHide = true;
        });
      } else {
        // Keyboard open
        setState(() {
          isHide = false;
        });
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _controller!.dispose();
    searchController.dispose();
    searchFocusNode.dispose();
    // addressController.searchAddressController.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70),
        child: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          shape: Border(
            bottom: BorderSide(color: AppThemeManage.appTheme.borderColor),
          ),
          backgroundColor: AppColors.transparent,
          systemOverlayStyle: systemUI(),
          flexibleSpace: flexibleSpace(),
          titleSpacing: 0,
          leading: Padding(
            padding: SizeConfig.getPadding(12),
            child: customeBackArrowBalck(context),
          ),
          title: Text(
            AppString.locationStrings.sendLocation,
            style: AppTypography.h220(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(widget.latitude, widget.longitude),
                        zoom: 14,
                      ),
                      markers: markers, //markers to show on map
                      zoomGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      rotateGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      indoorViewEnabled: true,
                      // onMapCreated: onMapCreated,
                      onMapCreated: (GoogleMapController mcontroller) {
                        _controller = mcontroller;
                        if (isLightModeGlobal) {
                          onMapCreatedLight();
                        } else {
                          onMapCreatedNight();
                        }
                      },
                      onCameraIdle: () async {
                        await _controller!.getVisibleRegion();
                        setState(() {});
                      },
                    ),
                    searchLocationTextField(),
                  ],
                ),
              ),
              isHide ? addressField() : searchAddressMapResult(),
            ],
          ),
          // _mapresult.isEmptys
          //     ? const SizedBox.shrink()
          //     : Column(
          //       children: [
          //         const SizedBox(height: 60),
          //         Padding(
          //           padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
          //           child: Container(
          //             width: MediaQuery.of(context).size.width,
          //             height: 110,
          //             decoration: BoxDecoration(
          //               color: Colors.white,
          //               borderRadius: BorderRadius.circular(5),
          //               border: Border.all(color: Colors.grey),
          //             ),
          //             child: ListView.builder(
          //               itemCount: _mapresult.length,
          //               itemBuilder: (context, index) {
          //                 return InkWell(
          //                   onTap: () async {
          //                     searchController.text =
          //                         await _mapresult[index]['description'];
          //                     // addressController.searchAddressController.text =
          //                     //     await _mapresult[index]['description'];
          //                     FocusScope.of(context).unfocus();
          //                     // setState(() async {

          //                     _mapresult.clear();
          //                     markers.clear();

          //                     await getLonLat(searchController.text);

          //                     await setImageAsMarker(_latitude, _longitude, "");
          //                     await getUserLocation(_latitude, _longitude);
          //                     if (_controller != null) {
          //                       _controller!.animateCamera(
          //                         CameraUpdate.newLatLng(
          //                           LatLng(_latitude, _longitude),
          //                         ),
          //                       );
          //                       setState(() {});
          //                     } else {
          //                       log("Controller is Null");
          //                     }
          //                     setState(() {});
          //                   },
          //                   child: ListTile(
          //                     title: Text(_mapresult[index]['description']),
          //                     // tileColor: Colors.grey,
          //                     horizontalTitleGap: 1.0,
          //                   ),
          //                 );
          //               },
          //             ),
          //           ),
          //         ),
          //       ],
          //     ),
        ],
      ),
    );
  }

  Widget addressField() {
    return SizedBox(
      height: SizeConfig.height(40),
      child: Padding(
        padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: SizeConfig.height(5)),
                Text(
                  AppString.locationStrings.nearbyPlaces,
                  style: AppTypography.innerText16(context),
                ),
                SizedBox(height: SizeConfig.height(2)),

                // Nearby Places List
                Expanded(
                  child:
                      _nearbyPlaces.isEmpty
                          ? Center(
                            child: Text(
                              AppString.noNearbyLocationFound,
                              style: AppTypography.innerText14(context),
                            ),
                          )
                          : ListView.builder(
                            itemCount:
                                _nearbyPlaces.length +
                                1, // +1 for current location
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                // Show current location first
                                return Padding(
                                  padding: SizeConfig.getPaddingOnly(
                                    bottom: 10,
                                  ),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _latitude = widget.latitude;
                                        _longitude = widget.longitude;
                                      });

                                      _controller?.animateCamera(
                                        CameraUpdate.newLatLng(
                                          LatLng(_latitude, _longitude),
                                        ),
                                      );

                                      markers.clear();
                                      setImageAsMarker(
                                        _latitude,
                                        _longitude,
                                        "Current Location",
                                      );

                                      selectedAddress = widget.userLocation;
                                      searchController.clear();
                                      _mapresult.clear();
                                    },
                                    child: Container(
                                      padding: SizeConfig.getPadding(10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color:
                                              AppThemeManage
                                                  .appTheme
                                                  .borderColor,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SvgPicture.asset(
                                            AppAssets
                                                .chatMsgTypeIcon
                                                .locationRed,
                                            height: 16,
                                          ),
                                          SizedBox(width: SizeConfig.width(2)),
                                          Flexible(
                                            child: Text(
                                              widget.userLocation,
                                              style:
                                                  AppTypography.innerText12Mediu(
                                                    context,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }

                              // Other nearby places
                              final place =
                                  _nearbyPlaces[index - 1]; // shift by 1
                              return Padding(
                                padding: SizeConfig.getPaddingOnly(bottom: 10),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _latitude =
                                          place["geometry"]["location"]["lat"] *
                                          1.0;
                                      _longitude =
                                          place["geometry"]["location"]["lng"] *
                                          1.0;
                                    });

                                    _controller?.animateCamera(
                                      CameraUpdate.newLatLng(
                                        LatLng(_latitude, _longitude),
                                      ),
                                    );

                                    markers.clear();
                                    setImageAsMarker(
                                      _latitude,
                                      _longitude,
                                      place["name"],
                                    );

                                    selectedAddress =
                                        "${place["name"] ?? ""} ${place["vicinity"] ?? ""}";
                                    searchController.clear();
                                    _mapresult.clear();
                                  },
                                  child: Container(
                                    padding: SizeConfig.getPadding(10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color:
                                            AppThemeManage.appTheme.borderColor,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        selectedAddress.isNotEmpty &&
                                                selectedAddress ==
                                                    "${place["name"] ?? ""} ${place["vicinity"] ?? ""}"
                                            ? SvgPicture.asset(
                                              AppAssets
                                                  .chatMsgTypeIcon
                                                  .locationRed,
                                              height: 16,
                                            )
                                            : SvgPicture.asset(
                                              AppAssets
                                                  .chatMsgTypeIcon
                                                  .locationMsg,
                                              colorFilter: ColorFilter.mode(
                                                AppThemeManage
                                                    .appTheme
                                                    .darkWhiteColor,
                                                BlendMode.srcIn,
                                              ),
                                              height: 16,
                                            ),
                                        SizedBox(width: SizeConfig.width(2)),
                                        Flexible(
                                          child: Text(
                                            "${place["name"] ?? ""} ${place["vicinity"] ?? ""}",
                                            style:
                                                AppTypography.innerText12Mediu(
                                                  context,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
            Positioned(top: -30, left: 0, right: 0, child: selectedLocation()),
          ],
        ),
      ),
    );
  }

  Widget searchAddressMapResult() {
    return SizedBox(
      height: SizeConfig.height(40),
      child: Padding(
        padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: SizeConfig.height(5)),
            Text(
              AppString.locationStrings.searchPlaces,
              style: AppTypography.innerText16(context),
            ),
            SizedBox(height: SizeConfig.height(2)),

            // Nearby Places List
            Expanded(
              child:
                  _mapresult.isEmpty
                      ? Center(
                        child: Text(
                          AppString.searchLocationNotFound,
                          style: AppTypography.innerText16(context),
                        ),
                      )
                      : ListView.builder(
                        itemCount: _mapresult.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: SizeConfig.getPaddingOnly(bottom: 10),
                            child: GestureDetector(
                              onTap: () async {
                                final selected =
                                    _mapresult[index]['description'];

                                // update text
                                searchController.text = selected;
                                FocusScope.of(context).unfocus();

                                // update selected address
                                setState(() {
                                  selectedAddress = selected;
                                });

                                await getLonLat(selected);
                                await setImageAsMarker(
                                  _latitude,
                                  _longitude,
                                  "",
                                  // place["name"],
                                );
                                await getUserLocation(_latitude, _longitude);

                                // move map
                                _controller?.animateCamera(
                                  CameraUpdate.newLatLng(
                                    LatLng(_latitude, _longitude),
                                  ),
                                );

                                // 🔑 after everything, clear results
                                setState(() {
                                  _mapresult.clear();
                                  isHide = true;
                                });
                              },
                              child: Container(
                                padding: SizeConfig.getPadding(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppThemeManage.appTheme.borderColor,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    selectedAddress.isNotEmpty
                                        ? (selectedAddress ==
                                                _mapresult[index]['description'])
                                            ? SvgPicture.asset(
                                              AppAssets
                                                  .chatMsgTypeIcon
                                                  .locationRed,
                                              height: 16,
                                            )
                                            : SvgPicture.asset(
                                              AppAssets
                                                  .chatMsgTypeIcon
                                                  .locationMsg,
                                              colorFilter: ColorFilter.mode(
                                                AppThemeManage
                                                    .appTheme
                                                    .darkWhiteColor,
                                                BlendMode.srcIn,
                                              ),
                                              height: 16,
                                            )
                                        : SvgPicture.asset(
                                          AppAssets.chatMsgTypeIcon.locationMsg,
                                          colorFilter: ColorFilter.mode(
                                            AppThemeManage
                                                .appTheme
                                                .darkWhiteColor,
                                            BlendMode.srcIn,
                                          ),
                                          height: 16,
                                        ),
                                    SizedBox(width: SizeConfig.width(2)),
                                    Flexible(
                                      child: Text(
                                        _mapresult[index]['description'],
                                        style: AppTypography.innerText12Mediu(
                                          context,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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

  Widget selectedLocation() {
    return InkWell(
      onTap: () {
        Navigator.pop(context, {
          "latitude": _latitude,
          "longitude": _longitude,
          // "address": selectedAddress,
        });
      },
      splashFactory: NoSplash.splashFactory,
      child: Container(
        height: SizeConfig.sizedBoxHeight(62),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppColors.appPriSecColor.secondaryColor.withValues(alpha: 0.9),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SvgPicture.asset(
                    AppAssets.chatMsgTypeIcon.locationMsg,
                    height: 16,
                  ),
                  SizedBox(width: SizeConfig.width(2)),
                  SizedBox(
                    width: SizeConfig.width(65),
                    child: Text(
                      selectedAddress,
                      style: AppTypography.innerText12Mediu(
                        context,
                      ).copyWith(color: AppColors.textColor.textBlackColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Icon(Icons.arrow_forward_ios_sharp, size: 15),
            ],
          ),
        ),
      ),
    );
  }

  Widget searchLocationTextField() {
    return Padding(
      padding: SizeConfig.getPaddingOnly(left: 20, right: 20, top: 10),
      child: TextFormField(
        controller: searchController,
        onEditingComplete: () {},
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onSaved: (newValue) {
          FocusScope.of(context).nextFocus();
        },
        // onTap: () {
        //   setState(() {
        //     isHide = false;
        //   });
        // },
        onChanged: (value) {
          if (value.isEmpty) {
            setState(() {
              _mapresult.clear();
            });
          } else {
            onChange(); // your API call to fetch places
          }
        },
        readOnly: false,
        focusNode: searchFocusNode,
        maxLines: 1,
        style: AppTypography.innerText12Ragu(context),
        decoration: InputDecoration(
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          fillColor: AppThemeManage.appTheme.darkGreyColor,
          filled: true,
          hintText: AppString.locationStrings.searchPlace,
          hintStyle: AppTypography.innerText12Ragu(
            context,
          ).copyWith(color: AppColors.textColor.textDarkGray),
          prefixIcon: Padding(
            padding: SizeConfig.getPadding(15),
            child: SvgPicture.asset(
              AppAssets.homeIcons.search,
              colorFilter: ColorFilter.mode(
                AppColors.textColor.textDarkGray,
                BlendMode.srcIn,
              ),
              height: SizeConfig.safeHeight(2),
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide.none,
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide.none,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide.none,
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (value) {
          return null;
        },
      ),
    );
  }
}

String darkMap = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#242f3e"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#746855"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#242f3e"
      }
    ]
  },
  {
    "featureType": "administrative.locality",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#d59563"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#d59563"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#263c3f"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#6b9a76"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#38414e"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#212a37"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#9ca5b3"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#746855"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#1f2835"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#f3d19c"
      }
    ]
  },
  {
    "featureType": "transit",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#2f3948"
      }
    ]
  },
  {
    "featureType": "transit.station",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#d59563"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#17263c"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#515c6d"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#17263c"
      }
    ]
  }
]
''';

String lightMap = '''
[
    {
        "featureType": "all",
        "elementType": "labels.text.fill",
        "stylers": [
            {
                "color": "#000000"
            }
        ]
    },
    {
        "featureType": "all",
        "elementType": "labels.text.stroke",
        "stylers": [
            {
                "color": "#ffffff"
            }
        ]
    },
    {
        "featureType": "administrative",
        "elementType": "geometry.fill",
        "stylers": [
            {
                "color": "#d6e2e6"
            }
        ]
    },
    {
        "featureType": "landscape",
        "elementType": "geometry",
        "stylers": [
            {
                "color": "#f2f2f2"
            }
        ]
    },
    {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
            {
                "color": "#b5d3e7"
            }
        ]
    }
]
''';
