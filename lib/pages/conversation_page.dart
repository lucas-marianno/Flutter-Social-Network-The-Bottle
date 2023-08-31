import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:the_bottle/components/blurred_appbar.dart';
import 'package:the_bottle/components/drawer_conversation.dart';
import 'package:the_bottle/components/input_field.dart';
import 'package:the_bottle/components/post_picture.dart';
import 'package:the_bottle/util/timestamp_to_string.dart';
import '../components/input_from_modal_bottom_sheet.dart';
import '../components/message_baloon.dart';
import '../components/show_dialog.dart';

// TODO: implement reaction to messages
// TODO: implement reply to messages

class ConversationPage extends StatefulWidget {
  const ConversationPage({
    super.key,
    required this.conversationId,
    required this.talkingTo,
  });
  final String conversationId;
  final Widget talkingTo;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController scrollController = ScrollController();
  final currentUser = FirebaseAuth.instance.currentUser!;
  bool showOptions = false;
  String? selectedMessageId;
  DocumentReference<Map<String, dynamic>>? selectedMessageRef;
  Map<String, dynamic>? selectedMessageData;

  void sendMessage(String text, Uint8List? loadedImage) async {
    if (text.isEmpty && loadedImage == null) return;

    final conversationRef =
        FirebaseFirestore.instance.collection('Conversations').doc(widget.conversationId);
    // update conversation
    final messageRef = await conversationRef.collection('Messages').add({
      'sender': currentUser.email,
      'text': text,
      'timestamp': Timestamp.now(),
    });

    // adds image to message
    if (loadedImage != null) {
      addImageToMessage(messageRef.id, loadedImage);
    }

    // scroll to most recent message
    scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.decelerate,
    );

