// lib/partner_profile_page/partner_profile_page_widget.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/supabase_auth/auth_util.dart';
import '../../backend/supabase/supabase.dart';
import '../../components/partner_card_widget.dart';
import '../../flutter_flow/flutter_flow_theme.dart';
import '../../flutter_flow/flutter_flow_util.dart';
import '../../flutter_flow/flutter_flow_widgets.dart';
import '../../index.dart';
import 'partner_profile_page_model.dart';

export 'partner_profile_page_model.dart';

class PartnerProfilePageWidget extends StatefulWidget {
  const PartnerProfilePageWidget({
    super.key,
    required this.partnerId,
  });

  final String? partnerId;

  static String routeName = 'PartnerProfilePage';
  static String routePath = '/partnerProfilePage';

  @override
  State<PartnerProfilePageWidget> createState() =>
      _PartnerProfilePageWidgetState();
}

class _PartnerProfilePageWidgetState extends State<PartnerProfilePageWidget> {
  late PartnerProfilePageModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  MedicalPartnersRow? _partnerData;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PartnerProfilePageModel());
    _loadPartnerData();
  }

  Future<void> _loadPartnerData() async {
    if (widget.partnerId == null) return;
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await MedicalPartnersTable().queryRows(
        queryFn: (q) => q.eq('id', widget.partnerId!).limit(1),
      );
      if (mounted && data.isNotEmpty) {
        setState(() {
          _partnerData = data.first;
        });
      }
    } catch (e) {
      debugPrint("Error loading partner data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.partnerId == null || widget.partnerId!.isEmpty) {
      return Scaffold(
        appBar:
            AppBar(title: Text(FFLocalizations.of(context).getText('ptrerr'))),
        body: Center(
            child: Text(FFLocalizations.of(context).getText('ptridmissing'))),
      );
    }

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      body: _isLoading || _partnerData == null
          ? Center(
              child: CircularProgressIndicator(
                  color: FlutterFlowTheme.of(context).primary))
          : _ProfileBody(
              partnerData: _partnerData!,
              onProfileUpdated: _loadPartnerData,
            ),
    );
  }
}

class _ProfileBody extends StatefulWidget {
  final MedicalPartnersRow partnerData;
  final Future<void> Function() onProfileUpdated;

  const _ProfileBody(
      {required this.partnerData, required this.onProfileUpdated});

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  final _formKey = GlobalKey<FormState>();

  bool _isEditMode = false;
  bool _isSaving = false;
  bool _isUploading = false;
  late TextEditingController _fullNameController;
  late TextEditingController _bioController;
  late TextEditingController _locationUrlController;
  late String _specialty;

  @override
  void initState() {
    super.initState();
    _fullNameController =
        TextEditingController(text: widget.partnerData.fullName ?? '');
    _bioController = TextEditingController(text: widget.partnerData.bio ?? '');
    _locationUrlController =
        TextEditingController(text: widget.partnerData.locationUrl ?? '');
    _specialty = widget.partnerData.specialty ?? 'No Specialty';
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _bioController.dispose();
    _locationUrlController.dispose();
    super.dispose();
  }

