import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class PremiumMediaCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final double rating;
  final VoidCallback onTap;
  final double width;
  final double imageHeight;
  final String? badge;
  final bool fillHeight;

  const PremiumMediaCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.rating,
    required this.onTap,
    this.width = 136,
    this.imageHeight = 198,
    this.badge,
    this.fillHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    final image = _poster();
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fillHeight) Expanded(child: image) else SizedBox(height: imageHeight, width: double.infinity, child: image),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0x70FFFFFF), fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _poster() => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF151922)),
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 180),
                errorWidget: (_, _, _) => const Icon(Icons.movie_outlined, color: Colors.white24, size: 42),
              )
            else
              const Icon(Icons.movie_outlined, color: Colors.white24, size: 42),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.transparent, Color(0xB8000000)],
                  stops: [0, .64, 1],
                ),
              ),
            ),
            if (rating > 0)
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .72), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFFFC857), size: 13),
                      const SizedBox(width: 3),
                      Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            if (badge != null && badge!.isNotEmpty)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFE50914), borderRadius: BorderRadius.circular(20)),
                  child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .3)),
                ),
              ),
          ],
        ),
      );
}

class PremiumSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  const PremiumSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -.3)),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!, style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
                  ],
                ],
              ),
            ),
            if (onSeeAll != null) TextButton(onPressed: onSeeAll, child: const Text('See all')),
          ],
        ),
      );
}
