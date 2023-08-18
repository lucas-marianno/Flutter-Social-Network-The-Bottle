import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:the_wall/components/profile_picture.dart';
import 'package:the_wall/components/show_dialog.dart';
import 'package:the_wall/components/username.dart';
import 'package:the_wall/pages/conversation_page.dart';
import '../pages/profile_page.dart';
import '../util/timestamp_to_string.dart';
import 'input_from_modal_bottom_sheet.dart';
import 'options_modal_bottom_sheet.dart';

class WallPostHeader extends StatefulWidget {
  const WallPostHeader({
    super.key,
    required this.message,
    required this.postId,
    required this.postOwner,
    required this.postTimeStamp,
    this.isEdited = false,
    this.isFullScreen = false,
  });
  final String message;
  final String postId;
  final String postOwner;
  final Timestamp postTimeStamp;
  final bool isEdited;
  final bool isFullScreen;

  @override
  State<WallPostHeader> createState() => _WallPostHeaderState();
}

class _WallPostHeaderState extends State<WallPostHeader> {
  final User currentUser = FirebaseAuth.instance.currentUser!;
  late final bool userOwnsPost;

  void messagePostOwner() async {
    if (currentUser.email == widget.postOwner) return;

    // check profile for a previous conversation
    final conversation = await FirebaseFirestore.instance
        .collection('User Profile')
        .doc(currentUser.email)
        .collection('Conversations')
        .doc(widget.postOwner)
        .get();

    // if theres a conversation, navigate to conversation
    if (conversation.exists) {
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
      // ignore: use_build_context_synchronously
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ConversationPage(
            conversationId: conversation['conversationId'],
            talkingTo: Username(userEmail: widget.postOwner),
          ),
        ),
      );
    } else {
      // if theres no conversation, create a new one and notify participants
      final newConversation = FirebaseFirestore.instance.collection('Conversations').doc();
      newConversation.set({
        'participants': [currentUser.email, widget.postOwner]
      });

      // notify currentUser
      await FirebaseFirestore.instance
          .collection('User Profile')
          .doc(currentUser.email)
          .collection('Conversations')
          .doc(widget.postOwner)
          .set({
        'conversationId': newConversation.id,
        'lastUpdated': Timestamp.now(),
        'seen': true,
      });

      // TODO: bugfix: only notify postOwner when currentUser sends a message
      // if currentUser doesnt send a starting message:
      // delete the conversation and never notify postOwner

      // notify postOwner
      await FirebaseFirestore.instance
          .collection('User Profile')
          .doc(widget.postOwner)
          .collection('Conversations')
          .doc(currentUser.email)
          .set({
        'conversationId': newConversation.id,
        'lastUpdated': Timestamp.now(),
        'seen': false,
      });

      // ignore: use_build_context_synchronously
      Navigator.pop(context);
      // ignore: use_build_context_synchronously
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ConversationPage(
            conversationId: newConversation.id,
            talkingTo: Username(userEmail: widget.postOwner),
          ),
        ),
      );
    }
  }

  void profileTap() {
    optionsFromModalBottomSheet(
      context,
      children: [
        currentUser.email == widget.postOwner
            ? Container()
            : ListTile(
                onTap: messagePostOwner,
                leading: const Icon(Icons.message),
                title: Row(
                  children: [
                    const Text(
                      'Message ',
                    ),
                    Username(
                      userEmail: widget.postOwner,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
        ListTile(
          onTap: () {
            // Go to profile
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ProfilePage(
                  userEmail: widget.postOwner,
                  heroTag: widget.postId,
                ),
              ),
            );
          },
          leading: const Icon(Icons.person),
          title: const Text(
            'View Profile',
          ),
        ),
      ],
    );
  }

  void postOptions() {
    if (widget.isFullScreen) return;
    optionsFromModalBottomSheet(
      context,
      children: [
        ListTile(
          onTap: editPost,
          leading: const Icon(Icons.edit),
          title: const Text(
            'Edit post',
          ),
        ),
        ListTile(
          onTap: deletePost,
          leading: const Icon(Icons.delete),
          title: const Text(
            'Delete post',
          ),
        ),
      ],
    );
  }

  void editPost() async {
    // dismiss any keyboard
    FocusManager.instance.primaryFocus?.unfocus();
    if (context.mounted) Navigator.pop(context);

    if (widget.postOwner != currentUser.email) {
      showMyDialog(
        context,
        title: 'Nope!',
        content: 'You cannot edit posts made by someone else',
      );
      return;
    }

    // get new text from user
    String? newPostText = await getInputFromModalBottomSheet(
      context,
      startingString: widget.message,
      enterKeyPressSubmits: false,
    );

    if (newPostText == null || newPostText.isEmpty || newPostText == widget.message) return;

    // edit post in firebase firestore
    FirebaseFirestore.instance.collection('User Posts').doc(widget.postId).set({
      'Message': newPostText,
      'Edited': true,
    }, SetOptions(merge: true));
  }

  void deletePost() async {
    // TODO: bugfix: when deleting a post, you must first delete its comments, otherwise the
    // comments colection will remain even after the parent collection has been deleted

    // dismiss any keyboard
    FocusManager.instance.primaryFocus?.unfocus();
    if (context.mounted) Navigator.pop(context);

    if (widget.postOwner != currentUser.email) {
      showMyDialog(context,
          title: 'Nope!', content: 'You cannot delete posts made by someone else');
      return;
    }

    try {
      // delete post picture from firebase storage (if it exists)
      await FirebaseStorage.instance.ref('Post Pictures/${widget.postId}').delete();
    } catch (e) {
      e;
    }
    // delete post from firebase firestore
    await FirebaseFirestore.instance.collection('User Posts').doc(widget.postId).delete();
  }

  @override
  void initState() {
    super.initState();
    userOwnsPost = widget.postOwner == currentUser.email;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // profile thumbnail
        Hero(
          tag: widget.postId,
          child: ProfilePicture(
            profileEmailId: widget.postOwner,
            size: ProfilePictureSize.small,
            onTap: profileTap,
          ),
        ),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // username
            Username(
              userEmail: widget.postOwner,
              onTap: profileTap,
              style: const TextStyle(fontSize: 16),
            ),
            // timestamp
            Text(
              timestampToString(widget.postTimeStamp),
            )
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // more
            userOwnsPost
                ? Material(
                    color: Colors.transparent,
                    child: InkWell(onTap: postOptions, child: const Icon(Icons.more_horiz)))
                : Container(),
            // edited flag
            Text(
              widget.isEdited ? 'edited' : '',
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
