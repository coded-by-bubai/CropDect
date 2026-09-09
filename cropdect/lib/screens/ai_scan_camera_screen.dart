import 'package:flutter/material.dart';
import 'package:cropdect/theme.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api_client.dart';
import 'dashboard_screen.dart';
import 'detection_result_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

class AIScanCameraScreen extends StatefulWidget {
  const AIScanCameraScreen({Key? key}) : super(key: key);

  @override
  State<AIScanCameraScreen> createState() => _AIScanCameraScreenState();
}

class _AIScanCameraScreenState extends State<AIScanCameraScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _scanController;
  bool _isUploading = false;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;

  Offset? _focusPoint;
  bool _showFocusCircle = false;
  
  final ImagePicker _imagePicker = ImagePicker();
  String _selectedStage = 'Vegetative';
  bool _isShutterPressed = false;
  late final ImageLabeler _imageLabeler;

  String _extractErrorMessage(dynamic data) {
    if (data == null) return 'Failed to analyze image.';
    if (data is String) {
      // If it's a huge HTML error page, just return a generic message so it doesn't flood the snackbar
      return data.toLowerCase().contains('<html') ? 'Internal Server Error.' : data;
    }
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        if (detail[0] is Map) {
          return detail[0]['msg']?.toString() ?? 'Validation Error';
        }
      }
    }
    return 'An unexpected error occurred.';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _imageLabeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.25));
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _cameraController?.dispose();
      _cameraController = null;
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      if (mounted) {
        _initializeCamera();
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      var status = await Permission.camera.status;
      if (status.isDenied) {
        status = await Permission.camera.request();
      }
      
      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Camera permission is required.'),
              action: SnackBarAction(label: 'Settings', onPressed: () => openAppSettings()),
            ),
          );
        }
        return;
      }

      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        for (var camera in _cameras!) {
          bool initialized = false;
          for (var preset in [ResolutionPreset.high, ResolutionPreset.medium, ResolutionPreset.low]) {
            try {
              _cameraController = CameraController(
                camera,
                preset,
                enableAudio: false,
              );
              await _cameraController!.initialize();
              initialized = true;
              break; // Success with this preset
            } catch (e) {
              debugPrint('Failed to initialize camera ${camera.name} with preset $preset: $e');
              _cameraController = null;
            }
          }

          if (initialized && _cameraController != null) {
            if (mounted) {
              try {
                _minZoom = await _cameraController!.getMinZoomLevel();
                _maxZoom = await _cameraController!.getMaxZoomLevel();
              } catch (_) {
                _minZoom = 1.0;
                _maxZoom = 1.0;
              }
              _currentZoom = _minZoom;
              setState(() {
                _isCameraInitialized = true;
              });
            }
            break; // Success! Stop trying other cameras
          }
        }

        if (_cameraController == null && mounted) {
          setState(() {
            _isCameraInitialized = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera initialization failed for all available cameras.')),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No camera detected. Please use the Gallery.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera initialization failed: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanController.dispose();
    _cameraController?.dispose();
    _imageLabeler.close();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_isCameraInitialized) return;
    
    try {
      if (_isFlashOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
      }
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      debugPrint('Error toggling flash: $e');
    }
  }

  void _onStageSelected(String stage) {
    setState(() {
      _selectedStage = stage;
    });
  }

  Future<bool> _validateImageIsCrop(String imagePath) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return true; // ML Kit is only supported on native mobile
    }
    
    final inputImage = InputImage.fromFilePath(imagePath);
    
    try {
      final labels = await _imageLabeler.processImage(inputImage);
      bool hasCrop = false;
      bool hasReject = false;
      
      final acceptKeywords = [
        'plant', 'leaf', 'flower', 'tree', 'vegetation', 'grass', 'nature', 'petal', 'wood', 'branch', 'twig', 'stem', 'root', 'flora', 'botany',
        'crop', 'agriculture', 'farm', 'produce', 'fruit', 'vegetable', 'food', 'harvest', 'seed',
        'soil', 'dirt', 'ground', 'earth', 'land',
        'insect', 'bug', 'caterpillar', 'beetle', 'worm', 'moth', 'butterfly', 'arachnid', 'spider', 'fungus', 'mushroom',
        'organism', 'green', 'terrestrial', 'vascular', 'macro', 'close-up', 'vein', 'pathology', 'disease', 'spot'
      ];

      final rejectLabels = [
        'Cup', 'Mug', 'Bottle', 'Glass', 'Tableware', 'Drinkware', 'Plate', 'Bowl',
        'Drawing', 'Art', 'Illustration', 'Poster', 'Painting', 'Sketch',
        'Computer', 'Monitor', 'Screen', 'Keyboard', 'Mobile phone', 'Laptop', 'Television', 'Camera', 'Tablet', 'Gadget', 'Telephone',
        'Vehicle', 'Car', 'Bicycle', 'Motorcycle', 'Truck', 'Bus', 'Airplane', 'Boat',
        'Clothing', 'Shoe', 'Footwear', 'Shirt', 'Pants', 'Dress', 'Hat', 'Glasses', 'Bag', 'Backpack',
        'Dog', 'Cat', 'Bird', 'Pet',
        'Toy', 'Tool', 'Book', 'Box', 'Clock', 'Watch', 'Jewelry',
        'Person', 'Cake', 'Table', 'Document', 'Paper', 'Text', 'Letter', 'Newspaper'
      ];
      
      debugPrint('ML Kit Detected Labels: ${labels.map((e) => "${e.label} (${e.confidence})").toList()}');

      for (ImageLabel label in labels) {
        String l = label.label.toLowerCase();
        
        // Substring match for accepted keywords (e.g. "Terrestrial plant" -> matches "plant")
        for (String keyword in acceptKeywords) {
          if (l.contains(keyword)) {
            hasCrop = true;
            break;
          }
        }
        
        // Use word-boundary matching for reject labels to prevent false positives!
        // E.g., without \b, "vegetable" triggers "table", "petal" triggers "pet", "earth" triggers "art"!
        if (label.confidence > 0.40) {
          for (String rejectWord in rejectLabels) {
            final regExp = RegExp(r'\b' + RegExp.escape(rejectWord.toLowerCase()) + r'\b');
            if (regExp.hasMatch(l)) {
              hasReject = true;
              break;
            }
          }
        }
      }
      
      // It MUST contain a crop, AND it MUST NOT contain artificial objects like cups or drawings
      return hasCrop && !hasReject;
    } catch (e) {
      debugPrint('ML Kit Error: $e');
      return true; // fail open in case of camera/MLKit errors
    }
  }

  void _showInvalidPhotoDialog(VoidCallback onProceed) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 28),
              const SizedBox(width: 12),
              Text('Invalid Photo', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
          content: Text(
            'The system could not clearly detect a plant or crop. Please capture or upload a clear photo of a crop leaf or diseased area.\n\nIf this is a crop, please try capturing it from a different angle or moving closer.',
            style: GoogleFonts.inter(color: AppTheme.onSurfaceVariant, fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onProceed();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              child: const Text('Scan Anyway'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (image == null) return; // User canceled

      setState(() {
        _isUploading = true;
      });

      final bytes = await image.readAsBytes();
      String fileName = image.name;
      
      Future<Position?> locationFuture = Future(() async {
        try {
          if (!await Geolocator.isLocationServiceEnabled()) return null;
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
            Position? pos = await Geolocator.getLastKnownPosition();
            pos ??= await Geolocator.getCurrentPosition(timeLimit: const Duration(milliseconds: 800)).catchError((_) => throw Exception());
            return pos;
          }
        } catch (_) {}
        return null;
      });

      Future<bool> validationFuture = _validateImageIsCrop(image.path);

      final results = await Future.wait([locationFuture, validationFuture]);
      Position? pos = results[0] as Position?;
      bool isValid = results[1] as bool;

      double? lat = pos?.latitude;
      double? lng = pos?.longitude;

      if (!fileName.toLowerCase().endsWith('.jpg') && !fileName.toLowerCase().endsWith('.jpeg') && !fileName.toLowerCase().endsWith('.png')) {
        fileName += '.jpg';
      }

      FormData formData = FormData.fromMap({
        "file": MultipartFile.fromBytes(bytes, filename: fileName),
        "crop_id": 1, // Fallback ID for API requirements
        if (lat != null) "latitude": lat,
        if (lng != null) "longitude": lng,
        "growth_stage": _selectedStage,
      });

      if (!isValid) {
        setState(() {
          _isUploading = false;
        });
        _showInvalidPhotoDialog(() => _uploadImage(formData, image!.path, bytes));
        return;
      }

      await _uploadImage(formData, image!.path, bytes);
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_extractErrorMessage(e.response?.data))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _onShutterPressed() async {
    HapticFeedback.mediumImpact();
    if (!_isCameraInitialized || _cameraController == null) return;
    
    XFile? image;
    try {
      image = await _cameraController!.takePicture();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to capture photo: $e')));
      }
      return;
    }
    
    if (image == null) return;

    try {
      setState(() {
        _isUploading = true;
      });
      
      final bytes = await image.readAsBytes();
      
      // Run compression, location fetching, and ML validation concurrently for faster speed
      Future<Uint8List> compressFuture = Future(() async {
        if (kIsWeb) return bytes;
        try {
          final result = await FlutterImageCompress.compressWithList(
            bytes, minHeight: 800, minWidth: 800, quality: 70,
          );
          if (result == null || result.isEmpty) return bytes;
          return result;
        } catch (e) {
          debugPrint('Compression error: $e');
          return bytes;
        }
      });

      Future<Position?> locationFuture = Future(() async {
        try {
          if (!await Geolocator.isLocationServiceEnabled()) return null;
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
            Position? pos = await Geolocator.getLastKnownPosition();
            pos ??= await Geolocator.getCurrentPosition(timeLimit: const Duration(milliseconds: 800)).catchError((_) => throw Exception());
            return pos;
          }
        } catch (_) {}
        return null;
      });

      Future<bool> validationFuture = _validateImageIsCrop(image.path);

      // Await all background tasks simultaneously
      final results = await Future.wait([compressFuture, locationFuture, validationFuture]);
      
      Uint8List compressedBytes = results[0] as Uint8List;
      Position? pos = results[1] as Position?;
      bool isValid = results[2] as bool;

      double? lat = pos?.latitude;
      double? lng = pos?.longitude;
      String fileName = image.name;

      if (!fileName.toLowerCase().endsWith('.jpg') && !fileName.toLowerCase().endsWith('.jpeg') && !fileName.toLowerCase().endsWith('.png')) {
        fileName += '.jpg';
      }

      FormData formData = FormData.fromMap({
        "file": MultipartFile.fromBytes(compressedBytes, filename: fileName),
        "crop_id": 1, // Fallback ID for API requirements
        if (lat != null) "latitude": lat,
        if (lng != null) "longitude": lng,
        "growth_stage": _selectedStage,
      });

      if (!isValid) {
        setState(() {
          _isUploading = false;
        });
        _showInvalidPhotoDialog(() => _uploadImage(formData, image!.path, compressedBytes));
        return;
      }

      await _uploadImage(formData, image!.path, compressedBytes);
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_extractErrorMessage(e.response?.data))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _uploadImage(FormData formData, String imagePath, [Uint8List? imageBytes]) async {
    try {
      if (mounted) {
        setState(() {
          _isUploading = true;
        });
      }
      final response = await apiClient.post(
        '/diagnostics/upload',
        data: formData,
      );

      if (response.statusCode == 200 && mounted) {
        // Completely dispose camera to prevent hardware lockups and black screens while on result screen
        _cameraController?.dispose();
        _cameraController = null;
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
          });
        }

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetectionResultScreen(
              resultData: response.data,
              imageBytes: imageBytes,
              imageFile: (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) 
                  ? null 
                  : File(imagePath), // Use the local file instantly on mobile
            ),
          ),
        );
        
        // Safely re-initialize camera when returning to this screen
        if (mounted) {
          _initializeCamera();
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_extractErrorMessage(e.response?.data))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildCorner(Alignment alignment) {
    return AnimatedBuilder(
      animation: _scanController,
      builder: (context, child) {
        // Subtle pulse effect (scale from 1.0 to 1.1 and back)
        final scale = 1.0 + (_scanController.value * 0.1);
        return Align(
          alignment: alignment,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                border: Border(
                  top: (alignment == Alignment.topLeft || alignment == Alignment.topRight)
                      ? const BorderSide(color: AppTheme.primaryFixed, width: 5)
                      : BorderSide.none,
                  bottom: (alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight)
                      ? const BorderSide(color: AppTheme.primaryFixed, width: 5)
                      : BorderSide.none,
                  left: (alignment == Alignment.topLeft || alignment == Alignment.bottomLeft)
                      ? const BorderSide(color: AppTheme.primaryFixed, width: 5)
                      : BorderSide.none,
                  right: (alignment == Alignment.topRight || alignment == Alignment.bottomRight)
                      ? const BorderSide(color: AppTheme.primaryFixed, width: 5)
                      : BorderSide.none,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04160F), // Premium dark background
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Container(
            color: Colors.black, // Inner scanner bounds
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
        onScaleStart: (details) {
          _baseZoom = _currentZoom;
        },
        onScaleUpdate: (details) async {
          if (_cameraController == null || !_isCameraInitialized) return;
          double zoom = (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
          if (zoom != _currentZoom) {
            setState(() {
              _currentZoom = zoom;
            });
            try {
              await _cameraController!.setZoomLevel(_currentZoom);
            } catch (_) {
              // Ignore unsupported zoom on desktop
            }
          }
        },
        onTapDown: (details) async {
          if (_cameraController == null || !_isCameraInitialized) return;
          
          final size = MediaQuery.of(context).size;
          final double x = (details.globalPosition.dx / size.width).clamp(0.0, 1.0);
          final double y = (details.globalPosition.dy / size.height).clamp(0.0, 1.0);
          
          try {
            await _cameraController!.setFocusPoint(Offset(x, y));
          } catch (_) {
            // Ignore unsupported focus on desktop, but still show UI feedback
          } finally {
            if (mounted) {
              setState(() {
                _focusPoint = details.globalPosition;
                _showFocusCircle = true;
              });
              
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  setState(() {
                    _showFocusCircle = false;
                  });
                }
              });
            }
          }
        },
        child: Stack(
          children: [
            // Camera Viewfinder Background
            Positioned.fill(
              child: _isCameraInitialized && _cameraController != null
                  ? Stack(
                      children: [
                        Positioned.fill(child: CameraPreview(_cameraController!)),
                        if (_showFocusCircle && _focusPoint != null)
                          Positioned(
                            left: _focusPoint!.dx - 30,
                            top: _focusPoint!.dy - 30,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 1.5, end: 1.0),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.amberAccent, width: 2),
                                      shape: BoxShape.rectangle,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    )
                  : (_cameras != null && _cameras!.isEmpty)
                    ? const Center(
                        child: Text(
                          'No camera detected. Please use the Gallery option below.',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          ),

          // Top App Bar Area Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Close Button
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => const DashboardScreen(),
                            transitionDuration: Duration.zero,
                          ),
                        );
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: const Center(child: Icon(Icons.close, color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                    // Title Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Row(
                            children: const [
                              Icon(Icons.info_outline, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'cropdect',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Help Button
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppTheme.surface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: Row(
                              children: const [
                                Icon(Icons.tips_and_updates_rounded, color: AppTheme.primary),
                                SizedBox(width: 8),
                                Text('Scanning Tips', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('1. Hold camera 10-15 cm away from the damaged leaf or pest.'),
                                SizedBox(height: 8),
                                Text('2. Ensure bright, natural sunlight without strong shadows.'),
                                SizedBox(height: 8),
                                Text('3. Select the accurate Crop Growth Stage below before scanning.'),
                                SizedBox(height: 8),
                                Text('4. If diagnosis is uncertain, submit for Expert Agronomist Review from results screen.'),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Got It', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: const Center(child: Icon(Icons.help_outline, color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Controls Layer
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 32, bottom: 48, left: 24, right: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black,
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Gallery Button
                  GestureDetector(
                    onTap: _isUploading ? null : _pickFromGallery,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.photo_library_rounded, color: Colors.white, size: 26),
                      ),
                    ),
                  ),

                  // Shutter Button
                  GestureDetector(
                    onTapDown: (_) {
                      if (!_isUploading) setState(() => _isShutterPressed = true);
                    },
                    onTapUp: (_) {
                      if (!_isUploading) {
                        setState(() => _isShutterPressed = false);
                        _onShutterPressed();
                      }
                    },
                    onTapCancel: () => setState(() => _isShutterPressed = false),
                    child: AnimatedScale(
                      scale: _isShutterPressed ? 0.85 : 1.0,
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.easeInOut,
                      child: Container(
                        width: 80,
                        height: 80,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: AppTheme.secondaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.camera_alt, color: AppTheme.onSecondaryContainer, size: 32),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Flash Toggle
                  GestureDetector(
                    onTap: _isUploading ? null : _toggleFlash,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _isFlashOn
                            ? Colors.amber.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isFlashOn
                              ? Colors.amber
                              : Colors.white.withValues(alpha: 0.4),
                          width: 1,
                        ),
                        boxShadow: _isFlashOn
                            ? [
                                BoxShadow(
                                  color: Colors.amber.withValues(alpha: 0.5),
                                  blurRadius: 15,
                                  spreadRadius: 5,
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Icon(
                          _isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: _isFlashOn ? Colors.amber : Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Dedicated Crop Stage Selector floating above bottom controls
          Positioned(
            bottom: 140,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 45,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: {'Seedling': '🌱', 'Vegetative': '🌿', 'Flowering': '🌼', 'Harvest': '🌾'}.entries.map((entry) {
                    final stage = entry.key;
                    final emoji = entry.value;
                    final isSel = _selectedStage == stage;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selectedStage = stage),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? AppTheme.primaryFixed : Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSel ? AppTheme.primaryFixed : Colors.white.withValues(alpha: 0.3),
                            width: isSel ? 1.5 : 1.0,
                          ),
                          boxShadow: isSel ? [
                            BoxShadow(color: AppTheme.primaryFixed.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 1)
                          ] : [],
                        ),
                        child: Row(
                          children: [
                            Text(emoji, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            Text(
                              stage,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                color: isSel ? AppTheme.onPrimaryContainer : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Viewfinder UI
          Positioned(
            top: 80, // Leave room for top bar
            bottom: 200, // Leave room for crop stage & shutter
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Scan Area Frame
                    Flexible(
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: Stack(
                          clipBehavior: Clip.none, // Required so the shadow overlay can spill out and cover the whole screen
                          children: [
                            // The true hole-punch dark overlay mask and glow
                            CustomPaint(
                              painter: ScannerOverlayPainter(
                                overlayColor: Colors.black.withValues(alpha: 0.65),
                                glowColor: AppTheme.primaryFixed.withValues(alpha: 0.4),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppTheme.primaryFixed, width: 1.5),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                            ),
                          // Corner Accents
                          _buildCorner(Alignment.topLeft),
                          _buildCorner(Alignment.topRight),
                          _buildCorner(Alignment.bottomLeft),
                          _buildCorner(Alignment.bottomRight),

                          // Premium Scanning Laser Animation (Optimized to fix BLASTBufferQueue max frames error)
                          AnimatedBuilder(
                            animation: _scanController,
                            child: RepaintBoundary( // Cache the laser drawing into a texture
                              child: Container(
                                height: 120,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.greenAccent.withValues(alpha: 0.15),
                                      Colors.greenAccent.withValues(alpha: 0.8),
                                      Colors.greenAccent.withValues(alpha: 0.15),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.45, 0.5, 0.55, 1.0],
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    height: 2,
                                    width: double.infinity,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            builder: (context, child) {
                              final scanValue = _scanController.value;
                              final alignmentY = -1.0 + (scanValue * 2);
                              
                              return Align(
                                alignment: Alignment(0, alignmentY),
                                child: child,
                              );
                            },
                          ),

                          // Dynamic Zoom Indicator and Slider
                          if (_maxZoom > _minZoom)
                            Positioned(
                              right: -10, // Push slightly off-screen to save space
                              top: 0,
                              bottom: 0,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      '${_currentZoom.toStringAsFixed(1)}x',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 180,
                                    child: RotatedBox(
                                      quarterTurns: 3,
                                      child: SliderTheme(
                                        data: SliderThemeData(
                                          trackHeight: 2,
                                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                          activeTrackColor: Colors.white,
                                          inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                                          thumbColor: AppTheme.primaryFixed,
                                        ),
                                        child: Slider(
                                          value: _currentZoom,
                                          min: _minZoom,
                                          max: _maxZoom,
                                          onChanged: (value) {
                                            setState(() {
                                              _currentZoom = value;
                                            });
                                            _cameraController?.setZoomLevel(value);
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    ),
                    const SizedBox(height: 32),
                    const SizedBox(height: 24),
                    // Animated Pulsating Instruction Pill
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.0),
                      duration: const Duration(seconds: 1),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Opacity(
                            opacity: value,
                            child: child,
                          ),
                        );
                      },
                      onEnd: () {
                        // Loop handled implicitly if we use AnimationController, but TweenBuilder just runs once.
                        // For a simple pulse, we can wrap in an infinite animation or keep it simple.
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryFixed.withValues(alpha: 0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.center_focus_strong, color: AppTheme.primaryFixed, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Center leaf in frame',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading Overlay
          if (_isUploading)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.75),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryFixed.withValues(alpha: 0.5),
                                    blurRadius: 50,
                                    spreadRadius: 20,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryFixed.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.primaryFixed.withValues(alpha: 0.3), width: 2),
                              ),
                              child: const CircularProgressIndicator(
                                color: AppTheme.primaryFixed,
                                strokeWidth: 4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'Analyzing Crop...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'AI is checking for diseases & pests',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
      ),
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final Color overlayColor;
  final Color glowColor;
  final double borderRadius;

  ScannerOverlayPainter({
    required this.overlayColor,
    required this.glowColor,
    this.borderRadius = 24,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw the dark overlay outside the frame (hole punch)
    final overlayPaint = Paint()..color = overlayColor;
    final path = Path()
      ..addRect(Rect.fromLTRB(-4000, -4000, size.width + 4000, size.height + 4000))
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(borderRadius)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlayPaint);
    
    // 2. Draw the outer glow (only outside)
    final glowPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 12);
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(borderRadius)),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) {
    return oldDelegate.overlayColor != overlayColor ||
           oldDelegate.glowColor != glowColor ||
           oldDelegate.borderRadius != borderRadius;
  }
}