  Future<void> _uploadProfilePicture() async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 600,
    );

    if (imageFile == null) {
      return;
    }

    setState(() => _isUploading = true);

    try {
      final file = File(imageFile.path);
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${currentUserUid}.$fileExt';
      final filePath = '$currentUserUid/$fileName';

      await Supabase.instance.client.storage.from('avatars').upload(
            filePath,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final imageUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(filePath);

      final cacheBusterUrl =
          '$imageUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await Supabase.instance.client.from('medical_partners').update({
        'photo_url': cacheBusterUrl,
      }).eq('id', widget.partnerData.id);

      await widget.onProfileUpdated();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile picture updated!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error uploading image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _saveProfileChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client.from('medical_partners').update({
        'full_name': _fullNameController.text,
        'bio': _bioController.text,
        'location_url': _locationUrlController.text,
      }).eq('id', widget.partnerData.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(FFLocalizations.of(context).getText('prof saved')),
          backgroundColor: Colors.green,
        ));
        await widget.onProfileUpdated();
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${FFLocalizations.of(context).getText('proferr')} ${e.message}'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${FFLocalizations.of(context).getText('proferr')} An unknown error occurred.'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isEditMode = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  _buildDetailsAndRatingCard(context),
                  const SizedBox(height: 16),
                  if (_bioController.text.isNotEmpty || _isEditMode) ...[
                    _buildAboutCard(context),
                    const SizedBox(height: 16),
                  ],
                  if (_locationUrlController.text.isNotEmpty ||
                      _isEditMode) ...[
                    _buildLocationCard(context),
                    const SizedBox(height: 16),
                  ],
                  _buildActionButtons(context),
                  const SizedBox(height: 16),
                  _buildReviewsSection(context),
                  if (widget.partnerData.category == 'Clinics')
                    _ClinicDoctorsList(clinicId: widget.partnerData.id),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isClinic = widget.partnerData.category == 'Clinics';
    final photoUrl = widget.partnerData.photoUrl;
    final bool isPhotoValid = photoUrl != null && photoUrl.isNotEmpty;
    final isOwnProfile = currentUserUid == widget.partnerData.id;

    return SliverAppBar(
      pinned: true,
      expandedHeight: 220.0,
      backgroundColor: theme.primary,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        if (isOwnProfile)
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ))
                : Icon(_isEditMode ? Icons.done_rounded : Icons.edit_rounded,
                    color: Colors.white, size: 28),
            onPressed: _isSaving
                ? null
                : () {
                    if (_isEditMode) {
                      _saveProfileChanges();
                    } else {
                      setState(() => _isEditMode = true);
                    }
                  },
            tooltip: _isEditMode
                ? FFLocalizations.of(context).getText('savechgs')
                : FFLocalizations.of(context).getText('editprof'),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 48),
        title: _isEditMode
            ? TextFormField(
                controller: _fullNameController,
                textAlign: TextAlign.center,
                style: theme.headlineSmall.copyWith(color: Colors.white),
                decoration: InputDecoration.collapsed(
                    hintText: FFLocalizations.of(context).getText('fullname'),
                    hintStyle: TextStyle(color: Colors.white54)),
              )
            : Text(
                _fullNameController.text,
                style: theme.headlineSmall.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.primary, theme.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            if (isPhotoValid)
              Image.network(
                photoUrl,
                fit: BoxFit.cover,
                color: Colors.black.withAlpha(77),
                colorBlendMode: BlendMode.darken,
              ),
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withAlpha(204), width: 3),
                      image: isPhotoValid
                          ? DecorationImage(
                              image: NetworkImage(photoUrl), fit: BoxFit.cover)
                          : null,
                    ),
                    child: !isPhotoValid
                        ? Icon(isClinic ? Icons.local_hospital : Icons.person,
                            size: 50, color: Colors.white)
                        : null,
                  ),
                  if (_isEditMode && isOwnProfile)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: _isUploading
                          ? const Padding(
                              padding: EdgeInsets.all(6.0),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Colors.white, size: 16),
                              onPressed:
                                  _isUploading ? null : _uploadProfilePicture,
                              padding: EdgeInsets.zero,
                            ),
                    )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsAndRatingCard(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return _InfoCard(
      child: Column(
        children: [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.medical_services_outlined,
                color: theme.secondaryText, size: 20),
            title: Text(
              _specialty,
              style: theme.bodyLarge,
            ),
          ),
          if (widget.partnerData.parentClinicId != null)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.apartment_outlined,
                  color: theme.secondaryText, size: 20),
              title: _ClinicAffiliation(
                clinicId: widget.partnerData.parentClinicId!,
              ),
            ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RatingBarIndicator(
                rating: widget.partnerData.averageRating?.toDouble() ?? 0.0,
                itemBuilder: (context, index) =>
                    Icon(Icons.star, color: theme.warning),
                itemCount: 5,
                itemSize: 22.0,
              ),
              const SizedBox(width: 8),
              Text(
                '(${widget.partnerData.reviewCount ?? 0} ${FFLocalizations.of(context).getText('reviews')})',
                style: theme.bodyMedium.copyWith(color: theme.secondaryText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return _InfoCard(
      title: FFLocalizations.of(context).getText('aboutptr'),
      icon: Icons.info_outline_rounded,
      child: _isEditMode
          ? TextFormField(
              controller: _bioController,
              maxLines: 5,
              style: theme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Your Bio / Description...',
                hintStyle: theme.labelMedium,
                filled: true,
                fillColor: theme.primaryBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: theme.alternate,
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: theme.alternate,
                    width: 1,
                  ),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            )
          : Text(_bioController.text, style: theme.bodyMedium),
    );
  }

  Widget _buildLocationCard(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return _InfoCard(
      title: 'Location',
      icon: Icons.location_on_outlined,
      child: _isEditMode
          ? TextFormField(
              controller: _locationUrlController,
              style: theme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'e.g. Google Maps link',
                hintStyle: theme.labelMedium,
                filled: true,
                fillColor: theme.primaryBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: theme.alternate,
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: theme.alternate,
                    width: 1,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            )
          : InkWell(
              onTap: () async {
                final urlString = _locationUrlController.text;
                if (await canLaunchUrl(Uri.parse(urlString))) {
                  await launchUrl(Uri.parse(urlString));
                }
              },
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      FFLocalizations.of(context).getText('viewloc'),
                      style: theme.bodyLarge.copyWith(
                          color: theme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Icon(Icons.launch, color: theme.primary, size: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isOwnProfile = currentUserUid == widget.partnerData.id;
    final isCharity = widget.partnerData.category == 'Charities';

    if (isOwnProfile || widget.partnerData.category == 'Clinics') {
      return const SizedBox.shrink();
    }

    if (isCharity) {
      return Text(
        FFLocalizations.of(context).getText('charity_no_booking'),
        textAlign: TextAlign.center,
        style: theme.bodyMedium.copyWith(color: theme.secondaryText),
      );
    }

    final bool isActive = widget.partnerData.isActive ?? false;

    return Column(
      children: [
        FFButtonWidget(
          onPressed: isActive
              ? () {
                  context.pushNamed(
                    BookingPageWidget.routeName,
                    queryParameters:
                        {'partnerId': widget.partnerData.id}.withoutNulls,
                  );
                }
              : null,
          text: FFLocalizations.of(context).getText('bookappt'),
          icon: const Icon(Icons.calendar_month_rounded),
          options: FFButtonOptions(
            width: double.infinity,
            height: 50.0,
            color: theme.primary,
            textStyle: theme.titleSmall.copyWith(color: Colors.white),
            elevation: 2.0,
            borderRadius: BorderRadius.circular(12.0),
            disabledColor: theme.alternate,
            disabledTextColor: theme.secondaryText,
          ),
        ),
        if (!isActive)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Text(
              FFLocalizations.of(context).getText('partner_inactive'),
              textAlign: TextAlign.center,
              style: theme.bodyMedium.copyWith(color: theme.secondaryText),
            ),
          ),
      ],
    );
  }

  Widget _buildReviewsSection(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(FFLocalizations.of(context).getText('ptrreviews'),
              style: theme.headlineSmall),
        ),
        _ReviewsList(partnerId: widget.partnerData.id),
      ],
    );
  }

  Widget _ClinicDoctorsList({required String clinicId}) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 48),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(FFLocalizations.of(context).getText('ourdocs'),
              style: theme.headlineSmall),
        ),
        FutureBuilder<List<MedicalPartnersRow>>(
          future: MedicalPartnersTable().queryRows(
            queryFn: (q) => q.eq('parent_clinic_id', clinicId),
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                  child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(FFLocalizations.of(context).getText('nodocs')),
              ));
            }
            final doctors = snapshot.data!;
            return ListView.builder(
              padding: EdgeInsets.zero,
              primary: false,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: doctors.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: PartnerCardWidget(
                    partner: doctors[index],
                    showBookingButton: true,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({this.title, this.icon, required this.child});

  final String? title;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Card(
      elevation: 2,
      shadowColor: theme.primaryBackground,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: theme.secondaryText, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(title!, style: theme.titleMedium),
                ],
              ),
              const Divider(height: 24),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _ReviewsList extends StatelessWidget {
  const _ReviewsList({required this.partnerId});
  final String partnerId;

  Future<List<Map<String, dynamic>>> _getReviews() {
    return Supabase.instance.client.rpc('get_reviews_with_user_names', params: {
      'partner_id_arg': partnerId
    }).then((data) => List<Map<String, dynamic>>.from(data as List));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getReviews(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
              child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child:
                      Text(FFLocalizations.of(context).getText('noreviews'))));
        }
        final reviewsList = snapshot.data!;
        return ListView.builder(
          padding: EdgeInsets.zero,
          primary: false,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reviewsList.length,
          itemBuilder: (context, index) {
            final review = reviewsList[index];
            return _ReviewCard(reviewData: review);
          },
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.reviewData});
  final Map<String, dynamic> reviewData;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    final String firstName = reviewData['first_name'] ?? 'A Patient';
    final String gender = reviewData['gender'] as String? ?? '';
    final double rating = (reviewData['rating'] as num?)?.toDouble() ?? 0.0;
    final String comment = reviewData['review_text'] ?? '';
    final DateTime createdAt = DateTime.parse(reviewData['created_at']);

    IconData genderIcon = gender == 'Male'
        ? Icons.male
        : (gender == 'Female' ? Icons.female : Icons.person);

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.alternate, width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.accent1.withAlpha(25),
                child: Icon(genderIcon, color: theme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(firstName,
                        style: theme.bodyLarge
                            .copyWith(fontWeight: FontWeight.bold)),
                    Text(DateFormat.yMMMMd().format(createdAt),
                        style: theme.bodySmall
                            .copyWith(color: theme.secondaryText)),
                  ],
                ),
              ),
              RatingBarIndicator(
                rating: rating,
                itemBuilder: (context, index) =>
                    Icon(Icons.star, color: theme.warning),
                itemCount: 5,
                itemSize: 16.0,
              ),
            ],
          ),
          if (comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12.0, left: 52, right: 8),
              child: Text(comment, style: theme.bodyMedium),
            ),
        ],
      ),
    );
  }
}

class _ClinicAffiliation extends StatelessWidget {
  const _ClinicAffiliation({required this.clinicId});
  final String clinicId;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return FutureBuilder<List<MedicalPartnersRow>>(
      future: MedicalPartnersTable().queryRows(
        queryFn: (q) => q.eq('id', clinicId).select('full_name').limit(1),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final clinicName = snapshot.data!.first.fullName ?? 'a clinic';
        return GestureDetector(
          onTap: () => context.pushNamed(
            'PartnerProfilePage',
            queryParameters: {'partnerId': clinicId}.withoutNulls,
          ),
          child: Text(
            'Part of $clinicName',
            textAlign: TextAlign.center,
            style: theme.bodyMedium.copyWith(
              color: theme.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        );
      },
    );
  }
}
