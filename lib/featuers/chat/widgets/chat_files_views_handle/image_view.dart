import 'dart:io';
import 'package:flutter/material.dart';
import 'package:stanchat/utils/app_size_config.dart';
import 'package:stanchat/utils/preference_key/constant/app_colors.dart';

class ImageViewerScreen extends StatefulWidget {
  final dynamic imageSource; // Can be String (URL/path), File, or AssetImage
  final String? imageTitle;
  final List<dynamic>? imageGallery; // For multiple images
  final int initialIndex;
  final String? heroTag; // For hero animation

  const ImageViewerScreen({
    super.key,
    required this.imageSource,
    this.imageTitle,
    this.imageGallery,
    this.initialIndex = 0,
    this.heroTag,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;

  // Transform controllers
  late TransformationController _transformationController;
  late AnimationController _animationController;
  late AnimationController _heroAnimationController;
  // ignore: unused_field
  Animation<Matrix4>? _animation;

  // Gesture variables
  TapDownDetails? _doubleTapDetails;
  // ignore: unused_field
  final double _scale = 1.0;
  // ignore: unused_field
  final double _previousScale = 1.0;
  // ignore: unused_field
  final Offset _focalPoint = Offset.zero;

  // UI visibility
  bool _showUI = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heroAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Start hero animation
    _heroAnimationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    _animationController.dispose();
    _heroAnimationController.dispose();
    super.dispose();
  }

  ImageProvider _getImageProvider(dynamic source) {
    if (source is String) {
      if (source.startsWith('http://') || source.startsWith('https://')) {
        return NetworkImage(source);
      } else if (source.startsWith('assets/')) {
        return AssetImage(source);
      } else {
        return FileImage(File(source));
      }
    } else if (source is File) {
      return FileImage(source);
    } else if (source is AssetImage) {
      return source;
    }
    throw ArgumentError('Invalid image source type');
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails!.localPosition;
      // Zoom to 2x on double tap
      _transformationController.value =
          Matrix4.identity()
            // ignore: deprecated_member_use
            ..translate(-position.dx, -position.dy)
            // ignore: deprecated_member_use
            ..scale(2.0)
            // ignore: deprecated_member_use
            ..translate(position.dx, position.dy);
    }
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
  }

  String _getHeroTag(int index) {
    if (widget.heroTag != null) {
      return widget.imageGallery != null
          ? '${widget.heroTag}_$index'
          : widget.heroTag!;
    }
    return 'image_viewer_$index';
  }

  Widget _buildImage(dynamic imageSource, int index) {
    final heroTag = _getHeroTag(index);

    return GestureDetector(
      onTap: _toggleUI,
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.5,
        maxScale: 4.0,
        child: Container(
          color: Colors.black,
          child: Center(
            child: Hero(
              tag: heroTag,
              child: Image(
                image: _getImageProvider(imageSource),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.black,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 64,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.black,
                    child: Center(
                      child: CircularProgressIndicator(
                        value:
                            loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    // Animate hero back
    await _heroAnimationController.reverse();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final hasGallery =
        widget.imageGallery != null && widget.imageGallery!.isNotEmpty;

    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _onWillPop,
      child: AnimatedBuilder(
        animation: _heroAnimationController,
        builder: (context, child) {
          return Scaffold(
            backgroundColor: Colors.black.withValues(
              alpha: _heroAnimationController.value,
            ),
            body: Stack(
              children: [
                // Main image viewer
                hasGallery
                    ? PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                          // Reset zoom when changing pages
                          _transformationController.value = Matrix4.identity();
                        });
                      },
                      itemCount: widget.imageGallery!.length,
                      itemBuilder: (context, index) {
                        return _buildImage(widget.imageGallery![index], index);
                      },
                    )
                    : _buildImage(widget.imageSource, 0),

                // Top bar with close button and title
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  top: _showUI ? 0 : -100,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              onPressed: () async {
                                await _heroAnimationController.reverse();
                                if (!context.mounted) return;
                                Navigator.pop(context);
                              },
                            ),
                            if (widget.imageTitle != null)
                              Expanded(
                                child: Text(
                                  widget.imageTitle!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (hasGallery)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_currentIndex + 1} / ${widget.imageGallery!.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom indicator dots for gallery
                if (hasGallery && widget.imageGallery!.length > 1)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    bottom: _showUI ? 20 : -50,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.imageGallery!.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentIndex == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color:
                                  _currentIndex == index
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
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

// Extension to make navigation easier with Hero support
extension ImageViewerNavigation on BuildContext {
  Future<void> viewImage({
    required dynamic imageSource,
    String? imageTitle,
    List<dynamic>? imageGallery,
    int initialIndex = 0,
    String? heroTag,
  }) {
    return Navigator.push(
      this,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return ImageViewerScreen(
            imageSource: imageSource,
            imageTitle: imageTitle,
            imageGallery: imageGallery,
            initialIndex: initialIndex,
            heroTag: heroTag,
          );
        },
      ),
    );
  }
}

// In your chat bubble or image grid:
class ImageThumbnail extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  final VoidCallback? onTap;
  final bool? isSender;

  const ImageThumbnail({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.onTap,
    this.isSender,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          onTap ??
          () {
            context.viewImage(imageSource: imageUrl, heroTag: heroTag);
          },
      child: Hero(
        tag: heroTag,
        child: Container(
          width: SizeConfig.screenWidth * 0.5,
          height: SizeConfig.sizedBoxHeight(160),
          decoration: BoxDecoration(
            borderRadius:
                isSender!
                    ? BorderRadius.only(
                      topLeft: Radius.circular(7),
                      bottomLeft: Radius.circular(7),
                      topRight: Radius.circular(7),
                    )
                    : BorderRadius.only(
                      topLeft: Radius.circular(7),
                      bottomRight: Radius.circular(7),
                      topRight: Radius.circular(7),
                    ),
            color: Colors.grey[300],
          ),
          child: ClipRRect(
            borderRadius:
                isSender!
                    ? BorderRadius.only(
                      topLeft: Radius.circular(7),
                      bottomLeft: Radius.circular(7),
                      topRight: Radius.circular(7),
                    )
                    : BorderRadius.only(
                      topLeft: Radius.circular(7),
                      bottomRight: Radius.circular(7),
                      topRight: Radius.circular(7),
                    ),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    color: AppColors.appPriSecColor.primaryColor,
                    value:
                        loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(child: Icon(Icons.broken_image));
              },
            ),
          ),
        ),
      ),
    );
  }
}

// Updated handleImageTap method with Hero support
void handleImageTap(BuildContext context, String imageUrl, String heroTag) {
  context.viewImage(
    imageSource: imageUrl,
    imageTitle: 'Chat Image',
    heroTag: heroTag,
  );
}

// For multiple images in a message
void handleMultipleImagesTap(
  BuildContext context,
  List<String> imageUrls,
  int tappedIndex,
  String baseHeroTag,
) {
  context.viewImage(
    imageSource: imageUrls[tappedIndex],
    imageGallery: imageUrls,
    initialIndex: tappedIndex,
    imageTitle: 'Images (${tappedIndex + 1}/${imageUrls.length})',
    heroTag: baseHeroTag,
  );
}
