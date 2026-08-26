import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'official_ads_service.dart';

/// An anchored adaptive banner that collapses completely on load failure.
class OfficialBannerSlot extends StatefulWidget {
  const OfficialBannerSlot({super.key, required this.ads});

  final OfficialAdsService ads;

  @override
  State<OfficialBannerSlot> createState() => _OfficialBannerSlotState();
}

class _OfficialBannerSlotState extends State<OfficialBannerSlot> {
  BannerAd? _banner;
  AdSize? _size;
  int? _requestedWidth;
  bool _failed = false;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    widget.ads.canRequestAds.addListener(_consentChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadFor(MediaQuery.sizeOf(context).width.floor());
  }

  void _consentChanged() {
    if (!widget.ads.canRequestAds.value) {
      _disposeBanner();
      if (mounted) setState(() {});
      return;
    }
    if (mounted) _loadFor(MediaQuery.sizeOf(context).width.floor());
  }

  void _loadFor(int width) {
    if (!widget.ads.canRequestAds.value ||
        width <= 0 ||
        (_requestedWidth == width && (_banner != null || _failed))) {
      return;
    }
    _requestedWidth = width;
    _failed = false;
    _disposeBanner();

    const size = AdSize.banner;
    if (!mounted || _requestedWidth != width || width < size.width) return;
    setState(() => _size = size);

    late final BannerAd banner;
    banner = BannerAd(
      adUnitId: widget.ads.bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _retryTimer?.cancel();
          if (!mounted ||
              !widget.ads.canRequestAds.value ||
              _requestedWidth != width) {
            banner.dispose();
            return;
          }
          setState(() => _banner = banner);
        },
        onAdFailedToLoad: (_, error) {
          debugPrint('Banner failed to load: $error');
          banner.dispose();
          if (mounted && _requestedWidth == width) {
            setState(() {
              _failed = true;
              _size = null;
            });
            _retryTimer?.cancel();
            _retryTimer = Timer(const Duration(seconds: 30), () {
              if (!mounted || !widget.ads.canRequestAds.value) return;
              _requestedWidth = null;
              _loadFor(MediaQuery.sizeOf(context).width.floor());
            });
          }
        },
      ),
    );
    unawaited(banner.load());
  }

  void _disposeBanner() {
    _banner?.dispose();
    _banner = null;
    _size = null;
  }

  @override
  void dispose() {
    widget.ads.canRequestAds.removeListener(_consentChanged);
    _retryTimer?.cancel();
    _disposeBanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.ads.canRequestAds.value || _failed) {
      return const SizedBox.shrink();
    }
    final size = _size;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        key: const Key('official-ad-banner'),
        width: double.infinity,
        height: (size?.height ?? 50).toDouble(),
        child: _banner == null
            ? null
            : Center(
                child: SizedBox(
                  width: size!.width.toDouble(),
                  height: size.height.toDouble(),
                  child: AdWidget(ad: _banner!),
                ),
              ),
      ),
    );
  }
}
