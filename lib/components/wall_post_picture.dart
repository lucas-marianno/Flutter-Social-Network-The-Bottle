import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class PostPicture extends StatelessWidget {
  const PostPicture({
    super.key,
    required this.postImageUrl,
    required this.onTap,
  });
  final String? postImageUrl;
  final void Function()? onTap;
  @override
  Widget build(BuildContext context) {
    if (postImageUrl == null) return Container();
    try {
      return ConstrainedBox(
        constraints: BoxConstraints.loose(const Size.square(500)),
        child: GestureDetector(
          onTap: onTap,
          child: CachedNetworkImage(
            imageUrl: postImageUrl!,
            fit: BoxFit.cover,
          ),
        ),
      );
    } catch (e) {
      return SizedBox(
        height: 300,
        width: 300,
        child: Column(
          children: [
            const Text('There was a problem fetching the image!'),
            const Text(''),
            Text(e.toString()),
          ],
        ),
      );
    }
  }
}
