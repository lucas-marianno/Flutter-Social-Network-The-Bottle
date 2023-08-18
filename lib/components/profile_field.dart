import 'package:flutter/material.dart';

class ProfileField extends StatelessWidget {
  const ProfileField({
    super.key,
    required this.sectionName,
    required this.text,
    required this.onTap,
    this.editable = false,
  });
  final String sectionName;
  final String text;
  final Function()? onTap;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // height: 100,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // field name + settings icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  sectionName,
                  style: const TextStyle(fontSize: 18),
                ),
                !editable
                    ? Container()
                    : IconButton(
                        onPressed: onTap,
                        icon: const Icon(
                          Icons.edit,
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 10),

            // field value
            Text(
              text,
              style: const TextStyle(fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}