    // notify participants that there's a new message and the update time
    final List participants = (await conversationRef.get())['participants'];
    for (String participant in participants) {
      if (participant != currentUser.email) {
        final updateTime = Timestamp.now();
        // notify participant
        FirebaseFirestore.instance
            .collection('User Profile')
            .doc(participant)
            .collection('Conversations')
            .doc(currentUser.email)
            .set({
          'conversationId': widget.conversationId,
          'lastUpdated': updateTime,
          'seen': false,
        }, SetOptions(merge: true));

        // notify  current user
        FirebaseFirestore.instance
            .collection('User Profile')
            .doc(currentUser.email)
            .collection('Conversations')
            .doc(participant)
            .set({
          'conversationId': widget.conversationId,
          'lastUpdated': updateTime,
          'seen': true,
        }, SetOptions(merge: true));
      }
    }
  }

  void deleteEmptyConversation() async {
    final ref = FirebaseFirestore.instance.collection('Conversations').doc(widget.conversationId);

    // verify if conversation has messages
    final hasMessages = (await ref.collection('Messages').get()).docs.isNotEmpty;
    if (hasMessages) return;

    // delete conversation if empty
    await ref.delete();
  }

  void addImageToMessage(String messageId, Uint8List image) async {
    // upload picture to firebase storage and retrieve download URL
    final String storageUrl =
        await (await FirebaseStorage.instance.ref('Conversation Files/$messageId').putData(image))
            .ref
            .getDownloadURL();

    // upload pictureUrl to firebase database
    await FirebaseFirestore.instance
        .collection('Conversations')
        .doc(widget.conversationId)
        .collection('Messages')
        .doc(messageId)
        .set(
      {'image': storageUrl},
      SetOptions(merge: true),
    );

    // unload image after post
    setState(() {});
  }

  void selectMessage(String messageId) async {
    // TODO: Implement multiple selection
    showOptions = true;
    selectedMessageId = messageId;
    selectedMessageRef = FirebaseFirestore.instance
        .collection('Conversations')
        .doc(widget.conversationId)
        .collection('Messages')
        .doc(selectedMessageId);
    selectedMessageData = (await selectedMessageRef!.get()).data()!;
    setState(() {});
  }

  void unSelectMessages() {
    setState(() {
      showOptions = false;
      selectedMessageId = null;
      selectedMessageRef = null;
      selectedMessageData = null;
    });
  }

  void deleteMessage() async {
    if (selectedMessageId == null) return;

    // delete message image (if exists)
    try {
      await FirebaseStorage.instance.ref('Conversation Files/$selectedMessageId').delete();
    } on FirebaseException {
      // skip
    }

    final messageSender = selectedMessageData!['sender']! as String;

    // ignore edit request
    if (messageSender != currentUser.email) {
      // TODO: bugfix: replace this dialog for only showing edit option if sender is currentuser
      // ignore: use_build_context_synchronously
      showMyDialog(
        context,
        title: 'Nope!',
        content: 'You can only delete your own messages',
      );
      return;
    }

    selectedMessageRef!.delete();

    unSelectMessages();
  }

  void editMessage() async {
    if (selectedMessageId == null) return;

    // retrieve current message data
    final messageSender = selectedMessageData!['sender']! as String;
    final oldText = selectedMessageData!['text']! as String;
    final oldTimeStamp = selectedMessageData!['timestamp']! as Timestamp;
    final bool isFirstEdit = !(selectedMessageData!['isEdited'] ?? false);

    // ignore edit request
    if (messageSender != currentUser.email) {
      // TODO: bugfix: replace this dialog for only showing edit option if sender is currentuser
      // ignore: use_build_context_synchronously
      showMyDialog(
        context,
        title: 'Nope!',
        content: 'You can only edit your own messages',
      );
      return;
    }

    // get new text from user
    // ignore: use_build_context_synchronously
    String? newText = await getInputFromModalBottomSheet(
      context,
      startingString: oldText,
      enterKeyPressSubmits: false,
    );

    if (newText == null || newText.isEmpty || newText == oldText) return;

    // set new text value and tag as edited
    selectedMessageRef!.set({
      'text': newText,
      'isEdited': true,
    }, SetOptions(merge: true));

    // save changes to history
    if (isFirstEdit) {
      await selectedMessageRef!.collection('Edit History').add({
        'previousText': null,
        'newText': oldText,
        'timestamp': oldTimeStamp,
      });
    }
    await selectedMessageRef!.collection('Edit History').add({
      'previousText': oldText,
      'newText': newText,
      'timestamp': Timestamp.now(),
    });
    unSelectMessages();
  }

  void messageInfo() async {
    if (selectedMessageId == null) return;
    //TODO: Feature: implement show edit history

    final history = (await selectedMessageRef!.collection('Edit History').get()).docs;

    // ignore: use_build_context_synchronously
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Message Info'),
        content: SizedBox(
          height: MediaQuery.of(context).size.height / 2,
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: history.isEmpty ? 1 : history.length,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              if (history.isEmpty) {
                return const Text('This message has never been edited');
              }
              // TODO: bugfix: Create a message info widget to be displayed here
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('before'),
                  Text(history[index]['previousText'] ?? ''),
                  const Text('after'),
                  Text(history[index]['newText']),
                  const Text('Modified at'),
                  Text(timestampToString(history[index]['timestamp'])),
                  const Text(''),
                ],
              );
            },
          ),
        ),
      ),
    );
    unSelectMessages();
  }

  @override
  void dispose() {
    deleteEmptyConversation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      endDrawer: const DrawerConversations(),
      extendBodyBehindAppBar: true,
      appBar: BlurredAppBar(
        centerTitle: false,
        title: widget.talkingTo,
        actions: showOptions
            ? [
                IconButton(onPressed: () {}, icon: const Icon(Icons.reply)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.star)),
                IconButton(onPressed: messageInfo, icon: const Icon(Icons.info_outline)),
                IconButton(onPressed: deleteMessage, icon: const Icon(Icons.delete)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.copy)),
                Transform.flip(
                  flipX: true,
                  child: IconButton(onPressed: () {}, icon: const Icon(Icons.reply)),
                ),
                IconButton(onPressed: editMessage, icon: const Icon(Icons.edit)),
              ]
            : [
                IconButton(
                  onPressed: () {
                    scaffoldKey.currentState?.openEndDrawer();
                  },
                  icon: const Icon(Icons.message),
                ),
              ],
      ),
      body: WillPopScope(
        onWillPop: () async {
          if (selectedMessageId != null) {
            unSelectMessages();
            return false;
          }
          return true;
        },
        child: GestureDetector(
          onTap: unSelectMessages,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('lib/assets/${Theme.of(context).brightness.name}doodle.jpg',
                  fit: BoxFit.cover),
              Column(
                children: [
                  // conversation
                  Expanded(
                    child: StreamBuilder(
                      stream: FirebaseFirestore.instance
                          .collection('Conversations')
                          .doc(widget.conversationId)
                          .collection('Messages')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          if (snapshot.data!.docs.isEmpty) {
                            return const Center(child: Text('start a conversation'));
                          }
                          final int itemCount = snapshot.data!.docs.length;
                          return ListView.builder(
                            controller: scrollController,
                            shrinkWrap: true,
                            reverse: true,
                            itemCount: itemCount,
                            itemBuilder: (context, index) {
                              final message = snapshot.data!.docs[index];
                              late final bool showsender;
                              late final String? imageUrl;
                              late final bool isEdited;
                              if (index == itemCount - 1 ||
                                  snapshot.data!.docs[index + 1]['sender'] != message['sender']) {
                                showsender = true;
                              } else {
                                showsender = false;
                              }
                              try {
                                imageUrl = message['image'];
                              } catch (e) {
                                imageUrl = null;
                              }
                              try {
                                isEdited = message['isEdited'];
                              } catch (e) {
                                isEdited = false;
                              }
                              return MessageBaloon(
                                sender: message['sender'],
                                text: message['text'],
                                timestamp: timestampToString(message['timestamp']),
                                messagePicture: PostPicture(
                                  imageHeight: 200,
                                  context: context,
                                  padding: const EdgeInsets.only(bottom: 10),
                                  postImageUrl: imageUrl,
                                ),
                                isSelected: selectedMessageId == message.id,
                                showSender: showsender,
                                isEdited: isEdited,
                                onLongPress: () => selectMessage(message.id),
                              );
                            },
                          );
                        } else {
                          return const Center(child: CircularProgressIndicator());
                        }
                      },
                    ),
                  ),
                  // post message
                  InputField(onSendTap: sendMessage, dismissKeyboardOnSend: false),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
